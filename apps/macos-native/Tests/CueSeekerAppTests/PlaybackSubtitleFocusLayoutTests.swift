import AppKit
import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

@Test
func subtitleFocusMetricsMatchCompactIterationGeometry() {
    #expect(PlaybackSubtitleFocusMetrics.cueVerticalPadding == 8)
    #expect(PlaybackSubtitleFocusMetrics.cueGap == 8)
    #expect(PlaybackSubtitleFocusMetrics.internalLineGap == 3)
    #expect(PlaybackSubtitleFocusMetrics.minimumNaturalCueHeight == 48)
    #expect(PlaybackSubtitleFocusMetrics.contentMaxWidth == 960)
    #expect(PlaybackSubtitleFocusMetrics.contentInset == 32)
    #expect(PlaybackSubtitleFocusMetrics.cueFontSize == 24)
    #expect(PlaybackSubtitleFocusMetrics.cueLineHeight == 32)
    #expect(PlaybackSubtitleFocusMetrics.reelTransitionDuration == 0.22)
    #expect(PlaybackCollageSelectionMetrics.checkboxSize == 24)
    #expect(
        PlaybackCollageSelectionMetrics.leadingAccessoryWidth
            == PlaybackCollageSelectionMetrics.checkboxSize
                + WorkbenchControlMetrics.redesignSpacing4
    )
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
func editingCollageReusesCurrentReelWithPrimaryCueCheckboxSelection() throws {
    _ = NSApplication.shared
    let cues = focusLayoutCues(0..<20)
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 640, height: 656)
    view.onToggleCollageCueSelection = { _ in }
    view.update(
        cues: cues,
        totalCount: cues.count,
        selectedOrdinal: 12,
        displayTitle: "Ave Mujica - 01",
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false,
        collageSelectedCueIDs: [cues[11].id],
        collageCanSelectAnotherCue: true
    )
    view.layoutSubtreeIfNeeded()

    let placement = try #require(
        view.placementsForTesting.first { $0.ordinal == 11 }
    )
    let checkboxRect = try #require(
        view.collageCheckboxRectForTesting(at: 11)
    )
    #expect(checkboxRect.width == PlaybackCollageSelectionMetrics.checkboxSize)
    #expect(checkboxRect.height == PlaybackCollageSelectionMetrics.checkboxSize)
    #expect(
        checkboxRect.midY
            == placement.rect.minY
                + PlaybackSubtitleFocusMetrics.informationHeight
                + PlaybackSubtitleFocusMetrics.cueVerticalPadding
                + PlaybackSubtitleFocusMetrics.cueLineHeight / 2
    )
    #expect(view.isCueHighlightedForTesting(at: 11))
    #expect(view.isCueHighlightedForTesting(at: 12))

    var toggledOrdinal: Int?
    view.onToggleCollageCueSelection = { toggledOrdinal = $0 }
    #expect(view.toggleCollageCueForTesting(at: 11))
    #expect(toggledOrdinal == 11)

    var toggledOrdinals: [Int] = []
    view.onToggleCollageCueSelection = { toggledOrdinals.append($0) }
    let badgePoint = CGPoint(
        x: placement.rect.minX
            + PlaybackCollageSelectionMetrics.leadingAccessoryWidth
            + 1,
        y: placement.rect.minY
            + PlaybackSubtitleFocusMetrics.cueVerticalPadding
            + 1
    )
    let primaryCuePoint = CGPoint(
        x: badgePoint.x,
        y: placement.rect.minY
            + PlaybackSubtitleFocusMetrics.informationHeight
            + PlaybackSubtitleFocusMetrics.cueVerticalPadding
            + 1
    )
    #expect(view.toggleCollageCueForTesting(at: badgePoint))
    #expect(view.toggleCollageCueForTesting(at: primaryCuePoint))
    #expect(toggledOrdinals == [11, 11])
    #expect(view.displayedSelectedOrdinalForTesting == 12)
    view.invalidate()
}

@MainActor
@Test
func editingCollageDisablesOnlyUncheckedCuesAtSelectionLimit() {
    _ = NSApplication.shared
    let cues = focusLayoutCues(0..<20)
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 640, height: 656)
    view.update(
        cues: cues,
        totalCount: cues.count,
        selectedOrdinal: 12,
        displayTitle: "Ave Mujica - 01",
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false,
        collageSelectedCueIDs: [cues[12].id],
        collageCanSelectAnotherCue: false
    )
    view.layoutSubtreeIfNeeded()

    #expect(view.isCollageCueEnabledForTesting(at: 12))
    #expect(!view.isCollageCueEnabledForTesting(at: 11))
    #expect(!view.toggleCollageCueForTesting(at: 11))
    #expect(view.toggleCollageCueForTesting(at: 12))
    let unselectedPlacement = view.placementsForTesting.first {
        $0.ordinal == 11
    }
    let selectedPlacement = view.placementsForTesting.first {
        $0.ordinal == 12
    }
    #expect(unselectedPlacement.map {
        !view.toggleCollageCueForTesting(at: CGPoint(
            x: $0.rect.midX,
            y: $0.rect.midY
        ))
    } == true)
    #expect(selectedPlacement.map {
        view.toggleCollageCueForTesting(at: CGPoint(
            x: $0.rect.midX,
            y: $0.rect.midY
        ))
    } == true)
    view.invalidate()
}

@Test
func playbackOverlayCurrentAndPlaylistShareFullWidthCueGeometry() {
    #expect(PlaybackOverlayMetrics.tabBarHeight == 54)
    #expect(PlaybackOverlayMetrics.tabIndicatorHeight == 2)
    #expect(PlaybackOverlayModule.standardModules == [.current])
    #expect(
        PlaybackOverlayModule.modules(hasPlaylist: true)
            == [.current, .playlist]
    )
}

