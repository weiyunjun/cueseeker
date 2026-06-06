# Table View Rendering Virtualization Performance - Step 4

Date: 2026-06-06

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Step 4 separates the table's virtual row count from the loaded row models in
the test Search and Shiori table views.

## Implementation

- Added snapshot row lookup by index so loaded row models can be supplied on
  demand.
- Changed `SubtitleTableView` to use a virtual `rowCount` plus a `rowProvider`
  closure instead of owning a full row array.
- Kept unloaded virtual rows renderable with estimated height and empty text,
  while preserving the visible index column.
- Changed the row-height cache to sparse index storage so measuring a high row
  index does not allocate intermediate cache slots.
- Added focused tests for virtual row counts and sparse row-height caching.

## Verification

- Passed: `swift test --filter SubtitleTableVirtualRow`
- Passed: `swift test --filter SubtitleTableRowHeightCache`
- Passed: `swift test`

## Outcome

Step 4 passed focused and full verification. The test table now exposes virtual
row counts separately from loaded row models, and row-height caching no longer
allocates dense intermediate slots for high row indexes.
