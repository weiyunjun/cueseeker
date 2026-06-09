# Search Result Segment Playback Segment Completion Fix

Date: 2026-06-09

Human requirement:

- `docs/human/requirements/20260609-Feature-Search Result Segment Playback.md`

Issue:

- Search/Shiori bounded playback stopped at the cue end, but the App state did
  not know the segment had completed.
- Pressing Play after a completed bounded segment called `setPaused(false)` on
  the completed native segment instead of replaying the current cue.

Scope:

- Forwarded native segment completion from `PlaybackViewModel` back to
  `AppCoordinator`.
- Tracked whether the current Search/Shiori cue segment has finished.
- Replayed the current Search/Shiori cue when the user presses Play after a
  finished bounded segment.
- When `Auto-play Search Result or Shiori Cues` is enabled, scheduled the next
  Search/Shiori cue after the persisted Auto-play Gap.
- Cancelled pending auto-play tasks when the user manually opens another cue,
  pauses playback, or enters Library playback.
- Added regression tests for segment completion forwarding and App paused-state
  handling.

Verification:

- Ran `git diff --check`.
- Result: passed.
- Ran `swift build` in `apps/macos-native`.
- Result: passed.
- Ran `swift test --filter CueSeekerAppTests` in `apps/macos-native`.
- Result: passed, 107 Swift Testing tests.
- Ran `swift test` in `apps/macos-native`.
- Result: passed, 263 tests.

Outcome:

- Completed bounded Search/Shiori cue playback no longer leaves the Play button
  stuck on an already-ended segment.
- Auto-play now has the state hook needed to advance after the configured gap.
