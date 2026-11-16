# 2026-11-16 Excerpt List Unified Entry Playback and Cover Summary Progress

- **Covering Requirement**: `docs/human/requirements/20261116-Feature-Excerpt List Unified Entry Playback And Cover Summary Progress.md`
- **Referenced Design Documents**:
  - `docs/human/design/data/Data.md`
  - `docs/human/design/workbench/Excerpt and Export.md`
  - `docs/human/design/playback/Command Panel.md`
  - `docs/human/design/playback/Playback Edge Cases.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
  - `docs/human/design/ui/UI Layouts - Playback.md`
  - `docs/human/design/ui/Toast Usage Registry.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `1dd7306`, requirement commit `5b128c4`)

## Scope

1. Separate full valid excerpt count (`xx`) from filtered valid excerpt count (`yy`) across excerpt list cards, detail table toolbar, and detail `Cover Summary` progress (`#x / yy`).
2. Limit target excerpt (`recent_cue_id`) writes strictly to actual playback actions, and permanently clear `recent_cue_id` (while preserving `recent_played_at`) when the target excerpt is deleted/moved out of the list or invalidated by folder removal/tombstoning.
3. Implement three-state `Cover Summary` progress (`Resume` `#x / yy`, `Play` `#1 / yy`, and `Disabled` `Play` with hidden progress when `yy = 0`) for `Excerpt` detail view without modifying `CoverSummaryCard` or changing unwatched `Library` folders.
4. Unify playback sequence resolution across all three excerpt list entry points (Workbench `Recent -> Excerpt Lists`, Playback `Command Panel -> Recent Excerpt Lists`, and `Excerpt` detail `Play` / `Resume`) using each list's runtime search query, persisted facet filter, and persisted sort order.

## Summary of Changes

1. **Permanent Target Excerpt Clearing in `CueSeekerCore`**:
   - Added `ExcerptList.clearingRecentCue()` in `apps/macos-native/Sources/CueSeekerCore/ExcerptDatabaseModels.swift`.
   - Removed fallback target cue rebinding in `apps/macos-native/Sources/CueSeekerCore/ExcerptDatabase.swift`: `recentExcerptListSummaries()` reads `recent_cue_id` directly, `reconcileRecentExcerptPlayback(forListID:)` clears `recent_cue_id` to `NULL` while preserving `recent_played_at` when the target cue is absent or invalid, and `updateRecentExcerptFallbackCue(listID:cueID:)` was deleted.
   - Updated `reconcileExcerptListRecentCues()` in `apps/macos-native/Sources/CueSeekerCore/IndexingDatabase+TombstoneReconciliation.swift` to clear `recent_cue_id` (`UPDATE excerpt_lists SET recent_cue_id = NULL WHERE recent_cue_id IS NOT NULL AND NOT EXISTS (...)`) instead of rebinding to another cue, preserving `recent_played_at` and ensuring folder re-addition does not restore the cleared target excerpt.

2. **Shared Table/Playback Projection & `Cover Summary` Three-State Logic in `CueSeekerApp`**:
   - Updated `apps/macos-native/Sources/CueSeekerApp/Excerpt/ExcerptStore.swift`:
     - Kept `activeListSummary` aligned to `recent.list` and updated `activeListHasPlayableContent` to check filtered `playbackTableResultExcerptIDs` after `tableHasLoadedInitialPage` completes (relying on `summary.cueCount > 0` prior to initial load).
     - Added `tableSearchQuery(forListID:)`, `activeListCoverSummaryState(for:)`, `syncOverviewListMetadata(from:)`, and shared `facetProjection(relations:facetSnapshot:using:)`.
     - Updated `adjustListCueCounts` so in-page deletion or removal of the active target excerpt synchronously clears `recentCueID`, `resumeExcerpt`, and `resumePosition` (keeping `recentPlayedAt`) even while the detail view is frozen on background library updates.
   - Extracted shared `projectRelations(...)` in `apps/macos-native/Sources/CueSeekerApp/Excerpt/ExcerptStore+Execution.swift` for both `residentExcerptTableProjection` and `resolveListPlayback(listID:settings:normalizeFacetFilter:)`, and synced overview list metadata in `moveExcerpt`, `moveExcerpts`, `removeExcerpts`, and `recordRecentExcerptPlayback`.
   - Wired `coverSummary` and `coverSummaryProgress` in `apps/macos-native/Sources/CueSeekerApp/Excerpt/WorkbenchExcerptTableView.swift` to `excerptStore.activeListCoverSummaryState(for:)` so line 1 continues showing full valid count `xx` while progress reflects `#x / yy` (`Resume`), `#1 / yy` (`Play`), or hidden progress with disabled `Play` (`yy = 0`), avoiding spurious `Disabled` or `#1 / 0` flashes before initial async load.

