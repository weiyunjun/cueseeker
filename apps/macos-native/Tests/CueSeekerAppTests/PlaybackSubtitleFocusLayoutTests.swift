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
    #expect(
        PlaybackSubtitleFocusMetrics.resolvedReelTransitionDuration(
            reducesMotion: false
        ) == 0.22
    )
    #expect(
        PlaybackSubtitleFocusMetrics.resolvedReelTransitionDuration(
            reducesMotion: true
        ) == 0
    )
}

@MainActor
@Test
func subtitleFocusNativeTextLayoutUsesFixedPitchAndTwoLineClip() throws {
    _ = NSApplication.shared
    let layout = PlaybackSubtitleFocusNativeTextLayout()
    let bounds = CGRect(
        x: 0,
        y: 0,
        width: 400,
        height: PlaybackSubtitleFocusMetrics.cueSlotHeight
    )
    let visibleLineRects = layout.visibleLineRects(
        text: "first\nsecond\nthird",
        in: bounds
    )

    #expect(visibleLineRects.count == 2)
    let first = try #require(visibleLineRects.first)
    let second = try #require(visibleLineRects.last)
    #expect(abs((second.minY - first.minY) - 52) < 0.75)
    #expect(visibleLineRects.allSatisfy { bounds.contains($0) })
    #expect(visibleLineRects.allSatisfy { $0.maxX < bounds.maxX })
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
func subtitleFocusVirtualReelPreservesPartiallyVisibleNegativeAnchor() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 20,
        focusAnchorY: -24
    )

    #expect(layout.focusAnchorY == -24)
    #expect(
        layout.rowRect(for: 8).minY - layout.contentOffsetY(for: 8)
            == -24
    )
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
func subtitleFocusNativeScrollbarUsesContinuousClipOffsetMapping() throws {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 50_000,
        focusAnchorY: 328
    )
    let metrics = PlaybackSubtitleFocusNativeScrollbarMetrics(
        layout: layout,
        contentOffsetY: layout.contentOffsetY(for: 25_000)
    )
    let vertical = try #require(metrics.presentation.vertical)

    #expect(
        abs(vertical.positionFraction - CGFloat(25_000) / 49_999)
            < 0.000_001
    )
    #expect(
        abs(
            metrics.contentOffsetY(for: 0.75)
                / layout.maximumContentOffsetY - 0.75
        ) < 0.000_001
    )
    #expect(
        vertical.visibleFraction
            == layout.viewportSize.height / layout.documentSize.height
    )
}

