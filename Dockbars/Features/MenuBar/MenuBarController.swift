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
    var onSwitchProfile: ((String?) -> Void)?   // nil = no profile
    var onSaveProfile: (() -> Void)?
    var onDeleteProfile: ((String) -> Void)?

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
        menu.removeAllItems()
        let toggle = NSMenuItem(title: "Open / Close Pocket", action: #selector(toggle), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(profileMenuItem())

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

    private func profileMenuItem() -> NSMenuItem {
        let root = NSMenuItem(title: "Profile", action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let none = NSMenuItem(title: "None", action: #selector(chooseNoProfile), keyEquivalent: "")
        none.target = self
        none.state = appState.profiles.activeName == nil ? .on : .off
        sub.addItem(none)

        if !appState.profiles.profiles.isEmpty { sub.addItem(.separator()) }
        for profile in appState.profiles.profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(chooseProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.name
            item.state = appState.profiles.activeName == profile.name ? .on : .off
            sub.addItem(item)
        }

        sub.addItem(.separator())
        let save = NSMenuItem(title: "Save Current as Profile…", action: #selector(saveProfile), keyEquivalent: "")
        save.target = self
        sub.addItem(save)
        if let active = appState.profiles.activeName {
            let del = NSMenuItem(title: "Delete “\(active)”", action: #selector(deleteActiveProfile), keyEquivalent: "")
            del.target = self
            del.representedObject = active
            sub.addItem(del)
        }
        root.submenu = sub
        return root
    }

    @objc private func chooseNoProfile() { onSwitchProfile?(nil) }
    @objc private func chooseProfile(_ sender: NSMenuItem) { onSwitchProfile?(sender.representedObject as? String) }
    @objc private func saveProfile() { onSaveProfile?() }
    @objc private func deleteActiveProfile(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { onDeleteProfile?(name) }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            // Rebuild so the Profile submenu reflects the current profiles/active.
            buildMenu()
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
