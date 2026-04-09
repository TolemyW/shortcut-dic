import XCTest
@testable import ShortcutDic

@MainActor
final class UsageTrackerTests: XCTestCase {

    var tracker: UsageTracker!
    var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UsageTrackerTest-\(UUID().uuidString).json")
        tracker = UsageTracker(storageURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testRecordAndRetrieve() {
        tracker.record(bundleId: "com.apple.finder", keyEquivalent: "c", modifiers: .command)
        tracker.record(bundleId: "com.apple.finder", keyEquivalent: "c", modifiers: .command)
        tracker.record(bundleId: "com.apple.finder", keyEquivalent: "v", modifiers: .command)

        let top = tracker.topShortcuts(for: "com.apple.finder", limit: 5)
        XCTAssertEqual(top.first?.keyEquivalent, "c")
        XCTAssertEqual(top.first?.count, 2)
    }

    func testTopShortcutsRespectLimit() {
        for char in ["a", "b", "c", "d", "e", "f"] {
            tracker.record(bundleId: "com.test", keyEquivalent: char, modifiers: .command)
        }
        let top = tracker.topShortcuts(for: "com.test", limit: 3)
        XCTAssertEqual(top.count, 3)
    }

    func testPersistence() {
        tracker.record(bundleId: "com.test", keyEquivalent: "x", modifiers: .command)
        tracker.save()

        let tracker2 = UsageTracker(storageURL: tempURL)
        let top = tracker2.topShortcuts(for: "com.test", limit: 5)
        XCTAssertEqual(top.first?.keyEquivalent, "x")
        XCTAssertEqual(top.first?.count, 1)
    }

    func testDifferentAppsAreSeparate() {
        tracker.record(bundleId: "com.app1", keyEquivalent: "a", modifiers: .command)
        tracker.record(bundleId: "com.app2", keyEquivalent: "b", modifiers: .command)

        let top1 = tracker.topShortcuts(for: "com.app1", limit: 5)
        let top2 = tracker.topShortcuts(for: "com.app2", limit: 5)
        XCTAssertEqual(top1.count, 1)
        XCTAssertEqual(top2.count, 1)
        XCTAssertEqual(top1.first?.keyEquivalent, "a")
        XCTAssertEqual(top2.first?.keyEquivalent, "b")
    }
}
