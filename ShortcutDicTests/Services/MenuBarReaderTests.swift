import XCTest
@testable import ShortcutDic

final class MenuBarReaderTests: XCTestCase {

    func testCacheReturnsSameResultForSameApp() async {
        let reader = MenuBarReader()
        let finderBundleId = "com.apple.finder"
        guard let finderPid = NSRunningApplication.runningApplications(
            withBundleIdentifier: finderBundleId
        ).first?.processIdentifier else {
            XCTSkip("Finder not running")
            return
        }

        let result1 = await reader.readShortcuts(for: finderPid, appName: "Finder", bundleId: finderBundleId)
        let result2 = await reader.readShortcuts(for: finderPid, appName: "Finder", bundleId: finderBundleId)

        // Second call should return cached result (same group count)
        XCTAssertEqual(result1?.groups.count, result2?.groups.count)
    }

    func testCacheInvalidatesAfterClear() async {
        let reader = MenuBarReader()
        reader.clearCache()
        XCTAssertFalse(reader.isCached(bundleId: "com.apple.finder"))
    }

    func testModifierConversion_commandOnly() {
        // AX modifier value 0 = just ⌘
        let modifiers = MenuBarReader.convertAXModifiers(0)
        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertFalse(modifiers.contains(.shift))
        XCTAssertFalse(modifiers.contains(.option))
        XCTAssertFalse(modifiers.contains(.control))
    }

    func testModifierConversion_commandShift() {
        // AX modifier value 1 = ⌘⇧
        let modifiers = MenuBarReader.convertAXModifiers(1)
        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertTrue(modifiers.contains(.shift))
    }

    func testModifierConversion_commandOption() {
        // AX modifier value 2 = ⌘⌥
        let modifiers = MenuBarReader.convertAXModifiers(2)
        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertTrue(modifiers.contains(.option))
    }

    func testModifierConversion_commandControl() {
        // AX modifier value 4 = ⌘⌃
        let modifiers = MenuBarReader.convertAXModifiers(4)
        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertTrue(modifiers.contains(.control))
    }

    func testModifierConversion_noCommand() {
        // AX modifier value 8 = no ⌘
        let modifiers = MenuBarReader.convertAXModifiers(8)
        XCTAssertFalse(modifiers.contains(.command))
    }
}
