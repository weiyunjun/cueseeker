# Media Track Start Time Offset Playback Desync

Human-owned requirement:

- `docs/human/requirements/20260629-Bug-Media Track Start Time Offset Playback Desync.md`

## Scope

This record covers the playback desync where media streams with different
`start_time` values could be normalized independently. In the reported sample,
video started later than audio/subtitles, so CueSeeker sought and displayed a
video frame from a later source timestamp while the UI, audio, and subtitles
remained at the requested time.

## Implementation

- Added a shared media timeline origin for each FFmpeg input, using the
  container start time when available and falling back to the earliest
  video/audio/subtitle stream start time.
- Converted frame timestamps, queued packet timestamps, presentation times, and
  seek targets against that shared origin instead of subtracting each stream's
  own start time.
- Applied the same timeline conversion to the native playback diagnostic probe
  so probe output and app playback use the same timing model.
- Added a regression test that generates a small MKV with audio starting at 0s
  and video starting at 2s; opening playback at 3s must still produce a video
  frame on the shared media timeline.

## Verification

- Passed: `swift build --package-path apps/macos-native`
- Passed: `swift test --package-path apps/macos-native --filter nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`
- Passed: `swift test --package-path apps/macos-native`
- Passed: `swift run --package-path apps/macos-native NativePlaybackProbe --seek 677 --quiet '/Volumes/Samsung/影视/言叶之庭/[Haruhana] Kotonoha no Niwa [BDRip][HEVC-10bit 1080p].mkv' 3`
- Passed: `swift run --package-path apps/macos-native NativePlayerSeekProbe --video '/Volumes/Samsung/影视/言叶之庭/[Haruhana] Kotonoha no Niwa [BDRip][HEVC-10bit 1080p].mkv' --seek-list 677 --seek-timeout 8`

## Outcome

CueSeeker now preserves track start offsets on one shared media timeline. Files
with delayed video, audio, or subtitle streams no longer get that stream
silently pulled earlier by per-stream normalization.
