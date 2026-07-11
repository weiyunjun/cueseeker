import AppKit
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

struct PlaybackSubtitleFocusCueMeasurement: Equatable {
    let visualLineCount: Int
    let naturalHeight: CGFloat
    let resolvedHeight: CGFloat
    let isOversized: Bool
}

@MainActor
final class PlaybackSubtitleFocusCueTextMeasurer {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    init() {
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.usesFontLeading = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func measurement(
        text: String,
        width: CGFloat,
        viewportHeight: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        let lineCount = sourceLines(in: text).reduce(into: 0) { result, line in
            result += wrappedLineCount(line, width: width)
        }
        let resolvedLineCount = max(1, lineCount)
        let naturalHeight = max(
            PlaybackSubtitleFocusMetrics.minimumNaturalCueHeight,
            CGFloat(resolvedLineCount) * PlaybackSubtitleFocusMetrics.cueLineHeight
                + PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
        )
        let safeViewportHeight = max(0, viewportHeight)
        return PlaybackSubtitleFocusCueMeasurement(
            visualLineCount: resolvedLineCount,
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, safeViewportHeight),
            isOversized: naturalHeight > safeViewportHeight
        )
    }

    static func attributedString(
        _ text: String,
        color: NSColor
    ) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(
                ofSize: PlaybackSubtitleFocusMetrics.cueFontSize,
                weight: .semibold
            ),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ])
    }

    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.minimumLineHeight = PlaybackSubtitleFocusMetrics.cueLineHeight
        style.maximumLineHeight = PlaybackSubtitleFocusMetrics.cueLineHeight
        style.lineSpacing = 0
        style.paragraphSpacing = 0
        return style
    }

    private func wrappedLineCount(_ line: String, width: CGFloat) -> Int {
        guard !line.isEmpty else {
            return 1
        }
        textStorage.setAttributedString(Self.attributedString(line, color: .white))
        textContainer.size = CGSize(width: max(1, width), height: 1_000_000)
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else {
            return 1
        }
        var count = 0
        layoutManager.enumerateLineFragments(
            forGlyphRange: glyphRange
        ) { _, _, _, _, _ in
            count += 1
        }
        return max(1, count)
    }

    private func sourceLines(in text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }
}

struct PlaybackSubtitleFocusVirtualReelLayout: Equatable {
    static let overscanCueCount = 4

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

struct PlaybackSubtitleFocusCuePlacement: Equatable {
    let ordinal: Int
    let cueID: Int64
    let rect: CGRect
    let measurement: PlaybackSubtitleFocusCueMeasurement
}

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
        viewportHeight: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        accessSequence &+= 1
        let key = Key(
            cueID: cue.id,
            text: cue.text,
            width: width,
            viewportHeight: viewportHeight,
            styleRevision: 1
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
        UIInvalidationProbe.count(
            "playback.subtitle_focus.cue_measurement",
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
            "playback.subtitle_focus.native_make"
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
            "playback.subtitle_focus.native_update"
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
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion
        )
    }
}

final class PlaybackSubtitleFocusReelContainerView: NSView {
    var onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool = {
        _ in false
    }
    var onCommitNativeReelSelection: (Int) -> Bool = { _ in false }
    var allowsNativeWheelInput: () -> Bool = { false }
    var allowsNativeScrollbarInput: () -> Bool = { false }
    var onScrollbarDraggingChanged: (Bool) -> Void = { _ in }
    var onNativeMotionGateChanged: (Bool) -> Void = { _ in }
    var onKeyboardMotionChanged: (Bool) -> Void = { _ in }

    private let scrollView = PlaybackSubtitleFocusNativeScrollView()
    private let documentView = PlaybackSubtitleFocusReelDocumentView()
    private let scrollbarView = PlaybackSubtitleFocusNativeScrollbarView()
    private var totalCount = 0
    private var selectedOrdinal = 0
    private var fractionalOrdinal: CGFloat = 0
    private var hasInitializedPosition = false
    private var loadedOrdinalRange: Range<Int> = 0..<0
    private var isInteractionEnabled = true
    private var reducesMotion = false
    private var hasCompleteCueCollection = false
    private var lastViewportSize: CGSize = .zero
    private var lastHandledKeyboardSequence = 0
    private var activeKeyboardRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    private var isKeyboardMotionActive = false
    private var activeWheelTargetOrdinal: Int?
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

