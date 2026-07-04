import CoreGraphics

/// Pure geometry: given a Dock configuration and screen frames, work out which
/// edge the pocket attaches to, where the hover trigger strip lives, and where
/// the panel should be placed. No AppKit, no side effects — fully unit-testable.
enum DockGeometry {
    /// Edges the pocket may use for a given Dock orientation.
    static func allowedEdges(for orientation: DockInfo.Orientation) -> [PanelEdge] {
        switch orientation {
        case .bottom: return [.right, .left]
        case .left, .right: return [.top, .bottom]
        }
    }

    /// Keep the user's preferred edge when it is valid for the current Dock
    /// orientation; otherwise fall back to the first allowed edge.
    static func resolveEdge(preferred: PanelEdge, orientation: DockInfo.Orientation) -> PanelEdge {
        let allowed = allowedEdges(for: orientation)
        return allowed.contains(preferred) ? preferred : allowed[0]
    }

    /// Thin trigger strip along the chosen screen edge (global, bottom-left origin).
    static func triggerZone(edge: PanelEdge, screenFrame: CGRect, thickness: CGFloat) -> CGRect {
        let t = max(1, thickness)
        switch edge {
        case .right:
            return CGRect(x: screenFrame.maxX - t, y: screenFrame.minY, width: t, height: screenFrame.height)
        case .left:
            return CGRect(x: screenFrame.minX, y: screenFrame.minY, width: t, height: screenFrame.height)
        case .top:
            return CGRect(x: screenFrame.minX, y: screenFrame.maxY - t, width: screenFrame.width, height: t)
        case .bottom:
            return CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: t)
        }
    }

    /// Panel origin so it sits flush against the chosen edge, centered along it,
    /// clamped to the visible frame so it never slips under the menu bar or Dock.
    static func panelOrigin(edge: PanelEdge, panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        switch edge {
        case .right:
            let y = clamp(visibleFrame.midY - panelSize.height / 2,
                          visibleFrame.minY, visibleFrame.maxY - panelSize.height)
            return CGPoint(x: visibleFrame.maxX - panelSize.width, y: y)
        case .left:
            let y = clamp(visibleFrame.midY - panelSize.height / 2,
                          visibleFrame.minY, visibleFrame.maxY - panelSize.height)
            return CGPoint(x: visibleFrame.minX, y: y)
        case .top:
            let x = clamp(visibleFrame.midX - panelSize.width / 2,
                          visibleFrame.minX, visibleFrame.maxX - panelSize.width)
            return CGPoint(x: x, y: visibleFrame.maxY - panelSize.height)
        case .bottom:
            let x = clamp(visibleFrame.midX - panelSize.width / 2,
                          visibleFrame.minX, visibleFrame.maxX - panelSize.width)
            return CGPoint(x: x, y: visibleFrame.minY)
        }
    }

    /// Off-screen start origin for the slide-in animation (offset outward by `distance`).
    static func offscreenOrigin(from origin: CGPoint, edge: PanelEdge, distance: CGFloat) -> CGPoint {
        switch edge {
        case .right: return CGPoint(x: origin.x + distance, y: origin.y)
        case .left: return CGPoint(x: origin.x - distance, y: origin.y)
        case .top: return CGPoint(x: origin.x, y: origin.y + distance)
        case .bottom: return CGPoint(x: origin.x, y: origin.y - distance)
        }
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        guard upper > lower else { return lower }
        return max(lower, min(upper, value))
    }
}
