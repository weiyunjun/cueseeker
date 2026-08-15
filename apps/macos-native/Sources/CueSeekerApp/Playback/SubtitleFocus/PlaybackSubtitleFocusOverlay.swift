import CueSeekerCore
import CueSeekerPlayback
import Foundation
import SwiftUI

struct PlaybackSubtitleFocusLayer: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool
    let onOpenLibraryEpisode: (CompleteLibraryVideoPresentation) -> Bool
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void

    init(
        session: PlaybackSubtitleFocusSessionStore,
        uiProbeScope: String? = nil,
        onExecuteAction: ((PlaybackSubtitleFocusActionExecution) -> Bool)? = nil,
        onCopySelectedText: @escaping (String) -> Void = { _ in },
        onSearchSelectedText: @escaping (String) -> Void = { _ in },
        onOpenLibraryEpisode:
            @escaping (CompleteLibraryVideoPresentation) -> Bool = {
                _ in false
            }
    ) {
        self.session = session
        self.uiProbeScope = uiProbeScope
        self.onExecuteAction = onExecuteAction ?? { execution in
            session.finishKeyboardAction(execution)
        }
        self.onCopySelectedText = onCopySelectedText
        self.onSearchSelectedText = onSearchSelectedText
        self.onOpenLibraryEpisode = onOpenLibraryEpisode
    }

    var body: some View {
        switch session.state {
        case .closed, .opening:
            EmptyView()
        case .cueSelection(let snapshot):
            PlaybackOverlay(
                session: session,
                snapshot: snapshot,
                cues: session.completeCueBatch?.cues ?? snapshot.cues,
                uiProbeScope: uiProbeScope,
                onExecuteAction: onExecuteAction,
                onCopySelectedText: onCopySelectedText,
                onSearchSelectedText: onSearchSelectedText,
                onOpenLibraryEpisode: onOpenLibraryEpisode
            )
        }
    }
}

