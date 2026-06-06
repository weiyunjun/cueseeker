# Table View Rendering Virtualization Performance - Step 5

Date: 2026-06-06

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Step 5 hydrates visible Search test-table rows on demand after fast scrolling
and cancels stale visible-range requests.

## Implementation

- Added sparse Search row hydration to the table sandbox row model store.
- Added a visible Search hydrator that expands the visible row range with
  overscan, skips already loaded rows, debounces fast scroll changes, and
  cancels stale requests.
- Added a test-table-only AppCoordinator query path that fetches rows directly
  by `SubtitleSearchCursor(offset:)` without mutating the production Search
  result array.
- Wired `SubtitleTableView` to report visible row ranges and connected the
  Search test page to hydrate missing visible rows.

## Verification

- Passed: `swift test --filter TableSandboxRowModelStore`
- Passed: `swift test --filter TableSandboxVisibleSearchHydrator`
- Passed: `swift test --filter SubtitleTableVirtualRow`
- Passed: `swift test`

## Outcome

Step 5 passed focused and full verification. Fast visible-range changes now
hydrate only missing Search test-table rows by offset, and stale visible-range
requests are cancelled before applying.
