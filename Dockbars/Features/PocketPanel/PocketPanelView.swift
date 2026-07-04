import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The pocket's content: a stash switcher header, a grid of items with
/// drag-and-drop add, drag-to-trash remove, click-to-open, and a full context menu.
struct PocketPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \Stash.order) private var stashes: [Stash]

    @State private var isDropTargeted = false
    @State private var isRemoveTargeted = false
    @State private var searchText = ""
    @State private var highlighted = 0
    @State private var gridColumns = 3
    @FocusState private var keyboardFocused: Bool

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
        (currentStash?.items ?? []).sorted { $0.order < $1.order }
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
            if filteredItems.isEmpty {
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
            handleAddDrop(providers)
        }
        .focusable()
        .focused($keyboardFocused)
        .onKeyPress { press in handleKey(press) }
        .onChange(of: appState.panelActivated) { _, activated in
            keyboardFocused = activated
        }
        .onChange(of: appState.isPanelVisible) { _, visible in
            if !visible { searchText = ""; highlighted = 0 }
        }
        .onChange(of: appState.selectedStashIndex) { _, _ in
            searchText = ""; highlighted = 0
        }
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
                Button { searchText = ""; highlighted = 0 } label: {
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
            Button(action: addViaOpenPanel) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add apps or files…")

            // Drag an item here to remove it from the stash.
            Image(systemName: isRemoveTargeted ? "trash.fill" : "trash")
                .foregroundStyle(isRemoveTargeted ? Color.red : Color.secondary)
                .frame(width: 22, height: 22)
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

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: PanelLayout.spacing) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.persistentModelID) { index, item in
                    StashItemView(
                        item: item, iconSize: iconSize, moveTargets: moveTargets,
                        isHighlighted: appState.panelActivated && index == highlighted,
                        onOpen: { open(item) },
                        onReveal: { reveal(item) },
                        onRename: { renameItem(item) },
                        onMove: { moveItem(item, to: $0) },
                        onRemove: { remove(item) }
                    )
                }
            }
            .padding(PanelLayout.padding)
            .background(GeometryReader { geo in
                Color.clear.onChange(of: geo.size.width, initial: true) { _, width in
                    gridColumns = max(1, Int((width - PanelLayout.spacing) / (cellWidth + PanelLayout.spacing)))
                }
            })
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

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        // ⌘1–9 switches stash.
        if press.modifiers.contains(.command), let digit = Int(press.characters), (1...9).contains(digit) {
            if digit - 1 < stashes.count { appState.selectedStashIndex = digit - 1 }
            return .handled
        }
        switch press.key {
        case .escape:
            if !searchText.isEmpty { searchText = ""; highlighted = 0 } else { appState.onTogglePanel?() }
            return .handled
        case .return:
            if let item = filteredItems[safe: highlighted] { open(item) }
            return .handled
        case .leftArrow: moveHighlight(-1); return .handled
        case .rightArrow: moveHighlight(1); return .handled
        case .upArrow: moveHighlight(-gridColumns); return .handled
        case .downArrow: moveHighlight(gridColumns); return .handled
        case .deleteForward, .delete:
            if !searchText.isEmpty { searchText.removeLast(); highlighted = 0 }
            return .handled
        default:
            // Printable character → append to the search query.
            if !press.modifiers.contains(.command), !press.modifiers.contains(.control),
               press.characters.count == 1,
               let scalar = press.characters.unicodeScalars.first, scalar.value >= 32 {
                searchText.append(press.characters)
                highlighted = 0
                return .handled
            }
            return .ignored
        }
    }

    private func moveHighlight(_ delta: Int) {
        guard !filteredItems.isEmpty else { return }
        highlighted = min(max(highlighted + delta, 0), filteredItems.count - 1)
    }

    // MARK: - Item actions

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

    private func renameItem(_ item: StashItem) {
        guard let name = InputPrompt.string(title: "Rename Item", defaultValue: item.displayName) else { return }
        item.displayName = name
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

    private func handleAddDrop(_ providers: [NSItemProvider]) -> Bool {
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

    /// Removes the item whose URL is dropped onto the trash zone.
    private func handleRemoveDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    if let item = currentStash?.items.first(where: { $0.urlString == url.absoluteString }) {
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
