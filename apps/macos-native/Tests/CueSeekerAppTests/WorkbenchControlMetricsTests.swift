import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@Test
func workbenchFocusRingMetricsMatchDesignTokens() {
    #expect(WorkbenchControlMetrics.redesignFocusRingWidth == 2)
    #expect(WorkbenchControlMetrics.redesignFocusRingOffset == 2)
    #expect(WorkbenchControlMetrics.redesignFocusRingPathExpansion == 3)
}

@Test
func workbenchPageTitleAndDetailSpacingMatchTheAcceptedHierarchy() {
    // The page title sits in the topbar now, a step below the Cover Summary
    // title that names a second-level page and above the Section Title.
    #expect(WorkbenchControlMetrics.redesignFontSizePageTitle == 20)
    #expect(WorkbenchControlMetrics.redesignFontWeightPageTitle == .semibold)
    #expect(WorkbenchControlMetrics.redesignFontSizeCoverSummaryTitle == 22)
    #expect(WorkbenchControlMetrics.redesignFontSizeSectionTitle == 18)
    #expect(WorkbenchControlMetrics.redesignFontSizeBody == 14)
    #expect(WorkbenchControlMetrics.redesignSpacing2 == 8)
    #expect(WorkbenchControlMetrics.redesignSpacing1 == 4)
    #expect(
        WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
            == WorkbenchControlMetrics.redesignSpacing8
    )
    #expect(WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding == 32)
    #expect(
        WorkbenchControlMetrics.redesignWorkbenchPageScrollbarChannel
            == TableScrollbarPrimitiveMetrics.size
                + TableScrollbarPrimitiveMetrics.inset * 2
    )
    #expect(WorkbenchControlMetrics.redesignWorkbenchPageScrollbarChannel == 16)
    #expect(
        WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding
            == WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
                + WorkbenchControlMetrics.redesignWorkbenchPageScrollbarChannel
    )
    #expect(WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding == 48)
    #expect(
        WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
            == WorkbenchControlMetrics.redesignSpacing1
    )
    #expect(WorkbenchControlMetrics.redesignWorkbenchPageTopPadding == 4)
    #expect(
        WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
            == WorkbenchControlMetrics.redesignSpacing6
    )
    #expect(WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding == 24)
    #expect(
        SchemaWorkbenchStyle.pageHorizontalPadding
            == WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
    )
    #expect(WorkbenchControlMetrics.redesignSpacing5 == 20)
    #expect(
        WorkbenchControlMetrics.redesignWorkbenchMediaCardGridHorizontalPadding
            == WorkbenchControlMetrics.redesignSpacing5
    )
    #expect(WorkbenchControlMetrics.redesignWorkbenchMediaCardGridHorizontalPadding == 20)
    #expect(
        WorkbenchControlMetrics.redesignWorkbenchMediaCardGridHorizontalPadding
            == WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
                - WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding
    )
    #expect(
        WorkbenchControlMetrics.redesignWorkbenchMediaCardGridTrailingPadding
            == WorkbenchControlMetrics.redesignWorkbenchMediaCardGridHorizontalPadding
                + WorkbenchControlMetrics.redesignWorkbenchPageScrollbarChannel
    )
    #expect(WorkbenchControlMetrics.redesignWorkbenchMediaCardGridTrailingPadding == 36)
    #expect(
        WorkbenchControlMetrics.redesignSpacing6
            - WorkbenchControlMetrics.redesignCoverSummaryDetailTopPadding
            == 20
    )
}

@MainActor
@Test
func workbenchSearchFieldPlacesInsertionPointAfterCompleteText() {
    let editor = NSTextView()
    editor.string = "Focused 日本語 🎬"
    editor.setSelectedRange(NSRange(location: 0, length: 0))
    let expectedRange = NSRange(
        location: editor.string.utf16.count,
        length: 0
    )

    WorkbenchSearchField.placeInsertionPointAtEnd(in: editor)

    #expect(editor.selectedRange() == expectedRange)
}

@Test
func workbenchTopbarIsTallerThanTheWindowControlsBand() {
    #expect(WorkbenchControlMetrics.redesignWorkbenchTopbarHeight == 54)
    #expect(WorkbenchControlMetrics.redesignAppTopbarHeight == 54)
    #expect(WorkbenchControlMetrics.redesignWindowControlsBandHeight == 45)
    #expect(AppShellLayout.topBarHeight == WorkbenchControlMetrics.redesignWorkbenchTopbarHeight)
    #expect(WorkbenchControlMetrics.redesignAppTopbarContentHorizontalPadding == 24)
    #expect(WorkbenchControlMetrics.redesignWorkbenchPageScrollbarChannel == 16)
    #expect(WorkbenchControlMetrics.redesignAppTopbarContentTrailingPadding == 40)
}

