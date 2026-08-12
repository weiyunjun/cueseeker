import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func coverSummaryLayoutKeepsSixteenByNineCoverLeftAligned() {
    let container = CGSize(width: 1_200, height: 252)
    let layout = CoverSummaryCardLayout.resolve(containerSize: container)

    #expect(layout.coverFrame.minX == 0)
    #expect(layout.coverFrame.size == CGSize(width: 448, height: 252))
    #expect(layout.coverFrame.height == WorkbenchControlMetrics.redesignCoverSummaryHeight)
    #expect(
        layout.coverFrame.width / layout.coverFrame.height
            == WorkbenchControlMetrics.redesignLibraryCoverAspectRatio
    )
    #expect(layout.contentFrame.minX == layout.coverFrame.maxX)
    #expect(
        layout.contentFrame.width
            == WorkbenchControlMetrics.redesignCoverSummaryContentSafeWidth
    )
    #expect(layout.contentFrame.size == layout.coverFrame.size)
    #expect(layout.blendFrame.isEmpty)
}

@Test
func coverSummaryLayoutFullyOverlapsAtCompactWidth() {
    let layout = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 700, height: 252)
    )

    #expect(layout.coverFrame == CGRect(x: 0, y: 0, width: 448, height: 252))
    #expect(layout.contentFrame == layout.coverFrame)
    #expect(layout.blendFrame == layout.coverFrame)
}

@Test
func coverSummaryLayoutSwitchesWithoutPartialOverlap() {
    let separated = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 896, height: 252)
    )
    let overlapped = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 895, height: 252)
    )

    #expect(separated.contentFrame == CGRect(x: 448, y: 0, width: 448, height: 252))
    #expect(separated.blendFrame.isEmpty)
    #expect(overlapped.contentFrame == overlapped.coverFrame)
    #expect(overlapped.blendFrame == overlapped.coverFrame)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryBlendMiddleOpacity == 0.72)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryBlendTrailingOpacity == 0.32)
}

@Test
func coverSummaryRegionsStayFixedAtMinimumWindowWidth() {
    let compactCardWidth = AppShellLayout.minimumWindowWidth
        - SchemaWorkbenchStyle.pageHorizontalPadding * 2
    let layout = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: compactCardWidth, height: 252)
    )

    #expect(compactCardWidth < layout.coverFrame.width)
    #expect(layout.coverFrame.size == CGSize(width: 448, height: 252))
    #expect(layout.contentFrame == layout.coverFrame)
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
