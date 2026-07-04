import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The pocket's content: a grid of stash items with drag-and-drop, click-to-open,
/// and a minimal context menu (Open / Reveal / Remove).
struct PocketPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \Stash.order) private var stashes: [Stash]

    @State private var isDropTargeted = false

    private var currentStash: Stash? { stashes.first }

    private var iconSize: CGFloat { CGFloat(appState.settings.iconSize) }

    private var columns: [GridItem] {
        // Adaptive: fills the panel with as many fixed-width columns as fit,
        // matching the column count the placement math sized the panel for.
        let cellWidth = PanelLayout.cellSize(iconSize: iconSize).width
        return [GridItem(.adaptive(minimum: cellWidth, maximum: cellWidth), spacing: PanelLayout.spacing)]
    }

    private var sortedItems: [StashItem] {
        (currentStash?.items ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover)

            if sortedItems.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: PanelLayout.spacing) {
                ForEach(sortedItems) { item in
                    StashItemView(item: item, iconSize: iconSize,
                                  onOpen: { open(item) },
                                  onReveal: { reveal(item) },
                                  onRemove: { remove(item) })
                }
            }
            .padding(PanelLayout.padding)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Drop apps or files here")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Actions

    private func open(_ item: StashItem) {
        guard let url = item.resolvedURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func reveal(_ item: StashItem) {
        guard let url = item.resolvedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func remove(_ item: StashItem) {
        context.delete(item)
        try? context.save()
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let stash = currentStash else { return false }
        var didAccept = false
        let baseOrder = (stash.items.map(\.order).max() ?? -1) + 1

        for (offset, provider) in providers.enumerated() {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            didAccept = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    addItem(url: url, to: stash, order: baseOrder + offset)
                }
            }
        }
        return didAccept
    }

    @MainActor
    private func addItem(url: URL, to stash: Stash, order: Int) {
        // Skip exact duplicates.
        if stash.items.contains(where: { $0.urlString == url.absoluteString }) { return }
        let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let item = StashItem(
            displayName: url.deletingPathExtension().lastPathComponent,
            urlString: url.absoluteString,
            bookmarkData: bookmark,
            order: order
        )
        item.stash = stash
        context.insert(item)
        try? context.save()
    }
}