@MainActor
@Test
func playbackCurrentUsesDedicatedCuePathWithTwoSharedInformationBadges() throws {
    let cue = SubtitleFocusCue(
        id: 42,
        cueGroupID: 142,
        ordinal: 0,
        eventIndex: 0,
        displayOrder: 0,
        startMilliseconds: 1_293_000,
        endMilliseconds: 1_300_000,
        content: "Primary Cue"
    )
    let adapter = PlaybackSubtitleFocusCueReelAdapter()
    adapter.update(
        cues: [cue],
        totalCount: 1,
        displayTitle: "Ave Mujica - 01",
        generation: 1
    )

    #expect(adapter.informationBadges(at: 0) == [
        "Ave Mujica - 01",
        "21:33 - 21:40",
    ])
}

@MainActor
@Test
func playbackCurrentEveryCueUsesFixedInformationHeightAndCachedBadgePlan() throws {
    let cue = SubtitleFocusCue(
        id: 42,
        cueGroupID: 142,
        ordinal: 0,
        eventIndex: 0,
        displayOrder: 0,
        startMilliseconds: 1_293_000,
        endMilliseconds: 1_300_000,
        content: "Primary Cue"
    )
    let adapter = PlaybackSubtitleFocusCueReelAdapter()
    adapter.update(
        cues: [cue],
        totalCount: 1,
        displayTitle: "Ave Mujica - 01",
        generation: 1
    )

    let base = try #require(adapter.extent(
        at: 0,
        isSelected: false,
        contentWidth: 960,
        viewportHeight: 656,
        uiProbeScope: nil
    ))
    for _ in 0..<1_000 {
        let selected = try #require(adapter.extent(
            at: 0,
            isSelected: true,
            contentWidth: 960,
            viewportHeight: 656,
            uiProbeScope: nil
        ))
        #expect(selected == base)
    }
    for _ in 0..<1_000 {
        _ = adapter.informationBadgePlans(at: 0, width: 960)
    }

    #expect(adapter.measurementCountForTesting == 1)
    #expect(adapter.informationBadgePlanPreparationCountForTesting == 1)
    #expect(
        base.naturalHeight
            == 48 + PlaybackSubtitleFocusMetrics.informationHeight
    )
}

@MainActor
@Test
func playbackCurrentUnselectedBadgePlansStayBounded() {
    var cues: [SubtitleFocusCue] = []
    for ordinal in 0..<100 {
        cues.append(SubtitleFocusCue(
            id: Int64(ordinal + 1),
            cueGroupID: Int64(ordinal + 1_001),
            ordinal: ordinal,
            eventIndex: ordinal,
            displayOrder: 0,
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            content: "Cue \(ordinal)"
        ))
    }
    let adapter = PlaybackSubtitleFocusCueReelAdapter()
    adapter.update(
        cues: cues,
        totalCount: cues.count,
        displayTitle: "Ave Mujica - 01",
        generation: 1
    )

    for ordinal in cues.indices {
        _ = adapter.informationBadgePlans(at: ordinal, width: 960)
    }

    #expect(adapter.informationBadgePlanCacheCountForTesting == 64)
    #expect(adapter.informationBadgePlanPreparationCountForTesting == 100)
}

@MainActor
@Test
func subtitleFocusTextMeasurementUsesEveryHardAndSoftVisualLine() {
    _ = NSApplication.shared
    let measurer = PlaybackSubtitleFocusCueTextMeasurer()

    for (text, expectedLines, expectedHeight) in [
        ("one", 1, CGFloat(48)),
        ("one\ntwo", 2, CGFloat(80)),
        ("one\ntwo\nthree", 3, CGFloat(112)),
        ("one\r\ntwo", 2, CGFloat(80)),
        ("one\n", 2, CGFloat(80)),
        ("one\n\nthree", 3, CGFloat(112)),
        ("", 1, CGFloat(48)),
    ] {
        let measurement = measurer.measurement(
            text: text,
            width: 2_000,
            viewportHeight: 1_000
        )
        #expect(measurement.visualLineCount == expectedLines)
        #expect(measurement.resolvedContentHeight == CGFloat(expectedLines) * 32)
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
            == CGFloat(wrapped.visualLineCount) * 32 + 16
    )
}

@MainActor
@Test
func subtitleFocusVisualLineStackPreservesEverySourceLineAtStrictThreePointGap() {
    let layout = PlaybackVisualLineStackLayout()

    for (text, expectedLineCount) in [
        ("one", 1),
        ("one\ntwo", 2),
        ("one\r\ntwo", 2),
        ("one\rtwo", 2),
        ("one\n", 2),
        ("one\n\nthree", 3),
        ("", 1),
    ] {
        let plan = layout.prepare(
            text: text,
            color: .white,
            width: 2_000
        )
        #expect(plan.visualLineCount == expectedLineCount)
        #expect(
            plan.nominalContentHeight
                == CGFloat(expectedLineCount)
                    * PlaybackSubtitleFocusMetrics.cueLineHeight
        )
        assertStrictPlaybackVisualLineGaps(plan)
    }
}

@MainActor
@Test
func subtitleFocusVisualLineStackUsesStrictThreePointGapAcrossSoftWraps() {
    let layout = PlaybackVisualLineStackLayout()
    let plan = layout.prepare(
        text: Array(repeating: "wrap", count: 40).joined(separator: " "),
        color: .white,
        width: 120
    )

    #expect(plan.visualLineCount > 3)
    assertStrictPlaybackVisualLineGaps(plan)
}

@MainActor
@Test
func subtitleFocusVisualLineStackUsesResolvedFontRunsInsteadOfLineSlots() throws {
    let layout = PlaybackVisualLineStackLayout()
    let plan = layout.prepare(
        text: "矛盾しない\nภาษาไทย 😀",
        color: .white,
        width: 2_000
    )

    #expect(plan.visualLineCount == 2)
    assertStrictPlaybackVisualLineGaps(plan)
    let first = try #require(plan.lines.first)
    #expect(first.typographicHeight > 0)
    #expect(abs(first.typographicHeight - first.usedRect.height) > 1)
    #expect(
        plan.resolvedContentHeight
            == max(plan.nominalContentHeight, plan.stackHeight)
    )
}

