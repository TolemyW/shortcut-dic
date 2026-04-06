import SwiftUI
import AppKit

final class OverlayPanel: NSPanel {

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

    func showOverlay<V: View>(_ view: V, at position: PanelPosition) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame.size = hostingView.fittingSize

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
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

    func hideOverlay() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
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
