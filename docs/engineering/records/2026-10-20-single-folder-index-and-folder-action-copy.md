# Implementation Record: Single Folder Index And Folder Action Copy

- Date: 2026-10-20
- Requirement: `docs/human/requirements/20261020-Feature-Single Folder Index And Folder Action Copy.md`
- Branch: `main`

## Scope Delivered

1. **File Page Action Copy & Root Folder Card Menu (`WorkbenchFileView.swift`, `Localizable.strings`)**
   - Updated the File page top-left full-index button copy from `Index Now` (`立即索引`) to `Index All` (`索引全部` / `索引全部`).
   - Updated the File page Level 1 root folder card `...` menu items (top to bottom):
     - `Rename This Folder` (`重命名此文件夹` / `重新命名此資料夾`, icon `pencil-simple`)
     - `Index This Folder` (`索引此文件夹` / `索引此資料夾`, icon `arrow-clockwise`)
     - `Remove This Folder` (`移除此文件夹` / `移除此資料夾`, icon `minus-circle`, destructive)
   - Updated the File page Level 2 subfolder card `...` menu item copy to `Rename This Folder` (`重命名此文件夹` / `重新命名此資料夾`).
   - Updated `FileStatusResolver.resolve` to use `IndexingStore.displayName(for:)` for `.indexing` and `.removing` status strings.

2. **Single-Folder Indexing & Task Panel Titles (`AppCoordinator+Indexing.swift`, `TaskQueueStore.swift`, `TaskPanel.swift`, `IndexingDatabase.swift`)**
   - Added `AppCoordinator.indexFolder(_:)` and `TaskQueueStore.enqueueIndexFolder(_:)` to enqueue a single-folder index task (`TaskWork.indexFolder`) that executes `AppCoordinator.runIndex(folders: [folder], isAllFolders: false, ...)`.
   - Updated `IndexingDatabase.publishLibraryIndex` (`bindSearchPathInCurrentTransaction(reuseCoveringLibrary: true)`, `clearPriorCueChangeNotices(libraryID:under:)`, and `pendingVideoMetadataPaths(libraryID:under:)`) so indexing a single root folder (even when nested inside another added parent root folder) scans, reconciles, and refreshes only paths under that folder while reusing the outermost covering `LibraryID` in `search_paths`.
   - Updated `TaskRecord` title resolution so full indexing displays `Index All` (`索引全部` / `索引全部`) and single-folder indexing displays `Index: [Folder]` (`索引：[Folder]` / `索引：[Folder]`).

## Verification

- Verified unit and integration tests in `TaskQueueStoreTests`, `LibraryFolderAdditionTests`, `FileCardMenuTests`, `AppLocalizationTests`, `FileRouteNavigationTests`, `LibraryFolderRemovalTests`, and `TaskCardMenuTests` (`75` tests passed).
