# Search And Shiori Facet Filter Step 1

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Establish the shared product semantics for the Search and Shiori data-card
filters without changing UI, persistence, indexing, or query execution.

## Classification

- Product semantics: implemented in `CueSeekerCore` so Search and Shiori can
  reuse one rule set.
- Platform UI/UX: unchanged.
- Platform integration: unchanged.
- Playback execution: unchanged.

## Implementation

- Added the required Duration and Character range classifications with the
  documented boundaries.
- Added one `CueFacetFilter` value that holds the selected values for Duration,
  Character, Language, and Watch Status.
- Made its existing initializer select every defined value by default; callers
  can explicitly pass an empty set to represent a fully cleared card.
- Removed the virtual `All` state. Selecting every available value leaves a
  card unrestricted, while an empty selection rejects every result.
- Evaluated selections with OR inside each card and AND between all four cards.
- Reused `SubtitleLanguageCode` so one multilingual Cue can match each language
  assigned to it, including the existing `unknown` value.
- Reused `LibraryWatchState` directly and added `Hashable` conformance so watch
  status remains independent from playback progress.
- Removed the superseded active-card count; the Filter button no longer has a
  number or Badge.

## Verification

- The revised tests first failed against the previous empty-selection-as-All
  behavior, then passed after the product rule was corrected.
- `swift test --filter CueFacetFilterTests` passed all 6 pure logic tests,
  covering every boundary, all selected, partial selection, single selection,
  multi-selection, per-card OR, cross-card AND, multilingual membership,
  Unknown, Watch Status, and empty-card rejection.
- `swift test --filter CueFacet` passed all 10 Step 1-3 facet tests, confirming
  the index cache and exact-search snapshot remain unchanged.
- `git diff --check` passed.

## Outcome

Step 1 now has one small reusable core filter model and pure logic coverage for
the revised card semantics. Every card contains only real selectable values,
and an empty card produces no results. No cache, asynchronous lifecycle,
database query, persistence, or UI path was introduced.
