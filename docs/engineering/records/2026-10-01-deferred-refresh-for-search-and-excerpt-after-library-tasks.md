# Deferred Refresh For Search And Excerpt After Library Tasks

Human-owned documents:

- `docs/human/requirements/20261001-Feature-Deferred Refresh For Search And Excerpt After Library Tasks.md`

## Why

1. During long-running library tasks (Index Now, Add Folder, Remove Folder), user workflows in Search and Excerpt views were previously interrupted by premature clearing, full reload invalidation, or background task finish events that refreshed the UI while the user was interacting with it.
2. When library changes finished, immediately reloading search and excerpt views on the main thread caused UI freezes and hitches, especially with large libraries.
3. Clicking on an invalid search or excerpt item (whose underlying content left the library) and subsequently returning to Workbench previously had two known hitch/stall risk points:
   - Returning to Workbench Search after playing an invalid search result could cause main-thread hitches due to repeated table rebuilds and redundant database checks.
   - Returning to Workbench Excerpt List after playing an invalid excerpt item could cause UI stalls due to synchronous multi-table queries on `@MainActor` and duplicate reload triggers.

## What changed

- **Deferred Excerpt Refresh on Reappearance**:
  - `prepareExcerptForIndexedContentMutation`: Avoids wiping resident excerpt rows or list overview during tasks. Queues folders to `pendingExcerptContentRemovalFolders` and marks `excerptNeedsReloadAfterIndexedContentMutation = true`.
  - `reloadExcerptAfterIndexedContentMutation`: Defers reload to when the user returns to the Excerpt view.
  - `refreshExcerptOnReappearanceIfNeeded`: Performs lazy reload only when Excerpt routes (`.excerpt`, `.excerptList`, `.recent`) reappear or when exiting playback via `stopPlayback`. Removes cached cue contents for removed folders and reloads list overview and table rows.
  - `openExcerpt`: Handles invalid excerpt playback gracefully by stopping the player, clearing playlist positions, setting `playbackStatus = .loadFailed`, and displaying `showPlaybackItemNotInLibrary()` without synchronous main-thread table freezes.

- **Synchronous Pruning for Search Results on Playback Click**:
  - `SearchStore`:
    - Added `isPlaybackPruningActive` and `searchSnapshotMutationRevision` to track when pruning has been activated by playback.
    - Implemented `pruneInvalidSearchResults(liveCueIDs:)` to synchronously remove removed items from loaded and pending result arrays, search ranks, and facet distribution snapshots (`CueFacetSnapshot.keeping(cueIDs:)`).
  - `AppCoordinator+PlaybackPlaylist`:
    - Implemented `synchronizeSearchAndPlaylistOnPlayback(seed:)` to synchronously query live cue IDs in the database and prune invalid search results upon clicking a search result to play.
    - Optimized `refreshSearchPlaybackPlaylistSource` to skip redundant SQLite lookups if no mutations occurred since the search snapshot.
  - `AppCoordinator+PlaybackLibraryChange`:
    - In `reconcilePlaybackAfterIndexedContentChange`, when Search is the active playback source, prunes invalid search results synchronously.

- **Diagnostic Performance Probes & Timing Breadcrumbs**:
  - Added millisecond timing breadcrumbs (`AppPerformanceProbe.breadcrumb`) to monitor critical paths and identify any main-thread hitches:
    - `Search.synchronizeSearchAndPlaylistOnPlayback candidates=... live=... duration=...ms`
    - `cueIDsInLibrary count=... liveCount=... duration=...ms`
    - `excerptIDsInLibrary count=... validCount=... duration=...ms`
    - `refreshExcerptOnReappearanceIfNeeded duration=...ms`
    - `stopPlayback duration=...ms`
    - `WorkbenchTestSearchView.resumeDeferredTableResponse duration=...ms`
    - `WorkbenchExcerptTableView.resumeDeferredTableResponse duration=...ms`

## Tests

- Added `SearchInvalidItemsPruningTests`:
  - `searchPrunesInvalidItemsUponEnteringPlayback`: Verifies search results remain unchanged after folder removal until playback is clicked, at which point invalid items are pruned synchronously.
  - `searchPrunesSynchronouslyWhenTaskFinishesDuringPlayback`: Verifies that if a folder removal task completes while playback is active, search results and playlists are synchronously pruned.
  - `searchDoesNotPruneWhenPlaybackNeverEntered`: Verifies search results are not pruned before user initiates playback.
- Added `ExcerptLifecycleAndInvalidItemsTests`:
  - `excerptRemainsIntactDuringTaskAndDefersReloadUntilReappearance`: Verifies excerpt table remains operable during folder removal and defers reload until reappearance.
  - `openingInvalidExcerptShowsNotInLibraryErrorAndStopsPlayer`: Verifies clicking an invalid excerpt stops playback and presents not-in-library error banner without crashing or hanging.
- Verified all new tests pass cleanly with sub-millisecond probe measurements.
