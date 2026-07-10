import CueSeekerCore
import SwiftUI

struct PlaybackSubtitleFocusLayer: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let onOpenActionMenu: (SubtitleFocusCue, CGFloat) -> Bool
    let onOpenSelectedActionMenu: () -> Bool
    let onDismissActionMenu: () -> Bool
    let onExecuteAction: (PlaybackSubtitleFocusAction) -> Bool

    init(
        session: PlaybackSubtitleFocusSessionStore,
        onOpenActionMenu: ((SubtitleFocusCue, CGFloat) -> Bool)? = nil,
        onOpenSelectedActionMenu: (() -> Bool)? = nil,
        onDismissActionMenu: (() -> Bool)? = nil,
        onExecuteAction: ((PlaybackSubtitleFocusAction) -> Bool)? = nil
    ) {
        self.session = session
        self.onOpenActionMenu = onOpenActionMenu ?? { cue, focusAnchorY in
            session.openActionMenuFromPointer(
                for: cue,
                focusAnchorY: focusAnchorY
            )
        }
        self.onOpenSelectedActionMenu = onOpenSelectedActionMenu ?? {
            guard let cue = session.actionMenuCandidateForKeyboard() else {
                return false
            }
            return session.openActionMenuFromKeyboard(for: cue)
        }
        self.onDismissActionMenu = onDismissActionMenu ?? session.dismissActionMenu
        self.onExecuteAction = onExecuteAction ?? { action in
            guard let execution = session.beginActionMenuExecution(action: action) else {
                return false
            }
            return session.failActionMenuExecution(
                menuGeneration: execution.menuGeneration
            )
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
                focusAnchorY: session.focusAnchorY,
                keyboardNavigationRequest: session.keyboardNavigationRequest,
                actionMenuState: session.actionMenuState,
                isActionMenuOpening: session.isActionMenuOpening,
                onCommitKeyboardNavigation:
                    session.commitKeyboardNavigation,
                onCommitNativeReelSelection:
                    session.commitNativeReelSelection,
                allowsNativeWheelInput:
                    session.allowsNativeWheelInput,
                allowsNativeScrollbarInput:
                    session.allowsNativeScrollbarInput,
                consumeDeferredActionMenuOpen:
                    session.consumeDeferredActionMenuOpen,
                onScrollbarDraggingChanged: session.noteScrollbarDragging,
                onCueReelMotionChanged: session.noteCueReelMotion,
                onOpenActionMenu: onOpenActionMenu,
                onOpenSelectedActionMenu: onOpenSelectedActionMenu,
                onDismissActionMenu: onDismissActionMenu,
                onHoverActionMenuItem: session.hoverActionMenuItem,
                onExecuteAction: onExecuteAction
            )
        }
    }
}

struct PlaybackSubtitleFocusOverlay: View {
    let snapshot: SubtitleFocusSnapshot
    let cues: [SubtitleFocusCue]
    let focusAnchorY: CGFloat?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let actionMenuState: PlaybackSubtitleFocusActionMenuState?
    let isActionMenuOpening: Bool
    let onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool
    let onCommitNativeReelSelection: (Int) -> Bool
    let allowsNativeWheelInput: () -> Bool
    let allowsNativeScrollbarInput: () -> Bool
    let consumeDeferredActionMenuOpen: () -> Bool
    let onScrollbarDraggingChanged: (Bool) -> Void
    let onCueReelMotionChanged: (Bool) -> Void
    let onOpenActionMenu: (SubtitleFocusCue, CGFloat) -> Bool
    let onOpenSelectedActionMenu: () -> Bool
    let onDismissActionMenu: () -> Bool
    let onHoverActionMenuItem: (PlaybackSubtitleFocusAction) -> Bool
    let onExecuteAction: (PlaybackSubtitleFocusAction) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCueReelMotionActive = false

