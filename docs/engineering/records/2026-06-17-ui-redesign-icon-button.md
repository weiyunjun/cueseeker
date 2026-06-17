# UI Redesign Icon Button Integration (Section 2.10)

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Section 2.10**: Icon Button (`WorkbenchIconButton`) redesign alignment. Button size aligned to 40x40px, border radius to 8px, background default/disabled transparent, hover background to `--color-bg-hover`, no borders, focus ring enabled, icon size to 20px, icon colors mapped to `iconDefault`/`iconDisabled`, and interactive mouse cursors (`pointingHand` when enabled, `operationNotAllowed` when disabled) implemented.

## Changes

- **`WorkbenchControls.swift`**:
  - Added `import AppKit` to support Cocoa mouse cursor modifications.
  - Added `redesignIconButtonSize` (40px) to `WorkbenchControlMetrics` to map `--size-icon-button`.
  - Refactored `WorkbenchIconButton` body with `.onHover` to dynamically push/pop `NSCursor.pointingHand` (when enabled) and `NSCursor.operationNotAllowed` (when disabled) in redesign mode.
  - Aligned redesign icon font size to `redesignControlIconSize` (20px).
  - Aligned button frame width and height to `redesignIconButtonSize` (40px).
  - Updated disabled icon color to use `iconDisabled` instead of `iconMuted`.

## Verification

- Compiled using `swift build` in `apps/macos-native`.
- Ran unit tests via `swift test` in `apps/macos-native`.
