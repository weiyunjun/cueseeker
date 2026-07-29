import AppKit
import CoreText
import CueSeekerCore
import SwiftUI

enum PlaybackSubtitleFocusScrollSettleDirective: Equatable {
    case none
    case cancel
    case debounce
    case immediate
}

struct PlaybackSubtitleFocusScrollSample: Equatable {
    enum Phase: Equatable {
        case none
        case began
        case changed
        case ended
        case cancelled
    }

    let deltaY: CGFloat
    let isPrecise: Bool
    let phase: Phase
    let momentumPhase: Phase
    let isInside: Bool
}

struct PlaybackVirtualReelItemExtent: Equatable {
    let visualLineCount: Int
    let visualLineStackHeight: CGFloat
    let resolvedContentHeight: CGFloat
    let naturalHeight: CGFloat
    let resolvedHeight: CGFloat
    let isOversized: Bool
}

typealias PlaybackSubtitleFocusCueMeasurement = PlaybackVirtualReelItemExtent

struct PlaybackVirtualReelSnapshot: Equatable {
    let datasetID: AnyHashable
    let generation: UInt64
    let revision: UInt64
    let totalCount: Int
    let loadedOrdinalRange: Range<Int>
    let loadedItemCount: Int
    let isComplete: Bool

    var isValid: Bool {
        totalCount >= 0
            && loadedOrdinalRange.lowerBound >= 0
            && loadedOrdinalRange.upperBound >= loadedOrdinalRange.lowerBound
            && loadedOrdinalRange.upperBound <= totalCount
            && loadedItemCount == loadedOrdinalRange.count
            && (!isComplete || (
                loadedOrdinalRange == 0..<totalCount
                    && loadedItemCount == totalCount
            ))
    }

    func belongsToSameDataset(as other: Self) -> Bool {
        datasetID == other.datasetID && generation == other.generation
    }
}

struct PlaybackVirtualReelSelectionCommit: Equatable {
    let datasetID: AnyHashable
    let generation: UInt64
    let ordinal: Int
}

enum PlaybackVirtualReelWindowRequestReason: Equatable {
    case visible
    case keyboard
    case wheel
    case scrollbar
}

struct PlaybackVirtualReelWindowRequest: Equatable {
    let datasetID: AnyHashable
    let generation: UInt64
    let revision: UInt64
    let targetOrdinal: Int
    let suggestedOrdinalRange: Range<Int>
    let reason: PlaybackVirtualReelWindowRequestReason
}

struct PlaybackVirtualReelWindowPolicy: Equatable {
    static let standard = Self(itemCount: 32, leadingItemCount: 16)

    let itemCount: Int
    let leadingItemCount: Int

    func windowRange(totalCount: Int, targetOrdinal: Int) -> Range<Int> {
        let resolvedTotalCount = max(0, totalCount)
        guard resolvedTotalCount > 0 else {
            return 0..<0
        }
        let count = min(max(1, itemCount), resolvedTotalCount)
        let target = min(max(0, targetOrdinal), resolvedTotalCount - 1)
        let maximumStart = resolvedTotalCount - count
        let start = min(
            max(0, target - max(0, leadingItemCount)),
            maximumStart
        )
        return start..<(start + count)
    }
}

@MainActor
protocol PlaybackVirtualReelContentAdapter: AnyObject {
    var snapshot: PlaybackVirtualReelSnapshot { get }
    var supportsWindowRequests: Bool { get }
    var measurementCacheCountForTesting: Int { get }
    var measuredOrdinalsForTesting: Set<Int> { get }

    func itemID(at ordinal: Int) -> AnyHashable?
    func extent(
        at ordinal: Int,
        isSelected: Bool,
        contentWidth: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String?
    ) -> PlaybackVirtualReelItemExtent?
    func drawItem(at ordinal: Int, isSelected: Bool, in rect: CGRect)
    func requestWindow(_ request: PlaybackVirtualReelWindowRequest)
    func invalidateMeasurements()
    func invalidate()
}

extension PlaybackVirtualReelContentAdapter {
    var supportsWindowRequests: Bool {
        false
    }

    var measurementCacheCountForTesting: Int {
        0
    }

    var measuredOrdinalsForTesting: Set<Int> {
        []
    }

    func requestWindow(_ request: PlaybackVirtualReelWindowRequest) {}
}

struct PlaybackVisualLineStackSegment {
    let text: String
    let font: NSFont
    let color: NSColor
    let nominalLineHeight: CGFloat
}

struct PlaybackVisualLineStackLine: Equatable {
    let segmentIndex: Int
    let nominalLineHeight: CGFloat
    let glyphRange: NSRange
    let usedRect: CGRect
    let originalBaseline: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let typographicTop: CGFloat

    var typographicHeight: CGFloat {
        ascent + descent
    }

    var typographicBottom: CGFloat {
        typographicTop + typographicHeight
    }
}

struct PlaybackVisualLineStackPlan: Equatable {
    let lines: [PlaybackVisualLineStackLine]
    let stackHeight: CGFloat
    let nominalContentHeight: CGFloat
    let resolvedContentHeight: CGFloat

    var visualLineCount: Int {
        lines.count
    }

    func typographicRects(in contentRect: CGRect) -> [CGRect] {
        lines.map { line in
            CGRect(
                x: contentRect.minX + line.usedRect.minX,
                y: contentRect.minY + line.typographicTop,
                width: line.usedRect.width,
                height: line.typographicHeight
            )
        }
    }
}

@MainActor
final class PlaybackVisualLineStackLayout {
    private struct DraftLine {
        let segmentIndex: Int
        let nominalLineHeight: CGFloat
        let glyphRange: NSRange
        let usedRect: CGRect
        let originalBaseline: CGFloat
        let ascent: CGFloat
        let descent: CGFloat

        var typographicHeight: CGFloat {
            ascent + descent
        }
    }

    private static let terminalLineSentinel = "\u{200B}"
    private static let segmentIndexAttribute = NSAttributedString.Key(
        "CueSeeker.PlaybackVisualLineStack.segmentIndex"
    )

    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()
    private(set) var plan = PlaybackVisualLineStackPlan(
        lines: [],
        stackHeight: 0,
        nominalContentHeight: 0,
        resolvedContentHeight: 0
    )

    init() {
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.usesFontLeading = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    @discardableResult
    func prepare(
        text: String,
        color: NSColor,
        width: CGFloat
    ) -> PlaybackVisualLineStackPlan {
        prepare(
            segments: [PlaybackVisualLineStackSegment(
                text: text,
                font: NSFont.systemFont(
                    ofSize: PlaybackSubtitleFocusMetrics.cueFontSize,
                    weight: PlaybackSubtitleFocusMetrics.cueFontWeight
                ),
                color: color,
                nominalLineHeight: PlaybackSubtitleFocusMetrics.cueLineHeight
            )],
            width: width
        )
    }

    @discardableResult
    func prepare(
        segments: [PlaybackVisualLineStackSegment],
        width: CGFloat
    ) -> PlaybackVisualLineStackPlan {
        let resolvedSegments = segments.isEmpty
            ? [PlaybackVisualLineStackSegment(
                text: "",
                font: NSFont.systemFont(
                    ofSize: PlaybackSubtitleFocusMetrics.cueFontSize,
                    weight: PlaybackSubtitleFocusMetrics.cueFontWeight
                ),
                color: .clear,
                nominalLineHeight: PlaybackSubtitleFocusMetrics.cueLineHeight
            )]
            : segments
        let attributedText = Self.attributedText(for: resolvedSegments)

        textStorage.setAttributedString(attributedText)
        textContainer.size = CGSize(
            width: max(1, width),
            height: 1_000_000
        )
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var draftLines: [DraftLine] = []
        layoutManager.enumerateLineFragments(
            forGlyphRange: glyphRange
        ) { [self] lineRect, usedRect, _, lineGlyphRange, _ in
            let characterRange = layoutManager.characterRange(
                forGlyphRange: lineGlyphRange,
                actualGlyphRange: nil
            )
            let segmentIndex = resolvedSegmentIndex(
                for: characterRange,
                segmentCount: resolvedSegments.count
            )
            let segment = resolvedSegments[segmentIndex]
            let metrics = typographicMetrics(
                for: lineGlyphRange,
                fallbackFont: segment.font
            )
            let originalBaseline = lineRect.minY
                + layoutManager.location(forGlyphAt: lineGlyphRange.location).y
            draftLines.append(DraftLine(
                segmentIndex: segmentIndex,
                nominalLineHeight: segment.nominalLineHeight,
                glyphRange: lineGlyphRange,
                usedRect: usedRect,
                originalBaseline: originalBaseline,
                ascent: metrics.ascent,
                descent: metrics.descent
            ))
        }

        if draftLines.isEmpty {
            let segment = resolvedSegments[0]
            let font = segment.font
            draftLines = [DraftLine(
                segmentIndex: 0,
                nominalLineHeight: segment.nominalLineHeight,
                glyphRange: NSRange(location: 0, length: 0),
                usedRect: .zero,
                originalBaseline: font.ascender,
                ascent: font.ascender,
                descent: -font.descender
            )]
        }

        let stackHeight = draftLines.reduce(CGFloat.zero) {
            $0 + $1.typographicHeight
        } + CGFloat(max(0, draftLines.count - 1))
            * PlaybackSubtitleFocusMetrics.internalLineGap
        let nominalContentHeight = draftLines.reduce(CGFloat.zero) {
            $0 + $1.nominalLineHeight
        }
        let resolvedContentHeight = max(nominalContentHeight, stackHeight)
        var nextTop = max(0, (resolvedContentHeight - stackHeight) / 2)
        let resolvedLines = draftLines.map { line in
            defer {
                nextTop += line.typographicHeight
                    + PlaybackSubtitleFocusMetrics.internalLineGap
            }
            return PlaybackVisualLineStackLine(
                segmentIndex: line.segmentIndex,
                nominalLineHeight: line.nominalLineHeight,
                glyphRange: line.glyphRange,
                usedRect: line.usedRect,
                originalBaseline: line.originalBaseline,
                ascent: line.ascent,
                descent: line.descent,
                typographicTop: nextTop
            )
        }

        plan = PlaybackVisualLineStackPlan(
            lines: resolvedLines,
            stackHeight: stackHeight,
            nominalContentHeight: nominalContentHeight,
            resolvedContentHeight: resolvedContentHeight
        )
        return plan
    }

    func drawPreparedPlan(in contentRect: CGRect) {
        guard contentRect.width > 0,
              contentRect.height > 0,
              !plan.lines.isEmpty,
              let context = NSGraphicsContext.current
        else {
            return
        }

        context.saveGraphicsState()
        NSBezierPath(rect: contentRect).addClip()
        for line in plan.lines {
            guard line.glyphRange.length > 0 else {
                continue
            }
            let targetBaseline = contentRect.minY
                + line.typographicTop
                + line.ascent
            layoutManager.drawGlyphs(
                forGlyphRange: line.glyphRange,
                at: CGPoint(
                    x: contentRect.minX,
                    y: targetBaseline - line.originalBaseline
                )
            )
        }
        context.restoreGraphicsState()
    }

    private func typographicMetrics(
        for glyphRange: NSRange,
        fallbackFont: NSFont
    ) -> (ascent: CGFloat, descent: CGFloat) {
        let characterRange = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )
        let metricRange = rangeWithoutLineTerminators(characterRange)
        guard metricRange.length > 0 else {
            return (fallbackFont.ascender, -fallbackFont.descender)
        }

        let attributedLine = textStorage.attributedSubstring(from: metricRange)
        let coreTextLine = CTLineCreateWithAttributedString(attributedLine)
        let runs = CTLineGetGlyphRuns(coreTextLine) as NSArray
        var resolvedAscent: CGFloat = 0
        var resolvedDescent: CGFloat = 0
        for case let run as CTRun in runs {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            _ = CTRunGetTypographicBounds(
                run,
                CFRange(location: 0, length: 0),
                &ascent,
                &descent,
                &leading
            )
            resolvedAscent = max(resolvedAscent, ascent)
            resolvedDescent = max(resolvedDescent, descent)
        }

        guard resolvedAscent > 0 || resolvedDescent > 0 else {
            return (fallbackFont.ascender, -fallbackFont.descender)
        }
        return (resolvedAscent, resolvedDescent)
    }

    private func resolvedSegmentIndex(
        for characterRange: NSRange,
        segmentCount: Int
    ) -> Int {
        guard textStorage.length > 0 else {
            return 0
        }
        let location = min(characterRange.location, textStorage.length - 1)
        let rawIndex = (textStorage.attribute(
            Self.segmentIndexAttribute,
            at: location,
            effectiveRange: nil
        ) as? NSNumber)?.intValue ?? 0
        return min(max(0, rawIndex), max(0, segmentCount - 1))
    }

