import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A control that records a global shortcut. Click to arm, then press a chord
/// (≥1 modifier + a key); Esc cancels. While armed it uses a local key-event
/// monitor so the chord is captured regardless of focus — crucially, this also
/// captures Space/Return, which a plain button would otherwise treat as a click.
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

    static func dismantleNSView(_ nsView: RecorderButton, coordinator: ()) {
        nsView.stopRecording()
    }
}

final class RecorderButton: NSButton {
    var onCapture: ((Int, Int) -> Void)?
    private var monitor: Any?
    private var recording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        refreshTitle(keyCode: 49, carbonModifiers: 2048)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refreshTitle(keyCode: Int, carbonModifiers: Int) {
        guard !recording else { return }
        title = KeyboardShortcut.displayString(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }

    @objc private func toggleRecording() {
        if recording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        recording = true
        title = NSLocalizedString("Press keys…", comment: "")
        // Local monitor: intercept the next chord anywhere in the app, consuming
        // it so Space/Return/etc. don't act as button clicks or type into fields.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return nil // swallow the event while recording
        }
    }

    func stopRecording() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            refreshTitle(keyCode: 49, carbonModifiers: 2048) // updateNSView will restore the real value
            return
        }
        let carbon = KeyboardShortcut.carbonModifiers(from: event.modifierFlags)
        guard carbon != 0 else { NSSound.beep(); return } // require a modifier
        stopRecording()
        onCapture?(Int(event.keyCode), carbon)
        title = KeyboardShortcut.displayString(keyCode: Int(event.keyCode), carbonModifiers: carbon)
    }

    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
}
