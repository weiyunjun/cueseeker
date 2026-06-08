# Test Search 2 Schema UI Shell Step 1

Human requirement:

- `docs/human/requirements/20260608-Feature-Test Search 2 Schema UI Shell.md`

## Scope

This record covers the first implementation stage for Test Search 2: adding a
separate top-bar test entry and reusing the Test Search UI shell around the
existing Test Search data and virtual table path.

This stage intentionally does not implement real filter semantics and does not
replace the AppKit virtual table with the SwiftUI schema data table.

## Changes

- Added a `Test Search 2` top-bar test icon to the right of `Test Search UI`.
- Added `WorkbenchTestPage.search2` routing and a new `WorkbenchTestSearch2View`.
- Extracted the Test Search UI page's search command row, filter control row,
  column visibility popover, filter set popover, filter builder popover, filter
  models, and shared fake filter defaults into reusable schema search shell
  components.
- Updated `SchemaWorkbenchPage` to use the shared schema search shell while
  preserving its fake table data.
- Wrapped the new Test Search 2 page with the shared schema search shell while
  keeping `SubtitleTableView`, `TableSandboxRowModelStore`, and
  `TableSandboxVisibleSearchHydrator` for real search rows, visible-row
  hydration, virtual row count, and playback actions.
- Added an optional submit callback to `WorkbenchSearchField` so the reused
  search bar can still submit real search queries from Test Search 2.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- `swift build --product CueSeeker` initially hit a transient
  `posix_spawn error: Resource temporarily unavailable (35)`, then succeeded on
  rerun.
- `swift test --filter subtitleTableViewUsesVirtualRowCountWithoutMaterializingModels` succeeded.
- `swift test --filter tableSandboxRowModelStoreTracksVirtualSearchTotalWithoutMaterializingUnloadedRows` succeeded.
- `swift test --filter CueSeekerAppTests` initially hit a transient
  `fatalError` during the test build/runner phase, then succeeded on rerun with
  93 tests passing.

## Outcome

Step 1 is complete. Test Search 2 now has an isolated top-bar entry and shares
the Test Search UI shell for the non-table UI while retaining the existing
AppKit virtual table and real search data path for end-to-end review.
