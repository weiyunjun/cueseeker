# Media Card Grid Sizing And Spacing Adjustment

Human-owned documents:

- `docs/human/requirements/20261014-UI-Media Card Grid Sizing And Spacing Adjustment.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Grid Spacing Reduction**:
   - The horizontal and vertical grid gap (`--gap-library-recent-grid` / `--gap-library-episode-grid`) was `16px`. Combined with the `12px` card hover padding (`--padding-library-media-card-hover`), unhovered cover images had a `40px` visual gap. Reducing the grid gap by `8px` (`16px` -> `8px`) tightens the card grid while keeping an `8px` separation between adjacent hover backgrounds.
2. **Card Minimum Width (`260px`) & Maximum Column Count Cap (`4` with Sidebar / `5` without Sidebar)**:
   - Setting `--width-library-recent-card-min` to `260px` ensures that at minimum window width (`480px`), every media card grid displays strictly 1 card per row while allowing `1504x846` (with left Dock and Sidebar open, `~1138px` grid width) to fit 4 cards per row (`4 * 260 + 3 * 8 = 1064px`).
   - Adding a maximum column count cap (`--grid-max-columns-library-with-sidebar: 4`, `--grid-max-columns-library-without-sidebar: 5`) ensures that across different macOS HiDPI scaling levels (`1504x846` through `1920x1080` and wider), Workbench grids with Sidebar visible display at most 4 cards per row, and grids without Sidebar (Workbench with Sidebar collapsed, Playback Overlay, Command Panel) display at most 5 cards per row, stepping down (`4 -> 3 -> 2 -> 1` or `5 -> 4 -> 3 -> 2 -> 1`) when the container narrows below `N * 260 + (N - 1) * 8`.
3. **Proportional Card Scaling Instead of Spacing Expansion**:
   - Removing `--width-library-recent-card-max: 220px` and constructing `LibraryOverviewGrid` columns with `GridItem(.flexible(minimum: 260, maximum: .infinity), spacing: 8)` capped at `maxColumns` allows cards to fill their column width and scale their `16:9` cover height proportionally while keeping horizontal and vertical spacing fixed at `8px`.

## What changed

1. **Design Tokens (`WorkbenchControls.swift`)**:
   - Updated `redesignLibraryRecentCardMinWidth` to `260`.
   - Removed `redesignLibraryRecentCardMaxWidth`.
   - Added `redesignLibraryRecentGridMaxColumnsWithSidebar = 4` and `redesignLibraryRecentGridMaxColumnsWithoutSidebar = 5`.
   - Updated `redesignLibraryRecentGridGap` and `redesignLibraryEpisodeGridGap` from `16` to `8`.
   - Added `WorkbenchControlMetrics.workbenchMediaCardGridWidth(viewportWidth:)`.
2. **Shared Media Card Grid & Card Sizing (`LibraryOverviewComponents.swift`, `ContentView.swift`, `WorkbenchTestLibraryView.swift`, `PlaybackLibraryOverlay.swift`, `PlaybackCommandPanel.swift`, `PlaybackMediaSelectionStore.swift`)**:
   - Added `LibraryOverviewGrid.columnCount(containerWidth:minimumItemWidth:itemGap:maxColumns:)` and capped column construction in `LibraryOverviewGrid` at `4` when `layerContext.layer == .workbenchPage && isWorkbenchSidebarVisible`, and `5` otherwise.
   - Propagated `isWorkbenchSidebarVisible` from `ContentRootView` (`!hidesWorkbenchChrome && layoutState.isSidebarVisible`) and `mediaCardGridContainerWidth` from the outer `GeometryReader`s across Recent, Library (Level 1 & Level 2), Excerpt (Level 1), Playback Overlay, and Command Panel.
   - Unified `PlaybackCommandPanelCardGrid.columnCount` and `PlaybackMediaSelectionStore.updateAdaptiveGrid` to use `LibraryOverviewGrid.columnCount` with `redesignLibraryRecentGridMaxColumnsWithoutSidebar` (`5`).
3. **Tests (`WorkbenchControlMetricsTests.swift`, `PlaybackMediaSelectionTests.swift`)**:
   - Updated `mediaCardGridMetricsAndMinimumWindowColumnCountMatchSpecification()` to verify the `260px` minimum width, `8px` grid gap, single-column layout at minimum window width, 4-column cap with Sidebar, and 5-column cap without Sidebar.
   - Updated `PlaybackMediaSelectionTests` to verify adaptive grid navigation with the `260px` minimum width, `8px` gap, and 5-column cap.

## Verification

- `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchControlMetricsTests|PlaybackMediaSelectionTests|playbackCommandPanelRecentVideos"`: passed.
