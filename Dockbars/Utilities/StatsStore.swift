import Foundation

/// Local-only open counts per item, for a "most opened" list. Nothing leaves
/// the Mac. Keyed by "kind:urlString" so it survives item removal/re-add.
@MainActor
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    private let key = "openCounts"
    private let namesKey = "openNames"
    @Published private(set) var counts: [String: Int] = [:]
    private var names: [String: String] = [:]

    private init() {
        counts = (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
        names = (UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String]) ?? [:]
    }

    func record(_ item: StashItem) {
        let id = "\(item.kindRaw):\(item.urlString)"
        counts[id, default: 0] += 1
        names[id] = item.displayName
        persist()
    }

    /// Top items as (name, count), most-opened first.
    func top(_ limit: Int = 10) -> [(name: String, count: Int)] {
        counts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (names[$0.key] ?? $0.key, $0.value) }
    }

    func clear() {
        counts.removeAll(); names.removeAll(); persist()
    }

    private func persist() {
        UserDefaults.standard.set(counts, forKey: key)
        UserDefaults.standard.set(names, forKey: namesKey)
    }
}
