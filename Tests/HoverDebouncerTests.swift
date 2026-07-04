import XCTest
@testable import Dockbars

final class HoverDebouncerTests: XCTestCase {
    func testOpensImmediatelyOnPointerInside() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        var opened = false
        debouncer.onOpen = { opened = true }

        debouncer.pointerInside(now: 0)

        XCTAssertTrue(debouncer.isOpen)
        XCTAssertTrue(opened)
    }

    func testDoesNotReopenWhenAlreadyOpen() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        var openCount = 0
        debouncer.onOpen = { openCount += 1 }

        debouncer.pointerInside(now: 0)
        debouncer.pointerInside(now: 0.1)

        XCTAssertEqual(openCount, 1)
    }

    func testCloseArmsDeadlineButDoesNotCloseEarly() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        var closed = false
        debouncer.onClose = { closed = true }

        debouncer.pointerInside(now: 0)
        debouncer.pointerOutside(now: 1.0)
        debouncer.tick(now: 1.2) // before the 1.25 deadline

        XCTAssertFalse(closed)
        XCTAssertTrue(debouncer.isOpen)
    }

    func testClosesAfterDelayElapses() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        var closed = false
        debouncer.onClose = { closed = true }

        debouncer.pointerInside(now: 0)
        debouncer.pointerOutside(now: 1.0)
        debouncer.tick(now: 1.25) // exactly at deadline

        XCTAssertTrue(closed)
        XCTAssertFalse(debouncer.isOpen)
    }

    func testReenteringBeforeDeadlineCancelsClose() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        var closed = false
        debouncer.onClose = { closed = true }

        debouncer.pointerInside(now: 0)
        debouncer.pointerOutside(now: 1.0)
        debouncer.pointerInside(now: 1.1) // came back before 1.25
        debouncer.tick(now: 1.3)

        XCTAssertFalse(closed)
        XCTAssertTrue(debouncer.isOpen)
        XCTAssertNil(debouncer.pendingCloseDeadline)
    }

    func testPointerOutsideWhileClosedIsNoop() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        debouncer.pointerOutside(now: 1.0)
        XCTAssertNil(debouncer.pendingCloseDeadline)
        XCTAssertFalse(debouncer.isOpen)
    }

    func testFirstOutsideWinsDeadlineNotExtendedByLaterOutside() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        debouncer.pointerInside(now: 0)
        debouncer.pointerOutside(now: 1.0) // deadline = 1.25
        debouncer.pointerOutside(now: 1.1) // must NOT push deadline to 1.35
        XCTAssertEqual(debouncer.pendingCloseDeadline, 1.25)
    }

    func testForceCloseClosesImmediatelyAndClearsDeadline() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        var closed = false
        debouncer.onClose = { closed = true }

        debouncer.pointerInside(now: 0)
        debouncer.pointerOutside(now: 1.0)
        debouncer.forceClose()

        XCTAssertTrue(closed)
        XCTAssertFalse(debouncer.isOpen)
        XCTAssertNil(debouncer.pendingCloseDeadline)
    }

    func testUpdateCloseDelayAffectsNextArming() {
        let debouncer = HoverDebouncer(closeDelay: 0.25)
        debouncer.updateCloseDelay(0.5)
        debouncer.pointerInside(now: 0)
        debouncer.pointerOutside(now: 1.0)
        XCTAssertEqual(debouncer.pendingCloseDeadline, 1.5)
    }
}
