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
     - Leading: `WorkbenchStatusIndicator` rendering `xx / yy rows selected` with the same font, weight, color, and horizontal origin as `xx results` / `xx excerpts`.
     - Middle (spaced by `16px`): batch selection hint text (`Batch selection active: click any row to select, Shift+click for range`).
     - Trailing (aligned to the right edge of the toolbar/table): `WorkbenchDestructiveButton` (`Exit Selection` with leading `sign-out` icon).
   - Replaced Toolbar Row 2 in Select Mode with `selectionActionsRow` (leading inset `10px`, which combines with each button's `12px` internal leading padding so the first button's label starts at `22px`, aligning with `xx / yy rows selected` and `xx results`):
     - Displays `Export to Anki A`, `Copy Deep Links D`, and `Copy Table T` action buttons and preserves `Esc`, `A`, `D`, and `T` keyboard shortcut handling via `WindowKeyDownMonitor`.

## Verification

- Updated unit tests in `SubtitleTableVirtualRowTests.swift` and `WorkbenchPageScrollbarTests.swift` verifying the `22px` / `10px` toolbar alignment metrics, Select Mode toolbar row replacement, and preserved `88px` two-row toolbar height.
- Verified test suites pass via `swift test`.
