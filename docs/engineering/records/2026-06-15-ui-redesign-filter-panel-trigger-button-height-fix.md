# UI Redesign Filter Panel Trigger Button Height and Popover Offset Fix

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the fix for Component 2.3 (Filter Panel Trigger Button) where the parent filter bar height was restricted to 40px while the child button height was set to 48px, leading to visual compression and popover offset misalignment.

## Changes

- Modified `SchemaWorkbenchFilterControlBar` in [SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) to dynamically set its height to `48px` if `isRedesign` is true (instead of hardcoding to 40px via `WorkbenchControlMetrics.controlHeight`).
- Updated `SchemaWorkbenchStyle.filterPopoverTop` in [SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) to dynamically calculate the top offset using `48px` when `isRedesign` is true, ensuring the filter popover positions correctly.

## Verification

- Verified the build compiles successfully with `swift build`.
- Ran unit tests via `swift test` and confirmed all 270 tests pass.
