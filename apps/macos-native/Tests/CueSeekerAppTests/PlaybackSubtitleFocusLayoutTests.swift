import AppKit
import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

@Test
func subtitleFocusMetricsMatchDocumentedDynamicGeometry() {
    #expect(PlaybackSubtitleFocusMetrics.cueVerticalPadding == 12)
    #expect(PlaybackSubtitleFocusMetrics.cueGap == 8)
    #expect(PlaybackSubtitleFocusMetrics.minimumNaturalCueHeight == 76)
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
func subtitleFocusTextMeasurementUsesEveryHardAndSoftVisualLine() {
    _ = NSApplication.shared
    let measurer = PlaybackSubtitleFocusCueTextMeasurer()

    for (text, expectedLines, expectedHeight) in [
        ("one", 1, CGFloat(76)),
        ("one\ntwo", 2, CGFloat(128)),
        ("one\ntwo\nthree", 3, CGFloat(180)),
        ("one\r\ntwo", 2, CGFloat(128)),
        ("one\n", 2, CGFloat(128)),
        ("one\n\nthree", 3, CGFloat(180)),
        ("", 1, CGFloat(76)),
    ] {
        let measurement = measurer.measurement(
            text: text,
            width: 2_000,
            viewportHeight: 1_000
        )
        #expect(measurement.visualLineCount == expectedLines)
        #expect(measurement.naturalHeight == expectedHeight)
        #expect(measurement.resolvedHeight == expectedHeight)
        #expect(!measurement.isOversized)
    }

    let wrapped = measurer.measurement(
        text: Array(repeating: "wrap", count: 40).joined(separator: " "),
        width: 120,
        viewportHeight: 10_000
    )
    #expect(wrapped.visualLineCount > 3)
    #expect(
        wrapped.naturalHeight
            == CGFloat(wrapped.visualLineCount) * 52 + 24
    )
}

@MainActor
@Test
func subtitleFocusNativeTextLayoutDrawsEveryFittingLineAtFixedLineHeight() throws {
    let layout = PlaybackSubtitleFocusNativeTextLayout()
    let cueRect = CGRect(x: 0, y: 0, width: 800, height: 180)
    let lineRects = layout.visibleLineRects(
        text: "first\nsecond\nthird",
        in: cueRect
    )

    #expect(lineRects.count == 3)
    let first = try #require(lineRects.first)
    let second = try #require(lineRects.dropFirst().first)
    let third = try #require(lineRects.last)
    #expect(first.minY >= 12)
    #expect(abs(second.minY - first.minY - 52) < 0.75)
    #expect(abs(third.minY - second.minY - 52) < 0.75)
    #expect(lineRects.allSatisfy { cueRect.contains($0) })

    #expect(
        layout.visibleLineRects(
            text: "first\r\nsecond",
            in: CGRect(x: 0, y: 0, width: 800, height: 128)
        ).count == 2
    )
    #expect(
        layout.visibleLineRects(
            text: "first\rsecond",
            in: CGRect(x: 0, y: 0, width: 800, height: 128)
        ).count == 2
    )
}

@MainActor
@Test
func subtitleFocusOversizedTextStartsAtHeadAndClipsTrailingLines() throws {
    let text = "first\nsecond\nthird"
    let cue = focusLayoutCue(ordinal: 0, content: text)
    let layout = PlaybackSubtitleFocusNativeTextLayout()
    let cueRect = CGRect(x: 0, y: 0, width: 800, height: 100)
    let visibleRects = layout.visibleLineRects(text: cue.text, in: cueRect)

    let first = try #require(visibleRects.first)
    #expect(first.minY >= 12)
    #expect(visibleRects.count < 3)
    #expect(visibleRects.allSatisfy { cueRect.contains($0) })
    #expect(cue.text == text)
}

@MainActor
@Test
func subtitleFocusMeasurementClampsOnlyResolvedHeight() {
    let measurer = PlaybackSubtitleFocusCueTextMeasurer()
    let measurement = measurer.measurement(
        text: "one\ntwo\nthree",
        width: 2_000,
        viewportHeight: 100
    )

    #expect(measurement.visualLineCount == 3)
    #expect(measurement.naturalHeight == 180)
    #expect(measurement.resolvedHeight == 100)
    #expect(measurement.isOversized)
}

@Test
func subtitleFocusVirtualGeometryUsesDocumentedPlacementDistances() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        fractionalOrdinal: 12
    )

    #expect(layout.focusAnchorY == 328)
    #expect(layout.contentWidth == 960)
    #expect(layout.acceptedTop(forResolvedHeight: 76) == 290)
    #expect(layout.acceptedTop(forResolvedHeight: 656) == 0)
    #expect(layout.adjacentCenterDistance(from: 76, to: 76) == 84)
    #expect(layout.adjacentCenterDistance(from: 76, to: 128) == 110)
    #expect(layout.adjacentCenterDistance(from: 128, to: 180) == 162)
}

