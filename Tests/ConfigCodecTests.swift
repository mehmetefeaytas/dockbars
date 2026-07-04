import XCTest
import SwiftData
@testable import Dockbars

@MainActor
final class ConfigCodecTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Stash.self, StashItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testExportImportRoundTripReplace() throws {
        let context = try makeContext()

        let work = Stash(name: "Work", order: 0)
        context.insert(work)
        let safari = StashItem(displayName: "Safari", urlString: "file:///Applications/Safari.app",
                               order: 0, kind: .file)
        safari.isPinned = true
        safari.stash = work
        context.insert(safari)
        let site = StashItem(displayName: "example", urlString: "https://example.com",
                             order: 1, kind: .url)
        site.stash = work
        context.insert(site)
        try context.save()

        let data = try XCTUnwrap(ConfigCodec.export(from: context))

        // Import with replace into a fresh context.
        let context2 = try makeContext()
        XCTAssertTrue(ConfigCodec.import(data, into: context2, replace: true))

        let stashes = try context2.fetch(FetchDescriptor<Stash>(sortBy: [SortDescriptor(\.order)]))
        XCTAssertEqual(stashes.count, 1)
        XCTAssertEqual(stashes[0].name, "Work")

        let items = stashes[0].items.sorted { $0.order < $1.order }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].displayName, "Safari")
        XCTAssertTrue(items[0].isPinned)
        XCTAssertEqual(items[0].kind, .file)
        XCTAssertEqual(items[1].kind, .url)
        XCTAssertEqual(items[1].urlString, "https://example.com")
    }

    func testImportMergeAppendsWithoutDeleting() throws {
        let context = try makeContext()
        let existing = Stash(name: "Existing", order: 0)
        context.insert(existing)
        try context.save()

        let payload = ConfigExport(stashes: [
            ConfigExport.StashExport(name: "Imported", order: 0, items: [])
        ])
        let data = try JSONEncoder().encode(payload)

        XCTAssertTrue(ConfigCodec.import(data, into: context, replace: false))
        let names = try context.fetch(FetchDescriptor<Stash>()).map(\.name).sorted()
        XCTAssertEqual(names, ["Existing", "Imported"])
    }

    func testImportRejectsInvalidJSON() throws {
        let context = try makeContext()
        XCTAssertFalse(ConfigCodec.import(Data("not json".utf8), into: context, replace: false))
    }
}