@MainActor
@Test
func subtitleFocusNativeTextLayoutDrawsEveryFittingLineAtStrictInternalGap() throws {
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
    #expect(first.minY >= 8)
    #expect(abs(second.minY - first.maxY - 3) < 0.001)
    #expect(abs(third.minY - second.maxY - 3) < 0.001)
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
    let text = "first\nsecond\nthird\nfourth"
    let cue = focusLayoutCue(ordinal: 0, content: text)
    let layout = PlaybackSubtitleFocusNativeTextLayout()
    let fitRects = layout.visibleLineRects(
        text: cue.text,
        in: CGRect(x: 0, y: 0, width: 800, height: 180)
    )
    let cueRect = CGRect(x: 0, y: 0, width: 800, height: 100)
    let visibleRects = layout.visibleLineRects(text: cue.text, in: cueRect)

    let first = try #require(visibleRects.first)
    let fitFirst = try #require(fitRects.first)
    #expect(first.minY >= 8)
    #expect(abs(first.minY - fitFirst.minY) < 0.001)
    #expect(visibleRects.count < 4)
    #expect(visibleRects.allSatisfy { cueRect.contains($0) })
    #expect(cue.text == text)
}

private func assertStrictPlaybackVisualLineGaps(
    _ plan: PlaybackVisualLineStackPlan
) {
    for (previous, next) in zip(plan.lines, plan.lines.dropFirst()) {
        #expect(
            abs(
                next.typographicTop
                    - previous.typographicBottom
                    - PlaybackSubtitleFocusMetrics.internalLineGap
            ) < 0.000_001
        )
    }
}

private func subtitleFocusMaximumLocalItemCount(
    viewportHeight: CGFloat
) -> Int {
    let minimumItemStep = PlaybackSubtitleFocusMetrics.minimumNaturalCueHeight
        + PlaybackSubtitleFocusMetrics.cueGap
    let visibleItemCount = Int(ceil(
        max(0, viewportHeight) / max(1, minimumItemStep)
    ))
    return visibleItemCount
        + PlaybackVirtualReelLayout.overscanItemCount * 2
        + 2
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
    #expect(measurement.naturalHeight == 112)
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
    #expect(layout.acceptedTop(forResolvedHeight: 48) == 304)
    #expect(layout.acceptedTop(forResolvedHeight: 656) == 0)
    #expect(layout.adjacentCenterDistance(from: 48, to: 48) == 56)
    #expect(layout.adjacentCenterDistance(from: 48, to: 80) == 72)
    #expect(layout.adjacentCenterDistance(from: 80, to: 112) == 104)
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
        lowerResolvedHeight: 48,
        upperResolvedHeight: 80
    )
    let upperTop = lowerTop + 48 + PlaybackSubtitleFocusMetrics.cueGap
    #expect(lowerTop == 268)
    #expect(upperTop == 324)
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
    #expect(fit.measurement.resolvedHeight == 48)
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
    #expect(oversized.measurement.naturalHeight == 112)
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
    let maximumLocalItemCount = subtitleFocusMaximumLocalItemCount(
        viewportHeight: view.frame.height
    )
    #expect(view.placementsForTesting.count <= maximumLocalItemCount)
    #expect(view.measuredOrdinalsForTesting.count <= maximumLocalItemCount)
    #expect(view.measuredOrdinalsForTesting.allSatisfy {
        abs($0 - 25_000) <= maximumLocalItemCount / 2
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
    #expect(
        fiftyThousand.0 <= subtitleFocusMaximumLocalItemCount(
            viewportHeight: 656
        )
    )
}

@MainActor
@Test
func playbackVirtualReelUsesOnlyLocalWorkForContentAgnosticItems() throws {
    _ = NSApplication.shared
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "test",
        generation: 1,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<50_000,
        isComplete: true,
        itemPrefix: "generic"
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 25_000,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    let selected = try #require(
        view.placementsForTesting.first { $0.ordinal == 25_000 }
    )
    #expect(selected.itemID == AnyHashable("generic-25000"))
    #expect(selected.extent.naturalHeight == 128)
    #expect(view.placementsForTesting.count <= 18)
    #expect(adapter.measuredOrdinals.count <= 18)
    #expect(adapter.measuredOrdinals.allSatisfy {
        abs($0 - 25_000) <= 9
    })
    view.invalidate()
    #expect(adapter.invalidationCount == 1)
    #expect(adapter.measuredOrdinals.isEmpty)
}

