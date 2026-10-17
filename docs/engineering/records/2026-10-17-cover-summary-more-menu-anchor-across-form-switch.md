# Implementation Record: Cover Summary More Menu Anchor Across Form Transitions

- **Requirement**: `docs/human/requirements/20261017-UI-Cover Summary Content Progress And Actions Redesign.md`
- **Date**: 2026-10-17

## Summary of Changes

1. **Single-Container Anchor Mounting (`CoverSummaryCard.swift`)**:
   - Replaced `Group` with `ZStack` in `CoverSummaryCard.moreMenuButton(action:for:)` so `.background { MenuAnchorProbe(handle: moreMenuAnchor) }` is mounted once outside the `.split` / `.backdrop` switch instead of being duplicated across both conditional branches.

2. **Window Lifecycle Guard (`MenuAnchorProbe.swift`)**:
   - Updated `MenuAnchorProbe` and `ProbeView` so `handle.view` is only overwritten in `makeNSView` / `updateNSView` when the probe view is attached to a window (or when `handle.view` currently has no window), and synchronized `handle.view` in `ProbeView.viewDidMoveToWindow()`.

3. **Regression Test (`CoverSummaryCardTests.swift`)**:
   - Added `coverSummaryMoreMenuAnchorStaysAttachedAcrossFormTransitions` verifying that resizing a hosted `CoverSummaryCard` from Split (`800px`) to Backdrop (`560px`) and back to Split (`800px`) preserves a valid `36×36` `windowFrame` on `moreMenuAnchor`.

## Verification

- Automated unit & UI host tests (`swift test --package-path apps/macos-native --filter coverSummary`):
  - All `CoverSummaryCardTests` (including `coverSummaryMoreMenuAnchorStaysAttachedAcrossFormTransitions`) passed.
