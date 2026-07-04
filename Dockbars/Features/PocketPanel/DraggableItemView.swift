import SwiftUI
import AppKit

/// Closures the AppKit item view invokes for user actions.
struct ItemActions {
    var open: () -> Void
    var reveal: () -> Void
    var rename: () -> Void
    var remove: () -> Void
    var moveTargets: [(name: String, move: () -> Void)]
    var dragBegan: () -> Void = {}
}

/// Hosts a SwiftUI cell but drives interaction from AppKit, because SwiftUI's
/// `.onDrag`/`.onDrop` are unreliable inside a borderless non-activating panel.
/// Left-click opens, right-click shows the context menu, and a drag starts a real
/// `NSDraggingSession` — so dropping on the trash works, and dropping into empty
/// space (no acceptor) removes the item ("drag out to remove").
struct DraggableItemView: NSViewRepresentable {
    let fileURL: URL?
    let dragImage: NSImage?
    let actions: ItemActions
    let content: AnyView

    func makeNSView(context: Context) -> DragSourceView {
        let view = DragSourceView()
        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: view.topAnchor),
            host.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        view.hostingView = host
        view.configure(fileURL: fileURL, dragImage: dragImage, actions: actions)
        return view
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.hostingView?.rootView = content
        view.configure(fileURL: fileURL, dragImage: dragImage, actions: actions)
    }
}

final class DragSourceView: NSView, NSDraggingSource {
    var hostingView: NSHostingView<AnyView>?
    private var fileURL: URL?
    private var dragImage: NSImage?
    private var actions: ItemActions?
    private var mouseDownLocation: NSPoint?

    func configure(fileURL: URL?, dragImage: NSImage?, actions: ItemActions) {
        self.fileURL = fileURL
        self.dragImage = dragImage
        self.actions = actions
    }

    // The SwiftUI content is display-only; claim any event within our tree.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) != nil ? self : nil
    }

    override var acceptsFirstResponder: Bool { true }
    // Deliver the click even if the panel wasn't key yet.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownLocation, let url = fileURL else { return }
        let distance = hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y)
        guard distance > 6 else { return } // threshold to distinguish click from drag
        mouseDownLocation = nil
        actions?.dragBegan()

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let image = dragImage ?? NSWorkspace.shared.icon(forFile: url.path)
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 44, height: 44), contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDownLocation != nil { actions?.open() } // click, not a drag
        mouseDownLocation = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let actions else { return }
        let menu = NSMenu()
        add(menu, "Open", #selector(doOpen))
        add(menu, "Reveal in Finder", #selector(doReveal))
        add(menu, "Rename…", #selector(doRename))
        if !actions.moveTargets.isEmpty {
            let move = NSMenuItem(title: "Move to Stash", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for (index, target) in actions.moveTargets.enumerated() {
                let mi = NSMenuItem(title: target.name, action: #selector(doMove(_:)), keyEquivalent: "")
                mi.target = self
                mi.tag = index
                submenu.addItem(mi)
            }
            move.submenu = submenu
            menu.addItem(move)
        }
        menu.addItem(.separator())
        add(menu, "Remove", #selector(doRemove))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func add(_ menu: NSMenu, _ title: String, _ selector: Selector) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func doOpen() { actions?.open() }
    @objc private func doReveal() { actions?.reveal() }
    @objc private func doRename() { actions?.rename() }
    @objc private func doRemove() { actions?.remove() }
    @objc private func doMove(_ sender: NSMenuItem) {
        guard let actions, actions.moveTargets.indices.contains(sender.tag) else { return }
        actions.moveTargets[sender.tag].move()
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .generic] // never .delete, so files are never trashed
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Dropped where nothing accepted it → remove from the stash ("drag out").
        if operation == [] { actions?.remove() }
    }
}
