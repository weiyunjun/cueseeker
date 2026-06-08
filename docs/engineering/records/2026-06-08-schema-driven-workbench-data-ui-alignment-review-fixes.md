# Schema-Driven Workbench Data UI - Alignment Review Fixes

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers the focused UI-alignment fixes requested after the internal
review of the Test Search UI implementation.

The change intentionally excludes:

- changing the default number of filter builder rules
- changing overall control density or global sizing

## Changes

- Replaced Filter Builder native SwiftUI menus with reusable custom workbench
  dropdowns that render as in-app popover panels.
- Added reusable popover row hover and highlighted selected-row backgrounds.
- Added a reusable plain action button and used it for the no-filter
  `New Filter Set` action.
- Removed the extra top-right close button from the Filter Builder panel.
- Updated text operator options to match the reference set:
  `contains`, `does not contain`, `is`, `is not`, `is empty`,
  and `is not empty`.
- Reworked table column width calculation so Cues no longer consumes all
  remaining width and pushes Language/Speaker too far right.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- `swift build --product CueSeeker` succeeded.

## Outcome

The six requested structural UI mismatches are fixed without changing the
excluded default filter count behavior or overall density settings.
