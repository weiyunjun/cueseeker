# Implementation Record: Segmented Control Neutral Styling And Tooltip Warmup

- **Date**: 2026-10-17
- **Requirement**: `docs/human/requirements/20261017-UI-Segmented Control Neutral Styling And Tooltip Warmup.md`
- **Design References**:
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Controls.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/Tooltip Usage Registry.md`

## Summary of Changes

1. **Segmented Control Neutral Groove & Raised Bordered Selected Segment Styling (`WorkbenchRedesignTokens.swift`, `WorkbenchSegmentedControl.swift`)**:
   - Added and updated Segmented Control tokens in `WorkbenchRedesignColors.NS` and `WorkbenchRedesignColors`:
     - `--color-segmented-control-bg` (`segmentedControlBg`): Light `rgba(0,0,0,0.055)`; Dark `rgba(255,255,255,0.06)`.
     - `--color-segmented-control-border` (`segmentedControlBorder`): Light `transparent`; Dark `rgba(255,255,255,0.08)` with `1px` border width.
     - `--color-segmented-control-selected-bg` (`segmentedControlSelectedBg`): Light `#FFFFFF`; Dark `rgba(255,255,255,0.16)`.
     - `--color-segmented-control-selected-border` (`segmentedControlSelectedBorder`): Light `#E5E7EB`; Dark `rgba(255,255,255,0.12)` with `1px` border width.
     - `--color-segmented-control-selected-content` (`segmentedControlSelectedContent`): aliases `textPrimary` (Light `#1F1F1F`; Dark `#E4E4E4`).
     - `--color-segmented-control-unselected-content` (`segmentedControlUnselectedContent`): aliases `textMuted` (Light `#717171`; Dark `#979797`).
   - Updated `WorkbenchSegmentedControl` container and segment rendering to use the neutral groove background/border and raised bordered selected segment without internal shadows, preserving existing geometry (`32px` height, `3px` padding, `2px` gap, `8px` outer radius, `5px` selected radius, `12px` font size, `500` weight, equal option widths, no hover state).

2. **Tooltip Continuous Hover Warmup / Skip Delay Window (`WorkbenchControls.swift`, `Tooltip.swift`)**:
   - Added `--delay-tooltip-skip-window: 0.3s` (`WorkbenchControlMetrics.redesignTooltipSkipWindowDelay = 0.3` and `TooltipCenter.defaultSkipWindowDelay`).
   - Updated `TooltipCenter` state machine:
     - First hover when no tooltip is active and outside the skip window waits the full `--delay-tooltip-hover` (`1s`).
     - When an already-displayed tooltip hides due to pointer exit (`hoverEnded`), records `lastHoverDismissedAt` to open a `300ms` skip window.
     - Entering a new tooltip target while a tooltip is currently displayed or within `300ms` of `lastHoverDismissedAt` skips the `1s` wait and reveals the new tooltip immediately.
     - Exiting before `1s` (before tooltip is displayed) does not open a skip window; waiting longer than `300ms` after `hoverEnded` expires the window; forced hiding (`hideImmediately` / `dismissFromUserInteraction` / `dismiss` via click, scroll, key press, or opening a menu/dialog) immediately clears `lastHoverDismissedAt` so the next hover restores the full `1s` wait.

## Verification

- Verified `TooltipTests` and `segmentedControlNeutralStylingAndGeometryTokensMatchSpecification` in `WorkbenchControlMetricsTests` (`swift test --package-path apps/macos-native --filter "TooltipTests|segmentedControlNeutralStylingAndGeometryTokensMatchSpecification|WorkbenchControlMetricsTests"`).
- All unit and hosting-view tests passed, matching requirement acceptance criteria.
