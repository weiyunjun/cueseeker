# Search Shiori Table Visual Hierarchy

## Human-Owned Source

- `docs/human/requirements/20260702-Feature-Search adn Shiori Table Visual Hierarchy.md`
- `docs/human/design/UI.md`

## Scope

Adjust the Search and Shiori table typography hierarchy so `Cues` reads as the
primary row content while display titles, dates, times, and headers step back
as context or metadata. Follow-up requirement updates also align Search and
Shiori table column order with the View menu order.

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
- Updated Search defaults to order text columns as `Display Title`, `Cues`,
  `Time`.
- Updated Shiori defaults to order text columns as `Display Title`, `Cues`,
  `Time`, `Date Added`.
- Passed visible column order into the virtual subtitle table so the table
  body, header, and View menu share the same user-facing order.
- Added focused tests for Search/Shiori View menu order and explicit subtitle
  table text-column ordering.

## Verification

- `git diff --check` passed.
- `swift test --filter subtitleTableText` passed.
- `swift test --filter schemaWorkbenchColumnVisibilityMenu` passed.
- `swift test --filter subtitleTableViewUsesExplicitColumnOrder` passed.
- `swift test` passed from `apps/macos-native`. XCTest reported 7 passing
  CASS rendering tests, and Swift Testing reported 369 passing tests.

## Outcome

Search and Shiori table rows now present `Cues` as the visual focal point,
while display titles, dates, times, and headers use quieter visual treatment.
Search text columns render as `Display Title`, `Cues`, `Time`, while Shiori
text columns render as `Display Title`, `Cues`, `Time`, `Date Added`. The
implementation keeps column visibility, selection, sorting, row actions, and
playback behavior unchanged.