    private func rangeWithoutLineTerminators(_ range: NSRange) -> NSRange {
        var result = range
        let string = textStorage.string as NSString
        while result.length > 0 {
            let characterRange = string.rangeOfComposedCharacterSequence(
                at: NSMaxRange(result) - 1
            )
            let character = string.substring(with: characterRange)
            guard character == "\n"
                    || character == "\r"
                    || character == Self.terminalLineSentinel
            else {
                break
            }
            result.length = characterRange.location - result.location
        }
        return result
    }

    private static func attributedText(
        for segments: [PlaybackVisualLineStackSegment]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, segment) in segments.enumerated() {
            let normalizedText = normalizedText(segment.text)
            let attributes = attributes(for: segment, segmentIndex: index)
            if !normalizedText.isEmpty {
                result.append(NSAttributedString(
                    string: normalizedText,
                    attributes: attributes
                ))
            }

            if index < segments.count - 1 {
                result.append(NSAttributedString(
                    string: "\n",
                    attributes: attributes
                ))
            } else if normalizedText.isEmpty || normalizedText.hasSuffix("\n") {
                var sentinelAttributes = attributes
                sentinelAttributes[.foregroundColor] = NSColor.clear
                result.append(NSAttributedString(
                    string: terminalLineSentinel,
                    attributes: sentinelAttributes
                ))
            }
        }
        return result
    }

    private static func attributes(
        for segment: PlaybackVisualLineStackSegment,
        segmentIndex: Int
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: segment.font,
            .foregroundColor: segment.color,
            .paragraphStyle: paragraphStyle(
                lineHeight: segment.nominalLineHeight
            ),
            segmentIndexAttribute: NSNumber(value: segmentIndex),
        ]
    }

    private static func paragraphStyle(lineHeight: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.minimumLineHeight = max(0, lineHeight)
        style.maximumLineHeight = max(0, lineHeight)
        style.lineSpacing = 0
        style.paragraphSpacing = 0
        return style
    }

    private static func normalizedText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

@MainActor
final class PlaybackSubtitleFocusCueTextMeasurer {
    private let visualLineLayout = PlaybackVisualLineStackLayout()

    func measurement(
        text: String,
        width: CGFloat,
        viewportHeight: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        let plan = visualLineLayout.prepare(
            text: text,
            color: .white,
            width: width
        )
        let naturalHeight = max(
            PlaybackSubtitleFocusMetrics.minimumNaturalCueHeight,
            plan.resolvedContentHeight
                + PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
        )
        let safeViewportHeight = max(0, viewportHeight)
        return PlaybackSubtitleFocusCueMeasurement(
            visualLineCount: plan.visualLineCount,
            visualLineStackHeight: plan.stackHeight,
            resolvedContentHeight: plan.resolvedContentHeight,
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, safeViewportHeight),
            isOversized: naturalHeight > safeViewportHeight
        )
    }

}

struct PlaybackVirtualReelLayout: Equatable {
    static let overscanItemCount = 4

    let viewportSize: CGSize
    let totalCount: Int
    let focusAnchorY: CGFloat
    let loadedOrdinalRange: Range<Int>
    let fractionalOrdinal: CGFloat

    init(
        viewportSize: CGSize,
        totalCount: Int,
        loadedOrdinalRange: Range<Int>,
        fractionalOrdinal: CGFloat
    ) {
        self.viewportSize = CGSize(
            width: max(0, viewportSize.width),
            height: max(0, viewportSize.height)
        )
        self.totalCount = max(0, totalCount)
        focusAnchorY = self.viewportSize.height / 2
        let lower = min(max(0, loadedOrdinalRange.lowerBound), self.totalCount)
        let upper = min(
            max(lower, loadedOrdinalRange.upperBound),
            self.totalCount
        )
        self.loadedOrdinalRange = lower..<upper
        self.fractionalOrdinal = Self.clampedFractionalOrdinal(
            fractionalOrdinal,
            to: self.loadedOrdinalRange
        )
    }

    var lowerOrdinal: Int {
        guard !loadedOrdinalRange.isEmpty else {
            return 0
        }
        return min(
            loadedOrdinalRange.upperBound - 1,
            max(loadedOrdinalRange.lowerBound, Int(floor(fractionalOrdinal)))
        )
    }

    var upperOrdinal: Int {
        min(max(loadedOrdinalRange.lowerBound, lowerOrdinal + 1), max(
            loadedOrdinalRange.lowerBound,
            loadedOrdinalRange.upperBound - 1
        ))
    }

    var interpolationFraction: CGFloat {
        guard upperOrdinal != lowerOrdinal else {
            return 0
        }
        return fractionalOrdinal - CGFloat(lowerOrdinal)
    }

    var nearestOrdinal: Int {
        guard !loadedOrdinalRange.isEmpty else {
            return 0
        }
        return min(
            loadedOrdinalRange.upperBound - 1,
            max(
                loadedOrdinalRange.lowerBound,
                Int(fractionalOrdinal.rounded())
            )
        )
    }

    func acceptedTop(forResolvedHeight height: CGFloat) -> CGFloat {
        focusAnchorY - max(0, height) / 2
    }

    func adjacentCenterDistance(
        from currentHeight: CGFloat,
        to targetHeight: CGFloat
    ) -> CGFloat {
        max(0, currentHeight) / 2
            + PlaybackSubtitleFocusMetrics.cueGap
            + max(0, targetHeight) / 2
    }

    func lowerCueTop(
        lowerResolvedHeight: CGFloat,
        upperResolvedHeight: CGFloat
    ) -> CGFloat {
        acceptedTop(forResolvedHeight: lowerResolvedHeight)
            - interpolationFraction * adjacentCenterDistance(
                from: lowerResolvedHeight,
                to: upperResolvedHeight
            )
    }

    static func clampedFractionalOrdinal(
        _ value: CGFloat,
        to range: Range<Int>
    ) -> CGFloat {
        guard !range.isEmpty else {
            return 0
        }
        let finiteValue = value.isFinite ? value : CGFloat(range.lowerBound)
        return min(
            CGFloat(range.upperBound - 1),
            max(CGFloat(range.lowerBound), finiteValue)
        )
    }

    var contentWidth: CGFloat {
        max(
            0,
            min(
                PlaybackSubtitleFocusMetrics.contentMaxWidth,
                viewportSize.width - PlaybackSubtitleFocusMetrics.contentInset * 2
            )
        )
    }

}

typealias PlaybackSubtitleFocusVirtualReelLayout = PlaybackVirtualReelLayout

struct PlaybackVirtualReelItemPlacement: Equatable {
    let ordinal: Int
    let itemID: AnyHashable
    let rect: CGRect
    let extent: PlaybackVirtualReelItemExtent

    var measurement: PlaybackVirtualReelItemExtent {
        extent
    }

    var cueID: Int64 {
        itemID.base as? Int64 ?? 0
    }
}

typealias PlaybackSubtitleFocusCuePlacement = PlaybackVirtualReelItemPlacement

@MainActor
private final class PlaybackSubtitleFocusCueMeasurementCache {
    private struct Key: Hashable {
        let cueID: Int64
        let text: String
        let width: CGFloat
        let viewportHeight: CGFloat
        let styleRevision: Int
    }

    private struct Entry {
        let measurement: PlaybackSubtitleFocusCueMeasurement
        let ordinal: Int
        var lastAccess: UInt64
    }

    private let capacity: Int
    private let measurer = PlaybackSubtitleFocusCueTextMeasurer()
    private var entries: [Key: Entry] = [:]
    private var accessSequence: UInt64 = 0
    private(set) var measurementCount = 0

    init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }

    var count: Int {
        entries.count
    }

    var measuredOrdinals: Set<Int> {
        Set(entries.values.map(\.ordinal))
    }

    func measurement(
        for cue: SubtitleFocusCue,
        width: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String? = nil
    ) -> PlaybackSubtitleFocusCueMeasurement {
        accessSequence &+= 1
        let key = Key(
            cueID: cue.id,
            text: cue.text,
            width: width,
            viewportHeight: viewportHeight,
            styleRevision: 2
        )
        if var entry = entries[key] {
            entry.lastAccess = accessSequence
            entries[key] = entry
            return entry.measurement
        }

        let measurement = measurer.measurement(
            text: cue.text,
            width: width,
            viewportHeight: viewportHeight
        )
        measurementCount += 1
        UIInvalidationProbe.count(
            "playback.subtitle_focus.cue_measurement",
            scope: uiProbeScope,
            details: "ordinal=\(cue.ordinal)"
        )
        entries[key] = Entry(
            measurement: measurement,
            ordinal: cue.ordinal,
            lastAccess: accessSequence
        )
        evictIfNeeded()
        return measurement
    }

    func removeAll() {
        entries.removeAll(keepingCapacity: true)
    }

    private func evictIfNeeded() {
        while entries.count > capacity,
              let oldest = entries.min(by: {
                  $0.value.lastAccess < $1.value.lastAccess
              })?.key {
            entries.removeValue(forKey: oldest)
        }
    }
}

