# UI Redesign Inline Add Button Integration (Section 2.9)

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Section 2.9**: Inline Add Button (`WorkbenchPlainActionButton`) redesign alignment. Height adjusted to 40px, corner radius to 8px, horizontal padding to 16px, icon font size to 20px, spacing to 12px, background default/disabled transparent, hover background to `--color-bg-hover`, and color tokens for disabled states aligned with specs.

## Changes

- **`WorkbenchControls.swift`**:
  - Updated `WorkbenchPlainActionButton` in redesign mode to use `12px` (`--spacing-3` token gap constraint) spacing inside the HStack.
  - Aligned redesign icon size to `redesignControlIconSize` (20px) for systemImage font size.
  - Updated text color and icon color to use `textDisabled` and `iconDisabled` when `isEnabled` is false under redesign.

## Verification

- Compiled using `swift build` in `apps/macos-native`.
- Ran unit tests via `swift test` in `apps/macos-native`.
