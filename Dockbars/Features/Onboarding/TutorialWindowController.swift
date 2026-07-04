import AppKit
import SwiftUI

/// Hosts the SwiftUI tutorial in a titled window. Temporarily promotes the app
/// to a regular activation policy so the window can take focus, and polls the
/// Accessibility status while open so the permission step updates live.
@MainActor
final class TutorialWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    private var refreshTimer: Timer?
    private weak var appState: AppState?

    convenience init(appState: AppState) {
        let hosting = NSHostingController(rootView: AnyView(EmptyView()))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to Dockbars"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        self.init(window: window)
        self.appState = appState
        window.delegate = self

        let root = TutorialView(settings: appState.settings, onFinish: { [weak self] in
            self?.close()
        })
        .environmentObject(appState)
        hosting.rootView = AnyView(root)
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        startRefresh()
    }

    private func startRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.appState?.refreshAccessibilityStatus() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
        NSApp.setActivationPolicy(.accessory)
        onClose?()
    }
}
