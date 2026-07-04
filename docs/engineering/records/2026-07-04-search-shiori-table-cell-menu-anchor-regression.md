# Search Shiori Table Cell Menu Anchor Regression

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Search Shiori Table Cell Interaction.md`
- `docs/human/design/UI.md`

## Scope

Fix the Search and Shiori result table regression where clicking `Display
Title`, `Time`, or `Date Added` opened the correct column-specific menu content
but visually anchored every menu to the `Cues` column.

## Classification

- Product semantics: unchanged; row identity, copied text, playback, and Shiori
  actions still target the same row data.
- Platform UI/UX: corrected row menu positioning so the menu anchor follows the
  triggering data cell.
- Platform integration: unchanged; pasteboard copying and Finder reveal
  callbacks remain the same.
- Playback execution: unchanged.

## Cause

The cell menu click path correctly identified the triggering column and passed
that column into menu construction. The positioning path then ignored that
column and recalculated the menu trigger frame from the `Cues` cell. The same
hard-coded `Cues` frame was also used when repositioning an already-open row
menu after layout changes.

## Changes

- Stored the triggering column ID in the active row menu anchor.
- Resolved row menu trigger frames from the stored column ID for both initial
  menu display and open-menu repositioning.
- Added a virtual table regression test that verifies a `Display Title` menu is
  anchored to the `Display Title` column rather than the `Cues` column.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTableView` passed with 30 Swift Testing tests.
- `swift test` passed with 7 XCTest tests and 385 Swift Testing tests.

## Outcome

Column-specific Search and Shiori table menus now anchor to the triggering data
cell. `Display Title`, `Time`, and `Date Added` no longer visually attach their
menus to the `Cues` column.
