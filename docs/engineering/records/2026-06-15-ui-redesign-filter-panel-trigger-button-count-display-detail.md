# UI Redesign Filter Panel Trigger Button Dot Separator and Pluralization

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation of the middle dot (`·`) separator between the filter set name and the filter count, and the proper singular/plural formatting ("1 Filter" vs "N Filters") on the filter bar trigger button.

## Changes

- Modified `WorkbenchFilterPanelTriggerButton` in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to combine title and detail text with a middle dot (`·`) separator via SwiftUI `Text` concatenation (`Text(title) + Text(" · ") + Text(detail)`). This ensures strict spacing matching the redesign mockups.
- Updated `SchemaWorkbenchFilterControlBar` in [SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) to dynamically calculate `filterCountText` as either `"1 Filter"` or `"\(filterCount) Filters"` based on the filter count, passing it down to both redesigned and legacy filter components.

## Verification

- Verified the build compiles successfully with `swift build`.
- Ran unit tests via `swift test` and confirmed all tests pass.
