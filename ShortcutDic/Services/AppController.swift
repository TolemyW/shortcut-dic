import AppKit
import Combine
import os.log

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ShortcutDic", category: "AppController")

enum OverlayMode: Equatable {
    case idle
    case speedView
    case searchMode
}

@MainActor
final class AppController: ObservableObject {

    let settings = AppSettings()
    let keyMonitor: KeyMonitor
    let menuBarReader = MenuBarReader()
    let systemShortcutReader = SystemShortcutReader()
    let usageTracker: UsageTracker
    let overlayPanel = OverlayPanel()

    @Published var overlayMode: OverlayMode = .idle

    private var cancellables = Set<AnyCancellable>()
    private var permissionTimer: Timer?
    private var escLocalMonitor: Any?
    private var escGlobalMonitor: Any?
    private var clickOutsideMonitor: Any?
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?
    private var cacheCleanupTimer: Timer?

    // Cached state for transitioning between modes
    private var currentShortcuts: AppShortcuts?
    private var currentFilteredShortcuts: AppShortcuts?
    private var currentModifier: NSEvent.ModifierFlags?
    private var currentBundleId: String?
    private var targetApp: NSRunningApplication?

    init() {
        self.keyMonitor = KeyMonitor(longPressThreshold: settings.longPressDelay)
        self.usageTracker = UsageTracker()

        setupBindings()

        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    func start() {
        guard AccessibilityHelper.isTrusted else {
            log.warning("Accessibility not trusted, prompting for permission")
            AccessibilityHelper.promptForPermission()
            startPermissionPolling()
            return
        }
        log.info("Accessibility trusted, starting key monitor")
        permissionTimer?.invalidate()
        permissionTimer = nil
        keyMonitor.start()
    }

    private func startPermissionPolling() {
        guard permissionTimer == nil else { return }
        log.info("Starting permission polling (every 1s)")
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                if AccessibilityHelper.isTrusted {
                    log.info("Permission granted, starting key monitor")
                    self?.permissionTimer?.invalidate()
                    self?.permissionTimer = nil
                    self?.keyMonitor.start()
                }
            }
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        settings.$longPressDelay
            .sink { [weak self] delay in
                self?.keyMonitor.longPressThreshold = delay
            }
            .store(in: &cancellables)

        settings.$excludedBundleIds
            .sink { [weak self] ids in
                self?.keyMonitor.excludedBundleIds = Set(ids)
            }
            .store(in: &cancellables)

        settings.$doubleTapWindow
            .sink { [weak self] window in
                self?.keyMonitor.doubleTapWindow = window
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(settings.$monitorCommand, settings.$monitorOption, settings.$monitorControl)
            .sink { [weak self] cmd, opt, ctrl in
                var flags: NSEvent.ModifierFlags = []
                if cmd { flags.insert(.command) }
                if opt { flags.insert(.option) }
                if ctrl { flags.insert(.control) }
                self?.keyMonitor.monitoredModifiers = flags
            }
            .store(in: &cancellables)

        settings.$globalHotkey
            .sink { [weak self] _ in
                self?.updateGlobalHotkeyMonitor()
            }
            .store(in: &cancellables)

        keyMonitor.onLongPress = { [weak self] modifier in
            Task { @MainActor [weak self] in
                await self?.showSpeedView(for: modifier)
            }
        }

        keyMonitor.onRelease = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleRelease()
            }
        }

