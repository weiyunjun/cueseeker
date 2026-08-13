import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func coverSummaryUsesSharedPlaybackActionTitles() {
    #expect(CoverSummaryActionKind.play.title == "Play")
    #expect(CoverSummaryActionKind.resume.title == "Resume")
}

@Test
func coverSummaryLayoutUsesTheFullContainerAsItsBackground() {
    let container = CGSize(width: 1_260, height: 252)
    let layout = CoverSummaryCardLayout.resolve(containerSize: container)

    #expect(layout.backgroundFrame == CGRect(x: 0, y: 0, width: 1_260, height: 252))
    #expect(layout.backgroundFrame.width / layout.backgroundFrame.height == 5)
    #expect(layout.backgroundFrame.height == WorkbenchControlMetrics.redesignCoverSummaryHeight)
}

@Test
func coverSummaryTextWidthTracksHalfTheContainerWithinItsBounds() {
    let minimum = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 896, height: 252)
    )
    let preferred = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 1_200, height: 252)
    )
    let maximum = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 1_500, height: 252)
    )

    #expect(minimum.contentFrame.width == 448)
    #expect(preferred.contentFrame.width == 600)
    #expect(maximum.contentFrame.width == 720)
    #expect(minimum.contentFrame.minX == 40)
    #expect(preferred.contentFrame.minX == 40)
    #expect(maximum.contentFrame.minX == 40)
}

@Test
func coverSummaryTextWidthReflowsContinuouslyWithTheContainer() {
    let narrower = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 1_000, height: 252)
    )
    let wider = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 1_100, height: 252)
    )

    #expect(narrower.contentFrame.width == 500)
    #expect(wider.contentFrame.width == 550)
    #expect(narrower.backgroundFrame.width == 1_000)
    #expect(wider.backgroundFrame.width == 1_100)
}

@Test
func coverSummaryTextWidthNeverExceedsItsInnerAvailableWidth() {
    let compactCardWidth = AppShellLayout.minimumWindowWidth
        - SchemaWorkbenchStyle.pageHorizontalPadding * 2
    let layout = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: compactCardWidth, height: 252)
    )

    #expect(compactCardWidth == 416)
    #expect(layout.contentFrame == CGRect(x: 40, y: 40, width: 336, height: 172))
    #expect(layout.contentFrame.maxX <= layout.backgroundFrame.maxX)
    #expect(layout.scrimEndLocation == 1)
}

@Test
func coverSummaryUsesTheAcceptedLeftToRightScrim() {
    let layout = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 1_260, height: 252)
    )

    #expect(layout.scrimEndLocation == 0.70)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimLeadingOpacity == 0.62)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimStrongOpacity == 0.54)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimMiddleOpacity == 0.34)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimTrailingOpacity == 0.12)
}

@Test
func coverSummaryScrimExtendsPastTextAtCompactWidth() {
    let layout = CoverSummaryCardLayout.resolve(
        containerSize: CGSize(width: 600, height: 252)
    )

    #expect(layout.scrimEndLocation == 528.0 / 600.0)
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
