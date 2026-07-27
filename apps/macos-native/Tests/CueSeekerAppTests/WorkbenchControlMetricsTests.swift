import Testing
@testable import CueSeekerApp

@Test
func workbenchFocusRingMetricsMatchDesignTokens() {
    #expect(WorkbenchControlMetrics.redesignFocusRingWidth == 2)
    #expect(WorkbenchControlMetrics.redesignFocusRingOffset == 2)
    #expect(WorkbenchControlMetrics.redesignFocusRingPathExpansion == 3)
}

@Test
func workbenchFilterCountBadgeMetricsMatchDesignTokens() {
    #expect(WorkbenchControlMetrics.redesignFilterCountBadgeSize == 20)
    #expect(WorkbenchControlMetrics.redesignFilterCountBadgeHorizontalPadding == 6)
    #expect(WorkbenchControlMetrics.redesignFilterCountBadgeRadius == 9_999)
    #expect(
        WorkbenchRedesignColors.NS.filterCountBadgeBg
            === WorkbenchRedesignColors.NS.bgCheckboxChecked
    )
    #expect(
        WorkbenchRedesignColors.NS.filterCountBadgeText
            === WorkbenchRedesignColors.NS.checkboxIcon
    )
}
