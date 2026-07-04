import SwiftUI

/// A single pocket cell. Rendering is SwiftUI; interaction (click, drag, context
/// menu) is handled by `DraggableItemView` in AppKit for reliability inside the
/// non-activating panel. Drag onto the trash or out of the panel to remove.
struct StashItemView: View {
    let item: StashItem
    let iconSize: CGFloat
    let moveTargets: [Stash]
    var isHighlighted: Bool = false
    var onDragStart: () -> Void = {}
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onRename: () -> Void
    let onMove: (Stash) -> Void
    let onRemove: () -> Void

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
                dragBegan: onDragStart
            ),
            content: AnyView(cell)
        )
        .frame(width: cellSize.width, height: cellSize.height)
        .help(item.displayName)
    }

    private var cell: some View {
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
        .contentShape(Rectangle())
    }
}
