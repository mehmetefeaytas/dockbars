import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A control that records a global shortcut. Click to arm, then press a key
/// combination (at least one modifier + a key). Esc cancels; the bound values
/// are written back through the bindings.
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var carbonModifiers: Int

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onCapture = { code, mods in
            keyCode = code
            carbonModifiers = mods
        }
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        nsView.refreshTitle(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }
}

/// AppKit button that becomes first responder and captures the next chord.
final class RecorderButton: NSButton {
    var onCapture: ((Int, Int) -> Void)?
    private var recording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(startRecording)
        refreshTitle(keyCode: 49, carbonModifiers: 2048)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refreshTitle(keyCode: Int, carbonModifiers: Int) {
        guard !recording else { return }
        title = KeyboardShortcut.displayString(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }

    @objc private func startRecording() {
        recording = true
        title = "Press keys…"
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }

        if event.keyCode == UInt16(kVK_Escape) {
            recording = false
            return // updateNSView restores the current title
        }

        let carbon = KeyboardShortcut.carbonModifiers(from: event.modifierFlags)
        // Require at least one modifier so the shortcut doesn't fire while typing.
        guard carbon != 0 else {
            NSSound.beep()
            return
        }
        recording = false
        onCapture?(Int(event.keyCode), carbon)
        title = KeyboardShortcut.displayString(keyCode: Int(event.keyCode), carbonModifiers: carbon)
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }
}
