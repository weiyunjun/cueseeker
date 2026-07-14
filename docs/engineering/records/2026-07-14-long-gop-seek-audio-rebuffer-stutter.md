# Long GOP Seek Audio Rebuffer Stutter

Date: 2026-07-14

Human-owned requirement:

- `docs/human/requirements/20260714-Bug-Long GOP Seek Audio Rebuffer Stutter.md`

## Scope

Diagnose and fix repeated audio interruptions after opening or seeking to a
subtitle result inside a long GOP. Preserve the existing behavior that pauses
audio when media input actually starves, and keep the shared native playback
path for Search, Shiori, Library, bounded segments, and timeline seeks.

## Step 1: Rebuffer Diagnostics

- Added per-session native counters for rebuffer count, last rebuffer duration,
  and whether the decode loop was blocked waiting for an empty compressed-packet
  queue when the rebuffer began.
- Marked only the blocking wait inside the packet dequeue loop as
  `waiting_for_packet`; decoder preroll, frame reordering, and video pacing do
  not set that state.
- Added `waiting_for_packet` to the existing rebuffer log.
- Extended `NativePlayerSeekProbe` with a post-seek observation interval and
  included the new counters in its snapshots.
- This step does not change rebuffer decisions, playback clocks, seek behavior,
  startup waterlines, or audio scheduling.

## Step 1 Evidence

Baseline commit: `19a8db1`

Target media:

- `/Volumes/Samsung/影视/赛马娘 第1季/[Nekomoe kissaten][Uma Musume][01][1080p][JPSC].mp4`
- Reported result: `756.240s` to `759.050s`

Different-video/open-equivalent bounded playback reproduced three rebuffer
events. All three began with `waiting_for_packet=no`; their measured durations
were 136 ms, 93 ms, and 79 ms. The final counters reported
`rebuffer_count=3`.

Same-session seek from `752.100s` to `756.240s`, followed by a 3.5 second
observation window, also reproduced three rebuffer events. All three began with
`waiting_for_packet=no`; the seek remained in one session and the probe itself
passed with `open_count=1` and `in_session_seek_count=1`.

This proves the reported interruptions are false starvation decisions: video
frame output exceeds the 120 ms watchdog threshold while the decode loop is
still processing available media data rather than waiting for input.

The bounded probe delivered the exact requested audio end and one segment
completion callback, but its pre-existing strict video assertion rejects a
last submitted frame exactly equal to the segment end. That assertion is
separate from this audio-stutter diagnosis and is not being treated as a
playback failure here.

## Step 1 Verification

- `git diff --check`: passed.
- `swift build` in `apps/macos-native`: passed.
- `swift test --filter nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`:
  passed, 1 test.
- Target bounded open-equivalent probe: reproduced three false rebuffer events,
  all with `waiting_for_packet=no`.
- Target in-session seek probe with `--post-seek-observation 3.5`: passed and
  reproduced three false rebuffer events, all with `waiting_for_packet=no`.

## Root Cause

The false watchdog decision was real, but gating that decision alone was not a
complete fix. Video and audio decoding shared one serial loop. Long-GOP video
preroll and normal video pacing could occupy that loop for 100-250 ms at a
time, so no new audio PCM reached `AVAudioPlayerNode` during those intervals.
The player node also began on the first scheduled buffer without a minimum PCM
reserve. Removing only the false pause therefore left an audible PCM underrun
path.

The affected file makes this deterministic because the seek starts at the
previous keyframe near `752.085s`, about 100 video frames before the requested
cue. Its interleaving also contains roughly 0.5-second packet blocks and a
roughly 1.0-second consecutive video block around the target. Those are valid
media characteristics, not input starvation.

## Step 2: Playback Fix

- Kept demux as the only `av_read_frame` owner and split its bounded read-ahead
  storage into video and audio compressed-packet queues. The existing 64 MB cap
  remains global, while the 10-second high-water decision now requires coverage
  from both active streams.
- Kept video decode and pacing on the existing decode queue. Added an
  event-driven serial audio feeder that exclusively owns audio decode,
  resampling, PCM scheduling, and player-node control. The feeder never waits on
  another queue and returns whenever it reaches high water or has no work.
- Added wall-time PCM waterlines: 350 ms to prime, 750 ms to request refill, and
  1.5 seconds as the scheduled high water. The media duration is divided by the
  active playback rate, so 0.5x and 2.0x use the same audible reserve policy.
- Added a first-video/PCM priming barrier. Audio is scheduled but cannot start
  until the first target video frame and the PCM prime condition are both
  available. Audio and video share the seek timestamp as their media-clock
  anchor; delayed track starts retain their actual media-time offset through
  `playAtTime:` rather than being forced to the same host instant.
- Limited the existing video-starvation watchdog to the state where video is
  actually blocked on an empty video packet queue. Video decoder work, frame
  reordering, PCM priming, and video pacing cannot trigger a rebuffer pause.