@Test
func dialogWidthTiersAndTheListEditorsDerivedSizes() {
    #expect(WorkbenchControlMetrics.redesignDialogWidthSmall == 360)
    #expect(WorkbenchControlMetrics.redesignDialogWidthMedium == 480)
    #expect(WorkbenchControlMetrics.redesignDialogWidthXLarge == 720)
    #expect(WorkbenchControlMetrics.redesignDialogWindowMargin == 24)
    #expect(WorkbenchControlMetrics.redesignTaskPanelHeight == 500)
    #expect(WorkbenchControlMetrics.redesignExcerptListEditorCoverWidth == 312)
    #expect(WorkbenchControlMetrics.redesignExcerptListEditorWideFormWidth == 336)
    #expect(WorkbenchControlMetrics.redesignExcerptListEditorDescriptionHeight == 97.5)
}

@Test
func cardIconContainerMetricsMatchDesignSpecification() {
    #expect(WorkbenchControlMetrics.redesignCardIconContainerSize == 36)
    #expect(WorkbenchControlMetrics.redesignCardIconAccentBaseOpacity == 0.32)
    #expect(WorkbenchControlMetrics.redesignCardIconAccentFolderTabOpacity == 0.52)
    #expect(WorkbenchControlMetrics.redesignCardIconAccentAnkiLineOpacity == 0.59)
    #expect(WorkbenchControlMetrics.redesignCardIconAccentForegroundOpacity == 1.0)
    #expect(WorkbenchControlMetrics.redesignCardBaselineHeight == 68)
    #expect(WorkbenchControlMetrics.redesignCardTrailingIconButtonTopOffset == 2)
}

@Test
func buttonHeightMatchesDesignSpecification() {
    #expect(WorkbenchControlMetrics.redesignHeight == 36)
    #expect(WorkbenchControlMetrics.redesignSearchHeight == 36)
    #expect(WorkbenchControlMetrics.redesignFieldHeight == 30)
    #expect(WorkbenchControlMetrics.redesignFieldRadius == 6)
    #expect(WorkbenchControlMetrics.redesignFieldPaddingX == 10)
    #expect(WorkbenchControlMetrics.redesignFormLabelWidth == 72)
    #expect(WorkbenchControlMetrics.redesignTableCellHoverRadius == 8)
}

@Test
func iconButtonOpenAndBadgeColorTokensMatchDesignSpecification() {
    let button = WorkbenchIconButton(icon: .funnel, isRedesign: true)
    #expect(button.countBackground == WorkbenchRedesignColors.badgeNeutralBg)
    #expect(button.countTextColor == WorkbenchRedesignColors.badgeNeutralText)
    #expect(button.openBackground == nil)

    let lightAppearance = NSAppearance(named: .aqua)!
    lightAppearance.performAsCurrentDrawingAppearance {
        let color = WorkbenchRedesignColors.NS.badgeNeutralBg.usingColorSpace(.sRGB)!
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 229.0 / 255.0) < 0.01)
        #expect(abs(g - 231.0 / 255.0) < 0.01)
        #expect(abs(b - 235.0 / 255.0) < 0.01)
    }

    let darkAppearance = NSAppearance(named: .darkAqua)!
    darkAppearance.performAsCurrentDrawingAppearance {
        let color = WorkbenchRedesignColors.NS.badgeNeutralBg.usingColorSpace(.sRGB)!
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 1.0) < 0.01)
        #expect(abs(a - 0.20) < 0.01)
    }
}

@Test
func darkModeTokensAndSurfaceUnificationMatchDesignSpecification() {
    let darkAppearance = NSAppearance(named: .darkAqua)!
    
    // Dialog and Surface background unification
    darkAppearance.performAsCurrentDrawingAppearance {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        let bgDialogDark = WorkbenchRedesignColors.NS.bgDialog.usingColorSpace(.sRGB)!
        let bgSurfaceDark = WorkbenchRedesignColors.NS.bgSurface.usingColorSpace(.sRGB)!
        bgDialogDark.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        bgSurfaceDark.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        #expect(abs(r1 - r2) < 0.001)
        #expect(abs(g1 - g2) < 0.001)
        #expect(abs(b1 - b2) < 0.001)
    }
    
    // Checkbox checked uses accent color
    #expect(WorkbenchRedesignColors.NS.bgCheckboxChecked == NSColor.controlAccentColor)
}

