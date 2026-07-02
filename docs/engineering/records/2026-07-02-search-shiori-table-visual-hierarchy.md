# Search Shiori Table Visual Hierarchy

## Human-Owned Source

- `docs/human/requirements/20260702-Feature-Search adn Shiori Table Visual Hierarchy.md`
- `docs/human/design/UI.md`

## Scope

Adjust the Search and Shiori table typography hierarchy so `Cues` reads as the
primary row content while display titles, dates, times, and headers step back
as context or metadata.

## Classification

- Product semantics: unchanged; row data, sorting, filtering, selection, and
  actions keep the same behavior.
- Platform UI/UX: table text color, weight, header size, and metadata numeric
  rendering are updated for the native macOS table surface.
- Platform integration: unchanged; existing Search and Shiori row hydration and
  visible-column wiring remain in place.
- Playback execution: unchanged.

## Changes

- Added the redesign table-header font-size token used by table headers.
- Added table text roles for primary content, secondary context, and metadata.
- Rendered `Cues` as primary text, `Display Title` as secondary context, and
  `Date Added` / `Time` as muted metadata with monospaced digits.
- Updated sortable table headers to use the smaller medium muted header style.
- Added a focused typography test for redesign table text roles.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTableText` passed.
- `swift test` passed. XCTest reported 7 passing CASS rendering tests, and
  Swift Testing reported 367 passing tests.

## Outcome

Search and Shiori table rows now present `Cues` as the visual focal point,
while display titles, dates, times, and headers use quieter visual treatment.
The implementation keeps the existing table layout, column visibility,
selection, sorting, row actions, and playback behavior unchanged.
