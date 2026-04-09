import SwiftUI
import AppKit

final class OverlayPanel: NSPanel {

    var isSearchMode = false

    override var canBecomeKey: Bool { isSearchMode }
    override var canBecomeMain: Bool { false }

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
        isExcludedFromWindowsMenu = true
    }

    /// Closure called when ESC is pressed at the panel level (backstop).
    var onCancelOperation: (() -> Void)?

    func enterSearchMode() {
        isSearchMode = true
        styleMask.remove(.nonactivatingPanel)
        // Force activation — the parameterless activate() is unreliable for LSUIElement apps
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        // Retry focusing: SwiftUI's NSViewRepresentable may not be in the view hierarchy yet
        focusTextFieldWithRetry(attempts: 3, delay: 0.05)
    }

    func exitSearchMode() {
        isSearchMode = false
        onCancelOperation = nil
        styleMask.insert(.nonactivatingPanel)
        resignKey()
    }

    override func cancelOperation(_ sender: Any?) {
        // Backstop: if ESC reaches the panel (text field didn't handle it), dismiss
        onCancelOperation?()
    }

    private func focusTextFieldWithRetry(attempts: Int, delay: TimeInterval) {
        guard attempts > 0, let contentView else { return }
        if let textField = findTextField(in: contentView) {
            makeFirstResponder(textField)
        } else {
            // SwiftUI may not have created the NSTextField yet — retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.focusTextFieldWithRetry(attempts: attempts - 1, delay: delay)
            }
        }
    }

    private func findTextField(in view: NSView) -> NSTextField? {
        if let tf = view as? NSTextField, tf.isEditable { return tf }
        for sub in view.subviews {
            if let found = findTextField(in: sub) { return found }
        }
        return nil
    }

    func showOverlay<V: View>(_ view: V, at position: PanelPosition, material: NSVisualEffectView.Material = .hudWindow, panelOpacity: CGFloat = 0.95) {
        // Cancel any in-flight hide animation and reset immediately
        animator().alphaValue = 1
        if isVisible { orderOut(nil) }

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame.size = hostingView.fittingSize

        let visualEffect = NSVisualEffectView()
        visualEffect.material = material
        visualEffect.alphaValue = panelOpacity
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

    func hideOverlay(animated: Bool = true) {
        if isSearchMode { exitSearchMode() }
        // Always cancel any in-flight show/hide animation first
        animator().alphaValue = alphaValue
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                self.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.orderOut(nil)
            })
        } else {
            alphaValue = 0
            orderOut(nil)
        }
    }

    private func positionOnScreen(_ position: PanelPosition) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = frame.size

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
