# UI Redesign Filter Panel Trigger Button Detail (Filter Count) Display

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the fix for Component 2.3 (Filter Panel Trigger Button) where the filter count (e.g. "1 Filter", "3 Filters") was not displayed when a specific filter set was active, unlike in the legacy implementation.

## Changes

- Modified `WorkbenchFilterPanelTriggerButton` in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to accept an optional `detail: String? = nil` parameter and render it with semibold weight next to the title text.
- Updated the callsite of `WorkbenchFilterPanelTriggerButton` in `SchemaWorkbenchFilterControlBar` inside [SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) to pass the filter count text as `detail` when `activeFilterSetName` is not nil.

## Verification

- Verified the build compiles successfully with `swift build`.
- Ran unit tests via `swift test` and confirmed all tests pass.
