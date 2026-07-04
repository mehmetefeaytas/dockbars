import Foundation
import SwiftData

/// Codable snapshot of the whole configuration (stashes + items), for JSON
/// export/import. File paths are machine-specific; this is a definitions export.
struct ConfigExport: Codable {
    struct Item: Codable {
        var displayName: String
        var urlString: String
        var kindRaw: String
        var payload: String?
        var isPinned: Bool
        var order: Int
    }
    struct StashExport: Codable {
        var name: String
        var order: Int
        var items: [Item]
    }
    var version = 1
    var stashes: [StashExport]
}

/// Serializes and restores the SwiftData config. Pure enough to unit-test the
/// round-trip via the two static transform helpers.
enum ConfigCodec {
    @MainActor
    static func export(from context: ModelContext) -> Data? {
        let stashes = (try? context.fetch(FetchDescriptor<Stash>(sortBy: [SortDescriptor(\.order)]))) ?? []
        let payload = ConfigExport(stashes: stashes.map(stashExport))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(payload)
    }

    @MainActor
    static func stashExport(_ stash: Stash) -> ConfigExport.StashExport {
        ConfigExport.StashExport(
            name: stash.name,
            order: stash.order,
            items: stash.items
                .sorted { $0.order < $1.order }
                .map { ConfigExport.Item(displayName: $0.displayName, urlString: $0.urlString,
                                         kindRaw: $0.kindRaw, payload: $0.payload,
                                         isPinned: $0.isPinned, order: $0.order) }
        )
    }

    @MainActor
    @discardableResult
    static func `import`(_ data: Data, into context: ModelContext, replace: Bool) -> Bool {
        guard let config = try? JSONDecoder().decode(ConfigExport.self, from: data) else { return false }

        if replace {
            let existing = (try? context.fetch(FetchDescriptor<Stash>())) ?? []
            existing.forEach { context.delete($0) }
        }
        var stashOrder = replace ? 0 : ((try? context.fetchCount(FetchDescriptor<Stash>())) ?? 0)
        for stashExport in config.stashes {
            let stash = Stash(name: stashExport.name, order: stashOrder)
            stashOrder += 1
            context.insert(stash)
            for itemExport in stashExport.items {
                let item = StashItem(displayName: itemExport.displayName, urlString: itemExport.urlString,
                                     order: itemExport.order,
                                     kind: StashItemKind(rawValue: itemExport.kindRaw) ?? .file,
                                     payload: itemExport.payload)
                item.isPinned = itemExport.isPinned
                item.stash = stash
                context.insert(item)
            }
        }
        try? context.save()
        return true
    }
}
