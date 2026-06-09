# Search Result Segment Playback Step 2

Date: 2026-06-09

Human requirement:

- `docs/human/requirements/20260609-Feature-Search Result Segment Playback.md`

Scope:

- Added native diagnostic counters for the last submitted video frame, last
  scheduled audio range, and segment-finished notification count.
- Extended `NativePlayerSeekProbe` with a bounded segment mode using
  `--segment-end`.
- Verified bounded playback directly against the native playback kernel instead
  of relying on end-to-end UI observation.
- Kept UI settings, Auto-play Gap behavior, automatic next-cue navigation, and
  user end-to-end acceptance outside this step.

Verification:

- Ran `git diff --check`.
- Result: passed.
- Ran `swift build` in `apps/macos-native`.
- Result: passed.
- Generated `/private/tmp/cueseeker_segment_probe.mp4` with `ffmpeg`.
- Ran `.build/debug/NativePlayerSeekProbe --video /private/tmp/cueseeker_segment_probe.mp4 --start 0.400 --segment-end 1.250 --segment-timeout 5`.
- Result: passed.

Observed probe result:

- Last submitted video frame: `1233ms`, before segment end `1250ms`.
- Last scheduled audio end: `1250ms`, not after segment end `1250ms`.
- Segment-finished event count: native `1`, delegate `1`.

Outcome:

- Step 2 adds direct verification coverage for precise segment stopping.
- The next implementation step can wire bounded playback into search/Shiori
  result click flows while still leaving automatic next-cue navigation and
  settings for later steps.
