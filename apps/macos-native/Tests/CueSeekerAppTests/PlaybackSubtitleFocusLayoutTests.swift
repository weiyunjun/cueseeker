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
func subtitleFocusVirtualReelUsesViewportPaddingForDocumentHeight() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 20,
        focusAnchorY: 328
    )

    #expect(layout.documentSize == CGSize(width: 1_280, height: 3_240))
    #expect(layout.maximumContentOffsetY == 2_584)
    #expect(layout.contentWidth == 960)
}

@Test
func subtitleFocusVirtualReelAlignsFirstAndLastCueToOneAnchor() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 20,
        focusAnchorY: 328
    )

    let firstScreenY = layout.rowRect(for: 0).minY
        - layout.contentOffsetY(for: 0)
    let lastScreenY = layout.rowRect(for: 19).minY
        - layout.contentOffsetY(for: 19)

    #expect(firstScreenY == 328)
    #expect(lastScreenY == 328)
}

@Test
func subtitleFocusVirtualReelVisibleRangeIsIndependentOfTotalCount() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 50_000,
        focusAnchorY: 328
    )
    let targetOffset = layout.contentOffsetY(for: 25_000)
    let visibleRange = layout.visibleOrdinalRange(
        in: CGRect(
            x: 0,
            y: targetOffset,
            width: 1_280,
            height: 656
        )
    )

    #expect(visibleRange.contains(25_000))
    #expect(visibleRange.count <= 15)
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

@Test
func subtitleFocusAnchorRemainsFixedDuringBoundaryNavigation() {
    let stageHeight: CGFloat = 720
    let firstAnchor = PlaybackSubtitleFocusMetrics.initialFocusAnchorY(
        stageHeight: stageHeight,
        totalCount: 20,
        selectedOrdinal: 0
    )
    let firstOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: firstAnchor,
        selectedOrdinal: 0,
        loadedStartOrdinal: 0
    )
    let secondOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: firstAnchor,
        selectedOrdinal: 1,
        loadedStartOrdinal: 0
    )

    #expect(firstAnchor == PlaybackSubtitleFocusMetrics.contentInset)
    #expect(firstOffset == 0)
    #expect(secondOffset - firstOffset == -PlaybackSubtitleFocusMetrics.cueSlotPitch)
    #expect(
        PlaybackSubtitleFocusMetrics.contentInset
            + secondOffset
            + PlaybackSubtitleFocusMetrics.cueSlotPitch
            == firstAnchor
    )

    let lastAnchor = PlaybackSubtitleFocusMetrics.initialFocusAnchorY(
        stageHeight: stageHeight,
        totalCount: 20,
        selectedOrdinal: 19
    )
    let lastOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: lastAnchor,
        selectedOrdinal: 19,
        loadedStartOrdinal: 10
    )
    let previousOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: lastAnchor,
        selectedOrdinal: 18,
        loadedStartOrdinal: 10
    )

    #expect(lastAnchor == 584)
    #expect(previousOffset - lastOffset == PlaybackSubtitleFocusMetrics.cueSlotPitch)
    #expect(
        PlaybackSubtitleFocusMetrics.contentInset
            + previousOffset
            + 8 * PlaybackSubtitleFocusMetrics.cueSlotPitch
            == lastAnchor
    )
}

@Test
func subtitleFocusPointerSelectionMovesAnchorWithoutMovingReel() {
    let originalAnchor = PlaybackSubtitleFocusMetrics.initialFocusAnchorY(
        stageHeight: 720,
        totalCount: 20,
        selectedOrdinal: 12
    )
    let originalOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: originalAnchor,
        selectedOrdinal: 12,
        loadedStartOrdinal: 6
    )
    let clickedOrdinal = 11
    let clickedAnchor = PlaybackSubtitleFocusMetrics.contentInset
        + originalOffset
        + CGFloat(clickedOrdinal - 6) * PlaybackSubtitleFocusMetrics.cueSlotPitch
    let clickedOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: clickedAnchor,
        selectedOrdinal: clickedOrdinal,
        loadedStartOrdinal: 6
    )

    #expect(originalAnchor == 360)
    #expect(clickedAnchor == 224)
    #expect(clickedOffset == originalOffset)
}

@Test
func subtitleFocusCacheWindowChangesPreserveCueScreenPosition() {
    let anchor: CGFloat = 360
    let oldOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: anchor,
        selectedOrdinal: 12,
        loadedStartOrdinal: 6
    )
    let newOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: anchor,
        selectedOrdinal: 12,
        loadedStartOrdinal: 2
    )
    let oldSelectedY = PlaybackSubtitleFocusMetrics.contentInset
        + oldOffset
        + CGFloat(12 - 6) * PlaybackSubtitleFocusMetrics.cueSlotPitch
    let newSelectedY = PlaybackSubtitleFocusMetrics.contentInset
        + newOffset
        + CGFloat(12 - 2) * PlaybackSubtitleFocusMetrics.cueSlotPitch

    #expect(oldSelectedY == anchor)
    #expect(newSelectedY == anchor)
}

