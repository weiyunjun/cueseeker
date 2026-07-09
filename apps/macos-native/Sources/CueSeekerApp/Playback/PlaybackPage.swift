import AppKit
import CueSeekerCore
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

                quickSearchOverlay(in: geometry.size)

                if let subtitleFocusSession {
                    PlaybackSubtitleFocusLayer(session: subtitleFocusSession)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
    }

    @ViewBuilder
    private func quickSearchOverlay(in size: CGSize) -> some View {
        let visible = playback.isQuickSearchOverlayVisible

        if visible {
            PlaybackQuickSearchOverlayHost(appState: appState, size: size)
            .transition(.opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)))
            .animation(.easeInOut(duration: 0.16), value: visible)
        }
    }

}

private struct PlaybackQuickSearchOverlayHost: View {
    @ObservedObject var appState: AppCoordinator
    let size: CGSize
    @EnvironmentObject private var playback: PlaybackStore
    @EnvironmentObject private var search: SearchStore

    var body: some View {
        let submittedQuery = playback.quickSearchSubmittedQuery
        let trimmedSearchQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let overlayResults = submittedQuery == trimmedSearchQuery ? search.searchResults : []

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
    }

    private var overlayWidth: CGFloat {
        min(860, max(280, size.width - 64))
    }

    private var overlayTop: CGFloat {
        min(max(58, size.height * 0.18 - 37), 113)
    }
}
