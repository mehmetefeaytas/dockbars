import AppKit
import Combine

/// A lightweight, self-contained record of an opened item, kept so recents
/// survive even if the source item is removed from its stash.
struct RecentRecord: Codable, Identifiable, Equatable {
    var displayName: String
    var urlString: String
    var kindRaw: String
    var payload: String?

    var id: String { "\(kindRaw):\(urlString)" }
    var kind: StashItemKind { StashItemKind(rawValue: kindRaw) ?? .file }
}

/// Tracks recently opened items (most-recent-first), persisted in UserDefaults.
/// Local-only; no timestamps leave the machine.
@MainActor
final class RecentTracker: ObservableObject {
    static let shared = RecentTracker()

    private let key = "recentItems"
    private let limit = 50
    @Published private(set) var records: [RecentRecord] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([RecentRecord].self, from: data) {
            records = decoded
        }
    }

    func record(_ item: StashItem) {
        let record = RecentRecord(displayName: item.displayName, urlString: item.urlString,
                                  kindRaw: item.kindRaw, payload: item.payload)
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        if records.count > limit { records.removeLast(records.count - limit) }
        persist()
    }

    func clear() {
        records.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
