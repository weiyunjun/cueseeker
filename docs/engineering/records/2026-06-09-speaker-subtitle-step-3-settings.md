# Speaker Subtitle Step 3 Settings

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Step 3 adds the Settings > Play switch for enabling speaker display during
playback. It does not yet change SRT or ASS subtitle text.

## Implementation

- Added `SettingsStore.playbackSpeakerDisplayEnabled`, persisted through
  `UserDefaults`.
- Added a `Show Speaker in Subtitles` switch to Settings > Play.
- Extended playback settings tests to verify the default disabled state and
  persisted enabled state.

## Verification

- Passed: `swift test --filter SettingsStorePlayback`

## Outcome

Users can now enable or disable playback speaker display from Settings > Play.
