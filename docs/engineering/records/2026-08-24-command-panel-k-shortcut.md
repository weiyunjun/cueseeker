# Command Panel opens with the K key

Human-owned documents:

- `docs/human/requirements/20260824-UI-Command Panel Keyboard Shortcut K.md`
- `docs/human/design/Controller.md`

## Why

Command Panel was opened with the backtick key. The Debug E2E controller's
`keyPress` only accepts letters, digits and a few named keys, so no automated
end-to-end procedure could ever reach Command Panel. Moving the entry key to a
letter removes that blind spot without adding new E2E capability.

## What changed

The playback key handler now opens Command Panel on `K` instead of backtick,
under the same conditions as before: no modifier keys and no editable text
focus. Backtick no longer opens the panel.

The controller Options button maps to the new entry key. It no longer carries a
character fallback, so pressing Options while the Command Panel search field has
focus produces no text; the button is now only an entry key, as the requirement
states.

Nothing else about Command Panel changed: closing, page navigation, search
behaviour and focused-cue prefill are untouched.

Files: `AppCoordinator+Playback.swift`, `AppCoordinator+ControllerInput.swift`,
`PlaybackSubtitleFocusKeyboardActionTests.swift`.

## Verification

- `swift build` clean.
- `swift test` filtered to the playback keyboard and Command Panel tests: 34
  tests green. Coverage includes `K` opening the root page, Escape closing it,
  backtick no longer opening it, `K` with Shift or with editable focus not
  opening it, the Collage editing state still swallowing the key, and the
  Options button producing no text action while the panel root is open.
- Full `swift test`: the failing tests are the same media-decode, window-scene
  and refresh-timing cases that also fail on the unmodified tree; the failing
  set was compared against a stashed baseline run and rotates between runs on
  both trees.

## Outcome

Matched expectations at unit level. In-app confirmation of acceptance criteria
1, 3, 4 and 5 (keyboard, search-field typing, controller Options, and Debug E2E
`keyPress k`) has not been run yet.
