# Speaker Subtitle ASS Visible Line Fix

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Correct ASS speaker display after the line-target experiment made speaker
prefixes disappear from the visible playback subtitles.

## Implementation

- Restored ASS playback speaker cue generation to use cue-group speakers.
- Kept the display target as the first non-empty display line in the cue group,
  so bilingual ASS subtitles show the speaker prefix at the visible subtitle
  start.
- Removed the line-level playback path that placed prefixes on the imported
  speaker line even when that line was not the first visible subtitle line.
- Added a regression test for a MyGO-like `Dial_CH`/`Dial_JP` cue group where
  the speaker prefix must appear on the `Dial_CH` first display line.

## Verification

- Passed: `swift test --filter SubtitleSpeakerDisplay`
- Passed: `swift test --filter playbackRequestStoresASSSubtitleSource`
- Passed: MyGO EP01 database verification found 391 speaker cue groups, all
  with a non-empty first visible `Dial_CH` target line.

## Outcome

Library, Search, and Test Search 2 playback share the same ASS source rewriting
path again, with the speaker prefix inserted into the visible subtitle start.
