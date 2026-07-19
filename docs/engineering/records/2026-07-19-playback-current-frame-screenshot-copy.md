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

### 2. Native-Size Image and Pasteboard Boundary

- Wrapped the native snapshot in an immutable playback-domain value without
  exposing mutable player state to the App target.
- Added a Core Image conversion path that accepts hardware or software pixel
  buffers, applies any image orientation property carried by the submitted
  frame, preserves the resulting native pixel dimensions, and produces an sRGB
  `CGImage` without reopening the media source.
- Kept macOS clipboard integration in the App target. It encodes the rendered
  image directly to an in-memory PNG and publishes `public.png` without a save
  panel or temporary file.

## Verification

- Passed: `swift test --package-path apps/macos-native --filter nativeSeekAndOpenRetainPresentedImageUntilCurrentGenerationCommits`.
- Confirmed the retained snapshot reports the decoded `160x90` fixture size,
  advances to the seek and source-open presentation generations, clears when
  playback removes the display image, and remains readable when a caller still
  owns an earlier snapshot.
- Passed: `swift test --package-path apps/macos-native --filter Screenshot` with
  the new native-size renderer and pasteboard writer tests plus the existing
  subtitle screenshot coverage.
- Passed: `swift test --package-path apps/macos-native --filter currentFrameScreenshotRenderer`.
- Confirmed both software-style BGRA and hardware-style bi-planar YUV pixel
  buffers produce the expected native pixel dimensions, and the pasteboard PNG
  decodes back to those dimensions.

## Outcome

- Pending implementation completion.