        scrollbarView.appearanceMode = .fixedDark
        scrollbarView.cursorPolicy = .pointingHand
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
           !hasActiveNativeMotion {
            fractionalOrdinal = CGFloat(selectedOrdinal)
        }
        if lastViewportSize != .zero,
           nextViewportSize != lastViewportSize {
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.reflow",
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
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool,
        isInteractionEnabled: Bool,
        cancelsWheelMotion: Bool
    ) {
        self.totalCount = max(0, totalCount)
        let previousSelectedOrdinal = self.selectedOrdinal
        self.selectedOrdinal = min(
            max(0, selectedOrdinal),
            max(0, totalCount - 1)
        )
        if let firstOrdinal = cues.first?.ordinal,
           let lastOrdinal = cues.last?.ordinal {
            loadedOrdinalRange = firstOrdinal..<(lastOrdinal + 1)
        } else {
            loadedOrdinalRange = 0..<0
        }
        hasCompleteCueCollection = cues.count == self.totalCount
            && loadedOrdinalRange == 0..<self.totalCount
        self.reducesMotion = reducesMotion
        let wasInteractionEnabled = self.isInteractionEnabled
        self.isInteractionEnabled = isInteractionEnabled
        if cancelsWheelMotion {
            cancelActiveScrollbarDrag()
            resetWheelInteraction(requiresNewGesture: true)
        } else if wasInteractionEnabled, !isInteractionEnabled {
            suspendWheelInputForSuppression()
        }
        documentView.updateContent(cues: cues, totalCount: totalCount)
        if !hasInitializedPosition {
            fractionalOrdinal = CGFloat(self.selectedOrdinal)
            hasInitializedPosition = true
        } else if previousSelectedOrdinal != self.selectedOrdinal,
                  !hasActiveNativeMotion {
            fractionalOrdinal = CGFloat(self.selectedOrdinal)
        }
        fractionalOrdinal = boundedLoadedFractionalOrdinal(fractionalOrdinal)
        updateDocumentGeometry()
        updateScrollbarPresentation()
        if !hasActiveNativeMotion {
            documentView.updateSelection(self.selectedOrdinal)
            synchronizeFractionalOrdinalIfIdle()
        }
        handleKeyboardNavigation(
            keyboardNavigationRequest,
            reducesMotion: reducesMotion
        )
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
        activeWheelTargetOrdinal = nil
        preciseGestureStartOrdinal = nil
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
        documentView.invalidate()
        scrollView.documentView = nil
    }

    var fractionalOrdinalForTesting: CGFloat {
        fractionalOrdinal
    }

