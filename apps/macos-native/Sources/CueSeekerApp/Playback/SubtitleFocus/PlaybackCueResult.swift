import AppKit

/// Presentation-only data for one Playlist, Search, or Shiori reel result.
/// Module action payloads intentionally remain outside this renderer model.
struct PlaybackCueResult: Equatable {
    /// Stable identity of this occurrence in its owning module data source.
    let itemID: AnyHashable
    /// Stable identity of the Primary Cue targeted by module actions.
    let primaryCueIdentity: AnyHashable
    let primaryCueText: String
    let additionalCueTexts: [String]
    /// Playlist supplies its own internal number. Other modules leave this nil.
    let sequenceNumber: Int?

    init(
        itemID: AnyHashable,
        primaryCueIdentity: AnyHashable,
        primaryCueText: String,
        additionalCueTexts: [String] = [],
        sequenceNumber: Int? = nil
    ) {
        self.itemID = itemID
        self.primaryCueIdentity = primaryCueIdentity
        self.primaryCueText = primaryCueText
        self.additionalCueTexts = additionalCueTexts
        self.sequenceNumber = sequenceNumber
    }
}

enum PlaybackCueResultLineRole: Equatable {
    case additionalCue(index: Int)
    case primaryCue
}

enum PlaybackCueResultTextStyle {
    case primary
    case cueGroup

    var font: NSFont {
        switch self {
        case .primary:
            NSFont.systemFont(
                ofSize: PlaybackSubtitleFocusMetrics.cueFontSize,
                weight: PlaybackSubtitleFocusMetrics.cueFontWeight
            )
        case .cueGroup:
            NSFont.systemFont(
                ofSize: PlaybackSubtitleFocusMetrics.cueGroupFontSize,
                weight: PlaybackSubtitleFocusMetrics.cueGroupFontWeight
            )
        }
    }

    var nominalLineHeight: CGFloat {
        switch self {
        case .primary:
            PlaybackSubtitleFocusMetrics.cueLineHeight
        case .cueGroup:
            PlaybackSubtitleFocusMetrics.cueGroupLineHeight
        }
    }

    func color(isSelected: Bool) -> NSColor {
        guard isSelected else {
            return PlaybackTheme.subtitleFocusCueUnselectedNative
        }
        switch self {
        case .primary:
            return PlaybackTheme.subtitleFocusCueSelectedNative
        case .cueGroup:
            return PlaybackTheme.subtitleFocusCueGroupSelectedNative
        }
    }
}

struct PlaybackCueResultVisualLine {
    let role: PlaybackCueResultLineRole
    let style: PlaybackCueResultTextStyle
    let color: NSColor
    let line: PlaybackVisualLineStackLine

    var typographicTop: CGFloat {
        line.typographicTop
    }

    var typographicBottom: CGFloat {
        line.typographicBottom
    }

    var baseline: CGFloat {
        line.typographicTop + line.ascent
    }
}

struct PlaybackCueResultSequencePlan {
    let value: Int
    let laneWidth: CGFloat
    let font: NSFont
    let color: NSColor
    /// Relative to the top of the Result's resolved content region.
    let primaryFirstLineBaseline: CGFloat
}

struct PlaybackCueResultLayoutPlan {
    let itemID: AnyHashable
    let primaryCueIdentity: AnyHashable
    let showsCueGroup: Bool
    let visualLinePlan: PlaybackVisualLineStackPlan
    let visualLines: [PlaybackCueResultVisualLine]
    let sequence: PlaybackCueResultSequencePlan?
    let resultWidth: CGFloat
    let cueTextWidth: CGFloat
    let extent: PlaybackVirtualReelItemExtent

    var primaryFirstVisualLine: PlaybackCueResultVisualLine? {
        visualLines.first { $0.role == .primaryCue }
    }

    func typographicRects(in resultRect: CGRect) -> [CGRect] {
        let contentRect = cueTextRect(in: resultRect)
        return visualLines.map { visualLine in
            CGRect(
                x: contentRect.minX + visualLine.line.usedRect.minX,
                y: contentRect.minY + visualLine.typographicTop,
                width: visualLine.line.usedRect.width,
                height: visualLine.line.typographicHeight
            )
        }
    }

    func visibleTypographicRects(in resultRect: CGRect) -> [CGRect] {
        let contentRect = cueTextRect(in: resultRect)
        return typographicRects(in: resultRect).compactMap { lineRect in
            let visibleRect = lineRect.intersection(contentRect)
            guard !visibleRect.isNull,
                  visibleRect.width > 0,
                  visibleRect.height > 0
            else {
                return nil
            }
            return visibleRect
        }
    }

