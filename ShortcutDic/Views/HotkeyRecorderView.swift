import SwiftUI
import AppKit

struct HotkeyRecorderView: View {
    @Binding var hotkey: HotkeyCombo?
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text("Global Hotkey")

            Spacer()

            Button {
                if isRecording {
                    isRecording = false
                } else {
                    isRecording = true
                }
            } label: {
                if isRecording {
                    Text("Press keys...")
                        .foregroundColor(.orange)
                        .frame(minWidth: 120)
                } else if let hotkey {
                    Text(hotkey.displayString)
                        .frame(minWidth: 120)
                } else {
                    Text("Click to record")
                        .foregroundColor(.secondary)
                        .frame(minWidth: 120)
                }
            }
            .background(
                HotkeyRecorderHelper(isRecording: $isRecording, hotkey: $hotkey)
            )

            if hotkey != nil {
                Button(role: .destructive) {
                    hotkey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Invisible NSViewRepresentable that captures key events when recording.
struct HotkeyRecorderHelper: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var hotkey: HotkeyCombo?

    func makeNSView(context: Context) -> NSView {
        let view = RecorderView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? RecorderView)?.coordinator = context.coordinator
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class RecorderView: NSView {
        var coordinator: Coordinator?
        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            coordinator?.handleKeyDown(event)
        }

        override func flagsChanged(with event: NSEvent) {
            // ignore standalone modifier changes
        }
    }

    class Coordinator {
        let parent: HotkeyRecorderHelper

        init(_ parent: HotkeyRecorderHelper) {
            self.parent = parent
        }

        func handleKeyDown(_ event: NSEvent) {
            guard parent.isRecording else { return }

            // Require at least one modifier
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else {
                if event.keyCode == 53 { // Esc cancels recording
                    parent.isRecording = false
                }
                return
            }

            parent.hotkey = HotkeyCombo(
                keyCode: event.keyCode,
                modifiers: mods.rawValue
            )
            parent.isRecording = false
        }
    }
}
