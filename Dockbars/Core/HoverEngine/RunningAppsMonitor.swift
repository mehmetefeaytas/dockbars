import AppKit
import Combine

/// Publishes the list of regular running apps (excluding Dockbars itself),
/// updated live as apps launch and quit.
@MainActor
final class RunningAppsMonitor: ObservableObject {
    @Published private(set) var apps: [NSRunningApplication] = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            center.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func refresh() {
        let mine = Bundle.main.bundleIdentifier
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != mine }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
