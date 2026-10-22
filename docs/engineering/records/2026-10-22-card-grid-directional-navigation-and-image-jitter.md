# 2026-10-22 Card Grid Directional Navigation And Image Jitter

## Requirement Reference
- `docs/human/requirements/20261022-Bug-Card Grid Directional Navigation And Image Jitter.md`

## Summary of Changes
1. **Deterministic Explicit Row Grid & Cover Sizing (`LibraryOverviewGrid`, `LibraryCoverFrame`, `LibraryCoverFillImage`, `LibraryCoverWithProgress`)**:
   - Replaced `LazyVGrid` in `LibraryOverviewGrid` with deterministic explicit `VStack` + `HStack` rows chunked by `resolvedColumnCount`, with explicit `cardWidth` and `mediaCardCoverSize` environment propagation.
   - Updated `LibraryCoverFrame`, `LibraryCoverFillImage`, and `LibraryCoverWithProgress.progressTrack` to consume `mediaCardCoverSize` directly when available, eliminating nested per-card `GeometryReader` layout passes that caused cover drift and jump artifacts under narrow window widths and scrolling.
   - Replaced `Color.clear` loading placeholders in `LibraryCachedCoverImage` and `ExcerptListCoverView` with `WorkbenchRedesignColors.libraryCoverPlaceholderBg` and avoided redundant `@State` updates when synchronous memory cache hits match the current key.

2. **Deterministic Row Matrix Navigation (`PlaybackMediaSelectionStore`, `AppCoordinator+PlaybackCommandPanel`, `PlaybackStore`)**:
   - Removed coordinate-distance `frameTargetIndex` from `PlaybackMediaSelectionStore` and replaced `targetIndex` with deterministic row chunking (`makeRows(itemCount:columnCount:sectionItemCounts:)`), ensuring Left/Right movement stays strictly within the current row and Up/Down movement selects the same column (or the rightmost item when an adjacent section row has fewer items) without skipping incomplete rows.

3. **Same-Frame Highlight Synchronization & Synchronous Viewport Scroll (`CardHighlightModel`, `PlaybackMediaScrollPositionBridge`, `PlaybackCommandPanel`, `PlaybackLibraryOverlay`)**:
   - Added `CardHighlightModel.syncSelectedDuringRender(_:)` and `PlaybackLibraryOverlay.init` activation so the initial and navigated selection state is synchronized on the first render pass without a 1-frame `.onAppear` / `.onChange` delay.
   - Moved `.coordinateSpace(name:)` inside `WorkbenchScrollView` content containers so `LibraryItemFramePreferenceKey` reports static document coordinates without firing during scroll.
   - Added `PlaybackMediaSelectionStore.targetScrollOffsetY` and synchronous `NSClipView` scrolling inside `PlaybackMediaScrollPositionBridge.updateNSView` (wrapped in disabled `CATransaction` actions), keeping fully visible cards stationary, scrolling to `y = 0` when returning to the first row so section headers remain visible, and eliminating the `await Task.yield()` + `ScrollViewReader.scrollTo` 1-frame flash.
   - Separated `Select` and `Hover` transition animations on media and excerpt cards (`LibraryOverviewCardButtonStyle`, `LibraryCoverHoverEffectModifier`, `LibraryMediaCards`, `ExcerptListCardGrid`) so `Select` switches instantaneously (`0ms`, `.animation(nil, value: isSelected)`) while pointer `Hover` retains the `0.12s` transition, eliminating fade/scale ghosting during instant keyboard scroll jumps.
   - Removed the stale `itemFramesByID = [:]` reset from `PlaybackMediaSelectionStore.updateAdaptiveGrid` / `updateColumnCount` and published `recordVisibleFrames` updates so `PlaybackLibraryOverlay` retains measured static card coordinates across adaptive column synchronization and triggers viewport scrolling reliably.

## Verification
- Updated and added unit tests in `PlaybackMediaSelectionTests.swift`, `PlaybackSubtitleFocusKeyboardActionTests.swift`, and `WorkbenchControlMetricsTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "PlaybackMediaSelectionTests|PlaybackSubtitleFocusKeyboardActionTests|WorkbenchControlMetricsTests"` (all 59 tests passed).
