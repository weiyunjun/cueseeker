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
- Click a search result to open or update the matching local video in the
  embedded Playback Area at the matching timestamp.
- Provide an embedded playback experience inside the CueSeeker workbench.
- Provide a usable native macOS shell with a basic Settings surface.

Acceptance criteria:

- The app does not depend on Flutter.
- The app can run on the documented minimum supported macOS version.
- The app can index local `.srt` files.
- The app can search indexed subtitle content.
- The app can open a matching local video from a search result.
- The app can seek to the subtitle start timestamp.
- The matching video renders inside the native app window, not in an external player window.
- Clicking a search result opens or updates the embedded Playback Area without
  leaving Search.
- Collapsing the Shared Content Panel preserves the selected result and does not
  pause playback.
- Switching from Search to another top-level section pauses playback without stopping it.
- Reopening the Shared Content Panel does not automatically change playback
  state.
- Clicking the embedded video toggles play/pause.
- Repeated selection within the same video should seek rather than reload the video when practical.
- Search is available through the native app shell.
- A basic Settings surface is available for folder management and decode
  configuration.
- Remote playback and advanced visual effects are out of scope.

M1 acceptance status:

- Accepted on 2026-04-28.
- The project owner has manually reviewed the current UI interactions and confirmed that the Search, Settings, and embedded playback workflow are usable for the M1 milestone.
- The implementation reviewed on 2026-04-28 exceeded the M1 milestone bar for UI interaction quality at that time, even though future UI and playback refinements remain expected.
- The automated Swift test suite passed with 23 tests on 2026-04-28 using `swift test --package-path apps/macos-native`.

Accepted M1 implementation summary:

- The legacy Flutter implementation is archived under `archive/flutter/`.
- The active native macOS app lives under `apps/macos-native/`.
- Core subtitle scanning, parsing, same-directory video matching, SQLite persistence, FTS5 search, incremental reindexing, and basic settings are implemented.
- Embedded playback now uses the project-owned native backend, replacing the
  earlier `libmpv`-primary bridge and later native-first fallback bridge.
- The app shell has moved to a custom native shell with AppKit titlebar controls and SwiftUI content.
- The Search workflow uses embedded playback instead of dedicated playback-page
  navigation. The accepted workbench layout direction places Library, Search,
  and Shiori behind a fixed left Mode Rail and a shared collapsible content
  panel beside the central Playback Area.

Known post-M1 follow-up areas:

- Search ranking, query semantics, CJK behavior, and other search-quality improvements require dedicated post-M1 design work and should not block M1 acceptance.
- ASS subtitle indexing, grouped cue search results, and ASS result click-to-play
  behavior are M2 feature work. M1 remains accepted as the minimal SRT loop.
  Source ASS playback rendering started with the accepted ASS Lite subset, but
  complex ASS playback should move to the accepted source-faithful rendering
  pipeline.
- Keyboard shortcuts, playback interaction refinement, native menu behavior, file and folder management, file-access persistence, error presentation, settings refinement, and packaging preparation belong to M2.
- Post-M1 settings refinement should move Settings to the macOS app menu and an
  independent Settings window so the main workspace remains focused on Search,
  playback, and future content or learning panels.
- Window sizing and restoration were substantially completed during M1 and should be treated as M2 regression-verification areas unless concrete defects are found.
- The native-only playback integration requires focused app-level regression
  testing before it is treated as fully stabilized.
- UI polish may continue in M2, but the current UI is accepted for the M1 minimal local loop.

## 4. M2: macOS Experience Polish

Planning status:

- Started on 2026-04-28 after the M1 native macOS minimal local loop was accepted.
- M2 scope is being refined from broad macOS polish into reviewable interaction, file-management, error, settings, and packaging work.
- Playback interaction work has started and currently includes video-level
  playback fullscreen, playback operation controls, keyboard shortcuts, and
  visible feedback overlays.
- ASS subtitle search support is included in M2 planning as a search, indexing,
  playback-selection, and data-model migration feature.
- The first ASS support implementation is complete in the native app: `.ass`
  files are indexed, grouped cue search results are displayed, and selecting an
  ASS result opens or updates playback at the cue group's `start_ms`.

Goal:

- Improve native macOS behavior around menus, keyboard shortcuts, playback interaction, file permissions, error presentation, settings, and packaging readiness.

