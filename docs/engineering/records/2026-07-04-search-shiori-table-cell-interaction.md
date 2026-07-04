# Search Shiori Table Cell Interaction

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Search Shiori Table Cell Interaction.md`
- `docs/human/design/UI.md`

## Scope

Update the Search and Shiori result table interaction so row-level hover and
selected backgrounds are no longer drawn in the redesign table. Data cells own
their hover surface, and the `Cues` cell opens the row action menu instead of
starting playback directly.

## Classification

- Product semantics: unchanged; row models, cue identity, Shiori behavior, and
  copy/remove semantics still operate on the same data.
- Platform UI/UX: updated table drawing, hover state, hit testing, cursor
  behavior, and menu anchoring.
- Platform integration: unchanged; existing Search and Shiori table plumbing
  still supplies rows and callbacks.
- Playback execution: unchanged; playback still uses the existing row playback
  callback, now invoked from the menu's `Play` item.

## Changes

- Removed redesign full-row hover and selected background drawing while keeping
  horizontal dividers.
- Added per-data-cell hover tracking and rounded cell hover backgrounds using
  the table hover color.
- Removed the drawn `Cues` ellipsis action button and its hit target.
- Changed `Cues` cell clicks to open the row action menu and added `Play` as
  the first menu item.
- Kept the `Cues` pointer cursor while removing hover underline decoration.
- Updated virtual table tests to verify the removed action button and the new
  Cues-cell menu entry behavior.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTableView` passed with 23 Swift Testing tests.
- `swift test` passed with 7 XCTest tests and 376 Swift Testing tests.

## Outcome

The Search and Shiori table now uses cell-owned hover surfaces and treats the
`Cues` cell as the menu trigger. Playback is available from the menu without
changing playback execution behavior.