@MainActor
@Test
func subtitleFocusNativeScrollbarPublishesOnlyOneMouseUpCommit() async {
    _ = NSApplication.shared
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    var committedOrdinals: [Int] = []
    var dragStates: [Bool] = []
    view.onCommitNativeReelSelection = { ordinal in
        committedOrdinals.append(ordinal)
        return true
    }
    view.allowsNativeScrollbarInput = { true }
    view.onScrollbarDraggingChanged = { dragStates.append($0) }
    view.update(
        cues: focusLayoutCues(0..<200),
        totalCount: 200,
        selectedOrdinal: 12,
        focusAnchorY: 328,
        presentationTranslation: 0,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .began,
        positionFraction: CGFloat(12) / 199
    ))
    for step in 1...1_000 {
        view.handleScrollbarDrag(TableScrollbarDragEvent(
            axis: .vertical,
            phase: .changed,
            positionFraction: 0.75 * CGFloat(step) / 1_000
        ))
    }

    #expect(committedOrdinals.isEmpty)
    #expect(
        abs(
            view.scrollbarPresentationForTesting.vertical!.positionFraction
                - 0.75
        ) < 0.000_001
    )

    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.75
    ))
    view.handleScrollbarDraggingChanged(false)
    await Task.yield()
    await Task.yield()

    #expect(committedOrdinals == [149])
    #expect(dragStates == [true, false])
    #expect(view.contentOffsetYForTesting == CGFloat(149) * 136)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusNativeScrollbarEnablesOnlyAfterCompleteBatch() {
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    view.update(
        cues: focusLayoutCues(6..<16),
        totalCount: 20,
        selectedOrdinal: 12,
        focusAnchorY: 328,
        presentationTranslation: 0,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    #expect(view.scrollbarPresentationForTesting.vertical != nil)
    #expect(!view.acceptsScrollbarInteractionForTesting)
    let offsetBeforeFullBatch = view.contentOffsetYForTesting

    view.update(
        cues: focusLayoutCues(0..<20),
        totalCount: 20,
        selectedOrdinal: 12,
        focusAnchorY: 328,
        presentationTranslation: 0,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )

    #expect(view.acceptsScrollbarInteractionForTesting)
    #expect(view.contentOffsetYForTesting == offsetBeforeFullBatch)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusPendingKeyboardUpdateCancelsStaleNativeScrollbarDrag() async {
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var nativeCommits: [Int] = []
    var keyboardCommits: [Int] = []
    var dragStates: [Bool] = []
    view.onCommitNativeReelSelection = { ordinal in
        nativeCommits.append(ordinal)
        return true
    }
    view.onCommitKeyboardNavigation = { request in
        keyboardCommits.append(request.targetOrdinal)
        return true
    }
    view.onScrollbarDraggingChanged = { dragStates.append($0) }
    view.update(
        cues: focusLayoutCues(0..<200),
        totalCount: 200,
        selectedOrdinal: 12,
        focusAnchorY: 328,
        presentationTranslation: 0,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .changed,
        positionFraction: 0.75
    ))

    let request = PlaybackSubtitleFocusKeyboardNavigationRequest(
        sequence: 1,
        direction: .forward,
        targetOrdinal: 13
    )
    view.update(
        cues: focusLayoutCues(0..<200),
        totalCount: 200,
        selectedOrdinal: 12,
        focusAnchorY: 328,
        presentationTranslation: 0,
        keyboardNavigationRequest: request,
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: true
    )
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.9
    ))
    await Task.yield()
    await Task.yield()

    #expect(nativeCommits.isEmpty)
    #expect(keyboardCommits == [13])
    #expect(dragStates == [true, false])
    #expect(view.contentOffsetYForTesting == CGFloat(13) * 136)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusResizeCancelsNativeScrollbarDragWithoutCommit() {
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var nativeCommits: [Int] = []
    var dragStates: [Bool] = []
    view.onCommitNativeReelSelection = { ordinal in
        nativeCommits.append(ordinal)
        return true
    }
    view.onScrollbarDraggingChanged = { dragStates.append($0) }
    view.update(
        cues: focusLayoutCues(0..<200),
        totalCount: 200,
        selectedOrdinal: 12,
        focusAnchorY: 328,
        presentationTranslation: 0,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .changed,
        positionFraction: 0.75
    ))

    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 720)
    view.layoutSubtreeIfNeeded()
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.9
    ))

    #expect(nativeCommits.isEmpty)
    #expect(dragStates == [true, false])
    #expect(view.contentOffsetYForTesting == CGFloat(12) * 136)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusKeyboardAnimatorUsesDocumentedEaseOutCurve() {
    let samples = stride(from: CGFloat(0), through: 1, by: 0.1).map {
        PlaybackSubtitleFocusKeyboardOffsetAnimator.easedProgress($0)
    }

    #expect(samples.first == 0)
    #expect(samples.last == 1)
    #expect(samples == samples.sorted())
    #expect(PlaybackSubtitleFocusKeyboardOffsetAnimator.easedProgress(0.5) > 0.8)
}

