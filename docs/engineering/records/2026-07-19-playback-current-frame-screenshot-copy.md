# Playback Current Frame Screenshot Copy

## Human-Owned Source

- `docs/human/requirements/20260719-Feature-Playback Current Frame Screenshot Copy.md`
- `docs/human/design/UI.md`

## Scope

Add playback-page current-frame screenshot copying without reopening, seeking,
or pausing the active video and without invoking FFmpeg.

## Implementation Steps

### 1. Submitted Frame Snapshot

- Added an immutable native playback frame snapshot that retains the pixel
  buffer, media timestamp, presentation generation, and decoded pixel size.
- Replaced the snapshot after every video frame successfully enters the current
  `AVSampleBufferDisplayLayer` presentation, rather than relying on the
  first-frame-only presentation delegate callback.
- Kept the previous snapshot during seek and source transitions while the
  previous image remains displayed, then atomically replaced it with the first
  frame of the current generation.
- Cleared the player-owned snapshot when playback removes the displayed image;
  snapshots already handed to callers retain their pixel buffer independently.

## Verification

- Passed: `swift test --package-path apps/macos-native --filter nativeSeekAndOpenRetainPresentedImageUntilCurrentGenerationCommits`.
- Confirmed the retained snapshot reports the decoded `160x90` fixture size,
  advances to the seek and source-open presentation generations, clears when
  playback removes the display image, and remains readable when a caller still
  owns an earlier snapshot.

## Outcome

- Pending implementation completion.
