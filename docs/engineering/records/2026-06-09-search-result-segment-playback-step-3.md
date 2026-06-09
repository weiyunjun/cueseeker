# Search Result Segment Playback Step 3

Date: 2026-06-09

Human requirement:

- `docs/human/requirements/20260609-Feature-Search Result Segment Playback.md`

Scope:

- Wired search-result playback to use bounded `PlaybackSegment` timing.
- Wired Shiori playback to use bounded `PlaybackSegment` timing.
- Passed cue `endMilliseconds` through both fresh video opens and same-video
  seeks.
- Left automatic next-cue navigation, Auto-play Gap, Settings UI, and user
  end-to-end acceptance for later steps.

Verification:

- Ran `git diff --check`.
- Result: passed.
- Ran `swift build` in `apps/macos-native`.
- Result: passed.
- Ran `swift test --filter CueSeekerAppTests` in `apps/macos-native`.
- Result: passed, 102 Swift Testing tests.

Outcome:

- Clicking a search result or Shiori now dispatches bounded playback for that
  cue's start-to-end range.
- Library video playback remains unbounded and unchanged.