    var selectedOrdinalForTesting: Int {
        selectedOrdinal
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
              preciseGestureStartOrdinal == nil
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
            && hasCompleteCueCollection
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
        guard let request,
              request.sequence > lastHandledKeyboardSequence,
              request.targetOrdinal >= 0,
              request.targetOrdinal < totalCount
        else {
            return
        }

        lastHandledKeyboardSequence = request.sequence
        UIInvalidationProbe.mark(
            "ACTION playback.subtitle_focus.keyboard_navigation",
            details: "target=\(request.targetOrdinal)"
        )
        activeKeyboardRequest = request
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
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.scrollbar_drag",
                details: "phase=began"
            )
            isScrollbarDragging = true
            onScrollbarDraggingChanged(true)
            setScrollbarMotionActive(true)
        } else {
            isScrollbarDragging = false
            onScrollbarDraggingChanged(false)
            setScrollbarMotionActive(false)
            updateScrollbarInteractionAvailability()
            scrollbarView.scrollbarMetricsDidChange()
        }
    }

    func handleScrollbarDrag(_ event: TableScrollbarDragEvent) {
        guard event.axis == .vertical,
              hasCompleteCueCollection,
              isScrollbarDragging
        else {
            return
        }

        switch event.phase {
        case .began:
            break
        case .changed:
            applyScrollbarPositionFraction(
                event.positionFraction,
                refreshesScrollbar: false
            )
        case .ended:
            applyScrollbarPositionFraction(
                event.positionFraction,
                refreshesScrollbar: true
            )
            settleScrollbarDrag()
        case .cancelled:
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            documentView.updateSelection(selectedOrdinal)
            synchronizeFractionalOrdinalIfIdle()
        }
    }

    private func applyScrollbarPositionFraction(
        _ positionFraction: CGFloat,
        refreshesScrollbar: Bool
    ) {
        let metrics = scrollbarMetrics
        let position = metrics.fractionalOrdinal(for: positionFraction)
        setFractionalOrdinal(position, refreshesScrollbar: refreshesScrollbar)
        documentView.updateSelection(currentLayout.nearestOrdinal)
    }

    private func settleScrollbarDrag() {
        let targetOrdinal = currentLayout.nearestOrdinal
        activeWheelTargetOrdinal = targetOrdinal
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
        let startOrdinal = activeWheelTargetOrdinal ?? selectedOrdinal
        let delta = direction == .backward ? -stepCount : stepCount
        let targetOrdinal = boundedLoadedOrdinal(startOrdinal + delta)
        guard targetOrdinal != startOrdinal else {
            return
        }
        UIInvalidationProbe.mark(
            "ACTION playback.subtitle_focus.wheel",
            details: "mode=discrete target=\(targetOrdinal)"
        )

        preciseGestureStartOrdinal = nil
        activeWheelTargetOrdinal = targetOrdinal
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
        if beginsGesture || preciseGestureStartOrdinal == nil {
            cancelPreciseSettle()
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            preciseGestureStartOrdinal = currentLayout.nearestOrdinal
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.wheel",
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
        guard preciseGestureStartOrdinal != nil else {
            return
        }

        let targetOrdinal = currentLayout.nearestOrdinal

        preciseGestureStartOrdinal = nil
        activeWheelTargetOrdinal = targetOrdinal
        documentView.updateSelection(targetOrdinal)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
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
            synchronizeFractionalOrdinalIfIdle()
        }
    }

    private func resetWheelInteraction(requiresNewGesture: Bool) {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: requiresNewGesture)
        wheelAnimator.cancel()
        activeWheelTargetOrdinal = nil
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

    private func boundedLoadedOrdinal(_ ordinal: Int) -> Int {
        guard !loadedOrdinalRange.isEmpty else {
            return selectedOrdinal
        }
        return min(
            max(loadedOrdinalRange.lowerBound, ordinal),
            loadedOrdinalRange.upperBound - 1
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
        activeKeyboardRequest != nil
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
    private let textLayout = PlaybackSubtitleFocusNativeTextLayout()
    private let measurementCache = PlaybackSubtitleFocusCueMeasurementCache()
    private var layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: .zero,
        totalCount: 0,
        loadedOrdinalRange: 0..<0,
        fractionalOrdinal: 0
    )
    private var cues: [SubtitleFocusCue] = []
    private var firstLoadedOrdinal = 0
    private var contentIdentity: ContentIdentity?
    private var selectedOrdinal = 0
    private(set) var placements: [PlaybackSubtitleFocusCuePlacement] = []

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
        measurementCache.removeAll()
        resolveLocalPlacementsIfNeeded()
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
    }

    func updateLocalLayout(_ layout: PlaybackSubtitleFocusVirtualReelLayout) {
        guard self.layout != layout else {
            return
        }
        self.layout = layout
        UIInvalidationProbe.count(
            "playback.subtitle_focus.layout_update",
            details: "ordinal=\(layout.fractionalOrdinal)"
        )
        resolveLocalPlacementsIfNeeded()
        needsDisplay = true
    }

    func invalidate() {
        cues.removeAll(keepingCapacity: false)
        contentIdentity = nil
        placements.removeAll(keepingCapacity: false)
        measurementCache.removeAll()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let visibleDirtyRect = dirtyRect.intersection(visibleRect)
        guard !visibleDirtyRect.isNull, !visibleDirtyRect.isEmpty else {
            return
        }
        for placement in placements where placement.rect.intersects(visibleDirtyRect) {
            guard let cue = cue(at: placement.ordinal) else {
                continue
            }
            UIInvalidationProbe.count(
                "playback.subtitle_focus.cue_draw",
                details: "ordinal=\(placement.ordinal)"
            )
            draw(cue: cue, ordinal: placement.ordinal, in: placement.rect)
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
        measurementCache.count
    }

    var measuredOrdinals: Set<Int> {
        measurementCache.measuredOrdinals
    }

    private func draw(
        cue: SubtitleFocusCue,
        ordinal: Int,
        in rowRect: CGRect
    ) {
            let color: NSColor
            if ordinal == selectedOrdinal {
                color = PlaybackTheme.subtitleFocusCueSelectedNative
            } else {
                color = PlaybackTheme.subtitleFocusCueUnselectedNative
            }
            textLayout.draw(
                text: cue.text,
                color: color,
                in: rowRect
            )
    }

    override func mouseDown(with event: NSEvent) {
        // Cue-specific pointer activation is intentionally absent. Keep the
        // event inside the focus overlay so it cannot reach the video surface.
    }

    private func cue(at ordinal: Int) -> SubtitleFocusCue? {
        let index = ordinal - firstLoadedOrdinal
        guard cues.indices.contains(index), cues[index].ordinal == ordinal else {
            return nil
        }
        return cues[index]
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
        resolved[layout.lowerOrdinal] = placement(
            ordinal: layout.lowerOrdinal,
            top: lowerTop,
            measurement: lowerMeasurement,
            layout: layout
        )

        if layout.upperOrdinal != layout.lowerOrdinal {
            resolved[layout.upperOrdinal] = placement(
                ordinal: layout.upperOrdinal,
                top: lowerTop + lowerMeasurement.resolvedHeight
                    + PlaybackSubtitleFocusMetrics.cueGap,
                measurement: upperMeasurement,
                layout: layout
            )
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
                    break
                }
                let top = nextTop
                    - PlaybackSubtitleFocusMetrics.cueGap
                    - measurement.resolvedHeight
                let item = placement(
                    ordinal: ordinal,
                    top: top,
                    measurement: measurement,
                    layout: layout
                )
                resolved[ordinal] = item
                nextTop = top
                if item.rect.maxY < 0 {
                    outsideCount += 1
                    if outsideCount
                        >= PlaybackSubtitleFocusVirtualReelLayout.overscanCueCount {
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
                    break
                }
                let top = nextBottom + PlaybackSubtitleFocusMetrics.cueGap
                let item = placement(
                    ordinal: ordinal,
                    top: top,
                    measurement: measurement,
                    layout: layout
                )
                resolved[ordinal] = item
                nextBottom = item.rect.maxY
                if item.rect.minY > layout.viewportSize.height {
                    outsideCount += 1
                    if outsideCount
                        >= PlaybackSubtitleFocusVirtualReelLayout.overscanCueCount {
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
        guard let cue = cue(at: ordinal) else {
            return nil
        }
        return measurementCache.measurement(
            for: cue,
            width: layout.contentWidth,
            viewportHeight: layout.viewportSize.height
        )
    }

    private func placement(
        ordinal: Int,
        top: CGFloat,
        measurement: PlaybackSubtitleFocusCueMeasurement,
        layout: PlaybackSubtitleFocusVirtualReelLayout
    ) -> PlaybackSubtitleFocusCuePlacement {
        let cue = cue(at: ordinal)
        return PlaybackSubtitleFocusCuePlacement(
            ordinal: ordinal,
            cueID: cue?.id ?? 0,
            rect: CGRect(
                x: (layout.viewportSize.width - layout.contentWidth) / 2,
                y: top,
                width: layout.contentWidth,
                height: measurement.resolvedHeight
            ),
            measurement: measurement
        )
    }

    private struct ContentIdentity: Equatable {
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
}

@MainActor
final class PlaybackSubtitleFocusNativeTextLayout {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    init() {
        layoutManager.usesFontLeading = false
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func draw(
        text: String,
        color: NSColor,
        in rect: CGRect
    ) {
        guard let glyphRange = prepare(
            text: text,
            color: color,
            in: rect
        ) else {
            return
        }

        let textRect = Self.textRect(in: rect)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: textRect.origin)
    }

    func visibleLineRects(
        text: String,
        in rect: CGRect
    ) -> [CGRect] {
        guard let glyphRange = prepare(
            text: text,
            color: .white,
            in: rect
        ) else {
            return []
        }
        return hitRects(for: glyphRange, in: Self.textRect(in: rect))
    }

    private func prepare(
        text: String,
        color: NSColor,
        in rect: CGRect
    ) -> NSRange? {
        let textRect = Self.textRect(in: rect)
        guard textRect.width > 0, textRect.height > 0, !text.isEmpty else {
            return nil
        }
        textContainer.size = textRect.size
        textStorage.setAttributedString(
            PlaybackSubtitleFocusCueTextMeasurer.attributedString(
                text,
                color: color
            )
        )
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.glyphRange(for: textContainer)
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

    private func hitRects(
        for glyphRange: NSRange,
        in rect: CGRect
    ) -> [CGRect] {
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
