# Debug Interaction Latency And Main Thread Stall Logging

Human-owned documents:

- `docs/human/requirements/20261101-Engineering-Debug Interaction Latency And Main Thread Stall Logging.md`
- `docs/human/design/system/Logging.md`

## Why

1. **Diagnose UI Stalls and "Empty Mouse Click" (`空键程`) Sensations**:
   - Daily usage across CueSeeker exhibits noticeable stalls and delayed visual transitions when navigating between pages, opening popup menus/submenus/popovers, and presenting or switching inside dialogs.
   - Some delays stem from main-thread synchronous bottlenecks (offscreen `NSHostingView` layout passes, synchronous SQLite queries, font loading), while others stem from visual presentation waiting for uncached data/cover prewarming before swapping the container view.
2. **Collect Structured Diagnostic Data in Debug Builds Without Altering Existing Behavior**:
   - Before changing any UI visual behavior or caching strategy, we need structured, fine-grained `DEBUG`-level timing logs written to `~/Library/Application Support/CueSeeker/logs/debug/cueseeker-YYYY-MM-DD.log` during normal daily usage, strictly compiled/enabled only in Debug builds (`#if DEBUG` and `AppBuildConfiguration.current == .debug`).

## What Changed

1. **Centralized Debug Interaction Latency Probe (`DebugInteractionLatencyProbe.swift`, `AppPerformanceProbe.swift`, `LibraryCoverImagePipeline.swift`)**:
   - Added `DebugInteractionLatencyProbe` (active only in Debug builds) to record structured `DEBUG` logs via `AppLogger.shared.debug(...)` across all 4 diagnostic categories.
   - Updated `LibraryCoverImagePipeline.prewarm(keys:)` to return `LibraryCoverPrewarmStats` (`totalCount`, `cacheHitCount`, `decodedCount`, `elapsedMilliseconds`) without changing its caching or concurrency behavior.
   - Updated `AppPerformanceProbe` so its `CFRunLoopObserver` runs by default in Debug builds with a `32ms` active-phase threshold (excluding normal `beforeWaiting -> afterWaiting` idle sleep) and emits `Main thread stall detected` (`stalled_ms`, `phase`, `last_action`, `last_action_age_ms`).
2. **Category 1 — Page/View Navigation & Transitions (`WorkbenchWorkspaceView.swift`, `PlaybackLibrarySessionStore.swift`, `PlaybackSubtitleFocusOverlay.swift`, `PlaybackCommandPanel.swift`, `AppCoordinator*.swift`, `PlaybackSubtitleFocusSessionStore.swift`, `AppDelegate.swift`, `SettingsView.swift`)**:
   - Instrumented Workbench module switches, Level 1 <-> Level 2 transitions, cross-module jumps (`Resume`/`Play`, `View in File`, `View in Search`, `Locate Video in Library`, `Locate Cue`, `Search Selected Text`), Playback enter/exit, Playback Overlay open/close/module switch/Subtitle Collage enter/exit, Command Panel open/close/drill-down/back, and Settings Window open/category switch.
   - Emits `Workbench navigation completed`, `Playback transition completed`, `Overlay module transition completed`, `Command panel page transition completed`, and `Settings navigation completed` with `sync_prep_ms`, `data_ready_ms`, `cover_prewarm_ms`, `cover_total`, `cover_hit`, `cover_decoded`, `container_wait_ms`, `first_frame_ms`, and `total_ms`.
3. **Category 2 — Popup Menus, Submenus & Popovers (`MenuGate.swift`, `MenuSubmenu.swift`, `WorkbenchPopoverControls.swift`, `LibraryCardContextMenuHost.swift`, `SubtitleTableCoordinator+Menus.swift`, `PlaybackSubtitleFocusReel.swift`, `PlaybackCueFooter.swift`, `PlaybackChromeMoreMenu.swift`, `PlaybackChromeSpeedMenu.swift`, `SchemaWorkbenchSearchShell.swift`, `SettingsLanguageCategory.swift`, `SettingsSubtitleCategory.swift`, `WorkbenchFileView.swift`, `TaskPanel.swift`, `WorkbenchFileDetailDialog.swift`, `AnkiExportDialog.swift`)**:
   - Instrumented all floating menus, submenus, and popovers for both opening (`Menu open completed` with `prep_and_measure_ms`, `measure_passes`, `first_frame_ms`, `total_ms`) and item selection (`Menu item action executed` with `elapsed_ms`).
4. **Category 3 — In-Window Dialogs, Dialog Internal Transitions & System File Panels (`WorkbenchDialogLayer.swift`, `AppCoordinator+FileDetail.swift`, `AppCoordinator+RemoteFolderDialogs.swift`, `AppCoordinator+AnkiExport.swift`, `AppCoordinator+SubtitleScreenshotExport.swift`, `LibraryStore+Execution.swift`, `ExcerptStore+Execution.swift`, `WorkbenchFileView.swift`, `TaskPanel.swift`, `WorkbenchFileDetailDialog.swift`)**:
   - Instrumented in-window dialog presentation and entrance animation frame gaps (`Dialog open completed` with `sync_prep_ms`, `first_frame_ms`, `anim_duration_ms`, `anim_frames`, `max_frame_gap_ms`, `total_ms`), dialog internal view switches (`Dialog internal transition completed`), and `NSOpenPanel`/`NSSavePanel` invocations (`System file panel completed`).

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter DebugInteractionLatencyProbeTests`
