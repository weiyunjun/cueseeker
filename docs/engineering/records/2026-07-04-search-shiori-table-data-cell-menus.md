# Search Shiori Table Data Cell Menus

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Search Shiori Table Cell Interaction.md`
- `docs/human/design/UI.md`

## Scope

Extend the accepted Search and Shiori result table cell-menu interaction from
`Cues` to the `Display Title`, `Time`, and `Date Added` data cells. The new
menus provide the first supported actions for those cells while keeping the
menu structure extensible for future column-specific actions.

## Classification

- Product semantics: unchanged; row identity, cue content, displayed titles,
  timestamps, and date-added strings keep their existing meanings.
- Platform UI/UX: updated data-cell hit testing, cursor rects, menu routing,
  menu content, and active-cell hover state.
- Platform integration: added platform actions for copying displayed cell text
  to the pasteboard and revealing the source subtitle file in Finder.
- Playback execution: unchanged; playback remains available from the existing
  `Cues` menu `Play` action.

## Changes

- Added subtitle file paths to the table row model so `Display Title` can reveal
  the source subtitle file.
- Routed subtitle paths from Search and Shiori row-model sources into
  `SubtitleTableRow`.
- Generalized data-cell menu routing from the `Cues` cell to the documented
  menu-capable columns.
- Added `Display Title` menu rows for `Open Folder` and `Copy Text`.
- Added `Time` and `Date Added` menu rows for `Copy Text`.
- Generalized pointer cursor rects from the `Cues` cell to all current
  menu-capable data cells.
- Added virtual table tests for the new cell menu triggers, cell text copying,
  and subtitle file reveal callback.

## Verification

- `git diff --check` passed.
- `swift test --filter tableSandboxRowModelStore` passed with 19 Swift
  Testing tests.
- `swift test --filter subtitleTableView` passed with 29 Swift Testing tests.
- `swift test` passed with 7 XCTest tests and 384 Swift Testing tests.

## Outcome

Search and Shiori table data cells now have column-specific action menus for
the documented `Display Title`, `Time`, and `Date Added` cells. The table can
reveal a subtitle file from the Display Title menu and copy displayed cell text
without changing row identity, cue playback behavior, or existing Cues actions.
