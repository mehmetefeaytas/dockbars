import AppKit

/// Owns the status-bar item. Left-click toggles the pocket (a reliable way to
/// open it regardless of hover); right-click (or Control-click) shows the menu.
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let menu = NSMenu()

    var onTogglePanel: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onShowTutorial: (() -> Void)?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        configureButton()
    }

    private func configureButton() {
        statusItem.isVisible = true
        guard let button = statusItem.button else {
            NSLog("Dockbars ▸ status item has NO button — menu bar may be full")
            return
        }
        let image = NSImage(systemSymbolName: "tray.full.fill", accessibilityDescription: "Dockbars")
        button.image = image
        button.image?.isTemplate = true
        if image == nil { button.title = "▦" }
        button.toolTip = "Dockbars — click to open the pocket, right-click for menu"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
        NSLog("Dockbars ▸ status item ready (image=\(image != nil))")
    }

    /// Shows the active stash name beside the icon (empty hides the label).
    func updateStashLabel(_ name: String) {
        statusItem.button?.title = name.isEmpty ? "" : " \(name)"
    }

    private func buildMenu() {
        let toggle = NSMenuItem(title: "Open / Close Pocket", action: #selector(toggle), keyEquivalent: "")
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
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            // Show the menu on demand (kept off the status item so left-click works).
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            onTogglePanel?()
        }
    }

    @objc private func toggle() { onTogglePanel?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func showTutorial() { onShowTutorial?() }
    @objc private func quit() { NSApp.terminate(nil) }
}