    func cueTextRect(in resultRect: CGRect) -> CGRect {
        let sequenceWidth = sequence?.laneWidth ?? 0
        return CGRect(
            x: resultRect.minX + sequenceWidth,
            y: resultRect.minY + PlaybackSubtitleFocusMetrics.cueVerticalPadding,
            width: max(0, resultRect.width - sequenceWidth),
            height: max(
                0,
                resultRect.height
                    - PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
            )
        )
    }
}

@MainActor
final class PlaybackCueResultLayout {
    private let visualLineLayout = PlaybackVisualLineStackLayout()
    private let sequenceTextStorage = NSTextStorage()
    private let sequenceLayoutManager = NSLayoutManager()
    private let sequenceTextContainer = NSTextContainer()
    private(set) var plan: PlaybackCueResultLayoutPlan?

    init() {
        sequenceTextContainer.lineFragmentPadding = 0
        sequenceTextContainer.maximumNumberOfLines = 1
        sequenceTextContainer.lineBreakMode = .byClipping
        sequenceLayoutManager.usesFontLeading = false
        sequenceLayoutManager.addTextContainer(sequenceTextContainer)
        sequenceTextStorage.addLayoutManager(sequenceLayoutManager)
    }

    @discardableResult
    func prepare(
        result: PlaybackCueResult,
        showsCueGroup: Bool,
        isSelected: Bool,
        width: CGFloat,
        viewportHeight: CGFloat
    ) -> PlaybackCueResultLayoutPlan {
        let safeWidth = max(0, width)
        let sequenceLaneWidth = result.sequenceNumber == nil
            ? 0
            : PlaybackSubtitleFocusMetrics.playlistSequenceWidth
        let cueTextWidth = max(0, safeWidth - sequenceLaneWidth)
        let visibleAdditionalCues = showsCueGroup
            ? result.additionalCueTexts
            : []

        var roles = visibleAdditionalCues.indices.map {
            PlaybackCueResultLineRole.additionalCue(index: $0)
        }
        roles.append(.primaryCue)
        let styles = Array(
            repeating: PlaybackCueResultTextStyle.cueGroup,
            count: visibleAdditionalCues.count
        ) + [.primary]
        let texts = visibleAdditionalCues + [result.primaryCueText]
        let segments = zip(texts, styles).map { text, style in
            PlaybackVisualLineStackSegment(
                text: text,
                font: style.font,
                color: style.color(isSelected: isSelected),
                nominalLineHeight: style.nominalLineHeight
            )
        }
        let visualLinePlan = visualLineLayout.prepare(
            segments: segments,
            width: cueTextWidth
        )
        let visualLines = visualLinePlan.lines.map { line in
            let segmentIndex = min(
                max(0, line.segmentIndex),
                max(0, roles.count - 1)
            )
            let style = styles[segmentIndex]
            return PlaybackCueResultVisualLine(
                role: roles[segmentIndex],
                style: style,
                color: style.color(isSelected: isSelected),
                line: line
            )
        }
        let naturalHeight = visualLinePlan.resolvedContentHeight
            + PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
        let safeViewportHeight = max(0, viewportHeight)
        let extent = PlaybackVirtualReelItemExtent(
            visualLineCount: visualLinePlan.visualLineCount,
            visualLineStackHeight: visualLinePlan.stackHeight,
            resolvedContentHeight: visualLinePlan.resolvedContentHeight,
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, safeViewportHeight),
            isOversized: naturalHeight > safeViewportHeight
        )
        let firstPrimaryLine = visualLines.first { $0.role == .primaryCue }
        let sequencePlan = result.sequenceNumber.flatMap { value in
            firstPrimaryLine.map { line in
                PlaybackCueResultSequencePlan(
                    value: value,
                    laneWidth: sequenceLaneWidth,
                    font: NSFont.systemFont(
                        ofSize: PlaybackSubtitleFocusMetrics.playlistSequenceFontSize,
                        weight: .regular
                    ),
                    color: PlaybackTheme.subtitleFocusCueUnselectedNative,
                    primaryFirstLineBaseline: line.baseline
                )
            }
        }
        let resolvedPlan = PlaybackCueResultLayoutPlan(
            itemID: result.itemID,
            primaryCueIdentity: result.primaryCueIdentity,
            showsCueGroup: showsCueGroup,
            visualLinePlan: visualLinePlan,
            visualLines: visualLines,
            sequence: sequencePlan,
            resultWidth: safeWidth,
            cueTextWidth: cueTextWidth,
            extent: extent
        )
        plan = resolvedPlan
        return resolvedPlan
    }

    func drawPreparedPlan(in resultRect: CGRect) {
        guard let plan else {
            return
        }
        visualLineLayout.drawPreparedPlan(in: plan.cueTextRect(in: resultRect))
        guard let sequence = plan.sequence else {
            return
        }
        draw(sequence: sequence, in: resultRect)
    }

    private func draw(
        sequence: PlaybackCueResultSequencePlan,
        in resultRect: CGRect
    ) {
        guard resultRect.width > 0,
              resultRect.height > 0,
              let context = NSGraphicsContext.current
        else {
            return
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byClipping
        sequenceTextStorage.setAttributedString(NSAttributedString(
            string: String(sequence.value),
            attributes: [
                .font: sequence.font,
                .foregroundColor: sequence.color,
                .paragraphStyle: paragraphStyle,
            ]
        ))
        sequenceTextContainer.size = CGSize(
            width: sequence.laneWidth,
            height: max(1, sequence.font.ascender - sequence.font.descender)
        )
        sequenceLayoutManager.ensureLayout(for: sequenceTextContainer)
        let glyphRange = sequenceLayoutManager.glyphRange(
            for: sequenceTextContainer
        )
        guard glyphRange.length > 0 else {
            return
        }
        let lineRect = sequenceLayoutManager.lineFragmentRect(
            forGlyphAt: glyphRange.location,
            effectiveRange: nil
        )
        let originalBaseline = lineRect.minY
            + sequenceLayoutManager.location(
                forGlyphAt: glyphRange.location
            ).y
        let targetBaseline = resultRect.minY
            + PlaybackSubtitleFocusMetrics.cueVerticalPadding
            + sequence.primaryFirstLineBaseline
        let sequenceClipRect = CGRect(
            x: resultRect.minX,
            y: resultRect.minY + PlaybackSubtitleFocusMetrics.cueVerticalPadding,
            width: sequence.laneWidth,
            height: max(
                0,
                resultRect.height
                    - PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
            )
        )

        context.saveGraphicsState()
        NSBezierPath(rect: sequenceClipRect).addClip()
        sequenceLayoutManager.drawGlyphs(
            forGlyphRange: glyphRange,
            at: CGPoint(
                x: resultRect.minX,
                y: targetBaseline - originalBaseline
            )
        )
        context.restoreGraphicsState()
    }
}

