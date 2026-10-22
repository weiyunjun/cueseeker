import AppKit
import CueSeekerCore
import SwiftUI

struct PlaybackCueTimelineRowLayout: Equatable {
    let markerRect: CGRect
    let cueRect: CGRect
}

@MainActor
enum PlaybackCueTimelineLayout {
    static func leadingAccessoryWidth(usesCheckbox: Bool) -> CGFloat {
        guard usesCheckbox else {
            return 0
        }
        return PlaybackCollageSelectionMetrics.checkboxSize
            + PlaybackCueTimelineMetrics.markerHorizontalGap
    }

    static func rowLayout(
        in rowRect: CGRect,
        usesCheckbox: Bool,
        markerCenterY: CGFloat? = nil
    ) -> PlaybackCueTimelineRowLayout {
        guard usesCheckbox else {
            return PlaybackCueTimelineRowLayout(
                markerRect: .zero,
                cueRect: rowRect
            )
        }
        let markerSize = PlaybackCollageSelectionMetrics.checkboxSize
        let resolvedMarkerCenterY = markerCenterY
            ?? rowRect.minY
            + PlaybackSubtitleFocusMetrics.cueVerticalPadding
            + PlaybackSubtitleFocusMetrics.cueLineHeight / 2
        let markerY = resolvedMarkerCenterY - markerSize / 2
        let cueX = rowRect.minX
            + markerSize
            + PlaybackCueTimelineMetrics.markerHorizontalGap
        return PlaybackCueTimelineRowLayout(
            markerRect: CGRect(
                x: rowRect.minX,
                y: markerY,
                width: markerSize,
                height: markerSize
            ),
            cueRect: CGRect(
                x: cueX,
                y: rowRect.minY,
                width: max(0, rowRect.maxX - cueX),
                height: rowRect.height
            )
        )
    }

    static func connectorRect(
        from current: PlaybackCueTimelineRowLayout,
        to next: PlaybackCueTimelineRowLayout
    ) -> CGRect? {
        guard !current.markerRect.isEmpty, !next.markerRect.isEmpty else {
            return nil
        }
        let startY = current.markerRect.maxY
            + PlaybackCueTimelineMetrics.connectorMarkerGap
        let endY = next.markerRect.minY
            - PlaybackCueTimelineMetrics.connectorMarkerGap
        guard endY > startY else {
            return nil
        }
        return CGRect(
            x: current.markerRect.midX
                - PlaybackCueTimelineMetrics.connectorWidth / 2,
            y: startY,
            width: PlaybackCueTimelineMetrics.connectorWidth,
            height: endY - startY
        )
    }

    static func drawConnector(in rect: CGRect) {
        PlaybackTheme.cueTimelineMutedNative.setFill()
        NSBezierPath(rect: rect).fill()
    }
}

@MainActor
enum PlaybackCollageCheckboxDrawing {
    static func draw(
        isSelected: Bool,
        isEnabled: Bool,
        in rect: CGRect
    ) {
        WorkbenchCheckboxStyle.drawAppKitGlyph(
            for: isSelected ? .checked : .unchecked,
            isEnabled: isEnabled,
            size: PlaybackCollageSelectionMetrics.checkboxSize,
            in: rect
        )
    }

    static func image(
        isSelected: Bool,
        isEnabled: Bool
    ) -> NSImage? {
        WorkbenchCheckboxStyle.appKitImage(
            for: isSelected ? .checked : .unchecked,
            isEnabled: isEnabled,
            size: PlaybackCollageSelectionMetrics.checkboxSize
        )
    }

    static func color(
        isSelected: Bool,
        isEnabled: Bool
    ) -> NSColor {
        WorkbenchCheckboxStyle.controlColor(
            for: isSelected ? .checked : .unchecked,
            isEnabled: isEnabled
        )
    }
}

