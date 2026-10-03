# Button Height Reduction

Human-owned documents:

- `docs/human/requirements/20261004-UI-Button Height Reduction.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Button Proportion Optimization**:
   - Standard buttons (`--height-control`) were originally fixed at 40px height with 14px 500 Medium font and 18px icons, leaving excessive vertical padding (~10-13px on each side) and feeling tall/bloated.
   - Reduced to 36px to strike the optimal visual balance on macOS between vertical breathing room and compact alignment.
   - Keeping typography (14px 500 Medium), icon size (18px), horizontal padding (14px), and corner radius (8px) unchanged.

## What changed

1. **Control Metrics**:
   - In `WorkbenchControls.swift`, updated `WorkbenchControlMetrics.redesignHeight` to `36` (`--height-control: 36px`).
   - `WorkbenchButton`, `WorkbenchPrimaryButton`, `WorkbenchDestructiveButton`, and `CoverSummaryActionButton` automatically inherit the 36px height.
2. **Search Bar Toolbar Decoupling**:
   - In `SchemaWorkbenchSearchShell.swift`, `SchemaWorkbenchSearchToolbar`'s container frame height remains explicitly bound to `WorkbenchControlMetrics.redesignSearchHeight` (40px, `--height-filter-bar-control`), preserving the 40px search field geometry.
   - In `WorkbenchExcerptTableView.swift`, `pinnedHeaderHeight` continues to use `redesignSearchHeight + redesignSpacing3`.
3. **Status Line Alignment**:
   - In `WorkbenchFileView.swift`, the status and action row (`statusIndicator` and `statusAndActionRow`) remain aligned with `redesignHeight`, automatically adapting to the 36px button height 1:1.
4. **Unit Verification**:
   - In `WorkbenchControlMetricsTests.swift`, updated `buttonHeightMatchesDesignSpecification()` asserting `WorkbenchControlMetrics.redesignHeight == 36`.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: 7/7 passed.
  - `swift test --package-path apps/macos-native --filter WorkbenchInputControlsTests`: 4/4 passed.
  - `swift test --package-path apps/macos-native --filter CoverSummaryCardTests`: 10/10 passed.
  - `swift test --package-path apps/macos-native --filter WorkbenchPageScrollbarTests`: 4/4 passed.
