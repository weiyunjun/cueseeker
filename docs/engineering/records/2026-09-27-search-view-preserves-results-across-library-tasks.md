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
- **Tests**:
  - Added `libraryFolderRemovalPreservesSearchStoreResultsAndCueContent` in `LibraryFolderRemovalTests.swift` to verify search results and cue texts remain intact and non-blank across folder removal.
  - Updated `LibraryFolderRemovalTests.swift` and `SearchStoreTests.swift` to verify folder mutations do not cancel active searches.

Files:

- `apps/macos-native/Sources/CueSeekerCore/SQLiteDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/SearchDatabase.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Search.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore+Execution.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/LibraryFolderRemovalTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SearchStoreTests.swift`

## Verification

### Automated Tests
- `swift test --package-path apps/macos-native --filter "SearchStoreTests|CueContentStoreTests|LibraryFolderRemovalTests"`: 46/46 passed.
- `swift test --package-path apps/macos-native --filter CueSeekerCoreTests`: 317/317 passed.

### Benchmark Review (SearchBench Release Mode)
Tested against production database (`~/Library/Application Support/CueSeeker/CueSeeker.sqlite`, Schema 54, 76,817 matches for `の`):

| Query | Metadata Mode | Historical (2026-09-15) | Pre-change (2026-09-27) | Post-change (2026-09-27) | Regression |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `大丈夫` (1,462 hits) | Visible Window | 4.02 ms | 3.63 ms | **3.44 ms** | **0.0% (-5.2%)** |
| `大丈夫` (1,462 hits) | Exact Scan | 26.68 ms | 26.28 ms | **25.27 ms** | **0.0% (-3.8%)** |
| `今` (10,124 hits) | Visible Window | 3.91 ms | 3.75 ms | **3.70 ms** | **0.0% (-1.3%)** |
| `今` (10,124 hits) | Exact Scan | 140.08 ms | 132.29 ms | **137.47 ms** | **0.0% (+3.9%)** |
| `の` (76,817 hits) | Visible Window | 9.94 ms | 8.48 ms | **8.26 ms** | **0.0% (-2.6%)** |
| `の` (76,817 hits) | Exact Scan | 1,134.19 ms | 1,051.42 ms | **1,047.15 ms** | **0.0% (-0.4%)** |

#### Detailed Post-Change Benchmark Runs (Release)
- **`大丈夫` (Visible Window)**: Warmup: 147.77 ms | Min: 3.31 ms | Median: 3.44 ms | Avg: 3.51 ms | Max: 3.75 ms | Cold: 4.75 ms
- **`大丈夫` (Exact Scan)**: Warmup: 569.15 ms | Min: 24.68 ms | Median: 25.27 ms | Avg: 25.37 ms | Max: 26.27 ms | Cold: 28.88 ms
- **`今` (Visible Window)**: Warmup: 50.30 ms | Min: 3.45 ms | Median: 3.70 ms | Avg: 3.70 ms | Max: 3.93 ms | Cold: 4.66 ms
- **`今` (Exact Scan)**: Warmup: 1,208.69 ms | Min: 136.25 ms | Median: 137.47 ms | Avg: 139.40 ms | Max: 145.41 ms | Cold: 139.11 ms
- **`の` (Visible Window)**: Warmup: 20.43 ms | Min: 7.93 ms | Median: 8.26 ms | Avg: 8.22 ms | Max: 8.59 ms | Cold: 8.93 ms
- **`の` (Exact Scan)**: Warmup: 2,381.94 ms | Min: 1,029.12 ms | Median: 1,047.15 ms | Avg: 1,044.71 ms | Max: 1,058.36 ms | Cold: 1,043.31 ms
