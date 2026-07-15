import CueSeekerCore
import SwiftUI

struct PlaybackSubtitleFocusLayer: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool
    let onOpenRecentItem: (RecentLibraryWatchingPresentation) -> Bool
    let onOpenLibraryEpisode: (CompleteLibraryVideoPresentation) -> Bool

    init(
        session: PlaybackSubtitleFocusSessionStore,
        uiProbeScope: String? = nil,
        onExecuteAction: ((PlaybackSubtitleFocusActionExecution) -> Bool)? = nil,
        onOpenRecentItem: ((RecentLibraryWatchingPresentation) -> Bool)? = nil,
        onOpenLibraryEpisode: ((CompleteLibraryVideoPresentation) -> Bool)? = nil
    ) {
        self.session = session
        self.uiProbeScope = uiProbeScope
        self.onExecuteAction = onExecuteAction ?? { execution in
            session.finishKeyboardAction(execution)
        }
        self.onOpenRecentItem = onOpenRecentItem ?? { _ in false }
        self.onOpenLibraryEpisode = onOpenLibraryEpisode ?? { _ in false }
    }

    var body: some View {
        switch session.state {
        case .closed, .opening:
            EmptyView()
        case .cueSelection(let snapshot):
            PlaybackMultiModuleOverlay(
                session: session,
                snapshot: snapshot,
                cues: session.completeCueBatch?.cues ?? snapshot.cues,
                uiProbeScope: uiProbeScope,
                onExecuteAction: onExecuteAction,
                onOpenRecentItem: onOpenRecentItem,
                onOpenLibraryEpisode: onOpenLibraryEpisode
            )
        }
    }
}

