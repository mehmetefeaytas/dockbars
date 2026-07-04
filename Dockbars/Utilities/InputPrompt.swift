import AppKit

/// Modal single-line text prompt. Used for naming/renaming stashes and items —
/// the pocket panel is non-activating and can't host a focused text field, so a
/// brief modal (with the app promoted to regular) is the reliable way to type.
enum InputPrompt {
    @MainActor
    static func string(title: String, message: String = "", defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultValue
        field.placeholderString = "Name"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        defer { NSApp.setActivationPolicy(.accessory) }

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
