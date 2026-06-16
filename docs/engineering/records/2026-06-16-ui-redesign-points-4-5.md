# UI Redesign Points 4 & 5 Integration

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Point 4**: Self-adaptive width for non-input controls (Filter Trigger, Select Trigger, Form Select Field, logic connect dropdowns, buttons, and popover row menu items) under redesign to prevent text truncation.
- **Point 5**: Dynamically anchoring all Select Menu / Dropdown popup panels and Filter Builder Popovers to their respective trigger controls (maxY + 4 offset, minX left-aligned) using geometry preference keys instead of absolute coordinate hand-calculations.
- Subsequent alignment bug fixes for popover padding, radius, row item spacing, and outer popover containers.

## Changes

- **`WorkbenchControls.swift`**:
  - Refactored `WorkbenchPopoverRow` (Menu Item Base / Select / Action Menu Item) to use `12px` (`--spacing-3` token gap constraint) horizontal spacing under redesign.
  - Refactored `WorkbenchPopoverPanel` under redesign to use `16px` corner radius (`--radius-menu`) and `4px` padding (`--spacing-1`).
  - Added redesign support to `WorkbenchButton` and `WorkbenchPlainActionButton` to ensure they use self-adaptive width (`.fixedSize`) and redesign height/corner radius/colors.
  - Reverted experimental redesign changes to `WorkbenchTextInputField` and `WorkbenchReadonlyField` to keep them clean for their separate component review.
- **`SchemaWorkbenchSearchShell.swift`**:
  - Removed hardcoded width frames (`110` and `150`) on the filter rule fields when `isRedesign` is true.
  - Removed fixed width constraint (`58`) on the logic connector when `isRedesign` is true to allow self-adaptive sizing of the interactive dropdown.
  - Anchored `SchemaWorkbenchColumnVisibilityPopover`, `SchemaWorkbenchFilterSetPopover`, `SchemaWorkbenchFilterBuilderPopover`, and the inline rule row dropdown panels dynamically below their triggers using geometry preferences.
  - Passed `isRedesign` to the outer `WorkbenchPopoverPanel` inside `SchemaWorkbenchFilterBuilderPopover` to align its corner radius (16px) and padding (4px) with the design token.
  - Propagated `isRedesign` to visibility popover, filter sets popover, and dropdown panels.

## Verification

- Verified the build compiles successfully with `swift build`.
- Ran unit tests via `swift test` and confirmed all 270 tests pass.