@Test
func workbenchButtonNeutralVariantsAndOpenColorLinkage() {
    let iconOnly = WorkbenchButton(icon: .listChecks, isRedesign: true) {}
    #expect(iconOnly.icon == .listChecks)
    #expect(iconOnly.title == nil)
    #expect(iconOnly.count == 0)

    let withBadge = WorkbenchButton(icon: .funnel, count: 4, isRedesign: true, isOpen: true) {}
    #expect(withBadge.icon == .funnel)
    #expect(withBadge.count == 4)
    #expect(withBadge.isOpen == true)

    let withTitle = WorkbenchButton(title: "默认排序", icon: .funnelSimple, isRedesign: true, isOpen: false) {}
    #expect(withTitle.title == "默认排序")
    #expect(withTitle.icon == .funnelSimple)
    #expect(withTitle.isOpen == false)

    // Verify Active tokens follow system controlAccentColor dynamically
    #expect(WorkbenchRedesignColors.NS.iconActive == NSColor.controlAccentColor)
    #expect(WorkbenchRedesignColors.NS.textActive == NSColor.controlAccentColor)
    #expect(WorkbenchRedesignColors.NS.borderActive == NSColor.controlAccentColor)
    #expect(WorkbenchRedesignColors.NS.accent == NSColor.controlAccentColor)
    #expect(WorkbenchRedesignColors.iconActive == Color(nsColor: WorkbenchRedesignColors.NS.iconActive))
    #expect(WorkbenchRedesignColors.textActive == Color(nsColor: WorkbenchRedesignColors.NS.textActive))
    #expect(WorkbenchRedesignColors.borderActive == Color(nsColor: WorkbenchRedesignColors.NS.borderActive))
    #expect(WorkbenchRedesignColors.bgActive == Color(nsColor: WorkbenchRedesignColors.NS.bgActive))
}

@Test
func workbenchIconButtonOpenStateMatchesSpecification() {
    let openIconButton = WorkbenchIconButton(icon: .gear, isRedesign: true, isOpen: true)
    #expect(openIconButton.isOpen == true)
    #expect(openIconButton.icon == .gear)
    #expect(openIconButton.redesignIconColor == WorkbenchRedesignColors.textSecondary)

    let idleIconButton = WorkbenchIconButton(icon: .gear, isRedesign: true, isOpen: false)
    #expect(idleIconButton.redesignIconColor == WorkbenchRedesignColors.textSecondary)

    // Verify custom surface iconColor (e.g. player topbar white textPrimary)
    // applies in idle state and remains matching in open state.
    let playerIdle = WorkbenchIconButton(
        icon: .tray,
        isRedesign: true,
        isOpen: false,
        iconColor: .white
    )
    #expect(playerIdle.redesignIconColor == .white)

    let playerOpen = WorkbenchIconButton(
        icon: .tray,
        isRedesign: true,
        isOpen: true,
        iconColor: .white
    )
    #expect(playerOpen.redesignIconColor == .white)

    // Verify explicit openIconColor override if specified
    let customOpen = WorkbenchIconButton(
        icon: .tray,
        isRedesign: true,
        isOpen: true,
        iconColor: .white,
        openIconColor: .yellow
    )
    #expect(customOpen.redesignIconColor == .yellow)
}

@Test
func workbenchTablePinnedToolbarHeightMatchesSpecification() {
    let searchPinnedToolbarHeight =
        WorkbenchControlMetrics.redesignHeight * 2
        + WorkbenchControlMetrics.redesignSpacing4 * 2
    // 36 (search field) + 16 (spacing-4) + 36 (second row) + 16 (bottom spacing-4) = 104
    #expect(searchPinnedToolbarHeight == 104)

    let excerptMergedPinnedToolbarHeight =
        WorkbenchControlMetrics.redesignHeight
        + WorkbenchControlMetrics.redesignSpacing4
    // 36 (merged single row) + 16 (bottom spacing-4) = 52
    #expect(excerptMergedPinnedToolbarHeight == 52)
    #expect(WorkbenchControlMetrics.redesignSpacing3 == 12)
}

