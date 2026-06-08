# Schema-Driven Workbench Data UI - Component Structure Fixes

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers the focused component-structure fixes requested for the
Test Search UI alignment screen.

The change intentionally does not address table column width, scrollbar
visibility, or broader visual alignment issues.

## Changes

- Reused `WorkbenchPlainActionButton` for both `New Filter Set` and
  `New Filter`.
- Added a general `WorkbenchButton` and used it for the ordinary
  `Save Filter Set` action.
- Added `WorkbenchReadonlyField` and used it for the `No value needed` value
  state.
- Updated toolbar buttons and active filter chips to keep text on one line and
  size to content instead of relying on narrow fixed frames.
- Split dropdowns into a reusable trigger (`WorkbenchInlineDropdown`) and a
  reusable panel (`WorkbenchDropdownPanel`).
- Moved Filter Builder dropdown open state and panel rendering to the
  Filter Builder layer so dropdowns no longer create their own nested overlay
  layers inside each field.
- Removed the unused `WorkbenchSelectField` component; its visual label remains
  as `WorkbenchSelectFieldLabel` for dropdown triggers.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- `swift build --product CueSeeker` succeeded.

## Outcome

The six requested component structure issues are addressed first, before any
follow-up visual alignment work.
