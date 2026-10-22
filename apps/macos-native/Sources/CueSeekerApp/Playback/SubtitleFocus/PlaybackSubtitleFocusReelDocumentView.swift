import AppKit
import CueSeekerCore
import QuartzCore
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

    private struct CueFocusAnimation {
        var currentProgress: CGFloat
        var startProgress: CGFloat
        var targetProgress: CGFloat
        var startTime: TimeInterval
        var duration: TimeInterval
    }

    private struct RowBitmapCacheKey: Hashable {
        let itemID: AnyHashable
        let ordinal: Int
        let datasetID: AnyHashable
        let generation: UInt64
        let revision: UInt64
        let pixelWidth: Int
        let pixelHeight: Int
        let isSelectedSteadyState: Bool
        let isEnabled: Bool
        let isEditingCollage: Bool
        let isChecked: Bool
        let isDarkAppearance: Bool
    }

    private struct RowBitmapCacheEntry {
        let image: CGImage
        var lastAccess: UInt64
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
    private var cueFocusAnimations: [Int: CueFocusAnimation] = [:]
    private var focusAnimationTimer: Timer?
    private var focusDisplayLink: AnyObject?
    private var focusFadeInDebounceDeadline: TimeInterval?
    private var focusClockTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    private let rowBitmapCacheCapacity = 32
    private var rowBitmapCache: [RowBitmapCacheKey: RowBitmapCacheEntry] = [:]
    private var rowBitmapCacheAccessSequence: UInt64 = 0
    private(set) var rowBitmapCacheHitCountForTesting = 0
    private(set) var rowBitmapCacheMissCountForTesting = 0
    private(set) var dynamicRowDrawCountForTesting = 0
    var isDrivenByExternalScrollAnimator = false {
        didSet {
            guard isDrivenByExternalScrollAnimator != oldValue else {
                return
            }
            if isDrivenByExternalScrollAnimator {
                stopFocusAnimationTimer()
            } else if focusFadeInDebounceDeadline != nil || hasRunningCueFocusAnimation {
                startFocusAnimationTimerIfNeeded()
            }
        }
    }
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
        rowBitmapCache.removeAll(keepingCapacity: true)
        needsDisplay = true
    }

    func resetRowDrawCountersForTesting() {
        rowBitmapCacheHitCountForTesting = 0
        rowBitmapCacheMissCountForTesting = 0
        dynamicRowDrawCountForTesting = 0
    }

    var selectedOrdinalForTesting: Int? {
        selectedOrdinal
    }

    func cueSelectionProgress(at ordinal: Int) -> CGFloat {
        cueFocusAnimations[ordinal]?.currentProgress ?? 0
    }

    func cueSelectionProgressForTesting(at ordinal: Int) -> CGFloat {
        cueSelectionProgress(at: ordinal)
    }

    var isFocusFadeInDebouncingForTesting: Bool {
        focusFadeInDebounceDeadline != nil
    }

    private var hasRunningCueFocusAnimation: Bool {
        cueFocusAnimations.values.contains { $0.duration > 0 }
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
                rowBitmapCache.removeAll(keepingCapacity: true)
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
            stopFocusAnimationTimer()
            focusFadeInDebounceDeadline = nil
            cueFocusAnimations.removeAll(keepingCapacity: true)
            placements.removeAll(keepingCapacity: true)
        }
        rowBitmapCache.removeAll(keepingCapacity: true)
        self.contentAdapter = contentAdapter
        contentSnapshot = snapshot
        resolveLocalPlacementsIfNeeded()
        needsDisplay = true
    }

    func setImmediateSelection(_ ordinal: Int?) {
        stopFocusAnimationTimer()
        focusFadeInDebounceDeadline = nil
        var affectedOrdinals = Set(cueFocusAnimations.keys)
        if let selectedOrdinal {
            affectedOrdinals.insert(selectedOrdinal)
        }
        if let ordinal {
            affectedOrdinals.insert(ordinal)
        }
        cueFocusAnimations.removeAll(keepingCapacity: true)
        selectedOrdinal = ordinal
        if let ordinal {
            cueFocusAnimations[ordinal] = CueFocusAnimation(
                currentProgress: 1,
                startProgress: 1,
                targetProgress: 1,
                startTime: 0,
                duration: 0
            )
        }
        if placements.isEmpty {
            resolveLocalPlacementsIfNeeded()
            needsDisplay = true
        } else {
            for affectedOrdinal in affectedOrdinals {
                invalidateRow(affectedOrdinal)
            }
        }
    }

    func updateSelection(_ ordinal: Int?) {
        guard selectedOrdinal != ordinal else {
            if focusFadeInDebounceDeadline == nil,
               !hasRunningCueFocusAnimation,
               let ordinal,
               cueSelectionProgress(at: ordinal) < 1 {
                cueFocusAnimations[ordinal] = CueFocusAnimation(
                    currentProgress: 1,
                    startProgress: 1,
                    targetProgress: 1,
                    startTime: 0,
                    duration: 0
                )
                if placements.isEmpty {
                    needsDisplay = true
                } else {
                    invalidateRow(ordinal)
                }
            }
            return
        }
        setImmediateSelection(ordinal)
    }

    func beginNavigationSelection(
        _ targetOrdinal: Int?,
        reducesMotion: Bool
    ) {
        if reducesMotion {
            setImmediateSelection(targetOrdinal)
            return
        }
        let now = max(focusClockTime, ProcessInfo.processInfo.systemUptime)
        focusClockTime = now
        selectedOrdinal = targetOrdinal
        if placements.isEmpty {
            resolveLocalPlacementsIfNeeded()
        }

        for ordinal in Array(cueFocusAnimations.keys) {
            guard var anim = cueFocusAnimations[ordinal] else {
                continue
            }
            if anim.currentProgress <= 0.000_5 {
                cueFocusAnimations.removeValue(forKey: ordinal)
                invalidateRow(ordinal)
            } else if anim.targetProgress > 0 {
                anim.startProgress = anim.currentProgress
                anim.targetProgress = 0
                anim.startTime = window?.isVisible == true
                    ? now - (1.0 / 120.0)
                    : now
                anim.duration = PlaybackSubtitleFocusMetrics.focusFadeOutDuration
                cueFocusAnimations[ordinal] = anim
                invalidateRow(ordinal)
            }
        }

        if let targetOrdinal {
            focusFadeInDebounceDeadline =
                now + PlaybackSubtitleFocusMetrics.focusFadeInDelay
            invalidateRow(targetOrdinal)
        } else {
            focusFadeInDebounceDeadline = nil
        }
        startFocusAnimationTimerIfNeeded()
    }

    func stepFocusTransitions(at rawNow: TimeInterval) {
        let now = max(focusClockTime, rawNow)
        focusClockTime = now
        if let deadline = focusFadeInDebounceDeadline,
           now + 0.000_001 >= deadline {
            focusFadeInDebounceDeadline = nil
            if let selectedOrdinal {
                let current = cueFocusAnimations[selectedOrdinal]?.currentProgress ?? 0
                cueFocusAnimations[selectedOrdinal] = CueFocusAnimation(
                    currentProgress: current,
                    startProgress: current,
                    targetProgress: 1,
                    startTime: min(now, deadline),
                    duration: PlaybackSubtitleFocusMetrics.focusFadeInDuration
                )
            }
        }

        for ordinal in Array(cueFocusAnimations.keys) {
            guard var anim = cueFocusAnimations[ordinal],
                  anim.duration > 0
            else {
                continue
            }
            let elapsed = max(0, now - anim.startTime)
            let rawProgress = elapsed / anim.duration
            let linearProgress = rawProgress >= 0.999_999
                ? 1
                : CGFloat(min(1, rawProgress))
            let easedProgress = PlaybackSubtitleFocusReelPositionAnimator
                .focusFadeEasedProgress(linearProgress)
            anim.currentProgress = anim.startProgress
                + (anim.targetProgress - anim.startProgress) * easedProgress
            if linearProgress >= 1 {
                anim.currentProgress = anim.targetProgress
                anim.duration = 0
            }
            if anim.currentProgress <= 0.000_5,
               anim.targetProgress == 0,
               anim.duration == 0 {
                cueFocusAnimations.removeValue(forKey: ordinal)
            } else {
                cueFocusAnimations[ordinal] = anim
            }
            invalidateRow(ordinal)
        }

        if placements.isEmpty {
            needsDisplay = true
        }
        if focusFadeInDebounceDeadline == nil, !hasRunningCueFocusAnimation {
            stopFocusAnimationTimer()
        }
    }

    func advanceFocusTransitionForTesting(by deltaSeconds: TimeInterval) {
        isDrivenByExternalScrollAnimator = false
        stopFocusAnimationTimer()
        focusClockTime += max(0, deltaSeconds)
        stepFocusTransitions(at: focusClockTime)
    }

    private func startFocusAnimationTimerIfNeeded() {
        guard focusAnimationTimer == nil,
              focusDisplayLink == nil,
              !isDrivenByExternalScrollAnimator
        else {
            return
        }
        if #available(macOS 14.0, *), window?.isVisible == true {
            let link = self.displayLink(
                target: self,
                selector: #selector(handleFocusDisplayLink(_:))
            )
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60,
                maximum: 120,
                preferred: 120
            )
            link.add(to: .main, forMode: .common)
            link.isPaused = false
            focusDisplayLink = link
            return
        }
        let timer = Timer(
            timeInterval: 1 / 120,
            target: self,
            selector: #selector(handleFocusAnimationTimer),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 0
        RunLoop.main.add(timer, forMode: .common)
        focusAnimationTimer = timer
    }

    private func stopFocusAnimationTimer() {
        if #available(macOS 14.0, *),
           let link = focusDisplayLink as? CADisplayLink {
            link.invalidate()
        }
        focusDisplayLink = nil
        focusAnimationTimer?.invalidate()
        focusAnimationTimer = nil
    }

    @objc
    private func handleFocusDisplayLink(_ sender: AnyObject) {
        handleFocusAnimationTimer()
    }

    @objc
    private func handleFocusAnimationTimer() {
        guard !isDrivenByExternalScrollAnimator else {
            return
        }
        stepFocusTransitions(
            at: max(focusClockTime, ProcessInfo.processInfo.systemUptime)
        )
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
        isDrivenByExternalScrollAnimator = false
        stopFocusAnimationTimer()
        focusFadeInDebounceDeadline = nil
        cueFocusAnimations.removeAll(keepingCapacity: false)
        rowBitmapCache.removeAll(keepingCapacity: true)
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
            let selectionProgress = cueSelectionProgress(at: placement.ordinal)
            let selectedTextRange = textSelection?.ordinal == placement.ordinal
                ? textSelection?.range
                : nil
            let isSteadyColor = selectedTextRange == nil
                && (selectionProgress <= 0.000_5 || selectionProgress >= 0.999_5)

            if isSteadyColor,
               placement.rect.width > 0,
               placement.rect.height > 0 {
                let scale = max(
                    1,
                    window?.backingScaleFactor
                        ?? NSScreen.main?.backingScaleFactor
                        ?? 2
                )
                let pixelWidth = max(
                    1,
                    Int((placement.rect.width * scale).rounded())
                )
                let pixelHeight = max(
                    1,
                    Int((placement.rect.height * scale).rounded())
                )
                let isSelectedSteadyState = selectionProgress >= 0.999_5
                let isDarkAppearance = effectiveAppearance.bestMatch(
                    from: [.darkAqua, .aqua]
                ) == .darkAqua
                let snapshot = contentSnapshot ?? contentAdapter?.snapshot
                let key = RowBitmapCacheKey(
                    itemID: placement.itemID,
                    ordinal: placement.ordinal,
                    datasetID: snapshot?.datasetID ?? AnyHashable(0),
                    generation: snapshot?.generation ?? 0,
                    revision: snapshot?.revision ?? 0,
                    pixelWidth: pixelWidth,
                    pixelHeight: pixelHeight,
                    isSelectedSteadyState: isSelectedSteadyState,
                    isEnabled: canToggle,
                    isEditingCollage: isEditingCollage,
                    isChecked: isChecked,
                    isDarkAppearance: isDarkAppearance
                )
                if var cached = rowBitmapCache[key] {
                    rowBitmapCacheHitCountForTesting += 1
                    rowBitmapCacheAccessSequence &+= 1
                    cached.lastAccess = rowBitmapCacheAccessSequence
                    rowBitmapCache[key] = cached
                    drawCachedRowImage(cached.image, in: placement.rect)
                    continue
                }
                rowBitmapCacheMissCountForTesting += 1
                if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                   let bitmapContext = CGContext(
                       data: nil,
                       width: pixelWidth,
                       height: pixelHeight,
                       bitsPerComponent: 8,
                       bytesPerRow: 0,
                       space: colorSpace,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                   ) {
                    bitmapContext.translateBy(x: 0, y: CGFloat(pixelHeight))
                    bitmapContext.scaleBy(x: scale, y: -scale)
                    bitmapContext.translateBy(
                        x: -placement.rect.minX,
                        y: -placement.rect.minY
                    )
                    let previousGraphicsContext = NSGraphicsContext.current
                    NSGraphicsContext.current = NSGraphicsContext(
                        cgContext: bitmapContext,
                        flipped: true
                    )
                    drawRowDirectly(
                        placement: placement,
                        isSelected: isSelectedSteadyState,
                        selectionProgress: isSelectedSteadyState ? 1 : 0,
                        isEnabled: canToggle,
                        isChecked: isChecked,
                        selectedTextRange: nil
                    )
                    NSGraphicsContext.current = previousGraphicsContext
                    if let image = bitmapContext.makeImage() {
                        rowBitmapCacheAccessSequence &+= 1
                        if rowBitmapCache.count >= rowBitmapCacheCapacity,
                           let oldestKey = rowBitmapCache.min(by: {
                               $0.value.lastAccess < $1.value.lastAccess
                           })?.key {
                            rowBitmapCache.removeValue(forKey: oldestKey)
                        }
                        rowBitmapCache[key] = RowBitmapCacheEntry(
                            image: image,
                            lastAccess: rowBitmapCacheAccessSequence
                        )
                        drawCachedRowImage(image, in: placement.rect)
                        continue
                    }
                }
                drawRowDirectly(
                    placement: placement,
                    isSelected: isSelectedSteadyState,
                    selectionProgress: isSelectedSteadyState ? 1 : 0,
                    isEnabled: canToggle,
                    isChecked: isChecked,
                    selectedTextRange: nil
                )
            } else {
                dynamicRowDrawCountForTesting += 1
                drawRowDirectly(
                    placement: placement,
                    isSelected: placement.ordinal == selectedOrdinal,
                    selectionProgress: selectionProgress,
                    isEnabled: canToggle,
                    isChecked: isChecked,
                    selectedTextRange: selectedTextRange
                )
            }
        }
    }

    private func drawRowDirectly(
        placement: PlaybackSubtitleFocusCuePlacement,
        isSelected: Bool,
        selectionProgress: CGFloat,
        isEnabled: Bool,
        isChecked: Bool,
        selectedTextRange: NSRange?
    ) {
        contentAdapter?.drawItem(
            at: placement.ordinal,
            isSelected: isSelected,
            selectionProgress: selectionProgress,
            isEnabled: isEnabled,
            selectedTextRange: selectedTextRange,
            in: cueContentRect(for: placement.rect)
        )
        if isEditingCollage {
            let timelineLayout = cueTimelineRowLayout(for: placement)
            PlaybackCollageCheckboxDrawing.draw(
                isSelected: isChecked,
                isEnabled: isEnabled,
                in: timelineLayout.markerRect
            )
        }
    }

    private func drawCachedRowImage(
        _ image: CGImage,
        in rect: CGRect
    ) {
        guard let cgContext = NSGraphicsContext.current?.cgContext else {
            return
        }
        cgContext.saveGState()
        cgContext.translateBy(x: rect.minX, y: rect.maxY)
        cgContext.scaleBy(x: 1, y: -1)
        cgContext.draw(image, in: CGRect(origin: .zero, size: rect.size))
        cgContext.restoreGState()
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