@Test
func mediaCardGridMetricsAndMinimumWindowColumnCountMatchSpecification() {
    #expect(WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth == 220)
    #expect(WorkbenchControlMetrics.redesignLibraryRecentGridGap == 8)
    #expect(WorkbenchControlMetrics.redesignLibraryEpisodeGridGap == 8)
    #expect(WorkbenchControlMetrics.redesignLibraryRecentGridMaxColumnsWithSidebar == 5)
    #expect(WorkbenchControlMetrics.redesignLibraryRecentGridMaxColumnsWithoutSidebar == 6)

    // At minimum Workbench page content width (600px), subtracting inline grid
    // padding (20px leading + 36px trailing = 56px) leaves 544px, which fits
    // 2 cards per row (2 cards require 220 * 2 + 8 = 448px; 3 require 676px).
    let minimumWorkbenchGridWidth =
        WorkbenchControlMetrics.workbenchMediaCardGridWidth(
            viewportWidth: AppShellLayout.pageContentMinimumWidth
        )
    #expect(minimumWorkbenchGridWidth == 544)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: minimumWorkbenchGridWidth) == 2)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 447) == 1)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 448) == 2)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 675) == 2)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 676) == 3)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 903) == 3)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 904) == 4)
    // Command Panel grid width (1040 - 40 = 1000px) fits 4 cards per row.
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 1_000) == 4)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 1_131) == 4)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 1_132) == 5)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 1_359) == 5)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 1_360) == 6)

    // Without Sidebar (and in Playback Overlay), column count is 6 on 1504x846
    // with left Dock (1375px / 1383px) or bottom Dock (1440px / 1448px), and caps at 6 on 1920px.
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 1_375) == 6)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 1_448) == 6)
    #expect(PlaybackCommandPanelCardGrid.columnCount(containerWidth: 1_864) == 6)

    // With Sidebar visible, column count is 5 on 1504x846 with left Dock (~1138px–1143px)
    // or bottom Dock (1208px), and caps at 5 on 1920x1080 (1624px).
    #expect(
        LibraryOverviewGrid<EmptyView>.columnCount(
            containerWidth: 1_138,
            maxColumns: WorkbenchControlMetrics.redesignLibraryRecentGridMaxColumnsWithSidebar
        ) == 5
    )
    #expect(
        LibraryOverviewGrid<EmptyView>.columnCount(
            containerWidth: 1_208,
            maxColumns: WorkbenchControlMetrics.redesignLibraryRecentGridMaxColumnsWithSidebar
        ) == 5
    )
    #expect(
        LibraryOverviewGrid<EmptyView>.columnCount(
            containerWidth: 1_624,
            maxColumns: WorkbenchControlMetrics.redesignLibraryRecentGridMaxColumnsWithSidebar
        ) == 5
    )
}

@MainActor
@Test
func segmentedControlAccentStylingAndGeometryTokensMatchSpecification() {
    #expect(WorkbenchControlMetrics.redesignSegmentedControlHeight == 32)
    #expect(WorkbenchControlMetrics.redesignSegmentedControlPadding == 3)
    #expect(WorkbenchControlMetrics.redesignSegmentedControlGap == 2)
    #expect(WorkbenchControlMetrics.redesignCornerRadius == 8)
    #expect(WorkbenchControlMetrics.redesignSegmentedControlSegmentRadius == 5)
    #expect(WorkbenchControlMetrics.redesignSegmentedControlSegmentHeight == 26)
    #expect(WorkbenchControlMetrics.redesignFontSizeSegmentedControl == 12)
    #expect(WorkbenchControlMetrics.redesignFontWeightControl == .medium)
    #expect(WorkbenchControlMetrics.redesignControlBorderWidth == 1)
    #expect(WorkbenchRedesignColors.NS.segmentedControlSelectedBg == NSColor.controlAccentColor)

    for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
        let appearance = NSAppearance(named: appearanceName)!
        appearance.performAsCurrentDrawingAppearance {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            let selectedContent = WorkbenchRedesignColors.NS.segmentedControlSelectedContent.usingColorSpace(.sRGB)!
            selectedContent.getRed(&r, green: &g, blue: &b, alpha: &a)
            #expect(abs(r - 1) < 0.001)
            #expect(abs(g - 1) < 0.001)
            #expect(abs(b - 1) < 0.001)
            #expect(abs(a - 1) < 0.001)
        }
    }
}