struct PlaybackMultiModuleOverlay: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let snapshot: SubtitleFocusSnapshot
    let cues: [SubtitleFocusCue]
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool
    let onOpenRecentItem: (RecentLibraryWatchingPresentation) -> Bool
    let onOpenLibraryEpisode: (CompleteLibraryVideoPresentation) -> Bool

    var body: some View {
        ZStack {
            PlaybackTheme.subtitleFocusOverlayBackground

            PlaybackSubtitleFocusPointerShield()

            HStack(spacing: 0) {
                PlaybackModuleSidebar(
                    modules: session.availableModules,
                    selectedModule: session.selectedModule,
                    onSelect: session.selectModule
                )
                .frame(width: PlaybackMultiModuleOverlayMetrics.sidebarWidth)
                .frame(maxHeight: .infinity)

                moduleContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var moduleContent: some View {
        if session.selectedModule == .current {
            PlaybackSubtitleFocusOverlay(
                snapshot: snapshot,
                cues: cues,
                contentGeneration: session.token.sessionGeneration,
                uiProbeScope: uiProbeScope,
                keyboardNavigationRequest: session.keyboardNavigationRequest,
                blocksNewNavigation: session.pendingKeyboardAction != nil
                    || session.activeKeyboardAction != nil,
                onCommitKeyboardNavigation: session.commitKeyboardNavigation,
                onCommitNativeReelSelection: session.commitNativeReelSelection,
                allowsNativeWheelInput: session.allowsNativeWheelInput,
                allowsNativeScrollbarInput: session.allowsNativeScrollbarInput,
                consumeDeferredAction: {
                    session.consumeDeferredKeyboardActionIfReady(
                        module: .current
                    )
                },
                onScrollbarDraggingChanged: {
                    session.noteScrollbarDragging($0, module: .current)
                },
                onCueReelMotionChanged: {
                    session.noteCueReelMotion($0, module: .current)
                },
                onExecuteAction: onExecuteAction
            )
        } else if session.selectedModule == .playlist,
                  let playlistWindow = session.playlistWindow {
            PlaybackCueResultOverlay(
                session: session,
                windowStore: playlistWindow,
                module: .playlist,
                showsSequenceNumber: true,
                uiProbeScope: uiProbeScope,
                onExecuteAction: onExecuteAction
            )
        } else if session.selectedModule == .search,
                  let searchStore = session.searchStore {
            PlaybackSearchOverlay(
                session: session,
                searchStore: searchStore,
                uiProbeScope: uiProbeScope,
                onExecuteAction: onExecuteAction
            )
        } else if session.selectedModule == .recent,
                  let recentStore = session.recentStore {
            PlaybackRecentOverlay(
                store: recentStore,
                onOpenItem: onOpenRecentItem
            )
        } else if session.selectedModule == .library,
                  let libraryStore = session.libraryStore {
            PlaybackLibraryOverlay(
                store: libraryStore,
                onOpenEpisode: onOpenLibraryEpisode
            )
        } else if session.selectedModule == .shiori,
                  let shioriWindow = session.shioriWindow {
            PlaybackCueResultOverlay(
                session: session,
                windowStore: shioriWindow,
                module: .shiori,
                showsSequenceNumber: false,
                uiProbeScope: uiProbeScope,
                onExecuteAction: onExecuteAction
            )
        } else {
            PlaybackTheme.subtitleFocusOverlayBackground
                .contentShape(Rectangle())
        }
    }
}

struct PlaybackModuleSidebar: View {
    let modules: [PlaybackOverlayModule]
    let selectedModule: PlaybackOverlayModule?
    let onSelect: (PlaybackOverlayModule) -> Bool

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: PlaybackMultiModuleOverlayMetrics.sidebarItemGap
        ) {
            ForEach(modules, id: \.self) { module in
                Button {
                    _ = onSelect(module)
                } label: {
                    HStack(spacing: PlaybackMultiModuleOverlayMetrics.sidebarLabelGap) {
                        Image(systemName: module.systemImage)
                            .font(.system(
                                size: PlaybackMultiModuleOverlayMetrics.sidebarItemIconSize,
                                weight: .medium
                            ))
                            .frame(
                                width: PlaybackMultiModuleOverlayMetrics.sidebarItemIconSize,
                                height: PlaybackMultiModuleOverlayMetrics.sidebarItemIconSize
                            )

                        Text(module.label)
                            .font(.system(
                                size: PlaybackMultiModuleOverlayMetrics.sidebarItemFontSize,
                                weight: .regular
                            ))
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(
                        selectedModule == module
                            ? PlaybackTheme.subtitleFocusCueSelected
                            : PlaybackTheme.subtitleFocusCueUnselected
                    )
                    .padding(
                        .horizontal,
                        PlaybackMultiModuleOverlayMetrics.sidebarItemHorizontalPadding
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: PlaybackMultiModuleOverlayMetrics.sidebarItemHeight,
                        maxHeight: PlaybackMultiModuleOverlayMetrics.sidebarItemHeight
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .pointerOnHover(isEnabled: true)
                .accessibilityLabel(module.label)
                .accessibilityIdentifier("playback-module-\(module.rawValue)")
            }

            Spacer(minLength: 0)
        }
        .padding(
            .horizontal,
            PlaybackMultiModuleOverlayMetrics.sidebarHorizontalPadding
        )
        .padding(
            .vertical,
            PlaybackMultiModuleOverlayMetrics.sidebarVerticalPadding
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
    }
}

struct PlaybackSubtitleFocusOverlay: View {
    let snapshot: SubtitleFocusSnapshot
    let cues: [SubtitleFocusCue]
    let contentGeneration: Int
    let uiProbeScope: String?
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
        contentGeneration: Int = 0,
        uiProbeScope: String? = nil,
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
        self.contentGeneration = contentGeneration
        self.uiProbeScope = uiProbeScope
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
        let _ = UIInvalidationProbe.count(
            "UI.PlaybackSubtitleFocusOverlay.body",
            scope: uiProbeScope
        )
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

                PlaybackSubtitleFocusPointerShield()

                // Keep the native pointer shield visually neutral in SwiftUI
                // rendering paths that cannot snapshot NSViewRepresentable.
                PlaybackTheme.subtitleFocusOverlayBackground
                    .allowsHitTesting(false)

                PlaybackSubtitleFocusReelRepresentable(
                    cues: cues,
                    totalCount: snapshot.totalCount,
                    selectedOrdinal: snapshot.selectedOrdinal,
                    contentGeneration: contentGeneration,
                    uiProbeScope: uiProbeScope,
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

private struct PlaybackSubtitleFocusPointerShield: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = PlaybackSubtitleFocusPointerShieldView()
        view.wantsLayer = true
        view.layer?.backgroundColor = PlaybackTheme
            .subtitleFocusOverlayBackgroundNative.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class PlaybackSubtitleFocusPointerShieldView: NSView {
    override var isOpaque: Bool {
        false
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        // The complete overlay owns pointer clicks, including its content
        // insets. Cue navigation remains exclusively wheel/scrollbar driven.
    }
}
