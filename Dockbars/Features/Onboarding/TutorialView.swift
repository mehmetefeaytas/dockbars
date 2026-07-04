import SwiftUI

/// Multi-step first-run walkthrough: what Dockbars is, granting Accessibility,
/// choosing the edge, and how to use the pocket (with live "try it" actions).
struct TutorialView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settings: SettingsStore
    var onFinish: () -> Void

    @State private var step = 0
    @State private var seedMessage: String?

    init(settings: SettingsStore, onFinish: @escaping () -> Void) {
        self.settings = settings
        self.onFinish = onFinish
    }

    private let stepCount = 4

    private var allowedEdges: [PanelEdge] {
        DockGeometry.allowedEdges(for: appState.dockInfo.orientation)
    }

    private var edgeLabel: String {
        DockGeometry.resolveEdge(preferred: settings.preferredEdge,
                                 orientation: appState.dockInfo.orientation)
            .displayName.lowercased()
    }

    /// Where the user should push the pointer, phrased per placement mode.
    private var hoverHint: String {
        switch settings.placementMode {
        case .dockAdjacent:
            switch appState.dockInfo.orientation {
            case .bottom: return "bottom-left corner, next to the Dock"
            case .left: return "left edge, next to the Dock"
            case .right: return "right edge, next to the Dock"
            }
        case .screenEdge:
            return "\(edgeLabel) edge"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)

            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 520, height: 440)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: accessibilityStep
        case 2: edgeStep
        default: usageStep
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        stepScaffold(
            symbol: "tray.full.fill",
            title: "Welcome to Dockbars",
            subtitle: "A hidden pocket for your Dock."
        ) {
            Text("Move your pointer to the edge of the screen and a panel of your favorite apps and files slides out — a natural extension of your Dock, not a replacement.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Label("Local-first. No network, no telemetry — everything stays on your Mac.",
                  systemImage: "lock.shield")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var accessibilityStep: some View {
        stepScaffold(
            symbol: appState.accessibilityTrusted ? "checkmark.shield.fill" : "hand.raised.fill",
            title: "Enable Accessibility",
            subtitle: "Required to detect your pointer at the Dock edge."
        ) {
            Text("macOS requires Accessibility access for Dockbars to watch for your pointer and read the Dock's position. Dockbars requests no network access.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if appState.accessibilityTrusted {
                Label("Access granted — you're all set.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                Button {
                    AccessibilityPermission.requestIfNeeded()
                    AccessibilityPermission.openSystemSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .controlSize(.large)
                Text("Enable **Dockbars** under Privacy & Security ▸ Accessibility. This window updates automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var edgeStep: some View {
        stepScaffold(
            symbol: "rectangle.righthalf.inset.filled",
            title: "Where should it open?",
            subtitle: "Your Dock is at the \(appState.dockInfo.orientation.rawValue)."
        ) {
            Picker("", selection: $settings.placementMode) {
                ForEach(PlacementMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)

            Text(settings.placementMode.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if settings.placementMode == .screenEdge {
                Picker("", selection: $settings.preferredEdge) {
                    ForEach(allowedEdges) { edge in
                        Text(edge.displayName).tag(edge)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            Text("You can change this anytime in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var usageStep: some View {
        stepScaffold(
            symbol: "cursorarrow.rays",
            title: "How to use it",
            subtitle: "Hover the \(hoverHint) to reveal the pocket."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                usageRow("cursorarrow.motionlines", "Push your pointer to the **\(hoverHint)** — the pocket slides out.")
                usageRow("plus.rectangle.on.folder", "Drag apps or files in from Finder, Launchpad, or the Dock.")
                usageRow("hand.tap", "Click an item to open it; right-click for more.")
                usageRow("menubar.arrow.up.rectangle", "Use the menu-bar icon to toggle the pocket or open Settings.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button {
                    let count = appState.onSeedDefaultApps?() ?? 0
                    seedMessage = count > 0 ? "Added \(count) apps to your pocket." : "Your common apps are already added."
                } label: {
                    Label("Add my common apps", systemImage: "sparkles")
                }
                Button {
                    appState.onTogglePanel?()
                } label: {
                    Label("Open pocket now", systemImage: "eye")
                }
            }
            .controlSize(.regular)

            if let seedMessage {
                Text(seedMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func usageRow(_ symbol: String, _ markdown: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(.tint)
            Text(.init(markdown))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Scaffold & footer

    private func stepScaffold<Body: View>(
        symbol: String, title: String, subtitle: String,
        @ViewBuilder body: () -> Body
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(title).font(.title2).bold()
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 4)
            body()
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack {
            Button("Back") { step -= 1 }
                .disabled(step == 0)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            if step < stepCount - 1 {
                Button("Next") { step += 1 }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Get Started") { onFinish() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
