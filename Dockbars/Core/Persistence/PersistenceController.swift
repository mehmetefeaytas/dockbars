import Foundation
import SwiftData

/// Builds the SwiftData container and seeds a default stash on first run.
@MainActor
enum PersistenceController {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Stash.self, StashItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A corrupt store should not brick the app; fall back to in-memory.
            NSLog("Dockbars: persistent store unavailable (\(error)); using in-memory store.")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }

    /// Ensures at least one stash exists so the panel always has content to show.
    static func ensureDefaultStash(in context: ModelContext) {
        let descriptor = FetchDescriptor<Stash>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        context.insert(Stash(name: "Stash", order: 0))
        try? context.save()
    }
}
