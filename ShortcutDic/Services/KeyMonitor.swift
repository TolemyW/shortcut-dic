import AppKit
import Combine
import os.log

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ShortcutDic", category: "KeyMonitor")

final class KeyMonitor: ObservableObject {

    @Published var isModifierHeld = false
    @Published var activeModifier: NSEvent.ModifierFlags?

    var longPressThreshold: TimeInterval
    var excludedBundleIds: Set<String> = []

    var onLongPress: ((NSEvent.ModifierFlags) -> Void)?
    var onRelease: (() -> Void)?
    var onDoubleTap: ((NSEvent.ModifierFlags) -> Void)?

    /// When true, all event handling is suppressed (used during search mode).
    var isLocked = false

    var doubleTapWindow: TimeInterval = 0.3

    /// Which modifier keys to monitor. Empty means monitor all.
    var monitoredModifiers: NSEvent.ModifierFlags = [.command, .option, .control]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressTimer: Timer?
    private var currentFlags: NSEvent.ModifierFlags = []
    private var lastReleaseTime: Date?
    private var lastReleasedModifier: NSEvent.ModifierFlags?

    init(longPressThreshold: TimeInterval = 0.5) {
        self.longPressThreshold = longPressThreshold
    }

    deinit {
        stop()
    }

    func isExcluded(bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return excludedBundleIds.contains(bundleId)
    }

    func start() {
        guard eventTap == nil else {
            log.debug("Event tap already exists, skipping start")
            return
        }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
        // Use passRetained to prevent use-after-free if callback fires during dealloc
        let userInfo = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handleFlagsChanged(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            log.error("Failed to create CGEvent tap — accessibility permission may not be effective yet")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("CGEvent tap created and enabled successfully")
    }

    func stop() {
        pressTimer?.invalidate()
        pressTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            // Balance the passRetained in start()
            Unmanaged.passUnretained(self).release()
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        // Only track modifiers the user has enabled
        let modifierOnly = flags.intersection(monitoredModifiers)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if self.isLocked {
                log.debug("KeyMonitor is locked, ignoring event")
                return
            }

            if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               self.isExcluded(bundleId: bundleId) {
                return
            }

            if !modifierOnly.isEmpty && self.currentFlags.isEmpty {
                // Modifier pressed — check for double-tap first
                if let releaseTime = self.lastReleaseTime,
                   let releasedMod = self.lastReleasedModifier,
                   Date().timeIntervalSince(releaseTime) < self.doubleTapWindow,
                   modifierOnly == releasedMod {
                    log.info("Double-tap detected")
                    self.lastReleaseTime = nil
                    self.lastReleasedModifier = nil
                    self.currentFlags = modifierOnly
                    self.pressTimer?.invalidate()
                    self.pressTimer = nil
                    self.onDoubleTap?(modifierOnly)
                    return
                }

                // Normal modifier press — start long-press timer
                self.lastReleaseTime = nil
                self.lastReleasedModifier = nil
                self.currentFlags = modifierOnly
                self.pressTimer?.invalidate()
                self.pressTimer = Timer.scheduledTimer(withTimeInterval: self.longPressThreshold, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.isModifierHeld = true
                    self.activeModifier = self.currentFlags
                    self.lastReleaseTime = nil
                    self.lastReleasedModifier = nil
                    self.onLongPress?(self.currentFlags)
                }
            } else if modifierOnly.isEmpty && !self.currentFlags.isEmpty {
                // Modifier released
                let releasedFlags = self.currentFlags
                self.pressTimer?.invalidate()
                self.pressTimer = nil
                self.currentFlags = []

                // Always record release for double-tap detection
                self.lastReleaseTime = Date()
                self.lastReleasedModifier = releasedFlags

                if self.isModifierHeld {
                    self.isModifierHeld = false
                    self.activeModifier = nil
                    self.onRelease?()
                }
            } else if modifierOnly != self.currentFlags {
                // Different modifier — restart
                self.lastReleaseTime = nil
                self.lastReleasedModifier = nil
                self.pressTimer?.invalidate()
                self.currentFlags = modifierOnly
                if self.isModifierHeld {
                    self.isModifierHeld = false
                    self.activeModifier = nil
                    self.onRelease?()
                }
                self.pressTimer = Timer.scheduledTimer(withTimeInterval: self.longPressThreshold, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.isModifierHeld = true
                    self.activeModifier = self.currentFlags
                    self.lastReleaseTime = nil
                    self.lastReleasedModifier = nil
                    self.onLongPress?(self.currentFlags)
                }
            }
        }
    }
}
