import AppKit
import ApplicationServices
import os.log

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ShortcutDic", category: "MenuBarReader")

@MainActor
final class MenuBarReader {

    private var cache: [String: CacheEntry] = [:]
    private let cacheDuration: TimeInterval = 5.0

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

    func readShortcuts(for pid: pid_t, appName: String, bundleId: String) async -> AppShortcuts? {
        if let entry = cache[bundleId], Date().timeIntervalSince(entry.timestamp) < cacheDuration {
            return entry.shortcuts
        }

        let result = await Task.detached(priority: .userInitiated) { [weak self] () -> AppShortcuts? in
            self?.readMenuBar(pid: pid, appName: appName, bundleId: bundleId)
        }.value

        if let result {
            cache[bundleId] = CacheEntry(shortcuts: result, timestamp: Date())
        }
        return result
    }

    private nonisolated func readMenuBar(pid: pid_t, appName: String, bundleId: String) -> AppShortcuts? {
        let appElement = AXUIElementCreateApplication(pid)

        var menuBarValue: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarValue)
        guard menuBarResult == .success, let menuBar = menuBarValue else {
            log.warning("Failed to get menu bar for \(appName) (pid \(pid)): AXError \(menuBarResult.rawValue)")
            return nil
        }

        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenValue)
        guard childrenResult == .success, let children = childrenValue as? [AXUIElement] else {
            log.warning("Failed to get menu bar children for \(appName): AXError \(childrenResult.rawValue)")
            return nil
        }

        var groups: [ShortcutGroup] = []

        for menuElement in children {
            guard let menuName = getStringAttribute(menuElement, kAXTitleAttribute) else { continue }
            if menuName.isEmpty || menuName == "Apple" { continue }

            var shortcuts: [Shortcut] = []
            readMenuItems(menuElement, menuPath: menuName, into: &shortcuts)

            if !shortcuts.isEmpty {
                groups.append(ShortcutGroup(menuName: menuName, shortcuts: shortcuts))
            }
        }

        log.info("Read \(groups.count) menu groups with shortcuts for \(appName)")
        return AppShortcuts(appName: appName, bundleIdentifier: bundleId, groups: groups)
    }

    private nonisolated func readMenuItems(_ element: AXUIElement, menuPath: String, into shortcuts: inout [Shortcut]) {
        var submenuValue: CFTypeRef?
        var children: [AXUIElement] = []

        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &submenuValue) == .success,
           let submenuChildren = submenuValue as? [AXUIElement] {
            for child in submenuChildren {
                var menuChildren: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &menuChildren) == .success,
                   let items = menuChildren as? [AXUIElement] {
                    children.append(contentsOf: items)
                }
            }
        }

        for item in children {
            if let cmdChar = getStringAttribute(item, kAXMenuItemCmdCharAttribute as String),
               let title = getStringAttribute(item, kAXTitleAttribute),
               !cmdChar.isEmpty, !title.isEmpty {

                var modifiersValue: CFTypeRef?
                var modifiers: NSEvent.ModifierFlags = .command

                var axModRaw: Int = 0
                if AXUIElementCopyAttributeValue(item, kAXMenuItemCmdModifiersAttribute as CFString, &modifiersValue) == .success,
                   let modNum = modifiersValue as? Int {
                    axModRaw = modNum
                    modifiers = Self.convertAXModifiers(modNum)
                }

                log.info("  \(menuPath) > \(title): key='\(cmdChar)' axMod=\(axModRaw) → flags=\(modifiers.rawValue)")

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

    private nonisolated func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    /// Convert AX modifier flags to NSEvent.ModifierFlags.
    /// kAXMenuItemCmdModifiers bit values: 0=⌘only, 1=shift, 2=option, 4=control, 8=no-⌘
    nonisolated static func convertAXModifiers(_ axModifiers: Int) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = .command

        if axModifiers & 1 != 0 { flags.insert(.shift) }
        if axModifiers & 2 != 0 { flags.insert(.option) }
        if axModifiers & 4 != 0 { flags.insert(.control) }
        if axModifiers & 8 != 0 { flags.remove(.command) }

        return flags
    }
}
