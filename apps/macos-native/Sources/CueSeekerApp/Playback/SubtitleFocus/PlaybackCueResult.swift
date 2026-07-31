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
    /// Context rendered as independent Badges above the Cue.
    let informationBadges: [String]

    init(
        itemID: AnyHashable,
        primaryCueIdentity: AnyHashable,
        primaryCueText: String,
        additionalCueTexts: [String] = [],
        informationBadges: [String] = []
    ) {
        self.itemID = itemID
        self.primaryCueIdentity = primaryCueIdentity
        self.primaryCueText = primaryCueText
        self.additionalCueTexts = additionalCueTexts
        self.informationBadges = informationBadges
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

struct PlaybackCueInformationBadgePlan: Equatable {
    let text: String
    /// Relative to the Result content width and top padding.
    let frame: CGRect
}

@MainActor
enum PlaybackCueInformationBadgeLayout {
    static func makePlans(
        texts: [String],
        width: CGFloat
    ) -> [PlaybackCueInformationBadgePlan] {
        let resolvedTexts = texts.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !resolvedTexts.isEmpty, width > 0 else {
            return []
        }
        let horizontalPadding = PlaybackSubtitleFocusMetrics
            .informationBadgeHorizontalPadding
        let gap = PlaybackSubtitleFocusMetrics.informationBadgeGap
        let rowHeight = PlaybackSubtitleFocusMetrics.informationBadgeRowHeight
        let availableBadgeWidth = max(
            0,
            width - CGFloat(resolvedTexts.count - 1) * gap
        )
        let desiredWidths = resolvedTexts.map { text in
            ceil((text as NSString).size(withAttributes: [
                .font: font,
            ]).width) + horizontalPadding * 2
        }
        let minimumWidth = min(
            horizontalPadding * 2 + 1,
            availableBadgeWidth / CGFloat(resolvedTexts.count)
        )
        let flexibleTotal = desiredWidths.reduce(0) {
            $0 + max(0, $1 - minimumWidth)
        }
        let availableFlexibleWidth = max(
            0,
            availableBadgeWidth
                - minimumWidth * CGFloat(resolvedTexts.count)
        )
        let scale = flexibleTotal > 0
            ? min(1, availableFlexibleWidth / flexibleTotal)
            : 0
        var nextX: CGFloat = 0
        return zip(resolvedTexts, desiredWidths).map { text, desiredWidth in
            let badgeWidth = minimumWidth
                + max(0, desiredWidth - minimumWidth) * scale
            defer { nextX += badgeWidth + gap }
            return PlaybackCueInformationBadgePlan(
                text: text,
                frame: CGRect(
                    x: nextX,
                    y: 0,
                    width: badgeWidth,
                    height: rowHeight
                )
            )
        }
    }

    static func draw(
        _ plans: [PlaybackCueInformationBadgePlan],
        in resultRect: CGRect,
        isSelected: Bool,
        isEnabled: Bool = true
    ) {
        guard !plans.isEmpty else {
            return
        }
        let horizontalPadding = PlaybackSubtitleFocusMetrics
            .informationBadgeHorizontalPadding
        let verticalPadding = PlaybackSubtitleFocusMetrics
            .informationBadgeVerticalPadding
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let backgroundColor = isSelected
            ? PlaybackTheme.informationBadgeBackgroundNative
            : PlaybackTheme.informationBadgeUnselectedBackgroundNative
        let textColor = isSelected
            ? PlaybackTheme.informationBadgeTextNative
            : isEnabled
                ? PlaybackTheme.informationBadgeUnselectedTextNative
                : WorkbenchRedesignColors.NS.textDisabled

        for plan in plans {
            let frame = plan.frame.offsetBy(
                dx: resultRect.minX,
                dy: resultRect.minY
                    + PlaybackSubtitleFocusMetrics.cueVerticalPadding
            )
            guard frame.width > 0, frame.height > 0 else {
                continue
            }
            backgroundColor.setFill()
            NSBezierPath(
                roundedRect: frame,
                xRadius: PlaybackSubtitleFocusMetrics.informationBadgeRadius,
                yRadius: PlaybackSubtitleFocusMetrics.informationBadgeRadius
            ).fill()
            NSAttributedString(
                string: plan.text,
                attributes: [
                    .font: font,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle,
                ]
            ).draw(
                with: frame.insetBy(
                    dx: horizontalPadding,
                    dy: verticalPadding
                ),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
            )
        }
    }

    private static var font: NSFont {
        NSFont.systemFont(
            ofSize: PlaybackSubtitleFocusMetrics.informationBadgeFontSize,
            weight: .semibold
        )
    }
}

@MainActor
final class PlaybackCueInformationBadgePlanCache {
    private struct Key: Hashable {
        let texts: [String]
        let width: CGFloat
    }

    private struct Entry {
        let plans: [PlaybackCueInformationBadgePlan]
        var lastAccess: UInt64
    }

    private let capacity: Int
    private var entries: [Key: Entry] = [:]
    private var accessSequence: UInt64 = 0
    private(set) var preparationCount = 0

    init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }

    var count: Int {
        entries.count
    }

    func plans(
        texts: [String],
        width: CGFloat
    ) -> [PlaybackCueInformationBadgePlan] {
        accessSequence &+= 1
        let key = Key(texts: texts, width: width)
        if var entry = entries[key] {
            entry.lastAccess = accessSequence
            entries[key] = entry
            return entry.plans
        }
        let plans = PlaybackCueInformationBadgeLayout.makePlans(
            texts: texts,
            width: width
        )
        preparationCount += 1
        entries[key] = Entry(
            plans: plans,
            lastAccess: accessSequence
        )
        evictIfNeeded()
        return plans
    }

    func removeAll() {
        entries.removeAll(keepingCapacity: true)
        accessSequence = 0
        preparationCount = 0
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

struct PlaybackCueResultLayoutPlan {
    let itemID: AnyHashable
    let primaryCueIdentity: AnyHashable
    let showsCueGroup: Bool
    let isSelected: Bool
    let visualLinePlan: PlaybackVisualLineStackPlan
    let visualLines: [PlaybackCueResultVisualLine]
    let informationBadges: [PlaybackCueInformationBadgePlan]
    let informationRowHeight: CGFloat
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
        let informationOffset = informationBadges.isEmpty
            ? 0
            : informationRowHeight + PlaybackSubtitleFocusMetrics.informationCueGap
        return CGRect(
            x: resultRect.minX,
            y: resultRect.minY
                + PlaybackSubtitleFocusMetrics.cueVerticalPadding
                + informationOffset,
            width: resultRect.width,
            height: max(
                0,
                resultRect.height
                    - PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
                    - informationOffset
            )
        )
    }

    func informationBadgeRects(in resultRect: CGRect) -> [CGRect] {
        informationBadges.map { badge in
            badge.frame.offsetBy(
                dx: resultRect.minX,
                dy: resultRect.minY
                    + PlaybackSubtitleFocusMetrics.cueVerticalPadding
            )
        }
    }
}

@MainActor
final class PlaybackCueResultLayout {
    private let visualLineLayout = PlaybackVisualLineStackLayout()
    private let informationBadgePlanCache: PlaybackCueInformationBadgePlanCache
    private(set) var plan: PlaybackCueResultLayoutPlan?

    init(informationBadgeCacheCapacity: Int = 64) {
        informationBadgePlanCache = PlaybackCueInformationBadgePlanCache(
            capacity: informationBadgeCacheCapacity
        )
    }

    var informationBadgePlanCacheCountForTesting: Int {
        informationBadgePlanCache.count
    }

    var informationBadgePlanPreparationCountForTesting: Int {
        informationBadgePlanCache.preparationCount
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
        let informationBadges = informationBadgePlanCache.plans(
            texts: result.informationBadges,
            width: safeWidth
        )
        let informationRowHeight = informationBadges.isEmpty
            ? 0
            : PlaybackSubtitleFocusMetrics.informationBadgeRowHeight
        let informationOffset = informationBadges.isEmpty
            ? 0
            : informationRowHeight
                + PlaybackSubtitleFocusMetrics.informationCueGap
        let resolvedContentHeight = informationOffset
            + visualLinePlan.resolvedContentHeight
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
            informationBadges: informationBadges,
            informationRowHeight: informationRowHeight,
            resultWidth: safeWidth,
            cueTextWidth: cueTextWidth,
            extent: extent
        )
        plan = resolvedPlan
        return resolvedPlan
    }

    func drawPreparedPlan(
        in resultRect: CGRect,
        selectedTextRange: NSRange? = nil
    ) {
        guard let plan else {
            return
        }
        PlaybackCueInformationBadgeLayout.draw(
            plan.informationBadges,
            in: resultRect,
            isSelected: plan.isSelected
        )
        let cueTextRect = plan.cueTextRect(in: resultRect)
        if let selectedTextRange {
            visualLineLayout.drawSelection(
                forUTF16Range: selectedTextRange,
                in: cueTextRect
            )
        }
        visualLineLayout.drawPreparedPlan(in: cueTextRect)
    }

    func textSelectionHit(
        at point: CGPoint,
        in resultRect: CGRect,
        constrainedToVisualLine visualLineIndex: Int? = nil
    ) -> (visualLineIndex: Int, utf16Offset: Int)? {
        guard let plan else {
            return nil
        }
        return visualLineLayout.textSelectionHit(
            at: point,
            in: plan.cueTextRect(in: resultRect),
            constrainedToVisualLine: visualLineIndex
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
        let hasInformationBadges: Bool
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
        layout = PlaybackCueResultLayout(
            informationBadgeCacheCapacity: capacity
        )
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
            hasInformationBadges: result.informationBadges.contains {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            },
            width: width,
            viewportHeight: viewportHeight,
            styleRevision: 1
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
