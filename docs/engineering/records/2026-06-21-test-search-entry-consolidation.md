# Test Search Entry Consolidation

## Human-Owned Source

- `docs/human/requirements/20260621-Feature-Test Search Test Entry.md`

## Scope

Consolidate the top-bar test entries by removing the old Test Search, Test
Shiori, and static Test Search UI routes, then expose the current schema-driven
search table route as Test Search.

Test Library remains available as a separate placeholder for future Library UI
work because the human-owned requirement does not ask to remove it.

## Implementation Steps

1. Removed the old Test Search, Test Shiori, and Test Search UI buttons from the
   top-bar test entry group.
2. Renamed the current search-table test entry to Test Search.
3. Reduced `WorkbenchTestPage` to the remaining Library and Search test routes.
4. Routed the Search test page to the existing schema-driven search table view,
   renamed from `WorkbenchTestSearch2View` to `WorkbenchTestSearchView`.
5. Removed the old standalone `SchemaWorkbenchPage` fake-data route.

## Verification

- `swift test` passed.

## Outcome

The requested entry consolidation is implemented. The test bar now retains Test
Library and exposes the current schema-driven search table as Test Search.
