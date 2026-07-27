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
3. Moved query execution, task creation, database access, generation checks,
   visible-page publication, exact completion, and count progress into
   `SearchStore`.
4. Moved Filter-only and Context table pagination tasks, generations, loaded
   ranges, totals, and duplicate-request rejection into `SearchStore`.
5. Replaced independently published result fields with one atomic result
   mutation boundary and one `resultRevision` notification after the complete
   state has been assigned.
6. Reduced `AppCoordinator` Search execution to cross-feature input snapshots
   and callbacks for playback and URL-scheme coordination.
7. Reduced `WorkbenchTestSearchView` to UI state and Search intent calls; it no
   longer creates or validates Filter/Context pagination tasks.
8. Updated indexing, playback, URL scheme, table, and tests to consume the
   Search-owned lifecycle and atomic result notification.

## Verification

- `swift test --filter SearchStoreTests`
- Result: 22 tests passed.
- `swift test --filter PlaybackSearch`
- Result: 4 tests passed.
- `swift test --filter URLSchemeSearch`
- Result: 7 tests passed.
- `swift test --filter CueGroupRefreshScopeIntegrationTests`
- Result: 14 tests passed.
- `swift test --filter LibraryFolderRemovalTests`
- Result: 8 tests passed.
- `swift test --filter PlaybackSubtitleFocusKeyboardActionTests`
- Result: 21 tests passed.
- `swift test --filter PlaybackPlaylistSourceTests`
- Result: 9 tests passed.
- `swift test`
- Result: 878 tests ran with 14 issues while the full suite concurrently
  exhausted shared media and SQLite resources or exceeded UI/media timing
  thresholds. Every failed test that overlaps this change passed when rerun in
  its focused suite or individually.

## Outcome

The unified result table remains the only production Search result presentation
path. `SearchStore` now owns query execution, result consistency, and
Filter/Context pagination lifecycle. `AppCoordinator` retains cross-feature
coordination, while the View retains UI-only state. Focused verification passed;
the existing full-suite resource contention remains outside this change.
