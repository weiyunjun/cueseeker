# 20261025 Player Progress Scrubber Keyframe Thumbnail Preview

## 1. Requirement Reference

- Requirement: `docs/human/requirements/20261025-Feature-Player Progress Scrubber Keyframe Thumbnail Preview.md`
- Stabilized Design References:
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Design Rules.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/UI Layouts - Playback.md`
  - `docs/human/design/playback/Playback Core.md`

## 2. Implementation Summary

1. **Native Keyframe Index & Session-Scoped Warm Thumbnail Decoder (`SFXNativePlaybackPlayer.h`, `SFXNativePlaybackInternal.h`, `SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`, `SFXKeyframeScrubPreviewDecoder.m`, `SFXNativePlaybackPlayer.m`, `PlaybackPlayer.swift`)**:
   - Captured the sorted container keyframe stream timestamps (`AVIndexEntry` with `AVINDEX_KEYFRAME`) on `SFXNativePlaybackSession` after `SFXSeekToStartPosition` in `prepareWithError:`, enabling lock-free binary search (`keyframeTimestampMillisecondsForTargetMilliseconds:`) that resolves the preceding keyframe timestamp in milliseconds using the same stream timestamp conversion as `av_seek_frame(..., AVSEEK_FLAG_BACKWARD)`.
   - Implemented `SFXKeyframeThumbnailDecoder` on `_scrubPreviewQueue`, keeping a warm `AVFormatContext`, software `AVCodecContext` (`FF_THREAD_SLICE`, `AVDISCARD_NONKEY`, `AVDISCARD_ALL` loop filter, `AV_CODEC_FLAG2_FAST`), and cached `SwsContext` (`sws_getCachedContext`) for the currently open video file, discarding non-video streams and scaling decoded keyframes directly to `targetPixelWidth` and proportional height (`CGImageRef`) without touching the main playback display layer.
   - Invalidated the thumbnail decoder and cancelled in-flight requests when switching video files or stopping playback.

2. **UI Tokens, Window-Edge Clamping, Layer-Aware Hover Location & Drag-Release Sync (`PlaybackTheme.swift`, `PlaybackChromeView.swift`, `PlaybackProgressScrubber.swift`, `PointerHover.swift`, `AppPointerShape.swift`)**:
   - Added `--width-player-progress-thumbnail` (`240px`, `PlaybackChromeMetrics.progressThumbnailWidth`), and reused `--radius-library-cover` (`8px`, `PlaybackChromeMetrics.progressThumbnailRadius`) and `--spacing-1` (`4px`, `PlaybackChromeMetrics.progressThumbnailGap` and `PlaybackChromeMetrics.progressWindowEdgeClampInset`).
   - Computed thumbnail display height dynamically from `240px` and the video's actual aspect ratio (`PlaybackChromeMetrics.progressThumbnailSize(aspectRatio:)`), and scaled decoded pixel dimensions by the active display backing scale factor (`@Environment(\.displayScale)`).
   - Positioned the thumbnail `4px` (`--spacing-1`) above `Player Progress Time Capsule` using `PlaybackProgressTimeCapsulePlacementLayout`, clamping both the thumbnail and the time capsule independently against the App window left and right edges with a `--spacing-1` (`4px`) inline inset rather than stopping at the progress bar track ends.
   - Unified progress bar hover entry/exit and horizontal pointer position tracking under `PointerHoverSession` (`onPointerHoverLocation` and `PointerHoverLocationGate`), ensuring that when an upper-layer surface (e.g., Command Panel, Playback Overlay, Menu, or Dialog) opens, the track height, thumb dot, preview track, floating time capsule, and keyframe thumbnail freeze together at the exact pre-open position; and when the upper layer closes, the current stationary pointer position inside or outside the progress bar is immediately resolved and restored without requiring mouse movement.
   - Synchronized `hoverX` during `DragGesture.onChanged` and updated/cleared hover state in `DragGesture.onEnded` (`PlaybackProgressScrubberHoverState`) based on whether the release location remains inside the `18px` progress bar hit area, preventing the thumbnail and time capsule from flashing back to the drag start position on mouse release.

3. **Real-Time Extraction, Keyframe Deduplication, Single-Flight Latest-Wins Coalescing & Same-Duration Episode Refresh (`PlaybackProgressScrubber.swift`, `PlaybackViewModel.swift`)**:
   - Implemented `PlaybackTimelineThumbnailStore` without trailing debounce:
     - When no decode is in flight, crossing into a new keyframe triggers extraction immediately (`0 ms`).
     - Within the same keyframe interval, micro-movements keep the current image and do not issue duplicate decode requests.
     - While a keyframe is currently decoding, rapid pointer movement across multiple keyframes records only the latest target keyframe (`pendingLatestRequest`); as soon as the in-flight frame completes, it is displayed immediately and extraction of the latest pending keyframe starts immediately.
     - Immediately clears thumbnail state and cancels pending work when the pointer exits the progress bar (and is not dragging), when switching videos, or when playback stops.
   - Tracked the active progress bar hover ratio (`activeTimelineHoverProgress`) and `timelineThumbnailContextRevision` on `PlaybackViewModel` so that when a new video presentation commits or duration updates after a thumbnail reset (including when switching to another episode with the exact same total duration while the pointer stays stationary on the progress bar), `PlaybackViewModel` and `PlaybackProgressScrubber` immediately re-request the new video's keyframe thumbnail at the current pointer position.

## 3. Verification

- Executed `swift test --package-path apps/macos-native --filter "PlaybackProgressScrubberThumbnailTests|PointerHoverGateTests|InterfaceLayerFreezeTests|PlaybackPresentationTransitionTests"`.
- All targeted unit and integration tests compiled cleanly and passed.
