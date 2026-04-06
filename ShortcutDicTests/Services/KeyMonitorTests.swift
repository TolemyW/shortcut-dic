import XCTest
@testable import ShortcutDic

final class KeyMonitorTests: XCTestCase {

    func testInitialState() {
        let monitor = KeyMonitor()
        XCTAssertFalse(monitor.isModifierHeld)
        XCTAssertNil(monitor.activeModifier)
    }

    func testLongPressThresholdDefault() {
        let monitor = KeyMonitor()
        XCTAssertEqual(monitor.longPressThreshold, 0.5, accuracy: 0.01)
    }

    func testLongPressThresholdCustom() {
        let monitor = KeyMonitor(longPressThreshold: 0.8)
        XCTAssertEqual(monitor.longPressThreshold, 0.8, accuracy: 0.01)
    }

    func testExcludedAppCheck() {
        let monitor = KeyMonitor()
        monitor.excludedBundleIds = Set(["com.game.test"])
        XCTAssertTrue(monitor.isExcluded(bundleId: "com.game.test"))
        XCTAssertFalse(monitor.isExcluded(bundleId: "com.apple.finder"))
    }
}
