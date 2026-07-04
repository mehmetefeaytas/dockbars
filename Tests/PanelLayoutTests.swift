import XCTest
@testable import Dockbars

final class PanelLayoutTests: XCTestCase {
    func testColumnsThatFitScalesWithWidth() {
        let narrow = PanelLayout.columnsThatFit(width: 100, iconSize: 48)
        let wide = PanelLayout.columnsThatFit(width: 600, iconSize: 48)
        XCTAssertGreaterThan(wide, narrow)
        XCTAssertGreaterThanOrEqual(narrow, 0)
    }

    func testColumnsThatFitReturnsZeroForTinyWidth() {
        XCTAssertEqual(PanelLayout.columnsThatFit(width: 4, iconSize: 48), 0)
    }

    func testAdaptiveSizeGrowsWithMoreRows() {
        let oneRow = PanelLayout.adaptiveSize(iconSize: 48, itemCount: 3, columns: 3)
        let twoRows = PanelLayout.adaptiveSize(iconSize: 48, itemCount: 6, columns: 3)
        XCTAssertEqual(oneRow.width, twoRows.width, accuracy: 0.001) // same columns → same width
        XCTAssertGreaterThan(twoRows.height, oneRow.height)          // more rows → taller
    }

    func testAdaptiveSizeClampsColumnsToAtLeastOne() {
        let size = PanelLayout.adaptiveSize(iconSize: 48, itemCount: 4, columns: 0)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
    }

    func testAdaptiveSizeRoundsRowsUp() {
        // 5 items in 3 columns → 2 rows.
        let five = PanelLayout.adaptiveSize(iconSize: 48, itemCount: 5, columns: 3)
        let six = PanelLayout.adaptiveSize(iconSize: 48, itemCount: 6, columns: 3)
        XCTAssertEqual(five.height, six.height, accuracy: 0.001) // both need 2 rows
    }

    func testLargerIconsProduceLargerCells() {
        let small = PanelLayout.cellSize(iconSize: 32)
        let large = PanelLayout.cellSize(iconSize: 64)
        XCTAssertGreaterThan(large.width, small.width)
        XCTAssertGreaterThan(large.height, small.height)
    }
}
