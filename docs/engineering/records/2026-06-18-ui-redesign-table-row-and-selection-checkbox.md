# Engineering Record: UI Redesign - Table Row & Row Selection Checkbox (Section 2.17 & 2.19)

## 1. Covering Human-Owned Requirement

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## 2. Scope

This record covers the implementation and follow-up fix for the Search 2
redesign table row work:

- Section 2.17 Table Row
- Section 2.19 Row Selection Checkbox

The work was intentionally limited to the `test-search-2` redesign table path.
It does not change database ordering, table hydration strategy, column hiding,
or row action behavior.

## 3. Implementation Summary

### 3.1 Table row selected rendering

- Added a row-selection rendering input to `SubtitleTableView` so AppKit row
  drawing can paint selected rows with `WorkbenchRedesignColors.NS.rowSelected`.
- Preserved the existing fixed-height virtual table geometry. Redesign rows
  continue to use a 64 px fixed height, keeping row index lookup as an O(1)
  y-offset calculation.
- Kept `drawRowsNow(in:)` constrained to `visibleRowRange(in:)` so rendering
  remains viewport-bound instead of materializing the full result set.

### 3.2 Virtual-friendly checkbox selection state

- Added `TableSandboxRowSelectionState` to represent selection without storing
  every selected row index.
- Used two storage modes:
  - explicit selected row indexes for normal sparse selection
  - all-except deselected row indexes after selecting all rows
- The header checkbox state is derived from selected count:
  - unchecked when zero rows are selected
  - checked when all rows are selected
  - indeterminate when some but not all rows are selected

### 3.3 Header and row checkbox rendering

- Implemented the header checkbox as a SwiftUI-hosted control because the table
  header already uses SwiftUI hosting for redesign header cells.
- Implemented body row checkboxes with AppKit drawing and hit testing. This
  avoids creating per-row SwiftUI controls for large result sets.
- Row checkbox click handling toggles only the hit row and invalidates only the
  affected row plus the header host refresh.

### 3.4 Row checkbox focus fix

- Follow-up review found that body row checkboxes could be clicked but did not
  have a real focus state, so the required focus ring could never be drawn.
- Added a focused row-checkbox index to the AppKit coordinator.
- Clicking a row checkbox now gives the custom document view first responder
  status, records the focused checkbox row, and redraws that row with the
  shared focus ring token.
- When the custom document view resigns first responder status, the focused row
  checkbox is cleared so the focus ring cannot remain visually stale.
- Space toggles the currently focused row checkbox. Arrow up/down moves the
  focused checkbox row without materializing offscreen controls.

### 3.5 Header-to-body keyboard focus bridge

- Follow-up manual testing found that focusing the final sortable header cell
  and pressing Tab did not enter the first body row checkbox.
- The cause was that header controls are real SwiftUI buttons hosted in AppKit,
  while body checkboxes are AppKit-drawn virtual row elements. The system key
  view loop could discover the header buttons but could not discover drawn row
  checkboxes.
- Added an AppKit keyboard focus monitor scoped to the table window. When Tab
  is pressed from the final visible interactive header, the coordinator moves
  first responder status to the table document view and focuses the first
  visible row checkbox.
- The final visible interactive header is resolved dynamically: Language,
  Speaker, Cues, then Display Title. This keeps the bridge correct when optional
  columns are hidden.
- The document view handles Tab while body checkbox focus is active by moving
  the single focused row index to the next or previous row. At the first or
  last row boundary it clears the focused checkbox and asks the window to move
  to the previous or next key view, avoiding a focus trap.

## 4. Virtualization Constraints Preserved

- No SwiftUI `List`, `Table`, or per-row `NSHostingView` was introduced for body
  rows.
- Body checkbox drawing is performed only inside the existing AppKit row draw
  pass.
- Selection after "select all" stores only exceptions, so selecting 100,000 rows
  does not allocate 100,000 selected indexes.
- Existing visible-row hydration remains the data loading boundary.

## 5. Verification

Commands run from `apps/macos-native/`:

```text
swift test
```

Result:

- 274 tests passed after the initial 2.17/2.19 implementation.
- 275 tests passed after the row checkbox focus-ring fix.

Additional focused coverage added:

- Redesign row height remains fixed at 64 px.
- Redesign row selected state is provided by lazy row-index lookup.
- Row selection state can select all 100,000 rows without materializing every
  selected index.
- Focused row checkbox state stores only one row index and clears when row
  count shrinks below that index.
- Keyboard entry into the virtual checkbox area resolves to the first visible
  row, or row 0 when no visible range is available yet.
- Tab and Shift+Tab move between focused virtual row checkboxes without
  materializing row controls, and exit the table focus chain at row boundaries.

## 6. Outcome

The implementation now matches the expected 2.17 selected-row behavior and the
2.19 row/header checkbox interaction model while preserving the table
virtualization strategy required for large result sets.
