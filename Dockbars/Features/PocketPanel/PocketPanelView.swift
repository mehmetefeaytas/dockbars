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
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            if sortedItems.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pocketGlassBackground(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(currentStash?.name ?? "Stash")
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(action: addViaOpenPanel) {
                Image(systemName: "plus")
            }
            .help("Add apps or files…")
            Button { appState.onOpenSettings?() } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Drop apps or files here")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(action: addViaOpenPanel) {
                Label("Add…", systemImage: "plus")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// Adds apps/files via a standard open panel (alternative to drag-and-drop).
    private func addViaOpenPanel() {
        guard let stash = currentStash else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose apps or files to add to your pocket"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        // Accessory apps must activate for the panel to come forward.
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }

        let baseOrder = (stash.items.map(\.order).max() ?? -1) + 1
        for (offset, url) in panel.urls.enumerated() {
            addItem(url: url, to: stash, order: baseOrder + offset)
        }
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
