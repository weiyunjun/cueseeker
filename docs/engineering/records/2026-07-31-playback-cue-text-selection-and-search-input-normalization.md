# Playback Cue Text Selection and Search Input Normalization

## Status

Implemented. Automated feature verification passes. Human visual and interaction
acceptance remains pending, so `docs/human/design/UI.md` is intentionally
unchanged.

## Requirement

- `docs/human/requirements/20260731-Feature-Playback Cue Text Selection And Search Input Normalization.md`

## Scope

- Add source-line-local text selection to the shared native Playback Reel used
  by Current, Playlist, and Command Panel Search. Visual wrapping caused by
  available width remains selectable across rows.
- Present the existing CueSeeker popover menu after a non-empty selection,
  anchored to the trailing boundary of the selected text.
- Copy selected text with the required playback feedback.
- Search selected text through the existing Command Panel Search operation.
- Keep Collage editing free of text-selection interaction.
- Normalize line breaks to spaces in Workbench Search, Shiori Search, and
  Command Panel Search inputs.

## Implementation

- Extended the shared TextKit layout with UTF-16 hit testing based on TextKit
  glyph ranges, source-line-constrained selection, native selection
  highlighting, and selected-text extraction.
- Kept selection state local to the native Reel document view and keyed it by
  item identity and source-line range. TextKit boundary points keep soft-wrapped
  rows selectable and anchor the menu to the last selected character rather
  than the mouse-up position. Selecting text does not change the focused Cue.
- Reused `WorkbenchPopoverPanel` and `WorkbenchPopoverRow` in a lightweight
  hosting view for `Copy Selected Text` and `Search Selected Text`.
- Routed copy and search actions through `AppCoordinator`. Search reuses
  `presentPlaybackCommandPanelSearch`, including when the panel is already
  presented.
- Added one shared `SearchInputNormalizer` and applied it at the shared search
  field plus Search, Shiori, and Command Panel state/query entry points.
- Added focused tests for source-line boundaries, soft wrapping, last-character
  menu anchoring, CueResult boundaries, copy feedback, input normalization, and
  open-panel search replacement.
- Simplified the initial implementation after review by removing the menu
  action model, full-view menu overlay, duplicated selected-text state,
  test-only production selection APIs, and repeated TextKit preparation.

## Verification

- `swift build` — passed.
- Seven focused selection, feedback, normalization, CueResult, and Command Panel
  tests — passed.
- `swift test --no-parallel` — ran 931 tests with three unrelated issues:
  - `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
    failed only in the full run and passed when rerun alone.
  - `subtitleTableViewCueContentRightClickOpensMenuBelowClickPosition` and
    `subtitleTableViewDisplayTitleContentRightClickOpensMenuBelowClickPosition`
    remain failing when rerun alone. Their implementation and tests are
    unchanged by this requirement.
- `git diff --check` — passed.

## Outcome

The three required Playback surfaces now share one source-line-local selection
implementation and one existing-style action menu. Width-driven visual wrapping
remains selectable, while source line breaks and Cue boundaries stop selection.
The menu follows the final selected character. Search boxes and their query/state
paths store and execute single-line input. Final visual and interaction
acceptance, followed by the corresponding `UI.md` update, remains with the human
reviewer.
