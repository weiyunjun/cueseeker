# Search Shiori Table Menu Content Hover Anchor

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Search Shiori Table Cell Interaction.md`
- `docs/human/design/UI.md`

## Scope

Adjust Search and Shiori table cell action menus so their positioning anchor
uses the triggering cell content hover rectangle instead of the full cell
rectangle. The existing menu gap token remains unchanged.

## Classification

- Product semantics: unchanged; menu actions, copied text, Shiori behavior, and
  playback still target the same row data.
- Platform UI/UX: updated row menu geometry so menu distance is measured from
  the visible hover surface.
- Platform integration: unchanged; pasteboard copying and Finder reveal
  callbacks remain the same.
- Playback execution: unchanged.

## Changes

- Reused the table cell content hover rectangle calculation for menu anchoring.
- Kept the existing fallback to full cell bounds when content hover geometry is
  unavailable.
- Kept menu spacing on `WorkbenchControlMetrics.redesignSpacing1`.
- Added virtual table regression tests for `Cues` and `Display Title` menu
  anchoring against their content hover rectangles.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTableView` passed with 31 Swift Testing tests.
- `swift test` passed with 7 XCTest tests and 386 Swift Testing tests.

## Outcome

Search and Shiori table cell action menus now measure their menu gap from the
same content hover rectangle users see under the pointer. `Cues`, `Display
Title`, `Time`, and `Date Added` keep the existing menu spacing token while no
longer inheriting extra distance from the full cell bounds.
