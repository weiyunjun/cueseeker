# Scope and Milestones

Status: Draft

## 1. Scope Philosophy

The native rewrite should be built in small milestones.

Each milestone must produce a reviewable result. Features that are not required for the current milestone should not block the current milestone.

The provisional minimum supported system version is macOS 13.0 Ventura. This may be revised before implementation if core architecture decisions require a newer version.

## 2. M0: Governance and Baseline

Goal:

- Confirm project governance.
- Confirm product documentation structure.
- Initialize Git if needed.
- Freeze the existing Flutter implementation.
- Archive the Flutter implementation for reference.

Acceptance criteria:

- Project governance document is reviewed.
- Product documents exist under `docs/product/`.
- Git baseline exists.
- Existing Flutter code is preserved.
- Archived Flutter code is available for reference.

## 3. M1: Native macOS Minimal Loop

Goal:

- Create a native macOS application.
- Select one or more local subtitle folders.
- Scan `.srt` files.
- Parse subtitle entries.
- Match subtitle files to same-directory local video files.
- Write subtitle entries to SQLite + FTS5.
- Search subtitle text.
- Click a search result to open or update the matching local video in the Playback Inspector at the matching timestamp.
- Provide an embedded playback experience inside the Search workspace.
- Provide a usable native macOS shell with Search and Settings navigation.

Acceptance criteria:

- The app does not depend on Flutter.
- The app can run on the documented minimum supported macOS version.
- The app can index local `.srt` files.
- The app can search indexed subtitle content.
- The app can open a matching local video from a search result.
- The app can seek to the subtitle start timestamp.
- The matching video renders inside the native app window, not in an external player window.
- Clicking a search result opens or updates the Playback Inspector without leaving Search.
- Collapsing the Playback Inspector pauses playback and preserves the selected result.
- Switching from Search to another top-level section pauses playback without stopping it.
- Reopening the Playback Inspector does not automatically resume playback.
- Clicking the embedded video toggles play/pause.
- Repeated selection within the same video should seek rather than reload the video when practical.
- Search and Settings are available through the native app shell.
- Remote playback and advanced visual effects are out of scope.

M1 acceptance status:

- Accepted on 2026-04-28.
- The project owner has manually reviewed the current UI interactions and confirmed that the Search, Settings, Playback Inspector, and embedded playback workflow are usable for the M1 milestone.
- The current implementation exceeds the M1 milestone bar for UI interaction quality, even though future UI and playback refinements remain expected.
- The automated Swift test suite passed with 23 tests on 2026-04-28 using `swift test --package-path apps/macos-native`.

Accepted M1 implementation summary:

- The legacy Flutter implementation is archived under `archive/flutter/`.
- The active native macOS app lives under `apps/macos-native/`.
- Core subtitle scanning, parsing, same-directory video matching, SQLite persistence, FTS5 search, incremental reindexing, and basic settings are implemented.
- Embedded playback now uses the project-owned native backend, replacing the
  earlier `libmpv`-primary bridge and later native-first fallback bridge.
- The app shell has moved to a custom native shell with AppKit titlebar controls and SwiftUI content.
- The Search workflow now uses the Playback Inspector instead of dedicated playback-page navigation.

Known post-M1 follow-up areas:

- Search ranking, query semantics, CJK behavior, and other search-quality improvements require dedicated post-M1 design work and should not block M1 acceptance.
- ASS subtitle indexing, grouped cue search results, and ASS result click-to-play
  behavior are M2 feature work. M1 remains accepted as the minimal SRT loop.
  Source ASS playback rendering is deferred beyond the first ASS implementation
  step.
- Keyboard shortcuts, playback interaction refinement, native menu behavior, file and folder management, file-access persistence, error presentation, settings refinement, and packaging preparation belong to M2.
- Window sizing and restoration were substantially completed during M1 and should be treated as M2 regression-verification areas unless concrete defects are found.
- The native-only playback integration requires focused app-level regression
  testing before it is treated as fully stabilized.
- UI polish may continue in M2, but the current UI is accepted for the M1 minimal local loop.

## 4. M2: macOS Experience Polish

Planning status:

- Started on 2026-04-28 after the M1 native macOS minimal local loop was accepted.
- M2 scope is being refined from broad macOS polish into reviewable interaction, file-management, error, settings, and packaging work.
- Playback interaction work has started and currently includes video-level Theater Mode fullscreen, playback operation controls, keyboard shortcuts, and visible feedback overlays.
- ASS subtitle search support is included in M2 planning as a search, indexing,
  playback-selection, and data-model migration feature.

Goal:

- Improve native macOS behavior around menus, keyboard shortcuts, playback interaction, file permissions, error presentation, settings, and packaging readiness.

Expected areas:

- Native menu bar.
  Define and implement standard macOS menu commands for app-level, file, edit, view, playback, and window operations.
- Keyboard shortcut model.
  Define shortcut commands, focus scope, and conflict rules, especially for search text input and playback context.
- Playback interaction model.
  Refine playback controls, progress and seek interaction, action buttons, and visual feedback such as operation HUD or animation. Playback controls and keyboard shortcuts should share the same underlying playback command model.
  Current implementation includes an app-drawn upward playback speed menu, hover-based speed preset selection, subtitle visibility toggle, video-surface-only play/pause tapping, playback operation-zone click isolation, Theater Mode fullscreen, keyboard shortcuts, and transient feedback overlays.
  Recent playback refinements align keyboard speed limits with playback controls, add the `1.75x` speed preset, use `5%` keyboard volume steps, keep timeline and volume hover states vertically stable, keep playback shortcuts active while read-only metadata text is selected, and suppress initial fullscreen hover events so controls and the cursor remain hidden immediately after entering fullscreen.
  Accepted interaction refinements also cover Theater Mode suspension during app deactivation, Cmd-Tab switcher visibility above playback fullscreen, Search field focus clearing for app-owned interactions, Search field focus preservation for system-level window or app switching, mouse-only fullscreen chrome reveal, and speed menu hover geometry that matches the speed button click area.
- ASS subtitle search and grouped result support.
  Add `.ass` scanning, ASS dialogue parsing, cue group and cue line indexing,
  grouped search result display, and click-to-playback behavior for matched ASS
  results. The first ASS step does not require rendering the source ASS subtitle
  track during playback.
- Window sizing and restoration regression verification.
  M1 already implemented launch maximization, AppShell layout persistence, titlebar/full-screen behavior, and Playback Inspector width and visibility persistence. M2 should verify these behaviors and fix concrete regressions rather than treating this as a new major feature area.
- File and folder management with file-access persistence.
  Complete local folder management, including folder removal, reindex behavior, missing-folder handling, and restart behavior for previously selected folders.
- Error presentation.
  Provide understandable user-facing errors for file access, indexing, database, search, and playback failures.
- App settings.
  Refine settings beyond the current folder-management surface after the specific M2 settings scope is confirmed.
- Packaging preparation.
  Prepare the app bundle for reliable local review builds, including dependency
  bundling concerns such as FFmpeg and required non-system FFmpeg dependencies.
- Signing and notarization preparation if needed.
  Prepare signing or notarization only if personal distribution beyond local development requires it.

Acceptance criteria:

- The core local workflow feels stable and native.
- Common keyboard interactions do not conflict with text input.
- Playback controls, keyboard shortcuts, and visible playback feedback behave consistently.
- Playback fullscreen affects only the video experience, not the app shell.
- Playback operation controls do not accidentally trigger video-surface play or pause.
- Folder permissions remain available after app restart if required.
- The user can remove configured folders and recover clearly from missing or unavailable folders.
- User-facing errors are understandable.
- Window sizing, restoration, titlebar, full-screen, and inspector persistence behavior remain stable after M2 changes.

## 5. M3: Favorites and Personal Learning Flow

Goal:

- Add a lightweight personal learning layer on top of the local search and playback workflow.

Expected areas:

- Favorite a subtitle line.
- View favorite lines.
- Remove favorites.
- Jump from a favorite to the matching video timestamp.
- Preserve favorite identity across reindexing when possible.

Acceptance criteria:

- Favorites persist locally.
- Favorites remain linked to source subtitle timing.
- Favorite actions are available through UI and keyboard interaction.

## 6. Explicitly Deferred

The following are deferred until the local-first product is stable:

- Remote subtitle indexing.
- Remote video playback.
- Local HTTP proxy.
- Remote cache management.
- Anki integration.
- Vocabulary book workflows.
- Advanced real-time video visual effects.
- Cross-platform support.
- Public release work.
