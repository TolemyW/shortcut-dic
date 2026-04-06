import AppKit

struct Shortcut: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let keyEquivalent: String
    let modifiers: NSEvent.ModifierFlags
    let menuPath: String

    /// Human-readable shortcut string like "⌘⇧C"
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyEquivalent.uppercased())
        return parts.joined()
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
