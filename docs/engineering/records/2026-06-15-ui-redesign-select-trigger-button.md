# UI Redesign Select Trigger Button (Component 2.4) Integration

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of Component 2.4 (Select Trigger Button) of the UI Redesign. It updates the toolbar view/filter sets buttons to support redesign style specifications, keyboard navigation, and the double-chevron indicator using dedicated constants.

## Changes

- **`WorkbenchControlMetrics`**: Added Select Indicator specific constants:
  - `redesignSelectIndicatorSize: CGFloat = 20` (slot size bounds)
  - `redesignSelectIndicatorSymbolFontSizeMacOS: CGFloat = 10` (custom visual font size for double chevrons)
  - `redesignSelectIndicatorWeightMacOS: Font.Weight = .medium` (font weight configuration to avoid layout overlay bleed)
- **`WorkbenchToolbarButton`**: Refactored in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to support `isRedesign`:
  - Dynamically binds sizes, colors, margins, and borders to redesign constants when `isRedesign` is true.
  - Implements `.disableFocusEffect()` on the native SwiftUI Button and renders a custom 11px corner focus rectangle overlay matching `--color-focus-ring` (opacity 22%) and `--focus-ring-width: 3px`.
  - Swaps the standard single chevron dropdown image with the double-chevron `"chevron.up.chevron.down"` inside a 20x20 slot using the custom metrics to prevent visual overlapping.
- **Layout Callsites**: Modified [SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) to pass `isRedesign: isRedesign` to View, Filter Sets, and Reset toolbar button instances.

## Verification

- Verified the build compiles successfully with `swift build`.
- Ran unit tests via `swift test` and confirmed all 270 tests pass.
