# 2026-10-22 Remove Legacy Dead Code And Rename Production Views

## Requirement Reference
- `docs/human/requirements/20261022-Engineering-Remove Legacy Dead Code And Rename Production Views.md`

## Summary of Changes
1. **Sub-step 1A — Removed Obsolete Thumbnail, Table, and Export Dead Code & Untracked Caches**:
   - Cleaned untracked historical build and bytecode caches on disk (`.build/rust`, `.dart_tool`, `.flutter-plugins-dependencies`, `archive/flutter/.dart_tool`, `archive/flutter/macos/Pods`, `archive/flutter/macos/Flutter/ephemeral`, `scripts/__pycache__`).
   - Removed unused `ThumbnailCache.swift`, `ThumbnailGenerator.swift`, `SearchBench/TestThumbnails.swift` (and its `Package.swift` exclusion), `SubtitleTableHeightInvalidationScheduler.swift`, `SubtitleTableHeightInvalidationWindow.swift`, `SubtitleActiveEntryLookup.swift`, and their obsolete test files.
   - Removed dead item-based single/batch screenshot and item-collage export paths from `AppCoordinator+SubtitleScreenshotExport.swift` and `SubtitleScreenshotExporter.swift` while preserving active collage preview/export pipelines.
   - Removed dead SwiftUI table views from `WorkbenchDataTable.swift`, dead M1 search list helpers from `SearchView.swift`, unused `SubtitleTableTimeRange`/`SubtitleTableSampleData` from `SubtitleTableRow.swift`, unused `TableSandboxHydrationPaging` from `TableSandboxVisibleSearchHydrator.swift`, and dead pre-ADR-0014 materialized row mutation methods from `TableSandboxRowModelStore.swift`.

## Verification
- Verified `swift build --package-path apps/macos-native` and targeted unit test suites (`SubtitleScreenshotExporterTests`, `TableSandboxRowModelStoreTests`, `PlaybackSubtitleDatabaseTests`, `SubtitleTableClipboardTests`, `PlaybackExcerptOverlayTests`, `PlaybackMultiModuleOverlayIntegrationTests`) pass with 0 errors.
