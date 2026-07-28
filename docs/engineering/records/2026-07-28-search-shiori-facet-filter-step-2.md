# Search And Shiori Facet Filter Step 2

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Build the index-maintained distribution cache required by the empty Search
state without changing Search or Shiori UI.

## Classification

- Product semantics and persistence: implemented in `CueSeekerCore`.
- Platform UI/UX: unchanged.
- Platform integration: unchanged.
- Playback execution: unchanged.

## Implementation

- Added one `cue_facet_counts` table in schema 40; the schema 39 migration
  backfills it from existing indexed content.
- Derived Duration from indexed Cue timestamps, Character from SQLite's stored
  Cue content length, Language from indexed file/style detections with Unknown
  fallback, and Watch Status from explicit watch state with missing state
  treated as Unwatched.
- Rebuilt the four distributions in the same transaction as index add, update,
  removal, reconciliation, and binding publication paths.
- Rebuilt only Watch Status when the effective explicit watch state changes;
  repeated writes of the same state do not touch the cache.
- Added a read-only Search API that reads only the aggregate table. Current
  schema startup does not rebuild or scan indexed Cue rows.
- Kept the implementation to one aggregate table and one cache implementation;
  no per-Cue classification table, trigger, or general cache framework was
  added.

## Verification

- `swift test --filter CueFacet` passed all 9 filter and cache tests, covering
  range boundaries, multilingual membership, Unknown, index replacement and
  removal, watch-only refresh, schema migration backfill, and no startup
  rebuild.
- `swift test --filter DatabaseBootstrapTests` passed all 16 tests.
- `swift test --filter LibraryDatabaseTests` passed all 18 tests.
- `swift test --filter IndexingDatabaseTests` passed all 17 tests.
- `swift test --filter SearchDatabaseTests` passed all 45 tests.
- The complete `swift test` run built successfully but finished with 12 issues
  among 888 tests in unrelated concurrent native playback, Subtitle Focus,
  folder-removal, and UI refresh-probe tests. The run also logged test database
  `disk I/O error` messages.
- Every failed area passed on immediate isolated rerun: 5 native media timeline
  tests, 21 Subtitle Focus keyboard-action tests, 1 folder-removal/indexing
  exclusion test, and 1 mounted-Search refresh-probe test.
- `git diff --check` passed.

## Outcome

Step 2 now supplies a transactionally synchronized, index-time distribution
cache for empty-query Search. Reading the empty-state distribution does not
scan indexed Cue data, and watch-state changes do not rebuild the other three
facets.
