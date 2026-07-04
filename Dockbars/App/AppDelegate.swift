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

        dragTriggerWindow = DragTriggerWindow()
        dragTriggerWindow.onDragEntered = { [weak self] in
            // A file drag reached the trigger zone — open so it can be dropped in.
            self?.hoverEngine.requestOpen() // → onOpen → openPanel()
        }

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
    private func currentPlacement() -> DockGeometry.PlacementResult {
        DockGeometry.placement(
            mode: appState.settings.placementMode,
            dockInfo: appState.dockInfo,
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
        hoverEngine.updateTriggerZone(placement.triggerZone)
        dragTriggerWindow.update(frame: placement.triggerZone)
        panelController.configure(edge: placement.edge, size: placement.size)
        panelController.applyAppearance(appState.settings.theme.appearance)
    }

    // MARK: - Panel lifecycle

    private func openPanel() {
        let placement = currentPlacement()
        appState.resolvedEdge = placement.edge
        panelController.show(edge: placement.edge, origin: placement.origin,
                             size: placement.size, reduceMotion: reduceMotion)
        appState.isPanelVisible = true
        NSLog("Dockbars ▸ openPanel mode=\(appState.settings.placementMode.rawValue) edge=\(placement.edge.rawValue) overflowed=\(placement.overflowed) frame=\(NSStringFromRect(CGRect(origin: placement.origin, size: placement.size)))")
    }

    private func closePanel() {
        panelController.hide(reduceMotion: reduceMotion)
        appState.isPanelVisible = false
        NSLog("Dockbars ▸ closePanel")
    }

    private func togglePanel() {
        if panelController.isVisible {
            hoverEngine.requestClose()
        } else {
            hoverEngine.requestOpen()
        }
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
