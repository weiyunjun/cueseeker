import CueSeekerCore
import SwiftUI

struct PlaybackSubtitleFocusLayer: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool

    init(
        session: PlaybackSubtitleFocusSessionStore,
        onExecuteAction: ((PlaybackSubtitleFocusActionExecution) -> Bool)? = nil
    ) {
        self.session = session
        self.onExecuteAction = onExecuteAction ?? { execution in
            session.finishKeyboardAction(execution)
        }
    }

    var body: some View {
        switch session.state {
        case .closed, .opening:
            EmptyView()
        case .cueSelection(let snapshot):
            PlaybackSubtitleFocusOverlay(
                snapshot: snapshot,
                cues: session.completeCueBatch?.cues ?? snapshot.cues,
                keyboardNavigationRequest: session.keyboardNavigationRequest,
                blocksNewNavigation: session.pendingKeyboardAction != nil
                    || session.activeKeyboardAction != nil,
                onCommitKeyboardNavigation: session.commitKeyboardNavigation,
                onCommitNativeReelSelection: session.commitNativeReelSelection,
                allowsNativeWheelInput: session.allowsNativeWheelInput,
                allowsNativeScrollbarInput: session.allowsNativeScrollbarInput,
                consumeDeferredAction: session.consumeDeferredKeyboardActionIfReady,
                onScrollbarDraggingChanged: session.noteScrollbarDragging,
                onCueReelMotionChanged: session.noteCueReelMotion,
                onExecuteAction: onExecuteAction
            )
        }
    }
}

struct PlaybackSubtitleFocusOverlay: View {
    let snapshot: SubtitleFocusSnapshot
    let cues: [SubtitleFocusCue]
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let blocksNewNavigation: Bool
    let onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool
    let onCommitNativeReelSelection: (Int) -> Bool
    let allowsNativeWheelInput: () -> Bool
    let allowsNativeScrollbarInput: () -> Bool
    let consumeDeferredAction: () -> PlaybackSubtitleFocusActionExecution?
    let onScrollbarDraggingChanged: (Bool) -> Void
    let onCueReelMotionChanged: (Bool) -> Void
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        snapshot: SubtitleFocusSnapshot,
        cues: [SubtitleFocusCue]? = nil,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest? = nil,
        blocksNewNavigation: Bool = false,
        onCommitKeyboardNavigation: @escaping (
            PlaybackSubtitleFocusKeyboardNavigationRequest
        ) -> Bool = { _ in false },
        onCommitNativeReelSelection: @escaping (Int) -> Bool = { _ in false },
        allowsNativeWheelInput: @escaping () -> Bool = { false },
        allowsNativeScrollbarInput: @escaping () -> Bool = { false },
        consumeDeferredAction: @escaping () -> PlaybackSubtitleFocusActionExecution? = { nil },
        onScrollbarDraggingChanged: @escaping (Bool) -> Void = { _ in },
        onCueReelMotionChanged: @escaping (Bool) -> Void = { _ in },
        onExecuteAction: @escaping (PlaybackSubtitleFocusActionExecution) -> Bool = { _ in false }
    ) {
        self.snapshot = snapshot
        self.cues = cues ?? snapshot.cues
        self.keyboardNavigationRequest = keyboardNavigationRequest
        self.blocksNewNavigation = blocksNewNavigation
        self.onCommitKeyboardNavigation = onCommitKeyboardNavigation
        self.onCommitNativeReelSelection = onCommitNativeReelSelection
        self.allowsNativeWheelInput = allowsNativeWheelInput
        self.allowsNativeScrollbarInput = allowsNativeScrollbarInput
        self.consumeDeferredAction = consumeDeferredAction
        self.onScrollbarDraggingChanged = onScrollbarDraggingChanged
        self.onCueReelMotionChanged = onCueReelMotionChanged
        self.onExecuteAction = onExecuteAction
    }

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let cueViewportHeight = max(
                0,
                viewportSize.height - PlaybackSubtitleFocusMetrics.contentInset * 2
            )
            let blocksInteraction = blocksNewNavigation
                || keyboardNavigationRequest != nil

            ZStack(alignment: .top) {
                PlaybackTheme.subtitleFocusOverlayBackground

                PlaybackSubtitleFocusReelRepresentable(
                    cues: cues,
                    totalCount: snapshot.totalCount,
                    selectedOrdinal: snapshot.selectedOrdinal,
                    focusAnchorY: viewportSize.height / 2
                        - PlaybackSubtitleFocusMetrics.contentInset,
                    presentationTranslation: 0,
                    keyboardNavigationRequest: keyboardNavigationRequest,
                    reducesMotion: reduceMotion,
                    isInteractionEnabled: !blocksInteraction,
                    cancelsWheelMotion: keyboardNavigationRequest != nil,
                    onCommitKeyboardNavigation: onCommitKeyboardNavigation,
                    onCommitNativeReelSelection: onCommitNativeReelSelection,
                    allowsNativeWheelInput: allowsNativeWheelInput,
                    allowsNativeScrollbarInput: allowsNativeScrollbarInput,
                    onScrollbarDraggingChanged: { isDragging in
                        onScrollbarDraggingChanged(isDragging)
                        if !isDragging {
                            executeDeferredActionIfReady()
                        }
                    },
                    onNativeMotionGateChanged: handleCueReelMotionChanged,
                    onKeyboardMotionChanged: handleCueReelMotionChanged
                )
                .frame(
                    width: viewportSize.width,
                    height: cueViewportHeight,
                    alignment: .top
                )
                .offset(y: PlaybackSubtitleFocusMetrics.contentInset)
            }
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipped()
            .contentShape(Rectangle())
            .environment(\.colorScheme, .dark)
        }
        .onDisappear {
            onCueReelMotionChanged(false)
            onScrollbarDraggingChanged(false)
        }
    }

    private func handleCueReelMotionChanged(_ isActive: Bool) {
        onCueReelMotionChanged(isActive)
        if !isActive {
            executeDeferredActionIfReady()
        }
    }

    private func executeDeferredActionIfReady() {
        guard let execution = consumeDeferredAction() else {
            return
        }
        _ = onExecuteAction(execution)
    }
}
