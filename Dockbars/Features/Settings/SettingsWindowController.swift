import AppKit
import SwiftUI

/// Hosts the SwiftUI Settings view in a standard titled window. Bringing it up
/// briefly promotes the app to a regular activation policy so the window can be
/// focused, then reverts to accessory when it closes.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init(appState: AppState) {
        let root = SettingsView(settings: appState.settings)
            .environmentObject(appState)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Dockbars Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Return to menu-bar-only mode.
        NSApp.setActivationPolicy(.accessory)
    }
}
