import AppKit
import CueSeekerCore

struct PlaybackVirtualReelItemExtent: Equatable {
    let visualLineCount: Int
    let visualLineStackHeight: CGFloat
    let resolvedContentHeight: CGFloat
    let firstVisualLineCenterOffset: CGFloat
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

typealias PlaybackTextSelectionHit = (
    lineUTF16Range: NSRange,
    utf16Offset: Int,
    boundaryPoint: CGPoint
)

@MainActor
protocol PlaybackVirtualReelContentAdapter: AnyObject {
    var snapshot: PlaybackVirtualReelSnapshot { get }
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
    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        isEnabled: Bool,
        selectedTextRange: NSRange?,
        in rect: CGRect
    )
    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        selectionProgress: CGFloat,
        isEnabled: Bool,
        selectedTextRange: NSRange?,
        in rect: CGRect
    )
    func textSelectionHit(
        at ordinal: Int,
        point: CGPoint,
        in rect: CGRect,
        constrainedToLine lineUTF16Range: NSRange?
    ) -> PlaybackTextSelectionHit?
    func selectableTextRects(at ordinal: Int, in rect: CGRect) -> [CGRect]
    func selectedText(at ordinal: Int, range: NSRange) -> String?
    func invalidateMeasurements()
    func invalidate()
}

extension PlaybackVirtualReelContentAdapter {
    var measurementCacheCountForTesting: Int {
        0
    }

    var measuredOrdinalsForTesting: Set<Int> {
        []
    }

    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        isEnabled: Bool,
        selectedTextRange: NSRange?,
        in rect: CGRect
    ) {
        drawItem(
            at: ordinal,
            isSelected: isSelected,
            selectionProgress: isSelected ? 1 : 0,
            isEnabled: isEnabled,
            selectedTextRange: selectedTextRange,
            in: rect
        )
    }

    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        selectionProgress _: CGFloat,
        isEnabled: Bool,
        selectedTextRange: NSRange?,
        in rect: CGRect
    ) {
        drawItem(
            at: ordinal,
            isSelected: isSelected,
            isEnabled: isEnabled,
            selectedTextRange: selectedTextRange,
            in: rect
        )
    }

    func textSelectionHit(
        at ordinal: Int,
        point: CGPoint,
        in rect: CGRect,
        constrainedToLine lineUTF16Range: NSRange?
    ) -> PlaybackTextSelectionHit? {
        nil
    }

    func selectedText(at ordinal: Int, range: NSRange) -> String? {
        nil
    }

    func selectableTextRects(at ordinal: Int, in rect: CGRect) -> [CGRect] {
        []
    }
}

struct PlaybackVirtualReelLayout: Equatable {
    static let overscanItemCount = 4

    let viewportSize: CGSize
    let totalCount: Int
    let focusAnchorY: CGFloat
    let loadedOrdinalRange: Range<Int>
    let fractionalOrdinal: CGFloat
    let usesFullWidth: Bool

