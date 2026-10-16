import CueSeekerCore
import CueSeekerPlayback
import Foundation
import SwiftUI

struct PlaybackSubtitleFocusLayer: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool
    let onRequestAction: (PlaybackSubtitleFocusAction) -> Void
    let onOpenLibraryEpisode: (CompleteLibraryVideoPresentation) -> Bool
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void
    let onReturn: () -> Void

    init(
        session: PlaybackSubtitleFocusSessionStore,
        uiProbeScope: String? = nil,
        onExecuteAction: ((PlaybackSubtitleFocusActionExecution) -> Bool)? = nil,
        onRequestAction: @escaping (PlaybackSubtitleFocusAction) -> Void = {
            _ in
        },
        onCopySelectedText: @escaping (String) -> Void = { _ in },
        onSearchSelectedText: @escaping (String) -> Void = { _ in },
        onOpenLibraryEpisode:
            @escaping (CompleteLibraryVideoPresentation) -> Bool = {
                _ in false
            },
        onReturn: @escaping () -> Void = {}
    ) {
        self.session = session
        self.uiProbeScope = uiProbeScope
        self.onExecuteAction = onExecuteAction ?? { execution in
            session.finishKeyboardAction(execution)
        }
        self.onRequestAction = onRequestAction
        self.onCopySelectedText = onCopySelectedText
        self.onSearchSelectedText = onSearchSelectedText
        self.onOpenLibraryEpisode = onOpenLibraryEpisode
        self.onReturn = onReturn
    }

    var body: some View {
        switch session.state {
        case .closed, .opening:
            EmptyView()
        case .cueSelection(let snapshot):
            overlay(
                snapshot: snapshot,
                cues: session.completeCueBatch?.cues ?? snapshot.cues
            )
        case .subtitleLeftLibrary:
            overlay(snapshot: nil, cues: [])
        }
    }

    private func overlay(
        snapshot: SubtitleFocusSnapshot?,
        cues: [SubtitleFocusCue]
    ) -> PlaybackOverlay {
        PlaybackOverlay(
            session: session,
            snapshot: snapshot,
            cues: cues,
            uiProbeScope: uiProbeScope,
            onExecuteAction: onExecuteAction,
            onRequestAction: onRequestAction,
            onCopySelectedText: onCopySelectedText,
            onSearchSelectedText: onSearchSelectedText,
            onOpenLibraryEpisode: onOpenLibraryEpisode,
            onReturn: onReturn
        )
    }
}

