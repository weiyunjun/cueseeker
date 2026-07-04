# Search Shiori Table Hover Geometry Correction

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Search Shiori Table Cell Interaction.md`
- `docs/human/design/UI.md`

## Scope

Correct the Search and Shiori result table cell hover geometry after screenshot
review showed the multi-line `Cues` hover drawing as separate per-line shapes
instead of one UI-standard rounded rectangle.

## Classification

- Product semantics: unchanged; row identity, menu actions, copy actions, and
  playback requests still target the same row data.
- Platform UI/UX: updated data-cell hover geometry and hover metrics.
- Platform integration: unchanged; table data sources, menu callbacks, and
  playback plumbing remain the same.

## Changes

- Changed text hover drawing to use one rounded rectangle around the union of
  visible text line bounds.
- Changed tag-cell hover drawing to use one rounded rectangle around the union
  of laid-out tag bounds.
- Added shared control metrics for the table cell hover radius and padding
  tokens, then routed the table hover drawing through those metrics.
- Aligned table cell hover metrics with the human-owned UI rules: background
  token `--color-bg-hover`, 12 px horizontal padding, 6 px vertical padding, and
  8 px radius.
- Added a text-layout regression test for union bounds across multiple visible
  lines.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTextLayout` passed with 5 Swift Testing tests.
- `swift test --filter subtitleTableView` passed with 24 Swift Testing tests.
- `swift test` passed with 7 XCTest tests and 378 Swift Testing tests.

## Outcome

Search and Shiori table cell hover geometry now follows the human-owned UI
rules: a single rounded rectangle covers the visible content bounds with the
documented token, padding, and radius values.