@MainActor
@Test
func playbackVirtualReelKeepsPositionAndCacheAcrossSameGenerationExpansion() {
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "test",
        generation: 4,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 6..<16,
        isComplete: false,
        itemPrefix: "window"
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    let initiallyMeasured = adapter.measuredOrdinals
    #expect(!view.acceptsScrollbarInteractionForTesting)

    adapter.replaceSnapshot(
        generation: 4,
        revision: 2,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "window"
    )
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    #expect(view.optionalSelectedOrdinalForTesting == 12)
    #expect(view.fractionalOrdinalForTesting == 12)
    #expect(initiallyMeasured.isSubset(of: adapter.measuredOrdinals))
    #expect(adapter.invalidationCount == 0)
    #expect(view.acceptsScrollbarInteractionForTesting)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelGenerationReplacementCancelsStaleCommitAndCache() async {
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    let first = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 8,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "old"
    )
    let replacement = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 9,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "new"
    )
    let staleRequest = PlaybackSubtitleFocusKeyboardNavigationRequest(
        sequence: 1,
        direction: .forward,
        targetOrdinal: 13,
        contentDatasetID: "search",
        contentGeneration: 8
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.update(
        contentAdapter: first,
        selectedOrdinal: 12,
        keyboardNavigationRequest: staleRequest,
        reducesMotion: false,
        isInteractionEnabled: false,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    view.update(
        contentAdapter: replacement,
        selectedOrdinal: 4,
        keyboardNavigationRequest: staleRequest,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    try? await Task.sleep(nanoseconds: 300_000_000)

    #expect(commits.isEmpty)
    #expect(first.invalidationCount == 1)
    #expect(first.measuredOrdinals.isEmpty)
    #expect(view.optionalSelectedOrdinalForTesting == 4)
    #expect(view.fractionalOrdinalForTesting == 4)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 4 }?.itemID
            == AnyHashable("new-4")
    )

    view.update(
        contentAdapter: replacement,
        selectedOrdinal: 4,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: 5,
            contentDatasetID: "search",
            contentGeneration: 9
        ),
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: false
    )
    await Task.yield()
    await Task.yield()
    #expect(commits == [PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable("search"),
        generation: 9,
        ordinal: 5
    )])
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelRejectsRequestFromOtherDatasetAtSameGeneration() async {
    let first = PlaybackVirtualReelTestAdapter(
        datasetID: "playlist",
        generation: 1,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "playlist"
    )
    let replacement = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 1,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "search"
    )
    let staleRequest = PlaybackSubtitleFocusKeyboardNavigationRequest(
        sequence: 1,
        direction: .forward,
        targetOrdinal: 13,
        contentDatasetID: "playlist",
        contentGeneration: 1
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.update(
        contentAdapter: first,
        selectedOrdinal: 12,
        keyboardNavigationRequest: staleRequest,
        reducesMotion: false,
        isInteractionEnabled: false,
        cancelsWheelMotion: false
    )
    view.update(
        contentAdapter: replacement,
        selectedOrdinal: 4,
        keyboardNavigationRequest: staleRequest,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(commits.isEmpty)
    #expect(view.optionalSelectedOrdinalForTesting == 4)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 4 }?.itemID
            == AnyHashable("search-4")
    )
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelAcceptsEmptyContentWithoutSyntheticSelection() {
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 1,
        revision: 1,
        totalCount: 0,
        loadedOrdinalRange: 0..<0,
        isComplete: true,
        itemPrefix: "empty"
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: nil,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    #expect(view.optionalSelectedOrdinalForTesting == nil)
    #expect(view.placementsForTesting.isEmpty)
    #expect(view.scrollbarPresentationForTesting.vertical == nil)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelRejectsRevisionRegressionAndReleasesReplacedAdapter() {
    let current = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 3,
        revision: 2,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "current"
    )
    let stale = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 3,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "stale"
    )
    let newer = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 3,
        revision: 3,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "newer"
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        contentAdapter: current,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    view.update(
        contentAdapter: stale,
        selectedOrdinal: 4,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(stale.invalidationCount == 1)
    #expect(current.invalidationCount == 0)
    #expect(view.optionalSelectedOrdinalForTesting == 12)
    #expect(view.fractionalOrdinalForTesting == 12)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 12 }?.itemID
            == AnyHashable("current-12")
    )

    view.update(
        contentAdapter: newer,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(current.invalidationCount == 1)
    #expect(newer.invalidationCount == 0)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 12 }?.itemID
            == AnyHashable("newer-12")
    )
    let invalidStale = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 3,
        revision: 2,
        totalCount: 20,
        loadedOrdinalRange: 0..<21,
        isComplete: false,
        itemPrefix: "invalid-stale"
    )
    view.update(
        contentAdapter: invalidStale,
        selectedOrdinal: 4,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(invalidStale.invalidationCount == 1)
    #expect(view.optionalSelectedOrdinalForTesting == 12)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 12 }?.itemID
            == AnyHashable("newer-12")
    )
    let invalidFuture = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 4,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<21,
        isComplete: false,
        itemPrefix: "invalid-future"
    )
    view.update(
        contentAdapter: invalidFuture,
        selectedOrdinal: 4,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(invalidFuture.invalidationCount == 1)
    #expect(view.optionalSelectedOrdinalForTesting == 12)
    let changedTotal = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 3,
        revision: 4,
        totalCount: 21,
        loadedOrdinalRange: 0..<21,
        isComplete: true,
        itemPrefix: "changed-total"
    )
    view.update(
        contentAdapter: changedTotal,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(changedTotal.invalidationCount == 1)
    #expect(view.optionalSelectedOrdinalForTesting == 12)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelRejectedKeyboardCommitUnlocksNextRequest() async {
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 5,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "result"
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    var attempts: [Int] = []
    var acceptsCommit = false
    var motionGateStates: [Bool] = []
    view.onCommitVirtualReelSelection = { commit in
        attempts.append(commit.ordinal)
        return acceptsCommit
    }
    view.onNativeMotionGateChanged = { motionGateStates.append($0) }
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: 13,
            contentDatasetID: "search",
            contentGeneration: 5
        ),
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: false
    )
    await Task.yield()
    await Task.yield()
    #expect(attempts == [13])
    #expect(view.optionalSelectedOrdinalForTesting == 12)
    #expect(view.fractionalOrdinalForTesting == 12)
    #expect(motionGateStates.last == false)

    acceptsCommit = true
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 2,
            direction: .forward,
            targetOrdinal: 14,
            contentDatasetID: "search",
            contentGeneration: 5
        ),
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: false
    )
    await Task.yield()
    await Task.yield()
    #expect(attempts == [13, 14])
    #expect(view.optionalSelectedOrdinalForTesting == 14)
    #expect(motionGateStates.last == false)
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 14,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: 15,
            contentDatasetID: "search",
            contentGeneration: 5
        ),
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: false
    )
    await Task.yield()
    #expect(attempts == [13, 14])
    #expect(view.optionalSelectedOrdinalForTesting == 14)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelInvalidateClearsStateAndCancelsPendingCommit() async {
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 6,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "result"
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    var motionGateStates: [Bool] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.onNativeMotionGateChanged = { motionGateStates.append($0) }
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: 13,
            contentDatasetID: "search",
            contentGeneration: 6
        ),
        reducesMotion: false,
        isInteractionEnabled: false,
        cancelsWheelMotion: false
    )
    view.invalidate()
    try? await Task.sleep(nanoseconds: 300_000_000)

    #expect(commits.isEmpty)
    #expect(motionGateStates.last == false)
    #expect(adapter.invalidationCount == 1)
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    #expect(view.fractionalOrdinalForTesting == 0)
    #expect(view.measurementCacheCountForTesting == 0)
    #expect(view.scrollbarPresentationForTesting.vertical == nil)
}

