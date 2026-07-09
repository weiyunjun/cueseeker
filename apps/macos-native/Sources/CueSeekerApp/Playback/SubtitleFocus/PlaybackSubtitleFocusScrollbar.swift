import SwiftUI

struct PlaybackSubtitleFocusScrollbarMetrics: Equatable {
    let totalCount: Int
    let cueViewportHeight: CGFloat
    let displayedOrdinal: Int

    var presentation: TableScrollbarPresentation {
        guard totalCount > 0 else {
            return TableScrollbarPresentation()
        }
        let documentHeight = PlaybackSubtitleFocusMetrics.reelHeight(
            cueCount: totalCount
        )
        let visibleFraction = documentHeight > 0
            ? min(1, max(0, cueViewportHeight / documentHeight))
            : 1
        let positionFraction = totalCount > 1
            ? CGFloat(boundedOrdinal) / CGFloat(totalCount - 1)
            : 0
        return TableScrollbarPresentation(
            vertical: TableScrollbarAxisPresentation(
                visibleFraction: visibleFraction,
                positionFraction: positionFraction
            )
        )
    }

    func ordinal(for positionFraction: CGFloat) -> Int? {
        guard totalCount > 0 else {
            return nil
        }
        guard totalCount > 1 else {
            return 0
        }
        let boundedFraction = min(1, max(0, positionFraction))
        return Int(
            (boundedFraction * CGFloat(totalCount - 1)).rounded()
        )
    }

    private var boundedOrdinal: Int {
        min(max(0, displayedOrdinal), max(0, totalCount - 1))
    }
}

enum PlaybackSubtitleFocusScrollbarInteractionEffect: Equatable {
    case cancelDebounce
    case publishPreview(Int)
    case scheduleDebounce(Int)
    case commitCachedTarget(Int)
    case requestTarget(Int)
}

struct PlaybackSubtitleFocusScrollbarInteractionState: Equatable {
    static let stableTargetDelayNanoseconds: UInt64 = 100_000_000

    private(set) var previewOrdinal: Int?
    private(set) var isDragging = false
    private(set) var lastRequestedTarget: Int?
    private(set) var failedStableTarget: Int?

    mutating func synchronizeCommittedOrdinal(
        _ ordinal: Int,
        force: Bool = false
    ) {
        if force || !isDragging {
            previewOrdinal = ordinal
        }
    }

    mutating func resolveTarget(
        committedOrdinal: Int
    ) -> [PlaybackSubtitleFocusScrollbarInteractionEffect] {
        if let lastRequestedTarget,
           lastRequestedTarget != committedOrdinal {
            failedStableTarget = lastRequestedTarget
        } else {
            failedStableTarget = nil
        }
        self.lastRequestedTarget = nil
        previewOrdinal = committedOrdinal
        return [.cancelDebounce]
    }

    mutating func handleDrag(
        phase: TableScrollbarDragPhase,
        targetOrdinal: Int,
        committedOrdinal: Int,
        isCached: Bool
    ) -> [PlaybackSubtitleFocusScrollbarInteractionEffect] {
        switch phase {
        case .began:
            isDragging = true
            return []

        case .changed:
            guard targetOrdinal != previewOrdinal else {
                return []
            }
            updatePreview(targetOrdinal)
            var effects: [PlaybackSubtitleFocusScrollbarInteractionEffect] = [
                .cancelDebounce,
                .publishPreview(targetOrdinal),
            ]
            if isCached {
                lastRequestedTarget = nil
                failedStableTarget = nil
                effects.append(.commitCachedTarget(targetOrdinal))
            } else if failedStableTarget != targetOrdinal {
                effects.append(.scheduleDebounce(targetOrdinal))
            }
            return effects

        case .ended:
            isDragging = false
            var effects: [PlaybackSubtitleFocusScrollbarInteractionEffect] = [
                .cancelDebounce,
            ]
            if targetOrdinal != previewOrdinal {
                updatePreview(targetOrdinal)
                effects.append(.publishPreview(targetOrdinal))
            }
            if isCached {
                lastRequestedTarget = nil
                failedStableTarget = nil
                effects.append(.commitCachedTarget(targetOrdinal))
            } else {
                lastRequestedTarget = targetOrdinal
                effects.append(.requestTarget(targetOrdinal))
            }
            return effects

        case .cancelled:
            isDragging = false
            var effects: [PlaybackSubtitleFocusScrollbarInteractionEffect] = [
                .cancelDebounce,
            ]
            if previewOrdinal != committedOrdinal {
                previewOrdinal = committedOrdinal
                effects.append(.publishPreview(committedOrdinal))
            }
            lastRequestedTarget = nil
            failedStableTarget = nil
            return effects
        }
    }

