# Initial Library Opening Empty State Fix

Human-owned documents:

- `docs/human/requirements/20261010-Bug-Initial Library Opening Shows Empty State.md`
- `docs/human/requirements/20261009-Feature-Workbench Invalidation.md`

## Why

1. **Empty State on First Library Launch**:
   - Every time the application was restarted, opening the Library tab for the first time (either by launching directly into the Library tab or launching on another tab and switching to Library) resulted in displaying "No library videos yet." (`library.empty`).
   - The user had to switch away to another tab and come back before library videos would appear.

2. **Root Cause**:
   - Commit `ac67ca958` introduced invalidation hold protection in `refreshCompleteLibrary(force: Bool = false)` to prevent screen jump during background mutations when `workbenchLayout.panelMode == .testLibrary`.
   - However, the initial hydration path `hydrateCompleteLibraryAsync()` also called `refreshCompleteLibrary()` with default `force: false`.
   - When the user opened Library, `panelMode` was `.testLibrary`, so `refreshCompleteLibrary` intercepted the call, marked `libraryNeedsReloadAfterIndexedMutation = true`, and exited without loading data.
   - Consequently, `completeLibraryStatus` remained `.idle` and folders remained empty, causing `WorkbenchTestLibraryView` to render the empty hint.

## What changed

1. **Hydration Uses Explicit Force (`AppCoordinator+Library.swift`)**:
   - In `hydrateCompleteLibraryAsync()`, updated `refreshCompleteLibrary()` calls to `refreshCompleteLibrary(force: true)`. Initial cold hydration is an explicit demand to load initial data and should not be intercepted by the invalidation hold.
2. **Regression Test Coverage (`WorkbenchInvalidationTests.swift`)**:
   - Added `initialLibraryHydrationProceedsWhileInLibraryPanelMode()` verifying that initial hydration on `.testLibrary` successfully loads and does not mark deferred reload or get blocked in an idle state.

## Verification

- `swift build --package-path apps/macos-native`: succeeded.
- `swift test --package-path apps/macos-native --filter WorkbenchInvalidationTests`: passed (5/5 tests passed).
- `swift test --package-path apps/macos-native --filter LibraryRouteSnapshotReuseTests`: passed (3/3 tests passed).
