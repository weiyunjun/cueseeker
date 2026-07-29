import AppKit
import Testing
@testable import CueSeekerApp

@Test
func playbackCueResultMetricsMatchDocumentedTokens() {
    #expect(PlaybackSubtitleFocusMetrics.cueVerticalPadding == 12)
    #expect(PlaybackSubtitleFocusMetrics.cueGap == 8)
    #expect(PlaybackSubtitleFocusMetrics.internalLineGap == 5)
    #expect(PlaybackSubtitleFocusMetrics.cueFontSize == 40)
    #expect(PlaybackSubtitleFocusMetrics.cueLineHeight == 52)
    #expect(PlaybackSubtitleFocusMetrics.cueFontWeight == .semibold)
    #expect(PlaybackSubtitleFocusMetrics.cueGroupFontSize == 28)
    #expect(PlaybackSubtitleFocusMetrics.cueGroupLineHeight == 38)
    #expect(PlaybackSubtitleFocusMetrics.cueGroupFontWeight == .medium)
    #expect(PlaybackSubtitleFocusMetrics.informationBadgeGap == 8)
    #expect(PlaybackSubtitleFocusMetrics.informationCueGap == 8)
    #expect(PlaybackSubtitleFocusMetrics.informationBadgeFontSize == 12)
    #expect(PlaybackSubtitleFocusMetrics.informationBadgeRadius == 6)
    #expect(PlaybackSubtitleFocusMetrics.informationBadgeHorizontalPadding == 10)
    #expect(PlaybackSubtitleFocusMetrics.informationBadgeVerticalPadding == 4)
    #expect(PlaybackSubtitleFocusMetrics.informationBadgeRowHeight == 23)
    #expect(PlaybackSubtitleFocusMetrics.selectedInformationHeight == 31)
    #expect(
        playbackCueResultAlpha(
            PlaybackTheme.subtitleFocusCueSelectedNative
        ) == 0.94
    )
    #expect(
        playbackCueResultAlpha(
            PlaybackTheme.subtitleFocusCueGroupSelectedNative
        ) == 0.62
    )
    #expect(
        playbackCueResultAlpha(
            PlaybackTheme.subtitleFocusCueUnselectedNative
        ) == 0.34
    )
}

@Test
func playbackSubtitleFocusColorsResolveDocumentedLightAndDarkTokens() {
    #expect(
        playbackCueResultHex(
            PlaybackTheme.subtitleFocusOverlayBackgroundNative,
            appearanceName: .aqua
        ) == "#F6F7F9"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.subtitleFocusOverlayBackgroundNative,
            appearanceName: .darkAqua
        ) == "#242426"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.subtitleFocusCueSelectedNative,
            appearanceName: .aqua
        ) == "#111827"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.subtitleFocusCueGroupSelectedNative,
            appearanceName: .aqua
        ) == "#475467"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.subtitleFocusCueUnselectedNative,
            appearanceName: .aqua
        ) == "#858B95"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.playbackModuleSidebarSelectedNative,
            appearanceName: .aqua
        ) == "#111827"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.playbackModuleSidebarUnselectedNative,
            appearanceName: .aqua
        ) == "#667085"
    )
    #expect(
        playbackCueResultAlpha(
            PlaybackTheme.subtitleFocusCueSelectedNative,
            appearanceName: .darkAqua
        ) == 0.94
    )
    #expect(
        playbackCueResultAlpha(
            PlaybackTheme.subtitleFocusCueGroupSelectedNative,
            appearanceName: .darkAqua
        ) == 0.62
    )
    #expect(
        playbackCueResultAlpha(
            PlaybackTheme.subtitleFocusCueUnselectedNative,
            appearanceName: .darkAqua
        ) == 0.34
    )
}

