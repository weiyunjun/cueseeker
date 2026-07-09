import AppKit
import CueSeekerCore
import SwiftUI

enum PlaybackSubtitleFocusTargetCommitMotion {
    static func insertionOffset(
        for direction: SubtitleFocusNavigationDirection
    ) -> CGFloat {
        direction == .backward
            ? -PlaybackSubtitleFocusMetrics.cueSlotPitch
            : PlaybackSubtitleFocusMetrics.cueSlotPitch
    }
}

enum PlaybackSubtitleFocusProtectedRange {
    static func resolve(
        loadedOrdinals: [Int],
        selectedOrdinal: Int,
        focusAnchorY: CGFloat,
        viewportMinY: CGFloat,
        viewportMaxY: CGFloat,
        presentationTranslation: CGFloat
    ) -> Range<Int>? {
        guard let loadedFirst = loadedOrdinals.first,
              let loadedLast = loadedOrdinals.last,
              viewportMaxY > viewportMinY
        else {
            return nil
        }

        let visibleOrdinals = loadedOrdinals.filter { ordinal in
            let cueTop = focusAnchorY
                + presentationTranslation
                + CGFloat(ordinal - selectedOrdinal)
                    * PlaybackSubtitleFocusMetrics.cueSlotPitch
            let cueBottom = cueTop + PlaybackSubtitleFocusMetrics.cueSlotHeight
            return cueTop < viewportMaxY && cueBottom > viewportMinY
        }
        guard let visibleFirst = visibleOrdinals.first,
              let visibleLast = visibleOrdinals.last
        else {
            guard loadedOrdinals.contains(selectedOrdinal) else {
                return nil
            }
            return max(loadedFirst, selectedOrdinal - 2)..<min(
                loadedLast + 1,
                selectedOrdinal + 3
            )
        }

        return max(loadedFirst, visibleFirst - 2)..<min(
            loadedLast + 1,
            visibleLast + 3
        )
    }
}

struct PlaybackSubtitleFocusLayer: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let onMoveSelection: (SubtitleFocusNavigationDirection) -> Bool
    let onNavigationIntent: (SubtitleFocusNavigationDirection) -> Void
    let onScrollbarPreview: (Int) -> Void
    let onCommitCachedScrollbarTarget: (Int) -> Bool
    let onRequestScrollbarTarget: (Int) -> Void

    init(
        session: PlaybackSubtitleFocusSessionStore,
        onMoveSelection: ((SubtitleFocusNavigationDirection) -> Bool)? = nil,
        onNavigationIntent: ((SubtitleFocusNavigationDirection) -> Void)? = nil,
        onScrollbarPreview: ((Int) -> Void)? = nil,
        onCommitCachedScrollbarTarget: ((Int) -> Bool)? = nil,
        onRequestScrollbarTarget: ((Int) -> Void)? = nil
    ) {
        self.session = session
        self.onMoveSelection = onMoveSelection ?? session.moveSelection
        self.onNavigationIntent = onNavigationIntent ?? { _ in }
        self.onScrollbarPreview = onScrollbarPreview ?? session.noteScrollbarPreviewChanged
        self.onCommitCachedScrollbarTarget = onCommitCachedScrollbarTarget
            ?? session.commitCachedScrollbarTarget
        self.onRequestScrollbarTarget = onRequestScrollbarTarget ?? { _ in }
    }

    var body: some View {
        switch session.state {
        case .closed, .opening:
            EmptyView()
        case .cueSelection(let snapshot):
            PlaybackSubtitleFocusOverlay(
                snapshot: snapshot,
                initialSelectedOrdinal: session.initialSelectedOrdinal,
                focusAnchorY: session.focusAnchorY,
                keyboardNavigationRequest: session.keyboardNavigationRequest,
                targetWindowState: session.targetWindowState,
                targetWindowCommit: session.targetWindowCommit,
                onProtectedVisibleRangeChanged:
                    session.updateProtectedVisibleOrdinalRange,
                takePendingKeyboardNavigationDirections:
                    session.takePendingKeyboardNavigationDirections,
                canMoveSelection: session.canMoveSelection,
                isCueCached: session.isCueCached,
                onMoveSelection: onMoveSelection,
                onNavigationIntent: onNavigationIntent,
                onSelectCue: session.selectCue,
                onScrollbarPreview: onScrollbarPreview,
                onCommitCachedScrollbarTarget: onCommitCachedScrollbarTarget,
                onRequestScrollbarTarget: onRequestScrollbarTarget
            )
        }
    }
}

