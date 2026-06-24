# Search Shiori Cue Time Columns

## Human-Owned Source

- `docs/human/requirements/20260624-Feature-Search Shiori Cue Time Columns.md`

## Scope

Update the Search and Shiori table surfaces so cue timing is visible as table
columns while keeping `Cues` locked visible in the View menu.

## Classification

- Product semantics: cue start and end milliseconds are exposed as user-facing
  cue time text.
- Platform UI/UX: Search and Shiori table column definitions, visibility menu
  entries, header rendering, row rendering, and copied table text include the
  requested time columns.
- Platform integration: existing Search and Shiori row hydration sources remain
  unchanged; table row mapping derives display text from the existing cue
  timing fields.
- Playback execution: unchanged.

## Changes

- Added `Start Time` and `End Time` display text to subtitle table row models.
- Formatted cue times as `hh:mm:ss` for hour-long timestamps and `mm:ss` when
  the hour value is zero.
- Changed Search default columns to Display Title, Start Time, End Time, and
  Cues.
- Changed Shiori default columns to Date Added, Display Title, Start Time, End
  Time, and Cues.
- Kept `Cues` locked in the column visibility menu while allowing the other
  configured columns to be hidden.
- Kept Start Time and End Time out of the filter builder because the current
  core filter model does not support cue-time fields.
- Updated table and row model tests for column ordering, text extraction, and
  cue-time formatting.

## Verification

- `git diff --check` passed.
- `swift test` passed. XCTest reported 7 passing CASS rendering tests, and
  Swift Testing reported 339 passing tests.

## Outcome

Search and Shiori now expose cue start and end times as first-class table
columns, with `Cues` remaining locked visible and time fields excluded from
unsupported filter-builder choices.
