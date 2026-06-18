# Engineering Record: UI Redesign - Count Summary

## 1. Covering Human-Owned Requirement

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## 2. Scope

This record covers Section 2.23 Count Summary for the Search 2 redesign table
utility bar.

The work is limited to:

- Showing a table count summary on the left side of the Table Utility Bar.
- Keeping the View trigger on the right side aligned with the table edge.
- Formatting default, selected, and overflow count states from the requirement.
- Aligning the first visible number with the table checkbox column.
- Preserving the virtualized `SubtitleTableView` row rendering and hydration
  behavior.

## 3. Implementation Summary

- Added `SchemaWorkbenchTableSummary` and `SchemaWorkbenchCountSummaryText` to
  format count summary text as segmented primary/secondary text.
- Added `SchemaWorkbenchCountSummaryView` to render the summary with body-size
  text, primary value color, and muted label color.
- Extended `SchemaWorkbenchSearchShell` and `SchemaWorkbenchTableUtilityBar` to
  accept an optional summary without changing legacy shell callsites.
- Wired `WorkbenchTestSearch2View` to provide the summary:
  - Empty query / all cues mode uses the loaded all-cue total.
  - Search mode uses `search.searchResultTotalCount`, matching the formal
    Search flow where the value increases as exact count progress arrives.
  - Selected count comes from `TableSandboxRowSelectionState.selectedCount`,
    preserving sparse all-row selection for large tables.
- Added `SubtitleTableMetrics.checkboxLeadingInset` and used it as the summary
  leading inset so the first number aligns with the row checkbox.
- Added `WorkbenchControlMetrics.redesignFontSizeBody` for the documented
  body-size summary text token.

## 4. Virtualization Constraints Preserved

- No row scan or materialization was added.
- Count summary rendering reads only aggregate count state and sparse selection
  state.
- The existing table row provider, hydration, visible-row callbacks, and AppKit
  virtualized rendering path remain unchanged.

## 5. Verification

Commands run from `apps/macos-native/`:

```text
swift build
swift test --quiet
```

Result:

- `swift build` passed.
- `swift test --quiet` passed with 304 Swift Testing tests and 7 CASS XCTest
  tests.
- The test command printed existing playback history disk I/O and EBML parsing
  warnings, but the test run completed successfully.

## 6. Outcome

The Search 2 Table Utility Bar now shows the documented Count Summary states
while keeping the View trigger right-aligned and the first count value aligned
with the table checkbox column.