@MainActor
final class PlaybackCueResultMeasurementCache {
    private struct Key: Hashable {
        let itemID: AnyHashable
        let primaryCueIdentity: AnyHashable
        let primaryCueText: String
        let additionalCueTexts: [String]
        let showsCueGroup: Bool
        let hasSequenceNumber: Bool
        let width: CGFloat
        let viewportHeight: CGFloat
        let styleRevision: Int
    }

    private struct Entry {
        let extent: PlaybackVirtualReelItemExtent
        var lastAccess: UInt64
    }

    private let capacity: Int
    private let layout = PlaybackCueResultLayout()
    private var entries: [Key: Entry] = [:]
    private var accessSequence: UInt64 = 0
    private(set) var measurementCount = 0

    init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }

    var count: Int {
        entries.count
    }

    func extent(
        for result: PlaybackCueResult,
        showsCueGroup: Bool,
        width: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String? = nil
    ) -> PlaybackVirtualReelItemExtent {
        accessSequence &+= 1
        let key = Key(
            itemID: result.itemID,
            primaryCueIdentity: result.primaryCueIdentity,
            primaryCueText: result.primaryCueText,
            additionalCueTexts: result.additionalCueTexts,
            showsCueGroup: showsCueGroup,
            hasSequenceNumber: result.sequenceNumber != nil,
            width: width,
            viewportHeight: viewportHeight,
            styleRevision: 1
        )
        if var entry = entries[key] {
            entry.lastAccess = accessSequence
            entries[key] = entry
            return entry.extent
        }

        let extent = layout.prepare(
            result: result,
            showsCueGroup: showsCueGroup,
            isSelected: false,
            width: width,
            viewportHeight: viewportHeight
        ).extent
        measurementCount += 1
        UIInvalidationProbe.count(
            "playback.cue_result.measurement",
            scope: uiProbeScope,
            details: "item=\(String(describing: result.itemID))"
        )
        entries[key] = Entry(
            extent: extent,
            lastAccess: accessSequence
        )
        evictIfNeeded()
        return extent
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
