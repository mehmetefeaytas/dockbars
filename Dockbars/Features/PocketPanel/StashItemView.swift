import SwiftUI

/// A single pocket cell. Rendering is SwiftUI; interaction (click, drag, context
/// menu) is handled by `DraggableItemView` in AppKit for reliability inside the
/// non-activating panel. Drag onto the trash or out of the panel to remove.
struct StashItemView: View {
    let item: StashItem
    let iconSize: CGFloat
    let moveTargets: [Stash]
    var isHighlighted: Bool = false
    var listStyle: Bool = false
    var onDragStart: () -> Void = {}
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onRename: () -> Void
    let onMove: (Stash) -> Void
    let onRemove: () -> Void
    var onTogglePin: () -> Void = {}

    @State private var peekTask: Task<Void, Never>?

    private var icon: NSImage {
        ItemLauncher.icon(for: item, size: iconSize)
    }

    private var cellSize: CGSize { PanelLayout.cellSize(iconSize: iconSize) }

    var body: some View {
        DraggableItemView(
            fileURL: URL(string: item.urlString) ?? item.resolvedURL,
            dragImage: icon,
            actions: ItemActions(
                open: onOpen,
                reveal: onReveal,
                rename: onRename,
                remove: onRemove,
                moveTargets: moveTargets.map { stash in (stash.name, { onMove(stash) }) },
                isPinned: item.isPinned,
                togglePin: onTogglePin,
                dragBegan: onDragStart
            ),
            content: AnyView(cell)
        )
        .frame(width: listStyle ? nil : cellSize.width,
               height: listStyle ? max(iconSize * 0.6, 28) : cellSize.height)
        .frame(maxWidth: listStyle ? .infinity : nil)
        .help(item.displayName)
        .onHover { hovering in
            peekTask?.cancel()
            guard hovering, item.kind == .file, let url = item.resolvedURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                return
            }
            // Quick Peek: preview after a 1s dwell.
            peekTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                QuickLookPreview.shared.show(url)
            }
        }
    }

    @ViewBuilder
    private var cell: some View {
        if listStyle { listCell } else { gridCell }
    }

    private var listCell: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: min(iconSize, 22), height: min(iconSize, 22))
            Text(item.displayName)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isHighlighted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
    }

    private var gridCell: some View {
        VStack(spacing: 4) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(item.displayName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: iconSize + 20)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHighlighted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .padding(3)
            }
        }
        .contentShape(Rectangle())
    }
}
