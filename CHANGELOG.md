# Changelog

All notable changes to Dockbars are documented here.

## [Unreleased]

### Fixes — keyboard now works after hover; drag & drop restored

**Fixed**
- **Keyboard navigation/search now works with hover-opened pockets.** Previously it
  only worked when opened from the menu bar. Now the pocket is promoted to a key
  window the moment the pointer **enters** it (`HoverEngine.onEnteredPanel`), so search
  and arrow/Return/Esc/⌘1–9 work in the normal hover flow — while a hover-open still
  never steals focus until you move into the panel.
- **Drag-and-drop add/remove restored.** The Phase 2 search work added `.focusable()`
  + `.onKeyPress` to the panel, which broke drop hit-testing. Keyboard handling moved
  to an app-level local `NSEvent` key monitor (`installKeyboardMonitor`), so SwiftUI
  focus no longer interferes with drag & drop. Search/highlight state moved to `AppState`.
- Reset the (accidentally persisted) placement default back to **Beside the Dock**.

### Phase 2 (part 2) — search & keyboard navigation

**Added**
- **Activated mode** — opening from the menu bar makes the pocket a key window
  (`PocketPanel.keyable`) so it accepts keyboard input; **hover/drag opens stay
  non-activating and never steal focus** (Phase 1 guarantee preserved).
- **Type-to-search** — in activated mode, start typing to filter the current stash
  (case-insensitive). A search bar shows the query; ✕ / Esc clears it; "No matches" state.
  Keys are captured via SwiftUI `.onKeyPress` on the focused panel (no global key tap).
- **Keyboard navigation** — arrow keys move a highlight, Return opens the highlighted
  item, Esc clears the search or closes the pocket, and **⌘1–9 switch stashes**.
- Selected-item highlight ring; grid column count tracked for arrow navigation.

**Notes**
- Search/keyboard require the activated (menu-bar-opened) pocket; the hover pocket
  stays mouse-only by design so it never takes focus from your active app.

### Phase 2 (part 1) — drag fix, multiple stashes, themes

**Fixed**
- **Drag-and-drop to add now works.** Dragging a file from Finder is a drag session,
  which NSEvent monitors don't observe — so hovering couldn't open the pocket mid-drag.
  Added a transparent **`DragTriggerWindow`** over the trigger zone whose `draggingEntered`
  opens the pocket, so files can be dragged straight in. (`.leftMouseDragged` also added to
  the hover monitors for in-app drags.)

**Added**
- **Drag-to-remove** — a trash target in the panel header; drag an item onto it to remove
  it from the stash (dragging an item out to Finder still copies it, as before).
- **Multiple stashes** — a stash menu in the header lists all stashes (checkmark on the
  current), with **New Stash… / Rename Stash… / Delete Stash** and quick access to Settings.
  Selection is tracked in `AppState.selectedStashIndex`.
- **Full item context menu** — Open, Reveal in Finder, **Rename…**, **Move to Stash ▸**, Remove.
- **Themes** — System / Light / Dark applied to the pocket panel (`PanelTheme`), selectable
  in Settings.
- **`InputPrompt`** — modal name prompt for creating/renaming stashes and items (the
  non-activating panel can't host a focused text field).
- Panel size now reserves header/toolbar chrome (`PanelLayout.chromeHeight`).

**Still to do in Phase 2:** in-panel search, keyboard navigation + ⌘1–9, extended item
types (URL / folder / Shortcut / script), running-apps section.

### Liquid Glass, easy adding & panel header

**Added**
- **Liquid Glass** background for the pocket (`pocketGlassBackground` → SwiftUI
  `glassEffect` on macOS 26 Tahoe, `NSVisualEffectView` fallback on macOS 15).
- **Panel header** with the stash name plus two controls: **+** (opens an
  `NSOpenPanel` to add apps/files — an explicit alternative to drag-and-drop) and a
  **gear** that opens Settings. The empty state also shows an "Add…" button.
- **Menu-bar icon hardening** — `statusItem.isVisible = true`, filled `tray.full.fill`
  symbol, text fallback if the symbol is missing, and a startup log of the button state.
  Clicking the menu-bar icon shows the menu (Toggle Pocket / Settings / Show Tutorial / Quit);
  Settings is now also one click away from the panel header.

**Notes**
- Two ways to add items: drag-and-drop, or the **+** button (file picker).
- Two ways to reach Settings: the menu-bar icon's menu, or the panel-header gear.

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
