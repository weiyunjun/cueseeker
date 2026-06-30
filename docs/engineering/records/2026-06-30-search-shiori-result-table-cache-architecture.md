# Search Shiori Result Table Cache Architecture

## Human-Owned Source

- `docs/human/requirements/20260630-Feature-Search Shiori Unified Result Table Architecture.md`

## Scope

Reduce Search table memory accumulation and remove the hydrated-row availability
cap that could make virtualized table rows unavailable after broad scrolling.

## Changes

- Disabled Core Search result caching by removing the page cache and ID-index
  cache storage paths. `clearSearchResultCache()` remains a compatibility no-op,
  and `searchResultCacheStats()` now reports zero cached entries and activity.
- Changed exact Search completion so it no longer materializes every matching
  `SubtitleSearchResult`. Exact search now accumulates all matching cue group
  IDs and file summaries, while only materializing the requested result page.
- Changed Search exact completion in the app to request a zero-result exact
  completion page, preserving the existing first visible page while using the
  background pass only for exact count and summary metadata.
- Changed Search table range hydration to query the requested visible range
  directly instead of depending on a cached result ID index.
- Removed `maximumHydratedSearchRows = 2000` and the Search/Shiori hydrated-row
  pruning paths from `TableSandboxRowModelStore`.
- Updated tests to assert the new no-cache semantics and retained hydrated rows.

## Verification

- `swift test` passed from `apps/macos-native` with 357 tests.

## Outcome

Search no longer keeps Core-level page or ID-index caches across searches, and
exact completion no longer builds a full in-memory `SubtitleSearchResult` array
for every match. The table row model store now treats hydrated Search/Shiori rows
as available data for the current result set instead of pruning them around a
fixed 2,000-row budget.

The broader unified Search/Shiori result core remains a follow-up architecture
step from the human-owned requirement.