@MainActor
final class PlaybackSubtitleFocusCueReelAdapter:
    PlaybackVirtualReelContentAdapter
{
    private struct SnapshotSignature: Equatable {
        let totalCount: Int
        let cueCount: Int
        let firstID: Int64?
        let lastID: Int64?
        let firstOrdinal: Int?
        let lastOrdinal: Int?
        let storageAddress: UInt?

        init(cues: [SubtitleFocusCue], totalCount: Int) {
            self.totalCount = totalCount
            cueCount = cues.count
            firstID = cues.first?.id
            lastID = cues.last?.id
            firstOrdinal = cues.first?.ordinal
            lastOrdinal = cues.last?.ordinal
            storageAddress = cues.withUnsafeBufferPointer { buffer in
                buffer.baseAddress.map { UInt(bitPattern: $0) }
            }
        }
    }

    private struct InformationBadgeKey: Equatable {
        let cueID: Int64
        let displayTitle: String
        let startMilliseconds: Int
        let endMilliseconds: Int
    }

    private struct InformationBadgeTextCache {
        let key: InformationBadgeKey
        let texts: [String]
    }

    private struct InformationBadgePlanCache {
        let key: InformationBadgeKey
        let width: CGFloat
        let plans: [PlaybackCueInformationBadgePlan]
    }

    private let datasetID = AnyHashable("current")
    private let measurementCache = PlaybackSubtitleFocusCueMeasurementCache()
    private let textLayout = PlaybackSubtitleFocusNativeTextLayout()
    private var cues: [SubtitleFocusCue] = []
    private var firstLoadedOrdinal = 0
    private var signature: SnapshotSignature?
    private var revision: UInt64 = 0
    private var displayTitle = ""
    private var informationBadgeTextCache: InformationBadgeTextCache?
    private var informationBadgePlanCache: InformationBadgePlanCache?
    private(set) var informationBadgePlanPreparationCountForTesting = 0
    private(set) var snapshot = PlaybackVirtualReelSnapshot(
        datasetID: AnyHashable("current"),
        generation: 0,
        revision: 0,
        totalCount: 0,
        loadedOrdinalRange: 0..<0,
        loadedItemCount: 0,
        isComplete: true
    )

    var measurementCacheCountForTesting: Int {
        measurementCache.count
    }

    var measuredOrdinalsForTesting: Set<Int> {
        measurementCache.measuredOrdinals
    }

    var measurementCountForTesting: Int {
        measurementCache.measurementCount
    }

    func update(
        cues: [SubtitleFocusCue],
        totalCount: Int,
        displayTitle: String,
        generation: UInt64
    ) {
        let resolvedTotalCount = max(0, totalCount)
        let nextSignature = SnapshotSignature(
            cues: cues,
            totalCount: resolvedTotalCount
        )
        if snapshot.generation != generation {
            revision = 0
            invalidateMeasurements()
        } else if signature != nextSignature || self.displayTitle != displayTitle {
            revision &+= 1
        }
        signature = nextSignature
        self.cues = cues
        self.displayTitle = displayTitle
        firstLoadedOrdinal = cues.first?.ordinal ?? 0
        let loadedOrdinalRange: Range<Int>
        if let firstOrdinal = cues.first?.ordinal,
           let lastOrdinal = cues.last?.ordinal {
            loadedOrdinalRange = firstOrdinal..<(lastOrdinal + 1)
        } else {
            loadedOrdinalRange = 0..<0
        }
        snapshot = PlaybackVirtualReelSnapshot(
            datasetID: datasetID,
            generation: generation,
            revision: revision,
            totalCount: resolvedTotalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            loadedItemCount: cues.count,
            isComplete: cues.count == resolvedTotalCount
                && loadedOrdinalRange == 0..<resolvedTotalCount
        )
    }

    func itemID(at ordinal: Int) -> AnyHashable? {
        cue(at: ordinal).map { AnyHashable($0.id) }
    }

    func extent(
        at ordinal: Int,
        isSelected: Bool,
        contentWidth: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String?
    ) -> PlaybackVirtualReelItemExtent? {
        guard let cue = cue(at: ordinal) else {
            return nil
        }
        let baseMeasurement = measurementCache.measurement(
            for: cue,
            width: contentWidth,
            viewportHeight: viewportHeight,
            uiProbeScope: uiProbeScope
        )
        guard isSelected, !displayTitle.isEmpty else {
            return baseMeasurement
        }
        return addingSelectedInformationHeight(
            to: baseMeasurement,
            viewportHeight: viewportHeight
        )
    }

    func drawItem(at ordinal: Int, isSelected: Bool, in rect: CGRect) {
        guard let cue = cue(at: ordinal) else {
            return
        }
        let badgePlans = isSelected
            ? informationBadgePlans(for: cue, width: rect.width)
            : []
        PlaybackCueInformationBadgeLayout.draw(badgePlans, in: rect)
        let textRect = badgePlans.isEmpty
            ? rect
            : CGRect(
                x: rect.minX,
                y: rect.minY
                    + PlaybackSubtitleFocusMetrics.selectedInformationHeight,
                width: rect.width,
                height: max(
                    0,
                    rect.height
                        - PlaybackSubtitleFocusMetrics.selectedInformationHeight
                )
            )
        textLayout.draw(
            text: cue.text,
            color: isSelected
                ? PlaybackTheme.subtitleFocusCueSelectedNative
                : PlaybackTheme.subtitleFocusCueUnselectedNative,
            in: textRect
        )
    }

    func invalidate() {
        cues.removeAll(keepingCapacity: false)
        firstLoadedOrdinal = 0
        signature = nil
        displayTitle = ""
        informationBadgeTextCache = nil
        informationBadgePlanCache = nil
        informationBadgePlanPreparationCountForTesting = 0
        invalidateMeasurements()
    }

    func invalidateMeasurements() {
        measurementCache.removeAll()
    }

    func informationBadges(at ordinal: Int) -> [String]? {
        cue(at: ordinal).map(informationBadges(for:))
    }

    func informationBadgePlans(
        at ordinal: Int,
        width: CGFloat
    ) -> [PlaybackCueInformationBadgePlan]? {
        cue(at: ordinal).map {
            informationBadgePlans(for: $0, width: width)
        }
    }

    private func cue(at ordinal: Int) -> SubtitleFocusCue? {
        let index = ordinal - firstLoadedOrdinal
        guard cues.indices.contains(index), cues[index].ordinal == ordinal else {
            return nil
        }
        return cues[index]
    }

    private func informationBadges(for cue: SubtitleFocusCue) -> [String] {
        guard !displayTitle.isEmpty else {
            return []
        }
        let key = informationBadgeKey(for: cue)
        if let informationBadgeTextCache,
           informationBadgeTextCache.key == key {
            return informationBadgeTextCache.texts
        }
        let texts = [
            displayTitle,
            PlaybackCueInformationText.timeRange(
                startMilliseconds: cue.startMilliseconds,
                endMilliseconds: cue.endMilliseconds
            ),
        ]
        informationBadgeTextCache = InformationBadgeTextCache(
            key: key,
            texts: texts
        )
        informationBadgePlanCache = nil
        return texts
    }

    private func informationBadgePlans(
        for cue: SubtitleFocusCue,
        width: CGFloat
    ) -> [PlaybackCueInformationBadgePlan] {
        let key = informationBadgeKey(for: cue)
        if let informationBadgePlanCache,
           informationBadgePlanCache.key == key,
           informationBadgePlanCache.width == width {
            return informationBadgePlanCache.plans
        }
        let plans = PlaybackCueInformationBadgeLayout.makePlans(
            texts: informationBadges(for: cue),
            width: width
        )
        informationBadgePlanPreparationCountForTesting += 1
        informationBadgePlanCache = InformationBadgePlanCache(
            key: key,
            width: width,
            plans: plans
        )
        return plans
    }

    private func informationBadgeKey(
        for cue: SubtitleFocusCue
    ) -> InformationBadgeKey {
        InformationBadgeKey(
            cueID: cue.id,
            displayTitle: displayTitle,
            startMilliseconds: cue.startMilliseconds,
            endMilliseconds: cue.endMilliseconds
        )
    }

    private func addingSelectedInformationHeight(
        to base: PlaybackSubtitleFocusCueMeasurement,
        viewportHeight: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        let selectedHeight = PlaybackSubtitleFocusMetrics
            .selectedInformationHeight
        let naturalHeight = base.naturalHeight + selectedHeight
        let safeViewportHeight = max(0, viewportHeight)
        return PlaybackSubtitleFocusCueMeasurement(
            visualLineCount: base.visualLineCount,
            visualLineStackHeight: base.visualLineStackHeight,
            resolvedContentHeight: base.resolvedContentHeight + selectedHeight,
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, safeViewportHeight),
            isOversized: naturalHeight > safeViewportHeight
        )
    }
}

struct PlaybackSubtitleFocusNativeScrollbarMetrics: Equatable {
    let totalCount: Int
    let fractionalOrdinal: CGFloat
    let visibleCueCapacity: Int

    init(
        totalCount: Int,
        fractionalOrdinal: CGFloat,
        visibleCueCapacity: Int
    ) {
        self.totalCount = max(0, totalCount)
        self.fractionalOrdinal = fractionalOrdinal.isFinite
            ? fractionalOrdinal
            : 0
        self.visibleCueCapacity = max(1, visibleCueCapacity)
    }

    var presentation: TableScrollbarPresentation {
        guard totalCount > 0 else {
            return TableScrollbarPresentation()
        }
        let lastOrdinal = max(0, totalCount - 1)
        let boundedOrdinal = min(
            CGFloat(lastOrdinal),
            max(0, fractionalOrdinal)
        )
        return TableScrollbarPresentation(
            vertical: TableScrollbarAxisPresentation(
                visibleFraction: min(
                    1,
                    CGFloat(max(1, visibleCueCapacity)) / CGFloat(totalCount)
                ),
                positionFraction: lastOrdinal > 0
                    ? boundedOrdinal / CGFloat(lastOrdinal)
                    : 0
            )
        )
    }

    func fractionalOrdinal(for positionFraction: CGFloat) -> CGFloat {
        let fraction = positionFraction.isFinite
            ? min(1, max(0, positionFraction))
            : 0
        return fraction * CGFloat(max(0, totalCount - 1))
    }

}

enum PlaybackSubtitleFocusNativeWheelMode: Equatable {
    case none
    case discrete(direction: SubtitleFocusNavigationDirection, stepCount: Int)
    case precise(deltaY: CGFloat, beginsGesture: Bool)
}

struct PlaybackSubtitleFocusNativeWheelOutput: Equatable {
    let shouldConsume: Bool
    let mode: PlaybackSubtitleFocusNativeWheelMode
    let settleDirective: PlaybackSubtitleFocusScrollSettleDirective

    static let passThrough = PlaybackSubtitleFocusNativeWheelOutput(
        shouldConsume: false,
        mode: .none,
        settleDirective: .none
    )

    static let consumedNoop = PlaybackSubtitleFocusNativeWheelOutput(
        shouldConsume: true,
        mode: .none,
        settleDirective: .none
    )
}

struct PlaybackSubtitleFocusNativeWheelState: Equatable {
    private var ownsPreciseGesture = false
    private var awaitsMomentum = false
    private var requiresNewGesture = false

    mutating func consume(
        _ sample: PlaybackSubtitleFocusScrollSample,
        isEnabled: Bool
    ) -> PlaybackSubtitleFocusNativeWheelOutput {
        guard isEnabled else {
            reset(requiresNewGesture: true)
            return .consumedNoop
        }

        let hasNoPhases = sample.phase == .none && sample.momentumPhase == .none
        let isDiscrete = !sample.isPrecise
        if requiresNewGesture {
            let startsFreshGesture = isDiscrete
                || sample.phase == .began
                || (sample.isPrecise && hasNoPhases && sample.isInside)
            guard startsFreshGesture else {
                return .consumedNoop
            }
            requiresNewGesture = false
        }

        if isDiscrete {
            guard sample.isInside else {
                return .passThrough
            }
            guard sample.deltaY.isFinite, sample.deltaY != 0 else {
                return .consumedNoop
            }
            let direction: SubtitleFocusNavigationDirection = sample.deltaY > 0
                ? .backward
                : .forward
            return PlaybackSubtitleFocusNativeWheelOutput(
                shouldConsume: true,
                mode: .discrete(
                    direction: direction,
                    stepCount: max(1, Int(abs(sample.deltaY).rounded(.up)))
                ),
                settleDirective: .none
            )
        }

        if sample.isPrecise && hasNoPhases {
            guard sample.isInside || ownsPreciseGesture else {
                return .passThrough
            }
            let beginsGesture = !ownsPreciseGesture
            ownsPreciseGesture = true
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .debounce
            )
        }

        var beginsGesture = false
        if sample.phase == .began {
            ownsPreciseGesture = sample.isInside
            awaitsMomentum = false
            beginsGesture = ownsPreciseGesture
        } else if sample.momentumPhase == .began, awaitsMomentum {
            ownsPreciseGesture = true
            awaitsMomentum = false
        } else if !ownsPreciseGesture,
                  !awaitsMomentum,
                  sample.phase == .changed,
                  sample.isInside {
            ownsPreciseGesture = true
            beginsGesture = true
        }

        guard ownsPreciseGesture else {
            return .passThrough
        }
        if sample.phase == .cancelled || sample.momentumPhase == .cancelled {
            ownsPreciseGesture = false
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .immediate
            )
        }
        if sample.momentumPhase == .ended {
            ownsPreciseGesture = false
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .immediate
            )
        }
        if sample.momentumPhase == .began {
            ownsPreciseGesture = true
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .cancel
            )
        }
        if sample.phase == .ended {
            ownsPreciseGesture = false
            awaitsMomentum = true
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .debounce
            )
        }
        return preciseOutput(
            sample,
            beginsGesture: beginsGesture,
            settleDirective: .cancel
        )
    }

    mutating func finishPreciseGesture() {
        ownsPreciseGesture = false
        awaitsMomentum = false
    }

    mutating func reset(requiresNewGesture: Bool = false) {
        ownsPreciseGesture = false
        awaitsMomentum = false
        self.requiresNewGesture = requiresNewGesture
    }

    private func preciseOutput(
        _ sample: PlaybackSubtitleFocusScrollSample,
        beginsGesture: Bool,
        settleDirective: PlaybackSubtitleFocusScrollSettleDirective
    ) -> PlaybackSubtitleFocusNativeWheelOutput {
        let deltaY = sample.deltaY.isFinite ? sample.deltaY : 0
        return PlaybackSubtitleFocusNativeWheelOutput(
            shouldConsume: true,
            mode: .precise(
                deltaY: deltaY,
                beginsGesture: beginsGesture
            ),
            settleDirective: settleDirective
        )
    }
}

struct PlaybackSubtitleFocusReelRepresentable: NSViewRepresentable {
    let cues: [SubtitleFocusCue]
    let totalCount: Int
    let selectedOrdinal: Int
    let displayTitle: String
    let contentGeneration: Int
    let uiProbeScope: String?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let reducesMotion: Bool
    let isInteractionEnabled: Bool
    let cancelsWheelMotion: Bool
    let onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool
    let onCommitNativeReelSelection: (Int) -> Bool
    let allowsNativeWheelInput: () -> Bool
    let allowsNativeScrollbarInput: () -> Bool
    let onScrollbarDraggingChanged: (Bool) -> Void
    let onNativeMotionGateChanged: (Bool) -> Void
    let onKeyboardMotionChanged: (Bool) -> Void

    func makeNSView(context: Context) -> PlaybackSubtitleFocusReelContainerView {
        UIInvalidationProbe.count(
            "playback.subtitle_focus.native_make",
            scope: uiProbeScope
        )
        let view = PlaybackSubtitleFocusReelContainerView()
        update(view)
        return view
    }

    func updateNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        context: Context
    ) {
        UIInvalidationProbe.count(
            "playback.subtitle_focus.native_update",
            scope: uiProbeScope
        )
        update(nsView)
    }

    static func dismantleNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        coordinator: Void
    ) {
        nsView.invalidate()
    }

    private func update(_ view: PlaybackSubtitleFocusReelContainerView) {
        view.uiProbeScope = uiProbeScope
        view.onCommitKeyboardNavigation = onCommitKeyboardNavigation
        view.onCommitNativeReelSelection = onCommitNativeReelSelection
        view.allowsNativeWheelInput = allowsNativeWheelInput
        view.allowsNativeScrollbarInput = allowsNativeScrollbarInput
        view.onScrollbarDraggingChanged = onScrollbarDraggingChanged
        view.onNativeMotionGateChanged = onNativeMotionGateChanged
        view.onKeyboardMotionChanged = onKeyboardMotionChanged
        view.update(
            cues: cues,
            totalCount: totalCount,
            selectedOrdinal: selectedOrdinal,
            displayTitle: displayTitle,
            contentGeneration: UInt64(max(0, contentGeneration)),
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion
        )
    }
}

