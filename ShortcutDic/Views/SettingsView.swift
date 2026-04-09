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

            Section("Trigger") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monitor Modifier Keys")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 16) {
                        Toggle("⌘ Command", isOn: $settings.monitorCommand)
                        Toggle("⌥ Option", isOn: $settings.monitorOption)
                        Toggle("⌃ Control", isOn: $settings.monitorControl)
                    }
                }

                HotkeyRecorderView(hotkey: $settings.globalHotkey)

                HStack {
                    Text("Long Press Delay")
                    Slider(value: $settings.longPressDelay, in: 0.3...1.0, step: 0.1)
                    Text("\(settings.longPressDelay, specifier: "%.1f")s")
                        .monospacedDigit()
                        .frame(width: 30)
                }

                HStack {
                    Text("Double-Tap Window")
                    Slider(value: $settings.doubleTapWindow, in: 0.2...0.5, step: 0.05)
                    Text("\(settings.doubleTapWindow, specifier: "%.2f")s")
                        .monospacedDigit()
                        .frame(width: 38)
                }
            }

            Section("Appearance") {
                ColorSettingRow(label: "Shortcut Key Color", color: $settings.keyColor)
                ColorSettingRow(label: "Title Color", color: $settings.titleColor)
                ColorSettingRow(label: "Label Color", color: $settings.labelColor)
                ColorSettingRow(label: "Accent Color", color: $settings.accentColor)

                Toggle("Adapt to Dark/Light Mode", isOn: $settings.adaptToDarkMode)

                HStack {
                    Text("Panel Opacity")
                    Slider(value: $settings.panelOpacity, in: 0.3...1.0, step: 0.05)
                    Text("\(Int(settings.panelOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 35)
                }

                HStack {
                    Text("Font Size")
                    Slider(value: $settings.fontSize, in: 9...20, step: 1)
                    Text("\(Int(settings.fontSize))pt")
                        .monospacedDigit()
                        .frame(width: 35)
                }

                Picker("Position", selection: $settings.panelPosition) {
                    ForEach(PanelPosition.allCases, id: \.self) { pos in
                        Text(pos.localizedName).tag(pos)
                    }
                }
            }

            Section("Display") {
                Stepper("Items per Group: \(settings.maxPerGroup)",
                        value: $settings.maxPerGroup, in: 3...20)
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
        .frame(width: 480, height: 640)
    }
}

/// A row with a label and a system color picker.
struct ColorSettingRow: View {
    let label: String
    @Binding var color: StorableColor

    @State private var pickerColor: Color = .white

    var body: some View {
        ColorPicker(label, selection: $pickerColor, supportsOpacity: false)
            .onAppear { pickerColor = color.color }
            .onChange(of: pickerColor) { _, newValue in
                if let nsColor = NSColor(newValue).usingColorSpace(.sRGB) {
                    color = StorableColor(nsColor)
                }
            }
    }
}