        keyMonitor.onDoubleTap = { [weak self] modifier in
            Task { @MainActor [weak self] in
                await self?.enterSearchMode(for: modifier)
            }
        }

        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.overlayMode == .searchMode {
                        self.dismissSearchMode()
                    } else if self.overlayPanel.isVisible {
                        // Safety net: hide any residual panel when app loses focus
                        self.overlayPanel.hideOverlay(animated: false)
                        self.overlayMode = .idle
                    }
                }
            }
            .store(in: &cancellables)

        // Invalidate system shortcut cache periodically when app activates
        NotificationCenter.default.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                self?.systemShortcutReader.clearCache()
            }
            .store(in: &cancellables)
    }

    // MARK: - Speed View

    private func showSpeedView(for modifier: NSEvent.ModifierFlags) async {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            log.warning("No frontmost application found")
            return
        }

        // Skip reading our own menu bar (causes NSMenu thread assertion)
        if bundleId == Bundle.main.bundleIdentifier {
            log.debug("Skipping self")
            return
        }

        if settings.disableInGames && isGameApp(bundleId: bundleId) {
            log.debug("Skipping game app: \(bundleId)")
            return
        }

        let appName = frontApp.localizedName ?? "Unknown"
        log.info("Reading shortcuts for \(appName) (\(bundleId))")
        guard let shortcuts = await menuBarReader.readShortcuts(
            for: frontApp.processIdentifier,
            appName: appName,
            bundleId: bundleId
        ) else {
            log.warning("Failed to read shortcuts for \(appName)")
            return
        }

        // If modifier was released while we were loading, or mode changed, don't show
        guard keyMonitor.isModifierHeld, overlayMode == .idle else {
            log.debug("Modifier released or mode changed during loading, skipping panel show")
            return
        }

        var filtered = shortcuts.filtered(by: modifier)

        // Append system shortcuts filtered by same modifier
        let sysGroup = systemShortcutReader.readSystemShortcuts()
        let filteredSys = sysGroup.filtered(by: modifier)
        if !filteredSys.shortcuts.isEmpty {
            filtered = AppShortcuts(
                appName: filtered.appName,
                bundleIdentifier: filtered.bundleIdentifier,
                groups: filtered.groups + [filteredSys]
            )
        }

        guard !filtered.groups.isEmpty else {
            log.debug("No shortcuts found for modifier in \(appName)")
            return
        }

        // Cache for potential search mode transition
        currentShortcuts = shortcuts
        currentFilteredShortcuts = filtered
        currentModifier = modifier
        currentBundleId = bundleId
        targetApp = frontApp

        let totalCount = filtered.groups.reduce(0) { $0 + $1.shortcuts.count }

        // Recent shortcuts from search mode history
        let recentEntries = usageTracker.recentShortcuts(for: bundleId, limit: 6)
        let recentShortcuts = recentEntries.compactMap { entry -> Shortcut? in
            for group in filtered.groups {
                if let match = group.shortcuts.first(where: {
                    $0.keyEquivalent.lowercased() == entry.keyEquivalent.lowercased() &&
                    $0.modifiers.rawValue == entry.modifiersRawValue
                }) {
                    return match
                }
            }
            return nil
        }

        let modifierLabel = modifierSymbol(modifier)
        let theme = AppTheme.from(settings: settings)
        let material = AppTheme.material(adaptToDarkMode: settings.adaptToDarkMode)
        let view = ShortcutGridView(
            appShortcuts: filtered,
            recentShortcuts: recentShortcuts,
            modifierLabel: modifierLabel,
            maxPerGroup: settings.maxPerGroup,
            totalShortcutCount: totalCount
        ).environment(\.appTheme, theme)

        overlayPanel.showOverlay(view, at: settings.panelPosition, material: material, panelOpacity: settings.panelOpacity)
        overlayMode = .speedView
    }

    // MARK: - Search Mode

    private func enterSearchMode(for modifier: NSEvent.ModifierFlags) async {
        log.info("Entering search mode")

        // If we don't have cached shortcuts (e.g., double-tap was too fast for speed view),
        // fetch them now
        if currentFilteredShortcuts == nil {
            guard let frontApp = NSWorkspace.shared.frontmostApplication,
                  let bundleId = frontApp.bundleIdentifier,
                  bundleId != Bundle.main.bundleIdentifier else { return }

            let appName = frontApp.localizedName ?? "Unknown"
            guard let shortcuts = await menuBarReader.readShortcuts(
                for: frontApp.processIdentifier,
                appName: appName,
                bundleId: bundleId
            ) else {
                log.warning("Failed to read shortcuts for search mode")
                return
            }

            var filtered = shortcuts.filtered(by: modifier)
            let sysGroup = systemShortcutReader.readSystemShortcuts().filtered(by: modifier)
            if !sysGroup.shortcuts.isEmpty {
                filtered = AppShortcuts(
                    appName: filtered.appName,
                    bundleIdentifier: filtered.bundleIdentifier,
                    groups: filtered.groups + [sysGroup]
                )
            }
            currentShortcuts = shortcuts
            currentFilteredShortcuts = filtered
            currentModifier = modifier
            currentBundleId = bundleId
            targetApp = frontApp
        }

        guard let filtered = currentFilteredShortcuts else { return }

        keyMonitor.isLocked = true

        let modifierLabel = modifierSymbol(modifier)
        let theme = AppTheme.from(settings: settings)
        let material = AppTheme.material(adaptToDarkMode: settings.adaptToDarkMode)
        let view = SearchView(
            appShortcuts: filtered,
            modifierLabel: modifierLabel,
            onExecute: { [weak self] shortcut in
                Task { @MainActor [weak self] in
                    self?.executeShortcut(shortcut)
                }
            },
            onDismiss: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.dismissSearchMode()
                }
            }
        ).environment(\.appTheme, theme)

        overlayPanel.onCancelOperation = { [weak self] in
            Task { @MainActor [weak self] in
                self?.dismissSearchMode()
            }
        }
        overlayPanel.showOverlay(view, at: settings.panelPosition, material: material, panelOpacity: settings.panelOpacity)
        overlayPanel.enterSearchMode()
        overlayMode = .searchMode

        installSearchMonitors()
    }

    private func installSearchMonitors() {
        removeSearchMonitors()

        // Local ESC monitor (fires when this app is active)
        escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in
                    self?.dismissSearchMode()
                }
                return nil
            }
            return event
        }

        // Global ESC monitor (fires when another app is active — backup)
        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in
                    self?.dismissSearchMode()
                }
            }
        }

        // Click outside the panel to dismiss
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissSearchMode()
            }
        }
    }

    private func removeSearchMonitors() {
        if let m = escLocalMonitor { NSEvent.removeMonitor(m); escLocalMonitor = nil }
        if let m = escGlobalMonitor { NSEvent.removeMonitor(m); escGlobalMonitor = nil }
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
    }

    private func dismissSearchMode() {
        guard overlayMode == .searchMode else { return }
        log.info("Dismissing search mode")
        removeSearchMonitors()
        overlayPanel.hideOverlay()
        overlayMode = .idle
        keyMonitor.isLocked = false

        // Re-activate target app
        targetApp?.activate()
        clearCachedState()
    }

    private func executeShortcut(_ shortcut: Shortcut) {
        guard let app = targetApp, let bundleId = currentBundleId else { return }
        log.info("Executing shortcut: \(shortcut.displayString) \(shortcut.title)")

        // Record in recent history
        usageTracker.recordRecent(bundleId: bundleId, shortcut: shortcut)
        usageTracker.record(bundleId: bundleId, keyEquivalent: shortcut.keyEquivalent, modifiers: shortcut.modifiers)

        // Dismiss and execute
        removeSearchMonitors()
        overlayPanel.hideOverlay()
        overlayMode = .idle
        keyMonitor.isLocked = false
        clearCachedState()

        ShortcutExecutor.execute(shortcut: shortcut, in: app)
    }

    // MARK: - Release Handling

    private func handleRelease() {
        switch overlayMode {
        case .speedView:
            overlayPanel.hideOverlay(animated: false)
            overlayMode = .idle
            // Clear cached state after double-tap window expires
            cacheCleanupTimer?.invalidate()
            cacheCleanupTimer = Timer.scheduledTimer(withTimeInterval: keyMonitor.doubleTapWindow + 0.1, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.overlayMode == .idle else { return }
                    self.clearCachedState()
                }
            }
        case .searchMode:
            // Panel is pinned in search mode — ignore release
            break
        case .idle:
            // Safety net: if panel is still visible despite idle state (race condition),
            // force hide it to prevent residual windows
            if overlayPanel.isVisible {
                log.warning("Panel visible in idle state — force hiding")
                overlayPanel.hideOverlay(animated: false)
            }
        }
    }

    // MARK: - Global Hotkey

    private func updateGlobalHotkeyMonitor() {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotkeyMonitor = nil
        }
        if let monitor = localHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            localHotkeyMonitor = nil
        }
        guard let combo = settings.globalHotkey else { return }
        let targetKeyCode = combo.keyCode
        let targetMods = NSEvent.ModifierFlags(rawValue: combo.modifiers)
            .intersection([.command, .option, .control, .shift])

        let handler: (NSEvent) -> Void = { [weak self] event in
            let eventMods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == targetKeyCode && eventMods == targetMods {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.overlayMode == .searchMode {
                        self.dismissSearchMode()
                    } else {
                        await self.enterSearchMode(for: .command)
                    }
                }
            }
        }

        // Global: fires when other apps are focused
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
        // Local: fires when this app is focused (e.g., settings window)
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
            return event
        }
        log.info("Global hotkey monitor registered: \(combo.displayString)")
    }

    // MARK: - Helpers

    private func clearCachedState() {
        currentShortcuts = nil
        currentFilteredShortcuts = nil
        currentModifier = nil
        currentBundleId = nil
        targetApp = nil
    }

    private func modifierSymbol(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    private func isGameApp(bundleId: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
              let bundle = Bundle(url: url),
              let category = bundle.infoDictionary?["LSApplicationCategoryType"] as? String else {
            return false
        }
        return category.contains("games")
    }
}
