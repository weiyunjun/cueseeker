# Speaker Subtitle ASS Line Target Fix

Superseded by:

- `docs/engineering/records/2026-06-09-speaker-subtitle-ass-visible-line-fix.md`

The line-level playback path recorded here was removed because it placed
speaker prefixes on the imported speaker line rather than the first visible ASS
subtitle line, making speaker prefixes disappear from normal playback views.

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Fix ASS speaker display so playback prefixes the subtitle line that actually
has speaker assignments.

## Implementation

- Added line-level speaker display cue targeting for ASS subtitle rewriting.
- Kept the existing group-level cue targeting as a fallback API for current
  tests and non-line-specific callers.
- Updated ASS playback speaker cue loading to read `speakersByCueLineID`,
  which preserves the imported cue-line ownership for bilingual ASS subtitles.
- Added a regression test covering a Chinese/Japanese ASS cue group where only
  the Japanese line has a speaker assignment.

## Verification

- Passed: `swift test --filter SubtitleSpeakerDisplay`

## Outcome

Test Search 2 playback can now render speaker prefixes on the ASS dialogue line
that contains the imported speaker assignment, instead of selecting the first
display line in the cue group.
