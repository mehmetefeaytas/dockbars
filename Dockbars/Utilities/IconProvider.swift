import AppKit

/// Resolves file/app icons at runtime. Icons are never written to disk;
/// they are fetched from NSWorkspace and cached in memory by path.
enum IconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forPath path: String, size: CGFloat) -> NSImage {
        let key = "\(path)@\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: size, height: size)
        cache.setObject(image, forKey: key)
        return image
    }

    static func icon(for url: URL, size: CGFloat) -> NSImage {
        icon(forPath: url.path, size: size)
    }
}
