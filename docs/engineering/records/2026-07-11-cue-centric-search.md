# Cue-Centric Search

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Change ordinary Search from one result per Cue Group to one result per matching
Cue. This step covers Search result identity, matching, filtering, counts,
pagination, file summaries, progress snapshots, result-ID hydration,
navigation, App state naming, and focused tests. Cue Context and the unfiltered
all-Cue Context source retain their current Cue-Group row implementation for a
later accepted step.

## Classification

- Product semantics: a Search result and Search action target is one Cue.
- Derived recall: Cue Group FTS remains a coarse recall index and does not
  define result identity.
- Presentation context: ordered sibling Cue text is carried separately and
  does not participate in matching, filtering, count, rank, or actions.

## Implementation

- Changed `SubtitleSearchResult.entryID` to contain the
  `subtitle_cue_lines.id` of the primary Cue.
- Added the owning Cue Group ID, source event index, display order, durable Cue
  identity projection, and complete ordered `cueGroupLines` context.
- Kept `content` and `cueLines` scoped to the primary Cue. One Cue containing
  source line breaks remains one result and retains its exact complete text.
- Retained Cue Group FTS as the recall pass, then expanded every recalled group
  into independently validated Cue matches in stable display order.
- Applied query validation, language filtering, schema filters, and Speaker
  metadata to each primary Cue. Sibling Cue text, language, or Speaker metadata
  cannot admit a nonmatching Cue.
- Counted and paginated every matching Cue independently in exact and visible
  modes, including when a page boundary falls between sibling Cues in one
  group. File summaries, ranks, progress snapshots, and result ID lists use the
  same Cue-level result stream.
- Changed result-ID hydration and indexed navigation windows to use Cue IDs and
  reconstruct the owning Group context without collapsing sibling results.
- Renamed Core/App result ID collections from `cueGroupIDs` and
  `searchResultCueGroupIDs` to `cueIDs` and `searchResultCueIDs`.
- Preserved Cue Group IDs only where they still express a real relationship:
  Group FTS candidates, optional sibling context, playback Group fallback, and
  the temporarily unchanged Context queries.

## Compatibility Boundary

`cueContextSearchPage` and `allCueGroupsVisiblePage` still emit one row per Cue
Group and are intentionally excluded from this step. Opening Context from an
ordinary Search result therefore passes `result.cueGroupID`, while ordinary
Search selection, hydration, navigation, copy, Shiori handoff, and export data
use the primary Cue. The remaining Context result identity is removed in the
dedicated Cue-centric Context step.

## Verification

- `swift test --filter search` passed all 37 selected ordinary Search tests.
- `swift test --filter Search` passed all 56 selected Search, App state,
  navigation, table hydration, Context-compatibility, and Settings tests.
- `swift test --quiet` passed the full suite: 495 Swift Testing tests and 7
  XCTest tests, with 0 failures.
- Focused tests verify:
  - one matching Cue is returned without sibling content becoming primary;
  - terms split across different Cues do not match;
  - two matching sibling Cues produce two stable results;
  - exact and visible pagination can split between sibling Cues without
    duplication or omission;
  - exact counts, Cue IDs, ranks, and file-summary counts use Cue units;
  - Cue-ID hydration and navigation distinguish same-Group siblings;
  - one Cue with source line breaks remains one complete result;
  - sibling Cue filter values and Speakers do not leak into the primary Cue.

## Outcome

Ordinary Search now uses Cue identity consistently from database validation
through App state and navigation. Cue Group remains available as recall and
optional presentation context without replacing the primary Cue.
