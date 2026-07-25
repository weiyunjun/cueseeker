import CueSeekerCore
import Foundation
import SwiftUI

struct PlaybackSubtitleFocusLayer: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool

    init(
        session: PlaybackSubtitleFocusSessionStore,
        uiProbeScope: String? = nil,
        onExecuteAction: ((PlaybackSubtitleFocusActionExecution) -> Bool)? = nil
    ) {
        self.session = session
        self.uiProbeScope = uiProbeScope
        self.onExecuteAction = onExecuteAction ?? { execution in
            session.finishKeyboardAction(execution)
        }
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
                onExecuteAction: onExecuteAction
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

    var body: some View {
        ZStack {
            PlaybackTheme.subtitleFocusOverlayBackground

            PlaybackSubtitleFocusPointerShield()

            VStack(spacing: 0) {
                PlaybackViewTabs(
                    modules: session.availableModules.filter {
                        $0 == .current || $0 == .playlist
                    },
                    selectedModule: session.selectedModule,
                    onSelect: session.selectModule
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
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    PlaybackCurrentVideoContext(
                        openSnapshot: session.openSnapshot
                    )
                    .frame(
                        width: geometry.size.width
                            * PlaybackOverlayMetrics.currentContextWidthFraction
                    )
                    .frame(maxHeight: .infinity)

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
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
        } else {
            PlaybackTheme.subtitleFocusOverlayBackground
                .contentShape(Rectangle())
        }
    }
}

private struct PlaybackViewTabs: View {
    let modules: [PlaybackOverlayModule]
    let selectedModule: PlaybackOverlayModule?
    let onSelect: (PlaybackOverlayModule) -> Bool

    var body: some View {
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
                    .padding(.horizontal, PlaybackOverlayMetrics.tabHorizontalPadding)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .pointerOnHover(isEnabled: true)
                .accessibilityLabel(module.label)
                .accessibilityIdentifier("playback-view-\(module.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
    }
}

private struct PlaybackCurrentVideoContext: View {
    let openSnapshot: PlaybackSubtitleFocusOpenSnapshot

    var body: some View {
        GeometryReader { geometry in
            let coverWidth = max(
                0,
                min(
                    PlaybackOverlayMetrics.currentCoverMaxWidth,
                    geometry.size.width
                        - PlaybackOverlayMetrics.currentContextHorizontalPadding * 2
                )
            )
            let coverHeight = coverWidth
                / WorkbenchControlMetrics.redesignLibraryCoverAspectRatio

            ZStack(alignment: .top) {
                LibraryCachedCoverImage(
                    coverPath: openSnapshot.videoPresentation?.coverPath,
                    coverRevision: openSnapshot.videoPresentation?.coverRevision
                )
                .frame(width: coverWidth, height: coverHeight)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignLibraryCoverRadius,
                        style: .continuous
                    )
                )
                .offset(y: max(0, geometry.size.height / 2 - coverHeight / 2))

                VStack(
                    alignment: .center,
                    spacing: WorkbenchControlMetrics.redesignSpacing2
                ) {
                    Text(videoTitle)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeLibraryMeta,
                            weight: .medium
                        ))
                        .foregroundStyle(PlaybackTheme.playbackModuleSidebarUnselected)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let episodeLabel {
                        Text(episodeLabel)
                            .font(.system(
                                size: WorkbenchControlMetrics.redesignFontSizeLibraryMeta,
                                weight: .regular
                            ))
                            .foregroundStyle(PlaybackTheme.playbackModuleSidebarUnselected)
                            .monospacedDigit()
                    }
                }
                .frame(width: coverWidth)
                .offset(
                    y: max(
                        0,
                        geometry.size.height / 2
                            + coverHeight / 2
                            + PlaybackOverlayMetrics.currentInfoTopGap
                    )
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var videoTitle: String {
        openSnapshot.videoPresentation?.displayTitle
            ?? URL(fileURLWithPath: openSnapshot.source.videoPath)
                .deletingPathExtension()
                .lastPathComponent
    }

    private var episodeLabel: String? {
        openSnapshot.videoPresentation.map {
            String(format: "EP%02d", $0.episodeNumber)
        }
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