@MainActor
@Test
func topbarTabsStylingGeometryAndSlidingMotionMatchSpecification() {
    #expect(PlaybackOverlayMetrics.tabGap == 16)
    #expect(PlaybackOverlayMetrics.tabHorizontalPadding == 8)
    #expect(PlaybackOverlayMetrics.tabIndicatorGap == 4)
    #expect(PlaybackOverlayMetrics.tabFontSize == 14)
    #expect(PlaybackOverlayMetrics.tabFontWeight == .semibold)
    #expect(PlaybackOverlayMetrics.tabIndicatorWidth == 24)
    #expect(PlaybackOverlayMetrics.tabIndicatorHeight == 2)
    #expect(PlaybackOverlayMetrics.tabSelectionMotionDuration == 0.18)

    let tabRect = CGRect(x: 100, y: 10, width: 80, height: 24)
    #expect(
        PlaybackOverlayMetrics.tabIndicatorFrame(for: tabRect)
            == CGRect(x: 128, y: 32, width: 24, height: 2)
    )

    for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
        let appearance = NSAppearance(named: appearanceName)!
        appearance.performAsCurrentDrawingAppearance {
            let unselected = PlaybackOverlayMetrics.interpolatedTabTextColor(progress: 0).usingColorSpace(.sRGB)!
            let selected = PlaybackOverlayMetrics.interpolatedTabTextColor(progress: 1).usingColorSpace(.sRGB)!
            let midpoint = PlaybackOverlayMetrics.interpolatedTabTextColor(progress: 0.5).usingColorSpace(.sRGB)!
            let textMuted = WorkbenchRedesignColors.NS.textMuted.usingColorSpace(.sRGB)!
            let textPrimary = WorkbenchRedesignColors.NS.textPrimary.usingColorSpace(.sRGB)!

            #expect(unselected == textMuted)
            #expect(selected == textPrimary)

            var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var rm: CGFloat = 0, gm: CGFloat = 0, bm: CGFloat = 0, am: CGFloat = 0
            textMuted.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
            textPrimary.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            midpoint.getRed(&rm, green: &gm, blue: &bm, alpha: &am)

            #expect(abs(rm - (r0 + r1) / 2) < 0.001)
            #expect(abs(gm - (g0 + g1) / 2) < 0.001)
            #expect(abs(bm - (b0 + b1) / 2) < 0.001)
            #expect(abs(am - 1) < 0.001)
        }
    }
}

