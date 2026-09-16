import AppKit
import Testing
@testable import CueSeekerApp

@Test
func playbackCueResultMetricsMatchCompactIteration() {
    #expect(PlaybackSubtitleFocusMetrics.cueVerticalPadding == 8)
    #expect(PlaybackSubtitleFocusMetrics.cueGap == 8)
    #expect(PlaybackSubtitleFocusMetrics.internalLineGap == 3)
    #expect(PlaybackSubtitleFocusMetrics.cueFontSize == 24)
    #expect(PlaybackSubtitleFocusMetrics.cueLineHeight == 32)
    #expect(PlaybackSubtitleFocusMetrics.cueFontWeight == .semibold)
    #expect(PlaybackSubtitleFocusMetrics.cueGroupFontSize == 20)
    #expect(PlaybackSubtitleFocusMetrics.cueGroupLineHeight == 28)
    #expect(PlaybackSubtitleFocusMetrics.cueGroupFontWeight == .medium)
    #expect(PlaybackSubtitleFocusMetrics.metadataCueGap == 8)
    #expect(PlaybackSubtitleFocusMetrics.metadataItemGap == 12)
    #expect(PlaybackSubtitleFocusMetrics.metadataFontSize == 12)
    #expect(PlaybackSubtitleFocusMetrics.metadataFontWeight == .regular)
    #expect(PlaybackSubtitleFocusMetrics.metadataLineHeight == 16)
    #expect(PlaybackSubtitleFocusMetrics.metadataHeight == 24)
    #expect(
        playbackCueResultAlpha(
            PlaybackTheme.subtitleFocusCueSelectedNative
        ) == 0.88
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
            PlaybackTheme.cueTimelineFocusedNative,
            appearanceName: .aqua
        ) == "#667085"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.cueTimelineMutedNative,
            appearanceName: .aqua
        ) == "#D0D5DD"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.cueMetadataNative,
            appearanceName: .aqua
        ) == "#667085"
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
        ) == 0.88
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
    #expect(
        playbackCueResultHex(
            PlaybackTheme.cueTimelineFocusedNative,
            appearanceName: .darkAqua
        ) == "#71717A"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.cueTimelineMutedNative,
            appearanceName: .darkAqua
        ) == "#52525B"
    )
    #expect(
        playbackCueResultHex(
            PlaybackTheme.cueMetadataNative,
            appearanceName: .darkAqua
        ) == "#A1A1AA"
    )
}

@MainActor
@Test
func editingCollageCheckboxMatchesSearchColorsAndFlatRendering() throws {
    for (isSelected, isEnabled, lightHex, darkHex) in [
        (true, true, "#667085", "#A1A1AA"),
        (false, true, "#D0D5DD", "#5A5A62"),
        (true, false, "#9A9A9A", "#606060"),
        (false, false, "#9A9A9A", "#606060"),
    ] {
        let color = PlaybackCollageCheckboxDrawing.color(
            isSelected: isSelected,
            isEnabled: isEnabled
        )
        #expect(
            color === WorkbenchCheckboxStyle.controlColor(
                for: isSelected ? .checked : .unchecked,
                isEnabled: isEnabled
            )
        )
        #expect(playbackCueResultHex(color, appearanceName: .aqua) == lightHex)
        #expect(playbackCueResultHex(color, appearanceName: .darkAqua) == darkHex)

        let image = try #require(PlaybackCollageCheckboxDrawing.image(
            isSelected: isSelected,
            isEnabled: isEnabled
        ))
        // The glyph arrives already filled with the colour checked above, so
        // the drawing carries no tint of its own.
        #expect(
            image.size == NSSize(
                width: PlaybackCollageSelectionMetrics.checkboxSize,
                height: PlaybackCollageSelectionMetrics.checkboxSize
            )
        )
        #expect(image.isTemplate == false)
    }
}

@MainActor
@Test
func playbackCueResultPrimaryOnlyUsesCurrentTypographyAndEveryVisualLine() {
    let layout = PlaybackCueResultLayout()

    for (text, expectedLines, expectedNaturalHeight) in [
        ("one", 1, CGFloat(48)),
        ("one\ntwo", 2, CGFloat(80)),
        ("one\r\ntwo", 2, CGFloat(80)),
        ("one\n", 2, CGFloat(80)),
        ("", 1, CGFloat(48)),
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
                == CGFloat(expectedLines) * 32
        )
        #expect(plan.extent.naturalHeight == expectedNaturalHeight)
        #expect(plan.visualLines.allSatisfy { $0.role == .primaryCue })
        playbackCueResultExpectStrictThreePointGaps(plan)
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
            == CGFloat(wrapped.visualLines.count) * 32
    )
    playbackCueResultExpectStrictThreePointGaps(wrapped)
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
    #expect(plan.visualLinePlan.nominalContentHeight == CGFloat(28 + 28 + 32))
    #expect(plan.extent.naturalHeight == 104)
    playbackCueResultExpectStrictThreePointGaps(plan)
}

