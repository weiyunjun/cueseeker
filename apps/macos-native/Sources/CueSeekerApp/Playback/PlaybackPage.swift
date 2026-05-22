import AppKit
import CueSeekerCore
import SwiftUI

struct PlaybackPageView: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppCoordinator
    let onClose: () -> Void
    @State private var activePanel: PlaybackDrawerKind = .results
    @EnvironmentObject private var playback: PlaybackStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var shiori: ShioriStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            // The video stage fills the whole window. The overlay panel floats
            // above it (centered, prototype geometry) and never squeezes it, so
            // toggling the panel cannot resize the video stage or disturb seek.
            ZStack(alignment: .top) {
                PlaybackVideoStage(
                    playbackSurface: playbackSurface,
                    appState: appState,
                    fullscreenManager: appState.playbackFullscreenManager,
                    onClose: onClose
                )
                .frame(width: geometry.size.width, height: geometry.size.height)

                overlayPanel(in: geometry.size)

                // The feedback HUD renders above the overlay panel and is
                // centered within the full-window black video base
                // (doc 12 §11/§13.4). It is the SwiftUI feedback layer only;
                // the native render/seek path is untouched.
                if let viewModel = playback.playbackViewModel {
                    PlaybackFeedbackLayer(viewModel: viewModel)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .onAppear {
            refreshSidebarData()
        }
        .onChange(of: appState.currentPlaybackSubtitlePath) { _ in
            refreshSidebarData()
        }
    }

    @ViewBuilder
    private func overlayPanel(in size: CGSize) -> some View {
        let visible = playback.isPlaybackSidePanelVisible
        let panelWidth = min(
            PlaybackOverlayPanelMetrics.maxWidth,
            max(0, size.width - PlaybackOverlayPanelMetrics.horizontalMargin * 2)
        )
        let panelHeight = max(
            0,
            size.height
                - PlaybackOverlayPanelMetrics.topInset
                - PlaybackOverlayPanelMetrics.bottomInset
        )

        PlaybackSidebarShell(appState: appState, activePanel: $activePanel)
            .frame(width: panelWidth, height: panelHeight)
            .background(overlayPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(overlayPanelBorder, lineWidth: 0.5)
            )
            .shadow(color: overlayPanelShadow, radius: 28, x: 0, y: 16)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.98)
            .position(
                x: size.width / 2,
                y: PlaybackOverlayPanelMetrics.topInset + panelHeight / 2
            )
            .offset(y: visible ? 0 : 10)
            .allowsHitTesting(visible)
            .animation(.easeInOut(duration: 0.18), value: visible)
    }

    private var overlayPanelBackground: Color {
        colorScheme == .dark
            ? Color(red: 36 / 255, green: 34 / 255, blue: 43 / 255)
            : Color(red: 246 / 255, green: 246 / 255, blue: 247 / 255)
    }

    private var overlayPanelBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.10)
    }

    private var overlayPanelShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.65)
            : Color.black.opacity(0.45)
    }

    private func refreshSidebarData() {
        appState.refreshSearchNavigationSnapshot()
        appState.refreshCurrentSubtitleEntries()
    }
}