    init(
        viewportSize: CGSize,
        totalCount: Int,
        loadedOrdinalRange: Range<Int>,
        fractionalOrdinal: CGFloat,
        usesFullWidth: Bool = false
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
        self.usesFullWidth = usesFullWidth
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
        let insetWidth = viewportSize.width - PlaybackSubtitleFocusMetrics.contentInset * 2
        return max(
            0,
            usesFullWidth
                ? insetWidth
                : min(
                    PlaybackSubtitleFocusMetrics.contentMaxWidth,
                    insetWidth
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
            styleRevision: 2
        )
        let natural: PlaybackSubtitleFocusCueMeasurement
        if var entry = entries[key] {
            entry.lastAccess = accessSequence
            entries[key] = entry
            natural = entry.measurement
        } else {
            natural = measurer.measurement(
                text: cue.text,
                width: width,
                viewportHeight: .greatestFiniteMagnitude
            )
            measurementCount += 1
            UIInvalidationProbe.count(
                "playback.subtitle_focus.cue_measurement",
                scope: uiProbeScope,
                details: "ordinal=\(cue.ordinal)"
            )
            entries[key] = Entry(
                measurement: natural,
                ordinal: cue.ordinal,
                lastAccess: accessSequence
            )
            evictIfNeeded()
        }

        let safeViewportHeight = max(0, viewportHeight)
        return PlaybackSubtitleFocusCueMeasurement(
            visualLineCount: natural.visualLineCount,
            visualLineStackHeight: natural.visualLineStackHeight,
            resolvedContentHeight: natural.resolvedContentHeight,
            firstVisualLineCenterOffset: natural.firstVisualLineCenterOffset,
            naturalHeight: natural.naturalHeight,
            resolvedHeight: min(natural.naturalHeight, safeViewportHeight),
            isOversized: natural.naturalHeight > safeViewportHeight
        )
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

    private static let cueLayoutCacheCapacity = 64
    private let datasetID = AnyHashable("current")
    private let measurementCache = PlaybackSubtitleFocusCueMeasurementCache()
    private let textLayout = PlaybackSubtitleFocusNativeTextLayout()
    private var cueLayouts: [Int64: PlaybackSubtitleFocusNativeTextLayout] = [:]
    private var cueLayoutAccess: [Int64: UInt64] = [:]
    private var cueLayoutAccessSequence: UInt64 = 0
    private var lastSelectionTextLayout: PlaybackSubtitleFocusNativeTextLayout?
    private var cues: [SubtitleFocusCue] = []
    private var firstLoadedOrdinal = 0
    private var signature: SnapshotSignature?
    private var revision: UInt64 = 0
    private var displayTitle = ""
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

    func geometryPreparationCountForTesting(at ordinal: Int) -> Int {
        guard let cue = cue(at: ordinal) else {
            return 0
        }
        return cueLayouts[cue.id]?.geometryPreparationCountForTesting ?? 0
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
        isSelected _: Bool,
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
        guard metadata(for: cue) != nil else {
            return baseMeasurement
        }
        return addingMetadataHeight(
            to: baseMeasurement,
            viewportHeight: viewportHeight
        )
    }

    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        selectionProgress: CGFloat,
        isEnabled: Bool,
        selectedTextRange: NSRange?,
        in rect: CGRect
    ) {
        guard let cue = cue(at: ordinal) else {
            return
        }
        let cueRect = cueTextRect(in: rect, for: cue)
        let cueTextLayout = cachedTextLayout(for: cue.id)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        defer { NSGraphicsContext.restoreGraphicsState() }
        cueTextLayout.draw(
            text: cue.text,
            color: isEnabled
                ? PlaybackTheme.subtitleFocusCuePrimaryNative(
                    selectionProgress: selectionProgress
                )
                : WorkbenchRedesignColors.NS.textDisabled,
            selectedTextRange: selectedTextRange,
            in: cueRect
        )
        let metadata = metadata(for: cue)
        PlaybackCueMetadataLayout.draw(
            PlaybackCueMetadataLayout.makePlan(
                metadata: metadata,
                width: rect.width
            ),
            in: metadataRect(in: rect, for: cue),
            isSelected: isSelected,
            selectionProgress: selectionProgress,
            isEnabled: isEnabled
        )
    }

    func textSelectionHit(
        at ordinal: Int,
        point: CGPoint,
        in rect: CGRect,
        constrainedToLine lineUTF16Range: NSRange?
    ) -> PlaybackTextSelectionHit? {
        guard let cue = cue(at: ordinal) else {
            return nil
        }
        let cueTextLayout = cachedTextLayout(for: cue.id)
        lastSelectionTextLayout = cueTextLayout
        return cueTextLayout.textSelectionHit(
            text: cue.text,
            point: point,
            in: cueTextRect(in: rect, for: cue),
            constrainedToLine: lineUTF16Range
        )
    }

    func selectedText(at ordinal: Int, range: NSRange) -> String? {
        guard let cue = cue(at: ordinal) else {
            return nil
        }
        let resolvedLayout = cueLayouts[cue.id]
            ?? lastSelectionTextLayout
            ?? textLayout
        return resolvedLayout.selectedText(range: range)
    }

    func selectableTextRects(at ordinal: Int, in rect: CGRect) -> [CGRect] {
        guard let cue = cue(at: ordinal) else {
            return []
        }
        let cueTextLayout = cachedTextLayout(for: cue.id)
        return cueTextLayout.visibleLineRects(
            text: cue.text,
            in: cueTextRect(in: rect, for: cue)
        )
    }

    func invalidate() {
        cues.removeAll(keepingCapacity: false)
        firstLoadedOrdinal = 0
        signature = nil
        displayTitle = ""
        invalidateMeasurements()
    }

    func invalidateMeasurements() {
        measurementCache.removeAll()
        cueLayouts.removeAll(keepingCapacity: true)
        cueLayoutAccess.removeAll(keepingCapacity: true)
        lastSelectionTextLayout = nil
    }

    private func cueTextRect(
        in rect: CGRect,
        for cue: SubtitleFocusCue
    ) -> CGRect {
        let baseMeasurement = naturalMeasurement(for: cue, width: rect.width)
        return CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: min(rect.height, baseMeasurement.naturalHeight)
        )
    }