struct PlaybackOverlay: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @Environment(\.isPlaybackOverlayCovered) private var isCoveredByHigherLayer
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    /// Nil when the subtitle Current opened on is no longer in the library.
    let snapshot: SubtitleFocusSnapshot?
    let cues: [SubtitleFocusCue]
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool
    let onRequestAction: (PlaybackSubtitleFocusAction) -> Void
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void
    let onOpenLibraryEpisode: (CompleteLibraryVideoPresentation) -> Bool
    let onReturn: () -> Void

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
                    onToggleEditingCollage: session.toggleEditingCollage,
                    onReturn: onReturn
                )
                .frame(height: WorkbenchControlMetrics.redesignAppTopbarHeight)

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
                    totalCueCount: snapshot?.totalCount ?? 0,
                    previewStore: previewStore,
                    uiProbeScope: uiProbeScope,
                    onCopy: { _ = session.copyCurrentCollage() },
                    onExport: { _ = session.exportCurrentCollage() },
                    onSelect: { _ = session.toggleFocusedCollageCueSelection() },
                    onJumpToCue: { _ = session.jumpToCollageCue(ordinal: $0) }
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
                    onRequestAction: onRequestAction,
                    onCopySelectedText: onCopySelectedText,
                    onSearchSelectedText: onSearchSelectedText
                )
            } else {
                // The playlist kept nothing the library still holds.
                PlaybackEmptyHint(L("playback.playlist.left_library"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(PlaybackTheme.subtitleFocusOverlayBackground)
            }
        } else {
            PlaybackTheme.subtitleFocusOverlayBackground
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var currentSubtitleOverlay: some View {
        if let snapshot {
            currentSubtitleOverlay(snapshot: snapshot)
        } else {
            PlaybackEmptyHint(L("playback.current.left_library"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(PlaybackTheme.subtitleFocusOverlayBackground)
        }
    }

    private func currentSubtitleOverlay(
        snapshot: SubtitleFocusSnapshot
    ) -> some View {
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
            isCoveredByHigherLayer: isCoveredByHigherLayer,
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
            onExecuteAction: onExecuteAction,
            onRequestAction: onRequestAction
        )
    }

    private var currentDisplayTitle: String {
        session.openSnapshot.videoPresentation?.displayTitle
            ?? URL.fromMediaPath(session.openSnapshot.source.videoPath)
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
    let totalCueCount: Int
    @ObservedObject var previewStore: PlaybackCollagePreviewStore
    let uiProbeScope: String?
    let onCopy: () -> Void
    let onExport: () -> Void
    let onSelect: () -> Void
    let onJumpToCue: (Int) -> Void
    let subtitleContent: SubtitleContent
    @State private var footerHeight = PlaybackCueFooterMetrics.minimumHeight

    init(
        plan: SubtitleCollageSelectionPlan,
        totalCueCount: Int,
        previewStore: PlaybackCollagePreviewStore,
        uiProbeScope: String?,
        onCopy: @escaping () -> Void,
        onExport: @escaping () -> Void,
        onSelect: @escaping () -> Void,
        onJumpToCue: @escaping (Int) -> Void,
        @ViewBuilder subtitleContent: () -> SubtitleContent
    ) {
        self.plan = plan
        self.totalCueCount = totalCueCount
        self.previewStore = previewStore
        self.uiProbeScope = uiProbeScope
        self.onCopy = onCopy
        self.onExport = onExport
        self.onSelect = onSelect
        self.onJumpToCue = onJumpToCue
        self.subtitleContent = subtitleContent()
    }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = PlaybackCollageEditorLayout.columnWidth(
                totalWidth: geometry.size.width
            )
            let contentHeight = max(0, geometry.size.height - footerHeight)
            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    PlaybackCollagePreviewPane(
                        store: previewStore,
                        uiProbeScope: uiProbeScope,
                        onJumpToCue: onJumpToCue
                    )
                    .frame(width: columnWidth, height: contentHeight)
                    // On the Overlay's layer, like the top bar: the preview asks
                    // whether it is frozen from where it actually is.
                    .interfaceLayer(.playbackOverlay)

                    subtitleContent
                        .frame(width: columnWidth, height: contentHeight)
                }
                .frame(
                    width: geometry.size.width,
                    height: contentHeight,
                    alignment: .leading
                )
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .top
            )
            .overlay(alignment: .bottom) {
                PlaybackCueFooter(
                    surface: .playbackOverlay,
                    status: PlaybackCueFooterStatus.collageCues(
                        selectedCount: plan.selectedCueCount,
                        totalCount: totalCueCount
                    ),
                    actions: PlaybackCueFooterAction.collageActions(
                        onCopy: onCopy,
                        onExport: onExport,
                        onSelect: onSelect
                    )
                )
                .padding(
                    .horizontal,
                    PlaybackSubtitleFocusMetrics.contentInset
                )
                .frame(width: geometry.size.width)
                .onPreferenceChange(PlaybackCueFooterHeightKey.self) {
                    footerHeight = $0
                }
            }
        }
    }
}

struct PlaybackOverlayTopBar: View {
    // Observed so the tab labels and the editing title are re-read when the
    // language changes: the bar's own inputs do not change with it, so
    // without this SwiftUI would leave the bar as it was.
    @EnvironmentObject private var localization: AppLocalizationStore
    let modules: [PlaybackOverlayModule]
    let selectedModule: PlaybackOverlayModule?
    let isEditingCollage: Bool
    let onSelect: (PlaybackOverlayModule) -> Bool
    let onToggleEditingCollage: () -> Bool
    let onReturn: () -> Void

