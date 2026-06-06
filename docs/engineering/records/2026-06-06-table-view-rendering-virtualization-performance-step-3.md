# Table View Rendering Virtualization Performance - Step 3

Date: 2026-06-06

Human-owned requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Separate loaded test Search/Shiori result references from the virtual total row
count so the table direction no longer requires all search pages to be loaded
before rendering.

## Implementation

- Added lightweight `TableSandboxRowReference` values to the table sandbox
  snapshot.
- Added `totalRowCount` and `loadedReferenceCount` to the snapshot.
- Passed Search's known total count into the row model store.
- Removed the test Search page behavior that automatically loaded all remaining
  global search pages.

## Verification

- Added test data with 100 loaded search results and a virtual total of
  2,000,000 results.
- Verified that only 100 references/rows are materialized while the snapshot
  still tracks the 2,000,000-row total.

## Outcome

The test Search page no longer treats the loaded page array as the full search
result universe. Later steps still need to make the AppKit table consume
`totalRowCount` directly and hydrate only visible rows.
