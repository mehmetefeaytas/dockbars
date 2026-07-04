import CoreGraphics

/// Snapshot of the Dock's configuration and the hosting screen's geometry.
struct DockInfo: Equatable {
    enum Orientation: String {
        case bottom, left, right
    }

    var orientation: Orientation
    /// Dock tile size in points (com.apple.dock `tilesize`).
    var tileSize: CGFloat
    var autohide: Bool
    /// Full display bounds (bottom-left origin, global coordinates).
    var screenFrame: CGRect
    /// Usable bounds excluding the menu bar and a non-hidden Dock.
    var visibleFrame: CGRect
    /// The Dock's actual tile rectangle (bottom-left origin), when resolvable via
    /// Accessibility. Nil when hidden/unavailable — callers estimate instead.
    var dockFrame: CGRect?

    static let fallback = DockInfo(
        orientation: .bottom,
        tileSize: 48,
        autohide: false,
        screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 800),
        dockFrame: nil
    )
}
