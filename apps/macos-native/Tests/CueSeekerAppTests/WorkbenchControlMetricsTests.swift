import AppKit
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
    #expect(
        WorkbenchControlMetrics.redesignFontSizePageTitle
            == WorkbenchControlMetrics.redesignFontSizeCoverSummaryTitle
    )
    #expect(WorkbenchControlMetrics.redesignFontSizePageTitle == 28)
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
