import Foundation
import SwiftData

/// A named collection of pocket items. Phase 1 uses a single default stash;
/// multiple stashes arrive in Phase 2.
@Model
final class Stash {
    var name: String
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \StashItem.stash)
    var items: [StashItem]

    init(name: String, order: Int = 0) {
        self.name = name
        self.order = order
        self.items = []
    }
}

/// A single item in a stash. The target is stored as both a URL string and a
/// (sandbox-agnostic) bookmark so we can still resolve files that move.
@Model
final class StashItem {
    var displayName: String
    var urlString: String
    var bookmarkData: Data?
    var order: Int
    var stash: Stash?

    init(displayName: String, urlString: String, bookmarkData: Data? = nil, order: Int = 0) {
        self.displayName = displayName
        self.urlString = urlString
        self.bookmarkData = bookmarkData
        self.order = order
    }

    /// Resolves the current on-disk URL, preferring bookmark data (survives moves).
    var resolvedURL: URL? {
        if let bookmarkData {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData,
                                  options: [.withoutUI],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                return url
            }
        }
        return URL(string: urlString)
    }
}
