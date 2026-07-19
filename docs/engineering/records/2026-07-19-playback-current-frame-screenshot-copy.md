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
  buffer and decoded pixel size.
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

### 3. Current Subtitle Presentation

- Added a main-actor capture contract that snapshots one submitted video frame,
  its current aspect-fit video rectangle, and the ASS surface already applied
  by the playback subtitle view.
- Composed the retained sparse ASS RGBA surface at its source destination
  coordinates instead of asking libass to render again at the media clock.
- Reused the actual SwiftUI simple-subtitle view to render the current visible
  text at the current playback viewport size, cropped away letterbox pixels,
  and scaled only that transparent overlay to the native video frame size.
- Preserved presentation order: video frame, source-faithful ASS surface, then
  the simple SwiftUI subtitle overlay that is visually above the native render
  container.

## Simplification Pass

### 1. Snapshot and Result Model

- Removed media timestamp and presentation generation from the screenshot
  snapshot because current-generation validation already happens before a
  frame is submitted and the copy pipeline never consumes those values.
- Removed the screenshot result wrapper and now passes the rendered `CGImage`
  directly through composition, PNG encoding, and pasteboard publication.
- Kept the independently retained native pixel buffer, decoded dimensions, and
  current-frame replacement semantics unchanged.

### 2. Unified Composition

- Removed the cross-module submitted-frame wrapper and made the presentation
  snapshot retain the native frame directly while exposing only the viewport
  size needed by the App subtitle renderer.
- Reused the playback overlay's existing sparse ASS frame instead of copying it
  into a second screenshot-only surface model.
- Changed the App layer to render only the transparent SwiftUI subtitle at the
  current viewport size. The playback renderer now crops away letterboxing,
  scales that overlay to native video pixels, and draws it in the same final
  bitmap context used for the video and ASS surface.
- Removed the intermediate native-size transparent bitmap and narrowed
  screenshot geometry, ASS data, and conversion errors to playback-module
  implementation details.

### 3. API and Layout Cleanup

- Removed the unused composition forwarding method, image-to-pasteboard
  convenience overload, and redundant internal memberwise initializers.
- Shared one aspect-fit video rectangle calculation between the live ASS layer
  and screenshot geometry so both paths cannot drift independently.
- Renamed the background work item field to describe its viewport-sized
  subtitle overlay and kept request generation ordering, background PNG work,
  pasteboard publication, input gates, and feedback unchanged.
- Reduced screenshot production code by a net 209 lines, from 739 lines added
  by the initial implementation to 530, while retaining behavior-focused test
  coverage.

### 4. Playback Command and Feedback

- Added a fixed `photo` transport-style button before the subtitle control. It
  has no selected state or icon transition and follows the existing timeline
  interaction suppression used by the other playback controls.
- Added bare `P` handling for the normal playback surface, including repeated
  key-down events. Modified `P` is not claimed, timeline dragging consumes the
  shortcut without taking a screenshot, and the subtitle-focus overlay keeps
  consuming it without dispatching the screenshot command.
- Captured the submitted frame, current layout geometry, ASS surface, and
  simple-subtitle overlay on the main actor, then moved pixel composition and
  in-memory PNG encoding to a user-initiated background task.
- Ordered concurrent requests by generation so an older completion cannot
  overwrite a newer successful copy. The main actor writes `public.png` to the
  pasteboard and shows the centered `photo` / `Screenshot Copied` HUD only
  after that write succeeds.

## Verification

- Passed: `swift test --package-path apps/macos-native --filter nativeSeekAndOpenRetainPresentedImageUntilCurrentGenerationCommits`.
- Confirmed the retained snapshot reports the decoded `160x90` fixture size,
  is replaced after both seek and source-open presentation commits, clears when
  playback removes the display image, and remains readable when a caller still
  owns an earlier snapshot.
- Passed: `swift test --package-path apps/macos-native --filter Screenshot` with
  the new native-size renderer and pasteboard writer tests plus the existing
  subtitle screenshot coverage.
- Passed: `swift test --package-path apps/macos-native --filter currentFrameScreenshotRenderer`.
- Confirmed both software-style BGRA and hardware-style bi-planar YUV pixel
  buffers produce the expected native pixel dimensions, and the pasteboard PNG
  decodes back to those dimensions.
- Passed: `swift test --package-path apps/macos-native --filter Screenshot` with
  13 screenshot-related tests.
- Passed: `swift test --package-path apps/macos-native --filter simpleSubtitleScreenshotOverlayUsesNativeOutputDimensions`.
- Confirmed an already-rendered sparse ASS surface is composited into the base
  frame and the reused simple-subtitle view produces a transparent native-size
  overlay whose visible pixels remain bottom-anchored after letterbox cropping
  and scaling.
- Passed the four command-state tests covering bare and repeated `P`, modified
  `P`, timeline dragging, subtitle-focus overlay suppression, and the required
  success HUD contents.
- Passed the native presentation-transition snapshot test and all 16 tests
  selected by the `Screenshot` filter after simplifying the snapshot and image
  result model.
- Passed all 16 tests selected by the `Screenshot` filter after unifying the
  composition path; the native-size SRT test still confirms correct video
  orientation, letterbox removal, and bottom anchoring.
- Passed 17 focused tests covering screenshots plus the shared aspect-fit ASS
  layout calculation after the final API cleanup.
- Ran the complete 787-test Swift Testing suite. Two unrelated shared-state and
  database tests failed under full-suite load; both passed immediately when
  rerun alone (`sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  and `subtitleFocusShioriKeySavesIdempotentlyAndKeepsPausedSession`).
- Ran the complete `swift test --package-path apps/macos-native` suite. The run
  exercised 787 Swift Testing tests but reported four timing/I/O-sensitive
  failures under full-suite load alongside transient SQLite `disk I/O error`
  messages. Each failed test passed immediately when rerun alone: the two
  native media-timeline tests and the two subtitle-focus database action tests.

## Outcome

- Current-frame screenshot copy is implemented for the playback page with the
  required frame fidelity, subtitle visibility, input gates, pasteboard-only
  output, and success feedback. The simplification pass preserves that behavior
  with fewer screenshot-specific models, allocations, and public interfaces.
