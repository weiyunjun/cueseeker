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
    #expect(WorkbenchControlMetrics.redesignAppTopbarHeight == 45)
    #expect(AppShellLayout.topBarHeight == WorkbenchControlMetrics.redesignWorkbenchTopbarHeight)
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
    #expect(WorkbenchControlMetrics.redesignExcerptListEditorDescriptionHeight == 58.5)
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
}

@Test
func iconButtonOpenAndBadgeColorTokensMatchDesignSpecification() {
    let button = WorkbenchIconButton(icon: .funnel, isRedesign: true)
    #expect(button.countBackground == Color.accentColor)
    #expect(button.countTextColor == WorkbenchRedesignColors.iconOnDark)
    #expect(button.countBackground.opacity(0.35) == Color.accentColor.opacity(0.35))
    #expect(button.openBackground == nil)
    #expect(PlaybackTheme.controlActiveBackground == Color.accentColor.opacity(0.26))
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
func coverSkeletonShimmerTokensMatchDesignSpecification() {
    #expect(WorkbenchControlMetrics.redesignShimmerMotionDuration == 1.5)
    #expect(WorkbenchControlMetrics.redesignCoverAntiFlickerDelayNanoseconds == 120_000_000)
    #expect(WorkbenchControlMetrics.redesignCoverCrossfadeDuration == 0.20)

    let darkAppearance = NSAppearance(named: .darkAqua)!
    darkAppearance.performAsCurrentDrawingAppearance {
        #expect(WorkbenchRedesignColors.NS.skeletonBase == WorkbenchRedesignColors.NS.libraryCoverPlaceholderBg)
    }

    let lightAppearance = NSAppearance(named: .aqua)!
    lightAppearance.performAsCurrentDrawingAppearance {
        #expect(WorkbenchRedesignColors.NS.skeletonBase == WorkbenchRedesignColors.NS.libraryCoverPlaceholderBg)
    }
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

    // Verify Active tokens exist and match specification
    #expect(WorkbenchRedesignColors.iconActive == Color(nsColor: WorkbenchRedesignColors.NS.iconActive))
    #expect(WorkbenchRedesignColors.textActive == Color(nsColor: WorkbenchRedesignColors.NS.textActive))
    #expect(WorkbenchRedesignColors.bgActive == Color(nsColor: WorkbenchRedesignColors.NS.bgActive))
}

@Test
func workbenchIconButtonOpenStateMatchesSpecification() {
    let openIconButton = WorkbenchIconButton(icon: .gear, isRedesign: true, isOpen: true)
    #expect(openIconButton.isOpen == true)
    #expect(openIconButton.icon == .gear)
}



