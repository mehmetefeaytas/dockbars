import Foundation

/// Terse localization helper for AppKit strings (menus, alerts, prompts).
/// SwiftUI `Text` literals localize on their own; this covers the plain-String
/// call sites. The key is the English text.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
