# Search Result Segment Playback Audio Drain Fix

Date: 2026-06-09

Human requirement:

- `docs/human/requirements/20260609-Feature-Search Result Segment Playback.md`

Issue:

- Search/Shiori bounded playback could stop before the audible cue reached the
  requested segment end.
- Native playback scheduled the final clipped audio buffer, marked the segment
  as ending, exited the decode loop, and immediately tore down the audio engine.
- Teardown stopped queued audio before it had actually played back.

Scope:

- Added native segment audio drain state so segment teardown waits for the final
  clipped audio buffer to finish playing.
- Switched final segment buffer completion to
  `AVAudioPlayerNodeCompletionDataPlayedBack` before sending the segment
  finished callback.
- Kept manual cancellation behavior intact: explicit stop/seek/open still
  cancels the drain and tears down the old session.
- Prevented the video starvation watchdog from pausing audio while a segment is
  already ending.

Verification:

- Ran `git diff --check`.
- Result: passed.
- Ran `swift build` in `apps/macos-native`.
- Result: passed.
- Ran `swift test --filter CueSeekerAppTests` in `apps/macos-native`.
- Result: passed, 107 Swift Testing tests.
- Ran `swift run NativePlayerSeekProbe --video '/Volumes/Seagate/影视/Ave Mujica/[DBD-Raws][BanG Dream! Ave Mujica][01][1080P][BDRip][HEVC-10bit][FLAC].mkv' --start 1117.82 --segment-end 1121.10 --segment-timeout 8`.
- Result: passed. Probe reported `last_audio_start_ms=1121088`,
  `last_audio_end_ms=1121100`, `segment_end_ms=1121100`, and
  `failures=0`.
- Ran `swift test` in `apps/macos-native`.
- Result: passed, 263 Swift Testing tests plus 7 XCTest tests.

Outcome:

- Bounded cue playback now waits until the clipped final audio buffer has been
  played back before reporting segment completion and tearing down native audio.
