# Dockbars

A native macOS hidden **Dock pocket**. Move your pointer to the edge of the screen next
to the Dock and a panel of your favorite apps and files slides out — a natural extension
of the Dock, not a replacement for it.

> Inspired by the "Stash" concept. Codename during development: **Stash++**.

## Status

**Phases 1–4 implemented.** Hidden Dock pocket with hover + menu-bar + global-shortcut
opening, multiple stashes, search & keyboard navigation, extended item types, themes,
recents/pins, Quick Peek, multi-monitor, widgets, clipboard history, statistics, JSON
export/import, and `dockbars://` automation. See [CHANGELOG.md](CHANGELOG.md).

### Opening the pocket

- **Hover** the trigger strip (default: bottom-left, beside the Dock). Move into the panel
  to enable keyboard/search.
- **Click** the menu-bar icon (right-click for the menu).
- **Global shortcut** ⌥Space.
- **URL / CLI**: `open dockbars://open` or `dockbars open`.

### Automation

`dockbars://` URL scheme:

```
dockbars://open              # open the pocket
dockbars://open?stash=Work   # select "Work" and open
dockbars://toggle            # toggle
```

CLI wrapper (`scripts/dockbars`, install to `/usr/local/bin`):

```bash
dockbars open
dockbars open Work
dockbars toggle
```

AppleScript (via the URL scheme):

```applescript
do shell script "open 'dockbars://open?stash=Work'"
```

Auto-update via **Sparkle** is planned; the appcast URL is a placeholder until then.

## Privacy

Dockbars is **local-first and offline**:

- **No network access.** (The only future exception will be Sparkle auto-updates in Phase 4, behind a clearly labeled setting.)
- **No telemetry, no analytics, no tracking.**
- All data — your stashes, items, and settings — stays on your Mac.
- Icons are resolved at runtime from the system; nothing is written to disk as image data.

## Requirements

- macOS 15 (Sequoia) or later. Tested against the macOS 26 (Tahoe) SDK.
- Xcode 26+ / Swift 5.10+ toolchain.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the project (`brew install xcodegen`).

## Accessibility permission

Dockbars needs **Accessibility** access to watch for the pointer reaching the Dock edge
and to read the Dock's position. This is why **App Sandbox is intentionally disabled** —
global mouse monitoring and Dock inspection are incompatible with the sandbox. Dockbars
requests no network entitlement and keeps Hardened Runtime enabled for notarization.

On first launch you'll be prompted; grant access in
**System Settings → Privacy & Security → Accessibility**.

## Build & run

```bash
# Generate the Xcode project from project.yml
xcodegen generate

# Build
xcodebuild -project Dockbars.xcodeproj -scheme Dockbars -configuration Debug build

# Run the tests
xcodebuild -project Dockbars.xcodeproj -scheme Dockbars -destination 'platform=macOS' test
```

Or open `Dockbars.xcodeproj` in Xcode and run the **Dockbars** scheme.

## Architecture

MVVM. `AppState` (an `ObservableObject`) is the single source of truth; the AppKit layer
bridges into SwiftUI with `NSHostingView`.

```
Dockbars/
├── App/         main, AppDelegate (coordinator), AppState
├── Core/
│   ├── DockObserver/    Dock position/size/autohide detection + pure geometry
│   ├── HoverEngine/     global mouse monitor + debounced open/close
│   ├── PanelController/ NSPanel lifecycle, positioning, slide+fade animation
│   └── Persistence/     SwiftData models (Stash, StashItem) + SettingsStore
├── Features/
│   ├── PocketPanel/     SwiftUI panel content
│   ├── Settings/        preferences window
│   └── MenuBar/         status item + onboarding
├── Utilities/
└── Tests/               DockGeometry + HoverDebouncer unit tests
```

Key technical decisions:

- **Panel:** `NSPanel` subclass — `nonactivatingPanel`, borderless, `level = .statusBar`,
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`. Opening the pocket never
  steals focus from the active app.
- **Hover:** `NSEvent` global + local `.mouseMoved` monitors. The hot path does a single
  cached rect test; the close delay is realized with one cancellable work item (no polling),
  keeping idle CPU near zero.
- **Dock detection:** reads `com.apple.dock` (`orientation`/`tilesize`/`autohide`) plus
  `NSScreen` frames, and listens to `com.apple.dock.prefchanged`.
- **Persistence:** SwiftData for stashes/items; UserDefaults for lightweight settings.
- **Menu bar only:** `NSStatusItem`, `LSUIElement = true`, no Dock icon.
- **Launch at login:** `SMAppService.mainApp`.
- **Dependencies:** zero third-party (Sparkle deferred to Phase 4).

## Roadmap

- **Phase 1 — MVP:** hidden pocket, hover detection, smart Dock detection, single 12-slot
  stash, drag-and-drop, click-to-open, animation, menu bar, settings, onboarding.
- **Phase 2:** multiple named stashes, extended item types, search, keyboard nav, full
  context menu, running-apps section, themes.
- **Phase 3:** recently used, favorites/pin, Quick Peek, global shortcut, multi-monitor,
  fullscreen awareness, profiles, list view.
- **Phase 4:** widgets, clipboard history, automation (URL scheme / AppleScript / CLI),
  export/import + iCloud sync, stats, Sparkle updates, accessibility pass.

## License

TBD.
