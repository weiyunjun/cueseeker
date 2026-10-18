# Search Reappearance Refresh By Library Task Type

Human-owned documents:

- `docs/human/requirements/20261018-Feature-Search Reappearance Refresh By Library Task Type.md`
- `docs/human/design/playback/Playback Edge Cases.md`

## Why

1. Under the previous deferred refresh rule, Search results stayed untouched when leaving and returning to the Search page after library tasks, and only pruned invalid items upon entering Playback.
2. When library tasks complete, whether Search refreshes upon reappearance must depend on **actual database content changes (outcome)** rather than mere task execution (process):
   - No actual database content change (e.g., `Index` where all files are unchanged, or adding/removing an empty folder): existing search results remain untouched without re-running the search.
   - Removal only (`Remove Folder` that removed indexed content): only invalidates cues from the removed folder; re-running a full search is unnecessary when returning to Search.
   - `Index` or `Add Folder` that produced actual database content changes (`result.hasIndexedContentChanges == true`): can add new matching cues, remove modified cues that no longer match, or change existing cue text, so re-executing the search is required when returning to Search.

## What changed

- **Pending Reappearance Refresh Tracking (`SearchStore`)**:
  - Added `SearchReappearanceRefreshMode` (`.none`, `.pruneRemovedItems`, `.rerunSearch`), where `.rerunSearch` takes precedence over `.pruneRemovedItems` when merged.
  - Updated `completeIndexedCueDataMutation(_:refreshMode:)` to record the pending reappearance refresh mode, and cleared pending refresh state when a new full search is prepared (`prepareSearch(appending: false, ...)`) or results are cleared (`clearResults()`).
  - Updated `pruneInvalidSearchResults(liveCueIDs:)` to also check whether `searchFacetSnapshot` contains removed cue IDs and clear `.pruneRemovedItems` once pruned.
  - Updated `projectSearchFacetFilter` and `applyProjectedFacetFilter` to allow re-projection when `resultFacetFilter` differs from the normalized `searchFacetFilter` after folder removal.
- **Outcome-Based Task Differentiation (`AppCoordinator+Indexing`)**:
  - `performFolderRemoval`: Marks `.pruneRemovedItems` upon successful folder removal (and `.none` if removal fails and rolls back). If the removed folder was empty and no cues were removed, pruning leaves existing results untouched.
  - `applyPublishedIndexMutation`: Only marks `.rerunSearch` when `result.hasIndexedContentChanges == true` (both for `Index` and `Add Folder`). Unchanged `Index` runs or empty folder additions do not mark `.rerunSearch`.
- **Deferred Reappearance Execution (`AppCoordinator`, `AppCoordinator+Search`, `AppCoordinator+Playback`, `WorkbenchTestSearchView`)**:
  - Added `refreshSearchOnReappearanceIfNeeded()` and wired it into `prepareWorkbenchRoute(.search)` and `stopPlayback()` (when returning to `.search`).
  - When `.pruneRemovedItems` is pending on reappearance, prunes invalid cues from `loadedSearchResultCueIDs`, `searchResultCueIDs`, and `searchFacetSnapshot` without re-executing the search, and re-projects from the snapshot if a removed folder normalized the active facet filter.
  - When `.rerunSearch` is pending on reappearance, clears cached cue content in `SearchStore` and re-executes the current search query with active filters (`debounce: false`).

## Tests

- Updated `SearchInvalidItemsPruningTests`:
  - `searchPrunesInvalidItemsUponReappearingAfterRemoval`: Verifies staying on Search preserves current results and counts after removal, and leaving/returning to Search prunes invalid items and updates facet counts without re-running the search.
  - `searchRerunsQueryUponReappearingAfterIndexOrAddFolder`: Verifies staying on Search preserves the frozen snapshot after an `Index` mutation, and leaving/returning to Search re-executes the query and reflects newly matched cues and updated cue text.
  - `searchRerunsQueryWhenBothRemovalAndIndexOccurredBeforeReappearance`: Verifies `.rerunSearch` takes precedence when both `Index`/`Add Folder` and `Remove Folder` occur before Search reappears.
  - `searchDoesNotRerunUponReappearingWhenIndexOrAddFolderHasNoContentChanges`: Verifies that an unchanged `Index` or empty `Add Folder` (`hasIndexedContentChanges == false`) does not mark `.rerunSearch` or re-run the search upon returning to Search.
- Verified `SearchInvalidItemsPruningTests` and `SearchStoreTests` pass.
