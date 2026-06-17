# UI Redesign Neutral Button Integration (Section 2.8)

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Section 2.8**: Neutral Button (`WorkbenchButton`) redesign alignment. Height adjusted to 40px, corner radius to 8px, horizontal padding to 16px, icon font size to 20px, spacing to 12px, font size to 16px, and color tokens for disabled states aligned with specs.

## Changes

- **`WorkbenchControls.swift`**:
  - Updated `WorkbenchButton` in redesign mode to use `12px` (`--spacing-3` token gap constraint) spacing inside the HStack.
  - Aligned redesign icon size to `redesignControlIconSize` (20px) for systemImage font size.
  - Updated text color, icon color, and border color to use `textDisabled`, `iconDisabled`, and `borderDisabled` when `isEnabled` is false under redesign.

## Verification

- Compiled using `swift build` in `apps/macos-native`.
- Ran unit tests via `swift test` in `apps/macos-native`.
