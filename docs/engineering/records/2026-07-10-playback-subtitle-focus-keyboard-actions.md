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

## Verification

- Pending implementation.

## Outcome

Pending implementation and owner end-to-end acceptance.

## Follow-ups

- The owner will run the documented end-to-end procedure after all implementation
  commits are complete.