    var body: some View {
        TitlebarBackgroundView(
            backgroundColor: Color.clear,
            onDoubleClickZoom: { window in
                NotificationCenter.default.post(
                    name: .topbarTitlebarZoomRequested,
                    object: window
                )
                return true
            }
        )
        .overlay {
            WorkbenchAdaptiveHeaderBar(
                leadingInset: 0,
                trailingInset: WorkbenchControlMetrics.redesignAppTopbarContentTrailingPadding,
                minimumGap: WorkbenchControlMetrics.redesignSpacing3
            ) {
                PlaybackReturnButton(
                    hoverBackground: WorkbenchRedesignColors
                        .overlaySurfaceShortcutButtonHoverBg,
                    scenarioID: "playback_overlay.topbar.return",
                    action: onReturn
                )
            } center: {
                if isEditingCollage {
                    Text(L("playback.collage.editing"))
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .semibold
                        ))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(PlaybackTheme.playbackModuleSidebarSelected)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("playback-collage-editor-title")
                } else {
                    WorkbenchSegmentedControl(
                        options: modules,
                        selection: Binding(
                            get: { selectedModule ?? modules.first ?? .current },
                            set: { _ = onSelect($0) }
                        ),
                        title: { $0.label },
                        accessibilityLabel: { $0.label },
                        accessibilityIdentifier: { "playback-view-\($0.rawValue)" }
                    )
                }
            } trailing: {
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                    if selectedModule == .current {
                        WorkbenchIconButton(
                            icon: .imagesSquare,
                            isRedesign: true,
                            isOpen: isEditingCollage,
                            hoverBackground: WorkbenchRedesignColors
                                .overlaySurfaceShortcutButtonHoverBg
                        ) {
                            _ = onToggleEditingCollage()
                        }
                        .workbenchTooltip(
                            scenarioID: "playback_overlay.topbar.collage",
                            label: isEditingCollage
                                ? L("tooltip.playback_overlay.collage.exit")
                                : L("tooltip.playback_overlay.collage.edit"),
                            shortcut: .action(.editCollage)
                        )
                        .accessibilityLabel(
                            isEditingCollage
                                ? L("playback.collage.exit")
                                : L("playback.collage")
                        )
                        .accessibilityIdentifier(
                            isEditingCollage
                                ? "playback-exit-collage"
                                : "playback-enter-collage"
                        )
                    }

                    TopbarAppEntries(
                        hoverBackground: WorkbenchRedesignColors
                            .overlaySurfaceShortcutButtonHoverBg
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
        // On the Overlay's layer, like the footer: read from the page
        // underneath, the bar's buttons would count as frozen for as long as
        // playback is open and never take a hover.
        .interfaceLayer(.playbackOverlay)
    }
}

private struct PlaybackSubtitlePlaylist: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    @ObservedObject var windowStore: PlaybackPlaylistSessionWindowStore
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool
    let onRequestAction: (PlaybackSubtitleFocusAction) -> Void
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
                surface: .playbackOverlay,
                status: PlaybackCueFooterStatus.cues(
                    totalCount: windowStore.snapshot.totalCount
                ),
                actions: PlaybackCueFooterAction.cueActions(
                    playTitle: L("playback.play"),
                    request: onRequestAction
                )
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
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    let snapshot: SubtitleFocusSnapshot
    let cues: [SubtitleFocusCue]
    let displayTitle: String
    let contentGeneration: Int
    let uiProbeScope: String?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let blocksNewNavigation: Bool
    let collageSelectionPlan: SubtitleCollageSelectionPlan?
    /// True while the Command Panel is stacked on top of this overlay.
    let isCoveredByHigherLayer: Bool
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
    let onRequestAction: (PlaybackSubtitleFocusAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.interfaceLayers) private var interfaceLayers
    /// The footer wraps rather than truncating, so the reel viewport has to
    /// subtract what the footer actually took.
    @State private var footerHeight = PlaybackCueFooterMetrics.minimumHeight

    init(
        snapshot: SubtitleFocusSnapshot,
        cues: [SubtitleFocusCue]? = nil,
        displayTitle: String = "",
        contentGeneration: Int = 0,
        uiProbeScope: String? = nil,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest? = nil,
        blocksNewNavigation: Bool = false,
        collageSelectionPlan: SubtitleCollageSelectionPlan? = nil,
        isCoveredByHigherLayer: Bool = false,
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
        onExecuteAction: @escaping (PlaybackSubtitleFocusActionExecution) -> Bool = { _ in false },
        onRequestAction: @escaping (PlaybackSubtitleFocusAction) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.cues = cues ?? snapshot.cues
        self.displayTitle = displayTitle
        self.contentGeneration = contentGeneration
        self.uiProbeScope = uiProbeScope
        self.keyboardNavigationRequest = keyboardNavigationRequest
        self.blocksNewNavigation = blocksNewNavigation
        self.collageSelectionPlan = collageSelectionPlan
        self.isCoveredByHigherLayer = isCoveredByHigherLayer
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
        self.onRequestAction = onRequestAction
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
                collageSelectionPlan == nil
                    ? viewportSize.height - footerHeight
                    : viewportSize.height
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
                    onKeyboardMotionChanged: handleCueReelMotionChanged,
                    interfaceLayers: interfaceLayers,
                    isCoveredByHigherLayer: isCoveredByHigherLayer
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
                if collageSelectionPlan == nil {
                    PlaybackCueFooter(
                        surface: .playbackOverlay,
                        status: PlaybackCueFooterStatus.cues(
                            totalCount: snapshot.totalCount
                        ),
                        actions: footerActions
                    )
                    .frame(maxWidth: PlaybackSubtitleFocusMetrics.contentMaxWidth)
                    .padding(
                        .horizontal,
                        PlaybackSubtitleFocusMetrics.contentInset
                    )
                    .onPreferenceChange(PlaybackCueFooterHeightKey.self) {
                        footerHeight = $0
                    }
                }
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

    private var footerActions: [PlaybackCueFooterAction] {
        PlaybackCueFooterAction.cueActions(
            playTitle: L("playback.play"),
            request: onRequestAction
        )
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
