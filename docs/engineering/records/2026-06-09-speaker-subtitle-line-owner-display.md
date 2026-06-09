# Speaker Subtitle Line Owner Display

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

Related clarification:

- Speaker display must follow the concrete ASS cue line that owns the speaker
  assignment. It must not merge speaker labels at the cue-group level and inject
  them into a different `Name`/style line.

## Scope

Restore ASS speaker prefix injection to line-level ownership so bilingual or
mixed ASS cue groups do not blur speaker semantics.

## Implementation

- Changed `SubtitleSpeakerDisplayCue.targetCues` to build cues from
  `speakersByCueLineID`.
- Changed ASS playback cue loading to read `speakersByCueLineID` from the
  database.
- Updated regression tests so a speaker attached to `Dial_JP` prefixes the
  `Dial_JP` dialogue and leaves the sibling `Dial_CH` dialogue unchanged.

## Verification

- Passed: `swift test --filter SubtitleSpeakerDisplay`
- Passed: `swift test --filter playbackRequestStoresASSSubtitleSource`
