# Search And Shiori Facet Filter Step 3

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Make each complete Search generation publish the full result IDs, four facet
distributions, and compact per-result facet values from the same traversal.
Search and Shiori UI remain unchanged.

## Classification

- Product semantics: implemented in `CueSeekerCore`.
- App search lifecycle: coordinated by `CueSeekerApp`.
- Platform UI/UX: unchanged.
- Playback execution: unchanged.

## Implementation

- Added one complete facet snapshot value containing the ordered Cue IDs,
  compact Duration, Character, Language, and Watch Status values, and their
  distributions.
- Accumulated the snapshot inside the existing exact match loop. No second FTS
  query, Cue scan, or exact task was added.
- Reused a complete visible traversal for small result sets instead of starting
  a redundant exact completion.
- Kept partial visible results without a snapshot; the App exposes them as
  calculating until the complete snapshot arrives.
- Reused the existing search generation and cancellation lifecycle. Starting a
  new query, changing folder scope, or mutating indexed Cue data discards the
  previous snapshot, and stale exact completion cannot commit.
- Kept the change to one new domain value and existing search/store paths; no
  new cache, task type, service, or database table was added.

## Verification

- `swift test --filter CueFacet` passed all 10 tests, including complete exact
  and complete-visible snapshot coverage.
- `swift test --filter SearchDatabaseTests` passed all 45 tests, including the
  assertion that partial visible results have no facet snapshot.
- `swift test --filter SearchStoreTests` passed all 27 tests, including stale
  generation rejection and calculating-state coverage.
- The complete `swift test` run built successfully but finished with 13 issues
  among 890 tests in unrelated concurrent folder-removal, native playback,
  Subtitle Focus, and UI refresh-probe tests.
- Every failed area passed on immediate isolated rerun: 8 folder-removal tests,
  21 Subtitle Focus keyboard-action tests, 14 UI refresh-scope tests, and 5
  native media timeline tests.
- `git diff --check` passed.

## Outcome

Step 3 now produces one generation-consistent exact result and facet snapshot.
Partial results cannot expose incomplete distributions, stale queries cannot
replace the current snapshot, and the existing full search traversal remains
the only source of the non-empty-query distribution.
