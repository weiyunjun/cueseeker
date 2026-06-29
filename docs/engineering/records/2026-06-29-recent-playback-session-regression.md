# Recent Playback Session Regression

Human-owned requirement:

- `docs/human/requirements/20260629-Bug Rrecent Playback Session Regression.md`

## Scope

This record covers the fixes for bug 2 and bug 3 from the requirement:

- Recent progress did not refresh after opening from Recent, playing, and closing.
- Recent-opened playback could not navigate to the previous or next video.

The reported audio/video sync issue is intentionally left for a later discussion
and is not changed by this implementation.

## Implementation

- Added a Recent-specific Library open path that loads the full folder detail
  before opening playback, then seeds the Library playback navigation list with
  same-folder videos.
- Updated the Recent card action to use the Recent-specific open path.
- Refreshed Recent Watching data after a synchronous Library playback-history
  save on playback close, so the visible Recent progress reflects the saved
  position.
- Added focused regression tests for same-folder Recent navigation preparation
  and Recent progress refresh after playback close.

## Verification

- Passed: `swift test --filter RecentPlayback`

## Outcome

Recent-opened playback now prepares same-folder Library navigation before
opening, and closing Library playback refreshes visible Recent progress after
the saved history write. The audio/video sync report remains unresolved for a
separate follow-up.
