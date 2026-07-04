import SwiftUI

extension View {
    /// Applies the system Liquid Glass material on macOS 26+ (Tahoe), falling back
    /// to an NSVisualEffectView vibrancy material on earlier systems.
    @ViewBuilder
    func pocketGlassBackground(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(VisualEffectView(material: .popover))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