struct PlaybackSubtitleFocusOverlay: View {
    let snapshot: SubtitleFocusSnapshot
    let initialSelectedOrdinal: Int?
    let focusAnchorY: CGFloat?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let targetWindowState: PlaybackSubtitleFocusTargetWindowState
    let targetWindowCommit: PlaybackSubtitleFocusTargetWindowCommit?
    let onProtectedVisibleRangeChanged: (Range<Int>?) -> Void
    let takePendingKeyboardNavigationDirections: () -> [SubtitleFocusNavigationDirection]
    let canMoveSelection: (SubtitleFocusNavigationDirection) -> Bool
    let isCueCached: (Int) -> Bool
    let onMoveSelection: (SubtitleFocusNavigationDirection) -> Bool
    let onNavigationIntent: (SubtitleFocusNavigationDirection) -> Void
    let onSelectCue: (Int, CGFloat) -> Bool
    let onScrollbarPreview: (Int) -> Void
    let onCommitCachedScrollbarTarget: (Int) -> Bool
    let onRequestScrollbarTarget: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wheelAccumulator = PlaybackSubtitleFocusWheelAccumulator()
    @State private var wheelSettleTask: Task<Void, Never>?
    @State private var reelPresentation = PlaybackSubtitleFocusReelPresentation()

    init(
        snapshot: SubtitleFocusSnapshot,
        initialSelectedOrdinal: Int? = nil,
        focusAnchorY: CGFloat? = nil,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest? = nil,
        targetWindowState: PlaybackSubtitleFocusTargetWindowState = .idle,
        targetWindowCommit: PlaybackSubtitleFocusTargetWindowCommit? = nil,
        onProtectedVisibleRangeChanged: @escaping (Range<Int>?) -> Void = { _ in },
        takePendingKeyboardNavigationDirections: @escaping () -> [SubtitleFocusNavigationDirection]
            = { [] },
        canMoveSelection: @escaping (SubtitleFocusNavigationDirection) -> Bool = { _ in false },
        isCueCached: @escaping (Int) -> Bool = { _ in false },
        onMoveSelection: @escaping (SubtitleFocusNavigationDirection) -> Bool = { _ in false },
        onNavigationIntent: @escaping (SubtitleFocusNavigationDirection) -> Void = { _ in },
        onSelectCue: @escaping (Int, CGFloat) -> Bool = { _, _ in false },
        onScrollbarPreview: @escaping (Int) -> Void = { _ in },
        onCommitCachedScrollbarTarget: @escaping (Int) -> Bool = { _ in false },
        onRequestScrollbarTarget: @escaping (Int) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.initialSelectedOrdinal = initialSelectedOrdinal
        self.focusAnchorY = focusAnchorY
        self.keyboardNavigationRequest = keyboardNavigationRequest
        self.targetWindowState = targetWindowState
        self.targetWindowCommit = targetWindowCommit
        self.onProtectedVisibleRangeChanged = onProtectedVisibleRangeChanged
        self.takePendingKeyboardNavigationDirections = takePendingKeyboardNavigationDirections
        self.canMoveSelection = canMoveSelection
        self.isCueCached = isCueCached
        self.onMoveSelection = onMoveSelection
        self.onNavigationIntent = onNavigationIntent
        self.onSelectCue = onSelectCue
        self.onScrollbarPreview = onScrollbarPreview
        self.onCommitCachedScrollbarTarget = onCommitCachedScrollbarTarget
        self.onRequestScrollbarTarget = onRequestScrollbarTarget
    }

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let contentWidth = max(
                0,
                min(
                    PlaybackSubtitleFocusMetrics.contentMaxWidth,
                    viewportSize.width - PlaybackSubtitleFocusMetrics.contentInset * 2
                )
            )
            let cueViewportHeight = max(
                0,
                viewportSize.height - PlaybackSubtitleFocusMetrics.contentInset * 2
            )
            let loadedStartOrdinal = snapshot.cues.first?.ordinal ?? 0
            let resolvedFocusAnchorY = focusAnchorY
                ?? PlaybackSubtitleFocusMetrics.initialFocusAnchorY(
                    stageHeight: viewportSize.height,
                    totalCount: snapshot.totalCount,
                    selectedOrdinal: initialSelectedOrdinal ?? snapshot.selectedOrdinal
                )
            let reelOffset = PlaybackSubtitleFocusMetrics.anchoredLoadedReelOffset(
                focusAnchorY: resolvedFocusAnchorY,
                selectedOrdinal: snapshot.selectedOrdinal,
                loadedStartOrdinal: loadedStartOrdinal
            )
            let targetCommitSequence = targetWindowCommit?.sequence ?? 0
            let targetCommitOffset = PlaybackSubtitleFocusTargetCommitMotion.insertionOffset(
                for: targetWindowCommit?.direction ?? .forward
            )
            let protectedVisibleRange = PlaybackSubtitleFocusProtectedRange.resolve(
                loadedOrdinals: snapshot.cues.map(\.ordinal),
                selectedOrdinal: snapshot.selectedOrdinal,
                focusAnchorY: resolvedFocusAnchorY,
                viewportMinY: PlaybackSubtitleFocusMetrics.contentInset,
                viewportMaxY: viewportSize.height - PlaybackSubtitleFocusMetrics.contentInset,
                presentationTranslation: wheelAccumulator.translation
            )

