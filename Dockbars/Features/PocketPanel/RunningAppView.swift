import SwiftUI
import AppKit

/// A running application shown in the pocket's "Running" section. Click to
/// bring the app to the front.
struct RunningAppView: View {
    let app: NSRunningApplication
    let iconSize: CGFloat

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: app.icon ?? NSWorkspace.shared.icon(for: .applicationBundle))
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(app.localizedName ?? "App")
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
        .onTapGesture { app.activate() }
        .help(app.localizedName ?? "")
    }
}
