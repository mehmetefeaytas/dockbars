import AppKit

/// Detects when the frontmost app occupies a full display (fullscreen) so hover
/// detection can be suspended. Heuristic: the frontmost app has a normal-layer
/// window whose size matches a whole display. Notified on space/app changes —
/// entering/leaving fullscreen switches Spaces, which fires activeSpaceDidChange.
@MainActor
final class FullscreenMonitor {
    var onChange: ((Bool) -> Void)?
    private(set) var isFullscreen = false

    init() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            center.addObserver(self, selector: #selector(update), name: name, object: nil)
        }
        update()
    }

    deinit { NSWorkspace.shared.notificationCenter.removeObserver(self) }

    @objc private func update() {
        let value = Self.isFrontmostFullscreen()
        guard value != isFullscreen else { return }
        isFullscreen = value
        onChange?(value)
    }

    static func isFrontmostFullscreen() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let pid = front.processIdentifier
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return false }

        let screenSizes = NSScreen.screens.map { $0.frame.size }
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let size = CGSize(width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            // A fullscreen window covers an entire display (including the menu bar).
            if screenSizes.contains(where: { abs($0.width - size.width) < 2 && abs($0.height - size.height) < 2 }) {
                return true
            }
        }
        return false
    }
}