    init(
        snapshot: SubtitleFocusSnapshot,
        cues: [SubtitleFocusCue]? = nil,
        focusAnchorY: CGFloat? = nil,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest? = nil,
        actionMenuState: PlaybackSubtitleFocusActionMenuState? = nil,
        isActionMenuOpening: Bool = false,
        onCommitKeyboardNavigation: @escaping (
            PlaybackSubtitleFocusKeyboardNavigationRequest
        ) -> Bool = { _ in false },
        onCommitNativeReelSelection: @escaping (Int) -> Bool = { _ in false },
        allowsNativeWheelInput: @escaping () -> Bool = { false },
        allowsNativeScrollbarInput: @escaping () -> Bool = { false },
        consumeDeferredActionMenuOpen: @escaping () -> Bool = { false },
        onScrollbarDraggingChanged: @escaping (Bool) -> Void = { _ in },
        onCueReelMotionChanged: @escaping (Bool) -> Void = { _ in },
        onOpenActionMenu: @escaping (SubtitleFocusCue, CGFloat) -> Bool = { _, _ in false },
        onOpenSelectedActionMenu: @escaping () -> Bool = { false },
        onDismissActionMenu: @escaping () -> Bool = { false },
        onHoverActionMenuItem: @escaping (PlaybackSubtitleFocusAction) -> Bool = { _ in false },
        onExecuteAction: @escaping (PlaybackSubtitleFocusAction) -> Bool = { _ in false }
    ) {
        self.snapshot = snapshot
        self.cues = cues ?? snapshot.cues
        self.focusAnchorY = focusAnchorY
        self.keyboardNavigationRequest = keyboardNavigationRequest
        self.actionMenuState = actionMenuState
        self.isActionMenuOpening = isActionMenuOpening
        self.onCommitKeyboardNavigation = onCommitKeyboardNavigation
        self.onCommitNativeReelSelection = onCommitNativeReelSelection
        self.allowsNativeWheelInput = allowsNativeWheelInput
        self.allowsNativeScrollbarInput = allowsNativeScrollbarInput
        self.consumeDeferredActionMenuOpen = consumeDeferredActionMenuOpen
        self.onScrollbarDraggingChanged = onScrollbarDraggingChanged
        self.onCueReelMotionChanged = onCueReelMotionChanged
        self.onOpenActionMenu = onOpenActionMenu
        self.onOpenSelectedActionMenu = onOpenSelectedActionMenu
        self.onDismissActionMenu = onDismissActionMenu
        self.onHoverActionMenuItem = onHoverActionMenuItem
        self.onExecuteAction = onExecuteAction
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
            let resolvedFocusAnchorY = focusAnchorY
                ?? viewportSize.height / 2
            let blocksNavigation = actionMenuState != nil
                || isActionMenuOpening
                || keyboardNavigationRequest != nil

            ZStack(alignment: .top) {
                PlaybackTheme.subtitleFocusOverlayBackground

                PlaybackSubtitleFocusReelRepresentable(
                    cues: cues,
                    totalCount: snapshot.totalCount,
                    selectedOrdinal: snapshot.selectedOrdinal,
                    focusAnchorY: resolvedFocusAnchorY
                        - PlaybackSubtitleFocusMetrics.contentInset,
                    presentationTranslation: 0,
                    keyboardNavigationRequest: keyboardNavigationRequest,
                    reducesMotion: reduceMotion,
                    isInteractionEnabled: !blocksNavigation,
                    cancelsWheelMotion: actionMenuState != nil
                        || keyboardNavigationRequest != nil,
                    onActivateCue: { cue, viewportY in
                        openActionMenu(
                            cue,
                            focusAnchorY: PlaybackSubtitleFocusMetrics.contentInset + viewportY
                        )
                    },
                    onCommitKeyboardNavigation: { request in
                        onCommitKeyboardNavigation(request)
                    },
                    onCommitNativeReelSelection: onCommitNativeReelSelection,
                    allowsNativeWheelInput: allowsNativeWheelInput,
                    allowsNativeScrollbarInput: allowsNativeScrollbarInput,
                    onScrollbarDraggingChanged: onScrollbarDraggingChanged,
                    onNativeMotionGateChanged: onCueReelMotionChanged,
                    onKeyboardMotionChanged: { isActive in
                        if isActive {
                            beginCueReelMotion()
                        } else {
                            finishCueReelMotionImmediately()
                        }
                    }
                )
                .frame(
                    width: viewportSize.width,
                    height: cueViewportHeight,
                    alignment: .top
                )
                .offset(y: PlaybackSubtitleFocusMetrics.contentInset)
                .allowsHitTesting(!blocksNavigation)

                if let actionMenuState {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            _ = onDismissActionMenu()
                        }

                    let selectedCueFrame = CGRect(
                        x: (viewportSize.width - contentWidth) / 2,
                        y: resolvedFocusAnchorY,
                        width: contentWidth,
                        height: PlaybackSubtitleFocusMetrics.cueSlotHeight
                    )
                    let menuOrigin = PlaybackSubtitleFocusActionMenuPlacement.origin(
                        cueFrame: selectedCueFrame,
                        overlayBounds: CGRect(origin: .zero, size: viewportSize)
                    )
                    PlaybackSubtitleFocusActionMenu(
                        state: actionMenuState,
                        onHover: { action in
                            _ = onHoverActionMenuItem(action)
                        },
                        onExecute: { action in
                            _ = onExecuteAction(action)
                        }
                    )
                    .position(
                        x: menuOrigin.x
                            + PlaybackSubtitleFocusActionMenuMetrics.width / 2,
                        y: menuOrigin.y
                            + PlaybackSubtitleFocusActionMenuMetrics.height / 2
                    )
                }
            }
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipped()
            .contentShape(Rectangle())
            .environment(\.colorScheme, .dark)
        }
        .onDisappear {
            updateCueReelMotion(false)
        }
        .onChange(of: actionMenuState?.generation) { generation in
            guard generation != nil else {
                return
            }
            updateCueReelMotion(false)
        }
    }

    private func openActionMenu(
        _ cue: SubtitleFocusCue,
        focusAnchorY: CGFloat
    ) {
        guard actionMenuState == nil,
              !isActionMenuOpening,
              !isCueReelMotionActive
        else {
            return
        }

        guard onOpenActionMenu(cue, focusAnchorY) else {
            return
        }
    }

    private func beginCueReelMotion() {
        updateCueReelMotion(true)
    }

    private func finishCueReelMotionImmediately(
        opensDeferredMenu: Bool = true
    ) {
        updateCueReelMotion(false)
        if opensDeferredMenu {
            openDeferredActionMenuIfReady()
        }
    }

    private func updateCueReelMotion(_ isActive: Bool) {
        guard isCueReelMotionActive != isActive else {
            return
        }
        isCueReelMotionActive = isActive
        onCueReelMotionChanged(isActive)
    }

    private func openDeferredActionMenuIfReady() {
        guard actionMenuState == nil,
              consumeDeferredActionMenuOpen()
        else {
            return
        }
        _ = onOpenSelectedActionMenu()
    }
}
