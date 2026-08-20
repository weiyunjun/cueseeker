import CoreGraphics
import Testing
@testable import CueSeekerApp

/// Narrowest Cover Summary the Workbench can present: the page content minimum
/// width less the page's own leading padding and trailing Scrollbar channel.
private let coverSummaryMinimumCardWidth =
    AppShellLayout.pageContentMinimumWidth
        - WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
        - WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding

@Test
func coverSummaryUsesSharedPlaybackActionTitles() {
    #expect(CoverSummaryActionKind.play.title == "Play")
    #expect(CoverSummaryActionKind.resume.title == "Resume")
}

@Test
func coverSummarySwitchesFormsAtItsDerivedWidth() {
    #expect(
        WorkbenchControlMetrics.redesignCoverSummarySplitMinimumWidth
            == WorkbenchControlMetrics.redesignCoverSummarySplitCoverWidth
                + WorkbenchControlMetrics.redesignCoverSummarySplitGap
                + WorkbenchControlMetrics.redesignCoverSummarySplitContentMinWidth
    )
    #expect(WorkbenchControlMetrics.redesignCoverSummarySplitMinimumWidth == 664)

    #expect(CoverSummaryCardLayout.resolve(containerWidth: 664).form == .split)
    #expect(CoverSummaryCardLayout.resolve(containerWidth: 663).form == .backdrop)
}

@Test
func coverSummarySplitFormLocksTheCoverAndLetsContentFillTheRest() {
    let atThreshold = CoverSummaryCardLayout.resolve(containerWidth: 664)
    let wide = CoverSummaryCardLayout.resolve(containerWidth: 1_400)

    #expect(atThreshold.coverFrame == CGRect(x: 0, y: 0, width: 320, height: 180))
    #expect(wide.coverFrame == atThreshold.coverFrame)
    #expect(atThreshold.cardHeight == 180)
    #expect(wide.cardHeight == 180)

    // Content starts past the cover and its gap, then takes every remaining
    // point: the split form is never capped.
    #expect(atThreshold.contentFrame.minX == 344)
    #expect(atThreshold.contentFrame.width == 320)
    #expect(wide.contentFrame.minX == 344)
    #expect(wide.contentFrame.width == 1_056)
    #expect(atThreshold.contentFrame.height == 180)
}

@Test
func coverSummaryBackdropFormKeepsAFixedHeightAtEveryWidth() {
    let narrowest = CoverSummaryCardLayout.resolve(
        containerWidth: coverSummaryMinimumCardWidth
    )
    let belowThreshold = CoverSummaryCardLayout.resolve(containerWidth: 663)

    #expect(coverSummaryMinimumCardWidth == 400)
    #expect(narrowest.form == .backdrop)
    #expect(narrowest.cardHeight == 225)
    #expect(belowThreshold.form == .backdrop)
    #expect(belowThreshold.cardHeight == 225)
    #expect(narrowest.coverFrame == CGRect(x: 0, y: 0, width: 400, height: 225))
    #expect(belowThreshold.coverFrame == CGRect(x: 0, y: 0, width: 663, height: 225))

    // At the narrowest card the fixed height is exactly the cover's own 16:9
    // height, so nothing is cropped there and wider cards crop from the centre.
    #expect(
        abs(
            WorkbenchControlMetrics.redesignCoverSummaryBackdropHeight
                - coverSummaryMinimumCardWidth
                    / WorkbenchControlMetrics.redesignLibraryCoverAspectRatio
        ) < 0.001
    )
}

@Test
func coverSummaryKeepsTheContentColumnHeightAcrossAFormChange() {
    let split = CoverSummaryCardLayout.resolve(containerWidth: 664)
    let backdrop = CoverSummaryCardLayout.resolve(containerWidth: 663)

    #expect(split.contentFrame.height == backdrop.contentFrame.height)
    #expect(split.contentFrame.height == 180)

    // The backdrop block padding is what makes the two heights match.
    #expect(backdrop.contentFrame.minY == 35)
    #expect(
        backdrop.cardHeight - backdrop.contentFrame.maxY == 10
    )
    #expect(
        WorkbenchControlMetrics.redesignCoverSummaryBackdropTopPadding
            + WorkbenchControlMetrics.redesignCoverSummarySplitCoverHeight
            + WorkbenchControlMetrics.redesignCoverSummaryBackdropBottomPadding
            == WorkbenchControlMetrics.redesignCoverSummaryBackdropHeight
    )
}

@Test
func coverSummaryHeightFunctionMatchesTheResolvedLayout() {
    let widths: [CGFloat] = [coverSummaryMinimumCardWidth, 500, 663, 664, 1_064, 1_400]
    for width in widths {
        #expect(
            CoverSummaryCardLayout.height(forCardWidth: width)
                == CoverSummaryCardLayout.resolve(containerWidth: width).cardHeight
        )
    }
}

@Test
func coverSummaryBackdropTextWidthStaysWithinItsInnerAvailableWidth() {
    let layout = CoverSummaryCardLayout.resolve(
        containerWidth: coverSummaryMinimumCardWidth
    )

    #expect(layout.contentFrame.minX == 40)
    #expect(layout.contentFrame.maxX <= layout.coverFrame.maxX)
    #expect(layout.contentFrame.maxY <= layout.coverFrame.maxY)
    #expect(layout.scrimEndLocation == 1)
}

@Test
func coverSummaryBackdropKeepsTheAcceptedLeftToRightScrim() {
    let layout = CoverSummaryCardLayout.resolve(containerWidth: 600)

    #expect(layout.form == .backdrop)
    // The scrim end follows the protected content edge past its default stop.
    #expect(layout.scrimEndLocation == 528.0 / 600.0)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimLeadingOpacity == 0.62)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimStrongOpacity == 0.54)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimMiddleOpacity == 0.34)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimTrailingOpacity == 0.12)
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
