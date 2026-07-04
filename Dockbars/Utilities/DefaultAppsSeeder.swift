import Foundation
import SwiftData

/// Seeds a stash with a handful of common apps so the pocket isn't empty on
/// first run. Only adds apps that actually exist and aren't already present.
enum DefaultAppsSeeder {
    private static let candidatePaths = [
        "/System/Library/CoreServices/Finder.app",
        "/Applications/Safari.app",
        "/System/Applications/Mail.app",
        "/System/Applications/Notes.app",
        "/System/Applications/System Settings.app",
        "/System/Applications/Music.app",
        "/System/Applications/Utilities/Terminal.app",
    ]

    @discardableResult
    @MainActor
    static func seed(into stash: Stash, context: ModelContext) -> Int {
        let fileManager = FileManager.default
        let existing = Set(stash.items.map(\.urlString))
        var order = (stash.items.map(\.order).max() ?? -1) + 1
        var added = 0

        for path in candidatePaths where fileManager.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            guard !existing.contains(url.absoluteString) else { continue }
            let bookmark = try? url.bookmarkData(options: .minimalBookmark,
                                                 includingResourceValuesForKeys: nil,
                                                 relativeTo: nil)
            let item = StashItem(
                displayName: url.deletingPathExtension().lastPathComponent,
                urlString: url.absoluteString,
                bookmarkData: bookmark,
                order: order
            )
            item.stash = stash
            context.insert(item)
            order += 1
            added += 1
        }
        try? context.save()
        return added
    }
}