struct PlaybackOverlay: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let snapshot: SubtitleFocusSnapshot
    let cues: [SubtitleFocusCue]
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void
    let onOpenLibraryEpisode: (CompleteLibraryVideoPresentation) -> Bool

    var body: some View {
        ZStack {
            PlaybackTheme.subtitleFocusOverlayBackground

            PlaybackSubtitleFocusPointerShield()

            VStack(spacing: 0) {
                PlaybackOverlayTopBar(
                    modules: session.availableModules.filter {
                        $0 == .current || $0 == .playlist
                    },
                    selectedModule: session.selectedModule,
                    isEditingCollage: session.isEditingCollage,
                    onSelect: session.selectModule,
                    onToggleEditingCollage: session.toggleEditingCollage
                )
                .frame(height: PlaybackOverlayMetrics.tabBarHeight)

                moduleContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var moduleContent: some View {
        if session.selectedModule == .current {
            if session.isEditingCollage,
               let previewStore = session.collagePreviewStore {
                PlaybackCollageEditor(
                    plan: session.collageSelectionPlan,
                    displayTitle: currentDisplayTitle,
                    previewStore: previewStore,
                    uiProbeScope: uiProbeScope
                ) {
                    currentSubtitleOverlay
                }
            } else {
                currentSubtitleOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if session.selectedModule == .playlist {
            if let libraryStore = session.libraryStore {
                PlaybackLibraryOverlay(
                    store: libraryStore,
                    onOpenEpisode: onOpenLibraryEpisode
                )
            } else if let playlistWindow = session.playlistWindow {
                PlaybackSubtitlePlaylist(
                    session: session,
                    windowStore: playlistWindow,
                    uiProbeScope: uiProbeScope,
                    onExecuteAction: onExecuteAction,
                    onCopySelectedText: onCopySelectedText,
                    onSearchSelectedText: onSearchSelectedText
                )
            } else {
                PlaybackTheme.subtitleFocusOverlayBackground
                    .contentShape(Rectangle())
            }
        } else {
            PlaybackTheme.subtitleFocusOverlayBackground
                .contentShape(Rectangle())
        }
    }

    private var currentSubtitleOverlay: some View {
        PlaybackSubtitleFocusOverlay(
            snapshot: snapshot,
            cues: cues,
            displayTitle: currentDisplayTitle,
            contentGeneration: session.token.sessionGeneration,
            uiProbeScope: uiProbeScope,
            keyboardNavigationRequest: session.keyboardNavigationRequest,
            blocksNewNavigation: session.pendingKeyboardAction != nil
                || session.activeKeyboardAction != nil,
            collageSelectionPlan: session.isEditingCollage
                ? session.collageSelectionPlan
                : nil,
            onCommitKeyboardNavigation: session.commitKeyboardNavigation,
            onCommitNativeReelSelection: session.commitNativeReelSelection,
            onToggleCollageCueSelection: session.toggleCollageCueSelection,
            onCopySelectedText: onCopySelectedText,
            onSearchSelectedText: onSearchSelectedText,
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
    }

    private var currentDisplayTitle: String {
        session.openSnapshot.videoPresentation?.displayTitle
            ?? URL(fileURLWithPath: session.openSnapshot.source.videoPath)
                .deletingPathExtension()
                .lastPathComponent
    }

}

enum PlaybackCollageEditorLayout {
    static func columnWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, totalWidth / 2)
    }
}

private struct PlaybackCollageEditor<SubtitleContent: View>: View {
    let plan: SubtitleCollageSelectionPlan
    let displayTitle: String
    @ObservedObject var previewStore: PlaybackCollagePreviewStore
    let uiProbeScope: String?
    let subtitleContent: SubtitleContent

    init(
        plan: SubtitleCollageSelectionPlan,
        displayTitle: String,
        previewStore: PlaybackCollagePreviewStore,
        uiProbeScope: String?,
        @ViewBuilder subtitleContent: () -> SubtitleContent
    ) {
        self.plan = plan
        self.displayTitle = displayTitle
        self.previewStore = previewStore
        self.uiProbeScope = uiProbeScope
        self.subtitleContent = subtitleContent()
    }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = PlaybackCollageEditorLayout.columnWidth(
                totalWidth: geometry.size.width
            )
            HStack(spacing: 0) {
                PlaybackCollagePreviewPane(
                    store: previewStore,
                    displayTitle: displayTitle,
                    uiProbeScope: uiProbeScope
                )
                .frame(width: columnWidth, height: geometry.size.height)

                subtitleContent
                    .frame(width: columnWidth, height: geometry.size.height)
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .leading
            )
        }
    }
}

private struct PlaybackOverlayTopBar: View {
    let modules: [PlaybackOverlayModule]
    let selectedModule: PlaybackOverlayModule?
    let isEditingCollage: Bool
    let onSelect: (PlaybackOverlayModule) -> Bool
    let onToggleEditingCollage: () -> Bool

    var body: some View {
        ZStack {
            if isEditingCollage {
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignControlIconSize,
                            weight: WorkbenchControlMetrics.redesignButtonIconWeight
                        ))

                    Text("Editing Collage")
                        .font(.system(
                            size: PlaybackOverlayMetrics.tabFontSize,
                            weight: .semibold
                        ))
                        .lineLimit(1)
                }
                .foregroundStyle(PlaybackTheme.playbackModuleSidebarSelected)
                .allowsHitTesting(false)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("playback-collage-editor-title")
            } else {
                HStack(spacing: PlaybackOverlayMetrics.tabGap) {
                    ForEach(modules, id: \.self) { module in
                        Button {
                            _ = onSelect(module)
                        } label: {
                            VStack(spacing: PlaybackOverlayMetrics.tabIndicatorGap) {
                                Text(module.label)
                                    .font(.system(
                                        size: PlaybackOverlayMetrics.tabFontSize,
                                        weight: selectedModule == module
                                            ? .semibold
                                            : .regular
                                    ))
                                    .lineLimit(1)

                                Capsule()
                                    .fill(PlaybackTheme.playbackModuleSidebarSelected)
                                    .frame(
                                        width: PlaybackOverlayMetrics.tabIndicatorWidth,
                                        height: PlaybackOverlayMetrics.tabIndicatorHeight
                                    )
                                    .opacity(selectedModule == module ? 1 : 0)
                            }
                            .foregroundStyle(
                                selectedModule == module
                                    ? PlaybackTheme.playbackModuleSidebarSelected
                                    : PlaybackTheme.playbackModuleSidebarUnselected
                            )
                            .padding(
                                .horizontal,
                                PlaybackOverlayMetrics.tabHorizontalPadding
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .pointerOnHover(isEnabled: true)
                        .accessibilityLabel(module.label)
                        .accessibilityIdentifier("playback-view-\(module.rawValue)")
                    }
                }
            }

            if selectedModule == .current {
                HStack {
                    WorkbenchToolbarButton(
                        title: isEditingCollage ? "Exit" : "Collage",
                        systemImage: "square.and.pencil",
                        isRedesign: true
                    ) {
                        _ = onToggleEditingCollage()
                    }
                    .accessibilityIdentifier(
                        isEditingCollage
                            ? "playback-exit-collage"
                            : "playback-enter-collage"
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
    }
}

private struct PlaybackSubtitlePlaylist: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    @ObservedObject var windowStore: PlaybackPlaylistSessionWindowStore
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlaybackCueResultOverlay(
                session: session,
                windowStore: windowStore,
                module: .playlist,
                uiProbeScope: uiProbeScope,
                onCopySelectedText: onCopySelectedText,
                onSearchSelectedText: onSearchSelectedText,
                onExecuteAction: onExecuteAction
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PlaybackCueFooter(
                status: PlaybackCueFooterStatus.cues(
                    totalCount: windowStore.snapshot.totalCount
                ),
                actionTitle: "Play"
            )
            .frame(maxWidth: PlaybackSubtitleFocusMetrics.contentMaxWidth)
            .padding(
                .horizontal,
                PlaybackSubtitleFocusMetrics.contentInset
            )
            .frame(maxWidth: .infinity)
        }
    }
}

struct PlaybackSubtitleFocusOverlay: View {
    let snapshot: SubtitleFocusSnapshot
    let cues: [SubtitleFocusCue]
    let displayTitle: String
    let contentGeneration: Int
    let uiProbeScope: String?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let blocksNewNavigation: Bool
    let collageSelectionPlan: SubtitleCollageSelectionPlan?
    let onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool
    let onCommitNativeReelSelection: (Int) -> Bool
    let onToggleCollageCueSelection: (Int) -> SubtitleCollageSelectionMutation
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void
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
        displayTitle: String = "",
        contentGeneration: Int = 0,
        uiProbeScope: String? = nil,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest? = nil,
        blocksNewNavigation: Bool = false,
        collageSelectionPlan: SubtitleCollageSelectionPlan? = nil,
        onCommitKeyboardNavigation: @escaping (
            PlaybackSubtitleFocusKeyboardNavigationRequest
        ) -> Bool = { _ in false },
        onCommitNativeReelSelection: @escaping (Int) -> Bool = { _ in false },
        onToggleCollageCueSelection:
            @escaping (Int) -> SubtitleCollageSelectionMutation = { _ in .unchanged },
        onCopySelectedText: @escaping (String) -> Void = { _ in },
        onSearchSelectedText: @escaping (String) -> Void = { _ in },
        allowsNativeWheelInput: @escaping () -> Bool = { false },
        allowsNativeScrollbarInput: @escaping () -> Bool = { false },
        consumeDeferredAction: @escaping () -> PlaybackSubtitleFocusActionExecution? = { nil },
        onScrollbarDraggingChanged: @escaping (Bool) -> Void = { _ in },
        onCueReelMotionChanged: @escaping (Bool) -> Void = { _ in },
        onExecuteAction: @escaping (PlaybackSubtitleFocusActionExecution) -> Bool = { _ in false }
    ) {
        self.snapshot = snapshot
        self.cues = cues ?? snapshot.cues
        self.displayTitle = displayTitle
        self.contentGeneration = contentGeneration
        self.uiProbeScope = uiProbeScope
        self.keyboardNavigationRequest = keyboardNavigationRequest
        self.blocksNewNavigation = blocksNewNavigation
        self.collageSelectionPlan = collageSelectionPlan
        self.onCommitKeyboardNavigation = onCommitKeyboardNavigation
        self.onCommitNativeReelSelection = onCommitNativeReelSelection
        self.onToggleCollageCueSelection = onToggleCollageCueSelection
        self.onCopySelectedText = onCopySelectedText
        self.onSearchSelectedText = onSearchSelectedText
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
            let reelViewportHeight = max(
                0,
                viewportSize.height - PlaybackCueFooterMetrics.height
            )
            let cueViewportHeight = max(
                0,
                reelViewportHeight
                    - PlaybackSubtitleFocusMetrics.contentInset * 2
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
                    displayTitle: displayTitle,
                    contentGeneration: contentGeneration,
                    uiProbeScope: uiProbeScope,
                    keyboardNavigationRequest: keyboardNavigationRequest,
                    reducesMotion: reduceMotion,
                    isInteractionEnabled: !blocksInteraction,
                    cancelsWheelMotion: keyboardNavigationRequest != nil,
                    collageSelectedCueIDs: collageSelectionPlan.map {
                        Set($0.selectedCues.map(\.id))
                    },
                    collageCanSelectAnotherCue: collageSelectionPlan?
                        .canSelectAnotherCue ?? true,
                    onCommitKeyboardNavigation: onCommitKeyboardNavigation,
                    onCommitNativeReelSelection: onCommitNativeReelSelection,
                    onToggleCollageCueSelection: {
                        _ = onToggleCollageCueSelection($0)
                    },
                    onCopySelectedText: onCopySelectedText,
                    onSearchSelectedText: onSearchSelectedText,
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
            .frame(
                width: viewportSize.width,
                height: viewportSize.height,
                alignment: .top
            )
            .overlay(alignment: .bottom) {
                PlaybackCueFooter(
                    status: PlaybackCueFooterStatus.cues(
                        totalCount: snapshot.totalCount
                    ),
                    actionTitle: collageSelectionPlan == nil
                        ? "Play"
                        : "Select"
                )
                .frame(maxWidth: PlaybackSubtitleFocusMetrics.contentMaxWidth)
                .padding(
                    .horizontal,
                    PlaybackSubtitleFocusMetrics.contentInset
                )
            }
            .clipped()
            .contentShape(Rectangle())
        }
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
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
        view.updateBackgroundColor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? PlaybackSubtitleFocusPointerShieldView)?
            .updateBackgroundColor()
    }
}

private final class PlaybackSubtitleFocusPointerShieldView: NSView {
    override var isOpaque: Bool {
        false
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundColor()
    }

    func updateBackgroundColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = PlaybackTheme
                .subtitleFocusOverlayBackgroundNative
                .usingColorSpace(.sRGB)?
                .cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        // The complete overlay owns pointer clicks, including its content
        // insets. Cue navigation remains exclusively wheel/scrollbar driven.
    }
}
