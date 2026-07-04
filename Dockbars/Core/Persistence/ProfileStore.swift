import Foundation
import Combine

/// A snapshot of the appearance/layout settings a profile captures. Stash
/// contents are shared; a profile changes how the pocket looks and behaves
/// (e.g. Work vs. Presentation), switchable from the menu bar.
struct SettingsSnapshot: Codable, Equatable {
    var placementMode: String
    var theme: String
    var preferredEdge: String
    var iconSize: Double
    var useListView: Bool
    var showRecent: Bool
    var showRunningApps: Bool
    var clipboardHistory: Bool
    var showWidgets: Bool
}

struct Profile: Codable, Identifiable, Equatable {
    var name: String
    var settings: SettingsSnapshot
    var id: String { name }
}

/// Persists named profiles and the active one in UserDefaults (local only).
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var activeName: String?

    private let defaults: UserDefaults
    private let profilesKey = "profiles"
    private let activeKey = "activeProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = decoded
        }
        activeName = defaults.string(forKey: activeKey)
    }

    func save(_ profile: Profile) {
        profiles.removeAll { $0.name == profile.name }
        profiles.append(profile)
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persist()
    }

    func delete(named name: String) {
        profiles.removeAll { $0.name == name }
        if activeName == name { activeName = nil; defaults.removeObject(forKey: activeKey) }
        persist()
    }

    func setActive(_ name: String?) {
        activeName = name
        if let name { defaults.set(name, forKey: activeKey) } else { defaults.removeObject(forKey: activeKey) }
    }

    func profile(named name: String) -> Profile? {
        profiles.first { $0.name == name }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: profilesKey)
        }
    }
}
