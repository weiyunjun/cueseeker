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

2. **UI Tokens & Floating Thumbnail Layout (`PlaybackTheme.swift`, `PlaybackProgressScrubber.swift`)**:
   - Added `--width-player-progress-thumbnail` (`160px`, `PlaybackChromeMetrics.progressThumbnailWidth`) and `--delay-player-progress-thumbnail-debounce` (`30ms`, `PlaybackChromeMetrics.progressThumbnailDebounceDelay`), and reused `--radius-library-cover` (`8px`, `PlaybackChromeMetrics.progressThumbnailRadius`) and `--spacing-1` (`4px`, `PlaybackChromeMetrics.progressThumbnailGap`).
   - Computed thumbnail display height dynamically from `160px` and the video's actual aspect ratio (`PlaybackChromeMetrics.progressThumbnailSize(aspectRatio:)`), and scaled decoded pixel dimensions by the active display backing scale factor (`@Environment(\.displayScale)`).
   - Positioned the thumbnail `4px` (`--spacing-1`) above `Player Progress Time Capsule` using `PlaybackProgressTimeCapsulePlacementLayout(targetX: targetX)`, so both the thumbnail and the time capsule follow `targetX` in `0 ms` and clamp independently within `[0, containerWidth]` at the left and right edges, with `8px` continuous corner clipping, no border or shadow, no empty placeholder box, `.allowsHitTesting(false)`, and Z-ordering above `Player Cue Queue Control Bar`.

3. **Real-Time Extraction, Keyframe Deduplication & `30ms` Debounce (`PlaybackProgressScrubber.swift`, `PlaybackViewModel.swift`)**:
   - Implemented `PlaybackTimelineThumbnailStore`:
     - Fires the first keyframe request immediately (`0 ms` debounce) upon entering the progress bar or starting a drag, showing only the time capsule until the first frame finishes decoding.
     - Checks keyframe identity (`keyframeTimestampMilliseconds(forTargetMilliseconds:)`) on pointer movement/drag: if the pointer stays within the same keyframe interval, keeps the current image, does not re-request, and does not reset any active `30ms` debounce timer.
     - Applies the `30ms` (`--delay-player-progress-thumbnail-debounce`) debounce only when crossing into a new keyframe interval, keeping the previous keyframe image visible until the new keyframe finishes decoding and replacing it in `0 ms` with no transition animation.
     - Immediately clears thumbnail state and cancels pending work when the pointer exits the progress bar (and is not dragging), when switching videos, or when playback stops.

## 3. Verification

- Executed `swift test --package-path apps/macos-native --filter "progressThumbnail|timelineThumbnailStore|nativePlaybackExtractsKeyframeTimestampsAndScaledTimelineThumbnails|WorkbenchControlMetricsTests|PlaybackMoreMenuTests|PlaybackChromeVisibilityModelTests"`.
- All 42 targeted unit and integration tests compiled cleanly and passed.
