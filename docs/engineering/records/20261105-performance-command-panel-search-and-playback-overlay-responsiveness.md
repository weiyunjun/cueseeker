# 2026-11-05 Performance: Command Panel Search And Playback Overlay Responsiveness

## Relevant Human Documentation

- `docs/human/requirements/20261105-Performance-Command Panel Search And Playback Overlay Responsiveness.md`
- `docs/human/design/ui/Playback.md`

## Implementation Summary

1. **Command Panel Root Live Count & Interruptible On-Demand Result Loading:**
   - Added token-scoped SQLite statement interruption (`beginInterruptibleExecution`, `endInterruptibleExecution`, `interrupt` via `sqlite3_interrupt`) in `SQLiteDatabase` and `SearchDatabase`, and updated `SQLiteStatement.step()` to reset interrupted statements and throw `CancellationError`.
   - Added `SearchDatabase.searchResultCount` to compute exact matching cue totals without allocating `SubtitleSearchResult` rows, `CueContent`, `CueFacetSnapshot`, or `SubtitleSearchFileSummary` arrays, and wired `cueOccurrenceCount` to reuse it.
   - Wrapped `SearchStore.startSearch` and `SearchStore.startCountOnlySearch` inside `withTaskCancellationHandler` with `SearchInterruptibleReadHandle` so cancelling an in-flight search immediately interrupts any active SQLite read statement instead of blocking subsequent queries on the database lock.
   - Updated Command Panel Root live search (`updatePlaybackCommandPanelLiveSearchIfNeeded`) to run count-only queries (`startCountOnlySearch`), promoting 0-match snapshots in-place when entering `.searchResults` and loading full cue results on demand when entering `.searchResults` or returning to Workbench `Search`.
2. **Non-Blocking Auto-Pause When Opening Command Panel & Playback Overlay:**
   - Added `CompleteLibraryVideoPresentation.replacingPlaybackHistory` and `CompleteLibraryFolderDetailPresentation.replacingPlaybackHistories`.
   - Updated `LibraryStore.applyImmediatePlaybackHistoryPresentationUpdates` to update cached `completeLibraryFolderDetailsByPath` snapshots in-place using single-row `libraryPlaybackHistory(forVideoFile:)` queries instead of re-querying full folder details (`completeLibraryFolderDetail(folderPath:)`) on the main thread or spawning redundant background library snapshot rebuilds on every auto-pause.
   - Updated `AppCoordinator.openPlaybackSubtitleFocusFromUser` to reuse cached `completeLibraryFolderDetailsByPath` and skip preparation-window SQLite queries when resolving the subtitle source.
   - Consolidated `LibraryDatabase.upsertLibraryPlaybackHistory` into a single immediate transaction, bypassed redundant `FileManager` attribute lookups and `video_files` upserts when the indexed video row already exists, skipped no-op `library_watch_states` writes when already `.watching`, and added `CueFacetCountCache.adjustWatchStates` to update `watchStatus` facet counts incrementally per video instead of scanning all `subtitle_cue_lines` rows on watch-state transitions.
3. **Subtitle Focus Reel First-Frame Rendering & Memory Optimization:**
   - Replaced `revision` in `PlaybackSubtitleFocusReelDocumentView.RowBitmapCacheKey` with `presentationStyleToken` (`displayTitle` for `PlaybackSubtitleFocusCueReelAdapter`, `showsCueGroup` for `PlaybackCueResultReelAdapter`) and preserved `rowBitmapCache` across same-dataset, same-generation, same-style content expansions (`completeCueBatch` / `appendLoadedItems`).
   - Skipped redundant `needsDisplay = true` invalidations in `updateContent` and `updateLocalLayout` when resolved viewport placements and viewport size are unchanged.
   - Wrapped offscreen row bitmap rendering in `autoreleasepool`, cached `CGColorSpace.sRGB`, reduced `rowBitmapCacheCapacity` from `32` to `18`, and released row bitmap cache storage when the document view detaches from its window or is invalidated.
   - Removed redundant full-window `CALayer` backing-store color allocation on `PlaybackSubtitleFocusPointerShieldView` and deduplicated stacked `PlaybackTheme.subtitleFocusOverlayBackground` layers in `PlaybackSubtitleFocusOverlay`.

## Verification

- Executed unit tests in `PlaybackSubtitleFocusKeyboardActionTests`, `PlaybackSubtitleFocusLayoutTests`, `LibraryDatabaseTests`, `RecentPlaybackSessionRegressionTests`, and `LibraryRouteSnapshotReuseTests`, including new tests covering Command Panel Root count-only search, on-demand `.searchResults` loading, Workbench `Search` reappearance refresh, `completeCueBatch` row bitmap cache preservation, and incremental `watchStatus` facet count updates.
- Result matched expectations.
