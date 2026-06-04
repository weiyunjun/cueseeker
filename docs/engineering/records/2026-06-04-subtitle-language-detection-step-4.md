# Subtitle Language Detection Step 4

Human requirement:

- `docs/human/requirements/20260604-Feature-Subtitle Language Detection And Search Filter.md`

## Scope

Integrated subtitle language analysis into the indexing flow:

- Added `SubtitleLanguageAnalyzer` to `SubtitleIndexer`.
- Runs language analysis after subtitle/video matching and subtitle parsing, before database writes.
- Persists language analysis in the same `replaceCueGroups` transaction as cue groups, ASS render segments, and ASS font references.
- Requires a current subtitle language manifest before unchanged subtitle files can be skipped.
- Added indexer tests for SRT language persistence, ASS used-style persistence, and reindexing unchanged files that were indexed before language manifests existed.

This step does not yet add language filtering to search SQL or expose the Search setting in the UI.

## Verification

- `swift test --filter SubtitleIndexer` passed 12 Swift Testing tests.
- `swift test --filter Language` passed 20 Swift Testing tests.
- `swift test` passed 195 Swift Testing tests and 7 XCTest tests.

## Outcome

Indexing now records subtitle language data for matched SRT and ASS files, and
unchanged legacy index rows are rebuilt once when the current language manifest
is missing.
