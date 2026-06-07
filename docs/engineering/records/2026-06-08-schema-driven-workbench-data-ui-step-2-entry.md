# Schema-Driven Workbench Data UI Step 2 - Independent Entry

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers Step 2 of the schema-driven workbench data UI frontend plan:
adding an independent top-bar Test Search UI entry and routing it to a blank
page.

## Changes

- Added a distinct `WorkbenchTestPage.searchUI` case.
- Added a fourth top-bar test icon, placed to the right of Test Shiori, with
  the label `Test Search UI`.
- Routed the new test page to `SchemaWorkbenchPage`.
- Added `SchemaWorkbenchPage` as a blank alignment surface. It intentionally
  does not connect to Search, Library, Shiori, database, or real filter state.

## Verification

- `CUESEEKER_FFMPEG_ROOT=/opt/homebrew swift build --target CueSeekerApp`
  succeeded.

## Outcome

Step 2 is complete. The independent Test Search UI entry now routes to a blank
`SchemaWorkbenchPage`; the next step is to add the three-region layout skeleton.