    mutating func debounceElapsed(
        for ordinal: Int,
        isCached: Bool
    ) -> PlaybackSubtitleFocusScrollbarInteractionEffect? {
        guard isDragging,
              previewOrdinal == ordinal,
              failedStableTarget != ordinal,
              !isCached
        else {
            return nil
        }
        lastRequestedTarget = ordinal
        return .requestTarget(ordinal)
    }

    private mutating func updatePreview(_ ordinal: Int) {
        if let lastRequestedTarget,
           lastRequestedTarget != ordinal {
            self.lastRequestedTarget = nil
        }
        if failedStableTarget != ordinal {
            failedStableTarget = nil
        }
        previewOrdinal = ordinal
    }
}

struct PlaybackSubtitleFocusScrollbar: View {
    let totalCount: Int
    let cueViewportHeight: CGFloat
    let committedOrdinal: Int
    let targetWindowState: PlaybackSubtitleFocusTargetWindowState
    let isCueCached: (Int) -> Bool
    let onPreviewChanged: (Int) -> Void
    let onCommitCachedTarget: (Int) -> Bool
    let onRequestTarget: (Int) -> Void

    @State private var interaction = PlaybackSubtitleFocusScrollbarInteractionState()
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        let metrics = PlaybackSubtitleFocusScrollbarMetrics(
            totalCount: totalCount,
            cueViewportHeight: cueViewportHeight,
            displayedOrdinal: interaction.previewOrdinal ?? committedOrdinal
        )
        PlaybackSubtitleFocusScrollbarRepresentable(
            presentation: metrics.presentation,
            isPresented: totalCount > 0,
            onDrag: { event in
                handleDrag(event, metrics: metrics)
            }
        )
        .onAppear {
            interaction.synchronizeCommittedOrdinal(committedOrdinal, force: true)
        }
        .onDisappear {
            cancelDebounce()
        }
        .onChange(of: committedOrdinal) { ordinal in
            interaction.synchronizeCommittedOrdinal(ordinal)
        }
        .onChange(of: targetWindowState.resolutionGeneration) { _ in
            perform(interaction.resolveTarget(committedOrdinal: committedOrdinal))
        }
    }

    private func handleDrag(
        _ event: TableScrollbarDragEvent,
        metrics: PlaybackSubtitleFocusScrollbarMetrics
    ) {
        guard event.axis == .vertical,
              let targetOrdinal = metrics.ordinal(
                for: event.positionFraction
              )
        else {
            return
        }

        let effects = interaction.handleDrag(
            phase: event.phase,
            targetOrdinal: targetOrdinal,
            committedOrdinal: committedOrdinal,
            isCached: isCueCached(targetOrdinal)
        )
        perform(effects)
    }

    private func scheduleDebounce(for ordinal: Int) {
        cancelDebounce()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: PlaybackSubtitleFocusScrollbarInteractionState
                    .stableTargetDelayNanoseconds
            )
            guard !Task.isCancelled else {
                return
            }
            debounceTask = nil
            guard let effect = interaction.debounceElapsed(
                for: ordinal,
                isCached: isCueCached(ordinal)
            ) else {
                return
            }
            perform([effect])
        }
    }

    private func perform(
        _ effects: [PlaybackSubtitleFocusScrollbarInteractionEffect]
    ) {
        for effect in effects {
            switch effect {
            case .cancelDebounce:
                cancelDebounce()
            case .publishPreview(let ordinal):
                onPreviewChanged(ordinal)
            case .scheduleDebounce(let ordinal):
                scheduleDebounce(for: ordinal)
            case .commitCachedTarget(let ordinal):
                _ = onCommitCachedTarget(ordinal)
            case .requestTarget(let ordinal):
                onRequestTarget(ordinal)
            }
        }
    }

    private func cancelDebounce() {
        debounceTask?.cancel()
        debounceTask = nil
    }
}

private struct PlaybackSubtitleFocusScrollbarRepresentable: NSViewRepresentable {
    let presentation: TableScrollbarPresentation
    let isPresented: Bool
    let onDrag: (TableScrollbarDragEvent) -> Void

    func makeNSView(context: Context) -> TableScrollbarOverlayView {
        let view = TableScrollbarOverlayView()
        view.appearanceMode = .fixedDark
        view.cursorPolicy = .pointingHand
        return view
    }

    func updateNSView(
        _ nsView: TableScrollbarOverlayView,
        context: Context
    ) {
        nsView.presentationProvider = { presentation }
        nsView.onDrag = onDrag
        nsView.isPresented = isPresented
        nsView.scrollbarMetricsDidChange()
    }

    static func dismantleNSView(
        _ nsView: TableScrollbarOverlayView,
        coordinator: Void
    ) {
        nsView.isPresented = false
        nsView.presentationProvider = { nil }
        nsView.onDrag = { _ in }
    }
}