final class PlaybackSubtitleFocusReelDocumentView: NSView, PointerShapeProviding {
    private struct TextSelection {
        let ordinal: Int
        let itemID: AnyHashable
        let lineUTF16Range: NSRange
        let anchorUTF16Offset: Int
        let anchorPoint: CGPoint
        var focusUTF16Offset: Int
        var focusPoint: CGPoint

        var range: NSRange {
            let lower = min(anchorUTF16Offset, focusUTF16Offset)
            return NSRange(
                location: lower,
                length: max(anchorUTF16Offset, focusUTF16Offset) - lower
            )
        }
    }

    var uiProbeScope: String?
    var onToggleCollageCueSelection: (Int) -> Void = { _ in }
    /// The text, the cue it came from, and where the menu hangs off inside that
    /// cue. A point in the document is no use on its own: the reel scrolls by
    /// laying its cues out somewhere else, so only the place inside the cue
    /// stays true.
    var onPresentSelectedTextActions: (String, Int, CGPoint) -> Void = { _, _, _ in }
    var onDismissSelectedTextActions: () -> Void = {}
    private var layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: .zero,
        totalCount: 0,
        loadedOrdinalRange: 0..<0,
        fractionalOrdinal: 0
    )
    private var contentAdapter: (any PlaybackVirtualReelContentAdapter)?
    private var contentSnapshot: PlaybackVirtualReelSnapshot?
    private var selectedOrdinal: Int?
    private var collageSelectedCueIDs: Set<Int64>?
    private var collageCanSelectAnotherCue = true
    private var textSelection: TextSelection?
    private(set) var placements: [PlaybackSubtitleFocusCuePlacement] = []
    /// Set while a drag started in this view is choosing text.
    private var isSelectingText = false
    private var pendingCollageCueOrdinal: Int?

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
        clearTextSelection()
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

    func updateCollageSelection(
        selectedCueIDs: Set<Int64>?,
        canSelectAnotherCue: Bool
    ) {
        guard collageSelectedCueIDs != selectedCueIDs
                || collageCanSelectAnotherCue != canSelectAnotherCue
        else {
            return
        }
        let changesMode = (collageSelectedCueIDs == nil) != (selectedCueIDs == nil)
        let changesAvailability = collageCanSelectAnotherCue != canSelectAnotherCue
        let changedCueIDs = (collageSelectedCueIDs ?? [])
            .symmetricDifference(selectedCueIDs ?? [])
        UIInvalidationProbe.count(
            "playback.subtitle_focus.collage_selection_update",
            scope: uiProbeScope,
            details: "changed=\(changedCueIDs.count)"
        )
        collageSelectedCueIDs = selectedCueIDs
        collageCanSelectAnotherCue = canSelectAnotherCue

        if changesMode {
            clearTextSelection()
            pendingCollageCueOrdinal = nil
            UIInvalidationProbe.count(
                "playback.subtitle_focus.collage_full_invalidation",
                scope: uiProbeScope,
                details: "reason=mode"
            )
            resolveLocalPlacementsIfNeeded()
            needsDisplay = true
        } else if changesAvailability {
            UIInvalidationProbe.count(
                "playback.subtitle_focus.collage_full_invalidation",
                scope: uiProbeScope,
                details: "reason=availability"
            )
            needsDisplay = true
        } else {
            for placement in placements {
                guard let cueID = cueID(at: placement.ordinal),
                      changedCueIDs.contains(cueID)
                else {
                    continue
                }
                UIInvalidationProbe.count(
                    "playback.subtitle_focus.collage_row_invalidation",
                    scope: uiProbeScope,
                    details: "ordinal=\(placement.ordinal)"
                )
                invalidateRow(placement.ordinal)
            }
        }
    }

    func updateLocalLayout(_ layout: PlaybackSubtitleFocusVirtualReelLayout) {
        guard self.layout != layout else {
            return
        }
        if self.layout.contentWidth != layout.contentWidth {
            clearTextSelection()
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
        collageSelectedCueIDs = nil
        collageCanSelectAnotherCue = true
        textSelection = nil
        placements.removeAll(keepingCapacity: false)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let visibleDirtyRect = dirtyRect.intersection(visibleRect)
        guard !visibleDirtyRect.isNull, !visibleDirtyRect.isEmpty else {
            return
        }
        for connectorRect in cueTimelineConnectorRects
        where connectorRect.intersects(visibleDirtyRect) {
            PlaybackCueTimelineLayout.drawConnector(in: connectorRect)
        }
        for placement in placements where placement.rect.intersects(visibleDirtyRect) {
            UIInvalidationProbe.count(
                "playback.subtitle_focus.cue_draw",
                scope: uiProbeScope,
                details: "ordinal=\(placement.ordinal)"
            )
            let isChecked = isCollageCueChecked(at: placement.ordinal)
            let canToggle = !isEditingCollage
                || isChecked
                || collageCanSelectAnotherCue
            contentAdapter?.drawItem(
                at: placement.ordinal,
                isSelected: placement.ordinal == selectedOrdinal,
                isEnabled: canToggle,
                selectedTextRange: textSelection?.ordinal == placement.ordinal
                    ? textSelection?.range
                    : nil,
                in: cueContentRect(for: placement.rect)
            )
            if isEditingCollage {
                let timelineLayout = cueTimelineRowLayout(for: placement)
                PlaybackCollageCheckboxDrawing.draw(
                    isSelected: isChecked,
                    isEnabled: canToggle,
                    in: timelineLayout.markerRect
                )
            }
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
        let point = convert(event.locationInWindow, from: nil)
        clearTextSelection()
        if let placement = collagePlacement(containing: point) {
            pendingCollageCueOrdinal = placement.ordinal
            isSelectingText = false
            return
        }
        pendingCollageCueOrdinal = nil
        beginTextSelection(at: point)
        isSelectingText = textSelection != nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelectingText else {
            return
        }
        updateTextSelection(
            focusPoint: convert(event.locationInWindow, from: nil)
        )
    }

    override func mouseUp(with event: NSEvent) {
        if let pendingOrdinal = pendingCollageCueOrdinal {
            pendingCollageCueOrdinal = nil
            let point = convert(event.locationInWindow, from: nil)
            if bounds.contains(point),
               let placement = collagePlacement(containing: point),
               placement.ordinal == pendingOrdinal {
                _ = toggleCollageCue(at: pendingOrdinal)
            }
            return
        }

        // A release only ends a drag this view began. The press that closes an
        // open menu is swallowed before it reaches here, and its release must
        // not be read as a finished selection and open the menu straight back
        // up.
        guard isSelectingText else {
            return
        }
        isSelectingText = false

        let point = convert(event.locationInWindow, from: nil)
        updateTextSelection(focusPoint: point)
        guard let textSelection,
              textSelection.range.length > 0,
              let text = contentAdapter?.selectedText(
                  at: textSelection.ordinal,
                  range: textSelection.range
              ),
              !text.isEmpty,
              let cueOrigin = cueContentOrigin(at: textSelection.ordinal)
        else {
            clearTextSelection()
            return
        }
        let anchorPoint = textSelection.focusUTF16Offset
            >= textSelection.anchorUTF16Offset
            ? textSelection.focusPoint
            : textSelection.anchorPoint
        onPresentSelectedTextActions(
            text,
            textSelection.ordinal,
            CGPoint(
                x: anchorPoint.x - cueOrigin.x,
                y: anchorPoint.y - cueOrigin.y
            )
        )
    }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: AppPointerShape.rectCursor)
    }

    /// The reel's answer to the pointer, asked by `AppPointerShape` when the
    /// pointer really moved: the I-beam over selectable cue text, the arrow
    /// elsewhere and throughout collage editing.
    func pointerShape(atWindowPoint windowPoint: CGPoint) -> PointerShape {
        guard !isEditingCollage, let contentAdapter else {
            return .arrow
        }
        let point = convert(windowPoint, from: nil)
        guard let placement = textPlacement(containing: point) else {
            return .arrow
        }
        let isOverText = contentAdapter.selectableTextRects(
            at: placement.ordinal,
            in: cueContentRect(for: placement.rect)
        ).contains { $0.contains(point) }
        return isOverText ? .iBeam : .arrow
    }

    func toggleCollageCueForTesting(at ordinal: Int) -> Bool {
        toggleCollageCue(at: ordinal)
    }

    func toggleCollageCueForTesting(at point: CGPoint) -> Bool {
        guard let placement = collagePlacement(containing: point) else {
            return false
        }
        return toggleCollageCue(at: placement.ordinal)
    }

    func collageCheckboxRectForTesting(at ordinal: Int) -> CGRect? {
        placements.first { $0.ordinal == ordinal }.map(collageCheckboxRect)
    }

    func cueContentRectForTesting(at ordinal: Int) -> CGRect? {
        placements.first { $0.ordinal == ordinal }.map {
            cueContentRect(for: $0.rect)
        }
    }

    var hasTextSelectionForTesting: Bool {
        textSelection != nil
    }

    /// The lines of a cue that can be selected, where they sit in the document.
    func selectableTextRectsForTesting(at ordinal: Int) -> [CGRect] {
        guard let placement = placements.first(where: { $0.ordinal == ordinal }),
              let contentAdapter
        else {
            return []
        }
        return contentAdapter.selectableTextRects(
            at: ordinal,
            in: cueContentRect(for: placement.rect)
        )
    }

    var cueTimelineConnectorRectsForTesting: [CGRect] {
        cueTimelineConnectorRects
    }

    func isCueHighlightedForTesting(at ordinal: Int) -> Bool {
        ordinal == selectedOrdinal
    }

    func isCollageCueEnabledForTesting(at ordinal: Int) -> Bool {
        !isEditingCollage
            || isCollageCueChecked(at: ordinal)
            || collageCanSelectAnotherCue
    }

    private func beginTextSelection(at point: CGPoint) {
        guard let placement = textPlacement(containing: point),
              let itemID = contentAdapter?.itemID(at: placement.ordinal),
              let hit = contentAdapter?.textSelectionHit(
                  at: placement.ordinal,
                  point: point,
                  in: cueContentRect(for: placement.rect),
                  constrainedToLine: nil
              )
        else {
            return
        }
        textSelection = TextSelection(
            ordinal: placement.ordinal,
            itemID: itemID,
            lineUTF16Range: hit.lineUTF16Range,
            anchorUTF16Offset: hit.utf16Offset,
            anchorPoint: hit.boundaryPoint,
            focusUTF16Offset: hit.utf16Offset,
            focusPoint: hit.boundaryPoint
        )
    }

    private func updateTextSelection(focusPoint: CGPoint) {
        guard let currentSelection = textSelection,
              let placement = placements.first(where: {
                  $0.ordinal == currentSelection.ordinal
                      && $0.itemID == currentSelection.itemID
              }),
              let hit = contentAdapter?.textSelectionHit(
                  at: currentSelection.ordinal,
                  point: focusPoint,
                  in: cueContentRect(for: placement.rect),
                  constrainedToLine: currentSelection.lineUTF16Range
              ),
              hit.lineUTF16Range == currentSelection.lineUTF16Range,
              hit.utf16Offset != currentSelection.focusUTF16Offset
        else {
            return
        }
        textSelection?.focusUTF16Offset = hit.utf16Offset
        textSelection?.focusPoint = hit.boundaryPoint
        invalidateRow(currentSelection.ordinal)
    }

    private func clearTextSelection() {
        guard let textSelection else {
            return
        }
        self.textSelection = nil
        onDismissSelectedTextActions()
        invalidateRow(textSelection.ordinal)
    }

    /// Drops the selection without reporting it, for the reel closing the menu
    /// that hangs off it.
    func discardTextSelection() {
        guard let textSelection else {
            return
        }
        self.textSelection = nil
        invalidateRow(textSelection.ordinal)
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
            contentWidth: cueContentWidth(for: layout.contentWidth),
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

    var isEditingCollage: Bool {
        collageSelectedCueIDs != nil
    }

    private func cueID(at ordinal: Int) -> Int64? {
        contentAdapter?.itemID(at: ordinal)?.base as? Int64
    }

    private func isCollageCueChecked(at ordinal: Int) -> Bool {
        guard let cueID = cueID(at: ordinal) else {
            return false
        }
        return collageSelectedCueIDs?.contains(cueID) == true
    }

    private func cueContentWidth(for width: CGFloat) -> CGFloat {
        return max(
            0,
            width - PlaybackCueTimelineLayout.leadingAccessoryWidth(
                usesCheckbox: isEditingCollage
            )
        )
    }

    private func cueContentRect(for rect: CGRect) -> CGRect {
        cueTimelineRowLayout(for: rect).cueRect
    }

    /// Where a cue's text starts in the document as the reel lays it out now.
    /// `nil` once the reel has carried that cue outside the laid-out window.
    func cueContentOrigin(at ordinal: Int) -> CGPoint? {
        placements.first { $0.ordinal == ordinal }.map {
            cueContentRect(for: $0.rect).origin
        }
    }

    private func collageCheckboxRect(
        for placement: PlaybackSubtitleFocusCuePlacement
    ) -> CGRect {
        guard isEditingCollage else {
            return .null
        }
        return cueTimelineRowLayout(for: placement).markerRect
    }

    private func cueTimelineRowLayout(
        for rect: CGRect
    ) -> PlaybackCueTimelineRowLayout {
        PlaybackCueTimelineLayout.rowLayout(
            in: rect,
            usesCheckbox: isEditingCollage
        )
    }

    private func cueTimelineRowLayout(
        for placement: PlaybackSubtitleFocusCuePlacement
    ) -> PlaybackCueTimelineRowLayout {
        PlaybackCueTimelineLayout.rowLayout(
            in: placement.rect,
            usesCheckbox: isEditingCollage,
            markerCenterY: placement.rect.minY
                + placement.extent.firstVisualLineCenterOffset
        )
    }

    private var cueTimelineConnectorRects: [CGRect] {
        guard isEditingCollage else {
            return []
        }
        return zip(placements, placements.dropFirst()).compactMap { current, next in
            guard next.ordinal == current.ordinal + 1 else {
                return nil
            }
            return PlaybackCueTimelineLayout.connectorRect(
                from: cueTimelineRowLayout(for: current),
                to: cueTimelineRowLayout(for: next)
            )
        }
    }

    private func collagePlacement(
        containing point: CGPoint
    ) -> PlaybackSubtitleFocusCuePlacement? {
        guard isEditingCollage else {
            return nil
        }
        return placements.first { $0.rect.contains(point) }
    }

    private func textPlacement(
        containing point: CGPoint
    ) -> PlaybackSubtitleFocusCuePlacement? {
        placements.first {
            cueContentRect(for: $0.rect).contains(point)
        }
    }

    private func toggleCollageCue(at ordinal: Int) -> Bool {
        guard isEditingCollage,
              placements.contains(where: { $0.ordinal == ordinal }),
              isCollageCueChecked(at: ordinal) || collageCanSelectAnotherCue
        else {
            return false
        }
        onToggleCollageCueSelection(ordinal)
        return true
    }
}

typealias PlaybackVirtualReelDocumentView =
    PlaybackSubtitleFocusReelDocumentView

/// The menu offered after selecting subtitle text with the pointer.
///
/// It observes the highlight model so arrow keys and pointer motion move one
/// highlight; the rows never paint their own hover.
struct PlaybackSelectedTextMenu: View {
    struct Item {
        let title: String
        let icon: AppIcon
    }

    @ObservedObject var highlight: MenuHighlightModel
    let items: [Item]
    let onActivate: (Int) -> Void

    var body: some View {
        WorkbenchPopoverPanel(highlight: highlight) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { position, item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        icon: item.icon,
                        showsCheckmarkSlot: false,
                        action: { onActivate(position) },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
        }
    }
}
