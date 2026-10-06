# Search Field Height And Batch Selection Row Simplification

Human-owned documents:

- `docs/human/requirements/20261006-UI-Search Field Height And Batch Selection Row Simplification.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Problem**:
   - The search box in Workbench search and Command Panel was 40px, appearing oversized compared to the 36px controls and buttons.
   - When focused, the search field had an accidental outer `focusRing` glow overlay, which conflicted with the `UI Design System.md` rule that specifies border-only focus indication without an outer focus ring.
   - The batch selection mode previously displayed an elaborate highlighted banner container (with background fill and outline border), which created unnecessary visual noise and introduced height inconsistencies.
   - Spacing between the second row and the table needed unification to 8px (`--spacing-2`).

2. **Root Cause**:
   - `WorkbenchControlMetrics.redesignSearchHeight` was defined as 40px instead of unifying with the standard `--height-control: 36px` (`redesignHeight`).
   - `WorkbenchSearchField` included an outer `focusRing` `.overlay` on focus, and its border `.overlay` lacked `.allowsHitTesting(false)`.
   - `SchemaWorkbenchSearchShell.selectionBanner` had custom background and border shapes instead of a simple horizontal action row matching the default action row's style.
   - Table bottom padding and pinned header height in `SchemaWorkbenchSearchShell` and `WorkbenchExcerptTableView` used `--spacing-3` (12px) instead of `--spacing-2` (8px).

## What changed

1. **Workbench Controls (`WorkbenchControls.swift`)**:
   - Unified `WorkbenchControlMetrics.redesignSearchHeight` to `redesignHeight` (36px).
   - Removed the outer `focusRing` `.overlay` from `WorkbenchSearchField`, ensuring focus state changes border color only with zero outer glow.
   - Added `.allowsHitTesting(false)` to the 1px stroke border `.overlay` so it never intercepts hit-testing or blocks focus/clicks.
2. **Search Shell (`SchemaWorkbenchSearchShell.swift`)**:
   - Removed redundant `.frame(height: ...)` from `WorkbenchSearchField`.
   - Set row heights of `defaultActionRow` and `selectionBanner` to `WorkbenchControlMetrics.redesignHeight` (36px).
   - Kept `defaultActionRow` and `selectionBanner` vertically centered with standard `HStack(spacing: ...)` so the result count and batch selection hint text are vertically centered with the 36px action button.
   - Simplified `selectionBanner` to remove the background shape, border stroke, and interior padding offsets.
   - Styled the batch selection hint text with `WorkbenchControlMetrics.redesignFontSizeBody` (14px regular) and `WorkbenchRedesignColors.textMuted`.
   - Updated search toolbar bottom padding to `redesignSpacing2` (8px).
3. **Excerpt Table View (`WorkbenchExcerptTableView.swift`)**:
   - Updated pinned search toolbar bottom padding to `redesignSpacing2` (8px).
   - Updated `pinnedHeaderHeight` formula to `redesignHeight * 2 + redesignSpacing2 * 2` (88px).
4. **Tests (`WorkbenchControlMetricsTests.swift`)**:
   - Added test expectation verifying `WorkbenchControlMetrics.redesignSearchHeight == 36`.

## Verification

- Automated tests:
  - `swift test --filter WorkbenchControlMetricsTests`: passed.
  - `swift test --filter WorkbenchInputControlsTests`: passed.
  - `swift test --filter PlaybackPageFocusIsolationTests`: passed.