final class PlaybackSubtitleFocusReelContainerView: NSView {
    private struct ContentToken: Equatable {
        let datasetID: AnyHashable
        let generation: UInt64
    }

    private enum PendingWindowSelection: Equatable {
        case keyboard(
            token: ContentToken,
            request: PlaybackSubtitleFocusKeyboardNavigationRequest
        )
        case native(
            token: ContentToken,
            ordinal: Int,
            reason: PlaybackVirtualReelWindowRequestReason
        )
        case restore(token: ContentToken, ordinal: Int)

        var token: ContentToken {
            switch self {
            case .keyboard(let token, _),
                 .native(let token, _, _),
                 .restore(let token, _):
                token
            }
        }

        var ordinal: Int {
            switch self {
            case .keyboard(_, let request):
                request.targetOrdinal
            case .native(_, let ordinal, _):
                ordinal
            case .restore(_, let ordinal):
                ordinal
            }
        }

        var requestReason: PlaybackVirtualReelWindowRequestReason {
            switch self {
            case .keyboard:
                .keyboard
            case .native(_, _, let reason):
                reason
            case .restore:
                .visible
            }
        }
    }

    private struct PendingScrollbarPreview: Equatable {
        let token: ContentToken
        let ordinal: Int
        let fractionalOrdinal: CGFloat
    }

    var uiProbeScope: String? {
        didSet {
            documentView.uiProbeScope = uiProbeScope
        }
    }
    var onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool = {
        _ in false
    }
    var onCommitNativeReelSelection: (Int) -> Bool = { _ in false }
    var onCommitVirtualReelSelection: ((PlaybackVirtualReelSelectionCommit) -> Bool)?
    var allowsNativeWheelInput: () -> Bool = { false }
    var allowsNativeScrollbarInput: () -> Bool = { false }
    var onScrollbarDraggingChanged: (Bool) -> Void = { _ in }
    var onNativeMotionGateChanged: (Bool) -> Void = { _ in }
    var onKeyboardMotionChanged: (Bool) -> Void = { _ in }

    private let scrollView = PlaybackSubtitleFocusNativeScrollView()
    private let documentView = PlaybackSubtitleFocusReelDocumentView()
    private let scrollbarView = PlaybackSubtitleFocusNativeScrollbarView()
    private let currentCueAdapter = PlaybackSubtitleFocusCueReelAdapter()
    private var mountedContentAdapter:
        (any PlaybackVirtualReelContentAdapter)?
    private var contentSnapshot: PlaybackVirtualReelSnapshot?
    private var totalCount = 0
    private var selectedOrdinal: Int?
    private var fractionalOrdinal: CGFloat = 0
    private var hasInitializedPosition = false
    private var loadedOrdinalRange: Range<Int> = 0..<0
    private var isInteractionEnabled = true
    private var reducesMotion = false
    private var hasCompleteItemCollection = false
    private var lastViewportSize: CGSize = .zero
    private var lastHandledKeyboardSequence = 0
    private var lastHandledGeneratedKeyboardToken: ContentToken?
    private var lastHandledGeneratedKeyboardSequence = 0
    private var activeKeyboardRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    private var activeKeyboardContentGeneration: UInt64?
    private var isKeyboardMotionActive = false
    private var activeWheelTargetOrdinal: Int?
    private var activeWheelContentGeneration: UInt64?
    private var pendingWindowSelection: PendingWindowSelection?
    private var pendingScrollbarPreview: PendingScrollbarPreview?
    private var lastWindowRequest: PlaybackVirtualReelWindowRequest?
    private var observedExternalSelectionToken: ContentToken?
    private var observedExternalSelectedOrdinal: Int?
    private var preciseGestureStartOrdinal: Int?
    private var wheelState = PlaybackSubtitleFocusNativeWheelState()
    private var preciseSettleTask: Task<Void, Never>?
    nonisolated(unsafe) private var eventMonitor: Any?
    private var isWheelMotionActive = false
    private var isScrollbarDragging = false
    private var isScrollbarMotionActive = false
    private var reportedNativeMotionActive = false
    private var motionCallbackGeneration = 0
    private var motionCallbackTask: Task<Void, Never>?
    private lazy var keyboardAnimator = PlaybackSubtitleFocusReelPositionAnimator(
        onUpdate: { [weak self] position in
            self?.setFractionalOrdinal(position)
        },
        onCompletion: { [weak self] in
            self?.completeKeyboardMotion()
        }
    )
    private lazy var wheelAnimator = PlaybackSubtitleFocusReelPositionAnimator(
        onUpdate: { [weak self] position in
            self?.setFractionalOrdinal(position)
        },
        onCompletion: { [weak self] in
            self?.completeWheelMotion()
        }
    )

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.documentView = documentView
        addSubview(scrollView)

