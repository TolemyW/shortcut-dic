import AppKit
import os.log

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ShortcutDic", category: "SystemShortcutReader")

final class SystemShortcutReader {

    private var cachedGroup: ShortcutGroup?

    func readSystemShortcuts() -> ShortcutGroup {
        if let cached = cachedGroup { return cached }

        var shortcuts: [Shortcut] = []

        guard let defaults = UserDefaults(suiteName: "com.apple.symbolichotkeys"),
              let hotkeys = defaults.dictionary(forKey: "AppleSymbolicHotKeys") else {
            log.warning("Failed to read AppleSymbolicHotKeys")
            return ShortcutGroup(menuName: "System", shortcuts: [])
        }

        for (idStr, value) in hotkeys {
            guard let dict = value as? [String: Any],
                  let enabled = dict["enabled"] as? Bool, enabled,
                  let valueDict = dict["value"] as? [String: Any],
                  let params = valueDict["parameters"] as? [Int],
                  params.count >= 3 else { continue }

            guard let id = Int(idStr),
                  let name = Self.hotkeyNames[id] else { continue }

            let asciiCode = params[0]
            let virtualKeyCode = params[1]
            let modifierMask = params[2]

            // Skip entries with no key assigned
            if virtualKeyCode == 65535 && asciiCode == 65535 { continue }

            let modifiers = Self.testConvertModifierMask(modifierMask)
            let keyString = Self.testKeyName(ascii: asciiCode, virtualKey: virtualKeyCode)

            guard !keyString.isEmpty else { continue }

            shortcuts.append(Shortcut(
                title: name,
                keyEquivalent: keyString,
                modifiers: modifiers,
                menuPath: "System"
            ))
        }

        shortcuts.sort { $0.title < $1.title }
        let group = ShortcutGroup(menuName: "System", shortcuts: shortcuts)
        cachedGroup = group
        log.info("Read \(shortcuts.count) system shortcuts")
        return group
    }

    func clearCache() {
        cachedGroup = nil
    }

    // MARK: - Modifier Conversion

    /// Convert symbolichotkeys modifier mask to NSEvent.ModifierFlags.
    /// Bits: 17=Shift, 18=Control, 19=Option, 20=Command, 23=Function (ignored)
    static func testConvertModifierMask(_ mask: Int) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if mask & (1 << 17) != 0 { flags.insert(.shift) }
        if mask & (1 << 18) != 0 { flags.insert(.control) }
        if mask & (1 << 19) != 0 { flags.insert(.option) }
        if mask & (1 << 20) != 0 { flags.insert(.command) }
        // bit 23 = .function, ignored for display (arrow/F-keys implicitly have it)
        return flags
    }

    // MARK: - Key Name Resolution

    static func testKeyName(ascii: Int, virtualKey: Int) -> String {
        // If ASCII is a printable character, use it
        if ascii != 65535 && ascii >= 0x20 && ascii < 0x7F {
            return String(Character(UnicodeScalar(ascii)!))
        }
        // Otherwise map virtual key code
        return testCarbonKeyName(virtualKey)
    }

    /// Map Carbon virtual key code to readable string.
    static func testCarbonKeyName(_ code: Int) -> String {
        let map: [Int: String] = [
            // Letters
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x1F: "O", 0x20: "U", 0x22: "I",
            0x23: "P", 0x25: "L", 0x26: "J", 0x28: "K", 0x2D: "N",
            0x2E: "M",
            // Numbers
            0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6",
            0x17: "5", 0x18: "=", 0x19: "9", 0x1A: "7", 0x1B: "-",
            0x1C: "8", 0x1D: "0", 0x1E: "]", 0x21: "[",
            // Special
            0x24: "↩", 0x30: "⇥", 0x31: "Space", 0x32: "`",
            0x33: "⌫", 0x35: "⎋",
            // Arrows (0x7B=123, 0x7C=124, 0x7D=125, 0x7E=126)
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            // Function keys
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
            0x69: "F13", 0x6B: "F14", 0x71: "F15",
            // Home/End/Page
            0x73: "Home", 0x77: "End", 0x74: "⇞", 0x79: "⇟",
        ]
        return map[code] ?? ""
    }

    // MARK: - Hotkey ID → Name Mapping

    static let hotkeyNames: [Int: String] = [
        // Accessibility
        7:   "Move Focus to Menu Bar",
        8:   "Move Focus to Dock",
        9:   "Move Focus to Active Window",
        10:  "Move Focus to Window Toolbar",
        11:  "Move Focus to Floating Window",
        12:  "Move Focus to Next Window",
        13:  "Change Tab Focus Mode",
        15:  "Turn Zoom On or Off",
        17:  "Zoom In",
        19:  "Zoom Out",
        27:  "Move Focus to Next Window",

        // Mission Control & Spaces
        32:  "Mission Control",
        33:  "Application Windows",
        34:  "Move Left a Space",
        35:  "Move Right a Space",
        36:  "Show Notification Center",

        // Screenshots
        28:  "Screenshot (Full Screen to File)",
        29:  "Screenshot (Full Screen to Clipboard)",
        30:  "Screenshot (Selection to File)",
        31:  "Screenshot (Selection to Clipboard)",
        184: "Screenshot and Recording Options",

        // Spaces switching
        79:  "Switch to Desktop 1",
        80:  "Switch to Desktop 2",
        81:  "Switch to Desktop 3",
        82:  "Switch to Desktop 4",

        // Input sources
        60:  "Select Previous Input Source",
        61:  "Select Next Input Source",

        // Spotlight
        64:  "Spotlight Search",
        65:  "Finder Search Window",

        // Desktop & Launchpad
        118: "Show Desktop",
        160: "Show Launchpad",

        // Accessibility
        162: "Accessibility Controls",
        175: "Turn Focus On or Off",

        // App management
        98:  "Turn Dock Hiding On or Off",
    ]
}
