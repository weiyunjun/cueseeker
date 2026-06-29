# Copy Table To Clipboard

## Human-Owned Source

- `docs/human/requirements/20260629-Feature-Copy Table.md`

## Scope

Add a selected-row table copy action to the Search and Shiori table surfaces.

## Classification

- Product semantics: unchanged; copied values come from existing table row
  presentation data.
- Platform UI/UX: Search and Shiori selected-row action bars add `Copy Table`
  beside `Collage`.
- Platform integration: selected rows are loaded from the active Search/Shiori
  data source for the current result set, mapped to table presentation rows, and
  written to the macOS pasteboard as TSV text.
- Playback execution: unchanged.

## Changes

- Added shared TSV generation for subtitle table rows.
- Included visible data-column headers in copied text.
- Expanded multiline cell values into multiple spreadsheet rows, leaving
  shorter columns blank after their first populated line.
- Added `Copy Table` actions to Search and Shiori selected-row action bars.
- Updated `Copy Table` to load the current result set directly from the active
  Search/Shiori data source instead of copying from the virtualized table row
  cache.
- Added a row-selection range helper so full-table selection can be projected
  onto the loaded result range.
- Added an incremental TSV builder used by the direct data-source copy path.
- Added tests for headers, multiline cue expansion, multiline non-cue columns,
  builder appending, tag text, tab / carriage-return sanitization, and ranged
  row selection.

## Verification

- `git diff --check` passed.
- `swift test` passed. XCTest reported 7 passing CASS rendering tests, and
  Swift Testing reported 357 passing tests.

## Outcome

Search and Shiori selected-row action bars now provide `Copy Table`. The copied
TSV includes visible data-column headers and expands multiline cell content so
spreadsheet paste keeps each cue line in its own cell while shorter columns are
left blank after their first populated line. Copy Table now loads rows from the
active table data source for the current result set, so virtualized row pruning
does not remove selected rows before clipboard generation.