@MainActor
@Test
func playbackVirtualReelEmptyContentRejectsAllInputAndOldRequest() async {
    let empty = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 1,
        revision: 1,
        totalCount: 0,
        loadedOrdinalRange: 0..<0,
        isComplete: true,
        itemPrefix: "empty"
    )
    let populated = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 2,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "result"
    )
    let staleRequest = PlaybackSubtitleFocusKeyboardNavigationRequest(
        sequence: 1,
        direction: .forward,
        targetOrdinal: 0,
        contentDatasetID: "search",
        contentGeneration: 1
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    var motionGateStates: [Bool] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.onNativeMotionGateChanged = { motionGateStates.append($0) }
    view.update(
        contentAdapter: empty,
        selectedOrdinal: nil,
        keyboardNavigationRequest: staleRequest,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.applyPreciseWheelDeltaForTesting(-500)
    view.settlePreciseWheelForTesting()
    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.5
    ))
    await Task.yield()
    #expect(commits.isEmpty)
    #expect(motionGateStates.allSatisfy { !$0 })

    view.update(
        contentAdapter: populated,
        selectedOrdinal: 0,
        keyboardNavigationRequest: staleRequest,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    await Task.yield()
    #expect(commits.isEmpty)
    view.update(
        contentAdapter: populated,
        selectedOrdinal: 0,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 2,
            direction: .forward,
            targetOrdinal: 1,
            contentDatasetID: "search",
            contentGeneration: 2
        ),
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: false
    )
    await Task.yield()
    await Task.yield()
    #expect(commits.map(\.ordinal) == [1])
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelSameAdapterGenerationClearsMeasurements() {
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 1,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "old"
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(!adapter.measuredOrdinals.isEmpty)
    adapter.replaceSnapshot(
        generation: 2,
        revision: 1,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "new"
    )
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 4,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(adapter.measurementInvalidationCount == 1)
    #expect(adapter.invalidationCount == 0)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 4 }?.itemID
            == AnyHashable("new-4")
    )
    adapter.replaceSnapshot(
        generation: 1,
        revision: 99,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "regressed"
    )
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 4,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(adapter.invalidationCount == 1)
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    #expect(view.placementsForTesting.isEmpty)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelInvalidSnapshotInvalidatesMountedAdapterOnce() {
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 1,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "valid"
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    adapter.replaceSnapshot(
        generation: 1,
        revision: 2,
        loadedOrdinalRange: 0..<21,
        isComplete: false,
        itemPrefix: "invalid"
    )
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(adapter.invalidationCount == 1)
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    #expect(view.placementsForTesting.isEmpty)
}

