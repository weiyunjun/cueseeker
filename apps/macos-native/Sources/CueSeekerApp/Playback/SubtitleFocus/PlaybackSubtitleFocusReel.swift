import AppKit
import CueSeekerCore
import SwiftUI

struct PlaybackSubtitleFocusVirtualReelLayout: Equatable {
    static let overscanCueCount = 4

    let viewportSize: CGSize
    let totalCount: Int
    let focusAnchorY: CGFloat

    init(
        viewportSize: CGSize,
        totalCount: Int,
        focusAnchorY: CGFloat
    ) {
        self.viewportSize = CGSize(
            width: max(0, viewportSize.width),
            height: max(0, viewportSize.height)
        )
        self.totalCount = max(0, totalCount)
        self.focusAnchorY = focusAnchorY.isFinite ? focusAnchorY : 0
    }

    var documentSize: CGSize {
        CGSize(
            width: viewportSize.width,
            height: viewportSize.height
                + CGFloat(max(0, totalCount - 1))
                    * PlaybackSubtitleFocusMetrics.cueSlotPitch
        )
    }

    var maximumContentOffsetY: CGFloat {
        CGFloat(max(0, totalCount - 1))
            * PlaybackSubtitleFocusMetrics.cueSlotPitch
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

    func contentOffsetY(for ordinal: Int) -> CGFloat {
        CGFloat(boundedOrdinal(ordinal)) * PlaybackSubtitleFocusMetrics.cueSlotPitch
    }

    func nearestOrdinal(
        toContentOffsetY offset: CGFloat,
        netDeltaY: CGFloat = 0
    ) -> Int {
        guard totalCount > 0 else {
            return 0
        }
        let position = min(max(0, offset), maximumContentOffsetY)
            / PlaybackSubtitleFocusMetrics.cueSlotPitch
        let lower = Int(floor(position))
        let upper = min(totalCount - 1, lower + 1)
        let fraction = position - CGFloat(lower)
        if abs(fraction - 0.5) < 0.0001 {
            if netDeltaY > 0 {
                return lower
            }
            if netDeltaY < 0 {
                return upper
            }
        }
        return boundedOrdinal(Int(position.rounded()))
    }

    func rowRect(for ordinal: Int) -> CGRect {
        CGRect(
            x: (viewportSize.width - contentWidth) / 2,
            y: focusAnchorY
                + CGFloat(boundedOrdinal(ordinal))
                    * PlaybackSubtitleFocusMetrics.cueSlotPitch,
            width: contentWidth,
            height: PlaybackSubtitleFocusMetrics.cueSlotHeight
        )
    }

    func visibleOrdinalRange(
        in documentRect: CGRect,
        overscan: Int = overscanCueCount
    ) -> Range<Int> {
        guard totalCount > 0,
              documentRect.width > 0,
              documentRect.height > 0
        else {
            return 0..<0
        }

        let pitch = PlaybackSubtitleFocusMetrics.cueSlotPitch
        let firstIntersecting = Int(floor(
            (documentRect.minY - focusAnchorY
                - PlaybackSubtitleFocusMetrics.cueSlotHeight) / pitch
        )) + 1
        let endIntersecting = Int(ceil(
            (documentRect.maxY - focusAnchorY) / pitch
        ))
        let lowerBound = max(0, firstIntersecting - max(0, overscan))
        let upperBound = min(
            totalCount,
            max(lowerBound, endIntersecting + max(0, overscan))
        )
        return lowerBound..<upperBound
    }

    private func boundedOrdinal(_ ordinal: Int) -> Int {
        guard totalCount > 0 else {
            return 0
        }
        return min(max(0, ordinal), totalCount - 1)
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

enum PlaybackSubtitleFocusPreciseWheelSettlement {
    static func accumulatingAppliedDeltaY(
        _ netDeltaY: CGFloat,
        from previousOffsetY: CGFloat,
        to currentOffsetY: CGFloat
    ) -> CGFloat {
        netDeltaY + previousOffsetY - currentOffsetY
    }

    static func targetOrdinal(
        layout: PlaybackSubtitleFocusVirtualReelLayout,
        currentOffsetY: CGFloat,
        startOrdinal: Int,
        netDeltaY: CGFloat,
        availableRange: Range<Int>
    ) -> Int {
        guard !availableRange.isEmpty else {
            return startOrdinal
        }
        func bounded(_ ordinal: Int) -> Int {
            min(
                max(availableRange.lowerBound, ordinal),
                availableRange.upperBound - 1
            )
        }

        var target = bounded(layout.nearestOrdinal(
            toContentOffsetY: currentOffsetY,
            netDeltaY: netDeltaY
        ))
        if target == startOrdinal, netDeltaY != 0 {
            target = bounded(startOrdinal + (netDeltaY > 0 ? -1 : 1))
        }
        return target
    }

    static func boundedContentOffsetY(
        layout: PlaybackSubtitleFocusVirtualReelLayout,
        requestedOffsetY: CGFloat,
        availableRange: Range<Int>
    ) -> CGFloat {
        guard !availableRange.isEmpty else {
            return min(max(0, requestedOffsetY), layout.maximumContentOffsetY)
        }
        let minimumOffset = layout.contentOffsetY(
            for: availableRange.lowerBound
        )
        let maximumOffset = layout.contentOffsetY(
            for: availableRange.upperBound - 1
        )
        return min(max(minimumOffset, requestedOffsetY), maximumOffset)
    }
}

struct PlaybackSubtitleFocusReelRepresentable: NSViewRepresentable {
    let cues: [SubtitleFocusCue]
    let totalCount: Int
    let selectedOrdinal: Int
    let focusAnchorY: CGFloat
    let presentationTranslation: CGFloat
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let reducesMotion: Bool
    let isInteractionEnabled: Bool
    let cancelsWheelMotion: Bool
    let onActivateCue: (SubtitleFocusCue, CGFloat) -> Void
    let onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool
    let onCommitNativeReelSelection: (Int) -> Bool
    let allowsNativeWheelInput: () -> Bool
    let onNativeMotionGateChanged: (Bool) -> Void
    let onKeyboardMotionChanged: (Bool) -> Void

    func makeNSView(context: Context) -> PlaybackSubtitleFocusReelContainerView {
        let view = PlaybackSubtitleFocusReelContainerView()
        update(view)
        return view
    }

    func updateNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        context: Context
    ) {
        update(nsView)
    }

    static func dismantleNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        coordinator: Void
    ) {
        nsView.invalidate()
    }

    private func update(_ view: PlaybackSubtitleFocusReelContainerView) {
        view.onActivateCue = onActivateCue
        view.onCommitKeyboardNavigation = onCommitKeyboardNavigation
        view.onCommitNativeReelSelection = onCommitNativeReelSelection
        view.allowsNativeWheelInput = allowsNativeWheelInput
        view.onNativeMotionGateChanged = onNativeMotionGateChanged
        view.onKeyboardMotionChanged = onKeyboardMotionChanged
        view.update(
            cues: cues,
            totalCount: totalCount,
            selectedOrdinal: selectedOrdinal,
            focusAnchorY: focusAnchorY,
            presentationTranslation: presentationTranslation,
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion
        )
    }
}

final class PlaybackSubtitleFocusReelContainerView: NSView {
    var onActivateCue: (SubtitleFocusCue, CGFloat) -> Void = { _, _ in }
    var onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool = {
        _ in false
    }
    var onCommitNativeReelSelection: (Int) -> Bool = { _ in false }
    var allowsNativeWheelInput: () -> Bool = { false }
    var onNativeMotionGateChanged: (Bool) -> Void = { _ in }
    var onKeyboardMotionChanged: (Bool) -> Void = { _ in }

