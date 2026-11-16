# 2026-11-16 Unified Baseline-Proportional Read-Only Text Selection Metrics

- **Covering Requirement**: `docs/human/requirements/20261116-UI-Unified Baseline-Proportional Read-Only Text Selection Metrics.md`
- **Referenced Design & Engineering Documents**:
  - `docs/engineering/02_git_workflow.md`
  - `docs/engineering/04_architecture_rules.md`
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Design Rules.md`
  - `docs/human/design/ui/UI Text Selection Rules.md`
  - `docs/human/design/ui/UI Tokens.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `2e4523b`, requirement commit `856d058`)

## Scope

1. Introduce shared design tokens and one minimal shared helper for baseline-proportional read-only text selection geometry (`[baselineY - fontSize * 1.07, baselineY + fontSize * 0.35]`), language-independent fixed-line-height vertical centering (`fontSize * 0.36`), and adjacent visual-line overlap resolution (`splitY = (prevRect.maxY + nextRect.minY) / 2`).
2. Converge all three read-only selectable text outlets onto the shared helper while keeping external layout sizes, baseline alignment, editable controls (`C-01`), and `Playback Cue Reel` row/scroll metrics unchanged:
   - Outlet 1: `WorkbenchSelectableText` (compact transparent vertical bleed + horizontal-only draw clip + unified fixed-line-height centering and selection bands).
   - Outlet 2: `SubtitleTable` (unified fixed-line-height centering and selection bands, single-line CoreText header rendering aligned with hit-testing/selection geometry, and unclipped header/tag vertical selection bounds).
   - Outlet 3: `Playback Cue Reel` (per-line baseline + font-size selection bands across `24px` primary and `20px` extra cues, overlap splitting, and aligned selection menu anchor `boundaryPoint.y`).
3. Add top anti-clip scroll padding in `WorkbenchFileDetailDialog` compensated identically in outer column spacing so `scrollOffset == 0` selection tops stay unclipped without shifting the first group header.

## Summary of Changes

1. **Shared Tokens & Geometry Helper (`apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControlMetrics.swift`)**:
   - Added `WorkbenchControlMetrics.redesignTextSelectionAscentScale` (`1.07`) and `WorkbenchControlMetrics.redesignTextSelectionDescentScale` (`0.35`).
   - Added `ReadOnlyTextSelectionMetrics` with `verticalBounds(baselineY:fontSize:)`, `fixedLineHeightBaselineCenterOffset(fontSize:)`, and `resolvingAdjacentLineOverlaps(_:)`.

2. **Outlet 1 — `WorkbenchSelectableText` (`apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchSelectableText.swift`)**:
   - Added `selectionVerticalBleed(fontSize:lineHeight:)` and negative vertical padding on `WorkbenchSelectableTextRepresentable` inside the `.overlay`, compensating `verticalBleed` via `layoutBounds` inside `WorkbenchSelectableTextNSView` (`textOrigin()`, `hitTest(_:)`, `resetCursorRects()`, `pointerShape(at:)`, `visibleWindowClipRect()`, `windowSelectionHitRect`, `mouseUp(with:)`).
   - Removed vertical `bounds` clipping during selection drawing in `draw(_:)` (keeping horizontal clamping only), switched fixed-line-height `deltaY` in `lineFragmentLayouts(at:)` onto `ReadOnlyTextSelectionMetrics.fixedLineHeightBaselineCenterOffset(fontSize:)`, and switched `selectionRects(for:in:)` onto `ReadOnlyTextSelectionMetrics`.

3. **Outlet 2 — `SubtitleTable`**:
   - `apps/macos-native/Sources/CueSeekerApp/Shared/SubtitleTable/SubtitleTableTextLayout.swift`: updated `SubtitleTextLayout` fixed-line-height `deltaY` and `selectionRects(forUTF16Range:at:)` (replacing `targetLineHeight` overrides) to use `ReadOnlyTextSelectionMetrics`, set `SubtitleTableText.header` to fixed `cellLineHeight` with `.byTruncatingTail`, added `maximumNumberOfLines` support in `SubtitleTextLayout` / `SubtitleTableTextFragmentLayout`, and replaced font-run ascender/descender mid-Y variance in `fixedLineParagraphStyle`.
   - `apps/macos-native/Sources/CueSeekerApp/Shared/SubtitleTable/SubtitleTableChromeAndHeaderViews.swift`: updated `SubtitleTableHeaderCellView` to render via `SubtitleTableHeaderTextRepresentable` / `SubtitleTableHeaderTextNSView` backed by `SubtitleTextLayout(maximumNumberOfLines: 1)` so EN and CJK headers share the exact rendering and selection baseline.
   - `apps/macos-native/Sources/CueSeekerApp/Shared/SubtitleTable/SubtitleTableCoordinator+Drawing.swift`, `SubtitleTableCoordinator+SelectionAndInput.swift`, and `SubtitleTableCoordinator+Testing.swift`: removed `targetLineHeight` overrides, passed `maximumNumberOfLines: 1` for headers, expanded header and `tagTextFragments` vertical `clipRect`s to `cellRect` / `tagRect` height, and unified `drawTags` onto `SubtitleTextLayout`.

