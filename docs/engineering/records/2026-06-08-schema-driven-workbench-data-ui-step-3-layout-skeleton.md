# Schema-Driven Workbench Data UI Step 3 - Layout Skeleton

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers Step 3 of the schema-driven workbench data UI frontend plan:
adding the three-region main layout skeleton for the independent Test Search UI
page.

## Changes

- Replaced the blank `SchemaWorkbenchPage` with a three-region layout:
  `SearchCommandBar`, `FilterControlBar`, and `WorkbenchDataTable`.
- Added static first-pass visual placeholders for the search row, filter row,
  and table container.
- Kept menus, dropdowns, and the filter builder out of the main layout. No
  overlay or popover state is introduced in this step.
- Left fake rows, schema-driven column state, menu interaction, and filter
  builder interaction for later steps.

## Verification

- `CUESEEKER_FFMPEG_ROOT=/opt/homebrew swift build --target CueSeekerApp`
  succeeded.

## Outcome

Step 3 is complete. The Test Search UI page now has the three main layout
regions required for the next shared-control implementation step.
