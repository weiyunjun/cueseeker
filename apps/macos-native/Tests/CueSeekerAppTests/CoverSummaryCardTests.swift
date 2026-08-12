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

@Test
func shioriDetailPageScrollPinsControlsAfterCoverLeavesViewport() {
    let geometry = SubtitleTablePageScrollGeometry(
        scrollableHeaderHeight: 294,
        pinnedHeaderHeight: 52,
        tableHeaderHeight: 40,
        bottomInset: 14
    )

    #expect(geometry.scrollableHeaderOriginY(scrollOffset: 120) == -120)
    #expect(geometry.pinnedHeaderOriginY(scrollOffset: 120) == 174)
    #expect(geometry.pinnedHeaderOriginY(scrollOffset: 294) == 0)
    #expect(geometry.pinnedHeaderOriginY(scrollOffset: 500) == 0)
    #expect(geometry.rowsOriginY == 386)
}

@Test
func shioriDetailPageScrollKeepsRowsBelowPinnedChrome() {
    let geometry = SubtitleTablePageScrollGeometry(
        scrollableHeaderHeight: 294,
        pinnedHeaderHeight: 52,
        tableHeaderHeight: 40,
        bottomInset: 14
    )
    let viewportSize = CGSize(width: 1_000, height: 700)

    let initial = geometry.tableBodyVisibleRect(
        scrollOffset: 0,
        viewportSize: viewportSize
    )
    let pinned = geometry.tableBodyVisibleRect(
        scrollOffset: 400,
        viewportSize: viewportSize
    )

    #expect(initial.minY == geometry.rowsOriginY)
    #expect(pinned.minY == 492)
    #expect(pinned.height == 608)
    #expect(geometry.documentHeight(rowsHeight: 2_000, viewportHeight: 700) == 2_400)
    #expect(geometry.scrollOffsetForRow(localRowY: 500, maximumOffset: 2_000) == 794)
}