Expected areas:

- Native menu bar.
  Define and implement standard macOS menu commands for app-level, file, edit, view, playback, and window operations.
- Keyboard shortcut model.
  Define shortcut commands, focus scope, and conflict rules, especially for search text input and playback context.
- Playback interaction model.
  Refine playback controls, progress and seek interaction, action buttons, and visual feedback such as operation HUD or animation. Playback controls and keyboard shortcuts should share the same underlying playback command model.
  Current implementation includes an app-drawn upward playback speed menu, hover-based speed preset selection, subtitle visibility toggle, video-surface-only play/pause tapping, playback operation-zone click isolation, playback fullscreen, keyboard shortcuts, and transient feedback overlays.
  Recent playback refinements align keyboard speed limits with playback controls, add the `1.75x` speed preset, use `5%` keyboard volume steps, keep timeline and volume hover states vertically stable, keep playback shortcuts active while read-only metadata text is selected, and suppress initial fullscreen hover events so controls and the cursor remain hidden immediately after entering fullscreen.
  Accepted interaction refinements also cover the AppKit Full Screen Space
  direction for playback fullscreen, Search field focus clearing for app-owned
  interactions, Search field focus preservation for system-level window or app
  switching, mouse-only fullscreen chrome reveal, and speed menu hover geometry
  that matches the speed button click area.
- ASS subtitle search and grouped result support.
  The native app now scans `.ass` files, parses ASS dialogue events, indexes cue
  groups and cue lines, displays grouped search results, and supports
  click-to-playback behavior for matched ASS results. Source ASS subtitle
  rendering should preserve readable search projection semantics while moving
  playback toward the accepted non-blocking, source-faithful ASS rendering
  pipeline.
- Window sizing and restoration regression verification.
  M1 already implemented launch maximization, AppShell layout persistence, and titlebar/full-screen behavior. M2 should verify these behaviors, including the accepted shared content panel width and visibility behavior, and fix concrete regressions rather than treating this as a new major feature area.
- File and folder management with file-access persistence.
  Complete local folder management, including folder removal, reindex behavior, missing-folder handling, and restart behavior for previously selected folders.
- Left Library panel.
  Add the first Shared Content Panel mode for known-video navigation: gray
  Library panel, flat collapsible folder groups, Finder-like natural sorting,
  friendly video rows with extension and duration, and Library-only resume
  history. The Shared Content Panel should be collapsible from the fixed Mode
  Rail and resizable after launch, with its default width equal to the minimum
  width.
- Error presentation.
  Provide understandable user-facing errors for file access, indexing, database, search, and playback failures.
- App settings.
  Move Settings to `CueSeeker > Settings...` and provide an independent
  two-column Settings window with current `Library` and `Decode` categories.
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
- Window sizing, restoration, titlebar, full-screen, and workbench panel
  persistence behavior remain stable after M2 changes.
- Settings can be opened from the app menu without pausing playback or changing
  CueSeeker workbench state.

## 5. M3: Shiori and Personal Learning Flow

Goal:

- Add a lightweight personal learning layer on top of the local search and playback workflow.

Expected areas:

- Save the current subtitle cue as a Shiori.
- View saved Shiori subtitle cues.
- Remove Shiori records.
- Jump from a Shiori row to the matching video timestamp.
- Preserve Shiori identity across reindexing when possible.
- Present Shiori as durable saved learning content in the Shared Content Panel
  for the first implementation.
- Allow Shiori records to feed future Queue or Learning Session workflows after
  those workflows and their placement are documented.

Acceptance criteria:

- Shiori records persist locally.
- Shiori records remain linked to source subtitle timing.
- Shiori actions are available through UI and keyboard interaction.
- Shiori has a documented home in the content-navigation and learning-panel
  model before implementation is treated as complete.

## 6. Explicitly Deferred

The following are deferred until the local-first product is stable:

- Playback Queue and configurable Learning Session modes, unless they are pulled
  into a documented milestone before implementation.
- Remote subtitle indexing.
- Remote video playback.
- Local HTTP proxy.
- Remote cache management.
- Anki integration.
- Vocabulary book workflows.
- Advanced real-time video visual effects.
- Cross-platform support.
- Public release work.
