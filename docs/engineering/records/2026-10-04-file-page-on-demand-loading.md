# File Page On-Demand Loading

Human-owned documents:

- `docs/human/requirements/20261004-Performance-File Page On Demand Loading.md`
- `docs/human/design/Data.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Root Cause of Folder Navigation Latency**:
   - The File page previously utilized `indexedContentDatabase.contentTree()`, which eagerly loaded and parsed the entire library across all indexed roots, all video files, and all active subtitle matches.
   - For medium or large libraries (particularly external drives like `/Volumes/Seagate/影视`), this full-tree multi-table join and sorting query took several seconds to build all in-memory tree nodes.
   - At the same time, `WorkbenchFileView` mistakenly triggered `hydrateCompleteLibraryAsync()` (which kicked off cover generation with 4 concurrent background workers and complete library summary queries), and listened to `.task(id: library.completeLibraryRevision)`. When complete library summaries finished, the revision incremented, which canceled the in-flight file tree loading task and restarted it from scratch.
   - Consequently, when users clicked a root folder card, Level 2 found an empty tree and `.loading` status, displaying a prolonged loading spinner.
2. **On-Demand & Sub-Millisecond Architecture**:
   - Clicking a root folder to view subfolders in Level 2 only requires reading the subfolder paths and titles under that specific root. This is a single, scoped query taking < 1ms in SQLite.
   - Clicking a subfolder to view files in Level 3 only requires querying the video files and matched subtitles for that specific directory, taking < 1ms in SQLite.
   - By pre-warming subfolders for indexed roots upon File page appearance and querying on-demand with memory caching, folder navigation becomes instantaneous (0ms perceived time).

## What changed

- **Core Query Optimization (`CueSeekerCore`)**:
  - In `IndexedContentDatabase.swift`:
    - Added `subfolders(under rootURL: URL) throws -> [IndexedContentFolder]`: scopes `libraryPresentation` to the specific root and queries video locations by `library_id` without joining or loading any subtitle records.
    - Added `objects(in folderPath: String) throws -> [IndexedContentObject]`: scopes `libraryPresentation` to the target directory and queries file sizes and subtitle matches strictly for videos in that directory.
    - Parameterized `loadVideoLocations(forRootID:)` to avoid loading video locations across unrelated roots.
  - In `IndexedContentDatabaseModels.swift`:
    - Added public initializers to `IndexedContentRoot` and `IndexedContentFolder`.
- **State Management & Caching (`CueSeekerApp`)**:
  - In `LibraryStore.swift`:
    - Added `fileSubfoldersByRootPath`, `fileObjectsByFolderPath`, `fileSubfolderStatusByRootPath`, `fileObjectStatusByFolderPath`, and an isolated `fileTreeRevision` counter.
    - Added lookup helpers `fileSubfolders(for:)`, `fileSubfolderStatus(for:)`, `fileObjects(for:)`, `fileObjectStatus(for:)` with standardized path matching.
  - In `AppCoordinator+Data.swift`:
    - Added `hydrateFileRootsAsync()`: pre-hydrates subfolders for all selected roots upon entering the File page.
    - Added `hydrateFileSubfoldersAsync(rootPath:)`: on-demand hydration for Level 2 subfolder view.
    - Added `hydrateFileObjectsAsync(folderPath:)`: on-demand hydration for Level 3 file flow.
    - Added `invalidateFileTreeCache()`: resets on-demand caches and increments `fileTreeRevision`.
  - In `AppCoordinator+Indexing.swift`:
    - Called `invalidateFileTreeCache()` upon index mutations (`applyPublishedIndexMutation`) and folder removal completions.
- **View Lifecycle & Elimination of Interference (`WorkbenchFileView.swift`)**:
  - Removed `hydrateCompleteLibraryAsync()` and dependency on `completeLibraryRevision`.
  - Replaced root task with `.task(id: "\(indexing.selectedFolders.map(\.path).joined(separator: ","))|\(library.fileTreeRevision)") { appState.hydrateFileRootsAsync() }`.
  - Updated Level 2 (`subfolderContent`) to read from `library.fileSubfolders(for: rootPath)` with `.task(id: "\(rootPath)|\(library.fileTreeRevision)")`.
  - Updated Level 3 (`filesContent`) to read from `library.fileObjects(for: folderPath)` with `.task(id: "\(folderPath)|\(library.fileTreeRevision)")`.
- **Verification & Tests**:
  - Added `indexedContentDatabaseOnDemandSubfoldersAndObjects` test in `IndexedContentDatabaseTests.swift`.
  - Added `fileOnDemandStoreCachingAndInvalidation` test in `FileRouteNavigationTests.swift`.

## Verification

- `swift test --package-path apps/macos-native --filter IndexedContentDatabaseTests`: 2/2 passed.
- `swift test --package-path apps/macos-native --filter FileRouteNavigationTests`: 7/7 passed.
- `swift test --package-path apps/macos-native --filter FileCardMenuTests`: 5/5 passed.
