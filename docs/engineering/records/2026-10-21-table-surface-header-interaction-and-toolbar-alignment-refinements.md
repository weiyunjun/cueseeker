# Implementation Record: Table Surface, Header Interaction, and Toolbar Alignment Refinements

- Date: 2026-10-21
- Requirement: `docs/human/requirements/20261021-UI-Table Surface Header Interaction And Toolbar Alignment Refinements.md`
- Branch: `main`

## Scope Delivered

1. **Table Surface Unification (`--color-bg-surface`) & Dedicated Row State Tokens (`WorkbenchRedesignTokens.swift`, `SubtitleTableView.swift`)**
   - Updated `C-06.1 Table` header and body surface backgrounds from `--color-table-bg` to `--color-bg-surface` (Light `#FFFFFF`; Dark `#1C1C1F`) so Dark Mode tables no longer render an extra gray canvas background and sticky headers remain opaque over scrolling rows.
   - Added `--color-table-row-hover` (`WorkbenchRedesignColors.tableRowHover` / `NS.tableRowHover`: Light `#F9FAFB`, Dark `#26262B`) and `--color-table-row-selected` (`WorkbenchRedesignColors.tableRowSelected` / `NS.tableRowSelected`: Light `#ECEEF2`, Dark `#313137`) stepped from `--color-bg-surface`, and applied them to `C-06.2 Table Header Cell` hover, `C-06.3 Table Row` hover/selected states, and `C-08.5 Cue State Indicator` hover background inside table rows while preserving `--color-table-bg`, `--color-row-hover`, and `--color-row-selected` for Settings/File/Task cards.

2. **Table Header Height (`44px`), Vertical Centering, and Toolbar Row/Bottom Gaps (`8px`) (`WorkbenchControls.swift`, `SchemaWorkbenchSearchShell.swift`, `WorkbenchExcerptTableView.swift`, `SubtitleTableView.swift`)**
   - Updated `WorkbenchControlMetrics.redesignTableHeaderHeight` (`--height-table-header`) from `27px` to `44px`.
   - Updated `SubtitleTableHeaderCellView`, `WorkbenchCheckboxButton`, and header text fragment layout to center header titles (`#`, column headers) and the select-all checkbox vertically within the `44px` header row.
   - Updated `L-05.4 Search / Excerpt Toolbar Layout` row gap (`SchemaWorkbenchStyle.toolbarRowSpacing`) and bottom gap (`SchemaWorkbenchStyle.toolbarBottomGap`) from `--spacing-4` (`16px`) to `--spacing-2` (`8px`) and pinned toolbar height (`SchemaWorkbenchStyle.pinnedToolbarHeight`) from `104px` to `88px` across Search and Excerpt detail views.

3. **Full-Row Header Hover, Checkbox Visibility, and Select-All Interaction (`SubtitleTableView.swift`)**
   - Updated `SubtitleVirtualTableHeaderView` so hovering anywhere on the header row renders `--color-table-row-hover` across the full header row and switches the leading `#` slot to the select-all `Checkbox` whenever selectable rows exist (`canToggleSelectionForRendering() == true`).
   - Kept the header row background at `--color-bg-surface` when not hovered regardless of `None Selected`, `Partially Selected`, or `All Selected` state.
   - Outside `Select Mode`, restricted select-all click activation to the leading checkbox cell while preserving text drag-selection and copy on column headers; inside `Select Mode`, clicking anywhere on the header row toggles select-all.

4. **Rounded Outer Table Border (`8px`) and Last-Row Divider Omission (`SubtitleTableView.swift`)**
   - Added `SubtitleTableOutlineOverlayView` and `Coordinator.tableOutlineFrameInContainer()` to wrap the visible table (`Header` + `Body` rows) in an `8px` (`--radius-control`) rounded `1px` (`--border-width-control`) border using `--color-border-control`, masking outer corners and hugging the bottom of the last data row when row content is shorter than the viewport.
   - Updated `shouldDrawRowBottomDivider(forRow:)` to omit the bottom divider on the final data row (`row == rowCount - 1`) so it does not double up against the rounded outer border.

5. **Toolbar Result Count Leading Alignment (`14px`) (`SchemaWorkbenchSearchShell.swift`)**
   - Added leading padding `--padding-control-x` (`14px`, `SchemaWorkbenchStyle.resultCountLeadingPadding`) to the `Result Count` status indicator (`xx results` / `xx excerpts`) in Toolbar Row 2 `Default` state so its left edge aligns with the search field's leading magnifying glass icon and the table's first-column checkbox.

## Verification

- Updated and added unit tests in `SubtitleTableVirtualRowTests.swift` and `FileCardMenuTests.swift` covering the new color tokens, `36px` header height, `8px` toolbar bottom gap, `14px` result count leading padding, full-row header hover checkbox visibility and background state, short-content table outline hugging, and last-row divider omission.
- Verified test suites pass via `swift test`.
