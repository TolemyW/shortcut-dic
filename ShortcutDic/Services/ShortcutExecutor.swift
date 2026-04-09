import AppKit
import os.log

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ShortcutDic", category: "ShortcutExecutor")

enum ShortcutExecutor {

    static func execute(shortcut: Shortcut, in app: NSRunningApplication) {
        app.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let keyCode = keyCodeFor(shortcut.keyEquivalent) else {
                log.warning("No key code mapping for '\(shortcut.keyEquivalent)'")
                return
            }

            let flags = convertToEventFlags(shortcut.modifiers)

            if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                keyDown.flags = flags
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                keyUp.flags = flags
                keyUp.post(tap: .cghidEventTap)
            }

            log.info("Executed shortcut: \(shortcut.displayString) \(shortcut.title)")
        }
    }

    private static func convertToEventFlags(_ modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }

    private static func keyCodeFor(_ key: String) -> CGKeyCode? {
        // Try direct map first, then lowercase
        keyCodeMap[key] ?? keyCodeMap[key.lowercased()]
    }

    // macOS virtual key codes (US keyboard layout)
    private static let keyCodeMap: [String: CGKeyCode] = [
        // Letters
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
        "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
        "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
        "y": 0x10, "t": 0x11, "o": 0x1F, "u": 0x20, "i": 0x22,
        "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D,
        "m": 0x2E,
        // Numbers
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
        // Punctuation
        "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E,
        ";": 0x29, "'": 0x27, ",": 0x2B, ".": 0x2F,
        "/": 0x2C, "\\": 0x2A, "`": 0x32,
        // Special keys (raw characters from AX API)
        "\r": 0x24, "\t": 0x30, " ": 0x31,
        "\u{08}": 0x33, "\u{7F}": 0x33, "\u{1B}": 0x35,
        // Unicode arrow keys (from AX API kAXMenuItemCmdCharAttribute)
        "\u{F700}": 0x7E, "\u{F701}": 0x7D, "\u{F702}": 0x7B, "\u{F703}": 0x7C,
        // Function keys (Unicode private use from AX API)
        "\u{F704}": 0x7A, "\u{F705}": 0x78, "\u{F706}": 0x63, "\u{F707}": 0x76,
        "\u{F708}": 0x60, "\u{F709}": 0x61, "\u{F70A}": 0x62, "\u{F70B}": 0x64,
        "\u{F70C}": 0x65, "\u{F70D}": 0x6D, "\u{F70E}": 0x67, "\u{F70F}": 0x6F,
        // Home/End/PageUp/PageDown
        "\u{F729}": 0x73, "\u{F72B}": 0x77, "\u{F72C}": 0x74, "\u{F72D}": 0x79,
        // Readable string forms (from SystemShortcutReader / displayString)
        "Space": 0x31, "space": 0x31,
        "↑": 0x7E, "↓": 0x7D, "←": 0x7B, "→": 0x7C,
        "↩": 0x24, "⇥": 0x30, "⌫": 0x33, "⎋": 0x35,
        "⇞": 0x74, "⇟": 0x79, "Home": 0x73, "End": 0x77,
        "F1": 0x7A, "F2": 0x78, "F3": 0x63, "F4": 0x76,
        "F5": 0x60, "F6": 0x61, "F7": 0x62, "F8": 0x64,
        "F9": 0x65, "F10": 0x6D, "F11": 0x67, "F12": 0x6F,
    ]
}
