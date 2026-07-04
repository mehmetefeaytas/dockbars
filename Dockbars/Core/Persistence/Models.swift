import Foundation
import SwiftData

/// What a stash item points to.
enum StashItemKind: String, Codable, CaseIterable {
    case file      // app, document, folder, alias (file URL)
    case url       // website / any openable URL
    case shortcut  // Apple Shortcut, run by name
    case script    // shell script
}

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
    /// Item type (defaulted for lightweight migration of existing file items).
    var kindRaw: String = StashItemKind.file.rawValue
    /// Extra data: the Shortcut name or the shell script body.
    var payload: String?
    /// Pinned items sort to the front of their stash.
    var isPinned: Bool = false
    var stash: Stash?

    init(displayName: String, urlString: String, bookmarkData: Data? = nil,
         order: Int = 0, kind: StashItemKind = .file, payload: String? = nil) {
        self.displayName = displayName
        self.urlString = urlString
        self.bookmarkData = bookmarkData
        self.order = order
        self.kindRaw = kind.rawValue
        self.payload = payload
    }

    var kind: StashItemKind { StashItemKind(rawValue: kindRaw) ?? .file }

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
