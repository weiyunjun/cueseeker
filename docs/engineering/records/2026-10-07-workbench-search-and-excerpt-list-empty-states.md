# Workbench Search And Excerpt List Empty States

Human-owned documents:

- `docs/human/requirements/20261007-UI-Workbench Search And Excerpt List Empty States.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Table Header Hiding in Empty States**:
   - In Workbench Search and Excerpt List pages, when there are no items or no search results, the previous table header remained visible, creating an awkward visual disconnect where a column header row framed empty space.
   - Requirement dictates that in all 4 empty states:
     - Search Empty Query (unsearched)
     - Search Empty Results (0 results found)
     - Excerpt List Empty (0 saved cues)
     - Excerpt List Empty Filter/Search (0 matches after search/filtering)
     the table header must be hidden (header height 0, header view hidden, divider border hidden).
2. **Empty Hint Centering**:
   - In Workbench Search, the hint text was already centered in the area below the search toolbar.
   - In Excerpt List, because the page uses `hostsPageChromeInTable: true` with a Cover Summary card (~200pt) and pinned Search Toolbar (~80pt), the previous `WorkbenchEmptyHint` was centered across the full window height, causing it to render immediately beneath the toolbar instead of being centered in the remaining visible content area.
   - The empty hint is now positioned inside a GeometryReader deducting the exact Cover Summary and Pinned Toolbar height to center dynamically in the remaining viewport area.
3. **Missing No-Results Hint Strings**:
   - Previously, search with 0 results had no empty hint displayed in the table area.
   - New localization keys `table.search_no_results` and `excerpt.table.no_results` provide concise, macOS-native copy in Simplified Chinese (`zh-Hans`), English (`en`), and Traditional Chinese (`zh-Hant`).

## What changed

1. **Localization (`Localizable.strings`)**:
   - Added `table.search_no_results`:
     - `en`: `No matching cues found.`
     - `zh-Hans`: `未找到匹配的台词。`
     - `zh-Hant`: `未找到相符的台詞。`
   - Added `excerpt.table.no_results`:
     - `en`: `No matching excerpts found.`
     - `zh-Hans`: `未找到匹配的摘录。`
     - `zh-Hant`: `未找到相符的摘錄。`
2. **Table Component (`SubtitleTableView.swift`)**:
   - Added `showsHeader: Bool` (defaults to `true`).
   - Wired `showsHeader` into `SubtitleTableView.Coordinator` to update `headerView?.isHidden = !showsHeader`, set `currentHeaderHeight = 0` when `showsHeader == false`, and dynamically adjust `headerHeightConstraint` (AutoLayout in standard mode) and `layoutPageChrome` / `pageScrollGeometry` (page chrome mode).
3. **Workbench Search View (`WorkbenchTestSearchView.swift`)**:
   - Derived `showsSearchNoResultsHint` from `!showsSearchEmptyHint && search.searchStatus == .completed && exactSearchResultRowCount == 0`.
   - Extracted `workbenchSearchShowsTableHeader(showsSearchEmptyHint:rowCount:)` evaluating `!showsSearchEmptyHint && rowCount > 0`.
   - Tied `showsHeader` directly to actual row count (`rowCount > 0`), ensuring table header does not flash into view during debounce or asynchronous search execution when row count is 0.
   - Passed `showsHeader: workbenchSearchShowsTableHeader(showsSearchEmptyHint: showsSearchEmptyHint, rowCount: snapshot.totalRowCount)` to `SubtitleTableView`.
   - Displayed `WorkbenchEmptyHint(message: L("table.search_empty_hint"))` for empty query and `WorkbenchEmptyHint(message: L("table.search_no_results"))` for zero results.
4. **Workbench Excerpt Table View (`WorkbenchExcerptTableView.swift`)**:
   - Defined `showsEmptyListHint` and `showsEmptyResultsHint`.
   - Computed `showsTableHeader = !showsEmptyListHint && !showsEmptyResultsHint`.
   - Passed `showsHeader: showsTableHeader` to `SubtitleTableView`.
   - Added `excerptEmptyHint(message:)` using `GeometryReader` deducting `topChromeHeight` (`scrollableHeaderHeight + pinnedHeaderHeight`) to center the empty hint precisely within the remaining visible space.
5. **Tests (`WorkbenchEmptyHintTests.swift`)**:
   - Added `subtitleTableViewHidesHeaderWhenShowsHeaderIsFalse()` to verify coordinator `showsHeader`, `currentHeaderHeight`, `header.isHidden`, and frame heights in `pageChromeFramesForTesting()`.
   - Added `emptyStateLocalizationMatchesRequirements()` to verify all four empty state localization keys across `en`, `zh-Hans`, and `zh-Hant`.
   - Added `workbenchSearchShowsTableHeaderRequiresNonEmptyRowsAndNonEmptyQuery()` to verify header remains hidden during empty query and 0-row debounce/searching states, and only displays when rows exist.

## Verification

- Automated tests:
  - `swift test --filter WorkbenchEmptyHintTests`: 4/4 passed.
  - `swift test --filter AppLocalizationTests`: 4/4 passed.
  - `swift test --filter SubtitleTableVirtualRowTests`: 101/101 passed.
  - `swift test --filter SearchStoreTests`: 27/27 passed.
  - `swift test --filter ExcerptPresentationTests`: 6/6 passed.
