# 2026-11-16 Search Result Memory Reclamation

- **Covering Requirement**: `docs/human/requirements/20261116-Performance-Search Result Memory Reclamation.md`
- **Referenced Design & Engineering Documents**:
  - `docs/engineering/04_architecture_rules.md` (`ADR-0014`)
  - `docs/human/design/data/Data.md`
  - `docs/human/design/workbench/Search and Filter.md`
  - `docs/human/design/workbench/Excerpt and Export.md`
  - `docs/human/design/playback/Command Panel.md`
  - `docs/human/design/playback/Playback Core.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `bcee7e5`, requirement commit `fe1ea2a`)

## Scope

1. Reclaim obsolete `CueContent` entries from `CueContentStore` instead of allowing distinct searches (`searchResults` cleared on query change without removing underlying `CueContent` objects) to accumulate indefinitely in memory.
2. Enforce one shared 3-way active `cueID` retention union whenever pruning runs:
   - Current `SearchStore` references (`loadedSearchResultCueIDs`, `searchResultCueIDs`, `searchFacetSnapshot?.cueIDs`, and `selectedSearchResult?.entryID`) so Filter tightening/relaxation re-projects in memory without disk reads.
   - Current active search `PlaybackPlaylistSource` bound cue IDs (`kind == .search`, `isActive && !isHeld`) so clearing or count-only editing in Playback `Command Panel` preserves playlist navigation, auto-switch, and overlay `Playlist` rows until playback stops or the playlist source is replaced/cleared.
   - `ExcerptStore` resident cue IDs (`residentRelations` and `residentSnapshotsByListID`) so search pruning/re-runs never invalidate cached Excerpt rows (and converging `AppCoordinator+Search.swift` reappearance cleanup onto safe pruning).
3. Compact or replace storage dictionaries synchronously on `MainActor` without publishing change broadcasts for unused evictions, and offload destruction of large evicted dictionaries plus `AppMemoryPressureRelief.relieveAfterLargeResultRelease` onto `DispatchQueue.global(qos: .utility)`.
4. Keep full single-round result residency unchanged (no sliding window).

## Summary of Changes

1. **`CueContentStore` Compact Reclamation & Offloaded Release (`apps/macos-native/Sources/CueSeekerApp/Shared/CueContentStore.swift`)**:
   - Added private `EvictedCueContentStorageBox` to transfer ownership of swapped-out `[Int64: CueContent]` dictionaries off `MainActor`.
   - Added `reclaimUnused(retaining:)` (plus `installPrebuilt(_:publishesChange:reclaimingOutside:)` and `installPrebuiltReclaiming(_:extraRetainedCueIDs:)`): swaps `contentByCueID` with `[:]` or a compact rebuilt dictionary when capacity is oversized (`shouldCompactCapacity`) or retained count is smaller than current count, emits zero `changes` notifications for unreferenced reclamation, and dispatches `box.release()` followed by `AppMemoryPressureRelief.relieveAfterLargeResultRelease` on `DispatchQueue.global(qos: .utility)` when `removedCount >= 1_000` or `previousCapacity >= 4_096`.

2. **Search `PlaybackPlaylistSource` & `ExcerptStore` Retention Exposure**:
   - `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackPlaylistSource.swift`: stored `residentCueIDs` (passed at initialization and in `replaceResidentItems`), cleared it on `holdItems` / `invalidate`, and exposed `activeSearchCueIDs` when `isActive && !isHeld && origin.kind == .search`.
   - `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackPlaylist.swift`: passed bound `cueIDs` when installing or refreshing search playlist sources in `installSearchPlaybackPlaylistSource` and `refreshSearchPlaybackPlaylistSource`.
   - `apps/macos-native/Sources/CueSeekerApp/Excerpt/ExcerptStore.swift`: added `residentCueIDs` computed property over `residentRelations` and cached `residentSnapshotsByListID`.
   - `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackStore.swift`: added `onPlaylistSourceDidChange` callback fired immediately after assigning/clearing `playlistSource` (avoiding `@Published` `willSet` timing ambiguity).

3. **`SearchStore` & `AppCoordinator` Reclamation Triggers**:
   - `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift` & `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore+Execution.swift`: added `externalRetainedCueIDsProvider`, `reclaimUnusedCueContent()`, and `retainedCueIDs()` unioning search state (`loadedSearchResultCueIDs`, `searchResultCueIDs`, `searchFacetSnapshot?.cueIDs`, `selectedSearchResult?.entryID`) with `externalRetainedCueIDsProvider`; wired reclamation into `commitExactSearchPage` (using `installPrebuilt(_:publishesChange:reclaimingOutside:)` where applicable), `commitCountOnlySearch`, and empty-query / zero-folder skip paths in `startSearch` and `startCountOnlySearch` without rebuilding on intermediate non-empty keystrokes. Removed synchronous `MainActor` `AppMemoryPressureRelief` calls from `resetResultLoadingState()` and `WorkbenchSearchView.clearTableRows(resetScroll:)`.
   - `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`, `AppCoordinator+Search.swift`, `AppCoordinator+Playback.swift`, `AppCoordinator+Library.swift`, and `AppCoordinator+PlaybackLibraryChange.swift`: wired `externalRetainedCueIDsProvider` (`excerpt.residentCueIDs` unioned with `playback.playlistSource?.activeSearchCueIDs`), triggered `reclaimUnusedCueContent()` via `playback.onPlaylistSourceDidChange`, zero-folder unfreeze cleanup, `openSearchResult` (when `playlistSource` changed), `stopPlayback`, `openLibraryVideo`, `reconcilePlaybackPlaylistIfAwaiting`, and converged `refreshSearchOnReappearanceIfNeeded()` from `clearCachedCueContent()` onto safe union reclamation. Kept `SearchStore` decoupled from `app.cueContent` per `20260927` (`libraryFolderRemovalPreservesSearchStoreResultsAndCueContent`).

4. **Pure-Logic Unit Tests**:
   - `apps/macos-native/Tests/CueSeekerAppTests/CueContentStoreTests.swift`: added `cueContentStoreReclaimsUnusedEntriesSilentlyWithoutPublishingChanges`, `sharedCueContentStoreSearchReclamationPreservesActiveAndCachedExcerptSnapshots`, and `cueContentStoreLargeReclamationUpdatesStoreSynchronouslyAndShrinksStorage`.
   - `apps/macos-native/Tests/CueSeekerAppTests/SearchStoreTests.swift`: added `clearingSearchQueryReclaimsCueContentWhenNoSearchPlaylistIsActive`, `sequentialSearchesAndZeroHitSearchEvictObsoleteCueContent`, `facetFilterTightenAndRelaxKeepsCurrentRoundCueContentInMemory`, `activeSearchPlaylistProtectsCueContentAcrossCommandPanelEditsUntilPlaybackStopsOrSourceChanges`, and `excerptSnapshotsRemainValidAndPreservedAcrossSearchAndReappearanceCleanup`.

## Verification

- **Build check**:
  - `swift build --package-path apps/macos-native`: succeeded (`Build complete! (0.33s)`, `0` errors).
- **Filtered headless pure-logic unit tests**:
  - Command: `swift test --package-path apps/macos-native --filter "CueContentStoreTests|SearchStoreTests|PlaybackSearchOverlayTests|SearchInvalidItemsPruningTests|ExcerptLifecycleAndInvalidItemsTests|PlaybackLibraryChangeTests|PlaybackSubtitleFocusKeyboardActionTests|TableSandboxRowModelStoreTests|URLSchemeSearchRoutingTests|URLSchemeCuePlaybackTests|libraryFolderRemovalPreservesSearchStoreResultsAndCueContent"`
  - Result: `146` tests passed in `2.372` seconds (`0` failures, `0` skipped, no window-popping suites invoked).
- **Headless Cold Search Benchmark (`SearchBench --headless-cold`, 5-round avg, DB `/Users/weiyunjun/Library/Application Support/CueSeeker/release/CueSeeker.sqlite`)**:

| Query | Baseline 1st / Full (`fe1ea2a`) | Post-Change 1st / Full | Baseline Commit / Post Commit |
| --- | --- | --- | --- |
| `大丈夫` (`1462` hits) | 159.80 ms / 344.16 ms | **154.74 ms / 259.91 ms** | 0.61 ms / 0.68 ms |
| `今日` (`2301` hits) | 155.72 ms / 269.69 ms | **149.86 ms / 263.02 ms** | 0.85 ms / 0.88 ms |
| `の` (`76817` hits) | 142.32 ms / 631.26 ms | **137.74 ms / 650.02 ms** | 49.91 ms / **46.93 ms** |

## Outcome

Obsolete search `CueContent` entries are now reclaimed along clear search lifecycle boundaries while preserving Filter-snapshot re-projection, active search playlists, and cached Excerpt snapshots, with large table evictions destroyed off `MainActor` prior to malloc pressure relief and zero cold-search regression. Pending user end-to-end UI acceptance.