3. **Unified Three-Entry Playback Resolution & Command Panel Interception**:
   - Unified `openRecentExcerpt` and `openExcerptListPlayback` in `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Excerpt.swift` via `resolveExcerptListPlayback(listID:)` and `openResolvedExcerptListPlayback(target:navigationScopeIDs:ordinal:)`.
   - Updated `openPlaybackCommandPanelRecentExcerpt(at:)` in `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackCommandPanel.swift` to resolve `resolveExcerptListPlayback(listID:)` before calling `dismissPlaybackCommandPanelForAction()`, keeping the Command Panel open and showing `PlaybackToastRequest.noAvailableExcerpts` (`No Available Excerpts` / `没有可用的摘录` / `沒有可用的摘錄`) when `yy = 0` without modifying `recent_played_at`.

4. **Pure-Logic & SQLite Unit Tests**:
   - Updated `recentExcerptPlaybackClearsTargetAnchorOnRemovalAndMoveWithoutFallbackRebind`, `readOnlyExcerptDatabaseLoadsRecentSummariesWithoutWriteAttemptWhenNoPlayableExcerpts`, and `playedExcerptListKeepsRecentPlayedTimestampAndDoesNotAutoRestoreCueAnchorOnFolderReAdd` in `apps/macos-native/Tests/CueSeekerCoreTests/ExcerptDatabaseTests.swift`.
   - Updated `resurrectingVideoAndCueDoesNotAlterExistingFolderOrExcerptListResumeOrder` in `apps/macos-native/Tests/CueSeekerCoreTests/IndexPathIdentityTests.swift`.
   - Added `listCoverSummaryAndUnifiedPlaybackResolveSearchFilterSortAndTemporaryFallback` and `removingTargetExcerptWhileFrozenRevertsCoverSummaryToPlaySynchronouslyAndPreservesPlayedAt` in `apps/macos-native/Tests/CueSeekerAppTests/ExcerptLifecycleAndInvalidItemsTests.swift`.

5. **Iterative Acceptance Fix - O(1) `Cover Summary` State Resolution & Projection Deduplication**:
   - Eliminated the `O(N^2)` nested linear scan (`validExcerptIDs.firstIndex` over `residentRelations.first(where:)`) and repeated per-render array filtering in `ExcerptStore.swift` by maintaining direct `cueID <-> excerptID` resident lookup maps plus precomputed valid result IDs and ordinals whenever resident relations or table result IDs update, and guarding unchanged `@Published` count/load assignments.
   - Skipped unused facet distribution reconstruction (`includeDistribution: false`) in `ExcerptStore+Execution.swift` when applying table sort/search/filter projections or resolving list playback.
   - Deduplicated `coverSummary` construction in `WorkbenchExcerptTableView.swift` so a single `body` pass evaluates `Cover Summary` once instead of building a discarded duplicate for `SchemaWorkbenchSearchShell`.

## Verification

- `swift build --package-path apps/macos-native`: succeeded (`Build complete! (7.06s)`, `0` errors).
- Targeted headless unit tests (`swift test --package-path apps/macos-native --filter "..."` covering `ExcerptLifecycleAndInvalidItemsTests`, `ExcerptListEditorTests`, `ExcerptPerformanceTrackerTests`, `ExcerptPresentationTests`, `PlaybackEntryAndExcerptNavigationTests`, `PlaybackExcerptOverlayTests`, `TableSandboxRowModelStoreTests`, `TableSandboxRowSelectionStateTests`, and `ExcerptDatabaseTests`): `91` tests passed in `0.881` seconds (`0` failures).

## Outcome

Target excerpt tracking, three-state `Cover Summary` progress (`#x / yy`, `#1 / yy`, `Disabled` when `yy = 0`), and three-entry playback sequence resolution are aligned on one projection pipeline and verified with headless pure-logic and SQLite tests. Pending user end-to-end UI acceptance before any post-acceptance `docs/human/design/` sync.
