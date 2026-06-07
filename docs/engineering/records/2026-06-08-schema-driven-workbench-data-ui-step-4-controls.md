# Schema-Driven Workbench Data UI Step 4 - Shared Workbench Controls

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers Step 4 of the schema-driven workbench data UI frontend plan:
extracting reusable static visual controls for the Test Search UI alignment
screen.

## Changes

- Added `Shared/WorkbenchControls/WorkbenchControls.swift`.
- Added shared visual metrics and colors for workbench controls.
- Added reusable visual controls:
  - `WorkbenchSearchField`
  - `WorkbenchToolbarButton`
  - `WorkbenchFilterChip`
  - `WorkbenchBadge`
  - `WorkbenchPopoverRow`
  - `WorkbenchIconButton`
  - `WorkbenchControlBackground`
- Updated `SchemaWorkbenchPage` to use the shared search field, toolbar button,
  and active filter chip instead of page-local helper views.

## Verification

- `CUESEEKER_FFMPEG_ROOT=/opt/homebrew swift build --target CueSeekerApp`
  succeeded.

## Outcome

Step 4 is complete. The Test Search UI skeleton now uses reusable workbench
controls for its search field, toolbar buttons, and active filter chip; badge,
popover row, and icon-button controls are ready for the upcoming overlay and
table-rendering steps.
