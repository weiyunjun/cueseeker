# Schema-Driven Workbench Data UI Step 6 - Table First Pass

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Planning document:

- `docs/proposals/2026-06-schema-driven-workbench-data-ui-frontend-plan.md`

## Scope

This record covers Step 6 of the schema-driven workbench data UI frontend plan:
rendering the Test Search UI table from a schema and fake rows.

## Changes

- Added `Shared/WorkbenchTable/WorkbenchDataTable.swift`.
- Added table schema models:
  - `WorkbenchTableColumn`
  - `WorkbenchTableColumnKind`
  - `WorkbenchTableColumnWidth`
  - `WorkbenchTableRow`
  - `WorkbenchTableCellValue`
  - `WorkbenchMultiSelectOption`
  - `WorkbenchBadgeStyle`
- Added first-pass cell renderers for:
  - row number
  - text
  - multi-select badge lists
- Updated `SchemaWorkbenchPage` to provide fake Search UI columns and rows.
- Replaced the placeholder table skeleton with schema-driven fake row rendering.
- Kept View menu column hiding, real filtering, real database access, editable
  cells, and row hover actions out of this step.

## Verification

- `swift build --target CueSeekerApp` succeeded without `CUESEEKER_FFMPEG_ROOT`.
- `swift build --product CueSeeker` succeeded without `CUESEEKER_FFMPEG_ROOT`.

## Outcome

Step 6 is complete. The Test Search UI table now renders five reference columns
from schema data. `Cues` renders through the text renderer with natural wrapping,
and `Language` renders through a reusable multi-select badge renderer.
