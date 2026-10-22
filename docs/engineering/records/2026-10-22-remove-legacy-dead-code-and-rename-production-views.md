# 2026-10-22 Remove Legacy Dead Code And Rename Production Views

## Requirement Reference
- `docs/human/requirements/20261022-Engineering-Remove Legacy Dead Code And Rename Production Views.md`

## Summary of Changes
1. **Sub-step 1A — Removed Obsolete Thumbnail, Table, and Export Dead Code & Untracked Caches**:
   - Cleaned untracked historical build and bytecode caches on disk (`.build/rust`, `.dart_tool`, `.flutter-plugins-dependencies`, `archive/flutter/.dart_tool`, `archive/flutter/macos/Pods`, `archive/flutter/macos/Flutter/ephemeral`, `scripts/__pycache__`).
   - Removed unused `ThumbnailCache.swift`, `ThumbnailGenerator.swift`, `SearchBench/TestThumbnails.swift` (and its `Package.swift` exclusion), `SubtitleTableHeightInvalidationScheduler.swift`, `SubtitleTableHeightInvalidationWindow.swift`, `SubtitleActiveEntryLookup.swift`, and their obsolete test files.
   - Removed dead item-based single/batch screenshot and item-collage export paths from `AppCoordinator+SubtitleScreenshotExport.swift` and `SubtitleScreenshotExporter.swift` while preserving active collage preview/export pipelines.
   - Removed dead SwiftUI table views from `WorkbenchDataTable.swift`, dead M1 search list helpers from `SearchView.swift`, unused `SubtitleTableTimeRange`/`SubtitleTableSampleData` from `SubtitleTableRow.swift`, unused `TableSandboxHydrationPaging` from `TableSandboxVisibleSearchHydrator.swift`, and dead pre-ADR-0014 materialized row mutation methods from `TableSandboxRowModelStore.swift`.
2. **Sub-step 1B — Removed Playback Overlay Dead Modules, Virtual Reel Window-Request Machinery, and Playback Shims**:
   - Removed unreachable `PlaybackVirtualReelWindowRequestReason`, `PlaybackVirtualReelWindowRequest`, `PlaybackVirtualReelWindowPolicy`, and pending window-request state/methods from `PlaybackSubtitleFocusReel.swift`.
   - Removed retired `.search`, `.library`, and `.excerpt` overlay module cases and state/routing branches from `PlaybackSubtitleFocusSessionStore.swift`, `PlaybackSubtitleFocusActions.swift`, `PlaybackSubtitleFocusOverlay.swift`, `PlaybackStore.swift`, `AppCoordinator+Playback.swift`, and `AppCoordinator+PlaybackSubtitleFocus.swift`.
   - Removed unused `subtitleLoadTask`, `setStringProperty`, `getBoolProperty`, `setBoolProperty`, and `setASSSubtitleTime` from `PlaybackPlayer.swift`, unused `clear(completion:)` from `SourceFaithfulASSSubtitleOverlayView.swift`, and unused uncropped `SFXASSImage` / `SFXASSImageRenderOutput` / `renderImagesAtTimestampMilliseconds` from `CASSRendering`.
3. **Sub-step 1C — Removed Legacy `isRedesign` Switch and Non-Redesign Style Branches Across 46 Files**:
   - Removed the `isRedesign: Bool` parameter and all `isRedesign == false` fallback branches from `SubtitleTableView.swift`, `WorkbenchPageScrollbar.swift`, `SchemaWorkbenchSearchShell.swift`, and `WorkbenchControls.swift`.
   - Removed legacy-only types and palettes (`SubtitleTableColumnLayout.legacy`, `SubtitleTableText.legacyBodyFont`/`indexFont`/`headerFont`, `WorkbenchControlColors`, `WorkbenchControlBackground`, and unused pre-redesign `WorkbenchTagColorID` cases in `WorkbenchTag.swift`).
   - Removed `isRedesign: true` arguments across all 36 source files and 10 test files.

## Verification
- Verified `swift build --package-path apps/macos-native` and targeted unit test suites (`SubtitleScreenshotExporterTests`, `TableSandboxRowModelStoreTests`, `PlaybackSubtitleDatabaseTests`, `SubtitleTableClipboardTests`, `PlaybackExcerptOverlayTests`, `PlaybackMultiModuleOverlayIntegrationTests`, `PlaybackSubtitleFocusLayoutTests`, `PlaybackSubtitleFocusSessionStoreTests`, `PlaybackPlaylistReelAdapterTests`, `CASSRenderingProbeTests`, `SubtitleTableScrollbarMetricsTests`, `SubtitleTableTagStyleTests`, `SubtitleTextLayoutDecorationTests`, `SubtitleTextLayoutTests`, `WorkbenchPageScrollbarTests`, `MenuPanelHeightTests`, `WorkbenchControlMetricsTests`, `WorkbenchInputControlsTests`, `WorkbenchEmptyHintTests`) pass with 0 errors.
