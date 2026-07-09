# Playback Subtitle Focus Action Menu

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Overlay.md`
- `docs/human/design/UI.md`

## Scope

Add the cue-scoped action menu and its Shiori, copy, and continuous-play
handoffs to Playback Subtitle Focus. Removal of the previous Quick Search UI
remains a separate final implementation step.

## Classification

- Product semantics: freezes one exact selected cue group and source identity
  for every menu lookup and action.
- Platform UI/UX: adds the Player Speed Menu-style dark menu, icon-and-label
  rows, keyboard and pointer selection, disabled saved state, placement, and
  dismissal behavior.
- Platform integration: performs exact Shiori lookup and persistence off the
  main actor, writes exact cue text to the system pasteboard, and rejects stale
  Session or menu results.
- Playback execution: adds an exact continuous seek from the selected cue and
  prevents a late bounded-cue completion from pausing the new playback.

## Changes

- Added a 172-point action menu with three fixed 30-point rows: Shiori, Copy Cue
  Text, and Play From This Cue. The menu uses the existing Player Speed Menu
  surface geometry with leading action icons and flips or clamps around the
  selected cue when space is limited.
- Kept the selected cue's text, color, geometry, and Focus Anchor unchanged
  while the menu is open. A full-stage dismiss layer closes only the menu, and
  the menu consumes its own padding and disabled-row pointer input.
- Added a menu-local state model that selects the first enabled action, moves
  through enabled rows only, follows enabled hover, prevents duplicate action
  execution, and presents `Shiori Already Saved` as a disabled item.
- Opened pointer menus against the exact clicked cue without a reel animation.
  Enter opens against the selected cue after queued reel navigation completes;
  the deferred transition owns subsequent cue, wheel, and scrollbar input and
  can be cancelled independently with Escape.
- Kept cue navigation suppressed through the complete 0.22-second reel
  transition, including a queued batch whose final attempted step reaches a
  cache or document boundary.
- Reset wheel gesture ownership when the menu opens so momentum from a gesture
  begun before the menu cannot navigate after dismissal. Added a settle
  fallback for phase transitions that produce no later wheel event.
- Added exact off-main Shiori availability lookup and persistence through the
  Session-scoped database actor. Saved state updates only the menu item; a
  completed persistence invalidates Shiori table rows even if the originating
  menu or playback source was cancelled after the write committed.
- Copied the complete frozen cue text with original line order and whitespace,
  then closed the overlay and restored the captured pre-overlay playback state.
- Added continuous playback from the frozen cue start, independent of the
  captured paused state. The handoff closes the overlay without a second pause
  command and consumes bounded segment completion identity so late or duplicate
  completion callbacks cannot pause continuous playback.
- Ignored repeated Enter and Escape events while keeping Up and Down repeat
  available for navigation.
- Kept all menu, hover, pending-open, execution, and lookup state inside the
  Subtitle Focus Session and avoided legacy Shiori presentation hydration or a
  global playback feedback HUD.

## Verification

- `swift build`
  - Passed.
- `swift test --filter SubtitleFocus`
  - Passed 79 Swift Testing tests covering menu geometry and placement, exact
    cue context, enabled selection, deferred-input ownership, batch-boundary
    motion, scroll suppression, exact clipboard content, saved-state lookup,
    persistence invalidation, stale-result rejection, and Session cleanup.
- `swift test --filter SegmentCompletion`
  - Passed 11 Swift Testing tests, including continuous-play late completion
    rejection and duplicate completion consumption.
- `swift test`
  - Passed 7 XCTest tests and 516 Swift Testing tests.
- Independent read-only UI, interaction, and lifecycle reviews
  - Found no remaining priority-one issue after the reported input and
    cancellation races were corrected.
- `git diff --check`
  - Passed.

## Outcome

The selected cue now owns a precise, keyboard- and pointer-operable action menu.
Shiori, copy, and continuous-play actions use the frozen cue group, preserve the
documented playback restoration rules, and remain isolated from unrelated
workbench presentation state. The result matched the accepted action-menu and
refresh-scope requirements.
