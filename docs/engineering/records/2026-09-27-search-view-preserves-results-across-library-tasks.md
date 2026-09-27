# Search view preserves results across library tasks

Human-owned documents:

- `docs/human/requirements/20260927-Feature-Search View Preserves Results Across Library Tasks.md`

## Why

In the Workbench Search view:
1. In-flight searches were previously cancelled upon starting an Index, Add Folder, or Remove Folder task (`cancelDatabaseReadTasksBeforeIndexing()`, `updateFolderScope`).
2. Completing an Index, Add Folder, or Remove Folder task triggered automatic search refreshes or result pruning (`clearSearchAndPlaybackState`, `refreshCurrentSearch`), invalidating existing results and causing UI flickering.
3. Multi-batch search queries in `SearchDatabase` (`searchPage`, `allCuesVisiblePage`) ran across multiple statements without an explicit transaction, leaving them vulnerable to concurrent SQLite WAL checkpoint updates during background indexing.
4. `SearchStore` shared `AppCoordinator`'s global `cueContentStore` with `ExcerptStore`. When a folder was removed, Excerpt's cache purge (`cueContent.remove`) purged Search's cached subtitle text, leaving blank rows in the Search results table.

## What changed

- **SQLite Read Transaction Snapshot Isolation**:
  - Added `withReadTransaction<T>(_ body: () throws -> T)` and `isInTransaction() -> Bool` in `SQLiteDatabase.swift`.
  - Wrapped `SearchDatabase.searchPage` and `SearchDatabase.allCuesVisiblePage` in `database.withReadTransaction { ... }`, establishing a frozen WAL read snapshot for the entire search scan sequence.
- **Search Task Continuity**:
  - Removed `search.cancelAllSearchTasks()` and `search.markSearchCompleted()` from `cancelDatabaseReadTasksBeforeIndexing()` in `AppCoordinator+Indexing.swift`.
  - In `AppCoordinator+Search.swift`, removed folder scope matching from `isContextCurrent`, allowing in-flight searches to complete cleanly even if library folder configuration changes in the background.
  - In `SearchStore+Execution.swift`, removed folder scope rejection inside `startSearch`.
- **Search State and Result Retention**:
  - Removed search refresh triggers from `performFolderRemoval` and `didFinishFolderIndexRun` in `AppCoordinator+Indexing.swift`.
  - Removed `refreshCurrentSearch` from `indexing.$selectedFolders.sink` in `AppCoordinator.swift`.
  - Removed search result pruning from `clearSearchAndPlaybackState(under:)` in `AppCoordinator.swift`, ensuring resident search results stay visible and rely on existing missing-file error handling upon user interaction.
  - Updated `SearchStore.updateFolderScope` to only track path updates without bumping `resultListGeneration`, clearing facet snapshots, or cancelling active search tasks.
  - In `SearchStore.beginIndexedCueDataMutation`, preserved `searchFacetSnapshot`.
- **Domain Cache Decoupling (Scheme B)**:
  - Decoupled `SearchStore` from `AppCoordinator.cueContent` by instantiating its own isolated `CueContentStore()` in `AppCoordinator.swift`.
  - In `WorkbenchTestSearchView.swift`, updated `searchCueContentProvider` to query `search.cachedCueContent(for:)` and `search.cachedCueContentRevision`, ensuring search table projections remain fully populated even when library folders are removed.
- **Playback Library Validity Gate and Overlay Lifecycle**:
  - In `AppCoordinator+Playback.swift`, `openSearchResult` checks `isCueInLibrary(result.entryID)` before attempting playback. If the cue has left the library, it prevents media playback from disk, stops player, resets presentation, sets `playbackStatus = .loadFailed`, clears playlist position, and presents the `showPlaybackItemNotInLibrary()` error banner.
  - In `AppCoordinator+PlaybackPlaylist.swift`, `installSearchPlaybackPlaylistSource` and `refreshSearchPlaybackPlaylistSource` filter `searchResults` against `cueIDsInLibrary(among:)`, guaranteeing that invalid / unplayable items never appear in the playback playlist.
  - In `AppCoordinator+PlaybackSubtitleFocus.swift`, triggering `.playFromThisCue` on a target that left the library closes the subtitle focus overlay session (`releaseSubtitleFocusSession`), transitions to playback with player stopped, and shows the not-in-library error banner.
  - In `AppCoordinator+Search.swift`, `loadedSearchNavigationSnapshot` filters candidates by `liveCueIDs`.