            ZStack(alignment: .top) {
                PlaybackTheme.subtitleFocusOverlayBackground

                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: PlaybackSubtitleFocusMetrics.cueGap) {
                        ForEach(snapshot.cues) { cue in
                            PlaybackSubtitleFocusCue(
                                cue: cue,
                                isSelected: cue.ordinal == snapshot.selectedOrdinal,
                                onClick: {
                                    let clickedAnchorY = PlaybackSubtitleFocusMetrics.contentInset
                                        + (reelPresentation.offset
                                            ?? reelOffset + wheelAccumulator.translation)
                                        + CGFloat(cue.ordinal - loadedStartOrdinal)
                                            * PlaybackSubtitleFocusMetrics.cueSlotPitch
                                    selectCue(
                                        cue,
                                        focusAnchorY: clickedAnchorY
                                    )
                                }
                            )
                        }
                    }
                    .frame(width: contentWidth, alignment: .topLeading)
                    .id(targetCommitSequence)
                    .transition(.asymmetric(
                        insertion: .offset(y: targetCommitOffset),
                        removal: .offset(y: -targetCommitOffset)
                    ))
                    .modifier(PlaybackSubtitleFocusReelOffsetEffect(
                        offset: reelOffset + wheelAccumulator.translation,
                        presentation: reelPresentation
                    ))
                }
                .animation(
                    reduceMotion ? nil : PlaybackSubtitleFocusMetrics.reelTransitionAnimation,
                    value: targetCommitSequence
                )
                .frame(
                    width: contentWidth,
                    height: cueViewportHeight,
                    alignment: .topLeading
                )
                .clipped()
                .offset(y: PlaybackSubtitleFocusMetrics.contentInset)

                PlaybackSubtitleFocusScrollCapture { output in
                    handleScroll(output)
                }
                .frame(width: viewportSize.width, height: viewportSize.height)
                .opacity(0.001)

                PlaybackSubtitleFocusScrollbar(
                    totalCount: snapshot.totalCount,
                    cueViewportHeight: cueViewportHeight,
                    committedOrdinal: snapshot.selectedOrdinal,
                    targetWindowState: targetWindowState,
                    isCueCached: isCueCached,
                    onPreviewChanged: onScrollbarPreview,
                    onCommitCachedTarget: onCommitCachedScrollbarTarget,
                    onRequestTarget: onRequestScrollbarTarget
                )
                .frame(
                    width: viewportSize.width,
                    height: cueViewportHeight
                )
                .offset(y: PlaybackSubtitleFocusMetrics.contentInset)

                PlaybackSubtitleFocusProtectedRangeReporter(
                    range: protectedVisibleRange,
                    onChange: onProtectedVisibleRangeChanged
                )
            }
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipped()
            .contentShape(Rectangle())
            .environment(\.colorScheme, .dark)
        }
        .onDisappear {
            wheelSettleTask?.cancel()
            wheelSettleTask = nil
        }
        .onAppear {
            drainPendingKeyboardNavigation()
        }
        .onChange(of: keyboardNavigationRequest) { _ in
            drainPendingKeyboardNavigation()
        }
    }

    private func drainPendingKeyboardNavigation() {
        for direction in takePendingKeyboardNavigationDirections() {
            handleKeyboardNavigation(direction)
        }
    }

    private func handleKeyboardNavigation(
        _ direction: SubtitleFocusNavigationDirection
    ) {
        wheelSettleTask?.cancel()
        wheelSettleTask = nil
        withAnimation(
            reduceMotion ? nil : PlaybackSubtitleFocusMetrics.reelTransitionAnimation
        ) {
            wheelAccumulator.finishSettling()
            _ = onMoveSelection(direction)
        }
    }

    private func handleScroll(_ output: PlaybackSubtitleFocusScrollOutput) {
        if output.deltaY != 0 {
            onNavigationIntent(output.deltaY > 0 ? .backward : .forward)
            wheelSettleTask?.cancel()
            wheelSettleTask = nil
            withTransaction(Transaction(animation: nil)) {
                wheelAccumulator.apply(
                    deltaY: output.deltaY,
                    canMoveSelection: canMoveSelection,
                    moveSelection: onMoveSelection
                )
            }
        }

        switch output.settleDirective {
        case .none:
            break
        case .cancel:
            wheelSettleTask?.cancel()
            wheelSettleTask = nil
        case .debounce:
            scheduleWheelSettle()
        case .immediate:
            settleWheel()
        }
    }

    private func scheduleWheelSettle() {
        wheelSettleTask?.cancel()
        wheelSettleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else {
                return
            }
            settleWheel()
        }
    }

    private func settleWheel() {
        wheelSettleTask?.cancel()
        wheelSettleTask = nil

        withTransaction(Transaction(animation: nil)) {
            wheelAccumulator.prepareToSettle(
                canMoveSelection: canMoveSelection,
                moveSelection: onMoveSelection
            )
        }
        withAnimation(
            reduceMotion ? nil : PlaybackSubtitleFocusMetrics.reelTransitionAnimation
        ) {
            wheelAccumulator.finishSettling()
        }
    }

    private func selectCue(
        _ cue: SubtitleFocusCue,
        focusAnchorY: CGFloat
    ) {
        guard cue.ordinal != snapshot.selectedOrdinal else {
            return
        }

        wheelSettleTask?.cancel()
        wheelSettleTask = nil
        withTransaction(Transaction(animation: nil)) {
            guard onSelectCue(cue.ordinal, focusAnchorY) else {
                return
            }
            wheelAccumulator.finishSettling()
        }
    }
}

