# Speaker Subtitle Diagnostics

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Add targeted diagnostics for the ASS speaker subtitle playback path because the
client still did not show speaker prefixes after the visible-line fix.

## Implementation

- Added `SubtitleSpeakerDisplayDiagnostics` in Core to write JSONL diagnostics
  under `logs/speaker-subtitle/`.
- Logged ASS speaker cue loading in App playback code, including switch state,
  subtitle path, cue-line record count, speaker group count, and generated cue
  count.
- Logged ASS subtitle source loading in `PlaybackPlayer`.
- Logged ASS renderer source loading and whether script rewriting changed the
  render script.

## Verification

- Passed: `swift test --filter SubtitleSpeakerDisplay`
- Passed: `swift test --filter playbackRequestStoresASSSubtitleSource`

## Outcome

After rebuilding and restarting the client, playing a MyGO ASS subtitle should
produce diagnostics that show where speaker prefix generation or rendering stops.
