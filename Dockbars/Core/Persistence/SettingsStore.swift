import Foundation
import Combine

/// User-facing settings, backed by UserDefaults.
///
/// The spec lists settings under SwiftData; we keep them in UserDefaults instead —
/// it is the idiomatic store for lightweight app preferences and binds cleanly to
/// SwiftUI controls. Stashes and items live in SwiftData (see Models.swift).
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let placementMode = "placementMode"
        static let theme = "panelTheme"
        static let edge = "preferredEdge"
        static let closeDelay = "closeDelay"
        static let triggerZoneWidth = "triggerZoneWidth"
        static let iconSize = "iconSize"
        static let launchAtLogin = "launchAtLogin"
        static let showRunningApps = "showRunningApps"
    }

    private let defaults: UserDefaults

    /// How the pocket positions itself. Defaults to beside-the-Dock.
    @Published var placementMode: PlacementMode {
        didSet { defaults.set(placementMode.rawValue, forKey: Keys.placementMode) }
    }
    /// Appearance applied to the pocket panel.
    @Published var theme: PanelTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published var preferredEdge: PanelEdge {
        didSet { defaults.set(preferredEdge.rawValue, forKey: Keys.edge) }
    }
    /// Seconds to wait after the pointer leaves before closing the pocket.
    @Published var closeDelay: Double {
        didSet { defaults.set(closeDelay, forKey: Keys.closeDelay) }
    }
    /// Thickness (px) of the hover trigger strip along the screen edge.
    @Published var triggerZoneWidth: Double {
        didSet { defaults.set(triggerZoneWidth, forKey: Keys.triggerZoneWidth) }
    }
    /// Icon edge length (px). Phase 1 range: 32–64.
    @Published var iconSize: Double {
        didSet { defaults.set(iconSize, forKey: Keys.iconSize) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            try? LaunchAtLogin.setEnabled(launchAtLogin)
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }
    /// Show a live section of running apps not already in the pocket.
    @Published var showRunningApps: Bool {
        didSet { defaults.set(showRunningApps, forKey: Keys.showRunningApps) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        placementMode = PlacementMode(rawValue: defaults.string(forKey: Keys.placementMode) ?? "") ?? .dockAdjacent
        theme = PanelTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        preferredEdge = PanelEdge(rawValue: defaults.string(forKey: Keys.edge) ?? "") ?? .right
        closeDelay = (defaults.object(forKey: Keys.closeDelay) as? Double) ?? 0.25
        triggerZoneWidth = (defaults.object(forKey: Keys.triggerZoneWidth) as? Double) ?? 4
        iconSize = (defaults.object(forKey: Keys.iconSize) as? Double) ?? 48
        launchAtLogin = LaunchAtLogin.isEnabled
        showRunningApps = defaults.bool(forKey: Keys.showRunningApps)
    }
}
