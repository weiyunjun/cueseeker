# UI Redesign Inline Add Button Integration (Section 2.9)

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Section 2.9**: Inline Add Button (`WorkbenchPlainActionButton`) redesign alignment. Height adjusted to 40px, corner radius to 8px, horizontal padding to 16px, icon font size to 16px (medium weight for `plus`), spacing to 12px, background default/disabled transparent, hover background to `--color-bg-hover`, and icon/text color tokens using `textPrimary`/`textDisabled`.

## Changes

- **`WorkbenchControls.swift`**:
  - Updated `WorkbenchPlainActionButton` in redesign mode to use `12px` (`--spacing-3` token gap constraint) spacing inside the HStack.
  - Aligned redesign icon font size to `16` and weight to `.medium` for systemImage `"plus"`.
  - Updated icon foregroundStyle to use `textPrimary`/`textDisabled` to match the text color.

## Verification

- Compiled using `swift build` in `apps/macos-native`.
- Ran unit tests via `swift test` in `apps/macos-native`.
