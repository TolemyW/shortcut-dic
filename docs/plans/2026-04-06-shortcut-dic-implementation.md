# ShortcutDic Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that shows a HUD overlay of the current app's keyboard shortcuts when the user long-presses a modifier key.

**Architecture:** Menu bar app (no Dock icon) using CGEventTap for global key monitoring, AXUIElement for reading menu bar shortcuts, and NSPanel + SwiftUI for the HUD overlay. Data flows: KeyMonitor detects long-press → MenuBarReader reads shortcuts → OverlayPanel displays them.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (NSPanel, CGEvent, AXUIElement), macOS 13+

---

### Task 1: Project Scaffolding

**Files:**
- Create: `ShortcutDic/ShortcutDicApp.swift`
- Create: `ShortcutDic/Info.plist`
- Create: `ShortcutDic/ShortcutDic.entitlements`
- Create: `ShortcutDic/Models/.gitkeep`
- Create: `ShortcutDic/Services/.gitkeep`
- Create: `ShortcutDic/Views/.gitkeep`
- Create: `ShortcutDic/Utilities/.gitkeep`
- Create: `project.yml` (xcodegen spec)

**Step 1: Install xcodegen if not present**

Run: `brew list xcodegen || brew install xcodegen`

**Step 2: Create project.yml for xcodegen**

```yaml
name: ShortcutDic
options:
  bundleIdPrefix: com.shortcutdic
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"

targets:
  ShortcutDic:
    type: application
    platform: macOS
    sources:
      - ShortcutDic
    settings:
      base:
        INFOPLIST_FILE: ShortcutDic/Info.plist
        CODE_SIGN_ENTITLEMENTS: ShortcutDic/ShortcutDic.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.shortcutdic.app
        GENERATE_INFOPLIST_FILE: false
    entitlements:
      path: ShortcutDic/ShortcutDic.entitlements

  ShortcutDicTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - ShortcutDicTests
    dependencies:
      - target: ShortcutDic
    settings:
      base:
        GENERATE_INFOPLIST_FILE: true
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/ShortcutDic.app/Contents/MacOS/ShortcutDic"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

**Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ShortcutDic</string>
    <key>CFBundleDisplayName</key>
    <string>ShortcutDic</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>ShortcutDic needs accessibility access to read menu bar shortcuts and monitor modifier keys.</string>
</dict>
</plist>
```

**Step 4: Create entitlements file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

Note: We disable App Sandbox because CGEventTap and AXUIElement require unrestricted access. This is standard for accessibility tools.

**Step 5: Create minimal app entry point**

```swift
// ShortcutDic/ShortcutDicApp.swift
import SwiftUI

@main
struct ShortcutDicApp: App {
    var body: some Scene {
        MenuBarExtra("ShortcutDic", systemImage: "keyboard") {
            Text("ShortcutDic is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        Settings {
            Text("Settings placeholder")
                .frame(width: 300, height: 200)
        }
    }
}
```

**Step 6: Create test directory with placeholder**

```swift
// ShortcutDicTests/ShortcutDicTests.swift
import XCTest
@testable import ShortcutDic

final class ShortcutDicTests: XCTestCase {
    func testAppLaunches() {
        XCTAssertTrue(true)
    }
}
```

**Step 7: Generate Xcode project and verify build**

Run: `xcodegen generate`
Run: `xcodebuild -project ShortcutDic.xcodeproj -scheme ShortcutDic -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add -A
git commit -m "scaffold: initialize ShortcutDic macOS menu bar app project"
```

---

### Task 2: Data Models

**Files:**
- Create: `ShortcutDic/Models/ShortcutModels.swift`
- Create: `ShortcutDicTests/Models/ShortcutModelsTests.swift`

**Step 1: Write tests for data models**

