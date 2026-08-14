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
    /// Plain context rendered below the complete Cue stack.
    let metadata: PlaybackCueMetadata?

    init(
        itemID: AnyHashable,
        primaryCueIdentity: AnyHashable,
        primaryCueText: String,
        additionalCueTexts: [String] = [],
        metadata: PlaybackCueMetadata? = nil
    ) {
        self.itemID = itemID
        self.primaryCueIdentity = primaryCueIdentity
        self.primaryCueText = primaryCueText
        self.additionalCueTexts = additionalCueTexts
        self.metadata = metadata
    }
}

struct PlaybackCueMetadata: Equatable {
    let displayTitle: String
    let timeRange: String

    var isEmpty: Bool {
        displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && timeRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum PlaybackCueInformationText {
    static func timeRange(
        startMilliseconds: Int,
        endMilliseconds: Int
    ) -> String {
        "\(timestamp(milliseconds: startMilliseconds)) - "
            + timestamp(milliseconds: endMilliseconds)
    }

    private static func timestamp(milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds) / 1_000
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
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

struct PlaybackCueMetadataPlan: Equatable {
    let displayTitle: String
    let timeRange: String
    /// Frames are relative to the metadata row origin.
    let displayTitleFrame: CGRect
    let timeRangeFrame: CGRect
}

@MainActor
enum PlaybackCueMetadataLayout {
    static func makePlan(
        metadata: PlaybackCueMetadata?,
        width: CGFloat
    ) -> PlaybackCueMetadataPlan? {
        guard let metadata, !metadata.isEmpty, width > 0 else {
            return nil
        }
        let hasDisplayTitle = !metadata.displayTitle
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTimeRange = !metadata.timeRange
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let desiredDisplayTitleWidth = hasDisplayTitle
            ? ceil((metadata.displayTitle as NSString).size(withAttributes: [
                .font: font,
            ]).width)
            : 0
        let desiredTimeWidth = hasTimeRange
            ? ceil((metadata.timeRange as NSString).size(withAttributes: [
                .font: font,
            ]).width)
            : 0
        let timeWidth = min(width, desiredTimeWidth)
        let gap = hasDisplayTitle && hasTimeRange && width > timeWidth
            ? min(
                PlaybackSubtitleFocusMetrics.metadataItemGap,
                width - timeWidth
            )
            : 0
        let displayTitleWidth = min(
            desiredDisplayTitleWidth,
            max(0, width - timeWidth - gap)
        )
        let timeX = hasDisplayTitle ? displayTitleWidth + gap : 0
        return PlaybackCueMetadataPlan(
            displayTitle: hasDisplayTitle ? metadata.displayTitle : "",
            timeRange: hasTimeRange ? metadata.timeRange : "",
            displayTitleFrame: CGRect(
                x: 0,
                y: 0,
                width: displayTitleWidth,
                height: PlaybackSubtitleFocusMetrics.metadataLineHeight
            ),
            timeRangeFrame: CGRect(
                x: timeX,
                y: 0,
                width: timeWidth,
                height: PlaybackSubtitleFocusMetrics.metadataLineHeight
            )
        )
    }

    static func draw(
        _ plan: PlaybackCueMetadataPlan?,
        in metadataRect: CGRect,
        isEnabled: Bool = true
    ) {
        guard let plan, metadataRect.width > 0, metadataRect.height > 0 else {
            return
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isEnabled
                ? PlaybackTheme.cueMetadataNative
                : WorkbenchRedesignColors.NS.textDisabled,
            .paragraphStyle: paragraphStyle,
        ]
        draw(
            plan.displayTitle,
            frame: plan.displayTitleFrame,
            metadataRect: metadataRect,
            attributes: attributes
        )
        draw(
            plan.timeRange,
            frame: plan.timeRangeFrame,
            metadataRect: metadataRect,
            attributes: attributes
        )
    }

    private static var font: NSFont {
        NSFont.systemFont(
            ofSize: PlaybackSubtitleFocusMetrics.metadataFontSize,
            weight: PlaybackSubtitleFocusMetrics.metadataFontWeight
        )
    }

    private static func draw(
        _ text: String,
        frame: CGRect,
        metadataRect: CGRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        guard !text.isEmpty, frame.width > 0, frame.height > 0 else {
            return
        }
        NSAttributedString(
            string: text,
            attributes: attributes
        ).draw(
            with: frame.offsetBy(
                dx: metadataRect.minX,
                dy: metadataRect.minY
            ),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
    }
}

struct PlaybackCueResultLayoutPlan {
    let itemID: AnyHashable
    let primaryCueIdentity: AnyHashable
    let showsCueGroup: Bool
    let isSelected: Bool
    let visualLinePlan: PlaybackVisualLineStackPlan
    let visualLines: [PlaybackCueResultVisualLine]
    let metadata: PlaybackCueMetadataPlan?
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
        return typographicRects(in: resultRect).compactMap { lineRect in
            let visibleRect = lineRect.intersection(resultRect)
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
        return CGRect(
            x: resultRect.minX,
            y: resultRect.minY + PlaybackSubtitleFocusMetrics.cueVerticalPadding,
            width: resultRect.width,
            height: visualLinePlan.resolvedContentHeight
        )
    }

    func metadataRect(in resultRect: CGRect) -> CGRect? {
        guard metadata != nil else {
            return nil
        }
        return CGRect(
            x: resultRect.minX,
            y: resultRect.minY
                + PlaybackSubtitleFocusMetrics.cueVerticalPadding
                + visualLinePlan.resolvedContentHeight
                + PlaybackSubtitleFocusMetrics.metadataCueGap,
            width: resultRect.width,
            height: PlaybackSubtitleFocusMetrics.metadataLineHeight
        )
    }
}

@MainActor
final class PlaybackCueResultLayout {
    private let visualLineLayout = PlaybackVisualLineStackLayout()
    private(set) var plan: PlaybackCueResultLayoutPlan?

    @discardableResult
    func prepare(
        result: PlaybackCueResult,
        showsCueGroup: Bool,
        isSelected: Bool,
        width: CGFloat,
        viewportHeight: CGFloat
    ) -> PlaybackCueResultLayoutPlan {
        let safeWidth = max(0, width)
        let cueTextWidth = safeWidth
        let visibleAdditionalCues = showsCueGroup
            ? result.additionalCueTexts
            : []

        let roles = [PlaybackCueResultLineRole.primaryCue]
            + visibleAdditionalCues.indices.map {
            PlaybackCueResultLineRole.additionalCue(index: $0)
        }
        let styles = [PlaybackCueResultTextStyle.primary] + Array(
            repeating: PlaybackCueResultTextStyle.cueGroup,
            count: visibleAdditionalCues.count
        )
        let texts = [result.primaryCueText] + visibleAdditionalCues
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
        let metadata = PlaybackCueMetadataLayout.makePlan(
            metadata: result.metadata,
            width: safeWidth
        )
        let metadataHeight = metadata == nil
            ? 0
            : PlaybackSubtitleFocusMetrics.metadataHeight
        let resolvedContentHeight = visualLinePlan.resolvedContentHeight
            + metadataHeight
        let naturalHeight = resolvedContentHeight
            + PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
        let safeViewportHeight = max(0, viewportHeight)
        let extent = PlaybackVirtualReelItemExtent(
            visualLineCount: visualLinePlan.visualLineCount,
            visualLineStackHeight: visualLinePlan.stackHeight,
            resolvedContentHeight: resolvedContentHeight,
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, safeViewportHeight),
            isOversized: naturalHeight > safeViewportHeight
        )
        let resolvedPlan = PlaybackCueResultLayoutPlan(
            itemID: result.itemID,
            primaryCueIdentity: result.primaryCueIdentity,
            showsCueGroup: showsCueGroup,
            isSelected: isSelected,
            visualLinePlan: visualLinePlan,
            visualLines: visualLines,
            metadata: metadata,
            resultWidth: safeWidth,
            cueTextWidth: cueTextWidth,
            extent: extent
        )
        plan = resolvedPlan
        return resolvedPlan
    }

    func drawPreparedPlan(
        in resultRect: CGRect,
        selectedTextRange: NSRange? = nil,
        isEnabled: Bool = true
    ) {
        guard let plan else {
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: resultRect).addClip()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let cueTextRect = plan.cueTextRect(in: resultRect)
        if let selectedTextRange {
            visualLineLayout.drawSelection(
                forUTF16Range: selectedTextRange,
                in: cueTextRect
            )
        }
        visualLineLayout.drawPreparedPlan(in: cueTextRect)
        if let metadataRect = plan.metadataRect(in: resultRect) {
            PlaybackCueMetadataLayout.draw(
                plan.metadata,
                in: metadataRect,
                isEnabled: isEnabled
            )
        }
    }

    func textSelectionHit(
        at point: CGPoint,
        in resultRect: CGRect,
        constrainedToLine lineUTF16Range: NSRange? = nil
    ) -> PlaybackTextSelectionHit? {
        guard let plan else {
            return nil
        }
        let visibleCueRect = plan.cueTextRect(in: resultRect)
            .intersection(resultRect)
        guard visibleCueRect.contains(point) else {
            return nil
        }
        return visualLineLayout.textSelectionHit(
            at: point,
            in: visibleCueRect,
            constrainedToLine: lineUTF16Range
        )
    }

    func selectedText(forUTF16Range range: NSRange) -> String? {
        visualLineLayout.selectedText(forUTF16Range: range)
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
        let hasMetadata: Bool
        let width: CGFloat
        let viewportHeight: CGFloat
        let styleRevision: Int
    }

    private struct Entry {
        let extent: PlaybackVirtualReelItemExtent
        var lastAccess: UInt64
    }

    private let capacity: Int
    private let layout: PlaybackCueResultLayout
    private var entries: [Key: Entry] = [:]
    private var accessSequence: UInt64 = 0
    private(set) var measurementCount = 0

    init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
        layout = PlaybackCueResultLayout()
    }

    var count: Int {
        entries.count
    }

    func extent(
        for result: PlaybackCueResult,
        showsCueGroup: Bool,
        isSelected _: Bool = false,
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
            hasMetadata: result.metadata?.isEmpty == false,
            width: width,
            viewportHeight: viewportHeight,
            styleRevision: 2
        )
        let baseExtent: PlaybackVirtualReelItemExtent
        if var entry = entries[key] {
            entry.lastAccess = accessSequence
            entries[key] = entry
            baseExtent = entry.extent
        } else {
            baseExtent = layout.prepare(
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
                extent: baseExtent,
                lastAccess: accessSequence
            )
            evictIfNeeded()
        }
        return baseExtent
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
