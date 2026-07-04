import AppKit

/// Borderless, non-activating floating panel that hosts the pocket content.
/// Ordering it in must never steal focus from the active app, so it never
/// becomes key or main in Phase 1 (keyboard nav arrives in Phase 2).
final class PocketPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Keep it out of the window cycle / screenshots of "windows".
        isExcludedFromWindowsMenu = true
    }

    /// Hover-opened pockets stay non-key (never steal focus). Explicitly-invoked
    /// pockets (menu bar / shortcut) set this true to accept keyboard input.
    var keyable = false

    override var canBecomeKey: Bool { keyable }
    override var canBecomeMain: Bool { false }
}
