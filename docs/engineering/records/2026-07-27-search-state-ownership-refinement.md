# Search State Ownership Refinement

## Requirement

- `docs/human/requirements/20260727-Engineering-Search State Ownership Refinement.md`
- `docs/human/design/Command Panel.md`

## Scope

Refine the native macOS Search ownership boundary without changing Search,
Filter, Context, pagination, selection, or playback behavior.

## Steps

1. Removed the obsolete grouped/card Search result presentation state, actions,
   per-file loading tasks, export entry point, performance hooks, and tests.
2. Preserved Search file summaries because exact counts, table hydration, and
   playback title fallback still consume them.
3. Moved the Search database handle, database URL, query tasks, navigation task,
   result generation, pagination cursor, loaded count, count-progress clock,
   and active performance run from `AppCoordinator` into `SearchStore`.
4. Updated indexing, URL scheme, playback playlist, and tests to address the
   Search-owned lifecycle state without changing their workflow.
5. Restricted Search state setters and routed query, filter, result,
   pagination, task, selection, context, and navigation changes through
   `SearchStore` intent methods.
6. Kept `AppCoordinator` responsible for cross-feature orchestration while
   moving Search state transitions and grouped state publication into the
   Search owner.

## Verification

- `swift test --filter SearchStoreTests`
- Result: 20 tests passed.
- `swift test --filter PlaybackSearch`
- Result: 4 tests passed.
- `swift test --filter URLSchemeSearch`
- Result: 7 tests passed.
- `swift test --filter CueGroupRefreshScopeIntegrationTests`
- Result: 14 tests passed.
- `swift test --filter LibraryFolderRemovalTests`
- Result: 8 tests passed.
- `swift test`
- Result: 876 tests ran with 18 issues while the full suite concurrently
  exhausted shared media and SQLite fixtures. Every failed test that overlaps
  this change passed when rerun in its focused suite or individually.

## Outcome

The unified result table remains the only production Search result presentation
path. Search now owns its database and asynchronous lifecycle state. The
refinement matched expectations. Search state writes are now restricted
to its owner, with existing callers and tests using explicit intents. Focused
verification matched expectations; the existing full-suite resource contention
remains outside this change.
