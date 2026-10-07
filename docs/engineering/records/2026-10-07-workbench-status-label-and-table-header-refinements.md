# Workbench Status Label and Table Header Refinements

Human-owned documents:

- `docs/human/requirements/20261007-UI-Workbench Status Label And Table Header Refinements.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Inconsistent Status & Metric Labels**:
   - Result counts and overview summaries across Search (`xx results`), Library (`xx folders`), File (`Last Updated: xxx`), and Excerpt (`xx lists  yy cues`) lacked unified typography and component encapsulation, using varied font weights and colors (`textMuted` vs `textSecondary`).
2. **Missing Folder Count in Library Sort Row**:
   - The Library overview sort action row only contained the right-aligned sort button, missing a counterpart metric indicating total folder count.
3. **Excerpt Overview Typography and Button Variant**:
   - The Excerpt summary text was formatted with title casing and middle dot (`%1$@ · %2$@`), rather than lowercase with double space separation (`%d lists  %d cues`).
   - The "New List" button used `WorkbenchPrimaryButton`, rather than a standard Neutral button with Phosphor `plus` icon aligned with other action bars.
4. **Table Header Height and Spacing Refinement**:
   - Workbench table headers (Search, Excerpt List) had excess vertical padding (40px) above text; reducing header container height to 27px while top-aligning header labels preserves visual distance to the bottom divider.
   - Index column `#` and batch selection checkbox required horizontal centering and vertical top alignment.
   - Vertical gaps between the search field, action row, and table header required standardization to `--spacing-4` (16px).

## What changed

1. **Unified Status & Metric Label (`WorkbenchStatusIndicator.swift`)**:
   - Created `WorkbenchStatusIndicator` conforming to the 36px `--height-control`, 14px Medium `--font-weight-control`, and `--color-text-secondary` specification with optional leading icon support.
   - Refactored `WorkbenchFileView.statusIndicator`, `SchemaWorkbenchSearchToolbar`, `WorkbenchTestLibraryView.sortBar`, and `LibraryOverviewLayout` to use `WorkbenchStatusIndicator`.
2. **Library Folder Count & Localization (`WorkbenchTestLibraryView.swift`, `Localizable.strings`)**:
   - Added `WorkbenchStatusIndicator` displaying folder count to the left side of `sortBar`.
   - Added `library.folder_count.one` and `library.folder_count.other` across English (`%d folders`), Simplified Chinese (`%d 个文件夹`), and Traditional Chinese (`%d 個資料夾`).
3. **Excerpt Overview & Neutral Action Button (`LibraryOverviewComponents.swift`, `Localizable.strings`, `plus.svg`, `AppIcon.swift`)**:
   - Imported Phosphor standard `plus.svg` (`U+E3D4`) and added `case plus = "plus"` to `AppIcon`.
   - Updated `LibraryOverviewLayout` action button to `WorkbenchButton(title: actionTitle, icon: .plus, isRedesign: true)`.
   - Updated Excerpt summary strings across English (`%d lists  %d cues`), Simplified Chinese (`%d 个列表  %d 条字幕`), and Traditional Chinese (`%d 個列表  %d 條字幕`).
4. **Table Header & Toolbar Spacing (`WorkbenchControls.swift`, `SubtitleTableView.swift`, `SchemaWorkbenchSearchShell.swift`, `WorkbenchExcerptTableView.swift`)**:
   - Updated `--height-table-header` (`redesignTableHeaderHeight`) from 40px to 27px.
   - Configured `SubtitleTableHeaderCellView` and `drawHeader` to top-align column headers and top-align `#` with horizontal centering.
   - Configured `WorkbenchCheckboxButton` to align header select-all checkbox horizontally centered and vertically top-aligned.
   - Adjusted toolbar vertical spacing in `SchemaWorkbenchSearchToolbar` and `WorkbenchExcerptTableContent` to `--spacing-4` (16px).
   - Fixed `pinnedHeaderHeight` and `excerptEmptyHint.topChromeHeight` in `WorkbenchExcerptTableView.swift` to use `redesignSpacing4 * 2` (104px), preventing the pinned toolbar from overlaying the top of the table header.
   - Updated `SubtitleTableVirtualRowTests.swift` scroll offset expectations for the 27px table header height.

## Verification

- `swift build --product CueSeeker --package-path apps/macos-native`: passed.
- `swift test --package-path apps/macos-native --filter SubtitleTable`: passed (188/188 tests passed).
- `swift test --package-path apps/macos-native --filter AppIconAssetTests`: passed (6/6 tests passed).
- `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: passed (13/13 tests passed).
- `swift test --package-path apps/macos-native --filter CoverSummaryCardTests`: passed (10/10 tests passed).
- `swift test --package-path apps/macos-native --filter FileRouteNavigationTests`: passed (7/7 tests passed).
- `swift test --package-path apps/macos-native --filter LibrarySortTests`: passed (3/3 tests passed).
