import Foundation

/// How the pocket is positioned relative to the Dock.
enum PlacementMode: String, CaseIterable, Codable, Identifiable {
    /// Sits next to the Dock (bottom-left for a bottom Dock); if it grows too
    /// large to fit beside the Dock, it repositions above the Dock. The default.
    case dockAdjacent
    /// Attaches to a user-chosen screen edge.
    case screenEdge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dockAdjacent: return "Beside the Dock"
        case .screenEdge: return "Screen Edge"
        }
    }

    var detail: String {
        switch self {
        case .dockAdjacent: return "Opens next to the Dock, and moves above it when it grows too large to fit."
        case .screenEdge: return "Opens from a screen edge you choose."
        }
    }
}