@Test
func subtitleFocusVirtualGeometryInterpolatesFractionalOrdinals() {
    let layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: CGSize(width: 1_280, height: 656),
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        fractionalOrdinal: 12.5
    )

    let lowerTop = layout.lowerCueTop(
        lowerResolvedHeight: 76,
        upperResolvedHeight: 128
    )
    let upperTop = lowerTop + 76 + PlaybackSubtitleFocusMetrics.cueGap
    #expect(lowerTop == 235)
    #expect(upperTop == 319)
    #expect(layout.nearestOrdinal == 13)
}

@Test
func subtitleFocusScrollbarMapsOnlyFractionalCueOrdinal() throws {
    let metrics = PlaybackSubtitleFocusNativeScrollbarMetrics(
        totalCount: 50_000,
        fractionalOrdinal: 24_999.5,
        visibleCueCapacity: 7
    )
    let vertical = try #require(metrics.presentation.vertical)

    #expect(abs(vertical.positionFraction - 0.5) < 0.000_001)
    #expect(abs(vertical.visibleFraction - CGFloat(7) / 50_000) < 0.000_001)
    #expect(metrics.fractionalOrdinal(for: 0.75) == 37_499.25)

    let thumb = try #require(
        TableScrollbarGeometry(presentation: metrics.presentation).thumbRect(
            for: .vertical,
            in: CGRect(x: 0, y: 0, width: 1_280, height: 656)
        )
    )
    #expect(thumb.height >= 24)
}

@MainActor
@Test
func subtitleFocusReelScrollbarUsesInheritedCursor() {
    _ = NSApplication.shared
    let view = PlaybackSubtitleFocusReelContainerView()

    #expect(view.scrollbarCursorPolicyForTesting == .inherited)

    view.invalidate()
}

@MainActor
@Test
func subtitleFocusReelCentersFitCueAndPinsOversizedCueToTop() throws {
    _ = NSApplication.shared
    let fitView = PlaybackSubtitleFocusReelContainerView()
    fitView.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    fitView.update(
        cues: focusLayoutCues(0..<20),
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    fitView.layoutSubtreeIfNeeded()
    let fit = try #require(
        fitView.placementsForTesting.first { $0.ordinal == 12 }
    )
    #expect(fit.measurement.resolvedHeight == 76)
    #expect(abs(fit.rect.midY - 328) < 0.001)
    fitView.invalidate()

    let oversizedView = PlaybackSubtitleFocusReelContainerView()
    oversizedView.frame = CGRect(x: 0, y: 0, width: 1_280, height: 100)
    var cues = focusLayoutCues(0..<20)
    cues[12] = focusLayoutCue(
        ordinal: 12,
        content: "first\nsecond\nthird"
    )
    oversizedView.update(
        cues: cues,
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    oversizedView.layoutSubtreeIfNeeded()
    let oversized = try #require(
        oversizedView.placementsForTesting.first { $0.ordinal == 12 }
    )
    #expect(oversized.measurement.naturalHeight == 180)
    #expect(oversized.measurement.resolvedHeight == 100)
    #expect(oversized.rect.minY == 0)
    oversizedView.invalidate()
}

@MainActor
@Test
func subtitleFocusFirstAndLastFittingCuesUseSameCenterAnchor() throws {
    for selectedOrdinal in [0, 19] {
        let view = PlaybackSubtitleFocusReelContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
        view.update(
            cues: focusLayoutCues(0..<20),
            totalCount: 20,
            selectedOrdinal: selectedOrdinal,
            keyboardNavigationRequest: nil,
            reducesMotion: false,
            isInteractionEnabled: true,
            cancelsWheelMotion: false
        )
        view.layoutSubtreeIfNeeded()
        let selected = try #require(
            view.placementsForTesting.first { $0.ordinal == selectedOrdinal }
        )
        #expect(abs(selected.rect.midY - 328) < 0.001)
        view.invalidate()
    }
}