@MainActor
@Test
func playbackCueResultPrimaryOnlyUsesCurrentTypographyAndEveryVisualLine() {
    let layout = PlaybackCueResultLayout()

    for (text, expectedLines, expectedNaturalHeight) in [
        ("one", 1, CGFloat(76)),
        ("one\ntwo", 2, CGFloat(128)),
        ("one\r\ntwo", 2, CGFloat(128)),
        ("one\n", 2, CGFloat(128)),
        ("", 1, CGFloat(76)),
    ] {
        let plan = layout.prepare(
            result: playbackCueResult(primaryText: text),
            showsCueGroup: false,
            isSelected: true,
            width: 2_000,
            viewportHeight: 2_000
        )
        #expect(plan.visualLinePlan.visualLineCount == expectedLines)
        #expect(
            plan.visualLinePlan.nominalContentHeight
                == CGFloat(expectedLines) * 52
        )
        #expect(plan.extent.naturalHeight == expectedNaturalHeight)
        #expect(plan.visualLines.allSatisfy { $0.role == .primaryCue })
        playbackCueResultExpectStrictFivePointGaps(plan)
    }

    let wrapped = layout.prepare(
        result: playbackCueResult(
            primaryText: Array(repeating: "wrap", count: 40).joined(separator: " ")
        ),
        showsCueGroup: false,
        isSelected: true,
        width: 120,
        viewportHeight: 10_000
    )
    #expect(wrapped.visualLines.count > 3)
    #expect(
        wrapped.visualLinePlan.nominalContentHeight
            == CGFloat(wrapped.visualLines.count) * 52
    )
    playbackCueResultExpectStrictFivePointGaps(wrapped)
}

@MainActor
@Test
func playbackCueResultFlattensMixedCueGroupIntoOneStrictStack() {
    let layout = PlaybackCueResultLayout()
    let plan = layout.prepare(
        result: playbackCueResult(
            primaryText: "primary",
            additionalTexts: ["first", "second"]
        ),
        showsCueGroup: true,
        isSelected: true,
        width: 2_000,
        viewportHeight: 2_000
    )

    #expect(plan.visualLines.map(\.role) == [
        .primaryCue,
        .additionalCue(index: 0),
        .additionalCue(index: 1),
    ])
    #expect(plan.visualLinePlan.nominalContentHeight == CGFloat(38 + 38 + 52))
    #expect(plan.extent.naturalHeight == 152)
    playbackCueResultExpectStrictFivePointGaps(plan)
}

@MainActor
@Test
func playbackCueResultKeepsFivePointGapAcrossGroupHardSoftAndCueBoundaries() {
    let layout = PlaybackCueResultLayout()
    let plan = layout.prepare(
        result: playbackCueResult(
            primaryText: "primary",
            additionalTexts: [
                "hard line\n"
                    + Array(repeating: "wrapped", count: 16).joined(separator: " "),
                "next additional",
            ]
        ),
        showsCueGroup: true,
        isSelected: true,
        width: 160,
        viewportHeight: 10_000
    )

    #expect(
        plan.visualLines.filter { $0.role == .additionalCue(index: 0) }.count > 2
    )
    #expect(plan.visualLines.contains { $0.role == .additionalCue(index: 1) })
    #expect(plan.visualLines.first?.role == .primaryCue)
    playbackCueResultExpectStrictFivePointGaps(plan)
}

@MainActor
@Test
func playbackCueResultPreservesRoleAwareEmptyAndTrailingLines() {
    let layout = PlaybackCueResultLayout()
    let plan = layout.prepare(
        result: playbackCueResult(
            primaryText: "primary\n",
            additionalTexts: ["first\n", ""]
        ),
        showsCueGroup: true,
        isSelected: true,
        width: 2_000,
        viewportHeight: 2_000
    )

    #expect(plan.visualLines.map(\.role) == [
        .primaryCue,
        .primaryCue,
        .additionalCue(index: 0),
        .additionalCue(index: 0),
        .additionalCue(index: 1),
    ])
    #expect(plan.visualLines.map(\.line.nominalLineHeight) == [52, 52, 38, 38, 38])
    #expect(plan.visualLinePlan.nominalContentHeight == 218)
    #expect(plan.extent.naturalHeight == 242)
    playbackCueResultExpectStrictFivePointGaps(plan)
}

@MainActor
@Test
func playbackCueResultUsesMixedResolvedFontRunsAndDocumentedColors() throws {
    let layout = PlaybackCueResultLayout()
    let selected = layout.prepare(
        result: playbackCueResult(
            primaryText: "矛盾しない 😀",
            additionalTexts: ["ภาษาไทย"]
        ),
        showsCueGroup: true,
        isSelected: true,
        width: 2_000,
        viewportHeight: 2_000
    )
    let selectedGroup = try #require(
        selected.visualLines.first { $0.style == .cueGroup }
    )
    let selectedPrimary = try #require(selected.primaryFirstVisualLine)

    #expect(selectedGroup.style == .cueGroup)
    #expect(selectedGroup.style.font.pointSize == 28)
    #expect(playbackCueResultAlpha(selectedGroup.color) == 0.62)
    #expect(selectedPrimary.style == .primary)
    #expect(selectedPrimary.style.font.pointSize == 40)
    #expect(playbackCueResultAlpha(selectedPrimary.color) == 0.94)
    #expect(selectedGroup.line.typographicHeight > 0)
    #expect(selectedPrimary.line.typographicHeight > 0)
    #expect(
        abs(
            selectedPrimary.typographicTop
                - max(
                    0,
                    (
                        selected.visualLinePlan.resolvedContentHeight
                            - selected.visualLinePlan.stackHeight
                    ) / 2
                )
        ) < 0.000_001
    )
    #expect(
        selected.visualLinePlan.resolvedContentHeight
            == max(
                selected.visualLinePlan.nominalContentHeight,
                selected.visualLinePlan.stackHeight
            )
    )

    let unselected = layout.prepare(
        result: playbackCueResult(
            primaryText: "矛盾しない 😀",
            additionalTexts: ["ภาษาไทย"]
        ),
        showsCueGroup: true,
        isSelected: false,
        width: 2_000,
        viewportHeight: 2_000
    )
    #expect(unselected.visualLines.allSatisfy {
        playbackCueResultAlpha($0.color) == 0.34
    })
    playbackCueResultExpectStrictFivePointGaps(unselected)
}

