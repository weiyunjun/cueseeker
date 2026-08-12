import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func coverSummaryLayoutKeepsSixteenByNineCoverRightAligned() {
    let container = CGSize(width: 1_200, height: 246)
    let layout = CoverSummaryCardLayout.resolve(containerSize: container)

    #expect(layout.coverFrame.maxX == container.width)
    #expect(layout.coverFrame.height == WorkbenchControlMetrics.redesignCoverSummaryHeight)
    #expect(
        layout.coverFrame.width / layout.coverFrame.height
            == WorkbenchControlMetrics.redesignLibraryCoverAspectRatio
    )
    #expect(layout.blendFrame.minX == layout.coverFrame.minX)
}

@Test
func coverSummaryLayoutClipsCoverFromTheLeftInCompactWidth() {
    let layout = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 400, height: 246)
    )

    #expect(layout.coverFrame.minX < 0)
    #expect(layout.coverFrame.maxX == 400)
}

@Test
func coverSummarySafeContentFitsTheMinimumWindowCard() {
    let compactCardWidth = AppShellLayout.minimumWindowWidth
        - SchemaWorkbenchStyle.pageHorizontalPadding * 2

    #expect(
        WorkbenchControlMetrics.redesignCoverSummaryContentSafeWidth
            <= compactCardWidth
    )
}
