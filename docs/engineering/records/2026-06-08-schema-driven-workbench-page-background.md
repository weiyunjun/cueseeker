# Schema-Driven Workbench Data UI - Page Background Correction

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers the focused correction for the Search UI alignment test
screen page background.

## Changes

- Removed the hard-coded `SchemaWorkbenchStyle.pageBackground` color.
- Removed the root background layer from `SchemaWorkbenchPage`.
- Let the screen inherit the existing test workbench/content background instead
  of introducing a separate canvas color.

## Verification

- `swift build --product CueSeeker` succeeded.
- `git diff --check` succeeded.

## Outcome

The Search UI alignment test screen no longer invents a standalone page
background color that differs from the design reference and existing app
surfaces.