@MainActor
@Test
func playbackCueResultSelectionCannotCrossCueOrSourceLineBreak() throws {
    let layout = PlaybackCueResultLayout()
    let resultRect = CGRect(x: 0, y: 0, width: 800, height: 160)
    let plan = layout.prepare(
        result: playbackCueResult(
            primaryText: "primary",
            additionalTexts: ["context"]
        ),
        showsCueGroup: true,
        isSelected: false,
        width: resultRect.width,
        viewportHeight: resultRect.height
    )
    let lineRects = plan.visibleTypographicRects(in: resultRect)
    let primaryRect = try #require(lineRects.first)
    let contextRect = try #require(lineRects.last)
    let anchor = try #require(layout.textSelectionHit(
        at: CGPoint(x: primaryRect.minX + 1, y: primaryRect.midY),
        in: resultRect
    ))
    let focus = try #require(layout.textSelectionHit(
        at: CGPoint(x: primaryRect.maxX + 20, y: contextRect.midY),
        in: resultRect,
        constrainedToLine: anchor.lineUTF16Range
    ))
    let range = NSRange(
        location: min(anchor.utf16Offset, focus.utf16Offset),
        length: abs(focus.utf16Offset - anchor.utf16Offset)
    )

    #expect(focus.lineUTF16Range == anchor.lineUTF16Range)
    #expect(layout.selectedText(forUTF16Range: range) == "primary")
}

@MainActor
@Test
func playbackCueResultKeepsThreePointGapAcrossGroupHardSoftAndCueBoundaries() {
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
    playbackCueResultExpectStrictThreePointGaps(plan)
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
    #expect(plan.visualLines.map(\.line.nominalLineHeight) == [32, 32, 28, 28, 28])
    #expect(plan.visualLinePlan.nominalContentHeight == 148)
    #expect(plan.extent.naturalHeight == 164)
    playbackCueResultExpectStrictThreePointGaps(plan)
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
    #expect(selectedGroup.style.font.pointSize == 20)
    #expect(playbackCueResultAlpha(selectedGroup.color) == 0.62)
    #expect(selectedPrimary.style == .primary)
    #expect(
        selected.extent.firstVisualLineCenterOffset
            == PlaybackSubtitleFocusMetrics.cueVerticalPadding
                + selectedPrimary.line.visibleCenterY
    )
    #expect(
        selected.extent.firstVisualLineCenterOffset
            != PlaybackSubtitleFocusMetrics.cueVerticalPadding
                + PlaybackSubtitleFocusMetrics.cueLineHeight / 2
    )
    #expect(selectedPrimary.style.font.pointSize == 24)
    #expect(playbackCueResultAlpha(selectedPrimary.color) == 0.88)
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
    playbackCueResultExpectStrictThreePointGaps(unselected)
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
func playbackCueResultShowsPlainMetadataBelowEntireCueGroup() throws {
    let layout = PlaybackCueResultLayout()
    let result = playbackCueResult(
        primaryText: Array(repeating: "wide", count: 12).joined(separator: " "),
        additionalTexts: ["context"],
        metadata: PlaybackCueMetadata(
            displayTitle: "A Very Long Display Title",
            timeRange: "21:33 - 21:40"
        )
    )
    let plan = layout.prepare(
        result: result,
        showsCueGroup: true,
        isSelected: true,
        width: 240,
        viewportHeight: 2_000
    )
    let resultRect = CGRect(
        x: 0,
        y: 0,
        width: 240,
        height: plan.extent.naturalHeight
    )
    let metadataRect = try #require(plan.metadataRect(in: resultRect))
    let lastCueRect = try #require(plan.typographicRects(in: resultRect).last)

    #expect(plan.cueTextWidth == 240)
    #expect(plan.metadata?.displayTitle == "A Very Long Display Title")
    #expect(plan.metadata?.timeRange == "21:33 - 21:40")
    #expect(metadataRect.minY >= lastCueRect.maxY)
    #expect(metadataRect.maxX <= 240)
    #expect(plan.cueTextRect(
        in: resultRect
    ).minY == PlaybackSubtitleFocusMetrics.cueVerticalPadding)
    #expect(plan.visualLines.first?.role == .primaryCue)

    let unselected = layout.prepare(
        result: result,
        showsCueGroup: true,
        isSelected: false,
        width: 240,
        viewportHeight: 2_000
    )
    #expect(unselected.metadata == plan.metadata)
    #expect(unselected.extent == plan.extent)
    #expect(plan.isSelected)
    #expect(!unselected.isSelected)

    let wideMetadata = try #require(PlaybackCueMetadataLayout.makePlan(
        metadata: result.metadata,
        width: 800
    ))
    #expect(
        wideMetadata.timeRangeFrame.minX
            == wideMetadata.displayTitleFrame.maxX
                + PlaybackSubtitleFocusMetrics.metadataItemGap
    )
    #expect(wideMetadata.timeRangeFrame.maxX < 800)
    #expect(wideMetadata.ordinalText.isEmpty)
    #expect(wideMetadata.ordinalFrame.width == 0)
    #expect(wideMetadata.displayTitleFrame.minX == 0)
}

