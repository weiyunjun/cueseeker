# Search view preserves results across library tasks

Human-owned documents:

- `docs/human/requirements/20260927-Feature-Search View Preserves Results Across Library Tasks.md`

## Why

In the Workbench Search view:
1. In-flight searches were previously cancelled upon starting an Index, Add Folder, or Remove Folder task (`cancelDatabaseReadTasksBeforeIndexing()`, `updateFolderScope`).
2. Completing an Index, Add Folder, or Remove Folder task triggered automatic search refreshes or result pruning (`clearSearchAndPlaybackState`, `refreshCurrentSearch`), invalidating existing results and causing UI flickering.
3. Multi-batch search queries in `SearchDatabase` (`searchPage`, `allCuesVisiblePage`) ran across multiple statements without an explicit transaction, leaving them vulnerable to concurrent SQLite WAL checkpoint updates during background indexing.

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
- **Tests**:
  - Updated `LibraryFolderRemovalTests.swift` to verify search results are retained when folder content is removed.
  - Updated `SearchStoreTests.swift` (`addingEmptyFolderLeavesActiveSearchAlone`) to verify folder additions do not invalidate or restart ongoing searches.

Files:

- `apps/macos-native/Sources/CueSeekerCore/SQLiteDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/SearchDatabase.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Search.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore+Execution.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/LibraryFolderRemovalTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SearchStoreTests.swift`

## Verification

- **Automated Tests**:
  - `swift test --package-path apps/macos-native --filter "LibraryFolderRemovalTests|LibraryFolderAdditionTests|SearchDatabaseTests"`: 64/64 passed.
  - `swift test --package-path apps/macos-native --filter SearchStoreTests`: 27/27 passed.
  - `swift test --package-path apps/macos-native --filter CueSeekerCoreTests`: 317/317 passed.
- **SearchBench Benchmark**:
  Tested against production database (`~/Library/Application Support/CueSeeker/CueSeeker.sqlite`, Schema 54, ~77k results for `の`):
  - `大丈夫` (1,462 matches):
    - Visible window: hot median 5.85 ms
    - Exact scan: hot median 42.52 ms
  - `今` (10,124 matches):
    - Visible window: hot median 7.45 ms
    - Exact scan: hot median 237.63 ms
  - `の` (76,817 matches):
    - Visible window: hot median 26.16 ms
    - Exact scan: hot median 1,953.22 ms
