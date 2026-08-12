import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func coverSummaryLayoutKeepsSixteenByNineCoverLeftAligned() {
    let container = CGSize(width: 1_200, height: 246)
    let layout = CoverSummaryCardLayout.resolve(containerSize: container)

    #expect(layout.coverFrame.minX == 0)
    #expect(layout.coverFrame.height == WorkbenchControlMetrics.redesignCoverSummaryHeight)
    #expect(
        layout.coverFrame.width / layout.coverFrame.height
            == WorkbenchControlMetrics.redesignLibraryCoverAspectRatio
    )
    #expect(layout.blendFrame.isEmpty)
}

@Test
func coverSummaryLayoutClipsCoverFromTheRightInCompactWidth() {
    let layout = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 400, height: 246)
    )

    #expect(layout.coverFrame.minX == 0)
    #expect(layout.coverFrame.maxX > 400)
    #expect(layout.blendFrame == CGRect(x: 0, y: 0, width: 400, height: 246))
}

@Test
func coverSummaryBlendMatchesTheActualCoverAndContentOverlap() {
    let layout = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 700, height: 246)
    )

    #expect(
        layout.blendFrame.minX
            == 700 - WorkbenchControlMetrics.redesignCoverSummaryContentSafeWidth
    )
    #expect(
        layout.blendFrame.maxX == layout.coverFrame.maxX
    )
    #expect(layout.blendFrame.height == layout.coverFrame.height)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryBlendMiddleOpacity == 0.72)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryBlendTrailingOpacity == 0.32)
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
