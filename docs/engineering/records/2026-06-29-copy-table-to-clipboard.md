# Copy Table To Clipboard

## Human-Owned Source

- `docs/human/requirements/20260629-Feature-xx.md`

## Scope

Add a selected-row table copy action to the Search and Shiori table surfaces.

## Classification

- Product semantics: unchanged; copied values come from existing table row
  presentation data.
- Platform UI/UX: Search and Shiori selected-row action bars add `Copy Table`
  beside `Collage`.
- Platform integration: selected virtual rows are hydrated before clipboard
  generation, then written to the macOS pasteboard as TSV text.
- Playback execution: unchanged.

## Changes

- Added shared TSV generation for subtitle table rows.
- Included visible data-column headers in copied text.
- Expanded multiline cell values into multiple spreadsheet rows, leaving
  shorter columns blank after their first populated line.
- Added `Copy Table` actions to Search and Shiori selected-row action bars.
- Added tests for headers, multiline cue expansion, multiline non-cue columns,
  tag text, and tab / carriage-return sanitization.

## Verification

- `git diff --check` passed.
- `swift test` passed. XCTest reported 7 passing CASS rendering tests, and
  Swift Testing reported 354 passing tests.

## Outcome

Search and Shiori selected-row action bars now provide `Copy Table`. The copied
TSV includes visible data-column headers and expands multiline cell content so
spreadsheet paste keeps each cue line in its own cell while shorter columns are
left blank after their first populated line.
