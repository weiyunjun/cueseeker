# 2026-10-22 Refine Playback-Core Boundaries And Root View Invalidation

## Requirement Reference
- `docs/human/requirements/20261022-Engineering-Refine Playback Core Boundaries And Root View Invalidation.md`

## Summary of Changes
1. **Step 1 — Eliminated Read-Query Write Side Effects, Unified Folder Path Matching, and Isolated Root/Scroll Invalidation**:
   - Removed hidden `clearRecentExcerptPlayback` and `updateRecentExcerptFallbackCue` write mutations from `ExcerptDatabase.recentExcerptListSummaries()`, moving recent-cue reconciliation into `reconcileRecentExcerptPlayback(forListID:)` inside the write transactions of `removeExcerpt(id:)` and `transferExcerpt(id:toListID:removesSource:)`.
   - Unified the 5 duplicate folder path prefix and `/var/` $\leftrightarrow$ `/private/var/` variant matching implementations into `MediaFolderPathMatching` in `CueSeekerCore/RemoteFolderCommon.swift`.
   - Removed unused `@EnvironmentObject` subscriptions from `AppTopBar` (`LibraryStore`, `ExcerptStore`), extracted dialog-layer state subscriptions (`confirmation`, `tasks`, `libraryStore`, `excerptStore`, `filterDialog`) into `ContentDialogLayerHost` while preserving `@EnvironmentObject private var playback: PlaybackStore` on `ContentRootView` so expanding/collapsing the playback page immediately hides/restores workbench chrome.
   - Replaced the unconditional `@ObservedObject` subscription on `PointerHoverModifier` with active-only listener registration in `PointerHover.swift` using a `@StateObject`-managed `PointerHoverSession` with full `.onAppear` / `.onDisappear` lifecycle synchronization.

## Verification
- Verified `ExcerptDatabaseTests`, `IndexPathIdentityTests`, `PointerHoverGateTests`, and `CueGroupRefreshScopeIntegrationTests` pass (49 tests, 0 failures).
