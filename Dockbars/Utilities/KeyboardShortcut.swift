import AppKit
import Carbon.HIToolbox

/// Helpers to convert between NSEvent modifier flags, Carbon modifier flags, and
/// a human-readable shortcut string (e.g. "⌥Space", "⌃⌘K").
enum KeyboardShortcut {
    /// NSEvent modifier flags → Carbon modifier flags (for RegisterEventHotKey).
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var carbon = 0
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        return carbon
    }

    static func modifierSymbols(carbon: Int) -> String {
        var s = ""
        if carbon & controlKey != 0 { s += "⌃" }
        if carbon & optionKey != 0 { s += "⌥" }
        if carbon & shiftKey != 0 { s += "⇧" }
        if carbon & cmdKey != 0 { s += "⌘" }
        return s
    }

    /// Human-readable display for a key code + Carbon modifiers.
    static func displayString(keyCode: Int, carbonModifiers: Int) -> String {
        modifierSymbols(carbon: carbonModifiers) + keyName(for: keyCode)
    }

    /// A minimal, readable name for common virtual key codes.
    static func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case kVK_Space: return "Space"
        case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        default:
            if let char = charForKeyCode(keyCode) { return char.uppercased() }
            return "Key \(keyCode)"
        }
    }

    /// Resolves the character a key code produces on the current layout.
    private static func charForKeyCode(_ keyCode: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let ptr = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(ptr, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
