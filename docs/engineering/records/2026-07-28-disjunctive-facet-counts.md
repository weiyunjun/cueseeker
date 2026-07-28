# Disjunctive Facet Counts

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Implement Step 8 disjunctive option counts for the Search and Shiori facet
cards without adding a database query, FTS request, or second scan per card.

## Implementation

- Extended the existing paged facet projection so one snapshot scan produces
  the ordered result IDs, filtered result count, and all four card
  distributions.
- Each card distribution ignores that card's selections while applying the
  other three cards; the result projection continues to apply all four cards.
- Accumulated partial distributions alongside the existing Search continuation
  pages and published the exact option counts when that projection completes.
- Reused the resident Shiori snapshot for its result projection and card
  counts.
- Kept empty Search option counts fixed at zero while retaining the cached
  database language set solely to determine which language options exist.
- Preserved the existing generation and cancellation checks so obsolete query
  or filter projections cannot publish.

## Verification

- The focused facet, Search, Shiori, and playback projection run passed all 15
  selected tests.
- `CueGroupRefreshScopeIntegrationTests` passed all 16 tests, including the
  assertion that a Search facet change does not refresh global or inactive
  surfaces.
- A release-mode projection against the current database for query `の` used a
  51,062-row exact snapshot. With Duration `1–2.999s`, Character `1–10`,
  Language `Japanese`, and Watch Status `Unwatched`, the first 50 results took
  `0.027ms` median; the remaining progressive projection and all four
  disjunctive distributions took `3.949ms` median and produced 2,806 results.
- The projection benchmark opened the database only to obtain the exact
  snapshot; every measured filter operation used only that in-memory snapshot.
- The full `swift test` run executed 912 tests and reported 13 issues in
  timing-sensitive media, folder-removal, menu-hover, and concurrent probe
  tests. The feature-focused and refresh-scope reruns passed independently.
- `git diff --check` passed.

## Outcome

Search and Shiori now show counts that reflect the other active cards while
retaining first-page publication, progressive completion, original result
ordering, and the existing database-free filter interaction.
