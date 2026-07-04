# Library Card Action Menus

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Library Card Action Menus.md`
- `docs/human/design/UI.md`

## Scope

Add the documented cover action menus to Recent Watching cards, Complete
Library folder cards, and Complete Library episode rows. The episode row Play
button is removed so the row itself becomes the primary play target while the
cover action button owns its menu interaction.

## Classification

- Product semantics: Library video identity, folder identity, subtitle identity,
  and watch-state meanings remain unchanged.
- Platform UI/UX: added the cover action button, popover menus, card tap
  routing, and cover hover scale behavior documented for the Library cards.
- Platform integration: added Finder reveal/open actions and Library Context
  entry points from the card menus.
- Playback execution: unchanged; card and episode row clicks still call the
  existing Library playback path.

## Changes

- Added Library action-button and cover-hover metrics from the updated UI spec.
- Reworked Recent Watching and Complete Library folder cards from outer
  `Button` wrappers to explicit card tap gestures with independent cover action
  buttons.
- Removed the Complete Library episode row Play button and made the row tap
  open the video instead.
- Added reusable Library card action button and menu views backed by
  `WorkbenchPopoverPanel` and `WorkbenchPopoverRow`.
- Added menu actions for Open Folder, Mark as Finished, Mark as Unwatched, Mark
  as Watching, and Context according to each card type.
- Added Core support for explicitly setting Library watch state so manual
  state changes can clear `completed_at` or delete history when needed.
- Added a Core query for the first cue group in a subtitle file so Library
  Context opens at the first cue group.
- Added tests for first cue lookup and explicit watch-state transitions.

## Verification

- `git diff --check` passed.
- `swift build` passed.
- `swift test --filter setLibraryWatchStateClearsCompletedStateAndDeletesUnwatchedHistory` passed.
- `swift test --filter allCueGroupsVisiblePageReturnsDefaultOrderAndSpeakers` passed.
- `swift test --filter libraryPlaybackHistory` passed.
- `swift test` passed with 7 XCTest tests and 387 Swift Testing tests.

## Outcome

Recent Watching, Complete Library folder, and Complete Library episode cards now
provide the documented cover action menus while preserving the existing Library
playback route. Manual watch-state menu actions persist through the Library
playback history table and can move videos between Finished, Watching, and
Unwatched without leaving stale completion state behind.