```swift
// ShortcutDicTests/Models/ShortcutModelsTests.swift
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
        XCTAssertEqual(shortcut.displayString, "⌘C")
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
        // Edit group should have 1 shortcut (Copy), File group should have 1 (New)
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
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project ShortcutDic.xcodeproj -scheme ShortcutDicTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: FAIL — `Shortcut`, `ShortcutGroup`, `AppShortcuts` not defined

**Step 3: Implement data models**

```swift
// ShortcutDic/Models/ShortcutModels.swift
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
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project ShortcutDic.xcodeproj -scheme ShortcutDicTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add ShortcutDic/Models/ShortcutModels.swift ShortcutDicTests/Models/ShortcutModelsTests.swift
git commit -m "feat: add shortcut data models with filtering"
```

---

### Task 3: Accessibility Helper

**Files:**
- Create: `ShortcutDic/Utilities/AccessibilityHelper.swift`

**Step 1: Implement AccessibilityHelper**

No unit test — this wraps system APIs that require actual accessibility permissions. Will be tested manually.

```swift
// ShortcutDic/Utilities/AccessibilityHelper.swift
import AppKit
import ApplicationServices

enum AccessibilityHelper {

    /// Check if the app has accessibility permission
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt for accessibility permission (shows system dialog)
    static func promptForPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to the Accessibility pane
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
```

**Step 2: Verify build**

Run: `xcodebuild -project ShortcutDic.xcodeproj -scheme ShortcutDic -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ShortcutDic/Utilities/AccessibilityHelper.swift
git commit -m "feat: add accessibility permission helper"
```

---

### Task 4: MenuBarReader Service

**Files:**
- Create: `ShortcutDic/Services/MenuBarReader.swift`
- Create: `ShortcutDicTests/Services/MenuBarReaderTests.swift`

**Step 1: Write tests**

Note: AXUIElement tests require accessibility permission and a running app. We test the parsing/caching logic, not the raw AX calls.

```swift
// ShortcutDicTests/Services/MenuBarReaderTests.swift
import XCTest
@testable import ShortcutDic

final class MenuBarReaderTests: XCTestCase {

    func testCacheReturnsSameResultForSameApp() async {
        let reader = MenuBarReader()
        // Read shortcuts for Finder (always running)
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
        // After clear, isCached should be false for any app
        XCTAssertFalse(reader.isCached(bundleId: "com.apple.finder"))
    }