@MainActor
@Test
func playbackCueResultShowCueGroupDoesNotChangeEitherStableIdentity() {
    let layout = PlaybackCueResultLayout()
    let result = playbackCueResult(
        itemID: "playlist-entry-7",
        primaryIdentity: "cue-42",
        primaryText: "primary",
        additionalTexts: ["context"]
    )
    let hidden = layout.prepare(
        result: result,
        showsCueGroup: false,
        isSelected: true,
        width: 800,
        viewportHeight: 800
    )
    let shown = layout.prepare(
        result: result,
        showsCueGroup: true,
        isSelected: true,
        width: 800,
        viewportHeight: 800
    )

    #expect(hidden.itemID == shown.itemID)
    #expect(hidden.primaryCueIdentity == shown.primaryCueIdentity)
    #expect(hidden.visualLines.map(\.role) == [.primaryCue])
    #expect(shown.visualLines.map(\.role) == [.primaryCue, .additionalCue(index: 0)])
    #expect(shown.extent.naturalHeight > hidden.extent.naturalHeight)

    let duplicateOccurrence = playbackCueResult(
        itemID: "playlist-entry-8",
        primaryIdentity: "cue-42",
        primaryText: "primary"
    )
    #expect(duplicateOccurrence.itemID != result.itemID)
    #expect(duplicateOccurrence.primaryCueIdentity == result.primaryCueIdentity)
}

@MainActor
@Test
func playbackCueResultShowsSelectedInformationBadgesAbovePrimaryCue() throws {
    let layout = PlaybackCueResultLayout()
    let result = playbackCueResult(
        primaryText: Array(repeating: "wide", count: 12).joined(separator: " "),
        additionalTexts: ["context"],
        informationBadges: [
            "[7/1000]",
            "A Very Long Display Title",
            "21:33 - 21:40",
        ]
    )
    let plan = layout.prepare(
        result: result,
        showsCueGroup: true,
        isSelected: true,
        width: 240,
        viewportHeight: 2_000
    )
    let badgeRects = plan.informationBadgeRects(
        in: CGRect(x: 0, y: 0, width: 240, height: plan.extent.naturalHeight)
    )

    #expect(plan.cueTextWidth == 240)
    #expect(plan.informationBadges.map(\.text) == [
        "[7/1000]",
        "A Very Long Display Title",
        "21:33 - 21:40",
    ])
    #expect(badgeRects.count == 3)
    #expect(badgeRects.first?.minY == PlaybackSubtitleFocusMetrics.cueVerticalPadding)
    #expect(badgeRects.last?.maxX ?? .infinity <= 240)
    #expect(plan.cueTextRect(
        in: CGRect(x: 0, y: 0, width: 240, height: plan.extent.naturalHeight)
    ).minY == PlaybackSubtitleFocusMetrics.cueVerticalPadding
        + plan.informationRowHeight
        + PlaybackSubtitleFocusMetrics.informationCueGap)
    #expect(plan.visualLines.first?.role == .primaryCue)

    let unselected = layout.prepare(
        result: result,
        showsCueGroup: true,
        isSelected: false,
        width: 240,
        viewportHeight: 2_000
    )
    #expect(unselected.informationBadges.isEmpty)
    #expect(unselected.extent.naturalHeight < plan.extent.naturalHeight)
}

