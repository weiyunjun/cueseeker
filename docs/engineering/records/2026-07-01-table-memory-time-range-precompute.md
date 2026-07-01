# Table Memory Time Range Precompute

## Human-Owned Source

- `docs/human/requirements/20260701-Bug-Table Memory Optimization.md`

## Scope

Move Search and Shiori table `Time` column display text out of the row drawing
path so scrolling no longer parses and formats cue time ranges for every
visible cell repaint.

## Classification

- Product semantics: unchanged; cue start and end timing still represent the
  indexed subtitle cue group.
- Platform UI/UX: Search and Shiori table rows now carry ready-to-draw `Time`
  text.
- Platform integration: subtitle indexing and database migration now persist a
  normalized cue `time_range` string.
- Playback execution: unchanged.

## Changes

- Added `time_range` to `subtitle_cue_groups`, bumped the schema version, and
  backfilled existing cue groups from their millisecond timestamps.
- Wrote `time_range` during cue group indexing so reindexing stores the display
  value before Search or Shiori rows render.
- Carried the indexed `time_range` through Search result queries and Shiori
  table queries.
- Changed `SubtitleTableRow.timeRange` from a computed property to a stored row
  field populated during row-model hydration.
- Added focused tests for Core Search result time ranges and App row-model use
  of a precomputed Search time range.

## Verification

- `git diff --check` passed.
- `swift test --filter TableSandboxRowModelStoreTests` passed.
- `swift test --filter SubtitleDatabaseTests` passed.
- `swift test` passed. XCTest reported 7 passing CASS rendering tests, and
  Swift Testing reported 366 passing tests.

## Outcome

Search and Shiori row drawing now reads precomputed `Time` text from the row
model instead of recalculating the range on every draw.
