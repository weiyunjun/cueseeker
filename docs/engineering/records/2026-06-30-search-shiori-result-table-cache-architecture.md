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
- Kept the ID-only exact Search completion path available for callers without a
  progress sink: `limit: 0` still returns cue group IDs and file summaries
  without filling the normal page results.
- Changed Search exact completion in the app to request a zero-result exact
  completion page, preserving the existing first visible page while using the
  background pass only for exact count and summary metadata.
- Added the exact completion cue group ID list to `SubtitleSearchPage` and
  stored the current Search result IDs in `SearchStore`.
- Added renderable Search rows to exact progress snapshots and to the final
  exact completion page when a progress sink is supplied. The Search UI now
  grows its current result range from these renderable rows, so the rows label,
  scrollbar row range, and synchronously available rows advance together.
- Changed Search table range hydration to prefer the current Search ID slice and
  fetch display rows by cue group ID. Far-away rows no longer fall back to a
  slow offset scan while the exact ID list is not ready.
- Removed the Search-view display cache warmup task. Until the compact result
  store is implemented, the Search table only exposes rows that already have
  synchronous display models, keeping the table summary count, scrollbar row
  range, and renderable rows aligned.
- Removed `maximumHydratedSearchRows = 2000` and the Search/Shiori hydrated-row
  pruning paths from `TableSandboxRowModelStore`.
- Reduced table row store duplication by treating the contiguous loaded row
  prefix as the primary random-access store. `rowsBySourceIndex` and row
  references now only retain sparse hydrated rows, and Search action-result
  caching now stores only explicitly hydrated rows instead of duplicating every
  currently rendered Search result.
- Changed legacy Search result groups to summary-first storage. Group rebuilds
  no longer regroup and duplicate every current Search result; rows are retained
  in a group only after that specific group is explicitly expanded or loaded.
- Changed Shiori save/remove presentation refreshes so the table is invalidated
  without unconditionally loading every saved Shiori into the legacy card-list
  arrays. The legacy arrays are refreshed only if they were already loaded.
- Added a macOS malloc pressure-relief hook after large Search/table result
  releases. This does not replace data-structure reductions, but it gives the
  allocator a chance to return freed pages sooner after broad searches are
  cleared.
- Updated tests to assert the new no-cache semantics and retained hydrated rows.

## Verification

- `swift test` passed from `apps/macos-native` with 362 tests.

## Outcome

Search no longer keeps Core-level page or ID-index caches across searches. The
ID-only Core completion path can avoid normal page result materialization, while
the app-facing progress path currently materializes cumulative renderable Search
rows as an interim step to keep table row counts and available display data
strictly aligned. The compact display row store remains the follow-up memory
optimization.

Search exact completion now keeps the current result ID list in app state, and
table hydration can use that list for random-access display row loading. The
Search view no longer publishes non-renderable exact/progress counts to the
table, so the rows label and scrollbar only cover rows whose display data can be
returned synchronously.

The table row store no longer keeps parallel dictionaries and references for
every contiguous Search row. This removes one major multiplier from the
rendered-row memory footprint while preserving sparse hydration for table
actions and export.

Legacy Search result grouping now keeps file summary metadata without building
per-file result arrays for the whole current Search result set. This removes
another full-result-array multiplier from broad searches while preserving
explicit group expansion behavior.

Shiori mutation paths now keep the table-first paging model intact. Saving or
removing a Shiori invalidates the table page cache without forcing the old
card-list presentation to hydrate all saved Shioris when that legacy
presentation was not already resident.

Large Search reset paths now ask the system allocator to relieve memory pressure
after releasing result arrays and table rows. This is intended to improve the
observable post-clear memory drop in macOS Activity Monitor, while keeping the
call behind a row-count threshold so small interactions are unaffected.

The broader unified Search/Shiori result core remains a follow-up architecture
step from the human-owned requirement.
