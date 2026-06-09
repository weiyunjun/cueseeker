# Search Result Segment Playback Auto Switch Wording

Date: 2026-06-09

Human requirement:

- `docs/human/requirements/20260609-Feature-Search Result Segment Playback.md`

Scope:

- Updated search result and Shiori playback so cue segment bounds are applied
  only when `Auto Switch to Next Search Result or Shiori Cues` is enabled.
- When the setting is off, opening a search result or Shiori seeks to the cue
  start and keeps playing the current video normally.
- Kept the existing bounded cue playback path for the enabled auto-switch
  sequence.
- Updated Play settings UI wording from `Auto-play` to `Auto Switch` for the
  sequence toggle and gap field.
- Added AppCoordinator coverage for the setting-dependent segment-bound
  decision.

Verification:

- Ran `git diff --check`.
- Result: passed.
- Ran `swift build` in `apps/macos-native`.
- Result: passed.
- Ran `swift test --filter CueSeekerAppTests` in `apps/macos-native`.
- Result: passed, 108 Swift Testing tests.
- Ran `swift test` in `apps/macos-native`.
- Result: passed, 264 Swift Testing tests plus 7 XCTest tests.

Outcome:

- The Play setting now matches the updated requirement wording: disabling Auto
  Switch means cue playback continues as normal video playback after the cue
  end, while enabling it keeps the precise bounded cue sequence behavior.
