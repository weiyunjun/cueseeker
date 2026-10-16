# Implementation Record: Workbench Toolbar Left Alignment And Sticky Header Refinement

- **Requirement**: `docs/human/requirements/20261016-UI-Workbench Toolbar Left Alignment And Sticky Header Refinement.md`
- **Date**: 2026-10-16

## Summary of Changes

1. **Unified `--spacing-3` (`12px`) Left-Aligned Workbench Toolbars (`Search`, `Library`, `Excerpt`, `File`)**:
   - Updated `SchemaWorkbenchSearchToolbar` in `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`:
     - Default second row (`Search` page `L-05.4`): left-aligned (`Filter` button $\rightarrow$ Result count text) with `--spacing-3` (`12px`) spacing and trailing `Spacer(minLength: 0)`.
     - Batch Selection Banner (`Search` and `Excerpt Detail` Select Mode): left-aligned (`Exit Select` button $\rightarrow$ selection hint text) with `--spacing-3` (`12px`) spacing and trailing `Spacer(minLength: 0)`.
   - Updated `WorkbenchTestLibraryView.sortBar` and `openSortMenu` in `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`:
     - Left-aligned (`Sort` button $\rightarrow$ Folder count text) with `--spacing-3` (`12px`) spacing, and anchored the Sort dropdown menu to the left edge (`anchorFrame`) of the Sort button.
   - Updated `LibraryOverviewLayout` in `apps/macos-native/Sources/CueSeekerApp/Shared/LibraryOverviewComponents.swift`:
     - Left-aligned (`New List` button $\rightarrow$ Excerpt summary text) with `--spacing-3` (`12px`) spacing.

2. **`Excerpt` Level 2 Merged Single-Row Toolbar (`L-05.3` / `L-05.4`)**:
   - Added `mergesSearchAndActionsIntoSingleRow: Bool` to `SchemaWorkbenchSearchToolbar` in `SchemaWorkbenchSearchShell.swift` and enabled it in `WorkbenchExcerptTableView.swift`.
   - Merged the search field and action bar into a single `--height-control` (`36px`) row (`pinnedHeaderHeight = 36 + 16 = 52px`):
     - Default state: left-aligned (`Search Field` $\rightarrow$ `Filter` button $\rightarrow$ Excerpt count text) with `--spacing-3` (`12px`) spacing; `Search Field` expands (`maxWidth: .infinity`) and shrinks first (`minWidth: 0`) when container width decreases while `Filter` button and Excerpt count keep their intrinsic widths (`fixedSize(horizontal: true, vertical: false)`, `layoutPriority(1)`).
     - Select Mode: replaces the entire merged row with the left-aligned Batch Selection Banner (`Exit Select` button $\rightarrow$ selection hint text), covering the search field, Filter button, and Excerpt count until Select Mode exits.

3. **`File` All-Level Left-Aligned Action Bar & Sticky Top Rows (`L-04.5` Level 1 / 2 / 3)**:
   - Updated `actionRow` and `statusAndActionRow` in `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift` to left-align `Add Folder` button $\rightarrow$ `Index Now` button $\rightarrow$ Index status indicator with unified `--spacing-3` (`12px`) spacing across all 3 levels.
   - Refactored `fileScrollSurface` in `WorkbenchFileView.swift` so Row 1 (`statusAndActionRow`) and Row 2 (`breadcrumbRow` on Level 2/3 or `rootFoldersHeaderRow` on Level 1 when `!indexing.selectedFolders.isEmpty`) sit in a frozen top header above `WorkbenchScrollView([.vertical])` inside `WorkbenchScrollView([.horizontal])`, keeping the top two rows fixed during vertical scrolling while still scrolling horizontally together with page content below `AppShellLayout.pageContentMinimumWidth` (`480px`).

## Verification

- Automated unit tests (`swift test --filter "WorkbenchControlMetricsTests|SchemaWorkbenchCountSummaryTests|WorkbenchPageScrollbarTests|FileRouteNavigationTests|FileCardMenuTests|WorkbenchScrollViewTests" --no-parallel`):
  - `WorkbenchControlMetricsTests`: verified both two-row Search pinned toolbar height (`104px`) and single-row Excerpt Detail pinned toolbar height (`52px`), as well as `redesignSpacing3 == 12`.
  - `WorkbenchPageScrollbarTests`: verified `excerptMergedSingleRowToolbarShrinksSearchFieldFirstAndCoversSearchInSelectMode` and `filePageFreezesTopActionAndBreadcrumbRowsAboveVerticalScrollView`.
  - All 42 tests across the 6 suites passed.
