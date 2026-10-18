# 2026-10-18: Outcome-Based Page Refresh and In-Place Rename Update

Human-owned documents:

- `docs/human/requirements/20261018-Feature-Outcome Based Page Refresh And In Place Rename Update.md`
- `docs/human/design/playback/Playback Edge Cases.md`
- `docs/human/design/workbench/Library and File.md`

## Why

1. **Outcome-based page refresh across all pages**:
   - Previously, `Add Folder` unconditionally marked deferred refresh flags (`recentNeedsReloadAfterIndexedMutation`, `libraryNeedsReloadAfterIndexedMutation`, `fileNeedsReloadAfterIndexedMutation`) via `refreshLibraryAfterAuxiliaryDataMutation()`, and `Remove Folder` unconditionally marked `pendingReappearanceRefreshMode = .pruneRemovedItems`, `excerptNeedsReloadAfterIndexedContentMutation`, and `Recent`/`Library`/`File` deferred refresh flags even when removing an empty folder that had no indexed database records.
   - All pages (`Search`, `Recent`, `Library`, `Excerpt` Level 1/2, and `File` Level 2/3) must determine whether to refresh or mark deferred reappearance refresh flags based on **actual database content changes (outcome)** rather than mere task execution (process).
2. **`Rename` as an in-place replacement update**:
   - Previously, `applyCompletedRename` constructed a synthetic `SubtitleIndexingResult` and routed it through `applyPublishedIndexMutation`, which treated `Rename` like a content-mutating `Index` run: marking `.rerunSearch` on `Search`, deferring `File` Level 2/3 and `Library`/`Recent`/`Excerpt` updates behind reappearance flags, and failing to rewrite active `File` Level 2/3 routes or selected/excluded folder paths in `Search` and `Excerpt` facet filters.
   - `Rename` only replaces folder or file paths and derived display titles; it should update `File` (Level 1/2/3), `Search` (in-place titles/paths and Folder filter paths without re-running search), `Library`, `Recent`, and `Excerpt` (in-place titles/paths and Folder filter paths) directly.

## What changed

- **Outcome-Based Folder Addition & Removal (`IndexingDatabase`, `LibraryFolderRemovalExecutor`, `AppCoordinator+Indexing`, `SearchStore`)**:
  - Updated `IndexingDatabase.removeIndexedFolder(_:keepingNestedRoots:)` and `LibraryFolderRemovalExecuting.removeFolder` to return `Bool` indicating whether any indexed database content was actually removed (`!affectedFolderPaths.isEmpty`).
  - Updated `SearchStore.completeIndexedCueDataMutation(_:refreshMode:didMutateIndexedContent:)` so that when `didMutateIndexedContent == false`, `indexedCueDataRevision` and `pendingReappearanceRefreshMode` remain untouched.
  - Updated `AppCoordinator.performFolderAddition` to only hold the active route and refresh `Library`/`Recent` when `result.hasIndexedContentChanges || result.requiresExcerptRefresh` is true.
  - Updated `AppCoordinator.performFolderRemoval` to check `didRemoveIndexedContent`; when `false` (e.g., removing an empty folder), it removes the root from `indexing.selectedFolders` and completes the search mutation token with `didMutateIndexedContent: false` without marking `Search`, `Recent`, `Library`, `Excerpt`, or `File` for reload.
- **In-Place `Rename` Replacement (`IndexingDatabase+Rename`, `LibraryRename`, `CueFacetFilter`, `WorkbenchLayoutState`, `SettingsStore`, `SearchStore`, `ExcerptStore`, `TableSandboxRowModelStore`, `AppCoordinator+LibraryRename`)**:
  - Rebuilt `CueFacetCountCache` inside `IndexingDatabase.applyRename(_:)` when `!affectedFolderPaths.isEmpty` so `cueFacetDistribution()` reflects renamed folder paths immediately.
  - Added `LibraryRenamer.rewrittenPath(_:steps:)` and `rewritingFolderPaths(_:)` on `CueFacetFilter`, `CueFacetDistribution`, `CueFacetSnapshot`, and `WorkbenchRoute`, plus `SettingsStore.rewriteFacetFilterFolderPaths(_:)` and `WorkbenchLayoutState.rewriteFolderPaths(_:)`.
  - Added `SearchStore.applyRename(_:databaseURL:)` to refresh cached `CueContent` entries, `emptySearchFacetDistribution`, `searchFacetSnapshot`, `searchFacetFilter`, and `resultFacetFilter` in place without marking `.rerunSearch` or re-executing the search query.
  - Added `ExcerptStore.applyRename(_:cueContentStore:)` and `AppCoordinator.applyRenameToExcerpt(_:)`, and updated `TableSandboxRowModelStore.refreshReferencedCueContent` to refresh `excerptsByEntryID` when `CueContent` changes.
  - Updated `AppCoordinator.applyCompletedRename(_:)` to apply in-place updates across `File` (rewriting active Level 2/3 routes and reloading subfolders/files immediately), `Search`, `Excerpt`, `Library`, and `Recent`.

## Verification

- Added unit tests in `apps/macos-native/Tests/CueSeekerAppTests/LibraryFolderRemovalTests.swift`:
  - `addingOrRemovingEmptyFolderDoesNotMarkDeferredPageRefreshes`: Verifies that adding or removing an empty folder leaves `Search`, `Recent`, `Library`, `Excerpt`, and `File` Level 2/3 untouched with all deferred refresh flags false/none.
  - `renameUpdatesFileSearchLibraryRecentAndExcerptInPlaceWithoutRerunningSearch`: Verifies that renaming a folder updates `File` Level 3 route/objects, `Search` results and Folder filter, `Excerpt` resident rows and Folder filter, and `Library` summaries in place without marking `.rerunSearch` or re-running the search.
- Verified `LibraryFolderRemovalTests` and `SearchInvalidItemsPruningTests` pass.