    private let scrollView = PlaybackSubtitleFocusNativeScrollView()
    private let documentView = PlaybackSubtitleFocusReelDocumentView()
    private var totalCount = 0
    private var selectedOrdinal = 0
    private var focusAnchorY: CGFloat = 0
    private var presentationTranslation: CGFloat = 0
    private var loadedOrdinalRange: Range<Int> = 0..<0
    private var isInteractionEnabled = true
    private var reducesMotion = false
    private var lastHandledKeyboardSequence = 0
    private var activeKeyboardRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    private var isKeyboardMotionActive = false
    private var activeWheelTargetOrdinal: Int?
    private var preciseGestureStartOrdinal: Int?
    private var preciseGestureNetDeltaY: CGFloat = 0
    private var wheelState = PlaybackSubtitleFocusNativeWheelState()
    private var preciseSettleTask: Task<Void, Never>?
    nonisolated(unsafe) private var eventMonitor: Any?
    private var isWheelMotionActive = false
    private var reportedNativeMotionActive = false
    private var motionCallbackGeneration = 0
    private var motionCallbackTask: Task<Void, Never>?
    private lazy var keyboardAnimator = PlaybackSubtitleFocusKeyboardOffsetAnimator(
        onUpdate: { [weak self] offset in
            self?.setContentOffsetY(offset)
        },
        onCompletion: { [weak self] in
            self?.completeKeyboardMotion()
        }
    )
    private lazy var wheelAnimator = PlaybackSubtitleFocusKeyboardOffsetAnimator(
        onUpdate: { [weak self] offset in
            self?.setContentOffsetY(offset)
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

        documentView.onActivateCue = { [weak self] cue, documentY in
            guard let self else {
                return
            }
            let viewportY = documentY - self.scrollView.contentView.bounds.minY
            self.onActivateCue(cue, viewportY)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        updateDocumentGeometry()
        if !hasActiveNativeMotion {
            synchronizeContentOffsetIfIdle()
        }
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
        focusAnchorY: CGFloat,
        presentationTranslation: CGFloat,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool,
        isInteractionEnabled: Bool,
        cancelsWheelMotion: Bool
    ) {
        self.totalCount = max(0, totalCount)
        self.selectedOrdinal = min(
            max(0, selectedOrdinal),
            max(0, totalCount - 1)
        )
        self.focusAnchorY = focusAnchorY.isFinite ? focusAnchorY : 0
        self.presentationTranslation = presentationTranslation.isFinite
            ? presentationTranslation
            : 0
        if let firstOrdinal = cues.first?.ordinal,
           let lastOrdinal = cues.last?.ordinal {
            loadedOrdinalRange = firstOrdinal..<(lastOrdinal + 1)
        } else {
            loadedOrdinalRange = 0..<0
        }
        self.reducesMotion = reducesMotion
        let wasInteractionEnabled = self.isInteractionEnabled
        self.isInteractionEnabled = isInteractionEnabled
        if cancelsWheelMotion {
            resetWheelInteraction(requiresNewGesture: true)
        } else if wasInteractionEnabled, !isInteractionEnabled {
            suspendWheelInputForSuppression()
        }
        documentView.updateContent(cues: cues, totalCount: totalCount)
        documentView.isInteractionEnabled = isInteractionEnabled
        updateDocumentGeometry()
        if !hasActiveNativeMotion {
            documentView.updateSelection(self.selectedOrdinal)
            synchronizeContentOffsetIfIdle()
        }
        handleKeyboardNavigation(
            keyboardNavigationRequest,
            reducesMotion: reducesMotion
        )
    }

    func invalidate() {
        onActivateCue = { _, _ in }
        if reportedNativeMotionActive {
            onNativeMotionGateChanged(false)
        }
        motionCallbackGeneration += 1
        motionCallbackTask?.cancel()
        motionCallbackTask = nil
        onCommitKeyboardNavigation = { _ in false }
        onCommitNativeReelSelection = { _ in false }
        allowsNativeWheelInput = { false }
        onNativeMotionGateChanged = { _ in }
        onKeyboardMotionChanged = { _ in }
        keyboardAnimator.cancel()
        wheelAnimator.cancel()
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
        removeEventMonitor()
        wheelState.reset()
        activeKeyboardRequest = nil
        activeWheelTargetOrdinal = nil
        preciseGestureStartOrdinal = nil
        isKeyboardMotionActive = false
        isWheelMotionActive = false
        reportedNativeMotionActive = false
        documentView.invalidate()
        scrollView.documentView = nil
    }

    private func updateDocumentGeometry() {
        let layout = PlaybackSubtitleFocusVirtualReelLayout(
            viewportSize: scrollView.contentSize,
            totalCount: totalCount,
            focusAnchorY: focusAnchorY
        )
        documentView.updateLayout(layout)
        if documentView.frame.size != layout.documentSize {
            documentView.frame = CGRect(origin: .zero, size: layout.documentSize)
        }
    }

    private func synchronizeContentOffsetIfIdle() {
        guard !keyboardAnimator.isRunning,
              !wheelAnimator.isRunning,
              preciseGestureStartOrdinal == nil
        else {
            return
        }
        let layout = currentLayout

        let requestedOffset = layout.contentOffsetY(for: selectedOrdinal)
            - presentationTranslation
        let offset = min(max(0, requestedOffset), layout.maximumContentOffsetY)
        setContentOffsetY(offset)
    }

    private var currentLayout: PlaybackSubtitleFocusVirtualReelLayout {
        PlaybackSubtitleFocusVirtualReelLayout(
            viewportSize: scrollView.contentSize,
            totalCount: totalCount,
            focusAnchorY: focusAnchorY
        )
    }

    private func setContentOffsetY(_ offset: CGFloat) {
        let currentOrigin = scrollView.contentView.bounds.origin
        guard abs(currentOrigin.y - offset) > 0.01 else {
            return
        }
        scrollView.contentView.scroll(to: CGPoint(x: 0, y: offset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func handleKeyboardNavigation(
        _ request: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool
    ) {
        guard let request,
              request.sequence > lastHandledKeyboardSequence,
              request.targetOrdinal >= 0,
              request.targetOrdinal < totalCount
        else {
            return
        }

        lastHandledKeyboardSequence = request.sequence
        activeKeyboardRequest = request
        documentView.updateSelection(request.targetOrdinal)
        setKeyboardMotionActive(true)
        keyboardAnimator.retarget(
            from: scrollView.contentView.bounds.minY,
            to: currentLayout.contentOffsetY(for: request.targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func completeKeyboardMotion() {
        guard let request = activeKeyboardRequest else {
            return
        }
        guard onCommitKeyboardNavigation(request) else {
            return
        }
        activeKeyboardRequest = nil
        selectedOrdinal = request.targetOrdinal
        setKeyboardMotionActive(false)
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
        let startOrdinal = activeWheelTargetOrdinal ?? selectedOrdinal
        let delta = direction == .backward ? -stepCount : stepCount
        let targetOrdinal = boundedLoadedOrdinal(startOrdinal + delta)
        guard targetOrdinal != startOrdinal else {
            return
        }

        preciseGestureStartOrdinal = nil
        preciseGestureNetDeltaY = 0
        activeWheelTargetOrdinal = targetOrdinal
        documentView.updateSelection(targetOrdinal)
        setWheelMotionActive(true)
        wheelAnimator.retarget(
            from: scrollView.contentView.bounds.minY,
            to: currentLayout.contentOffsetY(for: targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func handlePreciseWheel(
        deltaY: CGFloat,
        beginsGesture: Bool
    ) {
        if beginsGesture || preciseGestureStartOrdinal == nil {
            cancelPreciseSettle()
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            preciseGestureStartOrdinal = boundedLoadedOrdinal(
                currentLayout.nearestOrdinal(
                    toContentOffsetY: scrollView.contentView.bounds.minY
                )
            )
            preciseGestureNetDeltaY = 0
        }

        let layout = currentLayout
        let previousOffset = scrollView.contentView.bounds.minY
        let requestedOffset = previousOffset - deltaY
        let offset = PlaybackSubtitleFocusPreciseWheelSettlement
            .boundedContentOffsetY(
                layout: layout,
                requestedOffsetY: requestedOffset,
                availableRange: loadedOrdinalRange
            )
        preciseGestureNetDeltaY = PlaybackSubtitleFocusPreciseWheelSettlement
            .accumulatingAppliedDeltaY(
                preciseGestureNetDeltaY,
                from: previousOffset,
                to: offset
            )
        setContentOffsetY(offset)
        let previewOrdinal = boundedLoadedOrdinal(
            layout.nearestOrdinal(
                toContentOffsetY: offset,
                netDeltaY: preciseGestureNetDeltaY
            )
        )
        documentView.updateSelection(previewOrdinal)
        setWheelMotionActive(true)
    }

    private func schedulePreciseSettle() {
        preciseSettleTask?.cancel()
        preciseSettleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self, !Task.isCancelled else {
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
        guard let startOrdinal = preciseGestureStartOrdinal else {
            return
        }

        let layout = currentLayout
        let currentOffset = scrollView.contentView.bounds.minY
        let targetOrdinal = PlaybackSubtitleFocusPreciseWheelSettlement.targetOrdinal(
            layout: layout,
            currentOffsetY: currentOffset,
            startOrdinal: startOrdinal,
            netDeltaY: preciseGestureNetDeltaY,
            availableRange: loadedOrdinalRange
        )

        preciseGestureStartOrdinal = nil
        preciseGestureNetDeltaY = 0
        activeWheelTargetOrdinal = targetOrdinal
        documentView.updateSelection(targetOrdinal)
        wheelAnimator.retarget(
            from: currentOffset,
            to: layout.contentOffsetY(for: targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func completeWheelMotion() {
        guard let targetOrdinal = activeWheelTargetOrdinal else {
            return
        }
        let didCommit = onCommitNativeReelSelection(targetOrdinal)
        activeWheelTargetOrdinal = nil
        if didCommit {
            selectedOrdinal = targetOrdinal
        } else {
            documentView.updateSelection(selectedOrdinal)
        }
        setWheelMotionActive(false)
        if !didCommit {
            synchronizeContentOffsetIfIdle()
        }
    }

    private func resetWheelInteraction(requiresNewGesture: Bool) {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: requiresNewGesture)
        wheelAnimator.cancel()
        activeWheelTargetOrdinal = nil
        preciseGestureStartOrdinal = nil
        preciseGestureNetDeltaY = 0
        documentView.updateSelection(selectedOrdinal)
        setWheelMotionActive(false)
        synchronizeContentOffsetIfIdle()
    }

    private func suspendWheelInputForSuppression() {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: true)
        if preciseGestureStartOrdinal != nil {
            settlePreciseWheel()
        }
    }

    private func boundedLoadedOrdinal(_ ordinal: Int) -> Int {
        guard !loadedOrdinalRange.isEmpty else {
            return selectedOrdinal
        }
        return min(
            max(loadedOrdinalRange.lowerBound, ordinal),
            loadedOrdinalRange.upperBound - 1
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
        updateReportedNativeMotion()
    }

    private func setWheelMotionActive(_ isActive: Bool) {
        guard isWheelMotionActive != isActive else {
            return
        }
        isWheelMotionActive = isActive
        updateReportedNativeMotion()
    }

    private var hasActiveNativeMotion: Bool {
        activeKeyboardRequest != nil
            || activeWheelTargetOrdinal != nil
            || preciseGestureStartOrdinal != nil
            || keyboardAnimator.isRunning
            || wheelAnimator.isRunning
    }

    private func updateReportedNativeMotion() {
        let isActive = isKeyboardMotionActive || isWheelMotionActive
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

private final class PlaybackSubtitleFocusNativeScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

final class PlaybackSubtitleFocusReelDocumentView: NSView {
    var onActivateCue: (SubtitleFocusCue, CGFloat) -> Void = { _, _ in }
    var isInteractionEnabled = true {
        didSet {
            guard isInteractionEnabled != oldValue else {
                return
            }
            if !isInteractionEnabled {
                updateHoveredOrdinal(nil)
            }
        }
    }

    private let textLayout = PlaybackSubtitleFocusNativeTextLayout()
    private var layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: .zero,
        totalCount: 0,
        focusAnchorY: 0
    )
    private var cues: [SubtitleFocusCue] = []
    private var firstLoadedOrdinal = 0
    private var contentIdentity: ContentIdentity?
    private var selectedOrdinal = 0
    private var hoveredOrdinal: Int?
    private var hitRectsByOrdinal: [Int: [CGRect]] = [:]
    private var trackingAreaReference: NSTrackingArea?

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    func updateContent(cues: [SubtitleFocusCue], totalCount: Int) {
        let identity = ContentIdentity(cues: cues, totalCount: totalCount)
        guard identity != contentIdentity else {
            return
        }
        contentIdentity = identity
        self.cues = cues
        firstLoadedOrdinal = cues.first?.ordinal ?? 0
        hitRectsByOrdinal.removeAll(keepingCapacity: true)
        updateHoveredOrdinal(nil)
        needsDisplay = true
    }

    func updateSelection(_ ordinal: Int) {
        guard selectedOrdinal != ordinal else {
            return
        }
        let previousOrdinal = selectedOrdinal
        selectedOrdinal = ordinal
        invalidateRow(previousOrdinal)
        invalidateRow(selectedOrdinal)
        if hoveredOrdinal == selectedOrdinal {
            updateHoveredOrdinal(nil)
        }
    }

    func updateLayout(_ layout: PlaybackSubtitleFocusVirtualReelLayout) {
        guard self.layout != layout else {
            return
        }
        self.layout = layout
        hitRectsByOrdinal.removeAll(keepingCapacity: true)
        needsDisplay = true
    }

    func invalidate() {
        onActivateCue = { _, _ in }
        cues.removeAll(keepingCapacity: false)
        hitRectsByOrdinal.removeAll(keepingCapacity: false)
        contentIdentity = nil
        updateHoveredOrdinal(nil)
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
            self.trackingAreaReference = nil
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let visibleDirtyRect = dirtyRect.intersection(visibleRect)
        guard !visibleDirtyRect.isNull, !visibleDirtyRect.isEmpty else {
            return
        }
        let retainedRange = layout.visibleOrdinalRange(
            in: visibleRect,
            overscan: 1
        )
        hitRectsByOrdinal = hitRectsByOrdinal.filter { retainedRange.contains($0.key) }

        let drawRange = layout.visibleOrdinalRange(in: visibleDirtyRect)
        for ordinal in drawRange {
            guard let cue = cue(at: ordinal) else {
                continue
            }
            let rowRect = layout.rowRect(for: ordinal)
            let color: NSColor
            if ordinal == selectedOrdinal {
                color = NSColor.white.withAlphaComponent(0.94)
            } else if ordinal == hoveredOrdinal {
                color = NSColor.white.withAlphaComponent(0.62)
            } else {
                color = NSColor.white.withAlphaComponent(0.34)
            }
            hitRectsByOrdinal[ordinal] = textLayout.draw(
                text: cue.text,
                color: color,
                in: rowRect
            )
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [
                .activeInKeyWindow,
                .inVisibleRect,
                .mouseMoved,
                .mouseEnteredAndExited,
                .cursorUpdate,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        guard isInteractionEnabled else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        updateHoveredOrdinal(hitOrdinal(at: point))
    }

    override func mouseExited(with event: NSEvent) {
        updateHoveredOrdinal(nil)
    }

    override func cursorUpdate(with event: NSEvent) {
        guard isInteractionEnabled else {
            NSCursor.arrow.set()
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        if hitOrdinal(at: point) == nil {
            NSCursor.arrow.set()
        } else {
            NSCursor.pointingHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isInteractionEnabled,
              event.buttonNumber == 0
        else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        guard let ordinal = hitOrdinal(at: point),
              let cue = cue(at: ordinal)
        else {
            return
        }
        onActivateCue(cue, layout.rowRect(for: ordinal).minY)
    }

    private func cue(at ordinal: Int) -> SubtitleFocusCue? {
        let index = ordinal - firstLoadedOrdinal
        guard cues.indices.contains(index), cues[index].ordinal == ordinal else {
            return nil
        }
        return cues[index]
    }

    private func hitOrdinal(at point: CGPoint) -> Int? {
        let approximateOrdinal = Int(floor(
            (point.y - layout.focusAnchorY)
                / PlaybackSubtitleFocusMetrics.cueSlotPitch
        ))
        for ordinal in (approximateOrdinal - 1)...(approximateOrdinal + 1) {
            guard ordinal != selectedOrdinal,
                  let hitRects = hitRectsByOrdinal[ordinal],
                  hitRects.contains(where: { $0.contains(point) })
            else {
                continue
            }
            return ordinal
        }
        if let hitRects = hitRectsByOrdinal[selectedOrdinal],
           hitRects.contains(where: { $0.contains(point) }) {
            return selectedOrdinal
        }
        return nil
    }

    private func updateHoveredOrdinal(_ ordinal: Int?) {
        let nextOrdinal = ordinal == selectedOrdinal ? nil : ordinal
        guard hoveredOrdinal != nextOrdinal else {
            return
        }
        let previousOrdinal = hoveredOrdinal
        hoveredOrdinal = nextOrdinal
        if let previousOrdinal {
            invalidateRow(previousOrdinal)
        }
        if let nextOrdinal {
            invalidateRow(nextOrdinal)
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func invalidateRow(_ ordinal: Int) {
        guard ordinal >= 0, ordinal < layout.totalCount else {
            return
        }
        setNeedsDisplay(layout.rowRect(for: ordinal))
    }

    private struct ContentIdentity: Equatable {
        let totalCount: Int
        let cueCount: Int
        let firstID: Int64?
        let lastID: Int64?
        let firstOrdinal: Int?
        let lastOrdinal: Int?

        init(cues: [SubtitleFocusCue], totalCount: Int) {
            self.totalCount = totalCount
            cueCount = cues.count
            firstID = cues.first?.id
            lastID = cues.last?.id
            firstOrdinal = cues.first?.ordinal
            lastOrdinal = cues.last?.ordinal
        }
    }
}

private final class PlaybackSubtitleFocusNativeTextLayout {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()
    private let paragraphStyle: NSParagraphStyle

    init() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = PlaybackSubtitleFocusMetrics.cueLineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping
        self.paragraphStyle = paragraphStyle

        layoutManager.usesFontLeading = true
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 2
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func draw(
        text: String,
        color: NSColor,
        in rect: CGRect
    ) -> [CGRect] {
        guard rect.width > 0, rect.height > 0, !text.isEmpty else {
            return []
        }

        textContainer.size = rect.size
        textStorage.beginEditing()
        textStorage.replaceCharacters(
            in: NSRange(location: 0, length: textStorage.length),
            with: text
        )
        textStorage.setAttributes(
            [
                .font: NSFont.systemFont(
                    ofSize: PlaybackSubtitleFocusMetrics.cueFontSize,
                    weight: .semibold
                ),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle,
            ],
            range: NSRange(location: 0, length: textStorage.length)
        )
        textStorage.endEditing()
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: rect.origin)

        var hitRects: [CGRect] = []
        layoutManager.enumerateLineFragments(
            forGlyphRange: glyphRange
        ) { _, usedRect, _, _, stop in
            guard usedRect.minY < rect.height else {
                stop.pointee = true
                return
            }
            let hitRect = usedRect
                .offsetBy(dx: rect.minX, dy: rect.minY)
                .intersection(rect)
            if !hitRect.isNull, hitRect.width > 0, hitRect.height > 0 {
                hitRects.append(hitRect)
            }
        }
        return hitRects
    }
}

@MainActor
final class PlaybackSubtitleFocusKeyboardOffsetAnimator: NSObject {
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
