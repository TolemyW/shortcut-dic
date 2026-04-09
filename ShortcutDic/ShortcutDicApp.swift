import SwiftUI

@main
struct ShortcutDicApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: controller)
        } label: {
            Image("MenuBarIcon")
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

            SettingsLink()
                .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit ShortcutDic") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
