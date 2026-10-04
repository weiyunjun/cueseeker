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

