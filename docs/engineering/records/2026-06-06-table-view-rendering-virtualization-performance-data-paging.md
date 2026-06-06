# Table View Rendering Virtualization Performance - Data Paging

Date: 2026-06-06

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Complete the test Search table virtualization path beyond the renderer rebuild.
This change adds sparse Search result paging, viewport-priority hydration,
adjacent-page prefetch, and eager completion for small result sets.

## Goals

- Keep first-screen Search loading fast by using the initially loaded result
  page without waiting for all results.
- Avoid blank unloaded regions for small result sets by hydrating remaining
  pages in the background.
- Load the current viewport immediately when the user scrolls or drags the
  scrollbar to unloaded rows.
- Keep old scroll requests valid for the same query instead of cancelling every
  previous request on each scroll event.
- Preserve authoritative `totalRowCount` and keep original `SubtitleSearchResult`
  data available for hydrated rows.

## Implementation

- Replaced the single debounced visible-row hydration task with page-based
  request scheduling.
- Added current-viewport priority loading with adjacent-page prefetch.
- Added eager background completion for result sets up to 2,000 rows.
- Added generation reset for Search query and total-count changes.
- Stored hydrated `SubtitleSearchResult` values in the table sandbox row store
  so row actions can use rows loaded outside the production Search first page.

## Verification

- Passed: `swift test --filter TableSandboxVisibleSearchHydrator`
- Passed: `swift test --filter TableSandboxRowModelStore`
- Passed: `swift test`

## Outcome

Focused verification and full test verification passed.