@MainActor
@Test
func buttonPressedAndHoverColorTokensMatchDesignSpecification() {
    let lightAppearance = NSAppearance(named: .aqua)!
    lightAppearance.performAsCurrentDrawingAppearance {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        // --color-bg-pressed: Light #E5E7EB
        WorkbenchRedesignColors.NS.bgPressed.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 229.0 / 255.0) < 0.005)
        #expect(abs(g - 231.0 / 255.0) < 0.005)
        #expect(abs(b - 235.0 / 255.0) < 0.005)
        #expect(abs(a - 1.0) < 0.005)

        // --color-danger-bg-pressed: Light #FEE4E2
        WorkbenchRedesignColors.NS.dangerBgPressed.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 254.0 / 255.0) < 0.005)
        #expect(abs(g - 228.0 / 255.0) < 0.005)
        #expect(abs(b - 226.0 / 255.0) < 0.005)

        // --color-overlay-surface-shortcut-button-bg-pressed: Light #E1E4E9
        WorkbenchRedesignColors.NS.overlaySurfaceShortcutButtonPressedBg.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 225.0 / 255.0) < 0.005)
        #expect(abs(g - 228.0 / 255.0) < 0.005)
        #expect(abs(b - 233.0 / 255.0) < 0.005)

        // --color-overlay-surface-keycap-bg-pressed: Light #C4C9D3
        WorkbenchRedesignColors.NS.overlaySurfaceKeycapPressedBg.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 196.0 / 255.0) < 0.005)
        #expect(abs(g - 201.0 / 255.0) < 0.005)
        #expect(abs(b - 211.0 / 255.0) < 0.005)

        // --color-popover-surface-shortcut-button-bg-pressed: Light #EDEFF2
        WorkbenchRedesignColors.NS.popoverSurfaceShortcutButtonPressedBg.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 237.0 / 255.0) < 0.005)
        #expect(abs(g - 239.0 / 255.0) < 0.005)
        #expect(abs(b - 242.0 / 255.0) < 0.005)

        // --color-popover-surface-keycap-bg-pressed: Light #D2D6DE
        WorkbenchRedesignColors.NS.popoverSurfaceKeycapPressedBg.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 210.0 / 255.0) < 0.005)
        #expect(abs(g - 214.0 / 255.0) < 0.005)
        #expect(abs(b - 222.0 / 255.0) < 0.005)

        // --color-filter-chip-selected-bg-hover & --color-filter-chip-selected-bg-pressed (Light 0.12 / 0.16)
        WorkbenchRedesignColors.NS.filterChipSelectedBgHover.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0.12) < 0.005)
        WorkbenchRedesignColors.NS.filterChipSelectedBgPressed.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0.16) < 0.005)

        // --color-primary-button-bg-hover (12% black blend) & --color-primary-button-bg-pressed (22% black blend)
        let baseAccent = NSColor.controlAccentColor.usingColorSpace(.sRGB)!
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        baseAccent.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        WorkbenchRedesignColors.NS.primaryButtonBgHover.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - ar * 0.88) < 0.01)
        #expect(abs(g - ag * 0.88) < 0.01)
        #expect(abs(b - ab * 0.88) < 0.01)
        WorkbenchRedesignColors.NS.primaryButtonBgPressed.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - ar * 0.78) < 0.01)
        #expect(abs(g - ag * 0.78) < 0.01)
        #expect(abs(b - ab * 0.78) < 0.01)
    }

    let darkAppearance = NSAppearance(named: .darkAqua)!
    darkAppearance.performAsCurrentDrawingAppearance {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        // --color-bg-pressed: Dark rgba(255,255,255,0.16)
        WorkbenchRedesignColors.NS.bgPressed.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 1.0) < 0.005)
        #expect(abs(a - 0.16) < 0.005)

        // --color-danger-bg-pressed: Dark #4C1D1D
        WorkbenchRedesignColors.NS.dangerBgPressed.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 76.0 / 255.0) < 0.005)
        #expect(abs(g - 29.0 / 255.0) < 0.005)
        #expect(abs(b - 29.0 / 255.0) < 0.005)

        // --color-overlay-surface-shortcut-button-bg-pressed & --color-popover-surface-shortcut-button-bg-pressed: Dark alpha 0.12
        WorkbenchRedesignColors.NS.overlaySurfaceShortcutButtonPressedBg.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0.12) < 0.005)
        WorkbenchRedesignColors.NS.popoverSurfaceShortcutButtonPressedBg.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0.12) < 0.005)

        // --color-overlay-surface-keycap-bg-pressed & --color-popover-surface-keycap-bg-pressed: Dark alpha 0.22
        WorkbenchRedesignColors.NS.overlaySurfaceKeycapPressedBg.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0.22) < 0.005)
        WorkbenchRedesignColors.NS.popoverSurfaceKeycapPressedBg.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0.22) < 0.005)

        // --color-filter-chip-selected-bg-hover & --color-filter-chip-selected-bg-pressed (Dark 0.18 / 0.24)
        WorkbenchRedesignColors.NS.filterChipSelectedBgHover.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0.18) < 0.005)
        WorkbenchRedesignColors.NS.filterChipSelectedBgPressed.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0.24) < 0.005)

        // --color-primary-button-bg-hover (12% white blend) & --color-primary-button-bg-pressed (22% white blend)
        let baseAccent = NSColor.controlAccentColor.usingColorSpace(.sRGB)!
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        baseAccent.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        WorkbenchRedesignColors.NS.primaryButtonBgHover.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - (ar * 0.88 + 0.12)) < 0.01)
        #expect(abs(g - (ag * 0.88 + 0.12)) < 0.01)
        #expect(abs(b - (ab * 0.88 + 0.12)) < 0.01)
        WorkbenchRedesignColors.NS.primaryButtonBgPressed.usingColorSpace(.sRGB)!
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - (ar * 0.78 + 0.22)) < 0.01)
        #expect(abs(g - (ag * 0.78 + 0.22)) < 0.01)
        #expect(abs(b - (ab * 0.78 + 0.22)) < 0.01)
    }

    #expect(PlaybackTheme.controlPressedBackground == Color.white.opacity(0.24))
}

@Test
func taskCountBadgeGapMatchesFilterButtonSpacingToken() {
    #expect(
        WorkbenchControlMetrics.redesignTaskCountBadgeGap
            == WorkbenchControlMetrics.redesignSpacing2
    )
    #expect(WorkbenchControlMetrics.redesignTaskCountBadgeGap == 8)
}
