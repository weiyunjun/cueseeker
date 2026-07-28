# Search And Shiori Facet Filter Step 4

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Project the ordered Search exact snapshot into a filtered table without
performing another database search or delaying the first visible rows until a
complete projection is materialized.

## Classification

- Product semantics: implemented in `CueSeekerCore`.
- App search lifecycle and table projection: coordinated by `CueSeekerApp`.
- Platform UI/UX: unchanged.
- Database and playback execution: unchanged.

## Implementation

- Added one paged projection operation to the existing exact facet snapshot.
- Reused the existing four-card match semantics and preserved the source Cue ID
  order.
- Published the first table page synchronously, then appended the remaining
  matching IDs in `1,000`-row batches with cooperative yields.
- Kept the original exact Cue IDs and result count unchanged for Command Panel
  and other consumers; only the Workbench table projection is replaced.
- Published the filtered exact count when the in-memory scan completes.
- Cancelled stale projection work when the query, exact snapshot, or selected
  facet values change.
- Kept projection on the existing main-actor Search store and existing row
  model store; no service, database query, FTS task, cache, or second result
  model was added.

## Verification

- `swift test --filter CueFacetFilterTests` passed all 9 filter and snapshot
  projection tests.
- `swift test --filter facetFilter` passed both Search store projection tests,
  including first-page publication, ordered continuation, exact-boundary
  preservation, and immediate zero rows for an empty card.
- A release-mode scan against the current database using the query `の`
  measured 51,062 exact results. With Duration `1–2.999s`, Character `1–10`,
  Language `Japanese`, and Watch Status `Unwatched`, the first 50 matches took
  `0.011ms` median, the next 1,000 took `0.260ms` median, and the complete
  filtered count of 2,806 took `1.689ms` median.
- The filter projection operates only on the exact snapshot arrays; tests use a
  `SearchStore` without a database, proving the interaction does not require a
  database call.
- `git diff --check` passed.

## Outcome

Step 4 now follows the same presentation strategy as Search: the first visible
rows are available immediately, later rows appear progressively, and the exact
filtered count follows from the same short in-memory pass. The complete Search
snapshot remains the stable source for data-card distributions and non-table
consumers.
