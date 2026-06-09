# Speaker Subtitle Step 1 Core API

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Step 1 adds the Core database API needed to treat speakers as a string set on
subtitle cue lines. It does not import MyGO data, add Settings UI, or change
playback subtitle rendering.

## Implementation

- Added `SubtitleCueLineRecord` so import and playback code can identify
  persisted cue lines without raw SQL.
- Added `SubtitleCueLineSpeakerAssignment` for replacing the speaker set for a
  subtitle file.
- Added public database methods to list cue line records, replace all speaker
  assignments for one subtitle file, clear speaker assignments for one subtitle
  file, and read speakers grouped by cue line or cue group.
- Kept Test Search 2 search-result hydration on the existing
  `subtitle_cue_line_speakers` table and `SubtitleSearchResult.speakers` set.

## Verification

- Passed: `swift test --filter SubtitleDatabase`

## Outcome

The Core layer now exposes speaker data as a first-class set of strings, which
supports ordinary labels and suspected labels such as `疑似高松灯` on the same
cue.
