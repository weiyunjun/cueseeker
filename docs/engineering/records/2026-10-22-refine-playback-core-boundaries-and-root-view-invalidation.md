# 2026-10-22 Refine Playback-Core Boundaries And Root View Invalidation

## Requirement Reference
- `docs/human/requirements/20261022-Engineering-Refine Playback Core Boundaries And Root View Invalidation.md`

## Summary of Changes
1. **Step 1 — Eliminated Read-Query Write Side Effects, Unified Folder Path Matching, and Isolated Root/Scroll Invalidation**:
   - Removed hidden `clearRecentExcerptPlayback` and `updateRecentExcerptFallbackCue` write mutations from `ExcerptDatabase.recentExcerptListSummaries()`, moving recent-cue reconciliation into `reconcileRecentExcerptPlayback(forListID:)` inside the write transactions of `removeExcerpt(id:)` and `transferExcerpt(id:toListID:removesSource:)`.
   - Unified the 5 duplicate folder path prefix and `/var/` $\leftrightarrow$ `/private/var/` variant matching implementations into `MediaFolderPathMatching` in `CueSeekerCore/RemoteFolderCommon.swift`.
   - Removed unused `@EnvironmentObject` subscriptions from `AppTopBar` (`LibraryStore`, `ExcerptStore`), extracted dialog-layer state subscriptions (`confirmation`, `tasks`, `libraryStore`, `excerptStore`, `filterDialog`) into `ContentDialogLayerHost` while preserving `@EnvironmentObject private var playback: PlaybackStore` on `ContentRootView` so expanding/collapsing the playback page immediately hides/restores workbench chrome.
   - Replaced the unconditional `@ObservedObject` subscription on `PointerHoverModifier` with active-only listener registration in `PointerHover.swift` using a `@StateObject`-managed `PointerHoverSession` with full `.onAppear` / `.onDisappear` lifecycle synchronization.
2. **Step 2 — Decoupled `CueSeekerPlayback` from Direct Database Opens, Collage Naming Rules, and Cover/Metadata Persistence Orchestration**:
   - Defined `PlaybackSubtitleRenderCacheProviding` (including `cacheScopeID`) and `PlaybackSubtitleRenderCacheReader` in `CueSeekerCore/PlaybackSubtitleDatabase.swift`, removed `renderCacheDatabaseURL` from `PlaybackSubtitleSource` and `ASSPlaybackFontIntentProvider.swift`, and updated `SourceFaithfulASSSubtitleOverlayView.swift` and `SubtitleScreenshotExporter.swift` so `CueSeekerPlayback` no longer holds database file paths or opens `PlaybackSubtitleDatabase` directly.
   - Moved collage default filename formatting into `SubtitleCollageSelectionPlan.defaultCollageFileName(displayTitle:plan:)` in `CueSeekerCore/SubtitleCollage.swift`.
   - Moved `LibraryCoverDisplayRenditionCommitGate.swift`, `LibraryCoverDisplayRenditionGenerator.swift`, and `LibraryCoverDisplayRenditionIndexer.swift` into `CueSeekerCore/`, extracted cover candidate scoring, freshness checks, folder cover reference refresh, and batch cover commit orchestration into `CueSeekerCore/LibraryCoverCandidateScorer.swift`, and moved video metadata backfill persistence into `PlaybackVideoMetadataPersistence.indexVideoMetadata(...)` in `CueSeekerCore/LibraryDatabaseProtocols.swift`.

## Verification
- Verified `ExcerptDatabaseTests`, `IndexPathIdentityTests`, `PointerHoverGateTests`, `CueGroupRefreshScopeIntegrationTests`, `PlaybackRequestTests`, `LibraryCoverIndexerTests`, `LibraryCoverDisplayRenditionTests`, `PlaybackVideoMetadataIndexerTests`, `SubtitleScreenshotExporterTests`, and `SubtitleCollageTests` pass (118 tests across suites, 0 failures, 0 new warnings).
