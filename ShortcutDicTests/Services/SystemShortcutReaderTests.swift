import XCTest
@testable import ShortcutDic

final class SystemShortcutReaderTests: XCTestCase {

    func testConvertModifierMask_commandOnly() {
        // bit 20 = 1048576 = Command
        let flags = SystemShortcutReader.testConvertModifierMask(1048576)
        XCTAssertTrue(flags.contains(.command))
        XCTAssertFalse(flags.contains(.shift))
        XCTAssertFalse(flags.contains(.option))
        XCTAssertFalse(flags.contains(.control))
    }

    func testConvertModifierMask_controlOnly() {
        // bit 18 = 262144 = Control
        let flags = SystemShortcutReader.testConvertModifierMask(262144)
        XCTAssertTrue(flags.contains(.control))
        XCTAssertFalse(flags.contains(.command))
    }

    func testConvertModifierMask_controlShift() {
        // bit 17 + bit 18 = 131072 + 262144 = 393216
        let flags = SystemShortcutReader.testConvertModifierMask(393216)
        XCTAssertTrue(flags.contains(.control))
        XCTAssertTrue(flags.contains(.shift))
    }

    func testConvertModifierMask_functionFlagIgnored() {
        // bit 18 + bit 23 = 262144 + 8388608 = 8650752 (Control + Function)
        let flags = SystemShortcutReader.testConvertModifierMask(8650752)
        XCTAssertTrue(flags.contains(.control))
        XCTAssertFalse(flags.contains(.command))
    }

    func testCarbonKeyName_arrowKeys() {
        XCTAssertEqual(SystemShortcutReader.testCarbonKeyName(0x7E), "↑")
        XCTAssertEqual(SystemShortcutReader.testCarbonKeyName(0x7D), "↓")
        XCTAssertEqual(SystemShortcutReader.testCarbonKeyName(0x7B), "←")
        XCTAssertEqual(SystemShortcutReader.testCarbonKeyName(0x7C), "→")
    }

    func testCarbonKeyName_functionKeys() {
        XCTAssertEqual(SystemShortcutReader.testCarbonKeyName(0x7A), "F1")
        XCTAssertEqual(SystemShortcutReader.testCarbonKeyName(0x67), "F11")
        XCTAssertEqual(SystemShortcutReader.testCarbonKeyName(0x6F), "F12")
    }

    func testCarbonKeyName_space() {
        XCTAssertEqual(SystemShortcutReader.testCarbonKeyName(0x31), "Space")
    }

    func testKeyName_asciiPrintable() {
        // ASCII printable char should be returned directly
        let result = SystemShortcutReader.testKeyName(ascii: 32, virtualKey: 0x31) // space
        XCTAssertEqual(result, " ")
    }

    func testKeyName_nonAscii_fallsToVirtualKey() {
        // 65535 = no ASCII, should use virtual key
        let result = SystemShortcutReader.testKeyName(ascii: 65535, virtualKey: 0x7E)
        XCTAssertEqual(result, "↑")
    }

    func testHotkeyNamesExist() {
        // Verify key known IDs are mapped
        XCTAssertNotNil(SystemShortcutReader.hotkeyNames[64])  // Spotlight
        XCTAssertNotNil(SystemShortcutReader.hotkeyNames[32])  // Mission Control
    }
}
