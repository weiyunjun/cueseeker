# Search Result Segment Playback Gap Subtitle Hold

Date: 2026-06-09

Human requirement:

- `docs/human/requirements/20260609-Feature-Search Result Segment Playback.md`

Scope:

- Added subtitle presentation hold state for Auto Switch gap playback.
- Kept native cue playback ending at the exact cue end timestamp.
- During the Auto Switch gap, the visible subtitle presentation uses the cue
  interior timestamp immediately before the cue end.
- Applied the hold to both the Swift subtitle overlay and source-faithful ASS
  subtitle rendering.
- Cleared the hold when starting another cue, clearing cue playback, seeking,
  pausing, scrubbing, stopping playback, or disabling Auto Switch.
- Added tests covering subtitle hold/clear and AppCoordinator gap behavior.

Verification:

- Ran `git diff --check`.
- Result: passed.
- Ran `swift build` in `apps/macos-native`.
- Result: passed.
- Ran `swift test --filter CueSeekerAppTests` in `apps/macos-native`.
- Result: passed, 111 Swift Testing tests.
- Ran `swift test` in `apps/macos-native`.
- Result: passed, 275 Swift Testing tests plus 7 XCTest tests.

Outcome:

- Auto Switch Gap now preserves the just-played cue subtitle for follow-along
  practice without changing the precise segment end used by playback.
