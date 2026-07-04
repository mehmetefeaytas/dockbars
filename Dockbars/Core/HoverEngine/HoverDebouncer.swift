import Foundation

/// Pure debounce state machine for pocket open/close decisions.
///
/// Opens immediately when the pointer is inside the trigger zone (or the open
/// panel); when the pointer leaves it arms a close deadline `closeDelay` seconds
/// out, cancelled if the pointer returns before the deadline. All timing is
/// driven by an injected monotonic `now`, so the logic is fully unit-testable.
final class HoverDebouncer {
    private(set) var isOpen = false
    private(set) var pendingCloseDeadline: TimeInterval?
    private(set) var closeDelay: TimeInterval

    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    init(closeDelay: TimeInterval) {
        self.closeDelay = closeDelay
    }

    func updateCloseDelay(_ delay: TimeInterval) {
        closeDelay = delay
    }

    /// Pointer is inside the trigger zone or the open panel.
    func pointerInside(now: TimeInterval) {
        pendingCloseDeadline = nil
        if !isOpen {
            isOpen = true
            onOpen?()
        }
    }

    /// Pointer is outside; arm the close deadline if not already armed.
    func pointerOutside(now: TimeInterval) {
        guard isOpen else { return }
        if pendingCloseDeadline == nil {
            pendingCloseDeadline = now + closeDelay
        }
    }

    /// Advance time; closes if an armed deadline has elapsed.
    func tick(now: TimeInterval) {
        guard let deadline = pendingCloseDeadline else { return }
        if now >= deadline {
            pendingCloseDeadline = nil
            if isOpen {
                isOpen = false
                onClose?()
            }
        }
    }

    /// Force-close immediately (e.g. menu-bar toggle, Esc).
    func forceClose() {
        pendingCloseDeadline = nil
        if isOpen {
            isOpen = false
            onClose?()
        }
    }
}
