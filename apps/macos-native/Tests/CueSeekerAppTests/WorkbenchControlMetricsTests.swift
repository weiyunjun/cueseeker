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
    #expect(WorkbenchControlMetrics.redesignFontSizeCoverSummaryTitle == 28)
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
    #expect(WorkbenchControlMetrics.redesignCardIconGlyphSize == 20)
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
func segmentedControlNeutralStylingAndGeometryTokensMatchSpecification() {
    #expect(WorkbenchControlMetrics.redesignSegmentedControlHeight == 32)
    #expect(WorkbenchControlMetrics.redesignSegmentedControlPadding == 3)
    #expect(WorkbenchControlMetrics.redesignSegmentedControlGap == 2)
    #expect(WorkbenchControlMetrics.redesignCornerRadius == 8)
    #expect(WorkbenchControlMetrics.redesignSegmentedControlSegmentRadius == 5)
    #expect(WorkbenchControlMetrics.redesignSegmentedControlSegmentHeight == 26)
    #expect(WorkbenchControlMetrics.redesignFontSizeSegmentedControl == 12)
    #expect(WorkbenchControlMetrics.redesignFontWeightControl == .medium)
    #expect(WorkbenchControlMetrics.redesignControlBorderWidth == 1)

    let lightAppearance = NSAppearance(named: .aqua)!
    lightAppearance.performAsCurrentDrawingAppearance {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        let bg = WorkbenchRedesignColors.NS.segmentedControlBg.usingColorSpace(.sRGB)!
        bg.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 0) < 0.001)
        #expect(abs(g - 0) < 0.001)
        #expect(abs(b - 0) < 0.001)
        #expect(abs(a - 0.055) < 0.001)

        let border = WorkbenchRedesignColors.NS.segmentedControlBorder.usingColorSpace(.sRGB)!
        border.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(a - 0) < 0.001)

        let selectedBg = WorkbenchRedesignColors.NS.segmentedControlSelectedBg.usingColorSpace(.sRGB)!
        selectedBg.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 1) < 0.001)
        #expect(abs(g - 1) < 0.001)
        #expect(abs(b - 1) < 0.001)
        #expect(abs(a - 1) < 0.001)

        let selectedBorder = WorkbenchRedesignColors.NS.segmentedControlSelectedBorder.usingColorSpace(.sRGB)!
        selectedBorder.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 229.0 / 255.0) < 0.01)
        #expect(abs(g - 231.0 / 255.0) < 0.01)
        #expect(abs(b - 235.0 / 255.0) < 0.01)
        #expect(abs(a - 1) < 0.001)

        let selectedContent = WorkbenchRedesignColors.NS.segmentedControlSelectedContent.usingColorSpace(.sRGB)!
        let textPrimary = WorkbenchRedesignColors.NS.textPrimary.usingColorSpace(.sRGB)!
        #expect(selectedContent == textPrimary)

        let unselectedContent = WorkbenchRedesignColors.NS.segmentedControlUnselectedContent.usingColorSpace(.sRGB)!
        let textMuted = WorkbenchRedesignColors.NS.textMuted.usingColorSpace(.sRGB)!
        #expect(unselectedContent == textMuted)
    }

    let darkAppearance = NSAppearance(named: .darkAqua)!
    darkAppearance.performAsCurrentDrawingAppearance {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        let bg = WorkbenchRedesignColors.NS.segmentedControlBg.usingColorSpace(.sRGB)!
        bg.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 1) < 0.001)
        #expect(abs(g - 1) < 0.001)
        #expect(abs(b - 1) < 0.001)
        #expect(abs(a - 0.06) < 0.001)

        let border = WorkbenchRedesignColors.NS.segmentedControlBorder.usingColorSpace(.sRGB)!
        border.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 1) < 0.001)
        #expect(abs(g - 1) < 0.001)
        #expect(abs(b - 1) < 0.001)
        #expect(abs(a - 0.08) < 0.001)

        let selectedBg = WorkbenchRedesignColors.NS.segmentedControlSelectedBg.usingColorSpace(.sRGB)!
        selectedBg.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 1) < 0.001)
        #expect(abs(g - 1) < 0.001)
        #expect(abs(b - 1) < 0.001)
        #expect(abs(a - 0.16) < 0.001)

        let selectedBorder = WorkbenchRedesignColors.NS.segmentedControlSelectedBorder.usingColorSpace(.sRGB)!
        selectedBorder.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 1) < 0.001)
        #expect(abs(g - 1) < 0.001)
        #expect(abs(b - 1) < 0.001)
        #expect(abs(a - 0.12) < 0.001)

        let selectedContent = WorkbenchRedesignColors.NS.segmentedControlSelectedContent.usingColorSpace(.sRGB)!
        let textPrimary = WorkbenchRedesignColors.NS.textPrimary.usingColorSpace(.sRGB)!
        #expect(selectedContent == textPrimary)

        let unselectedContent = WorkbenchRedesignColors.NS.segmentedControlUnselectedContent.usingColorSpace(.sRGB)!
        let textMuted = WorkbenchRedesignColors.NS.textMuted.usingColorSpace(.sRGB)!
        #expect(unselectedContent == textMuted)
    }
}