private struct PlaybackSubtitleFocusProtectedRangeReporter: View {
    let range: Range<Int>?
    let onChange: (Range<Int>?) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear {
                onChange(range)
            }
            .onChange(of: range) { nextRange in
                onChange(nextRange)
            }
            .onDisappear {
                onChange(nil)
            }
    }
}

private struct PlaybackSubtitleFocusCue: View {
    let cue: SubtitleFocusCue
    let isSelected: Bool
    let onClick: () -> Void
    @State private var isHovered = false

    var body: some View {
        PlaybackSubtitleFocusCueText(
            text: cue.text,
            isSelected: isSelected,
            isHovered: isHovered
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(
            height: PlaybackSubtitleFocusMetrics.cueSlotHeight,
            alignment: .topLeading
        )
        .clipped()
        .contentShape(PlaybackSubtitleFocusCueHitShape(text: cue.text))
        .onTapGesture(perform: onClick)
        .onHover { isInside in
            isHovered = !isSelected && isInside
            if isInside {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .accessibilityLabel(cue.text)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onChange(of: isSelected) { selected in
            if selected {
                isHovered = false
            }
        }
    }
}

struct PlaybackSubtitleFocusCueText: View {
    let text: String
    let isSelected: Bool
    var isHovered = false

    var body: some View {
        Text(text)
            .font(.system(
                size: PlaybackSubtitleFocusMetrics.cueFontSize,
                weight: .semibold
            ))
            .lineSpacing(PlaybackSubtitleFocusMetrics.cueLineSpacing)
            .foregroundStyle(cueColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var cueColor: Color {
        if isSelected {
            return PlaybackTheme.subtitleFocusCueSelected
        }
        if isHovered {
            return PlaybackTheme.subtitleFocusCueHover
        }
        return PlaybackTheme.subtitleFocusCueUnselected
    }
}

struct PlaybackSubtitleFocusWheelAccumulator: Equatable {
    private(set) var translation: CGFloat = 0

    mutating func apply(
        deltaY: CGFloat,
        canMoveSelection: (SubtitleFocusNavigationDirection) -> Bool,
        moveSelection: (SubtitleFocusNavigationDirection) -> Bool
    ) {
        guard deltaY.isFinite, deltaY != 0 else {
            return
        }

        translation += deltaY

        if translation > 0, !canMoveSelection(.backward) {
            translation = 0
            return
        }
        if translation < 0, !canMoveSelection(.forward) {
            translation = 0
            return
        }

        while translation >= PlaybackSubtitleFocusMetrics.cueSlotPitch {
            guard moveSelection(.backward) else {
                translation = 0
                return
            }
            translation -= PlaybackSubtitleFocusMetrics.cueSlotPitch
        }
        while translation <= -PlaybackSubtitleFocusMetrics.cueSlotPitch {
            guard moveSelection(.forward) else {
                translation = 0
                return
            }
            translation += PlaybackSubtitleFocusMetrics.cueSlotPitch
        }
    }

    mutating func prepareToSettle(
        canMoveSelection: (SubtitleFocusNavigationDirection) -> Bool,
        moveSelection: (SubtitleFocusNavigationDirection) -> Bool
    ) {
        let threshold = PlaybackSubtitleFocusMetrics.cueSlotPitch / 2
        let direction: SubtitleFocusNavigationDirection?
        if translation >= threshold {
            direction = .backward
        } else if translation <= -threshold {
            direction = .forward
        } else {
            direction = nil
        }

        guard let direction,
              canMoveSelection(direction),
              moveSelection(direction)
        else {
            return
        }

        switch direction {
        case .backward:
            translation -= PlaybackSubtitleFocusMetrics.cueSlotPitch
        case .forward:
            translation += PlaybackSubtitleFocusMetrics.cueSlotPitch
        }
    }

    mutating func finishSettling() {
        translation = 0
    }
}

final class PlaybackSubtitleFocusReelPresentation {
    var offset: CGFloat?
}

struct PlaybackSubtitleFocusReelOffsetEffect: GeometryEffect {
    var offset: CGFloat
    let presentation: PlaybackSubtitleFocusReelPresentation

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        presentation.offset = offset
        return ProjectionTransform(CGAffineTransform(translationX: 0, y: offset))
    }
}

struct PlaybackSubtitleFocusCueHitShape: Shape {
    let text: String

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0, !text.isEmpty else {
            return Path()
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = PlaybackSubtitleFocusMetrics.cueLineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping
        let textStorage = NSTextStorage(
            string: text,
            attributes: [
                .font: NSFont.systemFont(
                    ofSize: PlaybackSubtitleFocusMetrics.cueFontSize,
                    weight: .semibold
                ),
                .paragraphStyle: paragraphStyle,
            ]
        )
        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = true
        let textContainer = NSTextContainer(
            size: CGSize(width: rect.width, height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 2
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        var result = Path()
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.enumerateLineFragments(
            forGlyphRange: glyphRange
        ) { _, usedRect, _, _, stop in
            guard usedRect.minY < rect.height else {
                stop.pointee = true
                return
            }
            let visibleRect = usedRect.intersection(
                CGRect(origin: .zero, size: rect.size)
            )
            if !visibleRect.isNull, visibleRect.width > 0, visibleRect.height > 0 {
                result.addRect(visibleRect)
            }
        }
        return result
    }
}

enum PlaybackSubtitleFocusScrollSettleDirective: Equatable {
    case none
    case cancel
    case debounce
    case immediate
}

struct PlaybackSubtitleFocusScrollOutput: Equatable {
    let shouldConsume: Bool
    let deltaY: CGFloat
    let settleDirective: PlaybackSubtitleFocusScrollSettleDirective

    static let passThrough = PlaybackSubtitleFocusScrollOutput(
        shouldConsume: false,
        deltaY: 0,
        settleDirective: .none
    )
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

struct PlaybackSubtitleFocusScrollSequence: Equatable {
    private var ownsSequence = false
    private var awaitsMomentum = false

    mutating func consume(
        _ sample: PlaybackSubtitleFocusScrollSample
    ) -> PlaybackSubtitleFocusScrollOutput {
        let isLegacyWheel = sample.phase == .none && sample.momentumPhase == .none
        if isLegacyWheel {
            guard sample.isInside else {
                return .passThrough
            }
            return output(for: sample, settleDirective: .debounce)
        }

        if sample.phase == .began {
            ownsSequence = sample.isInside
            awaitsMomentum = false
        } else if sample.momentumPhase == .began, awaitsMomentum {
            ownsSequence = true
            awaitsMomentum = false
        } else if !ownsSequence, !awaitsMomentum, sample.phase == .changed {
            ownsSequence = sample.isInside
        }

        guard ownsSequence else {
            return .passThrough
        }

        if sample.phase == .cancelled || sample.momentumPhase == .cancelled {
            ownsSequence = false
            awaitsMomentum = false
            return output(for: sample, settleDirective: .immediate)
        }
        if sample.momentumPhase == .ended {
            ownsSequence = false
            awaitsMomentum = false
            return output(for: sample, settleDirective: .immediate)
        }
        if sample.phase == .ended {
            ownsSequence = false
            awaitsMomentum = true
            return output(for: sample, settleDirective: .debounce)
        }
        if sample.momentumPhase == .began {
            return output(for: sample, settleDirective: .cancel)
        }
        return output(for: sample, settleDirective: .debounce)
    }

    mutating func reset() {
        ownsSequence = false
        awaitsMomentum = false
    }

    private func output(
        for sample: PlaybackSubtitleFocusScrollSample,
        settleDirective: PlaybackSubtitleFocusScrollSettleDirective
    ) -> PlaybackSubtitleFocusScrollOutput {
        PlaybackSubtitleFocusScrollOutput(
            shouldConsume: true,
            deltaY: sample.isPrecise
                ? sample.deltaY
                : sample.deltaY * PlaybackSubtitleFocusMetrics.cueSlotPitch,
            settleDirective: settleDirective
        )
    }
}

private struct PlaybackSubtitleFocusScrollCapture: NSViewRepresentable {
    let onScroll: (PlaybackSubtitleFocusScrollOutput) -> Void

    func makeNSView(context: Context) -> PlaybackSubtitleFocusScrollCaptureView {
        let view = PlaybackSubtitleFocusScrollCaptureView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(
        _ nsView: PlaybackSubtitleFocusScrollCaptureView,
        context: Context
    ) {
        nsView.onScroll = onScroll
    }

    static func dismantleNSView(
        _ nsView: PlaybackSubtitleFocusScrollCaptureView,
        coordinator: Void
    ) {
        nsView.invalidate()
    }
}

private final class PlaybackSubtitleFocusScrollCaptureView: NSView {
    var onScroll: (PlaybackSubtitleFocusScrollOutput) -> Void = { _ in }

    nonisolated(unsafe) private var eventMonitor: Any?
    private var sequence = PlaybackSubtitleFocusScrollSequence()

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            invalidate()
        } else {
            installMonitorIfNeeded()
        }
    }

    func invalidate() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        sequence.reset()
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    private func installMonitorIfNeeded() {
        guard eventMonitor == nil else {
            return
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window
            else {
                return event
            }

            let point = self.convert(event.locationInWindow, from: nil)
            let sample = PlaybackSubtitleFocusScrollSample(
                deltaY: event.scrollingDeltaY,
                isPrecise: event.hasPreciseScrollingDeltas,
                phase: Self.phase(from: event.phase),
                momentumPhase: Self.phase(from: event.momentumPhase),
                isInside: self.bounds.contains(point)
            )
            let output = self.sequence.consume(sample)
            guard output.shouldConsume else {
                return event
            }
            self.onScroll(output)
            return nil
        }
    }

    private static func phase(from phase: NSEvent.Phase) -> PlaybackSubtitleFocusScrollSample.Phase {
        if phase.contains(.began) {
            return .began
        }
        if phase.contains(.changed) || phase.contains(.mayBegin) || phase.contains(.stationary) {
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
}
