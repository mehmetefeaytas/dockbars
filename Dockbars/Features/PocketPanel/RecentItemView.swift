import SwiftUI

/// A recently-opened item shown in the pocket's "Recently used" section.
struct RecentItemView: View {
    let record: RecentRecord
    let iconSize: CGFloat

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: ItemLauncher.icon(for: record, size: iconSize))
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(record.displayName)
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
        .onTapGesture { ItemLauncher.open(record) }
        .help(record.displayName)
    }
}