        scrollbarView.appearanceMode = .inherited
        scrollbarView.presentationProvider = { [weak self] in
            self?.scrollbarMetrics.presentation
        }
        scrollbarView.allowsInteraction = { [weak self] in
            self?.allowsNativeScrollbarInput() == true
        }
        scrollbarView.onDrag = { [weak self] event in
            self?.handleScrollbarDrag(event)
        }
        scrollbarView.onDragStateChanged = { [weak self] isDragging in
            self?.handleScrollbarDraggingChanged(isDragging)
        }
        addSubview(scrollbarView)

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        let nextViewportSize = bounds.size
        if isScrollbarDragging,
           lastViewportSize != .zero,
           nextViewportSize != lastViewportSize {
            cancelActiveScrollbarDrag()
        }
        if lastViewportSize != .zero,
           nextViewportSize != lastViewportSize,
           !hasActiveNativeMotion,
           let selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
        }
        if lastViewportSize != .zero,
           nextViewportSize != lastViewportSize {
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.reflow",
                scope: uiProbeScope,
                details: "width=\(nextViewportSize.width) height=\(nextViewportSize.height)"
            )
        }
        lastViewportSize = nextViewportSize
        scrollView.frame = bounds
        scrollbarView.frame = bounds
        updateDocumentGeometry()
        if !hasActiveNativeMotion {
            synchronizeFractionalOrdinalIfIdle()
        }
        updateScrollbarPresentation()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeEventMonitor()
            resetWheelInteraction(requiresNewGesture: true)
        } else {
            installEventMonitorIfNeeded()
        }
    }

    func update(
        cues: [SubtitleFocusCue],
        totalCount: Int,
        selectedOrdinal: Int,
        displayTitle: String = "",
        contentGeneration: UInt64 = 0,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool,
        isInteractionEnabled: Bool,
        cancelsWheelMotion: Bool
    ) {
        currentCueAdapter.update(
            cues: cues,
            totalCount: totalCount,
            displayTitle: displayTitle,
            generation: contentGeneration
        )
        update(
            contentAdapter: currentCueAdapter,
            selectedOrdinal: selectedOrdinal,
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion
        )
    }

    func update(
        contentAdapter: any PlaybackVirtualReelContentAdapter,
        selectedOrdinal: Int?,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool,
        isInteractionEnabled: Bool,
        cancelsWheelMotion: Bool
    ) {
        let snapshot = contentAdapter.snapshot
        if let contentSnapshot,
           contentSnapshot.datasetID == snapshot.datasetID,
           (snapshot.generation < contentSnapshot.generation
               || (snapshot.generation == contentSnapshot.generation
                   && (
                       snapshot.revision < contentSnapshot.revision
                           || (snapshot.revision == contentSnapshot.revision
                               && snapshot != contentSnapshot)
                           || snapshot.totalCount != contentSnapshot.totalCount
                   ))) {
            rejectIncomingContentAdapter(contentAdapter)
            return
        }
        guard snapshot.isValid else {
            rejectIncomingContentAdapter(contentAdapter)
            return
        }
        let previousSnapshot = contentSnapshot
        let previousContentAdapter = mountedContentAdapter
        let changesDataset = previousSnapshot.map {
            !$0.belongsToSameDataset(as: snapshot)
        } ?? false
        let replacesRequestTransport = previousContentAdapter.map {
            $0 !== contentAdapter
        } ?? false
        let activeTargetOrdinal = activeKeyboardRequest?.targetOrdinal
            ?? activeWheelTargetOrdinal
            ?? preciseGestureStartOrdinal
        let removesActiveTarget = activeTargetOrdinal.map {
            !snapshot.loadedOrdinalRange.contains($0)
        } ?? false
        if changesDataset || removesActiveTarget {
            cancelMotionForContentReplacement()
        }
        if changesDataset {
            contentAdapter.invalidateMeasurements()
            hasInitializedPosition = false
        }
        if previousSnapshot != snapshot || replacesRequestTransport {
            lastWindowRequest = nil
        }
        contentSnapshot = snapshot
        mountedContentAdapter = contentAdapter
        self.totalCount = snapshot.totalCount
        let token = ContentToken(
            datasetID: snapshot.datasetID,
            generation: snapshot.generation
        )
        if let pendingWindowSelection,
           pendingWindowSelection.token != token {
            self.pendingWindowSelection = nil
        }
        if let pendingScrollbarPreview,
           pendingScrollbarPreview.token != token {
            self.pendingScrollbarPreview = nil
        }
        if observeExternalSelection(selectedOrdinal, for: token) {
            supersedePendingWindowIntent()
        }
        if case .restore(_, let ordinal) = pendingWindowSelection,
           resolvedOrdinal(selectedOrdinal, totalCount: snapshot.totalCount)
               != ordinal {
            supersedePendingWindowIntent(clearsScrollbarPreview: false)
        }
        if let pendingWindowSelection,
           !(0..<snapshot.totalCount).contains(pendingWindowSelection.ordinal) {
            supersedePendingWindowIntent(clearsScrollbarPreview: false)
        }
        if let pendingScrollbarPreview,
           (!isScrollbarDragging
               || !(0..<snapshot.totalCount).contains(
                   pendingScrollbarPreview.ordinal
               )) {
            self.pendingScrollbarPreview = nil
        }
        let readyPendingWindowSelection = pendingWindowSelection.flatMap {
            snapshot.loadedOrdinalRange.contains($0.ordinal) ? $0 : nil
        }
        let readyScrollbarPreview = pendingScrollbarPreview.flatMap {
            snapshot.loadedOrdinalRange.contains($0.ordinal) ? $0 : nil
        }
        let previousSelectedOrdinal = self.selectedOrdinal
        let requestedSelectedOrdinal = readyPendingWindowSelection?.ordinal
            ?? selectedOrdinal
        var unloadedRequestedOrdinal: Int?
        if let requestedSelectedOrdinal, snapshot.totalCount > 0 {
            let resolvedSelectedOrdinal = min(
                max(0, requestedSelectedOrdinal),
                snapshot.totalCount - 1
            )
            if snapshot.loadedOrdinalRange.contains(resolvedSelectedOrdinal) {
                self.selectedOrdinal = resolvedSelectedOrdinal
            } else {
                self.selectedOrdinal = nil
                if pendingWindowSelection == nil
                    && pendingScrollbarPreview == nil {
                    unloadedRequestedOrdinal = resolvedSelectedOrdinal
                }
            }
        } else {
            self.selectedOrdinal = nil
        }
        loadedOrdinalRange = snapshot.loadedOrdinalRange
        hasCompleteItemCollection = snapshot.isComplete
        self.reducesMotion = reducesMotion
        let wasInteractionEnabled = self.isInteractionEnabled
        self.isInteractionEnabled = isInteractionEnabled
        if cancelsWheelMotion {
            cancelActiveScrollbarDrag()
            resetWheelInteraction(requiresNewGesture: true)
        } else if wasInteractionEnabled, !isInteractionEnabled {
            suspendWheelInputForSuppression()
        }
        let activeScrollbarPreview = readyScrollbarPreview.flatMap { preview in
            pendingScrollbarPreview == preview && isScrollbarDragging
                ? preview
                : nil
        }
        documentView.updateContent(contentAdapter)
        if let activeScrollbarPreview {
            fractionalOrdinal = activeScrollbarPreview.fractionalOrdinal
            hasInitializedPosition = true
        } else if !hasInitializedPosition,
                  let selectedOrdinal = self.selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
            hasInitializedPosition = true
        } else if previousSelectedOrdinal != self.selectedOrdinal,
                  !hasActiveNativeMotion,
                  let selectedOrdinal = self.selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
        }
        fractionalOrdinal = boundedLoadedFractionalOrdinal(fractionalOrdinal)
        updateDocumentGeometry()
        updateScrollbarPresentation()
        if let activeScrollbarPreview {
            documentView.updateSelection(activeScrollbarPreview.ordinal)
        } else if !hasActiveNativeMotion {
            documentView.updateSelection(self.selectedOrdinal)
            synchronizeFractionalOrdinalIfIdle()
        }
        if let unloadedRequestedOrdinal {
            _ = requestWindow(
                targetOrdinal: unloadedRequestedOrdinal,
                reason: .visible,
                pendingSelection: .restore(
                    token: token,
                    ordinal: unloadedRequestedOrdinal
                )
            )
        }
        handleKeyboardNavigation(
            keyboardNavigationRequest,
            reducesMotion: reducesMotion
        )
        if let readyPendingWindowSelection,
           pendingWindowSelection == readyPendingWindowSelection {
            pendingWindowSelection = nil
            finishPendingWindowSelection(
                readyPendingWindowSelection,
                fallbackSelectedOrdinal: selectedOrdinal
            )
        }
        if let pendingWindowSelection {
            _ = requestWindow(
                targetOrdinal: pendingWindowSelection.ordinal,
                reason: pendingWindowSelection.requestReason,
                pendingSelection: pendingWindowSelection
            )
        }
        if let pendingScrollbarPreview,
           readyScrollbarPreview == nil {
            _ = requestWindow(
                targetOrdinal: pendingScrollbarPreview.ordinal,
                reason: .scrollbar,
                pendingSelection: nil
            )
        }
        requestVisibleWindowIfNeeded()
    }

    private func rejectIncomingContentAdapter(
        _ contentAdapter: any PlaybackVirtualReelContentAdapter
    ) {
        if let mountedContentAdapter,
           mountedContentAdapter === contentAdapter {
            resetForInvalidContent(contentAdapter)
        } else {
            contentAdapter.invalidate()
        }
    }

    private func observeExternalSelection(
        _ ordinal: Int?,
        for token: ContentToken
    ) -> Bool {
        guard observedExternalSelectionToken == token else {
            observedExternalSelectionToken = token
            observedExternalSelectedOrdinal = ordinal
            return false
        }
        let didChange = observedExternalSelectedOrdinal != ordinal
        observedExternalSelectedOrdinal = ordinal
        return didChange
    }

    private func resolvedOrdinal(
        _ ordinal: Int?,
        totalCount: Int
    ) -> Int? {
        guard let ordinal, totalCount > 0 else {
            return nil
        }
        return min(max(0, ordinal), totalCount - 1)
    }

    private func supersedePendingWindowIntent(
        clearsScrollbarPreview: Bool = true
    ) {
        finishPendingWindowMotion(pendingWindowSelection)
        pendingWindowSelection = nil
        if clearsScrollbarPreview {
            pendingScrollbarPreview = nil
        }
        lastWindowRequest = nil
    }

    private func resetForInvalidContent(
        _ contentAdapter: any PlaybackVirtualReelContentAdapter
    ) {
        cancelMotionForContentReplacement()
        if let mountedContentAdapter,
           mountedContentAdapter !== contentAdapter {
            contentAdapter.invalidate()
        }
        contentSnapshot = nil
        mountedContentAdapter = nil
        totalCount = 0
        selectedOrdinal = nil
        fractionalOrdinal = 0
        loadedOrdinalRange = 0..<0
        hasCompleteItemCollection = false
        hasInitializedPosition = false
        observedExternalSelectionToken = nil
        observedExternalSelectedOrdinal = nil
        documentView.invalidate()
        updateDocumentGeometry()
        updateScrollbarPresentation()
    }

    private func cancelMotionForContentReplacement() {
        keyboardAnimator.cancel()
        wheelAnimator.cancel()
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
        wheelState.reset(requiresNewGesture: true)
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        preciseGestureStartOrdinal = nil
        pendingWindowSelection = nil
        pendingScrollbarPreview = nil
        lastWindowRequest = nil
        if isScrollbarDragging {
            isScrollbarDragging = false
            onScrollbarDraggingChanged(false)
        }
        isKeyboardMotionActive = false
        isWheelMotionActive = false
        isScrollbarMotionActive = false
        motionCallbackGeneration += 1
        motionCallbackTask?.cancel()
        motionCallbackTask = nil
        if reportedNativeMotionActive {
            reportedNativeMotionActive = false
            onNativeMotionGateChanged(false)
            onKeyboardMotionChanged(false)
        }
    }

    func invalidate() {
        if reportedNativeMotionActive {
            onNativeMotionGateChanged(false)
        }
        motionCallbackGeneration += 1
        motionCallbackTask?.cancel()
        motionCallbackTask = nil
        onCommitKeyboardNavigation = { _ in false }
        onCommitNativeReelSelection = { _ in false }
        onCommitVirtualReelSelection = nil
        allowsNativeWheelInput = { false }
        allowsNativeScrollbarInput = { false }
        if isScrollbarDragging {
            onScrollbarDraggingChanged(false)
        }
        onScrollbarDraggingChanged = { _ in }
        onNativeMotionGateChanged = { _ in }
        onKeyboardMotionChanged = { _ in }
        keyboardAnimator.cancel()
        wheelAnimator.cancel()
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
        removeEventMonitor()
        wheelState.reset()
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        preciseGestureStartOrdinal = nil
        pendingWindowSelection = nil
        pendingScrollbarPreview = nil
        lastWindowRequest = nil
        observedExternalSelectionToken = nil
        observedExternalSelectedOrdinal = nil
        scrollbarView.onDrag = { _ in }
        scrollbarView.onDragStateChanged = nil
        scrollbarView.presentationProvider = { nil }
        scrollbarView.allowsInteraction = { false }
        scrollbarView.isPresented = false
        isScrollbarDragging = false
        isKeyboardMotionActive = false
        isWheelMotionActive = false
        isScrollbarMotionActive = false
        lastViewportSize = .zero
        reportedNativeMotionActive = false
        contentSnapshot = nil
        mountedContentAdapter = nil
        selectedOrdinal = nil
        fractionalOrdinal = 0
        loadedOrdinalRange = 0..<0
        totalCount = 0
        hasCompleteItemCollection = false
        hasInitializedPosition = false
        lastHandledKeyboardSequence = 0
        lastHandledGeneratedKeyboardToken = nil
        lastHandledGeneratedKeyboardSequence = 0
        isInteractionEnabled = false
        documentView.invalidate()
        scrollView.documentView = nil
    }

    var fractionalOrdinalForTesting: CGFloat {
        fractionalOrdinal
    }

    var selectedOrdinalForTesting: Int {
        selectedOrdinal ?? 0
    }

    var optionalSelectedOrdinalForTesting: Int? {
        selectedOrdinal
    }

    var displayedSelectedOrdinalForTesting: Int? {
        documentView.selectedOrdinalForTesting
    }

    var placementsForTesting: [PlaybackSubtitleFocusCuePlacement] {
        documentView.placements
    }

    var measuredOrdinalsForTesting: Set<Int> {
        documentView.measuredOrdinals
    }

    var measurementCacheCountForTesting: Int {
        documentView.measurementCacheCount
    }

    var scrollbarPresentationForTesting: TableScrollbarPresentation {
        scrollbarMetrics.presentation
    }

    var acceptsScrollbarInteractionForTesting: Bool {
        scrollbarView.acceptsInteraction && allowsNativeScrollbarInput()
    }

    func applyPreciseWheelDeltaForTesting(_ deltaY: CGFloat) {
        handlePreciseWheel(
            deltaY: deltaY,
            beginsGesture: preciseGestureStartOrdinal == nil
        )
    }

    func applyDiscreteWheelForTesting(
        direction: SubtitleFocusNavigationDirection,
        stepCount: Int = 1
    ) {
        handleDiscreteWheel(direction: direction, stepCount: stepCount)
    }

    func settlePreciseWheelForTesting() {
        settlePreciseWheel()
    }

    private func updateDocumentGeometry() {
        let layout = PlaybackSubtitleFocusVirtualReelLayout(
            viewportSize: scrollView.contentSize,
            totalCount: totalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            fractionalOrdinal: fractionalOrdinal
        )
        documentView.updateLocalLayout(layout)
        if documentView.frame.size != layout.viewportSize {
            documentView.frame = CGRect(origin: .zero, size: layout.viewportSize)
        }
        if scrollView.contentView.bounds.origin != .zero {
            scrollView.contentView.scroll(to: .zero)
        }
    }

    private func synchronizeFractionalOrdinalIfIdle() {
        guard !keyboardAnimator.isRunning,
              !wheelAnimator.isRunning,
              preciseGestureStartOrdinal == nil,
              let selectedOrdinal
        else {
            return
        }
        setFractionalOrdinal(CGFloat(selectedOrdinal))
    }

    private var currentLayout: PlaybackSubtitleFocusVirtualReelLayout {
        PlaybackSubtitleFocusVirtualReelLayout(
            viewportSize: scrollView.contentSize,
            totalCount: totalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            fractionalOrdinal: fractionalOrdinal
        )
    }

    private var scrollbarMetrics: PlaybackSubtitleFocusNativeScrollbarMetrics {
        PlaybackSubtitleFocusNativeScrollbarMetrics(
            totalCount: totalCount,
            fractionalOrdinal: fractionalOrdinal,
            visibleCueCapacity: documentView.visibleCueCenterCapacity
        )
    }

    private func updateScrollbarPresentation() {
        scrollbarView.isPresented = totalCount > 0
        updateScrollbarInteractionAvailability()
        scrollbarView.scrollbarMetricsDidChange()
    }

    private func updateScrollbarInteractionAvailability() {
        scrollbarView.acceptsInteraction = isInteractionEnabled
            && (hasCompleteItemCollection
                || mountedContentAdapter?.supportsWindowRequests == true)
            && selectedOrdinal != nil
            && !isKeyboardMotionActive
            && !isWheelMotionActive
    }

    private func cancelActiveScrollbarDrag() {
        guard isScrollbarDragging else {
            return
        }
        let restoresPresentation = totalCount > 0
        scrollbarView.isPresented = false
        if isScrollbarDragging {
            handleScrollbarDrag(TableScrollbarDragEvent(
                axis: .vertical,
                phase: .cancelled,
                positionFraction: scrollbarMetrics.presentation.vertical?
                    .positionFraction ?? 0
            ))
            handleScrollbarDraggingChanged(false)
        }
        scrollbarView.isPresented = restoresPresentation
    }

    private func setFractionalOrdinal(
        _ position: CGFloat,
        refreshesScrollbar: Bool = true
    ) {
        let boundedPosition = boundedLoadedFractionalOrdinal(position)
        guard abs(fractionalOrdinal - boundedPosition) > 0.000_001 else {
            if refreshesScrollbar {
                scrollbarView.scrollbarMetricsDidChange()
            }
            return
        }
        fractionalOrdinal = boundedPosition
        updateDocumentGeometry()
        if refreshesScrollbar {
            scrollbarView.scrollbarMetricsDidChange()
        }
    }

    private func handleKeyboardNavigation(
        _ request: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool
    ) {
        guard let request else {
            return
        }
        if let requestGeneration = request.contentGeneration {
            guard let contentSnapshot,
                  let contentDatasetID = request.contentDatasetID,
                  AnyHashable(contentDatasetID) == contentSnapshot.datasetID,
                  requestGeneration == contentSnapshot.generation
            else {
                return
            }
            let token = ContentToken(
                datasetID: contentSnapshot.datasetID,
                generation: requestGeneration
            )
            if lastHandledGeneratedKeyboardToken != token {
                lastHandledGeneratedKeyboardToken = token
                lastHandledGeneratedKeyboardSequence = 0
            }
            guard request.sequence > lastHandledGeneratedKeyboardSequence else {
                return
            }
            lastHandledGeneratedKeyboardSequence = request.sequence
        } else {
            guard request.sequence > lastHandledKeyboardSequence else {
                return
            }
            lastHandledKeyboardSequence = request.sequence
        }
        guard request.targetOrdinal >= 0,
              request.targetOrdinal < totalCount
        else {
            return
        }
        supersedePendingWindowIntent()
        guard loadedOrdinalRange.contains(request.targetOrdinal) else {
            guard let token = currentContentToken else {
                return
            }
            guard requestWindow(
                targetOrdinal: request.targetOrdinal,
                reason: .keyboard,
                pendingSelection: .keyboard(token: token, request: request)
            ) else {
                return
            }
            setKeyboardMotionActive(true)
            return
        }
        UIInvalidationProbe.mark(
            "ACTION playback.subtitle_focus.keyboard_navigation",
            scope: uiProbeScope,
            details: "target=\(request.targetOrdinal)"
        )
        activeKeyboardRequest = request
        activeKeyboardContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(request.targetOrdinal)
        setKeyboardMotionActive(true)
        keyboardAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(request.targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func completeKeyboardMotion() {
        guard let request = activeKeyboardRequest,
              activeKeyboardContentGeneration == contentSnapshot?.generation
        else {
            return
        }
        let didCommit: Bool
        if let onCommitVirtualReelSelection {
            didCommit = selectionCommit(for: request.targetOrdinal).map(
                onCommitVirtualReelSelection
            ) ?? false
        } else {
            didCommit = onCommitKeyboardNavigation(request)
        }
        guard didCommit else {
            activeKeyboardRequest = nil
            activeKeyboardContentGeneration = nil
            documentView.updateSelection(selectedOrdinal)
            setKeyboardMotionActive(false)
            synchronizeFractionalOrdinalIfIdle()
            return
        }
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        selectedOrdinal = request.targetOrdinal
        setKeyboardMotionActive(false)
    }

    func handleScrollbarDraggingChanged(_ isDragging: Bool) {
        guard isScrollbarDragging != isDragging else {
            return
        }
        if isDragging {
            guard scrollbarView.acceptsInteraction else {
                return
            }
            guard allowsNativeScrollbarInput() else {
                return
            }
            resetWheelInteraction(requiresNewGesture: true)
            supersedePendingWindowIntent()
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.scrollbar_drag",
                scope: uiProbeScope,
                details: "phase=began"
            )
            isScrollbarDragging = true
            onScrollbarDraggingChanged(true)
            setScrollbarMotionActive(true)
        } else {
            isScrollbarDragging = false
            onScrollbarDraggingChanged(false)
            setScrollbarMotionActive(false)
            if pendingScrollbarPreview != nil {
                restoreObservedExternalSelection()
            }
            updateScrollbarInteractionAvailability()
            scrollbarView.scrollbarMetricsDidChange()
        }
    }

    func handleScrollbarDrag(_ event: TableScrollbarDragEvent) {
        guard event.axis == .vertical,
              (hasCompleteItemCollection
                  || mountedContentAdapter?.supportsWindowRequests == true),
              isScrollbarDragging
        else {
            return
        }

        switch event.phase {
        case .began:
            break
        case .changed:
            _ = applyScrollbarPositionFraction(
                event.positionFraction,
                refreshesScrollbar: false,
                requestsCommit: false
            )
        case .ended:
            if applyScrollbarPositionFraction(
                event.positionFraction,
                refreshesScrollbar: true,
                requestsCommit: true
            ) {
                settleScrollbarDrag()
            }
        case .cancelled:
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            activeWheelContentGeneration = nil
            restoreObservedExternalSelection()
        }
    }

    private func applyScrollbarPositionFraction(
        _ positionFraction: CGFloat,
        refreshesScrollbar: Bool,
        requestsCommit: Bool
    ) -> Bool {
        let metrics = scrollbarMetrics
        let position = metrics.fractionalOrdinal(for: positionFraction)
        let targetOrdinal = min(
            max(0, Int(position.rounded())),
            max(0, totalCount - 1)
        )
        guard let token = currentContentToken else {
            return false
        }
        if requestsCommit {
            pendingScrollbarPreview = nil
            pendingWindowSelection = nil
        } else {
            pendingScrollbarPreview = PendingScrollbarPreview(
                token: token,
                ordinal: targetOrdinal,
                fractionalOrdinal: position
            )
        }
        guard loadedOrdinalRange.contains(targetOrdinal) else {
            let pendingSelection: PendingWindowSelection? = requestsCommit
                ? .native(
                    token: token,
                    ordinal: targetOrdinal,
                    reason: .scrollbar
                )
                : nil
            let didRequestWindow = requestWindow(
                targetOrdinal: targetOrdinal,
                reason: .scrollbar,
                pendingSelection: pendingSelection
            )
            if requestsCommit, didRequestWindow {
                setWheelMotionActive(true)
            }
            return false
        }
        setFractionalOrdinal(position, refreshesScrollbar: refreshesScrollbar)
        documentView.updateSelection(currentLayout.nearestOrdinal)
        return true
    }

    private func restoreObservedExternalSelection() {
        pendingScrollbarPreview = nil
        lastWindowRequest = nil
        guard let token = currentContentToken,
              observedExternalSelectionToken == token,
              let targetOrdinal = resolvedOrdinal(
                  observedExternalSelectedOrdinal,
                  totalCount: totalCount
              )
        else {
            selectedOrdinal = nil
            documentView.updateSelection(nil)
            updateScrollbarPresentation()
            return
        }
        if loadedOrdinalRange.contains(targetOrdinal) {
            selectedOrdinal = targetOrdinal
            fractionalOrdinal = CGFloat(targetOrdinal)
            hasInitializedPosition = true
            documentView.updateSelection(targetOrdinal)
            updateDocumentGeometry()
            updateScrollbarPresentation()
        } else {
            selectedOrdinal = nil
            documentView.updateSelection(nil)
            _ = requestWindow(
                targetOrdinal: targetOrdinal,
                reason: .visible,
                pendingSelection: .restore(
                    token: token,
                    ordinal: targetOrdinal
                )
            )
            updateScrollbarPresentation()
        }
    }

    private func settleScrollbarDrag() {
        let targetOrdinal = currentLayout.nearestOrdinal
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(targetOrdinal)
        setWheelMotionActive(true)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func installEventMonitorIfNeeded() {
        guard eventMonitor == nil else {
            return
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window
            else {
                return event
            }
            let point = self.convert(event.locationInWindow, from: nil)
            let isInside = self.bounds.contains(point)
            guard self.allowsNativeWheelInput() else {
                if self.isWheelMotionActive {
                    self.suspendWheelInputForSuppression()
                    return nil
                }
                return isInside ? nil : event
            }
            let sample = PlaybackSubtitleFocusScrollSample(
                deltaY: event.scrollingDeltaY,
                isPrecise: event.hasPreciseScrollingDeltas,
                phase: Self.scrollPhase(from: event.phase),
                momentumPhase: Self.scrollPhase(from: event.momentumPhase),
                isInside: isInside
            )
            let output = self.wheelState.consume(
                sample,
                isEnabled: self.isInteractionEnabled
            )
            guard output.shouldConsume else {
                return event
            }
            self.handleWheelOutput(output)
            return nil
        }
    }

    private func removeEventMonitor() {
        guard let eventMonitor else {
            return
        }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func handleWheelOutput(
        _ output: PlaybackSubtitleFocusNativeWheelOutput
    ) {
        switch output.mode {
        case .none:
            break
        case .discrete(let direction, let stepCount):
            handleDiscreteWheel(direction: direction, stepCount: stepCount)
        case .precise(let deltaY, let beginsGesture):
            handlePreciseWheel(deltaY: deltaY, beginsGesture: beginsGesture)
        }

        switch output.settleDirective {
        case .none:
            break
        case .cancel:
            cancelPreciseSettle()
        case .debounce:
            schedulePreciseSettle()
        case .immediate:
            settlePreciseWheel()
        }
    }

    private func handleDiscreteWheel(
        direction: SubtitleFocusNavigationDirection,
        stepCount: Int
    ) {
        cancelPreciseSettle()
        wheelState.finishPreciseGesture()
        guard let startOrdinal = activeWheelTargetOrdinal ?? selectedOrdinal else {
            return
        }
        let delta = direction == .backward ? -stepCount : stepCount
        let targetOrdinal = min(
            max(0, startOrdinal + delta),
            max(0, totalCount - 1)
        )
        guard targetOrdinal != startOrdinal else {
            return
        }
        supersedePendingWindowIntent()
        guard loadedOrdinalRange.contains(targetOrdinal) else {
            guard let token = currentContentToken else {
                return
            }
            guard requestWindow(
                targetOrdinal: targetOrdinal,
                reason: .wheel,
                pendingSelection: .native(
                    token: token,
                    ordinal: targetOrdinal,
                    reason: .wheel
                )
            ) else {
                return
            }
            setWheelMotionActive(true)
            return
        }
        UIInvalidationProbe.mark(
            "ACTION playback.subtitle_focus.wheel",
            scope: uiProbeScope,
            details: "mode=discrete target=\(targetOrdinal)"
        )

        preciseGestureStartOrdinal = nil
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(targetOrdinal)
        setWheelMotionActive(true)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func handlePreciseWheel(
        deltaY: CGFloat,
        beginsGesture: Bool
    ) {
        guard selectedOrdinal != nil,
              totalCount > 0,
              !loadedOrdinalRange.isEmpty
        else {
            return
        }
        if beginsGesture || preciseGestureStartOrdinal == nil {
            cancelPreciseSettle()
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            activeWheelContentGeneration = nil
            supersedePendingWindowIntent()
            preciseGestureStartOrdinal = currentLayout.nearestOrdinal
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.wheel",
                scope: uiProbeScope,
                details: "mode=precise"
            )
        }

        let position = documentView.fractionalOrdinal(
            afterMovingBy: -deltaY,
            from: fractionalOrdinal
        )
        setFractionalOrdinal(position)
        documentView.updateSelection(currentLayout.nearestOrdinal)
        setWheelMotionActive(true)
        requestAdjacentWindowIfNeeded(deltaY: deltaY)
    }

    private func schedulePreciseSettle() {
        preciseSettleTask?.cancel()
        let generation = contentSnapshot?.generation
        preciseSettleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.contentSnapshot?.generation == generation
            else {
                return
            }
            self.preciseSettleTask = nil
            self.settlePreciseWheel()
        }
    }

    private func cancelPreciseSettle() {
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
    }

    private func settlePreciseWheel() {
        cancelPreciseSettle()
        wheelState.finishPreciseGesture()
        guard selectedOrdinal != nil,
              !loadedOrdinalRange.isEmpty,
              preciseGestureStartOrdinal != nil
        else {
            return
        }

        let targetOrdinal = currentLayout.nearestOrdinal

        preciseGestureStartOrdinal = nil
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(targetOrdinal)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func completeWheelMotion() {
        guard let targetOrdinal = activeWheelTargetOrdinal,
              activeWheelContentGeneration == contentSnapshot?.generation
        else {
            return
        }
        let didCommit: Bool
        if let onCommitVirtualReelSelection {
            didCommit = selectionCommit(for: targetOrdinal).map(
                onCommitVirtualReelSelection
            ) ?? false
        } else {
            didCommit = onCommitNativeReelSelection(targetOrdinal)
        }
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        if didCommit {
            selectedOrdinal = targetOrdinal
        } else if selectedOrdinal != nil {
            documentView.updateSelection(selectedOrdinal)
        } else {
            restoreObservedExternalSelection()
        }
        setWheelMotionActive(false)
        if !didCommit, selectedOrdinal != nil {
            synchronizeFractionalOrdinalIfIdle()
        }
    }

    private func resetWheelInteraction(requiresNewGesture: Bool) {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: requiresNewGesture)
        wheelAnimator.cancel()
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        preciseGestureStartOrdinal = nil
        documentView.updateSelection(selectedOrdinal)
        setWheelMotionActive(false)
        synchronizeFractionalOrdinalIfIdle()
    }

    private func suspendWheelInputForSuppression() {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: true)
        if preciseGestureStartOrdinal != nil {
            settlePreciseWheel()
        }
    }

    private var currentContentToken: ContentToken? {
        contentSnapshot.map {
            ContentToken(datasetID: $0.datasetID, generation: $0.generation)
        }
    }

    @discardableResult
    private func requestWindow(
        targetOrdinal: Int,
        reason: PlaybackVirtualReelWindowRequestReason,
        pendingSelection: PendingWindowSelection?
    ) -> Bool {
        guard let contentSnapshot,
              let mountedContentAdapter,
              mountedContentAdapter.supportsWindowRequests,
              targetOrdinal >= 0,
              targetOrdinal < contentSnapshot.totalCount
        else {
            return false
        }
        let suggestedRange = PlaybackVirtualReelWindowPolicy.standard
            .windowRange(
                totalCount: contentSnapshot.totalCount,
                targetOrdinal: targetOrdinal
            )
        guard !suggestedRange.isEmpty else {
            return false
        }
        if let pendingSelection {
            self.pendingWindowSelection = pendingSelection
        }
        let request = PlaybackVirtualReelWindowRequest(
            datasetID: contentSnapshot.datasetID,
            generation: contentSnapshot.generation,
            revision: contentSnapshot.revision,
            targetOrdinal: targetOrdinal,
            suggestedOrdinalRange: suggestedRange,
            reason: reason
        )
        guard lastWindowRequest != request else {
            return true
        }
        lastWindowRequest = request
        mountedContentAdapter.requestWindow(request)
        return true
    }

    private func requestVisibleWindowIfNeeded() {
        guard pendingWindowSelection == nil,
              pendingScrollbarPreview == nil,
              let selectedOrdinal,
              let contentSnapshot,
              !contentSnapshot.isComplete,
              let mountedContentAdapter,
              mountedContentAdapter.supportsWindowRequests
        else {
            return
        }
        let suggestedRange = PlaybackVirtualReelWindowPolicy.standard
            .windowRange(
                totalCount: contentSnapshot.totalCount,
                targetOrdinal: selectedOrdinal
            )
        let loadedRange = contentSnapshot.loadedOrdinalRange
        guard suggestedRange.lowerBound < loadedRange.lowerBound
                || suggestedRange.upperBound > loadedRange.upperBound
        else {
            return
        }
        _ = requestWindow(
            targetOrdinal: selectedOrdinal,
            reason: .visible,
            pendingSelection: nil
        )
    }

    private func requestAdjacentWindowIfNeeded(deltaY: CGFloat) {
        guard deltaY != 0,
              let token = currentContentToken,
              !loadedOrdinalRange.isEmpty
        else {
            return
        }
        let nearestOrdinal = currentLayout.nearestOrdinal
        let targetOrdinal: Int?
        if deltaY < 0,
           nearestOrdinal == loadedOrdinalRange.upperBound - 1,
           loadedOrdinalRange.upperBound < totalCount {
            targetOrdinal = loadedOrdinalRange.upperBound
        } else if deltaY > 0,
                  nearestOrdinal == loadedOrdinalRange.lowerBound,
                  loadedOrdinalRange.lowerBound > 0 {
            targetOrdinal = loadedOrdinalRange.lowerBound - 1
        } else {
            targetOrdinal = nil
        }
        guard let targetOrdinal,
              requestWindow(
                  targetOrdinal: targetOrdinal,
                  reason: .wheel,
                  pendingSelection: .native(
                      token: token,
                      ordinal: targetOrdinal,
                      reason: .wheel
                  )
              )
        else {
            return
        }
        cancelPreciseSettle()
        preciseGestureStartOrdinal = nil
        documentView.updateSelection(selectedOrdinal)
        setWheelMotionActive(true)
    }

    private func finishPendingWindowSelection(
        _ pendingSelection: PendingWindowSelection,
        fallbackSelectedOrdinal: Int?
    ) {
        let didCommit: Bool
        switch pendingSelection {
        case .keyboard(_, let request):
            if let onCommitVirtualReelSelection {
                didCommit = selectionCommit(for: request.targetOrdinal).map(
                    onCommitVirtualReelSelection
                ) ?? false
            } else {
                didCommit = onCommitKeyboardNavigation(request)
            }
        case .native(_, let ordinal, _):
            if let onCommitVirtualReelSelection {
                didCommit = selectionCommit(for: ordinal).map(
                    onCommitVirtualReelSelection
                ) ?? false
            } else {
                didCommit = onCommitNativeReelSelection(ordinal)
            }
        case .restore:
            didCommit = true
        }
        guard !didCommit else {
            selectedOrdinal = pendingSelection.ordinal
            fractionalOrdinal = CGFloat(pendingSelection.ordinal)
            hasInitializedPosition = true
            documentView.updateSelection(selectedOrdinal)
            updateDocumentGeometry()
            updateScrollbarPresentation()
            finishPendingWindowMotion(pendingSelection)
            return
        }
        if let fallbackSelectedOrdinal,
           loadedOrdinalRange.contains(fallbackSelectedOrdinal) {
            selectedOrdinal = fallbackSelectedOrdinal
            fractionalOrdinal = CGFloat(fallbackSelectedOrdinal)
        } else {
            selectedOrdinal = nil
            fractionalOrdinal = boundedLoadedFractionalOrdinal(
                fractionalOrdinal
            )
            if let fallbackSelectedOrdinal,
               let token = currentContentToken,
               requestWindow(
                   targetOrdinal: fallbackSelectedOrdinal,
                   reason: .visible,
                   pendingSelection: .restore(
                       token: token,
                       ordinal: fallbackSelectedOrdinal
                   )
               ) {
                // Keep selection empty only while the prior window reloads.
            } else if let firstLoadedOrdinal = loadedOrdinalRange.first {
                selectedOrdinal = firstLoadedOrdinal
                fractionalOrdinal = CGFloat(firstLoadedOrdinal)
            }
        }
        documentView.updateSelection(selectedOrdinal)
        updateDocumentGeometry()
        updateScrollbarPresentation()
        finishPendingWindowMotion(pendingSelection)
    }

    private func finishPendingWindowMotion(
        _ pendingSelection: PendingWindowSelection?
    ) {
        switch pendingSelection {
        case .keyboard:
            setKeyboardMotionActive(false)
        case .native:
            setWheelMotionActive(false)
        case .restore, nil:
            break
        }
    }

    private func selectionCommit(
        for ordinal: Int
    ) -> PlaybackVirtualReelSelectionCommit? {
        guard let contentSnapshot,
              contentSnapshot.loadedOrdinalRange.contains(ordinal)
        else {
            return nil
        }
        return PlaybackVirtualReelSelectionCommit(
            datasetID: contentSnapshot.datasetID,
            generation: contentSnapshot.generation,
            ordinal: ordinal
        )
    }

    private func boundedLoadedFractionalOrdinal(_ ordinal: CGFloat) -> CGFloat {
        PlaybackSubtitleFocusVirtualReelLayout.clampedFractionalOrdinal(
            ordinal,
            to: loadedOrdinalRange
        )
    }

    private static func scrollPhase(
        from phase: NSEvent.Phase
    ) -> PlaybackSubtitleFocusScrollSample.Phase {
        if phase.contains(.began) {
            return .began
        }
        if phase.contains(.changed)
            || phase.contains(.mayBegin)
            || phase.contains(.stationary) {
            return .changed
        }
        if phase.contains(.ended) {
            return .ended
        }
        if phase.contains(.cancelled) {
            return .cancelled
        }
        return .none
    }

    private func setKeyboardMotionActive(_ isActive: Bool) {
        guard isKeyboardMotionActive != isActive else {
            return
        }
        isKeyboardMotionActive = isActive
        updateScrollbarInteractionAvailability()
        updateReportedNativeMotion()
    }

    private func setWheelMotionActive(_ isActive: Bool) {
        guard isWheelMotionActive != isActive else {
            return
        }
        isWheelMotionActive = isActive
        updateScrollbarInteractionAvailability()
        updateReportedNativeMotion()
    }

    private func setScrollbarMotionActive(_ isActive: Bool) {
        guard isScrollbarMotionActive != isActive else {
            return
        }
        isScrollbarMotionActive = isActive
        updateReportedNativeMotion()
    }

    private var hasActiveNativeMotion: Bool {
        isKeyboardMotionActive
            || isWheelMotionActive
            || activeKeyboardRequest != nil
            || activeWheelTargetOrdinal != nil
            || preciseGestureStartOrdinal != nil
            || isScrollbarDragging
            || keyboardAnimator.isRunning
            || wheelAnimator.isRunning
    }

    private func updateReportedNativeMotion() {
        let isActive = isKeyboardMotionActive
            || isWheelMotionActive
            || isScrollbarMotionActive
        guard reportedNativeMotionActive != isActive else {
            return
        }
        reportedNativeMotionActive = isActive
        onNativeMotionGateChanged(isActive)
        motionCallbackGeneration += 1
        let generation = motionCallbackGeneration
        motionCallbackTask?.cancel()
        motionCallbackTask = Task { @MainActor [weak self] in
            guard let self,
                  !Task.isCancelled,
                  self.motionCallbackGeneration == generation,
                  self.reportedNativeMotionActive == isActive
            else {
                return
            }
            self.motionCallbackTask = nil
            self.onKeyboardMotionChanged(isActive)
        }
    }
}

