import Foundation
import AppKit
import SwiftUI
import ServiceManagement

/// Codable wrapper for NSColor stored as hex string.
struct StorableColor: Codable, Equatable {
    var hex: String

    init(_ hex: String) { self.hex = hex }

    init(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        self.hex = String(format: "#%02X%02X%02X",
                          Int(c.redComponent * 255),
                          Int(c.greenComponent * 255),
                          Int(c.blueComponent * 255))
    }

    var nsColor: NSColor {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return .white }
        return NSColor(red: CGFloat((val >> 16) & 0xFF) / 255,
                       green: CGFloat((val >> 8) & 0xFF) / 255,
                       blue: CGFloat(val & 0xFF) / 255,
                       alpha: 1)
    }

    var color: Color { Color(nsColor) }
}

/// Stored representation of a global hotkey.
struct HotkeyCombo: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt  // NSEvent.ModifierFlags.rawValue

    var displayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyString = KeyCodeNames.name(for: keyCode)
        parts.append(keyString)
        return parts.joined(separator: " ")
    }
}

enum KeyCodeNames {
    static func name(for keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x30: "Tab", 0x31: "Space", 0x32: "`",
            0x24: "Return", 0x33: "Delete", 0x35: "Esc",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }
}

final class AppSettings: ObservableObject {

    // MARK: - Panel

    @Published var panelPosition: PanelPosition {
        didSet { UserDefaults.standard.set(panelPosition.rawValue, forKey: "panelPosition") }
    }

    // MARK: - Trigger

    @Published var longPressDelay: Double {
        didSet { UserDefaults.standard.set(longPressDelay, forKey: "longPressDelay") }
    }
    @Published var doubleTapWindow: Double {
        didSet { UserDefaults.standard.set(doubleTapWindow, forKey: "doubleTapWindow") }
    }
    @Published var monitorCommand: Bool {
        didSet { UserDefaults.standard.set(monitorCommand, forKey: "monitorCommand") }
    }
    @Published var monitorOption: Bool {
        didSet { UserDefaults.standard.set(monitorOption, forKey: "monitorOption") }
    }
    @Published var monitorControl: Bool {
        didSet { UserDefaults.standard.set(monitorControl, forKey: "monitorControl") }
    }
    @Published var globalHotkey: HotkeyCombo? {
        didSet {
            if let combo = globalHotkey {
                if let data = try? JSONEncoder().encode(combo) {
                    UserDefaults.standard.set(data, forKey: "globalHotkey")
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "globalHotkey")
            }
        }
    }

    var monitoredModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if monitorCommand { flags.insert(.command) }
        if monitorOption { flags.insert(.option) }
        if monitorControl { flags.insert(.control) }
        return flags
    }

    // MARK: - Appearance

    @Published var keyColor: StorableColor {
        didSet { saveColor(keyColor, forKey: "keyColor") }
    }
    @Published var titleColor: StorableColor {
        didSet { saveColor(titleColor, forKey: "titleColor") }
    }
    @Published var labelColor: StorableColor {
        didSet { saveColor(labelColor, forKey: "labelColor") }
    }
    @Published var accentColor: StorableColor {
        didSet { saveColor(accentColor, forKey: "accentColor") }
    }
    @Published var adaptToDarkMode: Bool {
        didSet { UserDefaults.standard.set(adaptToDarkMode, forKey: "adaptToDarkMode") }
    }
    @Published var panelOpacity: Double {
        didSet { UserDefaults.standard.set(panelOpacity, forKey: "panelOpacity") }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    @Published var maxPerGroup: Int {
        didSet { UserDefaults.standard.set(maxPerGroup, forKey: "maxPerGroup") }
    }

    private func saveColor(_ c: StorableColor, forKey key: String) {
        UserDefaults.standard.set(c.hex, forKey: key)
    }
    private static func loadColor(_ key: String, default hex: String) -> StorableColor {
        StorableColor(UserDefaults.standard.string(forKey: key) ?? hex)
    }

    // MARK: - Exclusions

    @Published var disableInGames: Bool {
        didSet { UserDefaults.standard.set(disableInGames, forKey: "disableInGames") }
    }
    @Published var excludedBundleIds: [String] {
        didSet { UserDefaults.standard.set(excludedBundleIds, forKey: "excludedBundleIds") }
    }

    // MARK: - General

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        self.panelPosition = PanelPosition(rawValue: defaults.string(forKey: "panelPosition") ?? "") ?? .center
        self.longPressDelay = defaults.double(forKey: "longPressDelay") != 0
            ? defaults.double(forKey: "longPressDelay") : 0.5
        self.doubleTapWindow = defaults.double(forKey: "doubleTapWindow") != 0
            ? defaults.double(forKey: "doubleTapWindow") : 0.3
        self.monitorCommand = defaults.object(forKey: "monitorCommand") as? Bool ?? true
        self.monitorOption = defaults.object(forKey: "monitorOption") as? Bool ?? true
        self.monitorControl = defaults.object(forKey: "monitorControl") as? Bool ?? true
        if let data = defaults.data(forKey: "globalHotkey"),
           let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            self.globalHotkey = combo
        } else {
            self.globalHotkey = nil
        }
        self.keyColor = Self.loadColor("keyColor", default: "#00CCCC")
        self.titleColor = Self.loadColor("titleColor", default: "#FFFFFF")
        self.labelColor = Self.loadColor("labelColor", default: "#888888")
        self.accentColor = Self.loadColor("accentColor", default: "#FFCC00")
        self.adaptToDarkMode = defaults.object(forKey: "adaptToDarkMode") as? Bool ?? true
        self.panelOpacity = defaults.double(forKey: "panelOpacity") != 0
            ? defaults.double(forKey: "panelOpacity") : 0.95
        self.fontSize = defaults.double(forKey: "fontSize") != 0
            ? defaults.double(forKey: "fontSize") : 13
        self.maxPerGroup = defaults.integer(forKey: "maxPerGroup") != 0
            ? defaults.integer(forKey: "maxPerGroup") : 5
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
