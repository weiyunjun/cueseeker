# 2026-10-19: Excerpt Valid Cue Counts and Unavailable Badge

Human-owned documents:

- `docs/human/requirements/20261019-Feature-Excerpt Valid Cue Counts And Unavailable Badge.md`

## Why

- Previously, `excerptListOverview()` and `uniqueExcerptCueCount()` counted all rows in `excerpts` regardless of whether the cue had become invalid (e.g., video missing or cue tombstoned), causing Excerpt L1 cards, L2 header counts, Recent Excerpt Lists cards, the toolbar count next to `Filter`, and Filter Dialog option counts / `Show (xx)` button to include unavailable cues.
- In the Excerpt List table (`L2`), `#` column numbers included unavailable rows, shifting numbering and showing numbers for rows that could not become checkboxes on hover.
- Unavailable rows previously rendered a trailing `?` icon on the right of the `Cues` column instead of a left-side inline `Unavailable` badge with hanging indentation.
- When `Index` completed in the background while the user was viewing Excerpt L1/L2 or Recent Excerpt Lists, boundary interactions (search/filter changes in L2, single-row `Remove / Move to / Duplicate to`, clicking a frozen card whose cues all became invalid, and switching the Recent `Videos / Excerpt Lists` Segmented Control) needed explicit alignment with the page-freeze specification.

## What changed

- **`ExcerptDatabase.swift`**:
  - Updated `excerptListOverview()` and `uniqueExcerptCueCount()` to join `subtitle_cue_lines`, `subtitle_files`, active `subtitle_video_matches`, and `video_files` (`COUNT(vf.id)` / `COUNT(DISTINCT s.cue_id)` where `vf.id IS NOT NULL`) so Excerpt L1 cards, L2 header metadata, and `All Excerpts` counts reflect only valid cues.
- **`AppCoordinator+Excerpt.swift` & `WorkbenchExcerptTableView.swift` & `CueFacetFilterPanel.swift` & `WorkbenchTestLibraryView.swift`**:
  - Updated `residentExcerptTableProjection` so `CueFacetOptionDistribution` (`distribution`) aggregates only valid cues while keeping all matching rows (valid and unavailable) in `relations` at their original `sort_order`.
  - Updated `WorkbenchExcerptTableView.exactSearchResultCountText` to use `tableSummary.selectableRowCount` (valid cues only) while keeping the table header visible when rows exist (`!rows.isEmpty`).
  - Updated `ExcerptFacetFilterDialog.counts` to use `projection.distribution.totalCount` for `Show (xx)`.
  - Unfroze (`refreshExcerptOnReappearanceIfNeeded()`) when changing search query (`updateExcerptSearchQuery`), changing facet filters (`updateExcerptFacetFilter`), or opening the Filter Dialog (`openFilterDialog()`).
  - Preserved the frozen snapshot in `removeExcerpt`, `moveExcerpt`, and `duplicateExcerpt` when `excerptNeedsReloadAfterIndexedContentMutation == true`, and adjusted list `cueCount` delta by `-1` only when the removed excerpt was valid (`item.isValid`).
  - Updated `openExcerptListPlayback` and `openExcerpt` so clicking a frozen card/Resume when all cues in the list are now invalid in SQLite opens the Playback page in `.loadFailed` state with the `.notInLibrary` red banner (`This item is no longer in the library`).
  - Triggered `refreshExcerptOnReappearanceIfNeeded()` and `refreshRecentOnReappearanceIfNeeded()` when switching the `Videos / Excerpt Lists` Segmented Control in `WorkbenchRecentView`.
- **`SubtitleTableRow.swift` & `TableSandboxRowModelStore.swift` & `SubtitleTableCueGeometry.swift` & `SubtitleTableView.swift`**:
  - Added `displayIndex: Int?` and `TableSandboxRowsSnapshot.displayIndexByRowIndex` so valid rows receive sequential 1-based `#` numbers and unavailable rows leave `#` blank without checkbox hover.
  - Placed the `question` (`18px`) icon on the left side of the `Cues` column for unavailable rows, vertically centered with the first line of the primary cue, with an `8px` gap (`unavailableLeadingIndent = 26px`).
  - Indented both primary cue text and `Show Cue Group` context lines by `unavailableLeadingIndent` (`26px`) so the left icon occupies a dedicated vertical slot and all cue lines share a flush left edge.
  - Updated the unavailable `question` icon hover background to fill only the interior of its circle with `WorkbenchRedesignColors.NS.rowSelected` (matching the File card `...` button hover color over a `rowHover` row) and kept the localized unavailable tooltip (`"table.cue_state.unavailable"`) anchored to the left icon.
- **Unit Tests**:
  - Added and updated tests in `ExcerptDatabaseTests.swift`, `SubtitleTableRowActionMenuTests.swift`, `SubtitleTableVirtualRowTests.swift`, and `ExcerptLifecycleAndInvalidItemsTests.swift`.

## Verification

- Verified `ExcerptDatabaseTests`, `SubtitleTableRowActionMenuTests`, `SubtitleTableVirtualRowTests`, `ExcerptLifecycleAndInvalidItemsTests`, `SubtitleTableCueGeometryTests`, `TableSandboxRowModelStoreTests`, `ExcerptPresentationTests`, and `SelectionActionOverlayInvalidItemsTests` pass via `swift test --package-path apps/macos-native`.
