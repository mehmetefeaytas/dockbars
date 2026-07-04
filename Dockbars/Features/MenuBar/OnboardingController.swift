import AppKit

/// First-launch guidance for the Accessibility permission. Shows a one-time
/// alert explaining why the permission is needed and how to grant it.
@MainActor
enum OnboardingController {
    private static let shownKey = "didShowAccessibilityOnboarding"

    static func showAccessibilityPrompt(force: Bool = false) {
        let defaults = UserDefaults.standard
        if !force && defaults.bool(forKey: shownKey) { return }
        defaults.set(true, forKey: shownKey)

        let alert = NSAlert()
        alert.messageText = "Enable Accessibility for Dockbars"
        alert.informativeText = """
        Dockbars watches for your pointer reaching the Dock edge to open the hidden pocket. \
        macOS requires Accessibility access for this.

        Open System Settings → Privacy & Security → Accessibility and enable Dockbars.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        NSApp.setActivationPolicy(.accessory)

        if response == .alertFirstButtonReturn {
            AccessibilityPermission.openSystemSettings()
        }
    }
}
