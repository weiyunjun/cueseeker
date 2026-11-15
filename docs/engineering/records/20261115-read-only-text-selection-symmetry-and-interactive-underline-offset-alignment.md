# 2026-11-15 Read-Only Text Selection Symmetry and Interactive Underline Offset Alignment

- **Covering Requirement**: `docs/human/requirements/20261115-UI-Read-Only Text Selection Symmetry And Interactive Underline Offset Alignment.md`
- **Branch / Baseline**: `main` (before change: `1495dc9`, requirement commit: `6cf2f76`)

## Summary of Changes

1. **Complete design token and explicit fixed line-height wiring**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControlMetrics.swift`: Added `--line-height-status-indicator: 20px` (`redesignLineHeightStatusIndicator`).
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchStatusIndicator.swift`: Passed `lineHeight: WorkbenchControlMetrics.redesignLineHeightStatusIndicator` to status indicator text while keeping overall control height at `36px`.
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogHeader.swift`: Passed `lineHeight: WorkbenchControlMetrics.redesignDetailFileTitleLineHeight` to detail dialog header titles (`WorkbenchDetailHeaderRow`).

2. **Playback subtitle focus selection symmetry, adjacent midpoint meeting, and clip rect fix**
   - `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackVisualLineStackLayout.swift`: Added `selectionRects(forUTF16Range:in:)` and reused each line's `visibleCenterY` and `nominalLineHeight` in `drawSelection(forUTF16Range:in:clipRect:)` to produce vertically symmetric 1:1 selection rects; when two adjacent visual lines are both selected and overlap vertically, splits seamlessly at their midpoint (`(prev.maxY + curr.minY) / 2`). Also passed the outer clip rect including `--padding-subtitle-focus-cue-y` into `PlaybackSubtitleFocusNativeTextLayout.draw`.
   - `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueResult.swift`: Expanded the selection clip rect in `drawPreparedPlan` to include top and bottom `--padding-subtitle-focus-cue-y` (stopping above `metadataRect.minY` when trailing metadata is present) so top/bottom selection padding on first and last lines is not clipped.

3. **Workbench and table fixed line-height optical centering and unconstrained text selection**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchSelectableText.swift`: Removed hardcoded static Latin `.baselineOffset` and switched to per-visual-line `CTRun` font metrics (`fontMidYOffset = (max(runFont.ascender) + min(runFont.descender)) / 2` and `max(-runFont.underlinePosition)`):
     - Fixed-`lineHeight` text centers optically within its `Line Height` via a uniform per-visual-line `deltaY` (preventing glyph-ink-bound baseline jitter) and expands selection height symmetrically across the full `lineHeight`.
     - Unconstrained static selectable text (`lineHeight == nil`) keeps `WorkbenchSelectableTextSizingLayout` outer sizing, glyph drawing origin, and native TextKit `enumerateEnclosingRects` geometry aligned so tall CJK/punctuation characters are not clipped at the top edge.
   - `apps/macos-native/Sources/CueSeekerApp/Shared/SubtitleTable/SubtitleTableTextLayout.swift`, `SubtitleTableCueGeometry.swift`, `SubtitleTableCoordinator+Drawing.swift`, `SubtitleTableCoordinator+SelectionAndInput.swift`, `SubtitleTableCoordinator+Testing.swift`: Replaced static `.baselineOffset` with per-visual-line `CTRun` font metric midpoints (`(maxAscender + minDescender) / 2`) centered within fixed line heights (`20px` body, `24px` primary cue, `20px` secondary cue) with zero baseline shift across character shapes; aligned table column headers by visible font center (`firstLineCenterYOffset` to `cellRect.midY`), reused `SubtitleTableText.cellLineHeight` (`20px`) for horizontally aligned symmetric header selection rects, and widened header `clipRect` vertically within cell bounds to accommodate the full `20px` selection band.

4. **Unify interactive hover underline offset across all 4 `Grab` link surfaces**
   - Removed the duplicate `- baselineOffset` subtraction in `WorkbenchSelectableTextNSView.underlineRects`, aligning both `WorkbenchSelectableTextNSView.underlineRects` and `SubtitleTextLayout.underlineRects` on the actual drawn baseline (`lineFragmentRect.minY + originalBaselineY + deltaY`) plus `max(-runFont.underlinePosition)` and `--offset-interactive-text-underline` (`2px`) for pixel-aligned `1px` underlines.

5. **Scope check and unit test updates**
   - Preserved minimal in-place architecture without adding standalone layout frameworks, metric engines, intermediate models, custom header views, `docs/human/design/` edits, or production test probes.
   - Added cross-character selection/underline consistency tests and multi-column header `minY`/height parity tests in `SubtitleTextLayoutDecorationTests.swift`, and updated baseline-dependent assertions in `WorkbenchSelectableTextTests.swift`, `SubtitleTextLayoutTests.swift`, `SubtitleTextLayoutDecorationTests.swift`, and `SubtitleTableCueGeometryTests.swift`.

## Compilation & Unit Test Verification

1. **Final build and targeted headless pure-logic test verification (after simplification commit `f28cc51` and final code edits)**:
   - `swift build --package-path apps/macos-native`: `Build complete! (6.76s)`.
   - `swift test --package-path apps/macos-native --filter SubtitleTextLayout --filter SubtitleTableCueGeometry --filter WorkbenchSelectableText --filter PlaybackVisualLineStackLayout`: `49` passed (`0` failed).
2. **End-to-end acceptance**:
   - Optical centering, mixed CJK/English rendering, cross-character baseline stability, header selection alignment, playback subtitle stream selection bounds, and all 4 `Grab` hover underline surfaces remain with the user for interactive acceptance.
