# Workbench Media Card Grid Padding Alignment

Human-owned documents:

- `docs/human/requirements/20261007-UI-Workbench Media Card Grid Padding Alignment.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Problem**:
   - In Workbench pages containing media card grids (Library Overview, Library Folder Detail, Excerpt List Overview, Recent Watching), unhovered card cover images visually indented inwards by 12pt relative to sibling elements.
   - For example, in Library Overview, the right edge of unhovered folder covers was indented 12pt to the left of the sort button (`Default Order`). In Library Folder Detail, episode covers were indented 12pt relative to the Cover Summary card edges. In Excerpt List Overview, covers did not align with the summary text or the New List button.
   - This occurred because `LibraryOverviewCardButtonStyle` includes an internal `12pt` hover padding (`redesignLibraryMediaCardHoverPadding`) so the card hover background capsule has room to expand. When the parent grid container shared the standard page inline padding (leading 32pt, trailing 48pt), the unhovered cover images inside the cards sat at `32 + 12 = 44pt` on the leading side and `48 + 12 = 60pt` on the trailing side.

2. **Root Cause**:
   - Both non-card containers (such as the sort bar, summary header, and cover summary card) and card grid containers shared the same `.workbenchPageInlinePadding()`.
   - The design tokens lacked a dedicated semantic padding token for card grid containers to compensate for the card hover margin.

## What changed

1. **New Tokens (`WorkbenchControls.swift`)**:
   - Added primitive spacing token `redesignSpacing5: CGFloat = 20` (`--spacing-5`).
   - Added semantic metrics:
     - `redesignWorkbenchMediaCardGridHorizontalPadding = redesignSpacing5` (`20pt`, leading padding offsetting the 12pt card hover padding to align covers at 32pt).
     - `redesignWorkbenchMediaCardGridTrailingPadding = redesignWorkbenchMediaCardGridHorizontalPadding + redesignWorkbenchPageScrollbarChannel` (`36pt`, trailing padding offsetting the 12pt card hover padding to align covers at 48pt).
   - Added `workbenchMediaCardGridInlinePadding()` view extension.

2. **Container Padding Separation**:
   - **`WorkbenchTestLibraryView.swift`**:
     - In `completeLibraryContent` (Library Level 1): `sortBar` uses `.workbenchPageInlinePadding()`, `CompleteLibraryFolderGrid` uses `.workbenchMediaCardGridInlinePadding()`.
     - In `folderDetailContent` (Library Level 2): `folderCoverSummary` uses `.workbenchPageInlinePadding()`, `CompleteLibraryEpisodeGrid` uses `.workbenchMediaCardGridInlinePadding()`.
     - In `WorkbenchRecentView`: `sectionTabs` uses `.workbenchPageInlinePadding()`, card grids use `.workbenchMediaCardGridInlinePadding()`.
   - **`LibraryOverviewComponents.swift`**:
     - In `LibraryOverviewLayout` (Excerpt Level 1): `HStack` (summary row) uses `.workbenchPageInlinePadding()`, `content` (card grid) uses `.workbenchMediaCardGridInlinePadding()`.
   - Excerpt Level 2 (`WorkbenchExcerptTableView`) remains unchanged as it contains no media card grid.

3. **Tests (`WorkbenchControlMetricsTests.swift`)**:
   - Added test assertions verifying `redesignSpacing5 == 20`, `redesignWorkbenchMediaCardGridHorizontalPadding == 20`, and `redesignWorkbenchMediaCardGridTrailingPadding == 36`.

## Verification

- `swift build --product CueSeeker --package-path apps/macos-native`: passed.
- `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: passed (12/12 tests passed).
