# Table Actions Time Column

## Human-Owned Source

- `docs/human/requirements/20260630-Feature-Table Actions Time Column.md`

## Scope

Update the Search and Shiori table surfaces so row actions remain reachable at
the trailing edge of the table and cue start/end timing is presented as a
single user-facing `Time` column.

## Classification

- Product semantics: unchanged; cue start and end timing remain sourced from
  the existing subtitle and Shiori timing data.
- Platform UI/UX: Search and Shiori table column definitions, row rendering,
  header rendering, row action placement, and copied table text reflect the
  requested fixed row actions and merged time column.
- Platform integration: existing Search and Shiori hydration paths continue to
  populate start and end timing; table presentation derives the combined `Time`
  text from those fields.
- Playback execution: unchanged.

## Changes

- Replaced Search and Shiori table `Start Time` / `End Time` columns with a
  single `Time` column.
- Added shared `Time` range presentation that shows `mm:ss - mm:ss` when both
  endpoints are within hour zero and `hh:mm:ss - hh:mm:ss` otherwise.
- Updated table header, row drawing, virtual row text extraction, and Copy
  Table TSV export to use the merged `Time` value.
- Moved redesign row action buttons to fixed trailing container overlays so
  they stay left of the vertical scrollbar during horizontal scrolling.
- Updated table column visibility and virtual table tests for the merged time
  column and fixed row action placement.

## Regression Fix

- Ensured fixed redesign row action buttons are laid out when the table is
  first created and whenever the table container lays out, so returning from
  Shiori playback does not require a mouse hover before the buttons appear.
- Added a regression test that confirms container layout creates visible fixed
  row action hosts without relying on hover.

## Verification

- `git diff --check` passed.
- `swift test` passed. XCTest reported 7 passing CASS rendering tests, and
  Swift Testing reported 365 passing tests.

## Outcome

Search and Shiori now show a single `Time` column instead of separate
`Start Time` and `End Time` columns. The row action button stays fixed at the
table trailing edge during horizontal scrolling, keeping the per-row menu
reachable beside the vertical scrollbar.
