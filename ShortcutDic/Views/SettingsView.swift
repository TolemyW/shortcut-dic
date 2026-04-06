import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
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

            Section("General") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
    }
}
