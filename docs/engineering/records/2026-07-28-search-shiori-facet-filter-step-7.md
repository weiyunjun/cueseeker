# Search And Shiori Facet Filter Step 7

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Replace the Shiori secondary page's old Filter Editor entry with the shared
Search facet panel, keep the panel hidden by default, restore each List's
persisted selection, and keep the table and playback on the same filtered
result projection.

## Classification

- Facet matching and the current List's exact distribution remain shared
  product semantics in `CueSeekerCore`.
- Shiori result projection and List preference restoration are coordinated by
  `ShioriStore`, `SettingsStore`, and `AppCoordinator`.
- Panel visibility and rendering are platform UI state in SwiftUI.
- Playback execution is unchanged; it consumes the updated Shiori table result
  IDs through the existing playlist path.

## Implementation

- Reused `CueFacetFilterPanel` and its adaptive card layout without adding
  Shiori-specific visual rules.
- Made the Shiori panel hidden by default and kept visibility as non-persisted
  view state.
- Replaced the Shiori toolbar's old Filter Editor action with a panel toggle,
  so the Filter button has no count or Badge.
- Restored the active List's saved facet selection at startup, List opening,
  and view activation; a List without saved exclusions keeps every option
  selected.
- Applied facet changes to the resident Shiori snapshot without another
  database load, and generated a new result snapshot for the table, copy, and
  playback consumers.
- Kept the shared panel's existing Calculating and Select-mode interaction
  rules.
- Removed the Shiori-only forced `Unknown` language option. Language choices
  now come exclusively from the active List's exact distribution, so a
  zero-count `Unknown` row is not displayed.

## Verification

- The focused Step 7 tests passed, covering the hidden Shiori panel default,
  per-List selection restoration, resident facet projection without a database
  reload, and the shared table/playback result scope.
- The complete `swift test` run executed 908 tests and reported 15 issues in
  eight existing native playback, Subtitle Focus, and UI probe timing tests.
  Every affected test passed when rerun individually, confirming full-suite
  concurrency instability rather than a Step 7 regression.
- `git diff --check` passed.
- `docs/human/design/UI.md` was not modified or staged by the AI.
- Visual acceptance remains with the project owner.

## Outcome

The Shiori secondary page now uses the same responsive facet cards as Search.
Its panel starts hidden, restores the current List's independent selection,
and updates the visible table and playback result scope immediately from the
resident snapshot.
