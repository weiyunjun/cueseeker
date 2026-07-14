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

## Planned Step 2

Require the decode loop to be blocked waiting for an empty packet queue before
the video-starvation watchdog may pause audio. Preserve the existing 120 ms
threshold and the existing clock rebasing and resume behavior for genuine input
starvation.
