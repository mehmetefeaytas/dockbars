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
    /// True when the pocket is a key window (keyboard + search enabled).
    @Published var panelActivated = false
    /// Live search query (driven by the keyboard monitor).
    @Published var searchQuery = ""
    /// Highlighted item index for keyboard navigation.
    @Published var highlightedIndex = 0

    // Actions wired by AppDelegate so SwiftUI views and menus can drive behavior.
    var onTogglePanel: (() -> Void)?
    var onShowTutorial: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onSeedDefaultApps: (() -> Int)?

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
