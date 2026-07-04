import XCTest
@testable import Dockbars

final class DockGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let visible = CGRect(x: 0, y: 70, width: 1440, height: 800)

    // MARK: - Allowed / resolved edges

    func testAllowedEdgesForBottomDock() {
        XCTAssertEqual(DockGeometry.allowedEdges(for: .bottom), [.right, .left])
    }

    func testAllowedEdgesForSideDock() {
        XCTAssertEqual(DockGeometry.allowedEdges(for: .left), [.top, .bottom])
        XCTAssertEqual(DockGeometry.allowedEdges(for: .right), [.top, .bottom])
    }

    func testResolveEdgeKeepsValidPreference() {
        XCTAssertEqual(DockGeometry.resolveEdge(preferred: .left, orientation: .bottom), .left)
    }

    func testResolveEdgeFallsBackWhenPreferenceInvalid() {
        // Preferred .right is invalid when the Dock is on the left; fall back to first allowed (.top).
        XCTAssertEqual(DockGeometry.resolveEdge(preferred: .right, orientation: .left), .top)
    }

    // MARK: - Trigger zones

    func testTriggerZoneRightEdge() {
        let zone = DockGeometry.triggerZone(edge: .right, screenFrame: screen, thickness: 4)
        XCTAssertEqual(zone, CGRect(x: 1436, y: 0, width: 4, height: 900))
    }

    func testTriggerZoneLeftEdge() {
        let zone = DockGeometry.triggerZone(edge: .left, screenFrame: screen, thickness: 4)
        XCTAssertEqual(zone, CGRect(x: 0, y: 0, width: 4, height: 900))
    }

    func testTriggerZoneTopEdge() {
        let zone = DockGeometry.triggerZone(edge: .top, screenFrame: screen, thickness: 6)
        XCTAssertEqual(zone, CGRect(x: 0, y: 894, width: 1440, height: 6))
    }

    func testTriggerZoneClampsThicknessToAtLeastOne() {
        let zone = DockGeometry.triggerZone(edge: .bottom, screenFrame: screen, thickness: 0)
        XCTAssertEqual(zone.height, 1)
    }

    // MARK: - Panel placement

    func testPanelOriginRightEdgeIsFlushAndVerticallyCentered() {
        let size = CGSize(width: 300, height: 400)
        let origin = DockGeometry.panelOrigin(edge: .right, panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin.x, visible.maxX - size.width, accuracy: 0.001)
        XCTAssertEqual(origin.y, visible.midY - size.height / 2, accuracy: 0.001)
    }

    func testPanelOriginTopEdgeSitsUnderMenuBar() {
        let size = CGSize(width: 600, height: 200)
        let origin = DockGeometry.panelOrigin(edge: .top, panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin.y, visible.maxY - size.height, accuracy: 0.001)
    }

    func testPanelOriginClampsOversizedPanel() {
        // Panel taller than the visible frame must not push its origin below the frame.
        let size = CGSize(width: 300, height: 5000)
        let origin = DockGeometry.panelOrigin(edge: .right, panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin.y, visible.minY, accuracy: 0.001)
    }

    // MARK: - Offscreen origin

    func testOffscreenOriginRightMovesOutward() {
        let start = DockGeometry.offscreenOrigin(from: CGPoint(x: 100, y: 50), edge: .right, distance: 16)
        XCTAssertEqual(start, CGPoint(x: 116, y: 50))
    }

    func testOffscreenOriginBottomMovesDown() {
        let start = DockGeometry.offscreenOrigin(from: CGPoint(x: 100, y: 50), edge: .bottom, distance: 16)
        XCTAssertEqual(start, CGPoint(x: 100, y: 34))
    }
}