@MainActor
@Test
func playbackVirtualReelMissingStableIdentityFailsClosed() {
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 1,
        revision: 1,
        totalCount: 20,
        loadedOrdinalRange: 0..<20,
        isComplete: true,
        itemPrefix: "result",
        missingItemIDs: [12]
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 12,
        keyboardNavigationRequest: nil,
        reducesMotion: false,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(view.placementsForTesting.isEmpty)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelLoadsRemoteWindowBeforeScrollbarCommit() throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 7,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "initial",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    var motionGateStates: [Bool] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.onNativeMotionGateChanged = { motionGateStates.append($0) }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(initial.requestedWindows.isEmpty)
    #expect(view.acceptsScrollbarInteractionForTesting)

    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.75
    ))
    view.handleScrollbarDraggingChanged(false)
    let request = try #require(initial.requestedWindows.last)
    #expect(request.reason == .scrollbar)
    #expect(request.suggestedOrdinalRange.count == 32)
    #expect(request.suggestedOrdinalRange.contains(request.targetOrdinal))
    #expect(commits.isEmpty)
    #expect(motionGateStates.last == true)

    let response = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 7,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: request.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "remote",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: response,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(commits.map(\.ordinal) == [request.targetOrdinal])
    #expect(view.optionalSelectedOrdinalForTesting == request.targetOrdinal)
    #expect(view.fractionalOrdinalForTesting == CGFloat(request.targetOrdinal))
    #expect(view.placementsForTesting.count <= 18)
    #expect(response.snapshot.loadedOrdinalRange.count == 32)
    #expect(!response.snapshot.isComplete)
    #expect(initial.invalidationCount == 1)
    #expect(motionGateStates.last == false)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelBootstrapsAnInitiallyEmptyRemoteWindow() throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 4,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<0,
        isComplete: false,
        itemPrefix: "empty-window",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 20_000,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    let request = try #require(initial.requestedWindows.last)
    #expect(request.reason == .visible)
    #expect(request.targetOrdinal == 20_000)
    #expect(request.suggestedOrdinalRange.count == 32)
    #expect(view.optionalSelectedOrdinalForTesting == nil)

    let response = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 4,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: request.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "loaded-window",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: response,
        selectedOrdinal: 20_000,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(commits.isEmpty)
    #expect(view.optionalSelectedOrdinalForTesting == 20_000)
    #expect(view.fractionalOrdinalForTesting == 20_000)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 20_000 }?.itemID
            == AnyHashable("loaded-window-20000")
    )
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelRejectedRemoteCommitReloadsPriorWindow() throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 10,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "initial",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var attemptedOrdinals: [Int] = []
    view.onCommitVirtualReelSelection = { commit in
        attemptedOrdinals.append(commit.ordinal)
        return false
    }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.75
    ))
    view.handleScrollbarDraggingChanged(false)
    let remoteRequest = try #require(initial.requestedWindows.last)
    let remote = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 10,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: remoteRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "remote",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: remote,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(attemptedOrdinals == [remoteRequest.targetOrdinal])
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    let fallbackRequest = try #require(remote.requestedWindows.last)
    #expect(fallbackRequest.reason == .visible)
    #expect(fallbackRequest.targetOrdinal == 16)

    let fallback = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 10,
        revision: 3,
        totalCount: 50_000,
        loadedOrdinalRange: fallbackRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "fallback",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: fallback,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(attemptedOrdinals == [remoteRequest.targetOrdinal])
    #expect(view.optionalSelectedOrdinalForTesting == 16)
    #expect(view.fractionalOrdinalForTesting == 16)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 16 }?.itemID
            == AnyHashable("fallback-16")
    )
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelRejectsLateRemoteWindowFromOldGeneration() throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 1,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "initial",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.75
    ))
    view.handleScrollbarDraggingChanged(false)
    let request = try #require(initial.requestedWindows.last)

    let replacement = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 2,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "replacement",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: replacement,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    let staleResponse = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 1,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: request.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "stale",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: staleResponse,
        selectedOrdinal: request.targetOrdinal,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(commits.isEmpty)
    #expect(staleResponse.invalidationCount == 1)
    #expect(view.optionalSelectedOrdinalForTesting == 16)
    #expect(
        view.placementsForTesting.first { $0.ordinal == 16 }?.itemID
            == AnyHashable("replacement-16")
    )
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelReissuesPendingRequestAcrossReplacementWindows() throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 20,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "initial",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    var motionGateStates: [Bool] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.onNativeMotionGateChanged = { motionGateStates.append($0) }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: 100,
            contentDatasetID: "search",
            contentGeneration: 20
        ),
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    let initialRequest = try #require(initial.requestedWindows.last)
    #expect(initialRequest.reason == .keyboard)
    #expect(motionGateStates.last == true)

    let replacementTransport = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 20,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "replacement",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: replacementTransport,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(initial.invalidationCount == 1)
    #expect(replacementTransport.requestedWindows.last == initialRequest)

    let intermediate = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 20,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: 200..<232,
        isComplete: false,
        itemPrefix: "intermediate",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: intermediate,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    let reissuedRequest = try #require(intermediate.requestedWindows.last)
    #expect(reissuedRequest.reason == .keyboard)
    #expect(reissuedRequest.targetOrdinal == 100)
    #expect(view.optionalSelectedOrdinalForTesting == nil)

    let response = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 20,
        revision: 3,
        totalCount: 50_000,
        loadedOrdinalRange: reissuedRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "response",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: response,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(commits.map(\.ordinal) == [100])
    #expect(view.optionalSelectedOrdinalForTesting == 100)
    #expect(motionGateStates.last == false)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelNewKeyboardIntentSupersedesPendingRemoteCommit() async throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 21,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "initial",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: 100,
            contentDatasetID: "search",
            contentGeneration: 21
        ),
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    let staleRequest = try #require(initial.requestedWindows.last)
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 2,
            direction: .forward,
            targetOrdinal: 17,
            contentDatasetID: "search",
            contentGeneration: 21
        ),
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    await Task.yield()
    #expect(commits.map(\.ordinal) == [17])

    let staleResponse = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 21,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: staleRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "stale-response",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: staleResponse,
        selectedOrdinal: 17,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(commits.map(\.ordinal) == [17])
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    let restoreRequest = try #require(staleResponse.requestedWindows.last)
    #expect(restoreRequest.reason == .visible)
    #expect(restoreRequest.targetOrdinal == 17)

    let restored = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 21,
        revision: 3,
        totalCount: 50_000,
        loadedOrdinalRange: restoreRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "restored",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: restored,
        selectedOrdinal: 17,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(commits.map(\.ordinal) == [17])
    #expect(view.optionalSelectedOrdinalForTesting == 17)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelExternalSelectionSupersedesPendingRestore() throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 22,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<0,
        isComplete: false,
        itemPrefix: "empty",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 100,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    let staleRestore = try #require(initial.requestedWindows.last)
    #expect(staleRestore.targetOrdinal == 100)

    view.update(
        contentAdapter: initial,
        selectedOrdinal: 200,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    let latestRestore = try #require(initial.requestedWindows.last)
    #expect(latestRestore.targetOrdinal == 200)

    let staleResponse = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 22,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: staleRestore.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "stale-response",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: staleResponse,
        selectedOrdinal: 200,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    let reissuedRestore = try #require(staleResponse.requestedWindows.last)
    #expect(reissuedRestore.targetOrdinal == 200)

    let latestResponse = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 22,
        revision: 3,
        totalCount: 50_000,
        loadedOrdinalRange: reissuedRestore.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "latest-response",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: latestResponse,
        selectedOrdinal: 200,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(view.optionalSelectedOrdinalForTesting == 200)
    #expect(view.displayedSelectedOrdinalForTesting == 200)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelRemoteScrollbarPreviewWaitsForMouseUpToCommit() async throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 23,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "initial",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var commits: [PlaybackVirtualReelSelectionCommit] = []
    view.onCommitVirtualReelSelection = { commit in
        commits.append(commit)
        return true
    }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
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
    let previewRequest = try #require(initial.requestedWindows.last)
    #expect(commits.isEmpty)

    let previewResponse = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 23,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: previewRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "preview",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: previewResponse,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()
    #expect(commits.isEmpty)
    #expect(previewResponse.requestedWindows.isEmpty)
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    #expect(view.displayedSelectedOrdinalForTesting == previewRequest.targetOrdinal)
    #expect(
        abs(view.fractionalOrdinalForTesting - 37_499.25) < 0.000_001
    )

    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.75
    ))
    view.handleScrollbarDraggingChanged(false)
    await Task.yield()
    #expect(commits.map(\.ordinal) == [previewRequest.targetOrdinal])
    #expect(view.optionalSelectedOrdinalForTesting == previewRequest.targetOrdinal)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelPendingTargetSuppressesOldSelectionPrefetch() throws {
    let adapter = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 24,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 100..<110,
        isComplete: false,
        itemPrefix: "narrow-window",
        supportsWindowRequests: true
    )
    let request = PlaybackSubtitleFocusKeyboardNavigationRequest(
        sequence: 1,
        direction: .forward,
        targetOrdinal: 1_000,
        contentDatasetID: "search",
        contentGeneration: 24
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 105,
        keyboardNavigationRequest: request,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(adapter.requestedWindows.count == 1)
    let pendingRequest = try #require(adapter.requestedWindows.first)
    #expect(pendingRequest.reason == .keyboard)
    #expect(pendingRequest.targetOrdinal == 1_000)

    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 105,
        keyboardNavigationRequest: request,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(adapter.requestedWindows == [pendingRequest])
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelWheelModesLoadAdjacentWindowBeforeCommit() {
    for (generation, usesPreciseWheel) in [(UInt64(25), false), (26, true)] {
        let initial = PlaybackVirtualReelTestAdapter(
            datasetID: "search",
            generation: generation,
            revision: 1,
            totalCount: 50_000,
            loadedOrdinalRange: 0..<32,
            isComplete: false,
            itemPrefix: "initial",
            supportsWindowRequests: true
        )
        let view = PlaybackVirtualReelContainerView()
        view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
        var commits: [PlaybackVirtualReelSelectionCommit] = []
        var motionGateStates: [Bool] = []
        view.onCommitVirtualReelSelection = { commit in
            commits.append(commit)
            return true
        }
        view.onNativeMotionGateChanged = { motionGateStates.append($0) }
        view.update(
            contentAdapter: initial,
            selectedOrdinal: 31,
            keyboardNavigationRequest: nil,
            reducesMotion: true,
            isInteractionEnabled: true,
            cancelsWheelMotion: false
        )
        if usesPreciseWheel {
            view.applyPreciseWheelDeltaForTesting(-500)
        } else {
            view.applyDiscreteWheelForTesting(direction: .forward)
        }
        guard let request = initial.requestedWindows.last else {
            Issue.record("Expected an adjacent wheel window request")
            view.invalidate()
            continue
        }
        #expect(request.reason == .wheel)
        #expect(request.targetOrdinal == 32)
        #expect(motionGateStates.last == true)

        let response = PlaybackVirtualReelTestAdapter(
            datasetID: "search",
            generation: generation,
            revision: 2,
            totalCount: 50_000,
            loadedOrdinalRange: request.suggestedOrdinalRange,
            isComplete: false,
            itemPrefix: "response",
            supportsWindowRequests: true
        )
        view.update(
            contentAdapter: response,
            selectedOrdinal: 31,
            keyboardNavigationRequest: nil,
            reducesMotion: true,
            isInteractionEnabled: true,
            cancelsWheelMotion: false
        )
        #expect(commits.map(\.ordinal) == [32])
        #expect(view.optionalSelectedOrdinalForTesting == 32)
        #expect(motionGateStates.last == false)
        view.invalidate()
    }
}

@MainActor
@Test
func playbackVirtualReelRejectedLoadedScrollbarPreviewRestoresExternalSelection() async throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 27,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "initial",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    var attempts: [Int] = []
    view.onCommitVirtualReelSelection = { commit in
        attempts.append(commit.ordinal)
        return false
    }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .changed,
        positionFraction: 0.75
    ))
    let previewRequest = try #require(initial.requestedWindows.last)
    let previewResponse = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 27,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: previewRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "preview",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: previewResponse,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.75
    ))
    view.handleScrollbarDraggingChanged(false)
    await Task.yield()
    #expect(attempts == [previewRequest.targetOrdinal])
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    let restoreRequest = try #require(previewResponse.requestedWindows.last)
    #expect(restoreRequest.reason == .visible)
    #expect(restoreRequest.targetOrdinal == 16)

    let restored = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 27,
        revision: 3,
        totalCount: 50_000,
        loadedOrdinalRange: restoreRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "restored",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: restored,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    #expect(attempts == [previewRequest.targetOrdinal])
    #expect(view.optionalSelectedOrdinalForTesting == 16)
    view.invalidate()
}

