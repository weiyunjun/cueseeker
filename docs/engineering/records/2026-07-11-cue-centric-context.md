# Cue-Centric Context And Shiori Presentation Data

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Change empty-query Search, filtered all-Cue results, and Context from Cue Group
rows to individual Cue rows. Carry exact Cue identity and optional Cue Group
presentation context through Search, Shiori, and Library Context entry points.
Prepare Shiori page data for `Show Cue Group` without implementing the dynamic
table presentation in this step.

## Classification

- Product semantics: every result, Context target, count, rank, page boundary,
  playback target, and default action represents one Cue.
- Presentation context: the owning Cue Group remains available as ordered
  secondary text but cannot replace or retarget the primary Cue.
- Durable Shiori identity: subtitle path, event index, and Cue timing resolve
  the current indexed Cue. Stored display order remains presentation metadata,
  not part of durable identity.

## Implementation

- Replaced `allCueGroupsVisiblePage` with `allCuesVisiblePage`. It orders,
  filters, counts, summarizes, and paginates individual Cue Lines. Primary
  content and Speaker/language metadata are isolated from sibling Cues.
- Changed `cueContextSearchPage` to accept `targetCueID`, resolve the exact Cue
  ordinal, and return Cue rows in stable group-time and source-display order.
  Context hydration keeps `cueLines` scoped to the primary Cue and carries the
  complete ordered Cue Group separately. Initial anchor sizing is clamped to
  the actual returned page size so the target remains inside the first page
  even when a caller requests a larger anchor window.
- Renamed Context request and helper state to `targetCueID`; removed ambiguous
  `targetEntryID` and `targetCueGroupID` names from the Context call chain.
- Changed Search Context to pass `SubtitleSearchResult.entryID`, Shiori Context
  to resolve the durable Cue identity, and Library Context to start from the
  first Cue rather than the first Cue Group.
- Added `SubtitleSearchResult.primaryGroupIndex` so duplicate sibling text does
  not force the presentation layer to infer the primary Cue by string or assume
  that source display order equals an array index.
- Added the strongly typed `ShioriCuePresentation` page snapshot containing the
  current Cue ID, Cue Group ID, primary group index, exact ordered Cue Group
  texts, Cue-local languages, and Cue-local Speakers. Table row sources retain
  this snapshot for the later dynamic-UI step.
- Kept unresolved Shiori snapshots recoverable: their Cue and Group IDs and
  primary index remain absent, their original content is exposed as the sole
  group text, and language/Speaker metadata falls back safely.
- Made Shiori rehydration ignore stored display order when resolving durable
  identity. Reindexed Cues therefore remain connected when current display
  order changes, while Context and presentation use the current order.
- Prevented language and Speaker metadata from leaking between sibling Cues in
  all-Cue, ordinary Search hydration, and Shiori filtering. Multi-Cue ASS groups
  without style/file detection use current-Cue content recognition instead of
  the Cue Group language union.
- Corrected legacy Shiori migration for mixed file-level Japanese/Chinese
  detection: style detection remains authoritative; single-language Japanese
  files remain Japanese; mixed files classify each Cue's content before the
  established bottommost fallback. A Style whose detection itself contains
  both Japanese and Chinese also classifies each Cue's content instead of
  treating every Cue in that Style as Japanese.

## Verification

- Focused all-Cue tests passed for Cue-level counts, pagination, file summaries,
  exact source line breaks, Cue-local language/Speaker filters, and sibling
  context.
- Focused Context tests passed for first/tail anchoring, preceding/following
  pages, an anchor window larger than the returned page, same-time sibling
  Cues, stable ranks, exact target identity, and full Cue Group context.
- Focused entry-point tests passed for Search exact-Cue Context, Shiori durable
  identity Context, and Library first-Cue Context.
- Focused Shiori tests passed for reindexing with changed display order,
  identity-resolved primary group index, exact group text, Cue-local language and
  Speaker filtering, orphan fallback, and current-Cue Context hydration.
- Focused migration tests passed for style-based Japanese preference,
  mixed-file and mixed-Style per-Cue recognition, bottommost fallback,
  preserved tags, and unresolved snapshots.
- `swift test --filter Search` passed all 58 Search, Context, App state,
  navigation, table hydration, and Settings tests.
- `swift test --filter Shiori` and `swift test --filter shiori` passed 19 and
  14 focused tests respectively.
- `swift test` passed the complete package suite: 500 Swift Testing tests and
  7 XCTest tests, with 0 failures.
- `git diff --check` passed with no whitespace errors.

## Outcome

Search-hosted Context and empty-query results now use one stable Cue as their
identity and action target. Shiori and optional Cue Group presentation data can
be rendered later without guessing which sibling is primary or changing the
row's Cue semantics.
