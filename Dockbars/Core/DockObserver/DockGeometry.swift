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

    // MARK: - Placement (edge vs. dock-adjacent)

    /// Fully-resolved placement for the pocket.
    struct PlacementResult: Equatable {
        var edge: PanelEdge       // layout orientation + slide direction
        var origin: CGPoint       // panel origin (bottom-left)
        var size: CGSize          // panel size
        var triggerZone: CGRect   // where hovering opens the pocket
        var overflowed: Bool      // dock-adjacent: repositioned because it didn't fit beside
    }

    /// Keep a reasonable minimum pocket size even for small/empty stashes.
    private static let minimumSlots = 4

    static func placement(mode: PlacementMode,
                          dockInfo: DockInfo,
                          preferredEdge: PanelEdge,
                          iconSize: CGFloat,
                          itemCount: Int,
                          triggerThickness: CGFloat,
                          margin: CGFloat) -> PlacementResult {
        let count = max(itemCount, minimumSlots)
        switch mode {
        case .screenEdge:
            let edge = resolveEdge(preferred: preferredEdge, orientation: dockInfo.orientation)
            let maxColumns = edge.isVertical ? 3 : 6
            let columns = min(maxColumns, count)
            let size = PanelLayout.adaptiveSize(iconSize: iconSize, itemCount: count, columns: columns)
            let origin = panelOrigin(edge: edge, panelSize: size, visibleFrame: dockInfo.visibleFrame)
            let trigger = triggerZone(edge: edge, screenFrame: dockInfo.screenFrame, thickness: triggerThickness)
            return PlacementResult(edge: edge, origin: origin, size: size, triggerZone: trigger, overflowed: false)

        case .dockAdjacent:
            return dockAdjacentPlacement(dockInfo: dockInfo, iconSize: iconSize, itemCount: count,
                                         triggerThickness: triggerThickness, margin: margin)
        }
    }

    /// Best-effort Dock rectangle when Accessibility can't provide one (hidden Dock).
    /// Assumes a centered Dock occupying ~half the relevant screen dimension.
    static func estimateDockFrame(_ info: DockInfo) -> CGRect {
        let screen = info.screenFrame
        let thickness = max(info.tileSize * 1.3, 60)
        switch info.orientation {
        case .bottom:
            let width = screen.width * 0.5
            return CGRect(x: screen.midX - width / 2, y: screen.minY, width: width, height: thickness)
        case .left:
            let height = screen.height * 0.5
            return CGRect(x: screen.minX, y: screen.midY - height / 2, width: thickness, height: height)
        case .right:
            let height = screen.height * 0.5
            return CGRect(x: screen.maxX - thickness, y: screen.midY - height / 2, width: thickness, height: height)
        }
    }

    private static func dockAdjacentPlacement(dockInfo: DockInfo,
                                              iconSize: CGFloat,
                                              itemCount: Int,
                                              triggerThickness: CGFloat,
                                              margin: CGFloat) -> PlacementResult {
        let dock = dockInfo.dockFrame ?? estimateDockFrame(dockInfo)
        let screen = dockInfo.screenFrame
        let visible = dockInfo.visibleFrame
        let t = max(1, triggerThickness)

        switch dockInfo.orientation {
        case .bottom:
            let gapLeft = dock.minX - screen.minX
            let besideColumns = PanelLayout.columnsThatFit(width: gapLeft - margin, iconSize: iconSize)
            if besideColumns >= 1 {
                let columns = min(besideColumns, itemCount)
                let size = PanelLayout.adaptiveSize(iconSize: iconSize, itemCount: itemCount, columns: columns)
                let availableHeight = visible.maxY - dock.minY - margin
                if size.height <= availableHeight {
                    // Fits in the bottom-left gap, beside the Dock.
                    let origin = CGPoint(x: screen.minX + margin, y: dock.minY)
                    let trigger = CGRect(x: screen.minX, y: screen.minY, width: max(gapLeft, 24), height: t)
                    return PlacementResult(edge: .bottom, origin: origin, size: size,
                                           triggerZone: trigger, overflowed: false)
                }
            }
            // Too large to fit beside → stack above the Dock, using the full width.
            let aboveColumns = max(1, PanelLayout.columnsThatFit(width: visible.width * 0.6, iconSize: iconSize))
            let columns = min(aboveColumns, itemCount)
            let size = PanelLayout.adaptiveSize(iconSize: iconSize, itemCount: itemCount, columns: columns)
            let x = clamp(dock.midX - size.width / 2, visible.minX, max(visible.minX, visible.maxX - size.width))
            let y = dock.maxY + margin
            let trigger = CGRect(x: screen.minX, y: screen.minY, width: max(gapLeft, 120), height: t)
            return PlacementResult(edge: .bottom, origin: CGPoint(x: x, y: y), size: size,
                                   triggerZone: trigger, overflowed: true)

        case .left:
            let columns = min(3, itemCount)
            let size = PanelLayout.adaptiveSize(iconSize: iconSize, itemCount: itemCount, columns: columns)
            let y = clamp(dock.minY, visible.minY, max(visible.minY, visible.maxY - size.height))
            let origin = CGPoint(x: dock.maxX + margin, y: y)
            let trigger = CGRect(x: screen.minX, y: screen.minY, width: t, height: screen.height)
            return PlacementResult(edge: .left, origin: origin, size: size,
                                   triggerZone: trigger, overflowed: false)

        case .right:
            let columns = min(3, itemCount)
            let size = PanelLayout.adaptiveSize(iconSize: iconSize, itemCount: itemCount, columns: columns)
            let y = clamp(dock.minY, visible.minY, max(visible.minY, visible.maxY - size.height))
            let origin = CGPoint(x: dock.minX - size.width - margin, y: y)
            let trigger = CGRect(x: screen.maxX - t, y: screen.minY, width: t, height: screen.height)
            return PlacementResult(edge: .right, origin: origin, size: size,
                                   triggerZone: trigger, overflowed: false)
        }
    }
}
