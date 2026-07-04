import CoreGraphics

/// Pure layout math for the pocket panel: derives panel size and grid columns
/// from the chosen edge and icon size. Kept free of AppKit so positioning is
/// deterministic and unit-testable.
enum PanelLayout {
    static let slotCount = 12
    static let spacing: CGFloat = 8
    static let padding: CGFloat = 12
    static let labelHeight: CGFloat = 16
    /// Height reserved for the header (stash menu + toolbar) and its divider.
    static let chromeHeight: CGFloat = 40

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

    /// How many item columns fit within `width` for the given icon size.
    /// Returns 0 when not even one column fits.
    static func columnsThatFit(width: CGFloat, iconSize: CGFloat) -> Int {
        let cellWidth = cellSize(iconSize: iconSize).width
        let usable = width - padding * 2 + spacing
        guard usable > 0 else { return 0 }
        return max(0, Int((usable / (cellWidth + spacing)).rounded(.down)))
    }

    /// Panel size for `itemCount` items laid out in `columns` columns.
    static func adaptiveSize(iconSize: CGFloat, itemCount: Int, columns: Int) -> CGSize {
        let cols = max(1, columns)
        let count = max(1, itemCount)
        let rows = max(1, Int((Double(count) / Double(cols)).rounded(.up)))
        let cell = cellSize(iconSize: iconSize)
        let width = padding * 2 + CGFloat(cols) * cell.width + CGFloat(cols - 1) * spacing
        let height = padding * 2 + CGFloat(rows) * cell.height + CGFloat(rows - 1) * spacing
        return CGSize(width: width, height: height)
    }
}