typealias PlaybackVirtualReelContainerView =
    PlaybackSubtitleFocusReelContainerView

private final class PlaybackSubtitleFocusNativeScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

private final class PlaybackSubtitleFocusNativeScrollbarView:
    TableScrollbarOverlayView
{
    var allowsInteraction: () -> Bool = { false }
    var acceptsInteraction = false {
        didSet {
            guard acceptsInteraction != oldValue else {
                return
            }
            window?.invalidateCursorRects(for: self)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard acceptsInteraction, allowsInteraction() else {
            return nil
        }
        return super.hitTest(point)
    }

    override func resetCursorRects() {
        guard acceptsInteraction, allowsInteraction() else {
            discardCursorRects()
            return
        }
        super.resetCursorRects()
    }
}

final class PlaybackSubtitleFocusReelDocumentView: NSView {
    var uiProbeScope: String?
    private var layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: .zero,
        totalCount: 0,
        loadedOrdinalRange: 0..<0,
        fractionalOrdinal: 0
    )
    private var contentAdapter: (any PlaybackVirtualReelContentAdapter)?
    private var contentSnapshot: PlaybackVirtualReelSnapshot?
    private var selectedOrdinal: Int?
    private(set) var placements: [PlaybackSubtitleFocusCuePlacement] = []

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    var selectedOrdinalForTesting: Int? {
        selectedOrdinal
    }

    func updateContent(
        _ contentAdapter: any PlaybackVirtualReelContentAdapter
    ) {
        let snapshot = contentAdapter.snapshot
        guard snapshot.isValid else {
            return
        }
        if snapshot == contentSnapshot {
            if let previousAdapter = self.contentAdapter,
               previousAdapter !== contentAdapter {
                previousAdapter.invalidate()
                self.contentAdapter = contentAdapter
                resolveLocalPlacementsIfNeeded()
                needsDisplay = true
            }
            return
        }
        if let contentSnapshot,
           contentSnapshot.belongsToSameDataset(as: snapshot),
           (snapshot.revision < contentSnapshot.revision
               || snapshot.revision == contentSnapshot.revision) {
            if let previousAdapter = self.contentAdapter {
                if previousAdapter === contentAdapter {
                    invalidate()
                } else {
                    contentAdapter.invalidate()
                }
            }
            return
        }
        if let previousAdapter = self.contentAdapter,
           previousAdapter !== contentAdapter {
            previousAdapter.invalidate()
        }
        if let contentSnapshot,
           !contentSnapshot.belongsToSameDataset(as: snapshot) {
            placements.removeAll(keepingCapacity: true)
        }
        self.contentAdapter = contentAdapter
        contentSnapshot = snapshot
        resolveLocalPlacementsIfNeeded()
        needsDisplay = true
    }

    func updateSelection(_ ordinal: Int?) {
        guard selectedOrdinal != ordinal else {
            return
        }
        let previousOrdinal = selectedOrdinal
        selectedOrdinal = ordinal
        if let previousOrdinal {
            invalidateRow(previousOrdinal)
        }
        if let selectedOrdinal {
            invalidateRow(selectedOrdinal)
        }
        resolveLocalPlacementsIfNeeded()
        needsDisplay = true
    }

    func updateLocalLayout(_ layout: PlaybackSubtitleFocusVirtualReelLayout) {
        guard self.layout != layout else {
            return
        }
        self.layout = layout
        UIInvalidationProbe.count(
            "playback.subtitle_focus.layout_update",
            scope: uiProbeScope,
            details: "ordinal=\(layout.fractionalOrdinal)"
        )
        resolveLocalPlacementsIfNeeded()
        needsDisplay = true
    }

    func invalidate() {
        contentAdapter?.invalidate()
        contentAdapter = nil
        contentSnapshot = nil
        selectedOrdinal = nil
        placements.removeAll(keepingCapacity: false)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let visibleDirtyRect = dirtyRect.intersection(visibleRect)
        guard !visibleDirtyRect.isNull, !visibleDirtyRect.isEmpty else {
            return
        }
        for placement in placements where placement.rect.intersects(visibleDirtyRect) {
            UIInvalidationProbe.count(
                "playback.subtitle_focus.cue_draw",
                scope: uiProbeScope,
                details: "ordinal=\(placement.ordinal)"
            )
            contentAdapter?.drawItem(
                at: placement.ordinal,
                isSelected: placement.ordinal == selectedOrdinal,
                in: placement.rect
            )
        }
    }

    func fractionalOrdinal(
        afterMovingBy pixelTravel: CGFloat,
        from currentFractionalOrdinal: CGFloat
    ) -> CGFloat {
        guard !layout.loadedOrdinalRange.isEmpty,
              pixelTravel.isFinite, pixelTravel != 0 else {
            return layout.fractionalOrdinal
        }

        let range: Range<Int>
        if let firstPlacement = placements.first,
           let lastPlacement = placements.last {
            let lower = max(
                layout.loadedOrdinalRange.lowerBound,
                firstPlacement.ordinal
            )
            let upper = min(
                layout.loadedOrdinalRange.upperBound,
                lastPlacement.ordinal + 1
            )
            range = lower..<max(lower, upper)
        } else {
            range = layout.loadedOrdinalRange
        }
        var position = PlaybackSubtitleFocusVirtualReelLayout
            .clampedFractionalOrdinal(currentFractionalOrdinal, to: range)
        var remaining = abs(pixelTravel)
        let movesForward = pixelTravel > 0
        var safetyCount = 0

        while remaining > 0.000_1, safetyCount < range.count + 1 {
            safetyCount += 1
            if movesForward {
                guard position < CGFloat(range.upperBound - 1) else {
                    break
                }
                let lower = Int(floor(position))
                let upper = lower + 1
                guard let lowerMeasurement = measurement(at: lower, layout: layout),
                      let upperMeasurement = measurement(at: upper, layout: layout) else {
                    break
                }
                let distance = layout.adjacentCenterDistance(
                    from: lowerMeasurement.resolvedHeight,
                    to: upperMeasurement.resolvedHeight
                )
                guard distance > 0 else {
                    position = CGFloat(upper)
                    continue
                }
                let fraction = position - CGFloat(lower)
                let distanceToBoundary = (1 - fraction) * distance
                if remaining < distanceToBoundary {
                    position += remaining / distance
                    remaining = 0
                } else {
                    position = CGFloat(upper)
                    remaining -= distanceToBoundary
                }
            } else {
                guard position > CGFloat(range.lowerBound) else {
                    break
                }
                let upper = Int(ceil(position))
                let lower = upper - 1
                guard let lowerMeasurement = measurement(at: lower, layout: layout),
                      let upperMeasurement = measurement(at: upper, layout: layout) else {
                    break
                }
                let distance = layout.adjacentCenterDistance(
                    from: lowerMeasurement.resolvedHeight,
                    to: upperMeasurement.resolvedHeight
                )
                guard distance > 0 else {
                    position = CGFloat(lower)
                    continue
                }
                let fraction = position - CGFloat(lower)
                let distanceToBoundary = fraction * distance
                if remaining < distanceToBoundary {
                    position -= remaining / distance
                    remaining = 0
                } else {
                    position = CGFloat(lower)
                    remaining -= distanceToBoundary
                }
            }
        }

        return PlaybackSubtitleFocusVirtualReelLayout.clampedFractionalOrdinal(
            position,
            to: range
        )
    }

    var visibleCueCenterCapacity: Int {
        guard !placements.isEmpty else {
            return 1
        }
        let count = placements.reduce(into: 0) { result, placement in
            if placement.rect.midY >= 0,
               placement.rect.midY <= layout.viewportSize.height {
                result += 1
            }
        }
        return max(1, count)
    }

    var measurementCacheCount: Int {
        contentAdapter?.measurementCacheCountForTesting ?? 0
    }

    var measuredOrdinals: Set<Int> {
        contentAdapter?.measuredOrdinalsForTesting ?? []
    }

    override func mouseDown(with event: NSEvent) {
        // Cue-specific pointer activation is intentionally absent. Keep the
        // event inside the focus overlay so it cannot reach the video surface.
    }

    private func invalidateRow(_ ordinal: Int) {
        guard ordinal >= 0, ordinal < layout.totalCount else {
            return
        }
        if let placement = placements.first(where: { $0.ordinal == ordinal }) {
            setNeedsDisplay(placement.rect)
        }
    }

    private func resolveLocalPlacementsIfNeeded() {
        guard !layout.loadedOrdinalRange.isEmpty,
              layout.viewportSize.width > 0,
              layout.viewportSize.height > 0,
              let lowerMeasurement = measurement(
                  at: layout.lowerOrdinal,
                  layout: layout
              ) else {
            placements = []
            return
        }

        let upperMeasurement = measurement(
            at: layout.upperOrdinal,
            layout: layout
        ) ?? lowerMeasurement
        let lowerTop = layout.lowerCueTop(
            lowerResolvedHeight: lowerMeasurement.resolvedHeight,
            upperResolvedHeight: upperMeasurement.resolvedHeight
        )
        var resolved: [Int: PlaybackSubtitleFocusCuePlacement] = [:]
        guard let lowerPlacement = placement(
            ordinal: layout.lowerOrdinal,
            top: lowerTop,
            measurement: lowerMeasurement,
            layout: layout
        ) else {
            placements = []
            return
        }
        resolved[layout.lowerOrdinal] = lowerPlacement

        if layout.upperOrdinal != layout.lowerOrdinal {
            guard let upperPlacement = placement(
                ordinal: layout.upperOrdinal,
                top: lowerTop + lowerMeasurement.resolvedHeight
                    + PlaybackSubtitleFocusMetrics.cueGap,
                measurement: upperMeasurement,
                layout: layout
            ) else {
                placements = []
                return
            }
            resolved[layout.upperOrdinal] = upperPlacement
        }

        var nextTop = lowerTop
        var outsideCount = 0
        if layout.lowerOrdinal > layout.loadedOrdinalRange.lowerBound {
            for ordinal in stride(
                from: layout.lowerOrdinal - 1,
                through: layout.loadedOrdinalRange.lowerBound,
                by: -1
            ) {
                guard let measurement = measurement(at: ordinal, layout: layout) else {
                    placements = []
                    return
                }
                let top = nextTop
                    - PlaybackSubtitleFocusMetrics.cueGap
                    - measurement.resolvedHeight
                guard let item = placement(
                    ordinal: ordinal,
                    top: top,
                    measurement: measurement,
                    layout: layout
                ) else {
                    placements = []
                    return
                }
                resolved[ordinal] = item
                nextTop = top
                if item.rect.maxY < 0 {
                    outsideCount += 1
                    if outsideCount
                        >= PlaybackVirtualReelLayout.overscanItemCount {
                        break
                    }
                }
            }
        }

        let lastSeedOrdinal = layout.upperOrdinal
        var nextBottom = resolved[lastSeedOrdinal]?.rect.maxY
            ?? resolved[layout.lowerOrdinal]?.rect.maxY
            ?? lowerTop
        outsideCount = 0
        if lastSeedOrdinal < layout.loadedOrdinalRange.upperBound - 1 {
            for ordinal in (lastSeedOrdinal + 1)..<layout.loadedOrdinalRange.upperBound {
                guard let measurement = measurement(at: ordinal, layout: layout) else {
                    placements = []
                    return
                }
                let top = nextBottom + PlaybackSubtitleFocusMetrics.cueGap
                guard let item = placement(
                    ordinal: ordinal,
                    top: top,
                    measurement: measurement,
                    layout: layout
                ) else {
                    placements = []
                    return
                }
                resolved[ordinal] = item
                nextBottom = item.rect.maxY
                if item.rect.minY > layout.viewportSize.height {
                    outsideCount += 1
                    if outsideCount
                        >= PlaybackVirtualReelLayout.overscanItemCount {
                        break
                    }
                }
            }
        }

        placements = resolved.values.sorted { $0.ordinal < $1.ordinal }
    }

    private func measurement(
        at ordinal: Int,
        layout: PlaybackSubtitleFocusVirtualReelLayout
    ) -> PlaybackSubtitleFocusCueMeasurement? {
        contentAdapter?.extent(
            at: ordinal,
            isSelected: ordinal == selectedOrdinal,
            contentWidth: layout.contentWidth,
            viewportHeight: layout.viewportSize.height,
            uiProbeScope: uiProbeScope
        )
    }

    private func placement(
        ordinal: Int,
        top: CGFloat,
        measurement: PlaybackSubtitleFocusCueMeasurement,
        layout: PlaybackSubtitleFocusVirtualReelLayout
    ) -> PlaybackSubtitleFocusCuePlacement? {
        guard let itemID = contentAdapter?.itemID(at: ordinal) else {
            return nil
        }
        return PlaybackSubtitleFocusCuePlacement(
            ordinal: ordinal,
            itemID: itemID,
            rect: CGRect(
                x: (layout.viewportSize.width - layout.contentWidth) / 2,
                y: top,
                width: layout.contentWidth,
                height: measurement.resolvedHeight
            ),
            extent: measurement
        )
    }
}

