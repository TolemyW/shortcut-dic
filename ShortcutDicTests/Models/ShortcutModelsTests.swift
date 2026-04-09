import XCTest
@testable import ShortcutDic

final class ShortcutModelsTests: XCTestCase {

    func testShortcutDisplayString_commandC() {
        let shortcut = Shortcut(
            title: "Copy",
            keyEquivalent: "c",
            modifiers: .command,
            menuPath: "Edit"
        )
        XCTAssertEqual(shortcut.displayString, "⌘ C")
    }

    func testShortcutDisplayString_commandShiftZ() {
        let shortcut = Shortcut(
            title: "Redo",
            keyEquivalent: "z",
            modifiers: [.command, .shift],
            menuPath: "Edit"
        )
        let display = shortcut.displayString
        XCTAssertTrue(display.contains("⌘"))
        XCTAssertTrue(display.contains("⇧"))
        XCTAssertTrue(display.contains("Z"))
    }

    func testShortcutMatchesModifier_commandMatchesCommand() {
        let shortcut = Shortcut(
            title: "Copy",
            keyEquivalent: "c",
            modifiers: .command,
            menuPath: "Edit"
        )
        XCTAssertTrue(shortcut.matchesModifier(.command))
    }

    func testShortcutMatchesModifier_commandShiftMatchesCommand() {
        let shortcut = Shortcut(
            title: "Redo",
            keyEquivalent: "z",
            modifiers: [.command, .shift],
            menuPath: "Edit"
        )
        XCTAssertTrue(shortcut.matchesModifier(.command))
    }

    func testShortcutMatchesModifier_optionDoesNotMatchCommand() {
        let shortcut = Shortcut(
            title: "Copy",
            keyEquivalent: "c",
            modifiers: .command,
            menuPath: "Edit"
        )
        XCTAssertFalse(shortcut.matchesModifier(.option))
    }

    func testShortcutGroupFiltered() {
        let shortcuts = [
            Shortcut(title: "Copy", keyEquivalent: "c", modifiers: .command, menuPath: "Edit"),
            Shortcut(title: "Special", keyEquivalent: "s", modifiers: .option, menuPath: "Edit"),
        ]
        let group = ShortcutGroup(menuName: "Edit", shortcuts: shortcuts)
        let filtered = group.filtered(by: .command)
        XCTAssertEqual(filtered.shortcuts.count, 1)
        XCTAssertEqual(filtered.shortcuts.first?.title, "Copy")
    }

    func testAppShortcutsFilteredByModifier() {
        let editShortcuts = [
            Shortcut(title: "Copy", keyEquivalent: "c", modifiers: .command, menuPath: "Edit"),
            Shortcut(title: "Special", keyEquivalent: "s", modifiers: .option, menuPath: "Edit"),
        ]
        let fileShortcuts = [
            Shortcut(title: "New", keyEquivalent: "n", modifiers: .command, menuPath: "File"),
        ]
        let app = AppShortcuts(
            appName: "Test",
            bundleIdentifier: "com.test",
            groups: [
                ShortcutGroup(menuName: "Edit", shortcuts: editShortcuts),
                ShortcutGroup(menuName: "File", shortcuts: fileShortcuts),
            ]
        )
        let filtered = app.filtered(by: .command)
        XCTAssertEqual(filtered.groups.count, 2)
        XCTAssertEqual(filtered.groups[0].shortcuts.count, 1)
        XCTAssertEqual(filtered.groups[1].shortcuts.count, 1)
    }

    func testAppShortcutsFilteredRemovesEmptyGroups() {
        let shortcuts = [
            Shortcut(title: "Special", keyEquivalent: "s", modifiers: .option, menuPath: "Edit"),
        ]
        let app = AppShortcuts(
            appName: "Test",
            bundleIdentifier: "com.test",
            groups: [ShortcutGroup(menuName: "Edit", shortcuts: shortcuts)]
        )
        let filtered = app.filtered(by: .command)
        XCTAssertEqual(filtered.groups.count, 0)
    }
}
