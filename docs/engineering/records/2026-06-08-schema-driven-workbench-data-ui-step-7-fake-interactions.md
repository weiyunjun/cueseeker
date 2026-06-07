# Schema-Driven Workbench Data UI Step 7 - Fake Interactions

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers Step 7 of the schema-driven workbench data UI frontend plan:
wiring fake interaction state for the Test Search UI alignment screen.

## Changes

- Added fake page state for:
  - search draft text
  - visible column IDs
  - active filter set ID
  - draft filter rules
- Updated the View menu so toggling a column immediately updates the rendered
  table headers and body cells.
- Updated the Filter Sets menu so choosing a fake preset updates the active chip
  and draft rules.
- Updated Reset so it returns the filter bar to the no-filter state.
- Updated the Filter Builder popover so field, operator, join, value, add, and
  delete controls mutate fake draft rules.
- Kept the Filter Builder field menu sourced from all table columns, not only
  visible columns.
- Added reusable shared control support for bound search input, select labels,
  and text input fields.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- `swift build --product CueSeeker` succeeded.

## Outcome

Step 7 is complete. The UI alignment screen now has working fake interactions
for column visibility, filter set selection, reset, and filter-builder draft
editing without connecting to real search, persistence, or database filtering.
