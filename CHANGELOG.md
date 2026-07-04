# Changelog

All notable changes to Dockbars are documented here.

## [Unreleased]

### Onboarding, settings & Dock-adjacent placement

**Added**
- **First-run tutorial** (`TutorialView` + `TutorialWindowController`) — a 4-step
  walkthrough: welcome, Accessibility permission (with live status polling), placement
  choice, and how-to-use with "Add my common apps" / "Open pocket now" actions. Re-openable
  from the menu bar ("Show Tutorial…") and Settings.
- **"Beside the Dock" placement mode** (`PlacementMode.dockAdjacent`), now the **default**.
  The pocket opens next to the Dock (bottom-left for a bottom Dock) and automatically
  **repositions above the Dock** when it grows too large to fit beside it. The alternative
  `.screenEdge` mode keeps the pick-an-edge behavior.
- **`DockFrameReader`** — reads the Dock's real tile rectangle via the Accessibility API
  (the only reliable source for Dock position/width), converted to AppKit coordinates.
  Falls back to an estimate when the Dock is hidden (autohide) or AX is unavailable.
- **Adaptive panel sizing** — `PanelLayout.columnsThatFit` / `adaptiveSize`; the panel grows
  with the item count and fits the available space; the grid uses adaptive columns.
- **`DefaultAppsSeeder`** — seeds common apps (Finder, Safari, Mail, Notes, System Settings,
  Music, Terminal) so the pocket isn't empty. Triggered from the tutorial/Settings, or at
  launch via the `DOCKBARS_SEED_ON_LAUNCH=1` test hook.
- **Settings** — placement-mode picker (edge picker shown only for Screen Edge), plus a
  "Getting Started" section (Show Tutorial / Open Pocket Now / Add Common Apps).
- **Startup diagnostics** — one-shot NSLog of Accessibility status, Dock geometry, and the
  resolved edge; `openPanel`/`closePanel` logging for troubleshooting.
- **Tests** — 6 new placement tests (fits-beside, overflow-when-narrow, overflow-when-tall,
  estimate fallback, screen-edge resolution). 28 tests total, all passing.

**Changed**
- Onboarding is now the tutorial window instead of a single alert; `DockInfo` carries the
  resolved `dockFrame`; `AppDelegate` computes a unified `PlacementResult` for both the
  trigger zone and panel origin.

**Verified end-to-end** (on-device): tutorial shows on first launch; seeding adds 7 apps;
the pocket opens at the bottom-left beside the Dock, renders the seeded apps, and closes on
leave — all confirmed via the window server and Accessibility inspection.

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