- Added a playback generation to seek and teardown. Audio work and
  `DataPlayedBack` callbacks from an old generation cannot mutate the new seek,
  complete its segment, or restart its player node.
- Committed low-water accounting and played-back diagnostics immediately on the
  completion callback, then serialized only lifecycle actions back through the
  audio feeder. A pending-record token makes natural `audioOutputDrained`
  publication occur only after the matching segment action is committed;
  failed seeks reconcile an interrupted segment drain, while cancellation and
  successful generation changes return or reset the token.
- Made the shared segment-boundary, playback-rate, and pause-after-first-frame
  fields atomic while retaining compound clocks and segment state under their
  existing locks. The lock order remains packet condition followed by session
  state, with no reverse acquisition or synchronous queue cycle.
- Preserved final-segment completion at
  `AVAudioPlayerNodeCompletionDataPlayedBack`. Natural EOF now waits for the
  remaining scheduled PCM to drain, while cancellation and session replacement
  wake and terminate that wait.
- Preserved `pauseAfterFirstFrame`: the first requested frame can be displayed
  without starting audio, and bounded PCM can remain primed for the later
  explicit resume.

## Step 2 Diagnostics

- Added counters for PCM buffers that reach `DataPlayedBack`, unexpected
  running-state PCM drains, and completed segment audio drains.
- Extended `NativePlayerSeekProbe` with exact assertions for rebuffer count,
  unexpected drain count, segment drain count, and actual audio playback
  progress. Per-seek output reports counter deltas after the requested
  observation window.
- Made pause-after-first-frame require an exact zero played-back delta, and made
  natural-EOF/reopen verification retain the completed session's counters and
  audio progress instead of inspecting only the replacement session.
- Required a paused observation of at least 250 ms and, for bounded probes that
  require audio progress, required the final scheduled audio end to land within
  100 ms before the segment endpoint. A logical drain alone therefore cannot
  hide an audio track that ended materially early.
- Added a playback-rate option to exercise the wall-time waterline at 0.5x,
  1.0x, and 2.0x.
- Changed the diagnostic last-video timestamp to floor milliseconds. This keeps
  a valid frame just below a half-open segment end from being rounded to the
  excluded endpoint.

## Step 2 Verification

Build and focused tests:

- `git diff --check`: passed.
- `swift build --package-path apps/macos-native`: passed.
- Isolated
  `nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`: passed.
- The final complete run passed all 633 tests. A preceding run reported the
  unrelated shared-preferences migration expectation in
  `ApplicationPersistenceTests.swift:29` (`"search"` versus `"shiori"`), but
  the final run passed it without any persistence-source change. The native
  common-timeline fixture passed both in isolation and in the final complete
  run.

Reported local target:

- Bounded playback from `756.240s` through `759.050s` passed 10 of 10 runs.
  Every run reported 132 played-back PCM buffers, zero rebuffer events, zero
  unexpected PCM drains, one expected segment audio drain, one native segment
  completion, and one delegate segment completion.
- Same-session seek from `752.100s` to `756.240s` passed 10 of 10 seeks in one
  session. Every one-second observation reported 43-45 played-back PCM buffers,
  zero rebuffer events, and zero unexpected drains. Final counters were
  `open_count=1` and `in_session_seek_count=10`.
- A final three-seek run after the completion-record concurrency audit also
  passed in one session. Its observation windows recorded 43, 44, and 42
  played-back buffers with zero rebuffer events and zero unexpected drains.
- The target pause-after-first-frame seek passed with zero played-back PCM
  buffers during its 300 ms paused observation, proving that priming does not
  produce an audible start.
- The target timeline-scrub seek passed with 42 played-back buffers during the
  one-second observation, zero rebuffer events, and zero unexpected drains.
- The target bounded segment passed at both 0.5x and 2.0x. Each run retained
  zero rebuffer events, zero unexpected drains, and one expected segment drain.

Other paths:

- A generated two-second A/V fixture reached natural EOF and reopened at
  `1.000s` with `open_count=2`, `in_session_seek_count=0`, 86 played-back
  buffers retained from the completed session, 17 from the replacement
  session, zero rebuffer events, and zero unexpected drains.
- A mounted Synology WebM passed a same-session seek from `60s` to `120s` with
  145 played-back buffers during the three-second observation, zero rebuffer
  events, and zero unexpected drains.
- A controlled network-jitter injector was not available in this workspace.
  Genuine forced-stall behavior therefore remains a separate read-ahead gate;
  the existing starvation pause mechanism was retained and narrowed to a real
  empty-video-queue wait.

## Outcome

Automated verification matches the reported bug's measurable acceptance
criteria: no false rebuffer cycle, no unexpected PCM drain, actual audio output
progress, and exact final-segment drain. Human end-to-end listening remains
pending under `docs/engineering/08_end_to_end_testing.md`.