@MainActor
@Test
func playbackVirtualReelCancellingRemotePreviewDoesNotReapplyIt() throws {
    let initial = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 28,
        revision: 1,
        totalCount: 50_000,
        loadedOrdinalRange: 0..<32,
        isComplete: false,
        itemPrefix: "initial",
        supportsWindowRequests: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    view.update(
        contentAdapter: initial,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .changed,
        positionFraction: 0.75
    ))
    let previewRequest = try #require(initial.requestedWindows.last)
    let previewResponse = PlaybackVirtualReelTestAdapter(
        datasetID: "search",
        generation: 28,
        revision: 2,
        totalCount: 50_000,
        loadedOrdinalRange: previewRequest.suggestedOrdinalRange,
        isComplete: false,
        itemPrefix: "preview",
        supportsWindowRequests: true
    )
    view.update(
        contentAdapter: previewResponse,
        selectedOrdinal: 16,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: true
    )
    #expect(view.optionalSelectedOrdinalForTesting == nil)
    #expect(view.displayedSelectedOrdinalForTesting == nil)
    #expect(abs(view.fractionalOrdinalForTesting - 37_499.25) > 0.000_001)
    let restoreRequest = try #require(previewResponse.requestedWindows.last)
    #expect(restoreRequest.targetOrdinal == 16)
    view.invalidate()
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
    #expect(after.measurement.naturalHeight == 112)
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

    let oneLineDistance = CGFloat(56)
    view.applyPreciseWheelDeltaForTesting(-oneLineDistance * 0.49)
    #expect(abs(view.fractionalOrdinalForTesting - 12.49) < 0.001)
    view.settlePreciseWheelForTesting()
    #expect(view.fractionalOrdinalForTesting == 12)
    view.invalidate()
}

