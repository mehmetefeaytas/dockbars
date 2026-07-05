import AppKit
import Combine
import SwiftData

/// Single source of truth shared between the AppKit layer and SwiftUI views.
@MainActor
final class AppState: ObservableObject {
    let settings: SettingsStore
    let container: ModelContainer

    /// Latest Dock configuration (position, size, autohide).
    @Published var dockInfo: DockInfo
    /// The edge the pocket currently attaches to, after reconciling the user's
    /// preference against the Dock's orientation.
    @Published var resolvedEdge: PanelEdge = .right
    @Published var isPanelVisible = false
    @Published var accessibilityTrusted: Bool

    /// Index of the currently shown stash (Phase 2 multi-stash).
    @Published var selectedStashIndex = 0
    /// Name of the current stash, mirrored for the menu-bar label.
    @Published var currentStashName = ""
    /// False when the chosen global shortcut couldn't be registered (in use).
    @Published var hotKeyRegistered = true
    /// True when the pocket is a key window (keyboard + search enabled).
    @Published var panelActivated = false
    /// Live search query (driven by the keyboard monitor).
    @Published var searchQuery = ""
    /// Highlighted item index for keyboard navigation.
    @Published var highlightedIndex = 0

    /// Shared clipboard history monitor (enabled per settings).
    let clipboard = ClipboardMonitor()

    // Actions wired by AppDelegate so SwiftUI views and menus can drive behavior.
    var onTogglePanel: (() -> Void)?
    var onShowTutorial: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onSeedDefaultApps: (() -> Int)?
    var onExportConfig: (() -> Void)?
    var onImportConfig: (() -> Void)?

    /// Shared profile store (settings snapshots switchable from the menu bar).
    let profiles = ProfileStore()

    init(settings: SettingsStore, container: ModelContainer) {
        self.settings = settings
        self.container = container
        self.dockInfo = DockObserver.readDockInfo()
        self.accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }
}
