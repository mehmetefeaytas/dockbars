import SwiftUI

/// Preferences: edge, close delay, trigger width, icon size, launch at login,
/// plus the Accessibility permission status.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private var allowedEdges: [PanelEdge] {
        DockGeometry.allowedEdges(for: appState.dockInfo.orientation)
    }

    var body: some View {
        Form {
            Section("Pocket") {
                Picker("Edge", selection: $settings.preferredEdge) {
                    ForEach(allowedEdges) { edge in
                        Text(edge.displayName).tag(edge)
                    }
                }
                .help("Which screen edge the pocket opens from. Options depend on your Dock position.")

                HStack {
                    Text("Icon size")
                    Slider(value: $settings.iconSize, in: 32...64, step: 4)
                    Text("\(Int(settings.iconSize)) px")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }

            Section("Behavior") {
                HStack {
                    Text("Close delay")
                    Slider(value: $settings.closeDelay, in: 0...1, step: 0.05)
                    Text(String(format: "%.2f s", settings.closeDelay))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                HStack {
                    Text("Trigger width")
                    Slider(value: $settings.triggerZoneWidth, in: 1...12, step: 1)
                    Text("\(Int(settings.triggerZoneWidth)) px")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: appState.accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(appState.accessibilityTrusted ? .green : .orange)
                    Text(appState.accessibilityTrusted
                         ? "Accessibility access granted"
                         : "Accessibility access required for hover detection")
                    Spacer()
                    if !appState.accessibilityTrusted {
                        Button("Open Settings") {
                            AccessibilityPermission.openSystemSettings()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
    }
}