@MainActor
@Test
func subtitleFocusDirectFiftyThousandCueTargetStaysLocallyVirtualized() {
    _ = NSApplication.shared
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        cues: focusLayoutCues(0..<50_000),
        totalCount: 50_000,
        selectedOrdinal: 25_000,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    #expect(view.placementsForTesting.contains { $0.ordinal == 25_000 })
    #expect(view.placementsForTesting.count <= 18)
    #expect(view.measuredOrdinalsForTesting.count <= 18)
    #expect(view.measuredOrdinalsForTesting.allSatisfy {
        abs($0 - 25_000) <= 9
    })
    #expect(view.measurementCacheCountForTesting <= 64)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusViewportWorkIsIndependentOfFiveHundredOrFiftyThousandCues() {
    func counts(totalCount: Int, selectedOrdinal: Int) -> (Int, Int) {
        let view = PlaybackSubtitleFocusReelContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
        view.update(
            cues: focusLayoutCues(0..<totalCount),
            totalCount: totalCount,
            selectedOrdinal: selectedOrdinal,
            keyboardNavigationRequest: nil,
            reducesMotion: false,
            isInteractionEnabled: true,
            cancelsWheelMotion: false
        )
        view.layoutSubtreeIfNeeded()
        let result = (
            view.placementsForTesting.count,
            view.measuredOrdinalsForTesting.count
        )
        view.invalidate()
        return result
    }

    let fiveHundred = counts(totalCount: 500, selectedOrdinal: 250)
    let fiftyThousand = counts(totalCount: 50_000, selectedOrdinal: 25_000)
    #expect(fiveHundred.0 == fiftyThousand.0)
    #expect(fiveHundred.1 == fiftyThousand.1)
    #expect(fiftyThousand.0 <= 18)
}

