import AppKit
import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

@Test
func subtitleFocusMetricsMatchDocumentedFixedGeometry() {
    #expect(PlaybackSubtitleFocusMetrics.cueSlotHeight == 104)
    #expect(PlaybackSubtitleFocusMetrics.cueGap == 32)
    #expect(PlaybackSubtitleFocusMetrics.cueSlotPitch == 136)
    #expect(PlaybackSubtitleFocusMetrics.contentMaxWidth == 960)
    #expect(PlaybackSubtitleFocusMetrics.contentInset == 32)
    #expect(PlaybackSubtitleFocusMetrics.cueFontSize == 40)
    #expect(PlaybackSubtitleFocusMetrics.cueLineHeight == 52)
    #expect(PlaybackSubtitleFocusMetrics.reelTransitionDuration == 0.22)
    #expect(PlaybackSubtitleFocusMetrics.reelHeight(cueCount: 10) == 1_328)
    #expect(PlaybackSubtitleFocusMetrics.reelHeight(cueCount: 0) == 0)
}

@Test
func subtitleFocusSelectedCueAlignsToCenterWhenBoundariesAllow() {
    let stageHeight: CGFloat = 720
    let viewportHeight = stageHeight - PlaybackSubtitleFocusMetrics.contentInset * 2
    let offset = PlaybackSubtitleFocusMetrics.loadedReelOffset(
        viewportHeight: viewportHeight,
        totalCount: 20,
        selectedOrdinal: 12,
        loadedStartOrdinal: 6
    )

    #expect(offset == -488)
    #expect(
        PlaybackSubtitleFocusMetrics.contentInset
            + offset
            + 6 * PlaybackSubtitleFocusMetrics.cueSlotPitch
            == stageHeight / 2
    )
}

@Test
func subtitleFocusReelOffsetClampsAtFirstAndLastCueBoundaries() {
    let stageHeight: CGFloat = 720
    let viewportHeight = stageHeight - PlaybackSubtitleFocusMetrics.contentInset * 2
    let firstOffset = PlaybackSubtitleFocusMetrics.loadedReelOffset(
        viewportHeight: viewportHeight,
        totalCount: 20,
        selectedOrdinal: 0,
        loadedStartOrdinal: 0
    )
    let lastOffset = PlaybackSubtitleFocusMetrics.loadedReelOffset(
        viewportHeight: viewportHeight,
        totalCount: 20,
        selectedOrdinal: 19,
        loadedStartOrdinal: 10
    )

    #expect(firstOffset == 0)
    #expect(PlaybackSubtitleFocusMetrics.contentInset + firstOffset == 32)
    #expect(lastOffset == -672)
    #expect(
        PlaybackSubtitleFocusMetrics.contentInset
            + lastOffset
            + 9 * PlaybackSubtitleFocusMetrics.cueSlotPitch
            + PlaybackSubtitleFocusMetrics.cueSlotHeight
            == stageHeight - PlaybackSubtitleFocusMetrics.contentInset
    )
}

@Test
func subtitleFocusTallViewportUsesCompleteDocumentBoundaryNotLoadedWindow() {
    let stageHeight: CGFloat = 1_342
    let viewportHeight = stageHeight - PlaybackSubtitleFocusMetrics.contentInset * 2
    let loadedOffset = PlaybackSubtitleFocusMetrics.loadedReelOffset(
        viewportHeight: viewportHeight,
        totalCount: 20,
        selectedOrdinal: 12,
        loadedStartOrdinal: 6
    )

    #expect(loadedOffset == -177)
    #expect(
        PlaybackSubtitleFocusMetrics.contentInset
            + loadedOffset
            + 6 * PlaybackSubtitleFocusMetrics.cueSlotPitch
            == stageHeight / 2
    )
}

@Test
func subtitleFocusShortReelKeepsSelectionNearestCenterWithinBoundaries() {
    let viewportHeight: CGFloat = 656
    #expect(PlaybackSubtitleFocusMetrics.loadedReelOffset(
        viewportHeight: viewportHeight,
        totalCount: 3,
        selectedOrdinal: 0,
        loadedStartOrdinal: 0
    ) == 280)
    #expect(PlaybackSubtitleFocusMetrics.loadedReelOffset(
        viewportHeight: viewportHeight,
        totalCount: 3,
        selectedOrdinal: 1,
        loadedStartOrdinal: 0
    ) == 192)
    #expect(PlaybackSubtitleFocusMetrics.loadedReelOffset(
        viewportHeight: viewportHeight,
        totalCount: 3,
        selectedOrdinal: 2,
        loadedStartOrdinal: 0
    ) == 56)
}

@MainActor
@Test
func subtitleFocusCueTextUsesFiftyTwoPointLinePitch() {
    _ = NSApplication.shared
    let oneLineHeight = subtitleFocusCueTextHeight(lineCount: 1)
    let twoLineHeight = subtitleFocusCueTextHeight(lineCount: 2)
    let threeLineHeight = subtitleFocusCueTextHeight(lineCount: 3)

    #expect(abs((twoLineHeight - oneLineHeight) - 52) < 0.75)
    #expect(abs((threeLineHeight - twoLineHeight) - 52) < 0.75)
    #expect(twoLineHeight <= PlaybackSubtitleFocusMetrics.cueSlotHeight)
    #expect(threeLineHeight > PlaybackSubtitleFocusMetrics.cueSlotHeight)
}

@MainActor
@Test
func subtitleFocusOverlayRendersCommittedSnapshotAtStageSize() throws {
    _ = NSApplication.shared
    let filledLine = String(repeating: "█", count: 80)
    let snapshot = SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: (6..<16).map { ordinal in
            SubtitleFocusCue(
                id: Int64(ordinal + 1),
                ordinal: ordinal,
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 900,
                lines: [filledLine, filledLine]
            )
        }
    )
    let renderer = ImageRenderer(
        content: PlaybackSubtitleFocusOverlay(snapshot: snapshot)
            .frame(width: 1_280, height: 720)
    )
    renderer.scale = 1

    let renderedImage = try #require(renderer.nsImage)
    #expect(renderedImage.size.width == 1_280)
    #expect(renderedImage.size.height == 720)

    let imageData = try #require(renderedImage.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: imageData))
    let edgeRows = [8, 16, 24, bitmap.pixelsHigh - 24, bitmap.pixelsHigh - 16, bitmap.pixelsHigh - 8]
    var maximumEdgeComponent: CGFloat = 0
    for y in edgeRows {
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            let pixelMaximum = max(
                color.redComponent,
                max(color.greenComponent, color.blueComponent)
            )
            maximumEdgeComponent = max(maximumEdgeComponent, pixelMaximum)
        }
    }
    #expect(maximumEdgeComponent < 0.3)
}

@MainActor
private func subtitleFocusCueTextHeight(lineCount: Int) -> CGFloat {
    let text = (0..<lineCount).map { "line \($0)" }.joined(separator: "\n")
    let hostingView = NSHostingView(
        rootView: PlaybackSubtitleFocusCueText(text: text, isSelected: true)
            .frame(width: 900, alignment: .topLeading)
    )
    hostingView.layoutSubtreeIfNeeded()
    return hostingView.fittingSize.height
}
