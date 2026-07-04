# Changelog

All notable changes to Dockbars are documented here.

## [Unreleased]

### Phase 1 — MVP (in progress)

Buildable skeleton established; builds clean and all unit tests pass.

**Added**
- XcodeGen project (`project.yml`): `Dockbars` app + `DockbarsTests` targets. macOS 15
  deployment target, Swift 5 language mode, `LSUIElement`, Hardened Runtime, **App Sandbox
  disabled** (required for global mouse monitoring + Dock inspection), and
  `NSAccessibilityUsageDescription`.
- **DockObserver** — reads `com.apple.dock` (`orientation`/`tilesize`/`autohide`) and
  `NSScreen` frames; reacts to `com.apple.dock.prefchanged` and screen-parameter changes.
- **DockGeometry** — pure, unit-tested geometry: allowed/resolved edges, trigger-zone rect,
  flush + centered panel origin (clamped to the visible frame), and off-screen slide origin.
- **HoverEngine** — global + local `.mouseMoved` monitors with an allocation-free hot path
  (single cached rect test); close delay realized with one cancellable work item (no polling).
- **HoverDebouncer** — pure, unit-tested debounce state machine (immediate open, delayed
  close, re-entry cancels, first-outside-wins deadline).
- **PanelController** + **PocketPanel** — non-activating borderless `NSPanel`
  (`level = .statusBar`, all-Spaces + fullscreen-auxiliary) that never steals focus;
  slide + fade animation with a Reduce Motion fallback (plain fade).
- **Persistence** — SwiftData models `Stash` / `StashItem` (with bookmark resolution);
  `SettingsStore` (UserDefaults) for edge, close delay, trigger width, icon size, launch at login.
- **PocketPanelView** / **StashItemView** — 12-slot grid, drag-and-drop add from Finder /
  Applications / Dock, click-to-open, drag-out, context menu (Open / Reveal / Remove).
- **MenuBarController** — `NSStatusItem` with Toggle Pocket / Settings / Quit.
- **SettingsView** — edge, icon size (32–64), close delay, trigger width, launch at login,
  Accessibility status.
- **OnboardingController** — first-launch Accessibility permission guidance.
- **Utilities** — `IconProvider` (runtime, cached, never persisted), `LaunchAtLogin`
  (`SMAppService`), `AccessibilityPermission`, `VisualEffectView`, `PanelLayout`.
- **Tests** — 22 unit tests across `DockGeometryTests` and `HoverDebouncerTests`.

**Notes / deviations**
- Settings are stored in UserDefaults (idiomatic for lightweight prefs) rather than SwiftData;
  stashes and items use SwiftData as specified.
- Animation uses `NSAnimationContext` slide + fade; the `CASpringAnimation` "Dock feel"
  refinement is tracked for a later Phase 1 iteration.