    func testModifierConversion() {
        // kAXMenuItemCmdModifiers values:
        // 0 = no extra modifiers (just ⌘)
        // kCGEventFlagMaskShift >> 16 = shift
        let modifiers = MenuBarReader.convertAXModifiers(0)
        XCTAssertTrue(modifiers.contains(.command))

        let shiftModifiers = MenuBarReader.convertAXModifiers(kCGEventFlagMaskShift.rawValue >> 16)
        XCTAssertTrue(shiftModifiers.contains(.command))
        XCTAssertTrue(shiftModifiers.contains(.shift))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project ShortcutDic.xcodeproj -scheme ShortcutDicTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: FAIL — `MenuBarReader` not defined

**Step 3: Implement MenuBarReader**

```swift
// ShortcutDic/Services/MenuBarReader.swift
import AppKit
import ApplicationServices

final class MenuBarReader {

    private var cache: [String: CacheEntry] = [:]
    private let cacheDuration: TimeInterval = 5.0 // seconds

    private struct CacheEntry {
        let shortcuts: AppShortcuts
        let timestamp: Date
    }

    func isCached(bundleId: String) -> Bool {
        guard let entry = cache[bundleId] else { return false }
        return Date().timeIntervalSince(entry.timestamp) < cacheDuration
    }

    func clearCache() {
        cache.removeAll()
    }

    /// Read all menu bar shortcuts for the given application
    func readShortcuts(for pid: pid_t, appName: String, bundleId: String) async -> AppShortcuts? {
        // Return cache if fresh
        if let entry = cache[bundleId], Date().timeIntervalSince(entry.timestamp) < cacheDuration {
            return entry.shortcuts
        }

        // Read on background thread (AX calls can be slow)
        let result = await Task.detached(priority: .userInitiated) { [weak self] () -> AppShortcuts? in
            self?.readMenuBar(pid: pid, appName: appName, bundleId: bundleId)
        }.value

        if let result {
            cache[bundleId] = CacheEntry(shortcuts: result, timestamp: Date())
        }
        return result
    }

    private func readMenuBar(pid: pid_t, appName: String, bundleId: String) -> AppShortcuts? {
        let appElement = AXUIElementCreateApplication(pid)

        var menuBarValue: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarValue)
        guard menuBarResult == .success, let menuBar = menuBarValue else {
            return nil
        }

        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenValue)
        guard childrenResult == .success, let children = childrenValue as? [AXUIElement] else {
            return nil
        }

        var groups: [ShortcutGroup] = []

        for menuElement in children {
            guard let menuName = getStringAttribute(menuElement, kAXTitleAttribute) else { continue }

            // Skip the Apple menu
            if menuName.isEmpty || menuName == "Apple" { continue }

            var shortcuts: [Shortcut] = []
            readMenuItems(menuElement, menuPath: menuName, into: &shortcuts)

            if !shortcuts.isEmpty {
                groups.append(ShortcutGroup(menuName: menuName, shortcuts: shortcuts))
            }
        }

        return AppShortcuts(appName: appName, bundleIdentifier: bundleId, groups: groups)
    }

    private func readMenuItems(_ element: AXUIElement, menuPath: String, into shortcuts: inout [Shortcut]) {
        // Get the submenu children
        var submenuValue: CFTypeRef?
        var children: [AXUIElement] = []

        // Try getting children directly (for menu bar items, the children are in a submenu)
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &submenuValue) == .success,
           let submenuChildren = submenuValue as? [AXUIElement] {
            for child in submenuChildren {
                // Each child might be a menu, get its children
                var menuChildren: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &menuChildren) == .success,
                   let items = menuChildren as? [AXUIElement] {
                    children.append(contentsOf: items)
                }
            }
        }

        for item in children {
            // Check for keyboard shortcut
            if let cmdChar = getStringAttribute(item, kAXMenuItemCmdCharAttribute as String),
               let title = getStringAttribute(item, kAXTitleAttribute),
               !cmdChar.isEmpty, !title.isEmpty {

                var modifiersValue: CFTypeRef?
                var modifiers: NSEvent.ModifierFlags = .command // default: ⌘ is always present

                if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdModifiersAttribute as CFString, &modifiersValue) == .success,
                   let modNum = modifiersValue as? Int {
                    modifiers = Self.convertAXModifiers(UInt64(modNum))
                }

                shortcuts.append(Shortcut(
                    title: title,
                    keyEquivalent: cmdChar,
                    modifiers: modifiers,
                    menuPath: menuPath
                ))
            }

            // Recurse into submenus
            var subChildren: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &subChildren) == .success,
               let subItems = subChildren as? [AXUIElement], !subItems.isEmpty {
                readMenuItems(item, menuPath: menuPath, into: &shortcuts)
            }
        }
    }

    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    /// Convert AX modifier flags to NSEvent.ModifierFlags
    /// kAXMenuItemCmdModifiers: 0 = ⌘ only, bit flags for shift/option/control
    static func convertAXModifiers(_ axModifiers: UInt64) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = .command // ⌘ is always implied

        // AX modifier bit values
        if axModifiers & UInt64(kCGEventFlagMaskShift.rawValue >> 16) != 0 {
            flags.insert(.shift)
        }
        if axModifiers & UInt64(kCGEventFlagMaskAlternate.rawValue >> 16) != 0 {
            flags.insert(.option)
        }
        if axModifiers & UInt64(kCGEventFlagMaskControl.rawValue >> 16) != 0 {
            flags.insert(.control)
        }
        // If kAXMenuItemCmdModifiersAttribute has bit 4 set, no ⌘
        if axModifiers & (1 << 3) != 0 {
            flags.remove(.command)
        }

        return flags
    }
}
```

**Step 4: Run tests**

Run: `xcodebuild test -project ShortcutDic.xcodeproj -scheme ShortcutDicTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: Tests PASS (cache/conversion tests pass; Finder test may skip if no accessibility permission in CI)

**Step 5: Commit**

```bash
git add ShortcutDic/Services/MenuBarReader.swift ShortcutDicTests/Services/MenuBarReaderTests.swift
git commit -m "feat: add menu bar shortcut reader with caching"
```

---

### Task 5: KeyMonitor Service

**Files:**
- Create: `ShortcutDic/Services/KeyMonitor.swift`
- Create: `ShortcutDicTests/Services/KeyMonitorTests.swift`

**Step 1: Write tests for timer logic**

```swift
// ShortcutDicTests/Services/KeyMonitorTests.swift
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
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project ShortcutDic.xcodeproj -scheme ShortcutDicTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: FAIL — `KeyMonitor` not defined

**Step 3: Implement KeyMonitor**

```swift
// ShortcutDic/Services/KeyMonitor.swift
import AppKit
import Combine

final class KeyMonitor: ObservableObject {

    @Published var isModifierHeld = false
    @Published var activeModifier: NSEvent.ModifierFlags?

    var longPressThreshold: TimeInterval
    var excludedBundleIds: Set<String> = []

    /// Callbacks
    var onLongPress: ((NSEvent.ModifierFlags) -> Void)?
    var onRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressTimer: Timer?
    private var currentFlags: NSEvent.ModifierFlags = []

    init(longPressThreshold: TimeInterval = 0.5) {
        self.longPressThreshold = longPressThreshold
    }

    deinit {
        stop()
    }

    func isExcluded(bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return excludedBundleIds.contains(bundleId)
    }

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        // Note: self pointer passed via Unmanaged
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handleFlagsChanged(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        pressTimer?.invalidate()
        pressTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        let modifierOnly = flags.intersection([.command, .option, .control])

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Check if in excluded app
            if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               self.isExcluded(bundleId: bundleId) {
                return
            }

            if !modifierOnly.isEmpty && self.currentFlags.isEmpty {
                // Modifier pressed — start timer
                self.currentFlags = modifierOnly
                self.pressTimer?.invalidate()
                self.pressTimer = Timer.scheduledTimer(withTimeInterval: self.longPressThreshold, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.isModifierHeld = true
                    self.activeModifier = self.currentFlags
                    self.onLongPress?(self.currentFlags)
                }
            } else if modifierOnly.isEmpty && !self.currentFlags.isEmpty {
                // Modifier released
                self.pressTimer?.invalidate()
                self.pressTimer = nil
                self.currentFlags = []

                if self.isModifierHeld {
                    self.isModifierHeld = false
                    self.activeModifier = nil
                    self.onRelease?()
                }
            } else if modifierOnly != self.currentFlags {
                // Different modifier pressed — restart
                self.pressTimer?.invalidate()
                self.currentFlags = modifierOnly
                if self.isModifierHeld {
                    self.isModifierHeld = false
                    self.activeModifier = nil
                    self.onRelease?()
                }
                self.pressTimer = Timer.scheduledTimer(withTimeInterval: self.longPressThreshold, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.isModifierHeld = true
                    self.activeModifier = self.currentFlags
                    self.onLongPress?(self.currentFlags)
                }
            }
        }
    }
}
```

**Step 4: Run tests**

Run: `xcodebuild test -project ShortcutDic.xcodeproj -scheme ShortcutDicTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add ShortcutDic/Services/KeyMonitor.swift ShortcutDicTests/Services/KeyMonitorTests.swift
git commit -m "feat: add CGEventTap-based modifier key long-press monitor"
```

---

### Task 6: Usage Tracker Service

**Files:**
- Create: `ShortcutDic/Services/UsageTracker.swift`
- Create: `ShortcutDicTests/Services/UsageTrackerTests.swift`

**Step 1: Write tests**

```swift
// ShortcutDicTests/Services/UsageTrackerTests.swift
import XCTest
@testable import ShortcutDic

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
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project ShortcutDic.xcodeproj -scheme ShortcutDicTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: FAIL — `UsageTracker` not defined

**Step 3: Implement UsageTracker**

```swift
// ShortcutDic/Services/UsageTracker.swift
import AppKit

final class UsageTracker {

    struct UsageEntry: Codable {
        let keyEquivalent: String
        let modifiersRawValue: UInt
        var count: Int
    }

    struct TopEntry {
        let keyEquivalent: String
        let modifiers: NSEvent.ModifierFlags
        let count: Int
    }

    /// bundleId -> [shortcutKey -> UsageEntry]
    /// shortcutKey = "\(modifiersRaw)_\(keyEquivalent)"
    private var data: [String: [String: UsageEntry]] = [:]
    private let storageURL: URL

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        load()
    }

    static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ShortcutDic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("usage.json")
    }

