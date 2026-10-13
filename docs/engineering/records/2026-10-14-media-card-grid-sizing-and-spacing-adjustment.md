# Media Card Grid Sizing And Spacing Adjustment

Human-owned documents:

- `docs/human/requirements/20261014-UI-Media Card Grid Sizing And Spacing Adjustment.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Grid Spacing Reduction**:
   - The horizontal and vertical grid gap (`--gap-library-recent-grid` / `--gap-library-episode-grid`) was `16px`. Combined with the `12px` card hover padding (`--padding-library-media-card-hover`), unhovered cover images had a `40px` visual gap. Reducing the grid gap by `8px` (`16px` -> `8px`) tightens the card grid while keeping an `8px` separation between adjacent hover backgrounds.
2. **Card Minimum Width (`300px`)**:
   - Increasing `--width-library-recent-card-min` from `180px` to `300px` ensures that at minimum window width (`480px`), every media card grid displays strictly 1 card per row and provides more horizontal space for card titles and metadata.
3. **Proportional Card Scaling Instead of Spacing Expansion**:
   - Previously, `--width-library-recent-card-max: 220px` capped card widths at `220px`, causing `LazyVGrid` to distribute extra horizontal width into column spacing when resizing the window. Removing the maximum card width cap allows cards to fill their adaptive column width (`maxWidth: .infinity`) and scale their `16:9` cover height proportionally while keeping horizontal and vertical spacing fixed at `8px`.

## What changed

1. **Design Tokens (`WorkbenchControls.swift`)**:
   - Updated `redesignLibraryRecentCardMinWidth` from `180` to `300`.
   - Removed `redesignLibraryRecentCardMaxWidth`.
   - Updated `redesignLibraryRecentGridGap` and `redesignLibraryEpisodeGridGap` from `16` to `8`.
2. **Shared Media Card Grid & Card Sizing (`LibraryOverviewComponents.swift`, `WorkbenchTestLibraryView.swift`)**:
   - Updated `LibraryOverviewGrid` to use `GridItem(.adaptive(minimum: WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth, maximum: .infinity), spacing: WorkbenchControlMetrics.redesignLibraryRecentGridGap, alignment: .topLeading)`.
   - Updated `LibraryOverviewCardButtonStyle` and `LibraryVideoCard` to use `.frame(maxWidth: .infinity, alignment: .topLeading)`.
   - Unified `LibraryVideoCardGrid` to reuse `LibraryOverviewGrid`, eliminating duplicate grid column definitions across Recent, Library (overview and folder detail), Excerpt overview, Playback Overlay (Video Playlist), and Command Panel (Recent Videos and Recent Excerpt Lists).
3. **Tests (`WorkbenchControlMetricsTests.swift`, `PlaybackMediaSelectionTests.swift`)**:
   - Added `mediaCardGridMetricsAndMinimumWindowColumnCountMatchSpecification()` verifying the `300px` minimum width, `8px` grid gap, and single-column layout at minimum window width.
   - Updated `PlaybackMediaSelectionTests` to exercise adaptive grid navigation with the updated `300px` minimum width and `8px` gap tokens.

## Verification

- `swift test --package-path apps/macos-native --filter "WorkbenchControlMetricsTests|PlaybackMediaSelectionTests|PlaybackSubtitleFocusKeyboardActionTests"`: passed.