    func metadata(at ordinal: Int) -> PlaybackCueMetadata? {
        cue(at: ordinal).flatMap(metadata(for:))
    }

    private func cue(at ordinal: Int) -> SubtitleFocusCue? {
        let index = ordinal - firstLoadedOrdinal
        guard cues.indices.contains(index), cues[index].ordinal == ordinal else {
            return nil
        }
        return cues[index]
    }

    private func metadata(for cue: SubtitleFocusCue) -> PlaybackCueMetadata? {
        guard !displayTitle.isEmpty else {
            return nil
        }
        return PlaybackCueMetadata(
            displayTitle: displayTitle,
            timeRange: PlaybackCueInformationText.timeRange(
                startMilliseconds: cue.startMilliseconds,
                endMilliseconds: cue.endMilliseconds
            )
        )
    }

    private func naturalMeasurement(
        for cue: SubtitleFocusCue,
        width: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        measurementCache.measurement(
            for: cue,
            width: width,
            viewportHeight: .greatestFiniteMagnitude
        )
    }

    private func metadataRect(
        in rect: CGRect,
        for cue: SubtitleFocusCue
    ) -> CGRect {
        let baseMeasurement = naturalMeasurement(for: cue, width: rect.width)
        return CGRect(
            x: rect.minX,
            y: rect.minY
                + PlaybackSubtitleFocusMetrics.cueVerticalPadding
                + baseMeasurement.resolvedContentHeight
                + PlaybackSubtitleFocusMetrics.metadataCueGap,
            width: rect.width,
            height: PlaybackSubtitleFocusMetrics.metadataLineHeight
        )
    }

    private func addingMetadataHeight(
        to base: PlaybackSubtitleFocusCueMeasurement,
        viewportHeight: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        let metadataHeight = PlaybackSubtitleFocusMetrics.metadataHeight
        let naturalHeight = base.naturalHeight + metadataHeight
        let safeViewportHeight = max(0, viewportHeight)
        return PlaybackSubtitleFocusCueMeasurement(
            visualLineCount: base.visualLineCount,
            visualLineStackHeight: base.visualLineStackHeight,
            resolvedContentHeight:
                base.resolvedContentHeight + metadataHeight,
            firstVisualLineCenterOffset: base.firstVisualLineCenterOffset,
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, safeViewportHeight),
            isOversized: naturalHeight > safeViewportHeight
        )
    }

    private func cachedTextLayout(
        for cueID: Int64
    ) -> PlaybackSubtitleFocusNativeTextLayout {
        cueLayoutAccessSequence &+= 1
        if let existing = cueLayouts[cueID] {
            cueLayoutAccess[cueID] = cueLayoutAccessSequence
            return existing
        }
        let created = PlaybackSubtitleFocusNativeTextLayout()
        cueLayouts[cueID] = created
        cueLayoutAccess[cueID] = cueLayoutAccessSequence
        while cueLayouts.count > Self.cueLayoutCacheCapacity,
              let oldestID = cueLayoutAccess.min(by: {
                  $0.value < $1.value
              })?.key {
            cueLayouts.removeValue(forKey: oldestID)
            cueLayoutAccess.removeValue(forKey: oldestID)
        }
        return created
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
        guard totalCount > visibleCueCapacity else {
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