@MainActor
@Test
func playbackCueResultOversizedExtentStartsAtFirstLineAndClipsOnlyBottom() throws {
    let layout = PlaybackCueResultLayout()
    let plan = layout.prepare(
        result: playbackCueResult(
            primaryText: "primary",
            additionalTexts: [(1...12).map { "line \($0)" }.joined(separator: "\n")],
            informationBadges: ["Display Title", "21:33 - 21:40"]
        ),
        showsCueGroup: true,
        isSelected: true,
        width: 800,
        viewportHeight: 100
    )
    let resultRect = CGRect(x: 0, y: 0, width: 800, height: 100)
    let fullRects = plan.typographicRects(in: resultRect)
    let visibleRects = plan.visibleTypographicRects(in: resultRect)
    let firstFull = try #require(fullRects.first)
    let firstVisible = try #require(visibleRects.first)

    #expect(plan.extent.naturalHeight > 100)
    #expect(plan.extent.resolvedHeight == 100)
    #expect(plan.extent.isOversized)
    #expect(
        firstFull.minY >= PlaybackSubtitleFocusMetrics.cueVerticalPadding
            + plan.informationRowHeight
            + PlaybackSubtitleFocusMetrics.informationCueGap
    )
    #expect(firstVisible.minY == firstFull.minY)
    #expect(visibleRects.count < fullRects.count)
    #expect(visibleRects.allSatisfy { resultRect.contains($0) })
    #expect(plan.informationBadges.count == 2)
}

@MainActor
@Test
func playbackCueResultMeasurementCacheKeysGeometryAndStaysBounded() {
    let cache = PlaybackCueResultMeasurementCache(capacity: 2)
    let base = playbackCueResult(
        informationBadges: ["Display Title", "21:33 - 21:40"]
    )

    let unselectedExtent = cache.extent(
        for: base,
        showsCueGroup: true,
        isSelected: false,
        width: 800,
        viewportHeight: 600
    )
    let selectedExtent = cache.extent(
        for: base,
        showsCueGroup: true,
        isSelected: true,
        width: 800,
        viewportHeight: 600
    )
    #expect(cache.measurementCount == 1)
    #expect(cache.count == 1)
    #expect(
        selectedExtent.naturalHeight - unselectedExtent.naturalHeight
            == PlaybackSubtitleFocusMetrics.selectedInformationHeight
    )

    _ = cache.extent(
        for: playbackCueResult(
            informationBadges: ["Changed Title", "00:00 - 00:01"]
        ),
        showsCueGroup: true,
        isSelected: true,
        width: 800,
        viewportHeight: 600
    )
    #expect(cache.measurementCount == 1)
    #expect(cache.count == 1)

    _ = cache.extent(
        for: base,
        showsCueGroup: false,
        width: 800,
        viewportHeight: 600
    )
    _ = cache.extent(
        for: base,
        showsCueGroup: true,
        width: 700,
        viewportHeight: 600
    )
    #expect(cache.measurementCount == 3)
    #expect(cache.count == 2)

    _ = cache.extent(
        for: base,
        showsCueGroup: true,
        width: 700,
        viewportHeight: 500
    )
    _ = cache.extent(
        for: playbackCueResult(),
        showsCueGroup: true,
        width: 700,
        viewportHeight: 500
    )
    _ = cache.extent(
        for: playbackCueResult(
            primaryText: "replacement"
        ),
        showsCueGroup: true,
        width: 700,
        viewportHeight: 500
    )
    _ = cache.extent(
        for: playbackCueResult(
            additionalTexts: ["replacement context"]
        ),
        showsCueGroup: true,
        width: 700,
        viewportHeight: 500
    )
    #expect(cache.measurementCount == 6)
    #expect(cache.count == 2)

    _ = cache.extent(
        for: playbackCueResult(
            itemID: "other",
            primaryIdentity: "cue-other",
            primaryText: "other"
        ),
        showsCueGroup: true,
        width: 700,
        viewportHeight: 600
    )
    #expect(cache.measurementCount == 7)
    #expect(cache.count == 2)
    cache.removeAll()
    #expect(cache.count == 0)
}

@MainActor
@Test
func playbackCueResultUsesSharedVirtualReelWithoutFullDatasetLayout() throws {
    let adapter = PlaybackCueResultTestAdapter(totalCount: 50_000)
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 25_000,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    let selected = try #require(
        view.placementsForTesting.first { $0.ordinal == 25_000 }
    )
    #expect(selected.itemID == AnyHashable("result-25000"))
    #expect(abs(selected.rect.midY - 328) < 0.001)
    #expect(adapter.measuredOrdinalsForTesting.count < 50)
    #expect(adapter.measurementCacheCountForTesting <= 64)
    #expect(view.placementsForTesting.count < 50)
    view.invalidate()
}

