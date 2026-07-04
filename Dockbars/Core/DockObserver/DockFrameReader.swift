import AppKit
import ApplicationServices

/// Reads the Dock's tile-list rectangle via the Accessibility API — the only
/// reliable source for the Dock's actual position and width (defaults and
/// NSScreen expose orientation/thickness but not the tile extent).
///
/// Returns nil when unavailable: no Accessibility grant, or the Dock is hidden
/// (autohide), in which case its AX frame collapses to zero and callers fall
/// back to an estimate.
enum DockFrameReader {
    static func currentDockFrame(primaryScreen: CGRect) -> CGRect? {
        guard AXIsProcessTrusted(),
              let dockApp = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }

        let app = AXUIElementCreateApplication(dockApp.processIdentifier)
        guard let list = firstList(in: app), let axFrame = frame(of: list) else { return nil }

        // Convert AX (top-left origin, y down) → AppKit (bottom-left origin).
        let nsY = primaryScreen.height - axFrame.origin.y - axFrame.height
        let rect = CGRect(x: axFrame.origin.x, y: nsY, width: axFrame.width, height: axFrame.height)

        // Reject degenerate (hidden Dock) or clearly off-screen frames.
        guard rect.width > 1, rect.height > 1, rect.intersects(primaryScreen) else { return nil }
        return rect
    }

    // MARK: - AX helpers

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }

    private static func role(_ element: AXUIElement) -> String {
        (attribute(element, kAXRoleAttribute as String) as? String) ?? ""
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
    }

    private static func firstList(in app: AXUIElement) -> AXUIElement? {
        for child in children(app) {
            if role(child) == (kAXListRole as String) { return child }
            for grandchild in children(child) where role(grandchild) == (kAXListRole as String) {
                return grandchild
            }
        }
        return nil
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let posValue = attribute(element, kAXPositionAttribute as String),
              let sizeValue = attribute(element, kAXSizeAttribute as String) else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }
}
