# UI Redesign Search Box Step 1

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation of Component 2.1 (Search Box) and Component 2.2 (Inline Clear Button) of the UI Redesign, including subsequent fixes for P1 (clear icon size reverted to 11pt to match visual calibration), P2 (button disabled state), and P3 (popover positioning offset under redesign).

## Changes

- Added `Color(hex:)` initializer to `Color` in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to support Hex Color definitions.
- Created `WorkbenchInlineClearButton` in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to provide the 32px clear button styling, background hovers, and focus rings.
- Updated `WorkbenchSearchField` in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to support `isRedesign` with custom 48px height, 9999px capsule corner radius, colors, focus borders, focus rings, and conditional placement of the clear button.
- Replaced the custom ZStack-based placeholder overlay with SwiftUI's native `prompt` parameter on `TextField` in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to ensure that the placeholder text is immediately hidden during IME (Chinese input method) composition.
- Modified `WorkbenchInlineClearButton` in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to size the SF symbol to `11pt` (P1) matching the macOS mapping token `--size-inline-clear-symbol-font-size-macos: 11pt`, and added the `.disabled(!isEnabled)` modifier to disable actions natively when disabled (P2).
- Converted static `viewPopoverTop` and `filterPopoverTop` constants in `SchemaWorkbenchStyle` within [SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) into dynamic functions that check the `isRedesign` state, ensuring popovers position correctly at 48px offset under redesign (P3).
- Updated `SchemaWorkbenchSearchShell` and `SchemaWorkbenchSearchCommandBar` in [SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) to accept and pass through `isRedesign: Bool`.
- Activated `isRedesign: true` in `WorkbenchTestSearch2View` in [WorkbenchTestSearch2View.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearch2View.swift) to apply the redesign styling.

## Verification

- Compiled application successfully via `swift build --product CueSeeker`.
- All 270 unit tests executed successfully via `swift test --jobs 1 --quiet`.

## Outcome

- The Search Box in `Test Search 2` now renders with capsule corners, custom height (48px), dynamic hover/disabled/focused background/border colors, focus rings, and an inline clear button matching the UI requirements.
- The placeholder text correctly disappears as soon as the user starts typing any character via IME (such as Chinese input method), resolving the overlap bug.
- Popovers align dynamically at the correct height offsets without 2px offset discrepancies.
