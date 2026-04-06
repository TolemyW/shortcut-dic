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