typealias PlaybackVirtualReelDocumentView =
    PlaybackSubtitleFocusReelDocumentView

@MainActor
final class PlaybackSubtitleFocusNativeTextLayout {
    private let visualLineLayout = PlaybackVisualLineStackLayout()

    func draw(
        text: String,
        color: NSColor,
        in rect: CGRect
    ) {
        let textRect = Self.textRect(in: rect)
        guard textRect.width > 0, textRect.height > 0 else {
            return
        }
        visualLineLayout.prepare(
            text: text,
            color: color,
            width: textRect.width
        )
        visualLineLayout.drawPreparedPlan(in: textRect)
    }

    func visibleLineRects(
        text: String,
        in rect: CGRect
    ) -> [CGRect] {
        let textRect = Self.textRect(in: rect)
        guard textRect.width > 0, textRect.height > 0 else {
            return []
        }
        let plan = visualLineLayout.prepare(
            text: text,
            color: .white,
            width: textRect.width
        )
        return plan.typographicRects(in: textRect).compactMap { lineRect in
            let visibleRect = lineRect.intersection(textRect)
            guard !visibleRect.isNull,
                  visibleRect.width > 0,
                  visibleRect.height > 0
            else {
                return nil
            }
            return visibleRect
        }
    }

    private static func textRect(in cueRect: CGRect) -> CGRect {
        CGRect(
            x: cueRect.minX,
            y: cueRect.minY + PlaybackSubtitleFocusMetrics.cueVerticalPadding,
            width: cueRect.width,
            height: max(
                0,
                cueRect.height
                    - PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
            )
        )
    }
}

