# UI Redesign Logic Connector Integration (Section 2.7)

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Section 2.7**: Logic Connector (`Where` static label, `And/Or` interactive dropdown, and subsequent rows' inherited static labels) redesign and alignment.
- Correcting styling/token mismatches for disabled states in interactive select components.

## Changes

- **`WorkbenchControls.swift`**:
  - Updated `WorkbenchSelectFieldLabel` to use `textDisabled`, `iconDisabled`, and `borderDisabled` when the component is disabled (`isEnabled` is false) under redesign.
- **`SchemaWorkbenchSearchShell.swift`**:
  - Added `@Environment(\.isEnabled)` tracking to `SchemaWorkbenchFilterRuleRow`.
  - Wrapped static logic connector labels (`Where` and inherited `And/Or`) in a height frame aligned with `WorkbenchControlMetrics.redesignFieldHeight` (40px) under redesign.
  - Implemented dynamic text color switching between `textPrimary` and `textDisabled` for static connector labels based on `isEnabled` state under redesign.
  - Aligned logic connector column horizontally by setting a unified width frame (`80px` under redesign, `58px` originally) for the first cell group of each filter builder row.

## Verification

- Compiled using `swift build` in `apps/macos-native`.
- Ran unit tests via `swift test` in `apps/macos-native`.
