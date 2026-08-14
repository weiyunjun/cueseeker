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
