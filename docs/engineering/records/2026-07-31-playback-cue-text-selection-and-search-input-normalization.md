# Playback Cue Text Selection and Search Input Normalization

## Status

Implemented. Automated feature verification passes. Human visual and interaction
acceptance remains pending, so `docs/human/design/UI.md` is intentionally
unchanged.

## Requirement

- `docs/human/requirements/20260731-Feature-Playback Cue Text Selection And Search Input Normalization.md`

## Scope

- Add line-local text selection to the shared native Playback Reel used by
  Current, Playlist, and Command Panel Search.
- Present the existing CueSeeker popover menu after a non-empty selection.
- Copy selected text with the required playback feedback.
- Search selected text through the existing Command Panel Search operation.
- Keep Collage editing free of text-selection interaction.
- Normalize line breaks to spaces in Workbench Search, Shiori Search, and
  Command Panel Search inputs.

## Implementation

- Extended the shared TextKit layout with UTF-16 hit testing based on TextKit
  glyph ranges, line-constrained selection, native selection highlighting, and
  selected-text extraction.
- Kept selection state local to the native Reel document view and keyed it by
  item identity and visual line. Selecting text does not change the focused Cue.
- Reused `WorkbenchPopoverPanel` and `WorkbenchPopoverRow` in a lightweight
  hosting view for `Copy Selected Text` and `Search Selected Text`.
- Routed copy and search actions through `AppCoordinator`. Search reuses
  `presentPlaybackCommandPanelSearch`, including when the panel is already
  presented.
- Added one shared `SearchInputNormalizer` and applied it at the shared search
  field plus Search, Shiori, and Command Panel state/query entry points.
- Added focused tests for hard-line boundaries, CueResult boundaries, copy
  feedback, input normalization, and open-panel search replacement.
- Simplified the initial implementation after review by removing the menu
  action model, full-view menu overlay, duplicated selected-text state,
  test-only production selection APIs, redundant line-range state, and repeated
  TextKit preparation. The follow-up reduced the implementation by 292 net
  lines without changing the accepted behavior.

## Verification

- `swift build` — passed.
- Six focused selection, feedback, normalization, CueResult, and Command Panel
  tests — passed.
- `swift test --no-parallel` — ran 930 tests with three unrelated issues:
  - `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
    failed only in the full run and passed when rerun alone.
  - `subtitleTableViewCueContentRightClickOpensMenuBelowClickPosition` and
    `subtitleTableViewDisplayTitleContentRightClickOpensMenuBelowClickPosition`
    remain failing when rerun alone. Their implementation and tests are
    unchanged by this requirement.
- `git diff --check` — passed.

## Outcome

The three required Playback surfaces now share one line-local selection
implementation and one existing-style action menu. Search boxes and their
query/state paths store and execute single-line input. Final visual and
interaction acceptance, followed by the corresponding `UI.md` update, remains
with the human reviewer.