@Test
func subtitleFocusWheelAccumulatorKeepsContinuousReelPosition() {
    var selectedOrdinal = 12
    var accumulator = PlaybackSubtitleFocusWheelAccumulator()
    let canMove: (SubtitleFocusNavigationDirection) -> Bool = { direction in
        direction == .backward ? selectedOrdinal > 0 : selectedOrdinal < 19
    }
    let move: (SubtitleFocusNavigationDirection) -> Bool = { direction in
        selectedOrdinal += direction == .backward ? -1 : 1
        return true
    }

    accumulator.apply(
        deltaY: 60,
        canMoveSelection: canMove,
        moveSelection: move
    )
    #expect(selectedOrdinal == 12)
    #expect(accumulator.translation == 60)

    accumulator.apply(
        deltaY: 76,
        canMoveSelection: canMove,
        moveSelection: move
    )
    #expect(selectedOrdinal == 11)
    #expect(accumulator.translation == 0)

    accumulator.apply(
        deltaY: -300,
        canMoveSelection: canMove,
        moveSelection: move
    )
    #expect(selectedOrdinal == 13)
    #expect(accumulator.translation == -28)
}

@Test
func subtitleFocusWheelAccumulatorSettlesNearestCueAndClampsBoundary() {
    var selectedOrdinal = 12
    var accumulator = PlaybackSubtitleFocusWheelAccumulator()
    let canMove: (SubtitleFocusNavigationDirection) -> Bool = { direction in
        direction == .backward ? selectedOrdinal > 0 : selectedOrdinal < 19
    }
    let move: (SubtitleFocusNavigationDirection) -> Bool = { direction in
        selectedOrdinal += direction == .backward ? -1 : 1
        return true
    }

    accumulator.apply(
        deltaY: -100,
        canMoveSelection: canMove,
        moveSelection: move
    )
    accumulator.prepareToSettle(
        canMoveSelection: canMove,
        moveSelection: move
    )
    #expect(selectedOrdinal == 13)
    #expect(accumulator.translation == 36)
    accumulator.finishSettling()
    #expect(accumulator.translation == 0)

    selectedOrdinal = 0
    accumulator.apply(
        deltaY: 30,
        canMoveSelection: canMove,
        moveSelection: move
    )
    #expect(selectedOrdinal == 0)
    #expect(accumulator.translation == 0)
}

@Test
func subtitleFocusWheelTieUsesNetTranslationDirection() {
    var selectedOrdinal = 12
    var accumulator = PlaybackSubtitleFocusWheelAccumulator()
    let canMove: (SubtitleFocusNavigationDirection) -> Bool = { _ in true }
    let move: (SubtitleFocusNavigationDirection) -> Bool = { direction in
        selectedOrdinal += direction == .backward ? -1 : 1
        return true
    }

    accumulator.apply(
        deltaY: 100,
        canMoveSelection: canMove,
        moveSelection: move
    )
    accumulator.apply(
        deltaY: -32,
        canMoveSelection: canMove,
        moveSelection: move
    )
    #expect(accumulator.translation == 68)

    accumulator.prepareToSettle(
        canMoveSelection: canMove,
        moveSelection: move
    )
    #expect(selectedOrdinal == 11)
    #expect(accumulator.translation == -68)
    accumulator.finishSettling()
    #expect(accumulator.translation == 0)
}

@Test
func subtitleFocusCueHitShapeContainsOnlyVisibleTextFragments() {
    let shape = PlaybackSubtitleFocusCueHitShape(
        text: "first\nsecond\nthird"
    )
    let path = shape.path(in: CGRect(
        x: 0,
        y: 0,
        width: 400,
        height: PlaybackSubtitleFocusMetrics.cueSlotHeight
    ))

    #expect(path.contains(CGPoint(x: 20, y: 20)))
    #expect(path.contains(CGPoint(x: 20, y: 70)))
    #expect(!path.contains(CGPoint(x: 390, y: 20)))
    #expect(path.boundingRect.maxY < PlaybackSubtitleFocusMetrics.cueSlotHeight)
}

@Test
func subtitleFocusAnimatedPointerAnchorUsesPresentationOffset() {
    let presentation = PlaybackSubtitleFocusReelPresentation()
    let effect = PlaybackSubtitleFocusReelOffsetEffect(
        offset: -420,
        presentation: presentation
    )
    _ = effect.effectValue(size: CGSize(width: 960, height: 1_328))
    let currentOffset = presentation.offset ?? 0
    let clickedOrdinal = 11
    let clickedAnchor = PlaybackSubtitleFocusMetrics.contentInset
        + currentOffset
        + CGFloat(clickedOrdinal - 6) * PlaybackSubtitleFocusMetrics.cueSlotPitch
    let selectedOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
        focusAnchorY: clickedAnchor,
        selectedOrdinal: clickedOrdinal,
        loadedStartOrdinal: 6
    )

    #expect(currentOffset == -420)
    #expect(selectedOffset == currentOffset)
}

