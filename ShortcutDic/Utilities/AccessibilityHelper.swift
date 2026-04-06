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
