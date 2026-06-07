# Schema-Driven Workbench Data UI Step 5 - Overlay Popovers

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers Step 5 of the schema-driven workbench data UI frontend plan:
adding overlay/popover state for the Test Search UI alignment screen.

## Changes

- Added page-level popover state to `SchemaWorkbenchPage`.
- Added a sibling `overlayLayer` above the three-region page layout so popovers
  do not become a fourth main layout region.
- Added static overlay views for:
  - `ColumnVisibilityPopover`
  - `FilterSetPopover`
  - `FilterBuilderPopover`
- Wired the View button, Filter Sets button, and active filter chip to open one
  popover at a time.
- Added optional action support to shared workbench controls so future
  interactions can reuse the same visual controls instead of wrapping them in
  ad hoc gesture layers.
- Added `WorkbenchSelectField` for field/operator dropdown affordances in the
  Filter Builder popover.
- Kept column hiding, real filter state, nested dropdowns, and query behavior
  out of this step.

## Verification

- `CUESEEKER_FFMPEG_ROOT=/opt/homebrew swift build --target CueSeekerApp`
  succeeded.
- Code inspection confirmed the main page still consists of
  `SearchCommandBar`, `FilterControlBar`, and `WorkbenchDataTable`; the
  popovers are rendered from a sibling overlay layer in the top-level `ZStack`.

## Outcome

Step 5 is complete. The Test Search UI page now has static overlay popovers for
View, Filter Sets, and Filter Builder without changing the main three-region
layout.