@Test
func subtitleFocusNativeDiscreteWheelAlwaysMovesAtLeastOneCue() {
    var state = PlaybackSubtitleFocusNativeWheelState()

    let tinyBackward = state.consume(
        focusScrollSample(deltaY: 0.1, isPrecise: false, isInside: true),
        isEnabled: true
    )
    let tinyForward = state.consume(
        focusScrollSample(deltaY: -0.1, isPrecise: false, isInside: true),
        isEnabled: true
    )
    let accelerated = state.consume(
        focusScrollSample(deltaY: -3, isPrecise: false, isInside: true),
        isEnabled: true
    )

    #expect(tinyBackward.mode == .discrete(direction: .backward, stepCount: 1))
    #expect(tinyForward.mode == .discrete(direction: .forward, stepCount: 1))
    #expect(accelerated.mode == .discrete(direction: .forward, stepCount: 3))
}

@Test
func subtitleFocusNativePreciseWheelOwnsGestureThroughMomentum() {
    var state = PlaybackSubtitleFocusNativeWheelState()
    let began = state.consume(
        focusScrollSample(deltaY: -12, phase: .began, isInside: true),
        isEnabled: true
    )
    let ended = state.consume(
        focusScrollSample(deltaY: -4, phase: .ended, isInside: false),
        isEnabled: true
    )
    let momentumBegan = state.consume(
        focusScrollSample(
            deltaY: -3,
            momentumPhase: .began,
            isInside: false
        ),
        isEnabled: true
    )
    let momentumEnded = state.consume(
        focusScrollSample(
            deltaY: -2,
            momentumPhase: .ended,
            isInside: false
        ),
        isEnabled: true
    )

    #expect(began.mode == .precise(deltaY: -12, beginsGesture: true))
    #expect(began.settleDirective == .cancel)
    #expect(ended.shouldConsume)
    #expect(ended.settleDirective == .debounce)
    #expect(momentumBegan.shouldConsume)
    #expect(momentumBegan.settleDirective == .cancel)
    #expect(momentumEnded.mode == .precise(deltaY: -2, beginsGesture: false))
    #expect(momentumEnded.settleDirective == .immediate)
}

@Test
func subtitleFocusNativePreciseWheelDoesNotSettleWhileGestureIsActive() {
    var state = PlaybackSubtitleFocusNativeWheelState()
    let began = state.consume(
        focusScrollSample(deltaY: -12, phase: .began, isInside: true),
        isEnabled: true
    )
    let changed = state.consume(
        focusScrollSample(deltaY: -4, phase: .changed, isInside: true),
        isEnabled: true
    )
    let ended = state.consume(
        focusScrollSample(deltaY: 0, phase: .ended, isInside: true),
        isEnabled: true
    )

    #expect(began.settleDirective == .cancel)
    #expect(changed.settleDirective == .cancel)
    #expect(ended.settleDirective == .debounce)
}

@Test
func subtitleFocusNativePreciseWheelPrioritizesCombinedMomentumBegin() {
    var state = PlaybackSubtitleFocusNativeWheelState()
    _ = state.consume(
        focusScrollSample(deltaY: -12, phase: .began, isInside: true),
        isEnabled: true
    )

    let combined = state.consume(
        focusScrollSample(
            deltaY: -3,
            phase: .ended,
            momentumPhase: .began,
            isInside: false
        ),
        isEnabled: true
    )

    #expect(combined.mode == .precise(deltaY: -3, beginsGesture: false))
    #expect(combined.settleDirective == .cancel)
}

@Test
func subtitleFocusNativePreciseWheelSettlesSubPitchGestureByNetDirection() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 20,
        focusAnchorY: 328
    )
    let startOffset = layout.contentOffsetY(for: 12)

    let forward = PlaybackSubtitleFocusPreciseWheelSettlement.targetOrdinal(
        layout: layout,
        currentOffsetY: startOffset + 1,
        startOrdinal: 12,
        netDeltaY: -1,
        availableRange: 0..<20
    )
    let backward = PlaybackSubtitleFocusPreciseWheelSettlement.targetOrdinal(
        layout: layout,
        currentOffsetY: startOffset - 1,
        startOrdinal: 12,
        netDeltaY: 1,
        availableRange: 0..<20
    )
    let firstBoundary = PlaybackSubtitleFocusPreciseWheelSettlement.targetOrdinal(
        layout: layout,
        currentOffsetY: 0,
        startOrdinal: 0,
        netDeltaY: 1,
        availableRange: 0..<20
    )

    #expect(forward == 13)
    #expect(backward == 11)
    #expect(firstBoundary == 0)
}

