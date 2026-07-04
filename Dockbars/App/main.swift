import AppKit

// Menu-bar-only app: no main window, no Dock icon (LSUIElement + .accessory policy).
// AppKit's app object and our delegate are main-actor isolated; the app runs on the
// main thread, so assume isolation here. `run()` blocks for the process lifetime,
// which keeps the delegate (held weakly by NSApplication) alive.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
