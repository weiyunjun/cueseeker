# Cue-Centric Table UI

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Implement the Cue-centric Search, Shiori, and Context table presentation in
reviewable stages. Phase 4A establishes the row data contract and preserves
complete source text. Dynamic row geometry, optional Cue Group rendering, and
shared Cue Group interactions remain subsequent phases of the same accepted
table requirement.

## Classification

- Product semantics: one table row and every default action target one primary
  Cue.
- Presentation context: ordered sibling Cue text remains optional secondary
  context and cannot replace the primary Cue identity.
- Platform UI data: the AppKit table receives exact primary and group payloads
  without owning database lookup or Cue identity resolution.

## Phase 4A: Row Contract And Complete Text

### Implementation

- Replaced the table row's ambiguous merged subtitle field with explicit exact
  primary Cue text, source-ordered Cue Group texts, and an optional resolved
  primary group index.
- Kept `cues` as a compatibility projection of exact primary Cue text so
  existing drawing and action code cannot silently switch to Cue Group text.
- Derived additional Cue texts by excluding the resolved primary array index,
  not by comparing text. Duplicate sibling Cues therefore remain distinct.
- Added a complete Cue Group clipboard payload that joins every source-ordered
  Cue while preserving each Cue's internal line order and line breaks.
- Mapped Search and Search-hosted Context rows from `SubtitleSearchResult`
  primary content, ordered group lines, and identity-resolved primary index.
  Row identity remains the primary Cue ID.
- Mapped Shiori rows from exact saved Cue content and `ShioriCuePresentation`.
  Indexed Shiori retain ordered group context, Cue-local language and Speaker
  presentation, while unresolved legacy snapshots fall back to their exact
  saved content with no inferred primary group index. Row identity remains the
  Shiori ID.
- Removed the six-line and 500-character table display budgets and stopped
  normalizing table payloads through the trimming/filtering display helper.
- Kept the Copy Table Cues column bound explicitly to exact primary Cue text,
  independent of the future `Show Cue Group` presentation state.
- Preserved primary/group presentation fields when patching visible Shiori tag
  cells.

### Verification

- `swift test --filter TableSandboxRowModelStoreTests` passed 30 tests.
- `swift test --filter SubtitleTableClipboardTests` passed 7 tests.
- `swift test` passed the complete package suite: 505 Swift Testing tests and
  7 XCTest tests, with 0 failures.
- `git diff --check` passed with no whitespace errors.
- Focused coverage verifies more than six source lines, a line longer than 500
  characters, internal empty lines, duplicate sibling text, identity-resolved
  array exclusion, source-ordered group copy text, indexed and orphan Shiori
  presentation, Shiori tag patch preservation, stable Search/Context/Shiori
  row identity, and primary-only Copy Table output.

## Outcome

Phase 4A gives the shared table one unambiguous primary Cue payload plus
separate optional Cue Group context without truncating or normalizing subtitle
source text. The later dynamic layout and interaction phases can now change
presentation without changing row identity, default action targets, or Copy
Table semantics.
