import AppKit

/// Detects when the pointer reaches the pocket's trigger strip and drives the
/// open/close lifecycle through `HoverDebouncer`.
///
/// Uses a global `.mouseMoved` monitor (plus a local one for our own panel).
/// The move handler is deliberately allocation-free: it does one rect test
/// against a cached trigger zone. The close delay is realized with a single
/// cancellable work item rather than a polling timer, so idle CPU stays near 0.
@MainActor
final class HoverEngine {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cachedTriggerZone: CGRect = .zero
    private var closeWorkItem: DispatchWorkItem?
    private let debouncer: HoverDebouncer

    /// Returns the current panel frame when visible, so hovering the panel keeps
    /// it open. Returns nil when the panel is hidden.
    var panelFrameProvider: (() -> CGRect?)?
    /// When true (e.g. a fullscreen app is frontmost — Phase 3), hover is ignored.
    var isSuspended = false

    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    init(closeDelay: TimeInterval) {
        debouncer = HoverDebouncer(closeDelay: closeDelay)
        debouncer.onOpen = { [weak self] in self?.onOpen?() }
        debouncer.onClose = { [weak self] in self?.onClose?() }
    }

    var isOpen: Bool { debouncer.isOpen }

    func updateTriggerZone(_ zone: CGRect) {
        cachedTriggerZone = zone
    }

    func updateCloseDelay(_ delay: TimeInterval) {
        debouncer.updateCloseDelay(delay)
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }
        // Local monitor covers moves delivered to our own (nonactivating) panel.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }

    /// Programmatic open (menu-bar toggle).
    func requestOpen() {
        cancelScheduledClose()
        debouncer.pointerInside(now: ProcessInfo.processInfo.systemUptime)
    }

    /// Programmatic close (menu-bar toggle, Esc).
    func requestClose() {
        cancelScheduledClose()
        debouncer.forceClose()
    }

    // MARK: - Core hot path

    private func handleMouseMoved() {
        guard !isSuspended else { return }
        let location = NSEvent.mouseLocation // cheap property, global bottom-left coords
        let inside = cachedTriggerZone.contains(location)
            || (debouncer.isOpen && (panelFrameProvider?()?.contains(location) ?? false))

        let now = ProcessInfo.processInfo.systemUptime
        if inside {
            cancelScheduledClose()
            debouncer.pointerInside(now: now)
        } else {
            debouncer.pointerOutside(now: now)
            scheduleCloseIfNeeded()
        }
    }

    private func scheduleCloseIfNeeded() {
        guard closeWorkItem == nil, debouncer.pendingCloseDeadline != nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.closeWorkItem = nil
            self.debouncer.tick(now: ProcessInfo.processInfo.systemUptime)
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debouncer.closeDelay, execute: work)
    }

    private func cancelScheduledClose() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }
}
