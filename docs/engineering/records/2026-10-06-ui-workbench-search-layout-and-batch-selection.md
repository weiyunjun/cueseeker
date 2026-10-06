# Workbench Search Layout And Batch Selection

Human-owned documents:

- `docs/human/requirements/20261006-UI-Workbench Search Layout And Batch Selection.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Two-Row Workbench Search Toolbar**:
   - Split search input and secondary controls into two rows:
     - Row 1: Full-width independent search box, capsule radius (`9999px`), height `40px`, disabled during batch selection mode. Result count is removed from within the search input.
     - Row 2 (Default): Result count text on the left (`textMuted`, 14px regular), Neutral filter button on the right.
     - Row 2 (Batch Selection): Replaced by a full-width Accent highlight banner (`--color-filter-chip-selected-bg` background, `--color-filter-chip-selected-content` border/text). Left side displays batch selection hint text (`table.batch_selection_banner_hint`), right side provides Neutral button `退出选择` (`table.exit_select`).
2. **Batch Selection Trigger & Interactions**:
   - Hover over an unselected row: Row's `#` sequence number dynamically displays an unchecked circle Checkbox. Clicking precisely inside the Checkbox toggles row selection and enters batch selection mode; clicking outside the Checkbox retains regular row actions (e.g. play/seek).
   - Hover over table header `#`: Header dynamically displays a select-all circle Checkbox. Clicking it toggles all rows and enters batch selection mode.
   - Batch selection mode: Checkbox is permanently displayed in column 1; clicking anywhere on the row toggles selection; Shift+click performs range selection.
   - Automatic Mode Exit: Deselecting all rows (selected count reaches 0), clicking `退出选择`, or pressing `Esc` exits batch selection mode and restores row 2 default controls.
3. **Bottom Selection Action Overlay Cleanliness**:
   - Removed the internal `退出 [Esc]` button from `SchemaWorkbenchSelectionActionOverlay` action flow, keeping only export and copy actions.
   - Retained the global `Esc` key shortcut listener to exit batch selection mode.

## What changed

1. **Localization (`Localizable.strings`)**:
   - Added `table.batch_selection_banner_hint` in `zh-Hans`, `en`, and `zh-Hant`.
   - Updated `table.exit_select` translations across languages.
2. **Search Shell Toolbar (`SchemaWorkbenchSearchShell.swift`)**:
   - Refactored `SchemaWorkbenchSearchToolbar` into a two-row layout with `VStack(spacing: redesignSpacing2)`.
   - Search field is disabled when `isSelectionMode` is active.
   - Row 2 switches between default action row (`searchResultCountText` + filter button) and `selectionBanner` (accent background, accent border, hint text + neutral exit button).
3. **Selection Action Overlay (`SchemaWorkbenchSelectionActionOverlay.swift`)**:
   - Removed `allActions` and the `退出 [Esc]` button from `WrappingFlowLayout`.
   - Retained key listener for `keyCode == 53` (`Esc`) to call `onExitSelectionMode()`.
4. **Excerpt Table View (`WorkbenchExcerptTableView.swift`)**:
   - Updated `pinnedHeaderHeight` to `redesignSearchHeight * 2 + redesignSpacing2 + redesignSpacing3` (100px) to accommodate the two-row toolbar.
   - Updated selection handlers (`toggleRowSelection`, `shiftSelectRow`, `toggleAllRowSelection`) to auto-enter selection mode when count > 0 and auto-exit when count == 0.
5. **Search Table View (`WorkbenchTestSearchView.swift`)**:
   - Updated selection handlers (`toggleRowSelection`, `shiftSelectRow`, `toggleAllRowSelection`) to auto-enter selection mode when count > 0 and auto-exit when count == 0.
6. **Table Sandbox (`SubtitleTableView.swift`)**:
   - `SubtitleTableHeaderView`: Tracks hover on index header column; displays select-all checkbox when hovered in non-selection mode; clicking it toggles selection and enters selection mode.
   - Cell drawing: Draws circle checkbox on column 1 when `isSelectionMode || hoveredRow == row`.
   - Checkbox hit-testing and mouse handling: Allows clicking the checkbox rect on unselected rows to toggle selection even when not yet in selection mode.
7. **Tests**:
   - `SubtitleTableVirtualRowTests.swift`: Added tests for unselected row checkbox hit-testing vs cue click playing, and header sequence column hover checkbox display.
   - `SchemaWorkbenchCountSummaryTests.swift`: Added tests verifying bottom overlay export actions exclude the exit button.

## Verification

- Automated tests:
  - `swift test --filter SubtitleTableVirtualRowTests`: 98/98 passed.
  - `swift test --filter SchemaWorkbenchCountSummaryTests`: 4/4 passed.
  - `swift test --filter Workbench`: all workbench layout and metrics tests passed.
