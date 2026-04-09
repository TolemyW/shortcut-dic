import XCTest
@testable import ShortcutDic

final class FuzzyMatchTests: XCTestCase {

    private func shortcut(_ title: String, key: String = "x", mods: NSEvent.ModifierFlags = .command) -> Shortcut {
        Shortcut(title: title, keyEquivalent: key, modifiers: mods, menuPath: "Test")
    }

    func testEmptyQueryReturnsAll() {
        let shortcuts = [shortcut("Copy"), shortcut("Paste")]
        let results = FuzzyMatch.filter(shortcuts, query: "")
        XCTAssertEqual(results.count, 2)
    }

    func testExactSubstringMatch() {
        let shortcuts = [shortcut("Copy"), shortcut("Paste"), shortcut("Copyright")]
        let results = FuzzyMatch.filter(shortcuts, query: "copy")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.title, "Copy") // prefix match ranks higher
    }

    func testKeyEquivalentMatch() {
        let shortcuts = [shortcut("Save", key: "s"), shortcut("Open", key: "o")]
        let results = FuzzyMatch.filter(shortcuts, query: "s")
        XCTAssertTrue(results.contains(where: { $0.title == "Save" }))
    }

    func testDisplayStringMatch() {
        let shortcuts = [
            shortcut("Copy", key: "c", mods: .command),
            shortcut("Quit", key: "q", mods: .command)
        ]
        let results = FuzzyMatch.filter(shortcuts, query: "⌘")
        XCTAssertEqual(results.count, 2)
    }

    func testFuzzyMatch() {
        let shortcuts = [shortcut("New Window"), shortcut("Open")]
        let results = FuzzyMatch.filter(shortcuts, query: "nw")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "New Window")
    }

    func testNoMatches() {
        let shortcuts = [shortcut("Copy"), shortcut("Paste")]
        let results = FuzzyMatch.filter(shortcuts, query: "zzz")
        XCTAssertTrue(results.isEmpty)
    }

    func testScoreOrdering() {
        let shortcuts = [
            shortcut("Notify"),         // non-prefix substring "fi" → not matched (no "fi" substring)
            shortcut("Filter"),         // prefix match "fi" → score 120
            shortcut("Configure"),      // non-prefix substring match "fi" → score 100
        ]
        let results = FuzzyMatch.filter(shortcuts, query: "fi")
        // prefix match "Filter" should rank first
        XCTAssertEqual(results.first?.title, "Filter")
        XCTAssertTrue(results.contains(where: { $0.title == "Configure" }))
    }
}
