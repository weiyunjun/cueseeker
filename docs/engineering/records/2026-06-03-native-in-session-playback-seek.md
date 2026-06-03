# Native In-Session Playback Seek

Date: 2026-06-03

Human-owned document:

- `docs/human/requirements/20260603-Feature-Native InSession Playback Seek.md`

## Scope

- Changed `SFXNativePlaybackPlayer.seekToMilliseconds` to seek inside the
  current `SFXNativePlaybackSession` instead of reopening the current path.
- Added a session seek request path that is handled by the decode loop itself.
  The seek path stops read-ahead, clears queued packets, seeks the FFmpeg input,
  flushes video/audio decoders, clears pending display/audio output, resets
  playback clocks, and restarts read-ahead.
- Preserved the different-video `openPath` path. Opening a path still creates a
  new native playback session.
- Cancelled pending timeline scrub preview requests before a formal in-session
  seek, matching the old reopen behavior.
- Added native counters for session opens, in-session seeks, and submitted video
  frames so probes can verify session boundaries.
- Added `NativePlayerSeekProbe` to exercise `SFXNativePlaybackPlayer` directly.

## Boundary

- This change does not alter Swift-level same-video versus different-video
  routing. The existing Swift layer already routes same-video actions to seek
  and different-video actions to open.
- This change does not change file indexing, subtitle matching, FFmpeg
  packaging, or cross-platform playback design.

## Pre-Change Baseline

- Source baseline: `SFXNativePlaybackPlayer.seekToMilliseconds` called
  `openPath` with the current path, so same-video native seek reopened the
  native session.
- `swift test --package-path apps/macos-native` passed 7 XCTest tests and 180
  Swift Testing tests before the change. The run printed existing non-fatal disk
  I/O and empty MKV probe diagnostics.
- `NativePlaybackProbe --seek-list 10,180,40,900 --seek-list-loops 2` on the
  reported Attack on Titan EP21 sample passed with 8 seek operations, 24 output
  video frames, 0 packet send failures, and 386 skipped preroll video frames.
- `NativePlaybackProbe --seek-list 0,30,60 --seek-list-loops 2` on the reported
  Attack on Titan EP01 sample passed with 6 seek operations, 18 output video
  frames, 0 packet send failures, and 34 skipped preroll video frames.

## Verification

- `swift build --package-path apps/macos-native` passed.
- `NativePlayerSeekProbe` on the reported Attack on Titan EP21 sample with
  `--seek-list 10,180,40,900 --seek-list-loops 2` passed:
  - final `open_count=1`
  - final `in_session_seek_count=8`
  - final `frame_count=42`
  - every seek submitted a new frame after the seek target
  - failures: 0
- `NativePlayerSeekProbe` on the reported Attack on Titan EP01 sample with
  `--seek-list 0,30,60 --seek-list-loops 2 --pause-after-first-frame` passed:
  - final `open_count=1`
  - final `in_session_seek_count=6`
  - final `frame_count=23`
  - every seek ended with `playing=no`
  - failures: 0
- `NativePlayerSeekProbe` with
  `--timeline-scrub-before-seek --pause-after-first-frame` passed on EP01:
  - final `open_count=1`
  - final `in_session_seek_count=6`
  - final `frame_count=23`
  - this confirms formal seek clears the read-ahead suspension used by timeline
    scrubbing.
- `NativePlayerSeekProbe` on a regular MKV sample
  (`Unnatural.EP10.1080p.NF.WEB-DL.AAC2.0.H.264-MagicStar.mkv`) passed:
  - final `open_count=1`
  - final `in_session_seek_count=6`
  - final `frame_count=42`
  - failures: 0
- `NativePlayerSeekProbe` on an MP4 sample
  (`Harry.Potter.and.the.Prisoner.of.Azkaban.2004.1080p.BrRip.x264.YIFY.mp4`)
  passed:
  - final `open_count=1`
  - final `in_session_seek_count=6`
  - final `frame_count=32`
  - failures: 0
- `NativePlaybackProbe --seek-list 10,180,40,900 --seek-list-loops 2` on EP21
  still passed with 8 seek operations, 24 output video frames, and 0 packet send
  failures.
- `NativePlaybackProbe --seek-list 0,30,60 --seek-list-loops 2` on EP01 still
  passed with 6 seek operations, 18 output video frames, and 0 packet send
  failures.
- `swift test --package-path apps/macos-native` passed 7 XCTest tests and 180
  Swift Testing tests after the change. The run still printed existing non-fatal
  disk I/O and empty MKV probe diagnostics.

## Outcome

- Same-video native seek now stays inside one native playback session.
- Different-video playback open remains session-creating.
- Automated probes cover normal playback seek, pause-after-first-frame seek,
  timeline-scrubbing seek, the reported MKV files, a regular MKV, and an MP4.
