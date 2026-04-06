import AppKit
import Combine

@MainActor
final class AppController: ObservableObject {

    let settings = AppSettings()
    let keyMonitor: KeyMonitor
    let menuBarReader = MenuBarReader()
    let usageTracker: UsageTracker
    let overlayPanel = OverlayPanel()

    @Published var isShowingPanel = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.keyMonitor = KeyMonitor(longPressThreshold: settings.longPressDelay)
        self.usageTracker = UsageTracker()

        setupBindings()
    }

    func start() {
        guard AccessibilityHelper.isTrusted else {
            AccessibilityHelper.promptForPermission()
            return
        }
        keyMonitor.start()
    }

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

        keyMonitor.onLongPress = { [weak self] modifier in
            Task { @MainActor [weak self] in
                await self?.showPanel(for: modifier)
            }
        }

        keyMonitor.onRelease = { [weak self] in
            Task { @MainActor [weak self] in
                self?.hidePanel()
            }
        }
    }

    private func showPanel(for modifier: NSEvent.ModifierFlags) async {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else { return }

        if settings.disableInGames && isGameApp(bundleId: bundleId) {
            return
        }

        let appName = frontApp.localizedName ?? "Unknown"
        guard let shortcuts = await menuBarReader.readShortcuts(
            for: frontApp.processIdentifier,
            appName: appName,
            bundleId: bundleId
        ) else { return }

        let filtered = shortcuts.filtered(by: modifier)
        guard !filtered.groups.isEmpty else { return }

        let topUsage = usageTracker.topShortcuts(for: bundleId, limit: 6)
        let frequentShortcuts = topUsage.compactMap { entry -> Shortcut? in
            for group in filtered.groups {
                if let match = group.shortcuts.first(where: {
                    $0.keyEquivalent.lowercased() == entry.keyEquivalent.lowercased() &&
                    $0.modifiers == entry.modifiers
                }) {
                    return match
                }
            }
            return nil
        }

        let modifierLabel = modifierSymbol(modifier)
        let view = ShortcutGridView(
            appShortcuts: filtered,
            frequentShortcuts: frequentShortcuts,
            modifierLabel: modifierLabel
        )

        overlayPanel.showOverlay(view, at: settings.panelPosition)
        isShowingPanel = true
    }

    private func hidePanel() {
        overlayPanel.hideOverlay()
        isShowingPanel = false
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
        if settings.excludedBundleIds.contains(bundleId) { return true }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
              let bundle = Bundle(url: url),
              let category = bundle.infoDictionary?["LSApplicationCategoryType"] as? String else {
            return false
        }
        return category.contains("games")
    }
}
