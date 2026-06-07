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

                    PlaybackSearchNavigationTimeObserver(appState: appState, viewModel: viewModel)
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)
                }

                quickSearchOverlay(in: geometry.size)
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
            max(0, size.width - 40)
        )
        let panelHeight = max(
            0,
            size.height
                - PlaybackOverlayPanelMetrics.topInset
                - PlaybackOverlayPanelMetrics.bottomInset
        )

        PlaybackSidebarShell(appState: appState, activePanel: $activePanel)
            .frame(width: panelWidth, height: panelHeight)
            .background(PlaybackTheme.cinematicBacking)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PlaybackTheme.textTertiary.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.42), radius: 24, x: 0, y: 12)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.98)
            .position(
                x: size.width - 20 - panelWidth / 2,
                y: PlaybackOverlayPanelMetrics.topInset + panelHeight / 2
            )
            .offset(y: visible ? 0 : 10)
            .allowsHitTesting(visible)
            .animation(.easeInOut(duration: 0.18), value: visible)
    }

    @ViewBuilder
    private func quickSearchOverlay(in size: CGSize) -> some View {
        let visible = playback.isQuickSearchOverlayVisible
        let overlayWidth = min(860, max(280, size.width - 64))
        let overlayTop = min(max(58, size.height * 0.18 - 37), 113)
        let submittedQuery = playback.quickSearchSubmittedQuery
        let trimmedSearchQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let overlayResults = submittedQuery == trimmedSearchQuery ? search.searchResults : []

        if visible {
            PlaybackQuickSearchOverlay(
                draft: $playback.quickSearchDraft,
                isFocused: $playback.isQuickSearchFocused,
                forcedTextUpdateID: playback.quickSearchForcedTextUpdateID,
                focusRequestID: playback.quickSearchFocusRequestID,
                submittedQuery: submittedQuery,
                results: overlayResults,
                selectedResultIndex: playback.quickSearchSelectedResultIndex,
                isSearching: search.isSearching,
                currentSentence: playback.quickSearchCurrentSentence,
                aiState: playback.quickSearchAIState,
                selectedChunkCountState: playback.quickSearchSelectedChunkCountState,
                navigationState: playback.quickSearchNavigationState,
                focusTarget: playback.quickSearchFocusTarget,
                onSubmit: {
                    appState.submitPlaybackQuickSearchFromUser()
                },
                onClear: {
                    playback.setQuickSearchDraft("")
                },
                onRequestFocus: {
                    playback.requestQuickSearchFocus()
                },
                onMoveUp: {
                    appState.movePlaybackQuickSearchFocus(by: -1)
                },
                onMoveDown: {
                    appState.movePlaybackQuickSearchFocus(by: 1)
                },
                onMoveLeft: {
                    appState.movePlaybackQuickSearchOptionRowSelection(by: -1)
                },
                onMoveRight: { _ in
                    appState.movePlaybackQuickSearchOptionRowSelection(by: 1)
                },
                onOpenResult: { result in
                    appState.openPlaybackQuickSearchResult(result)
                },
                onResultAppear: { result in
                    appState.markSearchResultVisible(result)
                    appState.loadMoreSearchResultsIfNeeded(currentResult: result)
                }
            )
            .frame(width: overlayWidth)
            .padding(.top, overlayTop)
            .transition(.opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)))
            .animation(.easeInOut(duration: 0.16), value: visible)
        }
    }

    private func refreshSidebarData() {
        appState.refreshSearchNavigationSnapshot()
        appState.refreshCurrentSubtitleEntries()
    }
}

private struct PlaybackSearchNavigationTimeObserver: View {
    let appState: AppCoordinator
    @ObservedObject var viewModel: PlaybackViewModel

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                updateActiveSearchNavigationResult()
            }
            .onChange(of: viewModel.displayedCurrentTime) { _ in
                updateActiveSearchNavigationResult()
            }
    }

    private func updateActiveSearchNavigationResult() {
        let milliseconds = max(
            0,
            Int((viewModel.displayedCurrentTime * 1_000).rounded(.down))
        )
        appState.updateActiveSearchNavigationResult(currentMilliseconds: milliseconds)
    }
}
