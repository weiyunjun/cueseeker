import SwiftUI

struct PlaybackPageView: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppCoordinator
    let onClose: () -> Void
    @EnvironmentObject private var playback: PlaybackStore

    var body: some View {
        GeometryReader { geometry in
            let subtitleFocusSession = playback.subtitleFocusSession
            let isSubtitleFocusActive = subtitleFocusSession != nil

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
                .allowsHitTesting(!isSubtitleFocusActive)
                .accessibilityHidden(isSubtitleFocusActive)

                // The feedback HUD is centered within the full-window black video base
                // (doc 12 §11/§13.4). It is the SwiftUI feedback layer only;
                // the native render/seek path is untouched.
                if let viewModel = playback.playbackViewModel {
                    PlaybackFeedbackLayer(viewModel: viewModel)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(false)
                }

                if let subtitleFocusSession {
                    PlaybackSubtitleFocusLayer(
                        session: subtitleFocusSession,
                        onMoveSelection: appState.movePlaybackSubtitleFocusSelection,
                        onNavigationIntent: appState.notePlaybackSubtitleFocusNavigationIntent,
                        onOpenActionMenu:
                            appState.openPlaybackSubtitleFocusActionMenu,
                        onOpenSelectedActionMenu:
                            appState.openPlaybackSubtitleFocusActionMenuFromKeyboard,
                        onDismissActionMenu:
                            appState.dismissPlaybackSubtitleFocusActionMenuFromUser,
                        onExecuteAction:
                            appState.executePlaybackSubtitleFocusAction
                    )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
    }
}
