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
    private var panelController: PanelController!
    private var menuBarController: MenuBarController!
    private var settingsWindowController: SettingsWindowController?
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

        refreshGeometry()
        hoverEngine.start()

        dockObserver.onChange = { [weak self] info in
            guard let self else { return }
            self.appState.dockInfo = info
            self.refreshGeometry()
        }
        dockObserver.start()

        menuBarController = MenuBarController(appState: appState)
        menuBarController.onTogglePanel = { [weak self] in self?.togglePanel() }
        menuBarController.onOpenSettings = { [weak self] in self?.openSettings() }

        observeSettings()

        // First-launch onboarding for the Accessibility permission.
        if !AccessibilityPermission.isTrusted {
            AccessibilityPermission.requestIfNeeded()
            OnboardingController.showAccessibilityPrompt()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hoverEngine?.stop()
        dockObserver?.stop()
    }

    // MARK: - Geometry

    /// Recompute the trigger zone + panel layout. Called only when the Dock or
    /// settings change — never in the mouse-moved hot path.
    private func refreshGeometry() {
        let info = appState.dockInfo
        let edge = DockGeometry.resolveEdge(
            preferred: appState.settings.preferredEdge,
            orientation: info.orientation
        )
        appState.resolvedEdge = edge

        let size = PanelLayout.panelSize(edge: edge, iconSize: CGFloat(appState.settings.iconSize))
        let zone = DockGeometry.triggerZone(
            edge: edge,
            screenFrame: info.screenFrame,
            thickness: CGFloat(appState.settings.triggerZoneWidth)
        )
        hoverEngine.updateTriggerZone(zone)
        panelController.configure(edge: edge, size: size)
    }

    // MARK: - Panel lifecycle

    private func openPanel() {
        let info = appState.dockInfo
        let edge = appState.resolvedEdge
        let size = PanelLayout.panelSize(edge: edge, iconSize: CGFloat(appState.settings.iconSize))
        let origin = DockGeometry.panelOrigin(edge: edge, panelSize: size, visibleFrame: info.visibleFrame)
        panelController.show(edge: edge, origin: origin, size: size, reduceMotion: reduceMotion)
        appState.isPanelVisible = true
    }

    private func closePanel() {
        panelController.hide(reduceMotion: reduceMotion)
        appState.isPanelVisible = false
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