@MainActor
final class PlaybackSubtitleFocusReelPositionAnimator: NSObject {
    let onUpdate: (CGFloat) -> Void
    let onCompletion: () -> Void

    private(set) var isRunning = false
    private var timer: Timer?
    private var generation = 0
    private var startTime: TimeInterval = 0
    private var duration: TimeInterval = 0
    private var startOffset: CGFloat = 0
    private var targetOffset: CGFloat = 0

    init(
        onUpdate: @escaping (CGFloat) -> Void,
        onCompletion: @escaping () -> Void
    ) {
        self.onUpdate = onUpdate
        self.onCompletion = onCompletion
    }

    func retarget(
        from currentOffset: CGFloat,
        to targetOffset: CGFloat,
        duration: TimeInterval
    ) {
        generation += 1
        startTime = ProcessInfo.processInfo.systemUptime
        self.duration = max(0, duration)
        startOffset = currentOffset
        self.targetOffset = targetOffset
        isRunning = true

        guard self.duration > 0, abs(targetOffset - currentOffset) > 0.01 else {
            finishImmediately(generation: generation)
            return
        }
        if timer == nil {
            let timer = Timer(
                timeInterval: 1 / 120,
                target: self,
                selector: #selector(handleTimer),
                userInfo: nil,
                repeats: true
            )
            timer.tolerance = 1 / 240
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    func cancel() {
        generation += 1
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    static func easedProgress(_ linearProgress: CGFloat) -> CGFloat {
        let x = min(1, max(0, linearProgress))
        guard x > 0, x < 1 else {
            return x
        }

        var lower: CGFloat = 0
        var upper: CGFloat = 1
        var parameter = x
        for _ in 0..<10 {
            let estimatedX = cubicBezierValue(
                parameter,
                firstControl: 0.22,
                secondControl: 0.36
            )
            if estimatedX < x {
                lower = parameter
            } else {
                upper = parameter
            }
            parameter = (lower + upper) / 2
        }
        return cubicBezierValue(
            parameter,
            firstControl: 1,
            secondControl: 1
        )
    }

    @objc
    private func handleTimer() {
        let elapsed = ProcessInfo.processInfo.systemUptime - startTime
        let linearProgress = CGFloat(min(1, max(0, elapsed / duration)))
        let easedProgress = Self.easedProgress(linearProgress)
        onUpdate(
            startOffset + (targetOffset - startOffset) * easedProgress
        )
        guard linearProgress >= 1 else {
            return
        }

        timer?.invalidate()
        timer = nil
        isRunning = false
        onUpdate(targetOffset)
        onCompletion()
    }

    private func finishImmediately(generation expectedGeneration: Int) {
        timer?.invalidate()
        timer = nil
        onUpdate(targetOffset)
        Task { @MainActor [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  self.isRunning
            else {
                return
            }
            self.isRunning = false
            self.onCompletion()
        }
    }

    private static func cubicBezierValue(
        _ parameter: CGFloat,
        firstControl: CGFloat,
        secondControl: CGFloat
    ) -> CGFloat {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * firstControl
            + 3 * inverse * parameter * parameter * secondControl
            + parameter * parameter * parameter
    }
}
