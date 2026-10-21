# Implementation Record: Search and Excerpt Select Mode Toolbar Layout Refinement

- Date: 2026-10-21
- Requirement: `docs/human/requirements/20261021-UI-Search And Excerpt Select Mode Toolbar Layout Refinement.md`
- Branch: `main`

## Scope Delivered

1. **Default Result Count Leading Alignment (`22px`) (`SchemaWorkbenchSearchShell.swift`)**
   - Updated `SchemaWorkbenchStyle.resultCountLeadingPadding` from `14px` to `22px` (`14px + 8px`) so the leading character of `xx results` in Search and `xx excerpts` in Excerpt detail aligns vertically with the `#` header in the table's first column.

2. **Select Mode Toolbar Row 1 & Row 2 Layout and Bottom Overlay Removal (`SchemaWorkbenchSearchShell.swift`, `SchemaWorkbenchSelectionActionOverlay.swift`, `WorkbenchExcerptTableView.swift`)**
   - When entering Select Mode, hid the Search Field, Filter Button, and Sort Button row, and removed the bottom floating `Selection Action Overlay`.
   - Replaced Toolbar Row 1 in Select Mode with `selectionSummaryRow` (leading inset `22px`, matching `resultCountLeadingPadding`):
     - Leading: `WorkbenchStatusIndicator` rendering `xx / yy rows selected` with the same font, weight, color, and horizontal origin as `xx results` / `xx excerpts`, kept at full width without truncation (`fixedSize(horizontal: true, vertical: false)`).
     - Middle (spaced by `16px`): batch selection hint text (`Batch selection active: click any row to select, Shift+click for range`), which shrinks/truncates first when space is limited and shows a full-text Tooltip on hover when truncated (`workbenchTruncatedTextTooltip`).
     - Trailing (aligned to the right edge of the toolbar/table): `WorkbenchDestructiveButton` (`Exit Selection` with leading `sign-out` icon).
   - Replaced Toolbar Row 2 in Select Mode with `selectionActionsRow` (leading inset `22px`, aligning the first button's left border with `xx / yy rows selected` and `xx results`, and `16px` horizontal spacing between buttons):
     - Displays `Export to Anki`, `Copy Deep Links`, and `Copy Table` as standard Neutral Buttons (`WorkbenchButton`, without inline keycaps), attaches shortcut Tooltips (`Export to Anki` + `A`, `Copy Deep Links` + `D`, `Copy Table` + `T`), and preserves `Esc`, `A`, `D`, and `T` keyboard shortcut handling via `WindowKeyDownMonitor`.

## Verification

- Updated unit tests in `SubtitleTableVirtualRowTests.swift` and `WorkbenchPageScrollbarTests.swift` verifying the `22px` toolbar alignment metrics, Select Mode toolbar row replacement, and preserved two-row toolbar height.
- Verified test suites pass via `swift test`.
