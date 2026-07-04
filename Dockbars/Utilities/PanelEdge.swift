import CoreGraphics

/// Which screen edge the pocket panel attaches to.
///
/// When the Dock sits at the bottom, the pocket lives on the left/right edge;
/// when the Dock sits on a side, the pocket lives on the top/bottom edge.
enum PanelEdge: String, CaseIterable, Codable, Identifiable {
    case right, left, top, bottom

    var id: String { rawValue }

    /// True when the panel is a tall vertical strip (left/right edges).
    var isVertical: Bool { self == .left || self == .right }

    var displayName: String {
        switch self {
        case .right: return "Right"
        case .left: return "Left"
        case .top: return "Top"
        case .bottom: return "Bottom"
        }
    }
}
