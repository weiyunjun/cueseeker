# Implementation Record: Search and Excerpt Select Mode Toolbar Layout Refinement

- Date: 2026-10-21
- Requirement: `docs/human/requirements/20261021-UI-Search And Excerpt Select Mode Toolbar Layout Refinement.md`
- Branch: `main`

## Scope Delivered

1. **Toolbar Left Alignment With Table Outer Border (`0px` Extra Leading Padding) (`SchemaWorkbenchSearchShell.swift`)**
   - Set `SchemaWorkbenchStyle.resultCountLeadingPadding`, `selectionSummaryLeadingPadding`, and `selectionActionRowLeadingPadding` to `0px` so both non-Select and Select Mode toolbar rows align directly with the table's left outer border.

2. **Select Mode Toolbar Row 1 & Row 2 Layout and Bottom Overlay Removal (`SchemaWorkbenchSearchShell.swift`, `SchemaWorkbenchSelectionActionOverlay.swift`, `WorkbenchExcerptTableView.swift`)**
   - When entering Select Mode, hid the Search Field, Filter Button, and Sort Button row, and removed the bottom floating `Selection Action Overlay`.
   - Replaced Toolbar Row 1 in Select Mode with `selectionSummaryRow` (left-aligned with the table):
     - Leading: `WorkbenchStatusIndicator` rendering `xx / yy rows selected` with the same font, weight, color, and horizontal origin as `xx results` / `xx excerpts`, kept at full width without truncation (`fixedSize(horizontal: true, vertical: false)`).
     - Middle (spaced by `16px`): batch selection hint text (`Batch selection active: click any row to select, Shift+click for range`), which shrinks/truncates first when space is limited and shows a full-text Tooltip on hover when truncated (`workbenchTruncatedTextTooltip`).
     - Trailing (aligned to the right edge of the toolbar/table): `WorkbenchDestructiveButton` (`Exit Selection` with leading `sign-out` icon and `Esc` shortcut Tooltip).
   - Replaced Toolbar Row 2 in Select Mode with `selectionActionsRow` (left-aligned with the table, with `16px` horizontal spacing between buttons):
     - Displays `Export to Anki` (`.export` icon), `Copy Deep Links` (`.linkSimple` icon), and `Copy Table` (`.copy` icon) as standard Neutral Buttons (`WorkbenchButton`, without inline keycaps), attaches shortcut Tooltips (`Export to Anki` + `A`, `Copy Deep Links` + `D`, `Copy Table` + `T`), and preserves `Esc`, `A`, `D`, and `T` keyboard shortcut handling via `WindowKeyDownMonitor`.

## Verification

- Updated unit tests in `SubtitleTableVirtualRowTests.swift`, `SchemaWorkbenchCountSummaryTests.swift`, and `WorkbenchPageScrollbarTests.swift` verifying the `0px` toolbar alignment metrics, action button icons, Select Mode toolbar row replacement, and preserved two-row toolbar height.
- Verified test suites pass via `swift test`.
