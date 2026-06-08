# Schema-Driven Workbench Data UI - Table Layout Fixes

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers the focused table layout correction requested during Search
UI alignment review.

## Changes

- Removed the weighted table column width model that had been added in the
  wrong direction for the previous visual issue.
- Replaced weighted column resolution with fixed and evenly flexible column
  resolution.
- Resolved one shared table layout object for the header and all body rows.
- Ensured the table content frame is at least as wide as the table container, so
  fixed-only visible column sets stay left-aligned instead of being centered.
- Updated the Search UI alignment table so `Cues` absorbs remaining width while
  `Language` and `Speaker` remain fixed metadata columns.

## Verification

- `swift build --product CueSeeker` succeeded.

## Outcome

The table no longer depends on weighted column sizing, and visible columns now
share a single left-anchored header/body layout contract for validation.
