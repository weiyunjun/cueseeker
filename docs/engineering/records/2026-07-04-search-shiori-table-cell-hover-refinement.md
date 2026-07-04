# Search Shiori Table Cell Hover Refinement

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Search Shiori Table Cell Interaction.md`
- `docs/human/design/UI.md`

## Scope

Refine the Search and Shiori result table cell hover behavior after the
accepted cell-interaction change. Hover surfaces now follow visible content
bounds, use the shared hover background token, and preserve the Cues text
underline and pointer cursor behavior.

## Classification

- Product semantics: unchanged; row identity, menu actions, Shiori operations,
  and playback requests still target the same row data.
- Platform UI/UX: updated table content hover drawing, header hover drawing,
  Cues text decoration, and cursor state recovery after menu actions.
- Platform integration: unchanged; menu action callbacks and table data sources
  remain the same.
- Playback execution: unchanged; playback continues through the existing `Play`
  menu action.

## Changes

- Changed data-cell hover drawing from full cell bounds to visible text or tag
  content bounds.
- Switched cell hover background drawing from the row hover token to the normal
  background hover token.
- Removed the redesign header area's full-width hover fill while keeping the
  sortable header trigger hover surface.
- Restored the Cues text underline when the Cues cell is hovered or menu-open.
- Cleared the internal Cues cursor state when dismissing row/header menus before
  recalculating hover, so Cues hover can re-apply the pointing cursor after menu
  item clicks.
- Added a virtual table regression test for menu dismissal clearing the Cues
  cursor state.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTableView` passed with 24 Swift Testing tests.
- `swift test` passed with 7 XCTest tests and 377 Swift Testing tests.

## Outcome

Search and Shiori table hover styling now matches the refined human-owned UI
rules, and Cues hover recovers the pointing cursor after `Copy Cue Text` or
`Context` menu actions.