    func record(bundleId: String, keyEquivalent: String, modifiers: NSEvent.ModifierFlags) {
        let key = "\(modifiers.rawValue)_\(keyEquivalent)"
        if data[bundleId] == nil {
            data[bundleId] = [:]
        }
        if var entry = data[bundleId]?[key] {
            entry.count += 1
            data[bundleId]?[key] = entry
        } else {
            data[bundleId]?[key] = UsageEntry(
                keyEquivalent: keyEquivalent,
                modifiersRawValue: modifiers.rawValue,
                count: 1
            )
        }
        save()
    }

    func topShortcuts(for bundleId: String, limit: Int) -> [TopEntry] {
        guard let appData = data[bundleId] else { return [] }
        return appData.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { TopEntry(
                keyEquivalent: $0.keyEquivalent,
                modifiers: NSEvent.ModifierFlags(rawValue: $0.modifiersRawValue),
                count: $0.count
            ) }
    }

    func save() {
        guard let jsonData = try? JSONEncoder().encode(data) else { return }
        try? jsonData.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let jsonData = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: [String: UsageEntry]].self, from: jsonData) else {
            return
        }
        data = decoded
    }
}
```

**Step 4: Run tests**

Run: `xcodebuild test -project ShortcutDic.xcodeproj -scheme ShortcutDicTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add ShortcutDic/Services/UsageTracker.swift ShortcutDicTests/Services/UsageTrackerTests.swift
git commit -m "feat: add shortcut usage frequency tracker with persistence"
```

---

### Task 7: Overlay Panel (NSPanel wrapper)

**Files:**
- Create: `ShortcutDic/Views/OverlayPanel.swift`

**Step 1: Implement the NSPanel-based overlay**

No unit test — UI component requiring visual verification. Will be tested in integration.

```swift
// ShortcutDic/Views/OverlayPanel.swift
import SwiftUI
import AppKit

