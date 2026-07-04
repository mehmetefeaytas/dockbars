import AppKit

/// Owns the first-run tutorial: decides whether to show it on launch and can
/// re-open it on demand (from the menu bar or Settings).
@MainActor
final class OnboardingController {
    private enum Keys {
        static let completed = "didCompleteOnboarding"
    }

    private let appState: AppState
    private var windowController: TutorialWindowController?

    init(appState: AppState) {
        self.appState = appState
    }

    var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: Keys.completed)
    }

    func showIfFirstLaunch() {
        guard !hasCompleted else { return }
        show()
    }

    func show() {
        if windowController == nil {
            windowController = TutorialWindowController(appState: appState)
            windowController?.onClose = {
                UserDefaults.standard.set(true, forKey: Keys.completed)
            }
        }
        windowController?.show()
    }
}
