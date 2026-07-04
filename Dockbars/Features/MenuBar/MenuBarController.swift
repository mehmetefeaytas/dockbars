import AppKit

/// Owns the status-bar item and its menu (Toggle Pocket / Settings / Quit).
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState

    var onTogglePanel: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onShowTutorial: (() -> Void)?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        buildMenu()
    }

    private func configureButton() {
        statusItem.isVisible = true
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: "Dockbars")
            button.image = image
            button.image?.isTemplate = true
            if image == nil { button.title = "▦" } // fallback if the symbol is unavailable
            NSLog("Dockbars ▸ status item: image=\(image != nil) window=\(button.window != nil) frame=\(button.window.map { NSStringFromRect($0.frame) } ?? "nil")")
        } else {
            NSLog("Dockbars ▸ status item has NO button — menu bar may be full")
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Toggle Pocket", action: #selector(toggle), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let tutorial = NSMenuItem(title: "Show Tutorial…", action: #selector(showTutorial), keyEquivalent: "")
        tutorial.target = self
        menu.addItem(tutorial)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Dockbars", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func toggle() { onTogglePanel?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func showTutorial() { onShowTutorial?() }
    @objc private func quit() { NSApp.terminate(nil) }
}
