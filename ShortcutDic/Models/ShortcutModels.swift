import AppKit

struct Shortcut: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let keyEquivalent: String
    let modifiers: NSEvent.ModifierFlags
    let menuPath: String

    /// Human-readable shortcut string like "⌘ ⇧ C"
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(Self.readableKey(keyEquivalent))
        return parts.joined(separator: " ")
    }

    /// Map special Unicode characters from AX API to readable names.
    private static func readableKey(_ key: String) -> String {
        guard let scalar = key.unicodeScalars.first else { return key }
        switch scalar.value {
        case 0x001B: return "⎋"           // Escape
        case 0x0008, 0x007F: return "⌫"   // Delete/Backspace
        case 0x0009: return "⇥"           // Tab
        case 0x000D, 0x0003: return "↩"   // Return/Enter
        case 0x0020: return "Space"
        case 0xF700: return "↑"           // Up arrow
        case 0xF701: return "↓"           // Down arrow
        case 0xF702: return "←"           // Left arrow
        case 0xF703: return "→"           // Right arrow
        case 0xF704...0xF70F:             // F1-F12
            let fNum = Int(scalar.value) - 0xF704 + 1
            return "F\(fNum)"
        case 0xF710...0xF71B:             // F13-F24
            let fNum = Int(scalar.value) - 0xF710 + 13
            return "F\(fNum)"
        case 0xF729: return "Home"
        case 0xF72B: return "End"
        case 0xF72C: return "⇞"           // Page Up
        case 0xF72D: return "⇟"           // Page Down
        case 0xF72F: return "⏏"           // Eject (used by some fullscreen toggles)
        default:
            let upper = key.uppercased()
            // If uppercased produces non-printable or replacement char, use hex
            if upper.unicodeScalars.contains(where: { !$0.isASCII && $0.value < 0x2000 }) {
                return String(format: "0x%04X", scalar.value)
            }
            return upper
        }
    }

    /// Whether this shortcut involves the given modifier key
    func matchesModifier(_ modifier: NSEvent.ModifierFlags) -> Bool {
        modifiers.contains(modifier)
    }

    static func == (lhs: Shortcut, rhs: Shortcut) -> Bool {
        lhs.title == rhs.title &&
        lhs.keyEquivalent == rhs.keyEquivalent &&
        lhs.modifiers == rhs.modifiers &&
        lhs.menuPath == rhs.menuPath
    }
}

struct ShortcutGroup: Identifiable {
    let id = UUID()
    let menuName: String
    let shortcuts: [Shortcut]

    func filtered(by modifier: NSEvent.ModifierFlags) -> ShortcutGroup {
        ShortcutGroup(
            menuName: menuName,
            shortcuts: shortcuts.filter { $0.matchesModifier(modifier) }
        )
    }
}

struct AppShortcuts {
    let appName: String
    let bundleIdentifier: String
    let groups: [ShortcutGroup]

    func filtered(by modifier: NSEvent.ModifierFlags) -> AppShortcuts {
        AppShortcuts(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            groups: groups
                .map { $0.filtered(by: modifier) }
                .filter { !$0.shortcuts.isEmpty }
        )
    }
}
