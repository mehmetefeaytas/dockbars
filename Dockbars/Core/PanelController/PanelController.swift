import AppKit
import SwiftUI
import SwiftData

/// Owns the pocket panel's lifecycle: hosting the SwiftUI content, positioning
/// flush to the active edge, and animating the slide + fade in/out.
@MainActor
final class PanelController {
    private let panel: PocketPanel
    private var edge: PanelEdge = .right
    private var panelSize: CGSize = CGSize(width: 300, height: 400)

    private(set) var isVisible = false

    /// Distance the panel travels during the slide animation.
    private let slideDistance: CGFloat = 16
    private let animationDuration: TimeInterval = 0.22

    init(appState: AppState, container: ModelContainer) {
        panel = PocketPanel(contentRect: CGRect(origin: .zero, size: panelSize))

        let root = PocketPanelView()
            .environmentObject(appState)
            .modelContainer(container)
        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.frame = CGRect(origin: .zero, size: panelSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    var frame: CGRect { panel.frame }

    /// Force the panel's appearance (System / Light / Dark).
    func applyAppearance(_ appearance: NSAppearance?) {
        panel.appearance = appearance
    }

    /// Update the layout the next open should use.
    func configure(edge: PanelEdge, size: CGSize) {
        self.edge = edge
        self.panelSize = size
        if isVisible {
            // Live-resize while open (e.g. Dock moved, icon size changed).
            panel.setContentSize(size)
        }
    }

    func show(edge: PanelEdge, origin: CGPoint, size: CGSize, reduceMotion: Bool, activated: Bool = false) {
        self.edge = edge
        self.panelSize = size
        panel.keyable = activated
        panel.setContentSize(size)

        let finalFrame = CGRect(origin: origin, size: size)

        guard !isVisible else {
            panel.setFrame(finalFrame, display: true)
            if activated { activate() }
            return
        }
        isVisible = true

        if reduceMotion {
            panel.alphaValue = 0
            panel.setFrame(finalFrame, display: true)
            order(activated: activated)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = animationDuration
                panel.animator().alphaValue = 1
            }
            return
        }

        let startOrigin = DockGeometry.offscreenOrigin(from: origin, edge: edge, distance: slideDistance)
        panel.alphaValue = 0
        panel.setFrame(CGRect(origin: startOrigin, size: size), display: false)
        order(activated: activated)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = animationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    /// Order the panel in — as a key window when activated (keyboard/search),
    /// otherwise without stealing focus from the active app.
    private func order(activated: Bool) {
        if activated {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func activate() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide(reduceMotion: Bool) {
        guard isVisible else { return }
        isVisible = false

        let origin = panel.frame.origin
        let endOrigin = reduceMotion
            ? origin
            : DockGeometry.offscreenOrigin(from: origin, edge: edge, distance: slideDistance)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = animationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            if !reduceMotion {
                panel.animator().setFrame(CGRect(origin: endOrigin, size: panel.frame.size), display: true)
            }
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })
    }
}
