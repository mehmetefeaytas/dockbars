import AppKit
import Combine
import SwiftData

/// Wires the app together: persistence, Dock observation, hover detection,
/// panel presentation, and the menu bar. Acts as the AppKit coordinator.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: ModelContainer!
    private var appState: AppState!
    private var dockObserver: DockObserver!
    private var hoverEngine: HoverEngine!
    private var dragTriggerWindow: DragTriggerWindow!
    private var panelController: PanelController!
    private var menuBarController: MenuBarController!
    private var settingsWindowController: SettingsWindowController?
    private var onboardingController: OnboardingController!
    private var settingsCancellable: AnyCancellable?
    private var keyMonitor: Any?
    private var lastGridColumns = 3
    private var globalHotKey: GlobalHotKey!
    private var fullscreenMonitor: FullscreenMonitor!

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        container = PersistenceController.makeContainer()
        PersistenceController.ensureDefaultStash(in: container.mainContext)

        appState = AppState(settings: SettingsStore(), container: container)

        dockObserver = DockObserver()
        appState.dockInfo = dockObserver.dockInfo

        panelController = PanelController(appState: appState, container: container)

        hoverEngine = HoverEngine(closeDelay: appState.settings.closeDelay)
        hoverEngine.panelFrameProvider = { [weak self] in
            guard let self, self.panelController.isVisible else { return nil }
            return self.panelController.frame
        }
        hoverEngine.onOpen = { [weak self] in self?.openPanel() }
        hoverEngine.onClose = { [weak self] in self?.closePanel() }

        hoverEngine.onEnteredPanel = { [weak self] in
            // Pointer moved into the open pocket → allow keyboard/search now.
            guard let self else { return }
            self.panelController.makeKey()
            self.appState.panelActivated = true
        }

        dragTriggerWindow = DragTriggerWindow()
        dragTriggerWindow.onDragEntered = { [weak self] in
            // A file drag reached the trigger zone — open so it can be dropped in.
            self?.hoverEngine.requestOpen() // → onOpen → openPanel()
        }

        installKeyboardMonitor()

        // Global shortcut (⌥Space) to toggle the pocket from anywhere.
        globalHotKey = GlobalHotKey()
        globalHotKey.onFire = { [weak self] in self?.togglePanel() }
        globalHotKey.register()

        // Suspend hover detection while a fullscreen app is frontmost.
        fullscreenMonitor = FullscreenMonitor()
        fullscreenMonitor.onChange = { [weak self] isFullscreen in
            self?.hoverEngine.isSuspended = isFullscreen
        }
        hoverEngine.isSuspended = fullscreenMonitor.isFullscreen

        refreshGeometry()
        hoverEngine.start()

        dockObserver.onChange = { [weak self] info in
            guard let self else { return }
            self.appState.dockInfo = info
            self.refreshGeometry()
        }
        dockObserver.start()

        onboardingController = OnboardingController(appState: appState)

        // Actions the tutorial, Settings, and menu can trigger.
        appState.onTogglePanel = { [weak self] in self?.togglePanel() }
        appState.onShowTutorial = { [weak self] in self?.onboardingController.show() }
        appState.onOpenSettings = { [weak self] in self?.openSettings() }
        appState.onSeedDefaultApps = { [weak self] in self?.seedDefaultApps() ?? 0 }

        menuBarController = MenuBarController(appState: appState)
        menuBarController.onTogglePanel = { [weak self] in self?.togglePanel() }
        menuBarController.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBarController.onShowTutorial = { [weak self] in self?.onboardingController.show() }

        observeSettings()

        // Test affordance: seed the pocket at launch when DOCKBARS_SEED_ON_LAUNCH=1.
        if ProcessInfo.processInfo.environment["DOCKBARS_SEED_ON_LAUNCH"] == "1" {
            let count = seedDefaultApps()
            NSLog("Dockbars ▸ seeded \(count) apps on launch (test hook)")
        }
        // Maintenance hook: unregister the login item and quit (cleans up test state).
        if ProcessInfo.processInfo.environment["DOCKBARS_UNREGISTER_LOGIN"] == "1" {
            try? LaunchAtLogin.setEnabled(false)
            UserDefaults.standard.set(false, forKey: "launchAtLogin")
            NSLog("Dockbars ▸ unregistered login item; quitting.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
            return
        }
        // Test affordance: open the pocket activated (keyboard/search) at launch.
        if ProcessInfo.processInfo.environment["DOCKBARS_ACTIVATE_ON_LAUNCH"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.togglePanel()
            }
        }

        logStartupDiagnostics()

        // First launch: request Accessibility and walk the user through setup.
        if !AccessibilityPermission.isTrusted {
            AccessibilityPermission.requestIfNeeded()
        }
        onboardingController.showIfFirstLaunch()
    }

    /// Adds a set of common apps to the default stash. Returns the number added.
    private func seedDefaultApps() -> Int {
        let context = container.mainContext
        guard let stash = try? context.fetch(FetchDescriptor<Stash>()).first else { return 0 }
        return DefaultAppsSeeder.seed(into: stash, context: context)
    }

    /// Emits a one-shot snapshot of the resolved state at launch. Invaluable when
    /// the app appears to "do nothing" — usually a missing Accessibility grant.
    private func logStartupDiagnostics() {
        let info = appState.dockInfo
        NSLog("""
        Dockbars ▸ launched. \
        accessibilityTrusted=\(AccessibilityPermission.isTrusted) \
        statusItemVisible=\(menuBarController != nil) \
        dock.orientation=\(info.orientation.rawValue) \
        dock.tileSize=\(info.tileSize) dock.autohide=\(info.autohide) \
        resolvedEdge=\(appState.resolvedEdge.rawValue) \
        screenFrame=\(NSStringFromRect(info.screenFrame)) \
        visibleFrame=\(NSStringFromRect(info.visibleFrame))
        """)
        if !AccessibilityPermission.isTrusted {
            NSLog("Dockbars ▸ Accessibility NOT granted — global hover detection is disabled. Grant it in System Settings ▸ Privacy & Security ▸ Accessibility. (The menu-bar 'Toggle Pocket' still works.)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hoverEngine?.stop()
        dockObserver?.stop()
    }

    // MARK: - Geometry

    /// Resolves the current placement from settings + Dock state + item count.
    /// Uses the given Dock info, defaulting to the app's cached (main-screen) one.
    private func currentPlacement(dockInfo: DockInfo? = nil) -> DockGeometry.PlacementResult {
        DockGeometry.placement(
            mode: appState.settings.placementMode,
            dockInfo: dockInfo ?? appState.dockInfo,
            preferredEdge: appState.settings.preferredEdge,
            iconSize: CGFloat(appState.settings.iconSize),
            itemCount: currentItemCount(),
            triggerThickness: CGFloat(appState.settings.triggerZoneWidth),
            margin: 8
        )
    }

    private func currentItemCount() -> Int {
        let context = container.mainContext
        guard let stash = try? context.fetch(FetchDescriptor<Stash>()).first else { return 0 }
        return stash.items.count
    }

    /// Recompute the trigger zone + panel layout. Called only when the Dock or
    /// settings change — never in the mouse-moved hot path.
    private func refreshGeometry() {
        let placement = currentPlacement()
        appState.resolvedEdge = placement.edge

        // Multi-monitor: a trigger strip on every screen (each computed from that
        // screen's own Dock info), so the pocket can be summoned on any display.
        let zones = NSScreen.screens.map { screen in
            currentPlacement(dockInfo: DockObserver.readDockInfo(for: screen)).triggerZone
        }
        hoverEngine.updateTriggerZones(zones.isEmpty ? [placement.triggerZone] : zones)
        dragTriggerWindow.update(frame: placement.triggerZone)

        panelController.configure(edge: placement.edge, size: placement.size)
        panelController.applyAppearance(appState.settings.theme.appearance)
        lastGridColumns = max(1, PanelLayout.columnsThatFit(width: placement.size.width,
                                                            iconSize: CGFloat(appState.settings.iconSize)))
    }

    // MARK: - Panel lifecycle

    /// Set just before requesting an open to mark whether the next open should be
    /// a key window (keyboard + search). Hover/drag opens leave it false.
    private var pendingActivated = false

    private func openPanel() {
        let activated = pendingActivated
        pendingActivated = false
        // Place on the screen the pointer is on (multi-monitor).
        let dockInfo = DockObserver.readDockInfo(for: DockObserver.screenUnderPointer())
        let placement = currentPlacement(dockInfo: dockInfo)
        appState.resolvedEdge = placement.edge
        panelController.show(edge: placement.edge, origin: placement.origin,
                             size: placement.size, reduceMotion: reduceMotion, activated: activated)
        appState.isPanelVisible = true
        appState.panelActivated = activated
        NSLog("Dockbars ▸ openPanel mode=\(appState.settings.placementMode.rawValue) edge=\(placement.edge.rawValue) activated=\(activated) overflowed=\(placement.overflowed) frame=\(NSStringFromRect(CGRect(origin: placement.origin, size: placement.size)))")
    }

    private func closePanel() {
        panelController.hide(reduceMotion: reduceMotion)
        appState.isPanelVisible = false
        appState.panelActivated = false
        appState.searchQuery = ""
        appState.highlightedIndex = 0
        NSLog("Dockbars ▸ closePanel")
    }

    private func togglePanel() {
        if panelController.isVisible {
            hoverEngine.requestClose()
        } else {
            pendingActivated = true // menu-invoked → enable keyboard/search
            hoverEngine.requestOpen()
        }
    }

    // MARK: - Keyboard

    /// A local key monitor drives search + navigation while the pocket is a key
    /// window. Kept out of SwiftUI focus so it never interferes with drag & drop.
    private func installKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard appState.isPanelVisible, appState.panelActivated else { return event }
        let items = filteredItems()

        // ⌘1–9 → switch stash.
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers, let digit = Int(chars), (1...9).contains(digit) {
            if digit - 1 < stashCount() {
                appState.selectedStashIndex = digit - 1
                appState.searchQuery = ""
                appState.highlightedIndex = 0
            }
            return nil
        }
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            return event
        }

        switch event.keyCode {
        case 53: // Escape
            if !appState.searchQuery.isEmpty {
                appState.searchQuery = ""; appState.highlightedIndex = 0
            } else {
                hoverEngine.requestClose()
            }
            return nil
        case 36, 76: // Return / keypad Enter
            if let item = items[safe: appState.highlightedIndex], let url = item.resolvedURL {
                NSWorkspace.shared.open(url)
                hoverEngine.requestClose()
            }
            return nil
        case 123: moveHighlight(-1, count: items.count); return nil          // left
        case 124: moveHighlight(1, count: items.count); return nil           // right
        case 126: moveHighlight(-lastGridColumns, count: items.count); return nil // up
        case 125: moveHighlight(lastGridColumns, count: items.count); return nil  // down
        case 51: // Delete / Backspace
            if !appState.searchQuery.isEmpty { appState.searchQuery.removeLast(); appState.highlightedIndex = 0 }
            return nil
        default:
            if let chars = event.characters, chars.count == 1,
               let scalar = chars.unicodeScalars.first, scalar.value >= 32 {
                appState.searchQuery.append(chars)
                appState.highlightedIndex = 0
                return nil
            }
            return event
        }
    }

    private func moveHighlight(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        appState.highlightedIndex = min(max(appState.highlightedIndex + delta, 0), count - 1)
    }

    /// Current stash's items after the search filter (mirrors the panel view).
    private func filteredItems() -> [StashItem] {
        let context = container.mainContext
        let stashes = (try? context.fetch(FetchDescriptor<Stash>(sortBy: [SortDescriptor(\.order)]))) ?? []
        guard !stashes.isEmpty else { return [] }
        let index = min(max(appState.selectedStashIndex, 0), stashes.count - 1)
        let items = stashes[index].items.sorted { $0.order < $1.order }
        let query = appState.searchQuery
        return query.isEmpty ? items : items.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    private func stashCount() -> Int {
        let context = container.mainContext
        return (try? context.fetchCount(FetchDescriptor<Stash>())) ?? 0
    }

    // MARK: - Settings

    private func openSettings() {
        appState.refreshAccessibilityStatus()
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appState: appState)
        }
        settingsWindowController?.show()
    }

    private func observeSettings() {
        // React to any settings change: re-derive geometry and push the delay.
        settingsCancellable = appState.settings.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.hoverEngine.updateCloseDelay(self.appState.settings.closeDelay)
                    self.refreshGeometry()
                }
            }
    }
}
