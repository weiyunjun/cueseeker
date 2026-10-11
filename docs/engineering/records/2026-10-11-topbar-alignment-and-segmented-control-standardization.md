# Topbar Alignment And Segmented Control Standardization

Human-owned documents:

- `docs/human/requirements/20261011-UI-Topbar Alignment And Segmented Control Standardization.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Workbench Topbar Right Button Alignment**:
   - The trailing margin of the Workbench topbar buttons was fixed to 24px, while page content below reserved a 16px vertical scrollbar channel (`--width-page-scrollbar-channel`), causing the rightmost Settings button to extend further right than the content.
2. **Topbar Height Inconsistency**:
   - Playback and Playback Overlay topbars were 45px while the Workbench topbar was 54px. Unifying them to 54px provides visual consistency across the app.
   - Native traffic light buttons (window controls) must preserve their vertical baseline in the 45px window controls band without shifting.
3. **Segmented Control Component & Layout Standardization**:
   - The Recent page, Playback Overlay, and Task panel previously used underline-style tabs (`WorkbenchTabs`).
   - The design specifies standardizing these views to use `WorkbenchSegmentedControl` (pill container with border and selected background fill, as in Settings General Appearance Mode).
   - In Recent, the segmented control moves to the topbar centered in the content area with simplified labels ("Videos" / "Excerpt Lists").
   - In TaskPanel, the segmented control moves to the top row alongside the title and close button.

## What changed

1. **Metrics & Padding (`WorkbenchControls.swift`, `AppWindowControls.swift`, `LiquidGlassVideoTopBar.swift`, `PlaybackSubtitleFocusOverlay.swift`)**:
   - Standardized `redesignAppTopbarHeight: CGFloat = 54`.
   - Defined `redesignWindowControlsBandHeight: CGFloat = 45` to anchor the native traffic lights and collapsed sidebar toggle vertically at their original position.
   - Defined `redesignAppTopbarContentTrailingPadding = redesignAppTopbarContentHorizontalPadding + redesignWorkbenchPageScrollbarChannel` (40px) across Workbench topbar, Playback topbar, and Playback Overlay topbar.
2. **Segmented Control Accessibility & Options (`WorkbenchSegmentedControl.swift`, `WorkbenchLayoutState.swift`, `Localizable.strings`)**:
   - Added `accessibilityIdentifier` support to `WorkbenchSegmentedControl`.
   - Added `shortLabel` to `WorkbenchRecentSection` ("Videos" / "Excerpt Lists"; "视频" / "摘录列表"; "影片" / "摘錄列表").
3. **Workbench Recent Topbar Integration (`AppTopbarLayout.swift`, `ContentView.swift`, `WorkbenchTestLibraryView.swift`)**:
   - Added `centerContent` slot to `AppTopbarLayout` centered in the content region.
   - Integrated `recentSegmentedControl` into `AppTopBar` for the Recent route.
   - Removed the inline `sectionTabs` from `WorkbenchRecentView`.
4. **Playback Overlay & Task Panel (`PlaybackSubtitleFocusOverlay.swift`, `TaskPanel.swift`)**:
   - Replaced `WorkbenchTabs` with `WorkbenchSegmentedControl` in `PlaybackOverlayTopBar` with updated trailing padding.
   - Integrated a unified `headerRow` in `TaskPanel` with title on the left, `WorkbenchSegmentedControl` in the center, and close button on the right.
5. **Test Coverage (`WorkbenchControlMetricsTests.swift`, `WorkbenchLayoutStateTests.swift`)**:
   - Updated metric assertions for 54px topbar height, 45px window controls band, and 40px trailing padding.
   - Added `workbenchRecentSectionLabelsAndShortLabelsMatchSpecification()` testing the new short labels.

## Verification

- `swift build --package-path apps/macos-native`: succeeded.
- `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: passed (12/12 tests passed).
- `swift test --package-path apps/macos-native --filter WorkbenchLayoutStateTests`: passed (13/13 tests passed).
- `swift test --package-path apps/macos-native --filter TaskQueueStoreTests`: passed (29/29 tests passed).
- `swift test --package-path apps/macos-native --filter PlaybackSubtitleFocusLayoutTests`: passed (72/72 tests passed).
