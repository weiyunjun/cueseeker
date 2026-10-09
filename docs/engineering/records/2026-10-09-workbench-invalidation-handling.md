# Workbench Invalidation Handling

Human-owned documents:

- `docs/human/requirements/20261009-Feature-Workbench Invalidation.md`
- `docs/human/design/Playback Edge Cases.md`
- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md`

## Why

1. **Non-disruptive Active Views (Principle 1 - Hold)**:
   - When indexing, adding folders, or removing folders causes content to leave the database, active surfaces where the user is currently working (Command Panel, Recent, Library Level 2, File Level 2/3, Excerpt Level 2) must remain frozen (Hold). They must not spontaneously refresh, flicker, close, or kick the user out to parent screens while the user is actively viewing them.
   - The previous implementation prematurely modified in-memory presentation structures (`removeCompleteLibraryPresentation`, `removeLibraryPresentation`, `invalidateFileTreeCache`) and triggered immediate view reconciliation, causing Library Level 2 to switch to an empty hint while the user was actively browsing folder contents.

2. **Boundary-Crossing Clean Refresh (Principle 2 - Boundary Reconciliation)**:
   - When navigating across boundaries (leaving and returning to a module, closing and reopening panels, switching tabs, or returning to a parent overview), surfaces reconcile with the database and drop invalidated entities cleanly.
   - The sole exception is the File Level 1 root view: as the primary folder management surface where users trigger add/remove actions, it updates immediately upon mutation completion.

3. **Entity Invalidation Display and Playback Interception (Principle 3 & 4)**:
   - When entering or returning to a removed parent entity (e.g. clicking a stale card from an unrefreshed overview, or following breadcrumbs from a child back to a removed root), regular detail skeletons (covers, descriptions, tables) must not be rendered. Instead, a clean, minimal text notice is shown under the top bar (`This folder is no longer in the library.` / `This list is no longer in the library.`).
   - Clicking an invalid item to play enters the playback surface, halts playback with a black screen and zeroed progress, and displays the top red error banner `This item is no longer in the library`, preserving full consistency with Search and Excerpt invalid playback handling.

## What changed

1. **AppCoordinator & Lifecycle Hooks**:
   - In `AppCoordinator.swift`:
     - Introduced `recentNeedsReloadAfterIndexedMutation`, `libraryNeedsReloadAfterIndexedMutation`, and `fileNeedsReloadAfterIndexedMutation` flags alongside existing `excerptNeedsReloadAfterIndexedContentMutation`.
     - Added `heldWorkbenchRoute` to freeze the active route at mutation completion. Protected held routes in `isWorkbenchRouteUnknown(_:)`.
     - Reconciled reappearance in `prepareWorkbenchRoute(_:)`: cleared held route on navigation departure and triggered deferred refresh routines (`refreshRecentOnReappearanceIfNeeded`, `refreshLibraryOnReappearanceIfNeeded`, `refreshFileOnReappearanceIfNeeded`).
   - In `AppCoordinator+Indexing.swift`:
     - Added `holdActiveWorkbenchRouteBeforeContentMutation()` to freeze current route prior to mutations (exempting `.file` root).
     - Ensured hold is established before folder removal and database changes occur.
   - In `AppCoordinator+Library.swift`:
     - Deferred `refreshLibrary(force:)`, `refreshCompleteLibrary(force:)`, `refreshRecentWatching(force:)`, and `refreshLoadedTestRecentWatching(force:)` when user is on `.testLibrary` or `.recentWatching`.
     - Guarded `removeLibraryPresentation(under:)` and `removeCompleteLibraryPresentation(under:)` against modifying in-memory stores when `.testLibrary` is active or route is held.
     - Updated `openLibraryVideo(_:)` to detect `libraryHasLost(videoPath:)`, halt the player with `.loadFailed`, and surface `showPlaybackItemNotInLibrary()`.
   - In `AppCoordinator+Data.swift`:
     - Deferred `invalidateFileTreeCache(force:)` while held on `.fileFolder` or `.fileFiles`.
   - In `AppCoordinator+Playback.swift`:
     - Triggered reappearance refreshes on playback exit in `stopPlayback()`.

2. **UI & Empty States**:
   - In `WorkbenchTestLibraryView.swift`:
     - Removed automatic `closeFolderDetail()` and `reconcileSelectedFolder()` triggers on `indexing.selectedFolders` and `library.completeLibraryRevision` changes.
     - Added `.onAppear` reappearance hooks.
     - Updated `folderPageContent` to prioritize `isWorkbenchRouteUnknown`, rendering `WorkbenchEmptyHint(message: L("library.folder.not_found"))` without detail skeletons when the entity is invalid and unheld.
   - In `WorkbenchFileView.swift`:
     - In `subfolderContent` and `filesContent`, displayed `WorkbenchEmptyHint(message: L("library.folder.not_found"))` when route is unknown.
   - Localizations:
     - Updated `library.folder.not_found` and `excerpt.list.not_found` across `en`, `zh-Hans`, and `zh-Hant` to the required strings (`This folder is no longer in the library.` / `This list is no longer in the library.`).

3. **Tests**:
   - Updated `WorkbenchRouteUnknownTests.swift` to verify known/unknown state transitions for `.fileFolder` and `.fileFiles`.
   - Added `WorkbenchInvalidationTests.swift` covering:
     - Recent and Library mutation deferral and reappearance refresh.
     - Held route preservation across mutations.
     - Invalid library video playback interception and error banner display.
     - Level 2 Library folder hold throughout background folder removal until departure.

## Verification

- Automated tests:
  - `swift test --filter WorkbenchInvalidationTests`: 4/4 passed.
  - `swift test --filter WorkbenchRouteUnknownTests`: 3/3 passed.
  - `swift test --filter PlaybackLibraryChangeTests`: 14/14 passed.
