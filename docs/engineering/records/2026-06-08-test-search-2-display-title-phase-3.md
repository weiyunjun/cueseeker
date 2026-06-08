# Test Search 2 Display Title Phase 3

Human requirement:

- `docs/human/requirements/20260608-Feature-Test Search 2 Schema UI Shell.md`

## Scope

This record covers Phase 3 of the Test Search 2 table UI work: changing the
second table field from Name to Display Title and showing the search result's
existing display title value in that column.

This phase intentionally does not change filter semantics, add speaker fields,
replace the AppKit virtual table, or change visible-row hydration.

## Changes

- Added `displayTitle` to `SubtitleSearchResult`.
- Passed the existing `subtitle_search_order_rows.display_title` value through
  both exact search result materialization and visible-window result hydration.
- Renamed the table row view-model field from `name` to `displayTitle`.
- Updated `TableSandboxRowModelStore` to prefer a search result's display title
  and only fall back to path-based title resolution when a result does not
  provide one.
- Included display title in the row cache key so title changes invalidate the
  cached row.
- Added a configurable second-column header to `SubtitleTableView`.
- Set Test Search 2's second-column header to `Display Title`; existing Test
  Search and Shiori table routes keep their default `Name` header.
- Updated affected App and Core tests for the display title data path.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- `swift test --filter tableSandboxRowModelStoreUsesSearchDisplayTitleWithoutResolvingPath` succeeded.
- `swift test --filter subtitleTableViewUsesVirtualRowCountWithoutMaterializingModels` succeeded.
- `swift test --filter searchResultsExposeCueGroupLanguages` succeeded.
- `swift test --filter searchPageReturnsFriendlyFileSummaryDisplayTitles` succeeded.
- `swift test --filter CueSeekerAppTests` succeeded with 95 tests passing.
- `swift test --filter CueSeekerCoreTests` succeeded with 121 tests passing.
- `swift build --product CueSeeker` succeeded.

## Outcome

Phase 3 is complete. Test Search 2 now labels the second table column as
Display Title and reads its row content from the committed search display title
data path while preserving virtualization, first-screen loading, and visible
row hydration.
