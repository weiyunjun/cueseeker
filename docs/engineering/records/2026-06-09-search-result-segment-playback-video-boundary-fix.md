# Search Result Segment Playback Video Boundary Fix

Date: 2026-06-09

Human requirement:

- `docs/human/requirements/20260609-Feature-Search Result Segment Playback.md`

Issue:

- The previous audio drain fix made bounded cue audio and subtitle timing reach
  the requested segment end, but video could freeze on an earlier frame.
- Native playback still set the global segment-ending flag as soon as the final
  clipped audio buffer was scheduled.
- That flag stopped the decode loop before video frames near the segment end
  were decoded and submitted.
- The existing `NativePlayerSeekProbe` segment check only required the last
  video frame to be before the segment end, so a large early video gap was not
  treated as a failure.

Scope:

- Split native segment completion into separate audio and video boundaries.
- Audio reaching the segment end now stops further audio scheduling without
  stopping video decode.
- Video reaching the segment end now stops further video scheduling without
  stopping audio drain.
- Segment completion and native teardown now happen only after both boundaries
  are satisfied and the final clipped audio buffer has played back.
- Updated `NativePlayerSeekProbe` to fail segment playback when the last
  submitted video frame is more than 100 ms before the requested segment end.

Verification:

- Ran `git diff --check`.
- Result: passed.
- Ran `swift build` in `apps/macos-native`.
- Result: passed.
- Ran `swift run NativePlayerSeekProbe --video '/Volumes/Seagate/影视/Ave Mujica/[DBD-Raws][BanG Dream! Ave Mujica][01][1080P][BDRip][HEVC-10bit][FLAC].mkv' --start 1117.82 --segment-end 1121.10 --segment-timeout 8`.
- Result: passed. Probe reported `last_video_ms=1121078`,
  `last_video_gap_ms=22`, `last_audio_start_ms=1121088`,
  `last_audio_end_ms=1121100`, and `failures=0`.
- Ran `swift test --filter CueSeekerAppTests` in `apps/macos-native`.
- Result: passed, 107 Swift Testing tests.
- Ran `swift test` in `apps/macos-native`.
- Result: passed, 263 Swift Testing tests plus 7 XCTest tests.

Outcome:

- Bounded cue playback now keeps video advancing to the segment end while still
  preserving exact final audio clipping and finish notification timing.