@MainActor
@Test
func subtitleFocusOverlayRendersAppearanceBackgroundAtStageSize() throws {
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
    for (colorScheme, expectsLightBackground) in [
        (ColorScheme.light, true),
        (ColorScheme.dark, false),
    ] {
        let renderer = ImageRenderer(
            content: PlaybackSubtitleFocusOverlay(snapshot: snapshot)
                .frame(width: 1_280, height: 720)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = 1

        let renderedImage = try #require(renderer.nsImage)
        #expect(renderedImage.size.width == 1_280)
        #expect(renderedImage.size.height == 720)

        let imageData = try #require(renderedImage.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: imageData))
        let cornerPoints = [
            (8, 8),
            (bitmap.pixelsWide - 8, 8),
            (8, bitmap.pixelsHigh - 8),
            (bitmap.pixelsWide - 8, bitmap.pixelsHigh - 8),
        ]
        for (x, y) in cornerPoints {
            let color = try #require(
                bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
            )
            let minimumComponent = min(
                color.redComponent,
                min(color.greenComponent, color.blueComponent)
            )
            let maximumComponent = max(
                color.redComponent,
                max(color.greenComponent, color.blueComponent)
            )
            if expectsLightBackground {
                #expect(minimumComponent > 0.9)
            } else {
                #expect(maximumComponent < 0.3)
            }
        }
    }
}

@MainActor
@Test
func subtitleFocusNativeReelAppearanceChangePreservesStateAndCaches() throws {
    _ = NSApplication.shared
    let view = PlaybackSubtitleFocusReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.appearance = NSAppearance(named: .aqua)
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

    let scrollbarView = try #require(
        playbackSubtitleFocusSubview(
            of: TableScrollbarOverlayView.self,
            in: view
        )
    )
    let selectedOrdinal = view.selectedOrdinalForTesting
    let fractionalOrdinal = view.fractionalOrdinalForTesting
    let measurementCacheCount = view.measurementCacheCountForTesting

    #expect(scrollbarView.appearanceMode == .inherited)
    view.appearance = NSAppearance(named: .darkAqua)
    view.layoutSubtreeIfNeeded()

    #expect(view.selectedOrdinalForTesting == selectedOrdinal)
    #expect(view.fractionalOrdinalForTesting == fractionalOrdinal)
    #expect(view.measurementCacheCountForTesting == measurementCacheCount)
    view.invalidate()
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

@MainActor
private final class PlaybackVirtualReelTestAdapter:
    PlaybackVirtualReelContentAdapter
{
    private(set) var snapshot: PlaybackVirtualReelSnapshot
    private(set) var measuredOrdinals: Set<Int> = []
    private(set) var invalidationCount = 0
    private(set) var measurementInvalidationCount = 0
    private(set) var requestedWindows: [PlaybackVirtualReelWindowRequest] = []
    let supportsWindowRequests: Bool
    private var itemPrefix: String
    private let missingItemIDs: Set<Int>

    init(
        datasetID: String,
        generation: UInt64,
        revision: UInt64,
        totalCount: Int,
        loadedOrdinalRange: Range<Int>,
        isComplete: Bool,
        itemPrefix: String,
        supportsWindowRequests: Bool = false,
        missingItemIDs: Set<Int> = []
    ) {
        snapshot = PlaybackVirtualReelSnapshot(
            datasetID: AnyHashable(datasetID),
            generation: generation,
            revision: revision,
            totalCount: totalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            loadedItemCount: loadedOrdinalRange.count,
            isComplete: isComplete
        )
        self.itemPrefix = itemPrefix
        self.supportsWindowRequests = supportsWindowRequests
        self.missingItemIDs = missingItemIDs
    }

    var measurementCacheCountForTesting: Int {
        measuredOrdinals.count
    }

    var measuredOrdinalsForTesting: Set<Int> {
        measuredOrdinals
    }

    func replaceSnapshot(
        generation: UInt64,
        revision: UInt64,
        loadedOrdinalRange: Range<Int>,
        isComplete: Bool,
        itemPrefix: String
    ) {
        snapshot = PlaybackVirtualReelSnapshot(
            datasetID: snapshot.datasetID,
            generation: generation,
            revision: revision,
            totalCount: snapshot.totalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            loadedItemCount: loadedOrdinalRange.count,
            isComplete: isComplete
        )
        self.itemPrefix = itemPrefix
    }

    func itemID(at ordinal: Int) -> AnyHashable? {
        guard snapshot.loadedOrdinalRange.contains(ordinal) else {
            return nil
        }
        guard !missingItemIDs.contains(ordinal) else {
            return nil
        }
        return AnyHashable("\(itemPrefix)-\(ordinal)")
    }

    func extent(
        at ordinal: Int,
        isSelected: Bool,
        contentWidth: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String?
    ) -> PlaybackVirtualReelItemExtent? {
        guard snapshot.loadedOrdinalRange.contains(ordinal) else {
            return nil
        }
        measuredOrdinals.insert(ordinal)
        let visualLineCount = ordinal % 3 + 1
        let naturalHeight = CGFloat(visualLineCount * 52 + 24)
        return PlaybackVirtualReelItemExtent(
            visualLineCount: visualLineCount,
            visualLineStackHeight: naturalHeight - 24,
            resolvedContentHeight: naturalHeight - 24,
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, max(0, viewportHeight)),
            isOversized: naturalHeight > viewportHeight
        )
    }

    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        isEnabled _: Bool,
        in rect: CGRect
    ) {}

    func requestWindow(_ request: PlaybackVirtualReelWindowRequest) {
        requestedWindows.append(request)
    }

    func invalidateMeasurements() {
        measurementInvalidationCount += 1
        measuredOrdinals.removeAll(keepingCapacity: false)
    }

    func invalidate() {
        invalidationCount += 1
        invalidateMeasurements()
        requestedWindows.removeAll(keepingCapacity: false)
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
