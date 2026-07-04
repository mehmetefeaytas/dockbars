import CoreGraphics

/// Pure layout math for the pocket panel: derives panel size and grid columns
/// from the chosen edge and icon size. Kept free of AppKit so positioning is
/// deterministic and unit-testable.
enum PanelLayout {
    static let slotCount = 12
    static let spacing: CGFloat = 8
    static let padding: CGFloat = 12
    static let labelHeight: CGFloat = 16

    static func cellSize(iconSize: CGFloat) -> CGSize {
        CGSize(width: iconSize + 24, height: iconSize + labelHeight + 12)
    }

    /// Columns × rows for the fixed 12-slot MVP grid, per edge orientation.
    static func grid(edge: PanelEdge) -> (columns: Int, rows: Int) {
        edge.isVertical ? (columns: 3, rows: 4) : (columns: 6, rows: 2)
    }

    static func columns(edge: PanelEdge) -> Int { grid(edge: edge).columns }

    static func panelSize(edge: PanelEdge, iconSize: CGFloat) -> CGSize {
        let (cols, rows) = grid(edge: edge)
        let cell = cellSize(iconSize: iconSize)
        let width = padding * 2 + CGFloat(cols) * cell.width + CGFloat(cols - 1) * spacing
        let height = padding * 2 + CGFloat(rows) * cell.height + CGFloat(rows - 1) * spacing
        return CGSize(width: width, height: height)
    }
}