@MainActor
@Test
func playbackCueResultMetadataLeadsWithOrdinalAndKeepsSharedItemGap() throws {
    let metadata = PlaybackCueMetadata(
        ordinal: 237,
        displayTitle: "Fate Stay Night - 02",
        timeRange: "07:29 - 07:31"
    )
    #expect(metadata.ordinalText == "#238")

    let wide = try #require(PlaybackCueMetadataLayout.makePlan(
        metadata: metadata,
        width: 800
    ))
    #expect(wide.ordinalText == "#238")
    #expect(wide.ordinalFrame.minX == 0)
    #expect(wide.ordinalFrame.width > 0)
    #expect(
        wide.displayTitleFrame.minX
            == wide.ordinalFrame.maxX
                + PlaybackSubtitleFocusMetrics.metadataItemGap
    )
    #expect(
        wide.timeRangeFrame.minX
            == wide.displayTitleFrame.maxX
                + PlaybackSubtitleFocusMetrics.metadataItemGap
    )
    #expect(wide.timeRangeFrame.maxX <= 800)

    // The ordinal and the time range survive a narrow row; only the display
    // title gives up width.
    let narrow = try #require(PlaybackCueMetadataLayout.makePlan(
        metadata: metadata,
        width: 160
    ))
    #expect(narrow.ordinalFrame.width == wide.ordinalFrame.width)
    #expect(narrow.timeRangeFrame.width == wide.timeRangeFrame.width)
    #expect(narrow.displayTitleFrame.width < wide.displayTitleFrame.width)
    #expect(narrow.timeRangeFrame.maxX <= 160)

    // Current and Editing Collage keep an ordinal-free metadata row.
    let withoutOrdinal = try #require(PlaybackCueMetadataLayout.makePlan(
        metadata: PlaybackCueMetadata(
            displayTitle: "Fate Stay Night - 02",
            timeRange: "07:29 - 07:31"
        ),
        width: 800
    ))
    #expect(withoutOrdinal.ordinalText.isEmpty)
    #expect(withoutOrdinal.displayTitleFrame.minX == 0)
}

@MainActor
@Test
func playbackCueResultOversizedExtentStartsAtFirstLineAndClipsOnlyBottom() throws {
    let layout = PlaybackCueResultLayout()
    let plan = layout.prepare(
        result: playbackCueResult(
            primaryText: "primary",
            additionalTexts: [(1...12).map { "line \($0)" }.joined(separator: "\n")],
            metadata: PlaybackCueMetadata(
                displayTitle: "Display Title",
                timeRange: "21:33 - 21:40"
            )
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
    )
    #expect(firstVisible.minY == firstFull.minY)
    #expect(visibleRects.count < fullRects.count)
    #expect(visibleRects.allSatisfy { resultRect.contains($0) })
    #expect(plan.metadata != nil)
    #expect(plan.metadataRect(in: resultRect)?.minY ?? 0 > resultRect.maxY)
}

@MainActor
@Test
func playbackCueResultMeasurementCacheKeysGeometryAndStaysBounded() {
    let cache = PlaybackCueResultMeasurementCache(capacity: 2)
    let base = playbackCueResult(
        metadata: PlaybackCueMetadata(
            displayTitle: "Display Title",
            timeRange: "21:33 - 21:40"
        )
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
    #expect(selectedExtent == unselectedExtent)

    _ = cache.extent(
        for: playbackCueResult(
            metadata: PlaybackCueMetadata(
                displayTitle: "Changed Title",
                timeRange: "00:00 - 00:01"
            )
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
    #expect(cache.measurementCount == 7)
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
    #expect(cache.measurementCount == 8)
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
    metadata: PlaybackCueMetadata? = nil
) -> PlaybackCueResult {
    PlaybackCueResult(
        itemID: itemID,
        primaryCueIdentity: primaryIdentity,
        primaryCueText: primaryText,
        additionalCueTexts: additionalTexts,
        metadata: metadata
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

private func playbackCueResultExpectStrictThreePointGaps(
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

    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        isEnabled _: Bool,
        selectedTextRange _: NSRange?,
        in rect: CGRect
    ) {
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
            metadata: PlaybackCueMetadata(
                displayTitle: "Display Title \(ordinal)",
                timeRange: "00:00 - 00:01"
            )
        )
    }
}
