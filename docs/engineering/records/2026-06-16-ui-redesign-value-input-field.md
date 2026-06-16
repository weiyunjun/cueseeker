# UI Redesign Value Input Field Integration (Section 2.6)

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Section 2.6**: Value Input Field (`WorkbenchTextInputField` and `WorkbenchReadonlyField`) redesign. Height adjusted to 40px, corner radius to 8px, horizontal padding to 16px, and color tokens for backgrounds, borders, focus rings, and text aligned with Light/Dark mode specifications.

## Changes

- **`WorkbenchControls.swift`**:
  - Added `isRedesign: Bool = false` to `WorkbenchTextInputField` and `WorkbenchReadonlyField`.
  - Implemented `@FocusState` and `@Environment(\.isEnabled)` tracking inside `WorkbenchTextInputField`.
  - Implemented redesign-specific container sizes, fonts, dynamic color mapping, borders, and focus rings for `WorkbenchTextInputField` when `isRedesign` is true.
  - Implemented redesign-specific container sizes, fonts, dynamic color mapping, and borders for `WorkbenchReadonlyField` when `isRedesign` is true.
  - Added prompt customization to `WorkbenchTextInputField` based on Codex review findings: explicitly specified font size on prompt, and dynamically switched foreground color between `textPlaceholder` and `textDisabled` based on whether the input field is enabled.
- **`SchemaWorkbenchSearchShell.swift`**:
  - Propagated `isRedesign: isRedesign` to `WorkbenchTextInputField` and `WorkbenchReadonlyField` inside the `valueInput` builder logic.

## Verification

- Compiled using `swift build` in `apps/macos-native`.
- Ran unit tests via `swift test` in `apps/macos-native`.
