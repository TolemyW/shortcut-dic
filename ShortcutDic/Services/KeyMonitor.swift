import AppKit
import Combine

final class KeyMonitor: ObservableObject {

    @Published var isModifierHeld = false
    @Published var activeModifier: NSEvent.ModifierFlags?

    var longPressThreshold: TimeInterval
    var excludedBundleIds: Set<String> = []

    var onLongPress: ((NSEvent.ModifierFlags) -> Void)?
    var onRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressTimer: Timer?
    private var currentFlags: NSEvent.ModifierFlags = []

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
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

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
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        pressTimer?.invalidate()
        pressTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        let modifierOnly = flags.intersection([.command, .option, .control])

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               self.isExcluded(bundleId: bundleId) {
                return
            }

            if !modifierOnly.isEmpty && self.currentFlags.isEmpty {
                // Modifier pressed — start timer
                self.currentFlags = modifierOnly
                self.pressTimer?.invalidate()
                self.pressTimer = Timer.scheduledTimer(withTimeInterval: self.longPressThreshold, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.isModifierHeld = true
                    self.activeModifier = self.currentFlags
                    self.onLongPress?(self.currentFlags)
                }
            } else if modifierOnly.isEmpty && !self.currentFlags.isEmpty {
                // Modifier released
                self.pressTimer?.invalidate()
                self.pressTimer = nil
                self.currentFlags = []

                if self.isModifierHeld {
                    self.isModifierHeld = false
                    self.activeModifier = nil
                    self.onRelease?()
                }
            } else if modifierOnly != self.currentFlags {
                // Different modifier — restart
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
                    self.onLongPress?(self.currentFlags)
                }
            }
        }
    }
}
