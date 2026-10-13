# Media Card Grid Min Width And Column Cap Refinement

Human-owned documents:

- `docs/human/requirements/20261014-UI-Media Card Grid Min Width And Column Cap Refinement.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Card Minimum Width (`220px`)**:
   - At `260px`, a `1504x846` display with left Dock (`~1138px–1143px` grid width with Sidebar open, `1375px–1383px` with Sidebar closed) could only fit 4 cards with Sidebar open (`5 * 260 + 32 = 1332px`) and 5 cards with Sidebar closed (`6 * 260 + 40 = 1600px`), while Command Panel (`1000px` grid width) could only fit 3 cards (`4 * 260 + 24 = 1064px`).
   - Reducing `--width-library-recent-card-min` to `220px` lowers the 4/5/6-column thresholds to `904px` / `1132px` / `1360px`, allowing 5 columns with Sidebar open, 6 columns with Sidebar closed (and in Playback Overlay), and 4 columns in Command Panel whether the Dock is on the left or bottom, while keeping 1 column at minimum window width (`424px < 448px`).
2. **Maximum Column Caps (`5` with Sidebar / `6` without Sidebar)**:
   - Raising `--grid-max-columns-library-with-sidebar` to `5` and `--grid-max-columns-library-without-sidebar` to `6` ensures consistent 5- and 6-column layouts across both left and bottom Dock configurations as well as larger viewports.

## What changed

1. **Design Tokens (`WorkbenchControls.swift`)**:
   - Updated `redesignLibraryRecentCardMinWidth` from `260` to `220`.
   - Updated `redesignLibraryRecentGridMaxColumnsWithSidebar` from `4` to `5`.
   - Updated `redesignLibraryRecentGridMaxColumnsWithoutSidebar` from `5` to `6`.
2. **Tests (`WorkbenchControlMetricsTests.swift`, `PlaybackMediaSelectionTests.swift`)**:
   - Updated metric assertions and column count threshold checks for `220px` minimum card width and `5` / `6` maximum column caps.

## Verification

- `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchControlMetricsTests|PlaybackMediaSelectionTests|playbackCommandPanelRecentVideos"`: passed.
