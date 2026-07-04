import SwiftUI

/// Preferences: edge, close delay, trigger width, icon size, launch at login,
/// plus the Accessibility permission status.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settings: SettingsStore
    @State private var seedMessage: String?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private var allowedEdges: [PanelEdge] {
        DockGeometry.allowedEdges(for: appState.dockInfo.orientation)
    }

    var body: some View {
        Form {
            Section("Pocket") {
                Picker("Placement", selection: $settings.placementMode) {
                    ForEach(PlacementMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .help(settings.placementMode.detail)

                Text(settings.placementMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.placementMode == .screenEdge {
                    Picker("Edge", selection: $settings.preferredEdge) {
                        ForEach(allowedEdges) { edge in
                            Text(edge.displayName).tag(edge)
                        }
                    }
                    .help("Which screen edge the pocket opens from. Options depend on your Dock position.")
                }

                Picker("Theme", selection: $settings.theme) {
                    ForEach(PanelTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }

                HStack {
                    Text("Icon size")
                    Slider(value: $settings.iconSize, in: 16...128, step: 4)
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
                Toggle("List view", isOn: $settings.useListView)
                Toggle("Show recently used", isOn: $settings.showRecent)
                Toggle("Show running apps", isOn: $settings.showRunningApps)
                Toggle("Clipboard history", isOn: $settings.clipboardHistory)
                Toggle("Show widgets", isOn: $settings.showWidgets)
            }

            Section("Getting Started") {
                Button {
                    appState.onShowTutorial?()
                } label: {
                    Label("Show Tutorial", systemImage: "graduationcap")
                }
                Button {
                    appState.onTogglePanel?()
                } label: {
                    Label("Open Pocket Now", systemImage: "eye")
                }
                Button {
                    let count = appState.onSeedDefaultApps?() ?? 0
                    seedMessage = count > 0 ? "Added \(count) apps." : "Common apps already added."
                } label: {
                    Label("Add Common Apps", systemImage: "sparkles")
                }
                if let seedMessage {
                    Text(seedMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Data") {
                Button {
                    appState.onExportConfig?()
                } label: {
                    Label("Export Configuration…", systemImage: "square.and.arrow.up")
                }
                Button {
                    appState.onImportConfig?()
                } label: {
                    Label("Import Configuration…", systemImage: "square.and.arrow.down")
                }
            }

            Section("Most Opened") {
                let top = StatsStore.shared.top(10)
                if top.isEmpty {
                    Text("No opens recorded yet.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(top.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(entry.name).lineLimit(1)
                            Spacer()
                            Text("\(entry.count)×").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    Button("Clear Statistics") { StatsStore.shared.clear() }
                        .font(.caption)
                }
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
