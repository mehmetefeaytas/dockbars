import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The pocket's content: a stash switcher header, a grid of items with
/// drag-and-drop add, drag-to-trash remove, click-to-open, and a full context menu.
struct PocketPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \Stash.order) private var stashes: [Stash]

    @StateObject private var runningApps = RunningAppsMonitor()
    @ObservedObject private var recents = RecentTracker.shared
    @ObservedObject private var stats = StatsStore.shared
    @State private var isDropTargeted = false
    @State private var isRemoveTargeted = false
    /// The item currently being dragged (set when its drag begins), so the trash
    /// target can remove exactly that item without fragile URL matching.
    @State private var draggingItemID: PersistentIdentifier?

    // Search + highlight live in AppState, driven by the app-level keyboard monitor
    // (keeping keyboard out of SwiftUI focus so it never interferes with drag & drop).
    private var searchText: String { appState.searchQuery }

    private var clampedIndex: Int {
        guard !stashes.isEmpty else { return 0 }
        return min(max(appState.selectedStashIndex, 0), stashes.count - 1)
    }

    private var currentStash: Stash? { stashes.isEmpty ? nil : stashes[clampedIndex] }

    private var iconSize: CGFloat { CGFloat(appState.settings.iconSize) }

    private var cellWidth: CGFloat { PanelLayout.cellSize(iconSize: iconSize).width }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cellWidth, maximum: cellWidth), spacing: PanelLayout.spacing)]
    }

    private var sortedItems: [StashItem] {
        (currentStash?.items ?? []).sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned } // pinned first
            return a.order < b.order
        }
    }

    /// Items after applying the search filter.
    private var filteredItems: [StashItem] {
        guard !searchText.isEmpty else { return sortedItems }
        return sortedItems.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private var moveTargets: [Stash] {
        stashes.filter { $0.persistentModelID != currentStash?.persistentModelID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if appState.panelActivated || !searchText.isEmpty {
                searchBar
            }
            Divider().opacity(0.4)
            // Content area is the add-drop zone (separate from the header's trash
            // zone so the two never conflict).
            Group {
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleAddDrop(providers)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pocketGlassBackground(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "Type to search" : searchText)
                .foregroundStyle(searchText.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            Spacer()
            if !searchText.isEmpty {
                Button { appState.searchQuery = ""; appState.highlightedIndex = 0 } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            stashMenu
            Spacer(minLength: 4)
            Menu {
                Button("Add Files…") { addViaOpenPanel() }
                Button("Add URL…") { addURL() }
                Button("Add Shortcut…") { addShortcut() }
                Button("Add Script…") { addScript() }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add apps, files, a URL, a Shortcut, or a script")

            // Drag an item here to remove it from the stash.
            Image(systemName: isRemoveTargeted ? "trash.fill" : "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isRemoveTargeted ? Color.red : Color.secondary)
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isRemoveTargeted ? Color.red.opacity(0.18) : Color.primary.opacity(0.06))
                )
                .contentShape(Rectangle())
                .help("Drag an item here to remove it")
                .onDrop(of: [.fileURL], isTargeted: $isRemoveTargeted) { providers in
                    handleRemoveDrop(providers)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var stashMenu: some View {
        Menu {
            ForEach(Array(stashes.enumerated()), id: \.element.persistentModelID) { index, stash in
                Button {
                    appState.selectedStashIndex = index
                } label: {
                    if index == clampedIndex {
                        Label(stash.name, systemImage: "checkmark")
                    } else {
                        Text(stash.name)
                    }
                }
            }
            Divider()
            Button("New Stash…") { newStash() }
            Button("Rename Stash…") { renameStash() }
            if stashes.count > 1 {
                Button("Delete Stash", role: .destructive) { deleteStash() }
            }
            Divider()
            Button("Settings…") { appState.onOpenSettings?() }
        } label: {
            Label(currentStash?.name ?? "Stash", systemImage: "square.stack")
                .font(.headline)
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var itemColumns: [GridItem] {
        appState.settings.useListView
            ? [GridItem(.flexible(), spacing: PanelLayout.spacing)]
            : columns
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: itemColumns, spacing: PanelLayout.spacing) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.persistentModelID) { index, item in
                    StashItemView(
                        item: item, iconSize: iconSize, moveTargets: moveTargets,
                        isHighlighted: appState.panelActivated && index == appState.highlightedIndex,
                        listStyle: appState.settings.useListView,
                        onDragStart: { draggingItemID = item.persistentModelID },
                        onOpen: { open(item) },
                        onReveal: { reveal(item) },
                        onRename: { renameItem(item) },
                        onMove: { moveItem(item, to: $0) },
                        onRemove: { remove(item) },
                        onTogglePin: { togglePin(item) }
                    )
                }
            }
            .padding(PanelLayout.padding)

            if appState.settings.showRecent && !recents.records.isEmpty {
                recentSection
            }
            if appState.settings.clipboardHistory && !appState.clipboard.entries.isEmpty {
                clipboardSection
            }
            if appState.settings.showRunningApps && !runningApps.apps.isEmpty {
                runningSection
            }
        }
    }

    private var clipboardSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().opacity(0.4)
            HStack {
                Text("Clipboard")
                    .font(.caption).bold().foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { appState.clipboard.clear() }
                    .buttonStyle(.borderless).font(.caption2)
            }
            .padding(.horizontal, PanelLayout.padding)
            ForEach(Array(appState.clipboard.entries.prefix(10).enumerated()), id: \.offset) { _, text in
                Button {
                    appState.clipboard.copyToPasteboard(text)
                } label: {
                    Text(text)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, PanelLayout.padding)
                .help("Click to copy")
            }
            .padding(.bottom, 4)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().opacity(0.4)
            HStack {
                Text("Recently used")
                    .font(.caption).bold()
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { recents.clear() }
                    .buttonStyle(.borderless)
                    .font(.caption2)
            }
            .padding(.horizontal, PanelLayout.padding)
            LazyVGrid(columns: columns, spacing: PanelLayout.spacing) {
                ForEach(recents.records.prefix(12)) { record in
                    RecentItemView(record: record, iconSize: iconSize)
                }
            }
            .padding(.horizontal, PanelLayout.padding)
            .padding(.bottom, PanelLayout.padding)
        }
    }

    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().opacity(0.4)
            Text("Running")
                .font(.caption).bold()
                .foregroundStyle(.secondary)
                .padding(.horizontal, PanelLayout.padding)
            LazyVGrid(columns: columns, spacing: PanelLayout.spacing) {
                ForEach(runningApps.apps, id: \.processIdentifier) { app in
                    RunningAppView(app: app, iconSize: iconSize)
                }
            }
            .padding(.horizontal, PanelLayout.padding)
            .padding(.bottom, PanelLayout.padding)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("No matches for “\(searchText)”")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
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
    }

    // MARK: - Item actions

    private func open(_ item: StashItem) {
        RecentTracker.shared.record(item)
        StatsStore.shared.record(item)
        ItemLauncher.open(item)
    }

    private func reveal(_ item: StashItem) {
        guard ItemLauncher.canRevealInFinder(item), let url = item.resolvedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func remove(_ item: StashItem) {
        context.delete(item)
        try? context.save()
    }

    private func renameItem(_ item: StashItem) {
        guard let name = InputPrompt.string(title: "Rename Item", defaultValue: item.displayName) else { return }
        item.displayName = name
        try? context.save()
    }

    private func togglePin(_ item: StashItem) {
        item.isPinned.toggle()
        try? context.save()
    }

    private func moveItem(_ item: StashItem, to stash: Stash) {
        item.stash = stash
        item.order = (stash.items.map(\.order).max() ?? -1) + 1
        try? context.save()
    }

    // MARK: - Stash actions

    private func newStash() {
        guard let name = InputPrompt.string(title: "New Stash") else { return }
        let order = (stashes.map(\.order).max() ?? -1) + 1
        context.insert(Stash(name: name, order: order))
        try? context.save()
        appState.selectedStashIndex = stashes.count // becomes the new last index
    }

    private func renameStash() {
        guard let stash = currentStash,
              let name = InputPrompt.string(title: "Rename Stash", defaultValue: stash.name) else { return }
        stash.name = name
        try? context.save()
    }

    private func deleteStash() {
        guard stashes.count > 1, let stash = currentStash else { return }
        context.delete(stash)
        try? context.save()
        appState.selectedStashIndex = 0
    }

    // MARK: - Drag & drop

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

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }

        let baseOrder = (stash.items.map(\.order).max() ?? -1) + 1
        for (offset, url) in panel.urls.enumerated() {
            addItem(url: url, to: stash, order: baseOrder + offset)
        }
    }

    private func addURL() {
        guard let stash = currentStash,
              let input = InputPrompt.string(title: "Add URL", message: "Enter a web address", defaultValue: "https://") else { return }
        var text = input
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text) else { return }
        let name = url.host ?? text
        insert(StashItem(displayName: name, urlString: text, kind: .url), into: stash)
    }

    private func addShortcut() {
        guard let stash = currentStash,
              let name = InputPrompt.string(title: "Add Shortcut", message: "Enter the exact Shortcut name") else { return }
        insert(StashItem(displayName: name, urlString: "dockbars-shortcut:\(name)", kind: .shortcut, payload: name), into: stash)
    }

    private func addScript() {
        guard let stash = currentStash,
              let name = InputPrompt.string(title: "Add Script", message: "Name this script") else { return }
        guard let body = InputPrompt.string(title: "Script for “\(name)”", message: "Shell command to run") else { return }
        insert(StashItem(displayName: name, urlString: "dockbars-script:\(name)", kind: .script, payload: body), into: stash)
    }

    private func insert(_ item: StashItem, into stash: Stash) {
        item.order = (stash.items.map(\.order).max() ?? -1) + 1
        item.stash = stash
        context.insert(item)
        try? context.save()
    }

    private func handleAddDrop(_ providers: [NSItemProvider]) -> Bool {
        draggingItemID = nil // dropping on the content area is never a removal
        guard let stash = currentStash else { return false }
        var didAccept = false
        let baseOrder = (stash.items.map(\.order).max() ?? -1) + 1

        for (offset, provider) in providers.enumerated() {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            didAccept = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.isFileURL else { return }
                Task { @MainActor in
                    addItem(url: url, to: stash, order: baseOrder + offset)
                }
            }
        }
        return didAccept
    }

    /// Removes the item dropped onto the trash zone. Uses the item captured when
    /// its drag began (reliable); falls back to URL matching for external drops.
    private func handleRemoveDrop(_ providers: [NSItemProvider]) -> Bool {
        defer { draggingItemID = nil }
        if let id = draggingItemID,
           let item = sortedItems.first(where: { $0.persistentModelID == id }) {
            context.delete(item)
            try? context.save()
            return true
        }
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    if let item = currentStash?.items.first(where: {
                        $0.urlString == url.absoluteString || $0.resolvedURL?.path == url.path
                    }) {
                        context.delete(item)
                        try? context.save()
                    }
                }
            }
        }
        return true
    }

    @MainActor
    private func addItem(url: URL, to stash: Stash, order: Int) {
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