private func playbackCueResult(
    itemID: AnyHashable = "result-1",
    primaryIdentity: AnyHashable = "cue-1",
    primaryText: String = "primary",
    additionalTexts: [String] = ["context"],
    informationBadges: [String] = []
) -> PlaybackCueResult {
    PlaybackCueResult(
        itemID: itemID,
        primaryCueIdentity: primaryIdentity,
        primaryCueText: primaryText,
        additionalCueTexts: additionalTexts,
        informationBadges: informationBadges
    )
}

private func playbackCueResultAlpha(
    _ color: NSColor,
    appearanceName: NSAppearance.Name = .darkAqua
) -> CGFloat {
    playbackCueResultColor(
        color,
        appearanceName: appearanceName
    )?.alphaComponent ?? -1
}

private func playbackCueResultHex(
    _ color: NSColor,
    appearanceName: NSAppearance.Name
) -> String {
    guard let resolved = playbackCueResultColor(
        color,
        appearanceName: appearanceName
    ) else {
        return ""
    }
    return String(
        format: "#%02X%02X%02X",
        Int((resolved.redComponent * 255).rounded()),
        Int((resolved.greenComponent * 255).rounded()),
        Int((resolved.blueComponent * 255).rounded())
    )
}

private func playbackCueResultColor(
    _ color: NSColor,
    appearanceName: NSAppearance.Name
) -> NSColor? {
    var resolved: NSColor?
    NSAppearance(named: appearanceName)?.performAsCurrentDrawingAppearance {
        resolved = color.usingColorSpace(.sRGB)
    }
    return resolved
}

private func playbackCueResultExpectStrictFivePointGaps(
    _ plan: PlaybackCueResultLayoutPlan
) {
    for (previous, next) in zip(
        plan.visualLines,
        plan.visualLines.dropFirst()
    ) {
        #expect(
            abs(
                next.typographicTop
                    - previous.typographicBottom
                    - PlaybackSubtitleFocusMetrics.internalLineGap
            ) < 0.000_001
        )
    }
}

@MainActor
private final class PlaybackCueResultTestAdapter:
    PlaybackVirtualReelContentAdapter
{
    let snapshot: PlaybackVirtualReelSnapshot
    private let cache = PlaybackCueResultMeasurementCache()
    private let layout = PlaybackCueResultLayout()
    private(set) var measuredOrdinalsForTesting: Set<Int> = []

    init(totalCount: Int) {
        snapshot = PlaybackVirtualReelSnapshot(
            datasetID: AnyHashable("result-test"),
            generation: 1,
            revision: 1,
            totalCount: totalCount,
            loadedOrdinalRange: 0..<totalCount,
            loadedItemCount: totalCount,
            isComplete: true
        )
    }

    var measurementCacheCountForTesting: Int {
        cache.count
    }

    func itemID(at ordinal: Int) -> AnyHashable? {
        guard snapshot.loadedOrdinalRange.contains(ordinal) else {
            return nil
        }
        return AnyHashable("result-\(ordinal)")
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
        measuredOrdinalsForTesting.insert(ordinal)
        return cache.extent(
            for: result(at: ordinal),
            showsCueGroup: true,
            isSelected: isSelected,
            width: contentWidth,
            viewportHeight: viewportHeight,
            uiProbeScope: uiProbeScope
        )
    }

    func drawItem(at ordinal: Int, isSelected: Bool, in rect: CGRect) {
        guard snapshot.loadedOrdinalRange.contains(ordinal) else {
            return
        }
        layout.prepare(
            result: result(at: ordinal),
            showsCueGroup: true,
            isSelected: isSelected,
            width: rect.width,
            viewportHeight: rect.height
        )
        layout.drawPreparedPlan(in: rect)
    }

    func invalidateMeasurements() {
        cache.removeAll()
        measuredOrdinalsForTesting.removeAll(keepingCapacity: false)
    }

    func invalidate() {
        invalidateMeasurements()
    }

    private func result(at ordinal: Int) -> PlaybackCueResult {
        PlaybackCueResult(
            itemID: AnyHashable("result-\(ordinal)"),
            primaryCueIdentity: AnyHashable("cue-\(ordinal)"),
            primaryCueText: "primary \(ordinal)",
            additionalCueTexts: ordinal.isMultiple(of: 3)
                ? ["context \(ordinal)"]
                : [],
            informationBadges: [
                "[\(ordinal + 1)/\(snapshot.totalCount)]",
                "Display Title \(ordinal)",
                "00:00 - 00:01",
            ]
        )
    }
}
