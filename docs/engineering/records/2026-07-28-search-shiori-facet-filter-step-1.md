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
- Represented a card's `All` state as an empty selection, evaluated selections
  with OR inside each card, and evaluated active cards with AND between cards.
- Reused `SubtitleLanguageCode` so one multilingual Cue can match each language
  assigned to it, including the existing `unknown` value.
- Reused `LibraryWatchState` directly and added `Hashable` conformance so watch
  status remains independent from playback progress.
- Exposed `activeCardCount` as the number of cards whose selection is not All.

## Verification

- `swift test --filter CueFacet` passed all 6 focused tests, including every
  Duration and Character boundary, All, per-card OR, all 16 active-card
  combinations, cross-card AND, multilingual membership, Unknown, Watch Status,
  active-card count, and clearing all cards.
- The first complete `swift test` run built successfully but finished with 15
  issues among 885 tests in unrelated concurrent native playback, folder
  removal, Subtitle Focus, and UI refresh-probe tests. The run also logged test
  database `disk I/O error` messages.
- Each affected area passed when immediately rerun in isolation: 5 native media
  timeline tests, 1 folder-removal progress test, 2 Subtitle Focus Shiori tests,
  and 1 mounted-Search refresh-probe test.
- `git diff --check` passed.

## Outcome

Step 1 now has one small reusable core filter model and pure logic coverage for
the accepted card semantics. No cache, asynchronous lifecycle, database query,
or UI path was introduced.