final class OverlayPanel: NSPanel {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Don't show in mission control / window list
        isExcludedFromWindowsMenu = true
    }

    /// Show the panel with the given SwiftUI view
    func showOverlay<V: View>(_ view: V, at position: PanelPosition) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame.size = hostingView.fittingSize

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        visualEffect.frame.size = hostingView.fittingSize
        hostingView.frame.origin = .zero
        visualEffect.addSubview(hostingView)

        contentView = visualEffect
        setContentSize(hostingView.fittingSize)
        positionOnScreen(position)

        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1
        }
    }

    func hideOverlay() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    private func positionOnScreen(_ position: PanelPosition) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = frame.size

        // Cap at 80% of screen
        let maxW = screenFrame.width * 0.8
        let maxH = screenFrame.height * 0.8
        if panelSize.width > maxW || panelSize.height > maxH {
            setContentSize(NSSize(
                width: min(panelSize.width, maxW),
                height: min(panelSize.height, maxH)
            ))
        }

        let origin: NSPoint
        switch position {
        case .center:
            origin = NSPoint(
                x: screenFrame.midX - frame.width / 2,
                y: screenFrame.midY - frame.height / 2
            )
        case .topLeft:
            origin = NSPoint(
                x: screenFrame.minX + 20,
                y: screenFrame.maxY - frame.height - 20
            )
        case .topRight:
            origin = NSPoint(
                x: screenFrame.maxX - frame.width - 20,
                y: screenFrame.maxY - frame.height - 20
            )
        case .bottomLeft:
            origin = NSPoint(
                x: screenFrame.minX + 20,
                y: screenFrame.minY + 20
            )
        case .bottomRight:
            origin = NSPoint(
                x: screenFrame.maxX - frame.width - 20,
                y: screenFrame.minY + 20
            )
        }
        setFrameOrigin(origin)
    }
}

enum PanelPosition: String, CaseIterable, Codable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"

    var localizedName: String { rawValue }
}
```

**Step 2: Verify build**

Run: `xcodebuild -project ShortcutDic.xcodeproj -scheme ShortcutDic -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ShortcutDic/Views/OverlayPanel.swift
git commit -m "feat: add HUD overlay panel with positioning and animations"
```

---

### Task 8: Shortcut Grid View (SwiftUI)

**Files:**
- Create: `ShortcutDic/Views/ShortcutGridView.swift`

**Step 1: Implement the shortcut grid view**

```swift
// ShortcutDic/Views/ShortcutGridView.swift
import SwiftUI

