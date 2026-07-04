import AppKit
import Combine

/// Local-only clipboard history. Polls `NSPasteboard.changeCount` (0.5s) and
/// keeps the last N text copies. Ignores items marked concealed (e.g. password
/// managers set `org.nspasteboard.ConcealedType`). Nothing ever leaves the Mac.
@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var entries: [String] = []

    private let limit = 20
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private var enabled = false

    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        if on {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.poll() }
            }
        } else {
            timer?.invalidate(); timer = nil
        }
    }

    func clear() { entries.removeAll() }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Respect password managers: skip concealed content.
        if pasteboard.types?.contains(Self.concealedType) == true { return }
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        entries.removeAll { $0 == text }
        entries.insert(text, at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
    }

    func copyToPasteboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount // don't re-record our own write
    }

    deinit { timer?.invalidate() }
}
