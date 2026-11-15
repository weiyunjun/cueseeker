# 2026-11-15 Breadcrumb All Folders Copy, Token Consolidation, and Task Panel Header Alignment

- **Covering Requirement**: `docs/human/requirements/20261115-UI-Breadcrumb All Folders Copy And Topbar Dialog Header Token Alignment.md`
- **Branch / Baseline**: `main` (before change: `6f0d262`, requirement commit: `5d4dcf4`)

## Summary of Changes

1. **Unify localized `All Folders` copy and remove orphaned pluralization branches (`L-04.5`)**
   - `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`: Replaced split singular/plural keys `file.all_folders.one` / `file.all_folders.other` with a single `file.all_folders` key (`All Folders` in English, `全部文件夹` in Simplified Chinese, and `全部資料夾` in Traditional Chinese).
   - `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`, `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+WorkbenchAccessibility.swift`: Removed `FileBreadcrumbResolver.allFoldersTitle` and its `folderCount` / `singularRootTitle` / `pluralRootTitle` parameters, unifying `rootFoldersHeaderRow`, `breadcrumbNodes`, and accessibility node/click navigation onto `L("file.all_folders")` and removing the unused local `folders` binding.

2. **Align breadcrumb link color and `File` root/current node font weights (`C-05.6` / `L-04.5` / `L-06.4`)**
   - `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`: Removed `@State isHovered` and `.onPointerHover` color-switching state from shared `BreadcrumbLink`, fixing link text color to `WorkbenchRedesignColors.textSecondary` (`--color-text-secondary`) while preserving accessibility focus rings, click navigation, and disabled/cross-region text selection rules.
   - `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`, `apps/macos-native/Sources/CueSeekerApp/Library/RemoteFolderDialogSharedViews.swift`: Unified the font weight of the level-1 `File` `All Folders` header, level-2/3 current trailing breadcrumb nodes, and the step-2 remote folder browser current breadcrumb node from `.semibold` to `WorkbenchControlMetrics.redesignFontWeightControl` (`--font-weight-control: 500`).

3. **Complete design tokens and clean up local hardcoded literals (`UI Tokens` / `C-05.4` / `C-05.5` / `C-10.1` / `L-01.2` / `L-03.1` / `L-07.1` / `L-08.2`)**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControlMetrics.swift`: Added global tab and dialog title tokens `redesignFontWeightTab` (`--font-weight-tab: 600`), `redesignTabIndicatorWidth` (`--width-tab-indicator: 24px`), `redesignTabIndicatorHeight` (`--height-tab-indicator: 2px`), `redesignTabMotionEasing` (`--easing-tab-motion: cubic-bezier(0.22, 1, 0.36, 1)`), and `redesignFontWeightDialogTitle` / `redesignNSFontWeightDialogTitle` (`--font-weight-dialog-title: 600`); wired `redesignDialogTitleCapTopInset` directly to `redesignNSFontWeightDialogTitle`; deleted temporary alias `redesignAppTopbarContentHorizontalPadding` and defined `redesignAppTopbarContentTrailingPadding` as `redesignSpacing6 + redesignWorkbenchPageScrollbarChannel`.
   - `apps/macos-native/Sources/CueSeekerApp/Workbench/AppTopbarLayout.swift`: Pointed expanded workbench topbar leading padding directly to `WorkbenchControlMetrics.redesignSpacing6`.
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogHeader.swift`: Updated `WorkbenchDialogHeader` title font weight to `WorkbenchControlMetrics.redesignFontWeightDialogTitle`.
   - `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`: Delegated `PlaybackOverlayMetrics` tab constants to `WorkbenchControlMetrics` tokens to eliminate duplicate literals and easing curves across shared `WorkbenchTabs`; aligned `PlaybackChromeMetrics.topbarHorizontalPadding` and `windowControlsReturnGap` directly to `WorkbenchControlMetrics.redesignSpacing4` (`16px`), matching `--padding-player-topbar-x` and `--gap-player-window-controls-return`.

4. **Align `Task` panel header to the `24px` visual boundary (`C-10.1` / `L-06.9`)**
   - `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift`: Removed the `.frame(height: WorkbenchControlMetrics.redesignSegmentedControlHeight)` height stretch and uncompensated inline `WorkbenchIconButton` from `headerRow`, attached `.workbenchDialogCloseButton(closesOnEscape: confirmation.session == nil && tasks.detailTaskID == nil)` on the outer container, added `.fixedSize(horizontal: false, vertical: true)` to `WorkbenchAdaptiveHeaderBar` so it shrinks vertically to natural title height inside the `500px` `VStack`, and reserved trailing glyph ink clearance via a non-interactive accessibility-hidden `Color.clear.frame(width: WorkbenchControlMetrics.redesignDialogCloseGlyphInk, height: 1)`. Updated the `Task` title to `redesignFontWeightDialogTitle` while preserving truncation tooltips, centered `WorkbenchTabs` with `--spacing-3` narrow-width collision clearance, `Esc` gating, and accessibility traversal order.

5. **Scope verification and unit test updates**
   - Applied surgical in-place edits without adding standalone modules, generalized engines, manager layers, redundant models, `docs/human/` edits, or production test backdoors.
   - Updated affected pure-logic assertions in `apps/macos-native/Tests/CueSeekerAppTests/FileRouteNavigationTests.swift` and `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchControlMetricsTests.swift`.

## Compilation & Unit Test Verification

Executed after the final code and test edits:

1. **Build verification**:
   - `swift build --package-path apps/macos-native`: `Build complete! (0.32s)`, `0` errors.
2. **Targeted headless pure-logic tests (filtered, zero window popups)**:
   - `swift test --package-path apps/macos-native --filter "FileRouteNavigationTests|WorkbenchControlMetricsTests|WorkbenchLayoutStateTests|WorkbenchAccessibilityStep2Tests|everyBundledLanguageDefinesTheSameKeys|singularCountKeysDoNotContainUnresolvedFormatPlaceholders"`
   - Result: `50` Swift Testing cases passed (`0` failed, covering `FileRouteNavigationTests`, `WorkbenchControlMetricsTests`, `WorkbenchLayoutStateTests`, `WorkbenchAccessibilityStep2Tests`, and localization key parity). (Note: pre-existing unrelated `AppLocalizationTests.simplifiedAndTraditionalChineseRefinedTranslationsMatchSpecification` failure on `en["file_detail.associated_video"]` remains outside this requirement's scope.)
3. **End-to-end acceptance**:
   - Visual verification of breadcrumb hover/weights, `All Folders` header, topbar padding, `Task` panel `24px` four-edge visual alignment, tab centering/clearance, tooltips, and `Esc`/accessibility behavior remains with the user.
