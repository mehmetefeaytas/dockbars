import AppKit

/// A transparent, click-through-ish window sitting over the hover trigger zone
/// that exists purely to catch drag-and-drop sessions. NSEvent monitors don't
/// receive events during a drag, so hovering alone can't open the pocket while
/// dragging a file — this window's `draggingEntered` does, so users can drag
/// files from Finder straight into the pocket.
@MainActor
final class DragTriggerWindow {
    private let window: NSWindow
    private let catchView: DragCatchView

    var onDragEntered: (() -> Void)?

    init() {
        catchView = DragCatchView()
        window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = false // must be false to receive drags
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = catchView
        catchView.onEntered = { [weak self] in self?.onDragEntered?() }
    }

    func update(frame: CGRect) {
        guard frame.width > 0, frame.height > 0 else { return }
        window.setFrame(frame, display: false)
        window.orderFrontRegardless()
    }
}

/// Content view that reports when a drag enters. It never accepts the drop
/// itself (returns `[]`); it just signals the pocket to open so the pocket panel
/// — which does accept `.fileURL` — can receive the drop.
private final class DragCatchView: NSView {
    var onEntered: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        onEntered?()
        return []
    }
}
