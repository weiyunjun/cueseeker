# Search Shiori Cues Cursor Regression

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Search Shiori Table Cell Interaction.md`
- `docs/human/design/UI.md`

## Scope

Fix the Search and Shiori result table regression where `Context` or `Copy Cue
Text` menu actions could leave the Cues cell using the default cursor even
though the Cues hover background and underline were visible.

## Classification

- Product semantics: unchanged; Cues cell clicks still open the row action menu,
  and menu actions still target the same row data.
- Platform UI/UX: updated Cues pointer cursor ownership to avoid `NSCursor`
  stack interference from SwiftUI menu rows.
- Platform integration: unchanged; menu callbacks, row providers, and playback
  plumbing remain the same.

## Cause

The previous fix cleared the coordinator's internal Cues cursor flag when the
menu dismissed, then immediately recalculated hover. That made the coordinator
state look correct, but SwiftUI menu rows also pushed a cursor on hover and
popped it on disappearance. Their later pop could remove the table's newly
pushed pointing-hand cursor, leaving the coordinator flag true while the actual
cursor had reverted to the default arrow.

## Changes

- Removed Cues cell cursor ownership from the `NSCursor.push()` / `pop()` stack.
- Added visible-row Cues cursor rects to the virtual table document view.
- Refreshed the document cursor directly from document mouse events and after
  menu dismissal, after the SwiftUI menu teardown has had a run-loop turn to
  finish.
- Invalidated Cues cursor rects when table geometry, scroll position, data,
  enabled state, redesign state, menu state, or external popup state changes.
- Replaced the old internal cursor-flag tests with cursor-rect regression tests
  for visible Cues rows and menu dismissal.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTableView` passed with 24 Swift Testing tests.
- `swift test` passed with 7 XCTest tests and 378 Swift Testing tests.

## Outcome

The Cues cell pointer cursor is now owned by AppKit document cursor rects and a
direct document cursor refresh, so SwiftUI menu-row cursor teardown no longer
removes the table's Cues pointer cursor after `Context` or `Copy Cue Text`.