@MainActor
@Test
func subtitleFocusMeasurementInstrumentationStaysBoundedAcrossDocument() {
    let cues = focusLayoutCues(0..<50_000)
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)

    for target in stride(from: 0, to: 50_000, by: 500) {
        view.update(
            cues: cues,
            totalCount: cues.count,
            selectedOrdinal: target,
            keyboardNavigationRequest: nil,
            reducesMotion: false,
            isInteractionEnabled: true,
            cancelsWheelMotion: false
        )
        view.layoutSubtreeIfNeeded()
    }

    #expect(view.measurementCacheCountForTesting <= 64)
    #expect(view.measuredOrdinalsForTesting.count <= 64)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusSingleHugePreciseWheelEventStaysInsideLocalLayoutBudget() throws {
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        cues: focusLayoutCues(0..<50_000),
        totalCount: 50_000,
        selectedOrdinal: 25_000,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    let previousLocalLast = try #require(
        view.placementsForTesting.last?.ordinal
    )

    view.applyPreciseWheelDeltaForTesting(-1_000_000)

    #expect(view.fractionalOrdinalForTesting > 25_000)
    #expect(view.fractionalOrdinalForTesting <= CGFloat(previousLocalLast))
    #expect(view.measurementCacheCountForTesting <= 64)
    #expect(view.measuredOrdinalsForTesting.count <= 64)
    view.invalidate()
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
    #expect(abs(view.fractionalOrdinalForTesting - 149.25) < 0.000_001)

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
    #expect(view.fractionalOrdinalForTesting == 149)
    #expect(
        abs(
            view.scrollbarPresentationForTesting.vertical!.positionFraction
                - CGFloat(149) / 199
        ) < 0.000_001
    )
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
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    #expect(view.scrollbarPresentationForTesting.vertical != nil)
    #expect(!view.acceptsScrollbarInteractionForTesting)
    #expect(view.fractionalOrdinalForTesting == 12)

    view.update(
        cues: focusLayoutCues(0..<20),
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )

    #expect(view.acceptsScrollbarInteractionForTesting)
    #expect(view.fractionalOrdinalForTesting == 12)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusResizeCancelsActiveScrollbarDragWithoutCommit() {
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var commits: [Int] = []
    var dragStates: [Bool] = []
    view.onCommitNativeReelSelection = { ordinal in
        commits.append(ordinal)
        return true
    }
    view.onScrollbarDraggingChanged = { dragStates.append($0) }
    view.update(
        cues: focusLayoutCues(0..<200),
        totalCount: 200,
        selectedOrdinal: 12,
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

    #expect(commits.isEmpty)
    #expect(dragStates == [true, false])
    #expect(view.selectedOrdinalForTesting == 12)
    #expect(view.fractionalOrdinalForTesting == 12)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusKeyboardRequestCancelsOldScrollbarDragBeforeCommit() async {
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

    view.update(
        cues: focusLayoutCues(0..<200),
        totalCount: 200,
        selectedOrdinal: 12,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: 13
        ),
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: true
    )
    await Task.yield()
    await Task.yield()

    #expect(nativeCommits.isEmpty)
    #expect(keyboardCommits == [13])
    #expect(dragStates == [true, false])
    #expect(view.fractionalOrdinalForTesting == 13)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusResizePreservesSelectedIdentityAndAcceptedPlacement() throws {
    let view = PlaybackSubtitleFocusReelContainerView()
    var cues = focusLayoutCues(0..<20)
    cues[12] = focusLayoutCue(
        ordinal: 12,
        content: "a long cue that wraps as the focus overlay becomes narrower"
    )
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        cues: cues,
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    let wide = try #require(view.placementsForTesting.first { $0.ordinal == 12 })

    view.frame = CGRect(x: 0, y: 0, width: 320, height: 656)
    view.layoutSubtreeIfNeeded()
    let narrow = try #require(view.placementsForTesting.first { $0.ordinal == 12 })

    #expect(wide.cueID == narrow.cueID)
    #expect(narrow.measurement.visualLineCount > wide.measurement.visualLineCount)
    #expect(abs(narrow.rect.midY - 328) < 0.001)
    #expect(view.fractionalOrdinalForTesting == 12)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusMiddleCueTextReplacementInvalidatesMeasurement() throws {
    var cues = focusLayoutCues(0..<20)
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        cues: cues,
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    let before = try #require(
        view.placementsForTesting.first { $0.ordinal == 12 }
    )

    cues[12] = focusLayoutCue(
        ordinal: 12,
        content: "replacement one\nreplacement two\nreplacement three"
    )
    view.update(
        cues: cues,
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    let after = try #require(
        view.placementsForTesting.first { $0.ordinal == 12 }
    )

    #expect(before.measurement.visualLineCount == 1)
    #expect(after.measurement.visualLineCount == 3)
    #expect(after.measurement.naturalHeight == 180)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusResizeDoesNotCommitActiveKeyboardTarget() {
    let view = PlaybackSubtitleFocusReelContainerView()
    var commits: [Int] = []
    view.onCommitKeyboardNavigation = { request in
        commits.append(request.targetOrdinal)
        return true
    }
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        cues: focusLayoutCues(0..<20),
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: 13
        ),
        reducesMotion: false,
        isInteractionEnabled: false,
        cancelsWheelMotion: true
    )
    view.layoutSubtreeIfNeeded()

    view.frame = CGRect(x: 0, y: 0, width: 640, height: 500)
    view.layoutSubtreeIfNeeded()

    #expect(commits.isEmpty)
    #expect(view.selectedOrdinalForTesting == 12)
    #expect(view.fractionalOrdinalForTesting >= 12)
    #expect(view.fractionalOrdinalForTesting <= 13)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusResizeDoesNotCommitActivePreciseWheelPreview() {
    let view = PlaybackSubtitleFocusReelContainerView()
    var commits: [Int] = []
    view.onCommitNativeReelSelection = { ordinal in
        commits.append(ordinal)
        return true
    }
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        cues: focusLayoutCues(0..<20),
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    view.applyPreciseWheelDeltaForTesting(-42)

    view.frame = CGRect(x: 0, y: 0, width: 640, height: 500)
    view.layoutSubtreeIfNeeded()

    #expect(commits.isEmpty)
    #expect(view.selectedOrdinalForTesting == 12)
    #expect(view.fractionalOrdinalForTesting > 12)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusKeyboardAnimatorUsesDocumentedEaseOutCurve() {
    let samples = stride(from: CGFloat(0), through: 1, by: 0.1).map {
        PlaybackSubtitleFocusReelPositionAnimator.easedProgress($0)
    }

    #expect(samples.first == 0)
    #expect(samples.last == 1)
    #expect(samples == samples.sorted())
    #expect(PlaybackSubtitleFocusReelPositionAnimator.easedProgress(0.5) > 0.8)
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