@Test
func subtitleFocusScrollSequenceLatchesInsideGestureThroughMomentum() {
    var sequence = PlaybackSubtitleFocusScrollSequence()
    let began = sequence.consume(focusScrollSample(
        deltaY: -10,
        phase: .began,
        isInside: true
    ))
    let changedOutside = sequence.consume(focusScrollSample(
        deltaY: -20,
        phase: .changed,
        isInside: false
    ))
    let ended = sequence.consume(focusScrollSample(
        deltaY: 0,
        phase: .ended,
        isInside: false
    ))
    let momentumBegan = sequence.consume(focusScrollSample(
        deltaY: -8,
        momentumPhase: .began,
        isInside: false
    ))
    let momentumEnded = sequence.consume(focusScrollSample(
        deltaY: 0,
        momentumPhase: .ended,
        isInside: false
    ))

    #expect(began.shouldConsume)
    #expect(began.deltaY == -10)
    #expect(changedOutside.shouldConsume)
    #expect(ended.settleDirective == .debounce)
    #expect(momentumBegan.settleDirective == .cancel)
    #expect(momentumEnded.settleDirective == .immediate)
}

@Test
func subtitleFocusScrollSequencePassesOutsideStartAndScalesLegacyWheel() {
    var sequence = PlaybackSubtitleFocusScrollSequence()
    let outside = sequence.consume(focusScrollSample(
        deltaY: -1,
        phase: .began,
        isInside: false
    ))
    let legacy = sequence.consume(focusScrollSample(
        deltaY: 1,
        isPrecise: false,
        isInside: true
    ))

    #expect(!outside.shouldConsume)
    #expect(legacy.shouldConsume)
    #expect(legacy.deltaY == PlaybackSubtitleFocusMetrics.cueSlotPitch)
    #expect(legacy.settleDirective == .debounce)
}

@Test
func subtitleFocusScrollSequenceRequiresNewGestureAfterMenuSuppression() {
    var sequence = PlaybackSubtitleFocusScrollSequence()
    _ = sequence.consume(focusScrollSample(
        deltaY: -10,
        phase: .began,
        isInside: true
    ))
    sequence.reset(requiresNewGesture: true)

    let staleChanged = sequence.consume(focusScrollSample(
        deltaY: -30,
        phase: .changed,
        isInside: true
    ))
    let staleMomentum = sequence.consume(focusScrollSample(
        deltaY: -20,
        momentumPhase: .began,
        isInside: true
    ))
    let newBegan = sequence.consume(focusScrollSample(
        deltaY: -12,
        phase: .began,
        isInside: true
    ))

    #expect(staleChanged == .consumedNoop)
    #expect(staleMomentum == .consumedNoop)
    #expect(newBegan.shouldConsume)
    #expect(newBegan.deltaY == -12)
}

@Test
func subtitleFocusMomentumEndAppliesFinalDeltaBeforeSettling() {
    var sequence = PlaybackSubtitleFocusScrollSequence()
    _ = sequence.consume(focusScrollSample(
        deltaY: -40,
        phase: .began,
        isInside: true
    ))
    let finalOutput = sequence.consume(focusScrollSample(
        deltaY: -30,
        momentumPhase: .ended,
        isInside: false
    ))
    var selectedOrdinal = 12
    var accumulator = PlaybackSubtitleFocusWheelAccumulator()
    let canMove: (SubtitleFocusNavigationDirection) -> Bool = { _ in true }
    let move: (SubtitleFocusNavigationDirection) -> Bool = { direction in
        selectedOrdinal += direction == .backward ? -1 : 1
        return true
    }

    accumulator.apply(
        deltaY: -40,
        canMoveSelection: canMove,
        moveSelection: move
    )
    accumulator.apply(
        deltaY: finalOutput.deltaY,
        canMoveSelection: canMove,
        moveSelection: move
    )
    accumulator.prepareToSettle(
        canMoveSelection: canMove,
        moveSelection: move
    )
    accumulator.finishSettling()

    #expect(finalOutput.settleDirective == .immediate)
    #expect(selectedOrdinal == 13)
    #expect(accumulator.translation == 0)
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

private func focusScrollSample(
    deltaY: CGFloat,
    isPrecise: Bool = true,
    phase: PlaybackSubtitleFocusScrollSample.Phase = .none,
    momentumPhase: PlaybackSubtitleFocusScrollSample.Phase = .none,
    isInside: Bool
) -> PlaybackSubtitleFocusScrollSample {
    PlaybackSubtitleFocusScrollSample(
        deltaY: deltaY,
        isPrecise: isPrecise,
        phase: phase,
        momentumPhase: momentumPhase,
        isInside: isInside
    )
}
