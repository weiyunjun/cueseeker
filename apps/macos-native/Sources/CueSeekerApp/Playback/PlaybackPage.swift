import SwiftUI

struct PlaybackPageView: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppCoordinator
    let onClose: () -> Void
    @EnvironmentObject private var playback: PlaybackStore

    var body: some View {
        let _ = UIInvalidationProbe.count(
            "UI.PlaybackPage.body",
            scope: appState.uiProbeScope
        )
        GeometryReader { geometry in
            let subtitleFocusSession = playback.subtitleFocusSession
            let isCommandPanelActive =
                playback.commandPanelPresentation != nil
            let isPlaybackModalActive =
                subtitleFocusSession != nil || isCommandPanelActive

            // The video stage fills the whole window so playback geometry is
            // independent from auxiliary overlays.
            ZStack(alignment: .top) {
                PlaybackVideoStage(
                    playbackSurface: playbackSurface,
                    appState: appState,
                    fullscreenManager: appState.playbackFullscreenManager,
                    isLayerOpen: isPlaybackModalActive,
                    onClose: onClose
                )
                // The chrome is on the playback page, not on the workbench page
                // underneath it. Asking the workbench page's answer would call
                // the chrome frozen for as long as playback is open.
                .interfaceLayer(.playbackPage)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .allowsHitTesting(!isPlaybackModalActive)
                .accessibilityHidden(isPlaybackModalActive)

                if let subtitleFocusSession {
                    PlaybackSubtitleFocusLayer(
                        session: subtitleFocusSession,
                        uiProbeScope: appState.uiProbeScope,
                        onExecuteAction:
                            appState.executePlaybackSubtitleFocusAction,
                        onRequestAction: { action in
                            _ = appState
                                .requestPlaybackSubtitleFocusAction(action)
                        },
                        onCopySelectedText:
                            appState.copyPlaybackSelectedText,
                        onSearchSelectedText:
                            appState.searchPlaybackSelectedText,
                        onOpenLibraryEpisode:
                            appState.openPlaybackLibraryEpisodeFromOverlay,
                        onReturn: onClose
                    )
                        .id(subtitleFocusSession.token.sessionGeneration)
                        .environmentObject(playback.pointerVisibility)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(!isCommandPanelActive)
                        .accessibilityHidden(isCommandPanelActive)
                }

                if isCommandPanelActive {
                    PlaybackCommandPanel(
                        appState: appState,
                        playback: playback,
                        searchStore: appState.search,
                        libraryStore: appState.library,
                        excerptStore: appState.excerpt
                    )
                    .environmentObject(playback.pointerVisibility)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                }

                // Anchored to the window under the top bar, above the Playback
                // Overlay and the Command Panel, and never hidden with the
                // Player UI.
                PlaybackErrorBanner(messages: playback.errorMessages)
                    .frame(
                        maxWidth: max(
                            0,
                            geometry.size.width - WorkbenchControlMetrics.redesignSpacing6 * 2
                        ),
                        alignment: .leading
                    )
                    .padding(.leading, WorkbenchControlMetrics.redesignSpacing6)
                    .padding(
                        .top,
                        WorkbenchControlMetrics.redesignAppTopbarHeight
                            + WorkbenchControlMetrics.redesignSpacing3
                    )
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .topLeading
                    )
                    .allowsHitTesting(false)

                // Keep command feedback above every playback-local overlay so
                // Subtitle Focus S/C feedback remains visible while focus stays open.
                if let viewModel = playback.playbackViewModel {
                    PlaybackFeedbackLayer(viewModel: viewModel)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
    }
}
