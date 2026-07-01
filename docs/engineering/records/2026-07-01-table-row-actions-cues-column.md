# Table Row Actions Cues Column

## Human-Owned Source

- `docs/human/requirements/20260701-Bug-Table Row Actions Cues Column.md`
- `docs/human/design/UI.md`

## Scope

Move Search and Shiori row action triggers out of the table-level overlay and
into the trailing area of each row's `Cues` cell.

## Classification

- Product semantics: unchanged; row actions still operate on the same Search
  or Shiori row data.
- Platform UI/UX: row action placement, drawing, hit testing, hover state, and
  menu anchoring now belong to the `Cues` cell.
- Platform integration: unchanged; existing Search and Shiori hydration paths
  still provide row models.
- Playback execution: unchanged.

## Changes

- Removed the redesign path that created one `NSHostingView<CueHoverButtons>`
  per visible row action.
- Added AppKit drawing for the row action trigger inside the trailing area of
  the `Cues` cell.
- Updated Cues text layout and hit testing so cue text does not overlap the row
  action trigger and clicking the trigger does not start playback.
- Re-anchored the row action menu from the Cues-cell trigger frame instead of a
  fixed table-edge overlay frame.
- Updated virtual table tests to verify the trigger follows the Cues column
  during horizontal scrolling and that container layout no longer creates row
  action host views.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTableView` passed.
- `swift test` passed. XCTest reported 7 passing CASS rendering tests, and
  Swift Testing reported 365 passing tests.

## Outcome

Search and Shiori row action triggers are now drawn as part of each visible
`Cues` cell. They follow row scrolling through the normal table drawing path
and no longer allocate SwiftUI hosting views per visible row.
