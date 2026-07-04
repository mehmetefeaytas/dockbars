import SwiftUI
import UniformTypeIdentifiers

/// A single pocket cell: icon + truncated label, click to open, drag out to move
/// the underlying file elsewhere, right-click for the minimal context menu.
struct StashItemView: View {
    let item: StashItem
    let iconSize: CGFloat
    let moveTargets: [Stash]
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onRename: () -> Void
    let onMove: (Stash) -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    private var icon: NSImage {
        if let url = item.resolvedURL {
            return IconProvider.icon(for: url, size: iconSize)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    var body: some View {
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
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onOpen() }
        .help(item.displayName)
        .onDrag {
            if let url = item.resolvedURL {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider()
        }
        .contextMenu {
            Button("Open") { onOpen() }
            Button("Reveal in Finder") { onReveal() }
            Button("Rename…") { onRename() }
            if !moveTargets.isEmpty {
                Menu("Move to Stash") {
                    ForEach(moveTargets) { stash in
                        Button(stash.name) { onMove(stash) }
                    }
                }
            }
            Divider()
            Button("Remove", role: .destructive) { onRemove() }
        }
    }
}