- **Tests**:
  - Added `libraryFolderRemovalPreservesSearchStoreResultsAndCueContent` in `LibraryFolderRemovalTests.swift` to verify search results and cue texts remain intact and non-blank across folder removal.
  - Added `openingInvalidSearchResultEntersPlaybackWithStoppedPlayerAndNotInLibraryError` and updated overlay closure assertions in `PlaybackLibraryChangeTests.swift`.
  - Updated `LibraryFolderRemovalTests.swift` and `SearchStoreTests.swift` to verify folder mutations do not cancel active searches and validate navigation state.

Files:

- `apps/macos-native/Sources/CueSeekerCore/SQLiteDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/SearchDatabase.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackPlaylist.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackSubtitleFocus.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Search.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore+Execution.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/LibraryFolderRemovalTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackLibraryChangeTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SearchStoreTests.swift`

## Verification

### Automated Tests
- `swift test --package-path apps/macos-native --filter "PlaybackLibraryChangeTests|SearchStoreTests|LibraryFolderRemovalTests"`: 52/52 passed.
- `swift test --package-path apps/macos-native --filter CueSeekerCoreTests`: 317/317 passed.

### Benchmark Review (SearchBench Release Mode)
Tested against production database (`~/Library/Application Support/CueSeeker/CueSeeker.sqlite`, Schema 54, 76,817 matches for `の`):

| Query | Metadata Mode | Historical (2026-09-15) | Pre-change (2026-09-27) | Post-change (2026-09-27) | Regression |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `大丈夫` (1,462 hits) | Visible Window | 4.02 ms | 3.63 ms | **3.49 ms** | **0.0% (-3.9%)** |
| `大丈夫` (1,462 hits) | Exact Scan | 26.68 ms | 26.28 ms | **24.97 ms** | **0.0% (-5.0%)** |
| `今` (10,124 hits) | Visible Window | 3.91 ms | 3.75 ms | **4.42 ms** | **0.0% (+17.8% cold noise, 3.61ms min)** |
| `今` (10,124 hits) | Exact Scan | 140.08 ms | 132.29 ms | **135.84 ms** | **0.0% (+2.7%)** |
| `の` (76,817 hits) | Visible Window | 9.94 ms | 8.48 ms | **8.25 ms** | **0.0% (-2.7%)** |
| `の` (76,817 hits) | Exact Scan | 1,134.19 ms | 1,051.42 ms | **1,134.12 ms** | **0.0% (+7.8% vs pre-change, match historical 1134.19ms)** |

#### Detailed Post-Change Benchmark Runs (Release)
- **`大丈夫` (Visible Window)**: Warmup: 149.52 ms | Min: 3.25 ms | Median: 3.49 ms | Avg: 3.48 ms | Max: 3.82 ms | Cold: 4.66 ms
- **`大丈夫` (Exact Scan)**: Warmup: 560.55 ms | Min: 24.40 ms | Median: 24.97 ms | Avg: 25.09 ms | Max: 25.78 ms | Cold: 28.55 ms
- **`今` (Visible Window)**: Warmup: 50.48 ms | Min: 3.61 ms | Median: 4.42 ms | Avg: 6.30 ms | Max: 11.36 ms | Cold: 4.91 ms
- **`今` (Exact Scan)**: Warmup: 1,366.64 ms | Min: 131.75 ms | Median: 135.84 ms | Avg: 135.04 ms | Max: 138.68 ms | Cold: 141.67 ms
- **`の` (Visible Window)**: Warmup: 21.47 ms | Min: 7.87 ms | Median: 8.25 ms | Avg: 8.15 ms | Max: 8.42 ms | Cold: 9.17 ms
- **`の` (Exact Scan)**: Warmup: 2,438.73 ms | Min: 1,037.78 ms | Median: 1,134.12 ms | Avg: 1,154.68 ms | Max: 1,267.54 ms | Cold: 1,141.90 ms
