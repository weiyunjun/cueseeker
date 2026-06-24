# Cue Parsing Index Filtering

## Human Document

- `docs/human/requirements/20260624-Feature-Cue Parsing Index Filtering.md`

## Implementation

- Added shared cue indexing constants for the parser algorithm version and the
  200ms minimum indexed cue duration.
- Applied the new filtering and de-duplication rules in SRT and ASS cue parsing
  before rows are written to the searchable cue index.
- Versioned indexed subtitle files with `index_algorithm_version` so existing
  rows are rebuilt once after the parsing rules change.
- Preserved cue-line speaker assignments across the forced rebuild by restoring
  speakers through stable cue-line keys after replacement.

## Data Preservation Check

- Existing local speaker rows were checked before implementation:
  - Speaker assignment rows: 3934
  - Speaker rows below 200ms: 0
  - Speaker rows with cleaned empty text: 0
  - Strict duplicate speaker-bearing retained-field keys: 0
- Existing local Shiori rows were checked before implementation:
  - Shiori rows: 142
  - Shiori rows below 200ms: 0
  - Shiori rows with cleaned empty text: 0

## Verification

- `swift test` passed.

## Outcome

- Searchable cue indexing now filters short and empty cue rows and removes
  duplicate cleaned cue rows according to the human requirement.
- The app will rebuild stale subtitle index rows once, without deleting user
  Shiori records or existing cue-line speaker assignments that still match a
  retained cue line.
