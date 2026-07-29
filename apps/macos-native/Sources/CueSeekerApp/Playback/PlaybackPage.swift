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
                    onClose: onClose
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .allowsHitTesting(!isPlaybackModalActive)
                .accessibilityHidden(isPlaybackModalActive)

                if let subtitleFocusSession {
                    PlaybackSubtitleFocusLayer(
                        session: subtitleFocusSession,
                        uiProbeScope: appState.uiProbeScope,
                        onExecuteAction:
                            appState.executePlaybackSubtitleFocusAction,
                        onOpenLibraryEpisode:
                            appState.openPlaybackLibraryEpisodeFromOverlay
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
                        shioriStore: appState.shiori
                    )
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                }

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