@Test
func subtitleFocusNativePreciseWheelUsesOnlyAppliedDeltaAtBoundary() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 20,
        focusAnchorY: 328
    )
    var netDeltaY: CGFloat = 0
    netDeltaY = PlaybackSubtitleFocusPreciseWheelSettlement
        .accumulatingAppliedDeltaY(netDeltaY, from: 0, to: 0)
    netDeltaY = PlaybackSubtitleFocusPreciseWheelSettlement
        .accumulatingAppliedDeltaY(netDeltaY, from: 0, to: 10)

    let target = PlaybackSubtitleFocusPreciseWheelSettlement.targetOrdinal(
        layout: layout,
        currentOffsetY: 10,
        startOrdinal: 0,
        netDeltaY: netDeltaY,
        availableRange: 0..<20
    )

    #expect(netDeltaY == -10)
    #expect(target == 1)
}

@Test
func subtitleFocusNativePreciseWheelStaysInsideInitialLoadedWindow() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 50_000,
        focusAnchorY: 328
    )
    let availableRange = 6..<16

    let beforeWindow = PlaybackSubtitleFocusPreciseWheelSettlement
        .boundedContentOffsetY(
            layout: layout,
            requestedOffsetY: -10_000,
            availableRange: availableRange
        )
    let afterWindow = PlaybackSubtitleFocusPreciseWheelSettlement
        .boundedContentOffsetY(
            layout: layout,
            requestedOffsetY: layout.maximumContentOffsetY,
            availableRange: availableRange
        )

    #expect(beforeWindow == layout.contentOffsetY(for: 6))
    #expect(afterWindow == layout.contentOffsetY(for: 15))
}

@Test
func subtitleFocusNativeWheelRequiresFreshGestureAfterSuppression() {
    var state = PlaybackSubtitleFocusNativeWheelState()
    _ = state.consume(
        focusScrollSample(deltaY: -10, phase: .began, isInside: true),
        isEnabled: true
    )
    _ = state.consume(
        focusScrollSample(deltaY: -5, phase: .changed, isInside: true),
        isEnabled: false
    )
    let stale = state.consume(
        focusScrollSample(deltaY: -5, phase: .changed, isInside: true),
        isEnabled: true
    )
    let fresh = state.consume(
        focusScrollSample(deltaY: -5, phase: .began, isInside: true),
        isEnabled: true
    )

    #expect(stale == .consumedNoop)
    #expect(fresh.mode == .precise(deltaY: -5, beginsGesture: true))
}

@MainActor
@Test
func subtitleFocusOverlayRendersCommittedSnapshotAtStageSize() throws {
    _ = NSApplication.shared
    let filledLine = String(repeating: "█", count: 80)
    let content = [filledLine, filledLine].joined(separator: "\n")
    let cues: [SubtitleFocusCue] = (6..<16).map { ordinal in
        focusLayoutCue(ordinal: ordinal, content: content)
    }
    let snapshot = SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: cues
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

private func focusLayoutCues(_ range: Range<Int>) -> [SubtitleFocusCue] {
    range.map { ordinal in
        focusLayoutCue(ordinal: ordinal, content: "cue \(ordinal)")
    }
}

private func focusLayoutCue(
    ordinal: Int,
    content: String
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: Int64(ordinal + 1),
        cueGroupID: Int64(ordinal + 1_001),
        ordinal: ordinal,
        eventIndex: ordinal,
        displayOrder: 0,
        startMilliseconds: ordinal * 1_000,
        endMilliseconds: ordinal * 1_000 + 900,
        content: content
    )
}