4. **Outlet 3 — `Playback Cue Reel` (`apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackVisualLineStackLayout.swift`)**:
   - Added `fontSize` to `DraftLine` / `PlaybackVisualLineStackLine`, preserved `visibleCenterY` exclusively for first-line center offsets and Collage marker alignment, switched `selectionRects(forUTF16Range:in:)` onto `selectionBand(for:in:)` + `ReadOnlyTextSelectionMetrics.resolvingAdjacentLineOverlaps(_:)`, and updated `textSelectionHit` `boundaryPoint.y` returns to `selectionBand(for:in:).minY`.

5. **`WorkbenchFileDetailDialog` Scroll Top Anti-Clip Padding (`apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileDetailDialog.swift`)**:
   - Added `scrollContentTopAntiClipPadding` (`2`) to the `WorkbenchScrollView` content inside `fileDetailDialogBody` and subtracted `2` from `WorkbenchDialogColumn` `spacing`.

6. **Pure-Logic Unit Tests**:
   - Added `readOnlyTextSelectionMetricsScaleProportionallyAndResolveOverlaps` in `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchControlMetricsTests.swift`.
   - Updated and expanded pure-logic selection tests in `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTextLayoutDecorationTests.swift`, `SubtitleTableCueGeometryTests.swift`, `SubtitleTextLayoutTests.swift`, and `PlaybackSubtitleFocusLayoutTests.swift` (`subtitleFocusTextSelectionCrossesSoftWrapAndAnchorsAtLastGlyph` and `subtitleFocusSelectionRectsUseUnifiedBaselineScaleAndSplitSoftWraps`).

## Verification

- **Language gate check**:
  - `bash scripts/verify_engineering_doc_lang.sh docs/engineering/records/20261116-unified-baseline-proportional-read-only-text-selection-metrics.md`
- **Build check**:
  - `swift build --package-path apps/macos-native`: succeeded (`Build complete! (0.32s)`).
- **Filtered headless pure-logic unit tests**:
  - Command: `swift test --package-path apps/macos-native --filter "WorkbenchControlMetricsTests|SubtitleTextLayout|SubtitleTableCueGeometryTests|SubtitleTableVirtualRowTests|PlaybackSubtitleFocusLayoutTests|PlaybackCueResultLayoutTests|FileDetailDialogTests|SettingsAndDialogsStaticTextSelectionTests" --skip "playbackOverlayCurrentAndPlaylistShareFullWidthCueGeometry"`
  - Result: `259` tests passed in `5.257` seconds (`0` failures; `playbackOverlayCurrentAndPlaylistShareFullWidthCueGeometry` skipped due to pre-existing `PlaybackOverlayModule.collage` expectation mismatch on `origin/main`, and window-creating suites skipped per test rules).
  - Additional check on `WorkbenchSelectableTextTests`: `23` of `24` passed in combined suite execution (`listCardSelectableTextPreservesHoverProbeAndRightClickClearsSelectionBeforeMenu` passes `1` of `1` in `0.089` seconds standalone but observes shared `PointerHoverScrollState` leakage when executed immediately after prior tests).

## Outcome

All three read-only selectable text outlets (`WorkbenchSelectableText`, `SubtitleTable`, and `Playback Cue Reel`) and `WorkbenchFileDetailDialog` top scroll edge protection now share one baseline-proportional geometry helper (`1.07` ascent / `0.35` descent = `1.42 * fontSize`, `0.36 * fontSize` fixed-line-height offset, and midpoint overlap splitting) with zero external layout regression in pure-logic verification. Pending user end-to-end visual acceptance prior to design document synchronization.