@MainActor
@Test
func subtitleFocusPreciseWheelUsesContentDependentDistanceAndNearestSettlement() {
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        cues: focusLayoutCues(0..<20),
        totalCount: 20,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    let oneLineDistance = CGFloat(84)
    view.applyPreciseWheelDeltaForTesting(-oneLineDistance * 0.49)
    #expect(abs(view.fractionalOrdinalForTesting - 12.49) < 0.001)
    view.settlePreciseWheelForTesting()
    #expect(view.fractionalOrdinalForTesting == 12)
    view.invalidate()
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
            focusLayoutCue(
                ordinal: ordinal,
                content: [filledLine, filledLine, filledLine].joined(separator: "\n")
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
    let edgeRows = [
        8,
        16,
        24,
        bitmap.pixelsHigh - 24,
        bitmap.pixelsHigh - 16,
        bitmap.pixelsHigh - 8,
    ]
    var maximumEdgeComponent: CGFloat = 0
    for y in edgeRows {
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
            guard let color = bitmap.colorAt(x: x, y: y)?
                .usingColorSpace(.deviceRGB) else {
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
@Test
func subtitleFocusOverlayConsumesPointerAcrossItsCompleteSurface() throws {
    _ = NSApplication.shared
    let snapshot = SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: focusLayoutCues(6..<16)
    )
    var keyboardCommits: [Int] = []
    var nativeCommits: [Int] = []
    var actionCount = 0
    let hostingView = NSHostingView(
        rootView: PlaybackSubtitleFocusOverlay(
            snapshot: snapshot,
            onCommitKeyboardNavigation: { request in
                keyboardCommits.append(request.targetOrdinal)
                return true
            },
            onCommitNativeReelSelection: { ordinal in
                nativeCommits.append(ordinal)
                return true
            },
            onExecuteAction: { _ in
                actionCount += 1
                return true
            }
        )
        .frame(width: 1_280, height: 720)
    )
    let parent = NSView(frame: CGRect(x: 0, y: 0, width: 1_280, height: 720))
    let sentinel = PlaybackSubtitleFocusPointerSentinelView(frame: parent.bounds)
    hostingView.frame = parent.bounds
    parent.addSubview(sentinel)
    parent.addSubview(hostingView)
    let window = NSWindow(
        contentRect: parent.bounds,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = parent
    parent.layoutSubtreeIfNeeded()
    hostingView.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))

    let reel = try #require(
        playbackSubtitleFocusSubview(
            of: PlaybackSubtitleFocusReelContainerView.self,
            in: hostingView
        )
    )
    let documentView = try #require(
        playbackSubtitleFocusSubview(
            of: PlaybackSubtitleFocusReelDocumentView.self,
            in: hostingView
        )
    )
    reel.layoutSubtreeIfNeeded()
    let selectedPlacement = try #require(
        reel.placementsForTesting.first { $0.ordinal == 12 }
    )
    let cueTextPoint = documentView.convert(
        CGPoint(
            x: selectedPlacement.rect.minX + 20,
            y: selectedPlacement.rect.midY
        ),
        to: parent
    )
    let points = [
        CGPoint(x: 100, y: 8),
        CGPoint(x: 40, y: 180),
        cueTextPoint,
        CGPoint(x: 100, y: 712),
    ]
    let originalSelectedOrdinal = reel.selectedOrdinalForTesting
    let originalFractionalOrdinal = reel.fractionalOrdinalForTesting

    let targets = points.map { parent.hitTest($0) }
    #expect(
        targets.map { target in
            target.map { $0 !== sentinel } ?? false
        } == [true, true, true, true]
    )
    for (point, candidate) in zip(points, targets) {
        let target = try #require(candidate)
        target.mouseDown(with: playbackSubtitleFocusMouseEvent(
            location: parent.convert(point, to: nil),
            window: window
        ))
    }

    #expect(sentinel.mouseDownCount == 0)
    #expect(keyboardCommits.isEmpty)
    #expect(nativeCommits.isEmpty)
    #expect(actionCount == 0)
    #expect(reel.selectedOrdinalForTesting == originalSelectedOrdinal)
    #expect(reel.fractionalOrdinalForTesting == originalFractionalOrdinal)
    reel.invalidate()
    withExtendedLifetime(window) {}
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

@MainActor
private func playbackSubtitleFocusSubview<ViewType: NSView>(
    of type: ViewType.Type,
    in root: NSView
) -> ViewType? {
    if let match = root as? ViewType {
        return match
    }
    for subview in root.subviews {
        if let match = playbackSubtitleFocusSubview(of: type, in: subview) {
            return match
        }
    }
    return nil
}

@MainActor
private func playbackSubtitleFocusMouseEvent(
    location: CGPoint,
    window: NSWindow
) -> NSEvent {
    NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: location,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!
}

private final class PlaybackSubtitleFocusPointerSentinelView: NSView {
    private(set) var mouseDownCount = 0

    override func mouseDown(with event: NSEvent) {
        mouseDownCount += 1
    }
}

private func focusLayoutCues(_ range: Range<Int>) -> [SubtitleFocusCue] {
    range.map { focusLayoutCue(ordinal: $0) }
}

private func focusLayoutCue(
    ordinal: Int,
    content: String? = nil
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: Int64(ordinal + 1),
        cueGroupID: Int64(ordinal + 1_001),
        ordinal: ordinal,
        eventIndex: ordinal,
        displayOrder: 0,
        startMilliseconds: ordinal * 1_000,
        endMilliseconds: ordinal * 1_000 + 900,
        content: content ?? "cue \(ordinal)"
    )
}