struct ShortcutGridView: View {
    let appShortcuts: AppShortcuts
    let frequentShortcuts: [Shortcut]
    let modifierLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(appShortcuts.appName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(modifierLabel + " held")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 4)

            Divider().background(Color.gray.opacity(0.5))

            // Frequently used section
            if !frequentShortcuts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("★ Frequently Used")
                        .font(.caption)
                        .foregroundColor(.yellow)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140), spacing: 8)
                    ], spacing: 4) {
                        ForEach(frequentShortcuts) { shortcut in
                            ShortcutRow(shortcut: shortcut)
                        }
                    }
                }

                Divider().background(Color.gray.opacity(0.5))
            }

            // Menu groups in columns
            let columns = distributeGroups(appShortcuts.groups, targetColumns: 3)

            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(column) { group in
                            GroupSection(group: group)
                        }
                    }
                    .frame(minWidth: 160)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Distribute groups across N columns, balancing by shortcut count
    private func distributeGroups(_ groups: [ShortcutGroup], targetColumns: Int) -> [[ShortcutGroup]] {
        guard !groups.isEmpty else { return [] }
        let columnCount = min(targetColumns, groups.count)
        var columns = Array(repeating: [ShortcutGroup](), count: columnCount)
        var heights = Array(repeating: 0, count: columnCount)

        for group in groups {
            // Add to shortest column
            let minIndex = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[minIndex].append(group)
            heights[minIndex] += group.shortcuts.count + 2 // +2 for header
        }

        return columns
    }
}

struct GroupSection: View {
    let group: ShortcutGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.menuName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)

            ForEach(group.shortcuts) { shortcut in
                ShortcutRow(shortcut: shortcut)
            }
        }
    }
}

struct ShortcutRow: View {
    let shortcut: Shortcut

    var body: some View {
        HStack(spacing: 6) {
            Text(shortcut.displayString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.cyan)
                .frame(width: 50, alignment: .leading)

            Text(shortcut.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()
        }
    }
}
```

**Step 2: Verify build**

Run: `xcodebuild -project ShortcutDic.xcodeproj -scheme ShortcutDic -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ShortcutDic/Views/ShortcutGridView.swift
git commit -m "feat: add shortcut grid view with frequency section and multi-column layout"
```

---

### Task 9: Settings View & Persistence

**Files:**
- Create: `ShortcutDic/Views/SettingsView.swift`
- Create: `ShortcutDic/Models/AppSettings.swift`

**Step 1: Implement AppSettings**

```swift
// ShortcutDic/Models/AppSettings.swift
import Foundation
import ServiceManagement

final class AppSettings: ObservableObject {

