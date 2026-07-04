import AppKit

/// Opens a stash item and provides its icon, per item kind.
enum ItemLauncher {
    static func open(_ item: StashItem) {
        switch item.kind {
        case .file:
            if let url = item.resolvedURL { NSWorkspace.shared.open(url) }
        case .url:
            if let url = URL(string: item.urlString) { NSWorkspace.shared.open(url) }
        case .shortcut:
            let name = item.payload ?? item.displayName
            run("/usr/bin/shortcuts", ["run", name])
        case .script:
            run("/bin/zsh", ["-lc", item.payload ?? ""])
        case .snippet:
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(item.payload ?? item.displayName, forType: .string)
        }
    }

    static func canRevealInFinder(_ item: StashItem) -> Bool {
        item.kind == .file
    }

    /// Opens a recent record (no live StashItem needed).
    static func open(_ record: RecentRecord) {
        switch record.kind {
        case .file, .url:
            if let url = URL(string: record.urlString) { NSWorkspace.shared.open(url) }
        case .shortcut:
            run("/usr/bin/shortcuts", ["run", record.payload ?? record.displayName])
        case .script:
            run("/bin/zsh", ["-lc", record.payload ?? ""])
        case .snippet:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(record.payload ?? record.displayName, forType: .string)
        }
    }

    static func icon(for record: RecentRecord, size: CGFloat) -> NSImage {
        switch record.kind {
        case .file:
            if let url = URL(string: record.urlString) { return IconProvider.icon(for: url, size: size) }
            return symbol("doc", size: size)
        case .url: return symbol("globe", size: size)
        case .shortcut: return symbol("wand.and.stars", size: size)
        case .script: return symbol("terminal", size: size)
        case .snippet: return symbol("text.quote", size: size)
        }
    }

    static func icon(for item: StashItem, size: CGFloat) -> NSImage {
        if let emoji = item.customIcon, !emoji.isEmpty {
            return emojiImage(emoji, size: size)
        }
        switch item.kind {
        case .file:
            if let url = item.resolvedURL { return IconProvider.icon(for: url, size: size) }
            return symbol("doc", size: size)
        case .url:
            return symbol("globe", size: size)
        case .shortcut:
            return symbol("wand.and.stars", size: size)
        case .script:
            return symbol("terminal", size: size)
        case .snippet:
            return symbol("text.quote", size: size)
        }
    }

    static func emojiImage(_ emoji: String, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let font = NSFont.systemFont(ofSize: size * 0.8)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let string = emoji as NSString
        let textSize = string.size(withAttributes: attributes)
        let point = NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2)
        string.draw(at: point, withAttributes: attributes)
        image.unlockFocus()
        return image
    }

    private static func symbol(_ name: String, size: CGFloat) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.7, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
        return image
    }

    /// Launches a helper process detached; failures are logged, never fatal.
    private static func run(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        do {
            try process.run()
        } catch {
            NSLog("Dockbars ▸ failed to run \(launchPath): \(error)")
        }
    }
}
