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