    @Published var panelPosition: PanelPosition {
        didSet { UserDefaults.standard.set(panelPosition.rawValue, forKey: "panelPosition") }
    }
    @Published var longPressDelay: Double {
        didSet { UserDefaults.standard.set(longPressDelay, forKey: "longPressDelay") }
    }
    @Published var disableInGames: Bool {
        didSet { UserDefaults.standard.set(disableInGames, forKey: "disableInGames") }
    }
    @Published var excludedBundleIds: [String] {
        didSet { UserDefaults.standard.set(excludedBundleIds, forKey: "excludedBundleIds") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    init() {
        let defaults = UserDefaults.standard
        self.panelPosition = PanelPosition(rawValue: defaults.string(forKey: "panelPosition") ?? "") ?? .center
        self.longPressDelay = defaults.double(forKey: "longPressDelay") != 0
            ? defaults.double(forKey: "longPressDelay") : 0.5
        self.disableInGames = defaults.object(forKey: "disableInGames") as? Bool ?? true
        self.excludedBundleIds = defaults.stringArray(forKey: "excludedBundleIds") ?? []
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}
```

**Step 2: Implement SettingsView**

```swift
// ShortcutDic/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            // Accessibility status
            Section("Accessibility") {
                HStack {
                    Circle()
                        .fill(AccessibilityHelper.isTrusted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(AccessibilityHelper.isTrusted ? "Permission Granted" : "Permission Required")

                    Spacer()

                    if !AccessibilityHelper.isTrusted {
                        Button("Grant Access") {
                            AccessibilityHelper.openAccessibilitySettings()
                        }
                    }
                }
            }

            // Panel
            Section("Panel") {
                Picker("Position", selection: $settings.panelPosition) {
                    ForEach(PanelPosition.allCases, id: \.self) { pos in
                        Text(pos.localizedName).tag(pos)
                    }
                }

                HStack {
                    Text("Trigger Delay")
                    Slider(value: $settings.longPressDelay, in: 0.3...1.0, step: 0.1)
                    Text("\(settings.longPressDelay, specifier: "%.1f")s")
                        .monospacedDigit()
                        .frame(width: 30)
                }
            }

            // Exclusions
            Section("Exclusions") {
                Toggle("Disable in games", isOn: $settings.disableInGames)

                VStack(alignment: .leading) {
                    Text("Excluded Apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(settings.excludedBundleIds, id: \.self) { bundleId in
                        HStack {
                            Text(bundleId)
                                .font(.caption)
                            Spacer()
                            Button(role: .destructive) {
                                settings.excludedBundleIds.removeAll { $0 == bundleId }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // General
            Section("General") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
    }
}
```

**Step 3: Verify build**

Run: `xcodebuild -project ShortcutDic.xcodeproj -scheme ShortcutDic -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ShortcutDic/Models/AppSettings.swift ShortcutDic/Views/SettingsView.swift
git commit -m "feat: add settings view with position, delay, exclusions, and launch-at-login"
```

---

### Task 10: App Controller — Wire Everything Together

**Files:**
- Create: `ShortcutDic/Services/AppController.swift`
- Modify: `ShortcutDic/ShortcutDicApp.swift`

**Step 1: Implement AppController (orchestrator)**

```swift
// ShortcutDic/Services/AppController.swift
import AppKit
import Combine

@MainActor
final class AppController: ObservableObject {

    let settings = AppSettings()
    let keyMonitor: KeyMonitor
    let menuBarReader = MenuBarReader()
    let usageTracker: UsageTracker
    let overlayPanel = OverlayPanel()

    @Published var isShowingPanel = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.keyMonitor = KeyMonitor(longPressThreshold: settings.longPressDelay)
        self.usageTracker = UsageTracker()

        setupBindings()
    }

    func start() {
        guard AccessibilityHelper.isTrusted else {
            AccessibilityHelper.promptForPermission()
            return
        }
        keyMonitor.start()
    }

    private func setupBindings() {
        // Sync settings → key monitor
        settings.$longPressDelay
            .sink { [weak self] delay in
                self?.keyMonitor.longPressThreshold = delay
            }
            .store(in: &cancellables)

        settings.$excludedBundleIds
            .sink { [weak self] ids in
                self?.keyMonitor.excludedBundleIds = Set(ids)
            }
            .store(in: &cancellables)

        // Long press → show panel
        keyMonitor.onLongPress = { [weak self] modifier in
            Task { @MainActor [weak self] in
                await self?.showPanel(for: modifier)
            }
        }

        // Release → hide panel
        keyMonitor.onRelease = { [weak self] in
            Task { @MainActor [weak self] in
                self?.hidePanel()
            }
        }
    }

    private func showPanel(for modifier: NSEvent.ModifierFlags) async {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else { return }

        // Check game exclusion
        if settings.disableInGames && isGameApp(bundleId: bundleId) {
            return
        }

        let appName = frontApp.localizedName ?? "Unknown"
        guard let shortcuts = await menuBarReader.readShortcuts(
            for: frontApp.processIdentifier,
            appName: appName,
            bundleId: bundleId
        ) else { return }

        let filtered = shortcuts.filtered(by: modifier)
        guard !filtered.groups.isEmpty else { return }

        // Get frequent shortcuts
        let topUsage = usageTracker.topShortcuts(for: bundleId, limit: 6)
        let frequentShortcuts = topUsage.compactMap { entry -> Shortcut? in
            // Match usage entry to actual shortcut from menu
            for group in filtered.groups {
                if let match = group.shortcuts.first(where: {
                    $0.keyEquivalent.lowercased() == entry.keyEquivalent.lowercased() &&
                    $0.modifiers == entry.modifiers
                }) {
                    return match
                }
            }
            return nil
        }

        let modifierLabel = modifierSymbol(modifier)
        let view = ShortcutGridView(
            appShortcuts: filtered,
            frequentShortcuts: frequentShortcuts,
            modifierLabel: modifierLabel
        )

        overlayPanel.showOverlay(view, at: settings.panelPosition)
        isShowingPanel = true
    }

    private func hidePanel() {
        overlayPanel.hideOverlay()
        isShowingPanel = false
    }

    private func modifierSymbol(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    private func isGameApp(bundleId: String) -> Bool {
        // Check user exclusion list first
        if settings.excludedBundleIds.contains(bundleId) { return true }

        // Check if app is categorized as a game via Launch Services
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
              let bundle = Bundle(url: url),
              let category = bundle.infoDictionary?["LSApplicationCategoryType"] as? String else {
            return false
        }
        return category.contains("games")
    }
}
```

**Step 2: Update ShortcutDicApp.swift to use AppController**

Replace entire contents of `ShortcutDic/ShortcutDicApp.swift`:

```swift
// ShortcutDic/ShortcutDicApp.swift
import SwiftUI

@main
struct ShortcutDicApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: controller)
        } label: {
            Image(systemName: "keyboard")
        }

        Settings {
            SettingsView(settings: controller.settings)
        }
    }
}

struct MenuBarContent: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack {
            HStack {
                Circle()
                    .fill(AccessibilityHelper.isTrusted ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(AccessibilityHelper.isTrusted ? "Running" : "Needs Permission")
            }

            Divider()

            if !AccessibilityHelper.isTrusted {
                Button("Grant Accessibility Access") {
                    AccessibilityHelper.promptForPermission()
                }
            }

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit ShortcutDic") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .onAppear {
            controller.start()
        }
    }
}
```

**Step 3: Verify build**

Run: `xcodebuild -project ShortcutDic.xcodeproj -scheme ShortcutDic -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ShortcutDic/Services/AppController.swift ShortcutDic/ShortcutDicApp.swift
git commit -m "feat: wire all components together via AppController"
```

---

### Task 11: Manual Integration Test & Polish

**Step 1: Build and run the app**

Run: `xcodebuild -project ShortcutDic.xcodeproj -scheme ShortcutDic -destination 'platform=macOS' build 2>&1 | tail -5`

**Step 2: Manual test checklist**

Run the built app from `build/Release/ShortcutDic.app` or via Xcode:

- [ ] Menu bar icon appears (keyboard icon)
- [ ] Clicking icon shows menu with status, settings, quit
- [ ] Granting accessibility permission works
- [ ] Long-press ⌘ for 0.5s shows HUD panel with Finder shortcuts
- [ ] Releasing ⌘ hides the panel with fade animation
- [ ] Panel shows shortcuts grouped by menu name
- [ ] Settings window opens with all options
- [ ] Changing panel position works
- [ ] Changing delay works
- [ ] Launch at login toggle works
- [ ] Switching to different app shows that app's shortcuts

**Step 3: Fix any build/runtime issues found**

Address compiler errors, layout issues, or logic bugs discovered during manual testing.

**Step 4: Commit**

```bash
git add -A
git commit -m "fix: polish and integration fixes"
```

---

### Task 12: Add .gitignore & Final Cleanup

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore**

```gitignore
# Xcode
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.xccheckout
*.moved-aside
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# macOS
.DS_Store
*.swp
*~

# Swift Package Manager
.build/
Packages/
Package.resolved
```

**Step 2: Remove .gitkeep files (directories now have real files)**

Run: `find . -name '.gitkeep' -delete`

**Step 3: Commit**

```bash
git add .gitignore
git rm --cached -r '*.gitkeep' 2>/dev/null; true
git commit -m "chore: add gitignore and clean up"
```

---

## Task Dependency Summary

```
Task 1 (scaffold) ← Task 2 (models) ← Task 4 (menu reader)
                   ← Task 3 (a11y)   ← Task 5 (key monitor)
                                      ← Task 6 (usage tracker)
                                      ← Task 7 (overlay panel)
                                      ← Task 8 (grid view)
                                      ← Task 9 (settings)
                                      ← Task 10 (wire together)
                                      ← Task 11 (integration test)
                                      ← Task 12 (cleanup)
```

Tasks 3-9 can be done in any order after Task 2, but Task 10 depends on all of them. Tasks 2-9 are parallelizable in pairs.
