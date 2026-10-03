# Button Height Reduction To 32px

Human-owned documents:

- `docs/human/requirements/20261004-UI-Button Height Reduction To 32px.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Button Proportion Optimization**:
   - Previously, standard buttons (`--height-control`) were fixed at 40px height while using a 14px 500 Medium font and 18px icons, leaving excessive vertical padding (~10-13px on each side) and feeling disproportionately tall compared to the compact desktop scale of macOS.
   - The table row menu items (`WorkbenchPopoverRow`) utilize a 32px height with the identical 14px font and 18px icon size, presenting a much more balanced and refined proportion.
   - Other interactive controls in the system (such as segmented controls, filter chips, icon buttons, and sidebar items) already standardise on 32px.
   - Aligning standard button height to 32px removes early mobile/touch-target legacy padding while keeping typography, icon size, horizontal padding, and corner radius unchanged.

## What changed

1. **Control Metrics**:
   - In `WorkbenchControls.swift`, updated `WorkbenchControlMetrics.redesignHeight` from `40` to `32` (`--height-control: 32px`).
   - `WorkbenchButton`, `WorkbenchPrimaryButton`, and `WorkbenchDestructiveButton` automatically inherit the 32px height.
2. **Search Bar Toolbar Decoupling**:
   - In `SchemaWorkbenchSearchShell.swift`, explicitly bound `SchemaWorkbenchSearchToolbar`'s container frame height to `WorkbenchControlMetrics.redesignSearchHeight` (40px, `--height-filter-bar-control`) instead of the shared `redesignHeight`, preserving the 40px search field geometry.
   - In `WorkbenchExcerptTableView.swift`, updated `pinnedHeaderHeight` calculation to use `redesignSearchHeight + redesignSpacing3`.
3. **Status Line Alignment**:
   - In `WorkbenchFileView.swift`, the status and action row (`statusIndicator` and `statusAndActionRow`) remain aligned with `redesignHeight`, automatically adapting to the 32px button height 1:1.
4. **Unit Verification**:
   - In `WorkbenchControlMetricsTests.swift`, added `buttonHeightMatchesDesignSpecification()` asserting `WorkbenchControlMetrics.redesignHeight == 32`.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: 7/7 passed.
  - `swift test --package-path apps/macos-native --filter WorkbenchInputControlsTests`: 4/4 passed.
  - `swift test --package-path apps/macos-native --filter CoverSummaryCardTests`: 10/10 passed.
  - `swift test --package-path apps/macos-native --filter WorkbenchPageScrollbarTests`: 4/4 passed.
