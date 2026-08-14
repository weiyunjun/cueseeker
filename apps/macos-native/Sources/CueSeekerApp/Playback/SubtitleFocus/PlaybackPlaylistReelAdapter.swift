import AppKit
import Foundation

/// Session-scoped presentation adapter between a complete Playback Cue Result
/// dataset and the shared viewport-virtualized Reel.
@MainActor
final class PlaybackCueResultReelAdapter: PlaybackVirtualReelContentAdapter {
    private let windowStore: PlaybackCueResultSessionWindowStore
    private let measurementCache: PlaybackCueResultMeasurementCache
    private let layout = PlaybackCueResultLayout()
    private let measurementCacheCapacity: Int
    private var presentationRevision: UInt64 = 0
    private var measurementAccessSequence: UInt64 = 0
    private var measuredOrdinalAccess: [Int: UInt64] = [:]
    private var isActive = true

    private(set) var showsCueGroup: Bool

    init(
        windowStore: PlaybackCueResultSessionWindowStore,
        showsCueGroup: Bool,
        measurementCacheCapacity: Int = 64
    ) {
        self.windowStore = windowStore
        self.showsCueGroup = showsCueGroup
        let resolvedCapacity = max(1, measurementCacheCapacity)
        self.measurementCacheCapacity = resolvedCapacity
        measurementCache = PlaybackCueResultMeasurementCache(
            capacity: resolvedCapacity
        )
    }

    var snapshot: PlaybackVirtualReelSnapshot {
        let windowSnapshot = windowStore.snapshot
        return PlaybackVirtualReelSnapshot(
            datasetID: reelDatasetID(from: windowSnapshot.datasetID),
            generation: windowSnapshot.generation,
            revision: windowSnapshot.revision &+ presentationRevision,
            totalCount: windowSnapshot.totalCount,
            loadedOrdinalRange: windowSnapshot.loadedOrdinalRange,
            loadedItemCount: windowSnapshot.loadedItemCount,
            isComplete: windowSnapshot.isComplete
        )
    }

    var measurementCacheCountForTesting: Int {
        measurementCache.count
    }

    var measuredOrdinalsForTesting: Set<Int> {
        Set(measuredOrdinalAccess.keys)
    }

    @discardableResult
    func setShowsCueGroup(_ showsCueGroup: Bool) -> Bool {
        guard isActive, self.showsCueGroup != showsCueGroup else {
            return false
        }
        self.showsCueGroup = showsCueGroup
        presentationRevision &+= 1
        invalidateMeasurements()
        return true
    }

    func item(at ordinal: Int) -> PlaybackCueResultItem? {
        guard isActive else {
            return nil
        }
        return windowStore.item(at: ordinal)
    }

    func cueResult(at ordinal: Int) -> PlaybackCueResult? {
        guard let item = item(at: ordinal), item.ordinal == ordinal else {
            return nil
        }
        return item.cueResult()
    }

    func itemID(at ordinal: Int) -> AnyHashable? {
        cueResult(at: ordinal)?.itemID
    }

    func extent(
        at ordinal: Int,
        isSelected: Bool,
        contentWidth: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String?
    ) -> PlaybackVirtualReelItemExtent? {
        guard let result = cueResult(at: ordinal) else {
            return nil
        }
        recordMeasuredOrdinal(ordinal)
        return measurementCache.extent(
            for: result,
            showsCueGroup: showsCueGroup,
            isSelected: isSelected,
            width: contentWidth,
            viewportHeight: viewportHeight,
            uiProbeScope: uiProbeScope
        )
    }

    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        isEnabled: Bool,
        selectedTextRange: NSRange?,
        in rect: CGRect
    ) {
        guard let result = cueResult(at: ordinal) else {
            return
        }
        layout.prepare(
            result: result,
            showsCueGroup: showsCueGroup,
            isSelected: isSelected,
            width: rect.width,
            viewportHeight: rect.height
        )
        layout.drawPreparedPlan(
            in: rect,
            selectedTextRange: selectedTextRange,
            isEnabled: isEnabled
        )
    }

    func textSelectionHit(
        at ordinal: Int,
        point: CGPoint,
        in rect: CGRect,
        constrainedToLine lineUTF16Range: NSRange?
    ) -> PlaybackTextSelectionHit? {
        guard let result = cueResult(at: ordinal) else {
            return nil
        }
        layout.prepare(
            result: result,
            showsCueGroup: showsCueGroup,
            isSelected: ordinal == windowStore.selectedOrdinal,
            width: rect.width,
            viewportHeight: rect.height
        )
        return layout.textSelectionHit(
            at: point,
            in: rect,
            constrainedToLine: lineUTF16Range
        )
    }

    func selectedText(at ordinal: Int, range: NSRange) -> String? {
        guard cueResult(at: ordinal) != nil else {
            return nil
        }
        return layout.selectedText(forUTF16Range: range)
    }

    func selectableTextRects(at ordinal: Int, in rect: CGRect) -> [CGRect] {
        guard let result = cueResult(at: ordinal) else {
            return []
        }
        let plan = layout.prepare(
            result: result,
            showsCueGroup: showsCueGroup,
            isSelected: ordinal == windowStore.selectedOrdinal,
            width: rect.width,
            viewportHeight: rect.height
        )
        return plan.visibleTypographicRects(in: rect)
    }

    func invalidateMeasurements() {
        measurementCache.removeAll()
        measuredOrdinalAccess.removeAll(keepingCapacity: true)
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        invalidateMeasurements()
        // A module View can disappear while the Overlay Session remains open.
        // The Session owns and destroys the window; this adapter owns only its
        // presentation caches.
    }

    private func reelDatasetID(from datasetID: AnyHashable) -> AnyHashable {
        guard let uuid = datasetID.base as? UUID else {
            return datasetID
        }
        return AnyHashable(uuid.uuidString)
    }

    private func recordMeasuredOrdinal(_ ordinal: Int) {
        measurementAccessSequence &+= 1
        measuredOrdinalAccess[ordinal] = measurementAccessSequence
        while measuredOrdinalAccess.count > measurementCacheCapacity,
              let oldestOrdinal = measuredOrdinalAccess.min(by: {
                  $0.value < $1.value
              })?.key {
            measuredOrdinalAccess.removeValue(forKey: oldestOrdinal)
        }
    }
}

typealias PlaybackPlaylistReelAdapter = PlaybackCueResultReelAdapter
