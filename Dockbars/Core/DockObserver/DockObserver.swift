import AppKit

/// Watches the Dock's configuration (position, tile size, autohide) and the
/// screen layout, publishing a fresh `DockInfo` whenever anything changes.
@MainActor
final class DockObserver {
    private(set) var dockInfo: DockInfo
    var onChange: ((DockInfo) -> Void)?

    init() {
        dockInfo = DockObserver.readDockInfo()
    }

    func start() {
        // The Dock posts this distributed notification when its prefs change.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(dockPrefsChanged),
            name: NSNotification.Name("com.apple.dock.prefchanged"),
            object: nil
        )
        // Screen arrangement / resolution changes also affect our geometry.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func dockPrefsChanged() {
        reload()
    }

    @objc private func screenParametersChanged() {
        reload()
    }

    private func reload() {
        let updated = DockObserver.readDockInfo()
        guard updated != dockInfo else { return }
        dockInfo = updated
        onChange?(updated)
    }

    /// Reads the live Dock configuration. Works without App Sandbox.
    static func readDockInfo() -> DockInfo {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let orientationRaw = dockDefaults?.string(forKey: "orientation") ?? "bottom"
        let orientation = DockInfo.Orientation(rawValue: orientationRaw) ?? .bottom

        let tileSize = dockDefaults?.object(forKey: "tilesize") as? Double ?? 48
        let autohide = dockDefaults?.bool(forKey: "autohide") ?? false

        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return .fallback }

        return DockInfo(
            orientation: orientation,
            tileSize: CGFloat(tileSize),
            autohide: autohide,
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
