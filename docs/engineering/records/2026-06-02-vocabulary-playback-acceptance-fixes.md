# Vocabulary Playback Acceptance Fixes

Date: 2026-06-02

Human requirement: `docs/human/requirements/20260601-Feature-Vocabulary.md`

## Scope

- Made vocabulary example cards open playback when clicked.
- Added a vocabulary playback source so opened examples keep their own playlist state.
- Added playback sidebar support for vocabulary examples, including selected-row scrolling and previous/next navigation through all derived examples in the vocabulary list.
- Preserved the existing playback sidebar visibility and active drawer state when opening vocabulary examples, matching the Search/Shiori playback entry behavior.
- Refreshed Shiori rows after successful indexing so derived vocabulary examples use the latest subtitle text and video name/path for matching cue ranges.
- Marked Shiori rows invalid when their saved cue range no longer exists after reindexing, and excluded invalid Shiori rows from derived vocabulary examples.

## Boundary

- Did not add a new persisted examples table.
- Did not implement manual example add/delete, duplicate manual examples, or empty manually curated example lists.
- Did not refactor the backend around a new unified group/example interface; this remains deferred to a separate requirement.

## Verification

- `git diff --check` passed.
- `swift test --filter VocabularyStoreTests` passed.
- `swift test --filter reindexingSubtitleRefreshesMatchingShioriSnapshotAndInvalidatesMissingCue` passed.
- `swift test` passed.

## Outcome

- Vocabulary examples are now usable for end-to-end validation: clicking an example starts playback, the vocabulary example playlist is available without forcing the playback sidebar open, previous/next navigation moves within that playlist, and reindexing keeps the temporary Shiori-derived examples synchronized without changing the schema.
