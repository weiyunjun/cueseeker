# Speaker Subtitle Step 4 Playback Display

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Step 4 wires the Settings > Play speaker switch into playback subtitle text for
both SRT and source-faithful ASS playback.

## Implementation

- Added Core speaker display formatting that orders normal speaker labels
  before `疑似` labels and joins labels with `,`.
- Added Core ASS `Dialogue` text rewriting that inserts the speaker prefix after
  leading ASS override tags.
- Added group-level speaker display cues so ASS playback prefixes the first
  display line for a cue group while using speakers aggregated from all lines in
  that group.
- Extended `PlaybackSubtitleSource` to carry speaker display cues into the ASS
  renderer.
- Updated App playback subtitle loading so SRT cue text and ASS source scripts
  are rewritten only when `Settings > Play > Show Speaker in Subtitles` is on.
- Added a settings observer so changing the switch refreshes the current
  playback subtitle display without reopening the video.

## Verification

- Passed: `swift test --filter SubtitleSpeakerDisplay`
- Passed: `swift test --filter initialPlaybackSRTCuePrefixesSpeakerWhenSettingIsEnabled`
- Passed: `swift test --filter playbackRequestStoresASSSubtitleSource`

## Outcome

Playback can now show speaker prefixes at the beginning of SRT subtitle text and
ASS dialogue text when the speaker display switch is enabled.
