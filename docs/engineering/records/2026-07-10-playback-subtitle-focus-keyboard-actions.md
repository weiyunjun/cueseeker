# Playback Subtitle Focus Keyboard Actions

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Keyboard Actions.md`
- `docs/human/design/UI.md`

## Scope

Replace the Playback Subtitle Focus cue action menu with direct keyboard
actions, remove cue hover and click behavior, remove normal-playback Shiori and
copy-current-subtitle commands, and move normal subtitle visibility to `Q` and
a standalone circular bottom-player button.

## Classification

- Product semantics: bind `S`, `C`, and `Space` to one exact settled focus cue
  and preserve the documented Session lifecycle.
- Platform UI/UX: remove the cue menu, cue pointer states, and two bottom-player
  commands; keep the feedback HUD above the focus overlay.
- Platform integration: keep exact cue Shiori persistence and pasteboard writes
  while removing current-playback-time command paths.
- Playback execution: reuse the existing continuous seek-and-play handoff for
  the focused cue start.

## Planned Changes

- Update stable product and testing contracts before implementation.
- Route Subtitle Focus `S`, `C`, `Space`, and `Enter` ahead of normal playback
  shortcuts, including final-settlement targeting.
- Keep `S` and `C` inside the paused focus Session and close only for `Space`.
- Remove action-menu and cue pointer interaction state without changing Up,
  Down, wheel, or scrollbar navigation.
- Remove normal-playback Shiori and copy buttons and current-timestamp command
  implementations; map normal subtitle visibility to `Q`.
- Add focused regression coverage and run the complete macOS-native suite.

## Changes

- Replaced the menu-open lifecycle with one Session-owned pending/active
  keyboard-action state machine. An action accepted during keyboard, wheel, or
  scrollbar motion freezes new navigation, captures the final settled cue, and
  is consumed atomically once.
- Routed focus-scoped `S`, `C`, and `Space` ahead of normal playback commands;
  repeated key-down events are consumed without issuing duplicate actions and
  Enter is consumed without opening UI.
- Kept Shiori save and exact cue copy inside the paused focus Session. Shiori is
  idempotent and reports saved versus already saved; copy preserves complete
  cue text and line breaks.
- Reused the existing continuous-play handoff for Space and added a dedicated
  close path that does not restore the pre-focus playback state.
- Removed the action-menu view, menu lookup state, cue hover rendering, cue hit
  rectangles, cue click activation, and pointer cursor changes while retaining
  native Up, Down, wheel, and scrollbar navigation.
- Moved the existing playback feedback layer above Subtitle Focus so S/C
  feedback remains visible without intercepting input.
- Removed the normal-playback current-timestamp Shiori and subtitle-copy
  coordinator commands, their bottom-player control closures, and their Shiori
  presentation tests. Focus-scoped persistence and clipboard primitives remain.
- Remapped normal-playback `Q` to subtitle visibility and left normal `S` and
  `C` unhandled. Removed both normal Shiori/copy buttons and their grouped
  capsule, then rendered subtitle visibility as a standalone selected-capable
  circular button.

## Verification

- `swift build`
  - Passed after the focus action, overlay, reel, and coordinator changes.
- `swift test --filter SubtitleFocus`
  - Passed 57 Swift Testing tests covering exact cue clipboard and Shiori
    behavior, idempotent persistence, feedback, keyboard and native motion
    settlement, single deferred dispatch, Down-then-S final-cue persistence,
    Space exact-target continuous-play handoff, Session cleanup, and existing
    virtual reel navigation.
- `swift test --filter SegmentCompletion`
  - Passed 11 tests, including rejection of late bounded-cue completion during
    continuous playback.
- `swift test --filter 'normalPlayback|ShioriPresentation'`
  - Passed 2 tests covering the Q subtitle toggle, no normal S/C command or
    Shiori write, and the remaining table-owned Shiori removal presentation.
- `swift test`
  - Passed all 7 XCTest tests and 466 Swift Testing tests.
- Independent read-only implementation reviews
  - Found no P0, P1, or P2 issue in the focus action state machine, async Shiori
    lifecycle, native reel settlement, feedback stacking, normal shortcut map,
    removed backend commands, or bottom-player control structure.
- Static residual audit and `git diff --check`
  - Found no active Subtitle Focus action-menu, cue hover/click, normal
    current-time Shiori/copy command, or old Q/C shortcut implementation; passed
    whitespace validation.

## Outcome

The Subtitle Focus keyboard actions, pointer removal, normal-playback command
cleanup, Q shortcut, and standalone circular subtitle button are implemented.
Automated full-suite verification is complete. Native-player and visible UI
behavior remain for owner end-to-end acceptance.

## Follow-ups

- The owner will run `docs/engineering/08_end_to_end_testing.md` §5 after all
  implementation commits are complete and report the listed evidence.
