import CueSeekerCore
import SwiftUI

struct PlaybackLibraryOverlay: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @ObservedObject var store: PlaybackLibrarySessionStore
    @ObservedObject private var library: LibraryStore
    let onOpenEpisode: (CompleteLibraryVideoPresentation) -> Bool

    init(
        store: PlaybackLibrarySessionStore,
        onOpenEpisode: @escaping (CompleteLibraryVideoPresentation) -> Bool
    ) {
        self.store = store
        _library = ObservedObject(wrappedValue: store.libraryStore)
        self.onOpenEpisode = onOpenEpisode
        store.activate()
    }

    var body: some View {
        VStack(spacing: 0) {
            PlaybackLibraryEpisodeList(
                store: store,
                selection: store.selection,
                onOpenEpisode: onOpenEpisode
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PlaybackCueFooter(
                surface: .playbackOverlay,
                status: PlaybackCueFooterStatus.videos(
                    totalCount: store.detail?.videos.count ?? 0
                ),
                actions: [
                    .primary(id: "play", title: L("playback.play")) {
                        // The same path Return takes: resolve the selected
                        // episode, then open it.
                        guard let video = store.primaryActionVideo() else {
                            return
                        }
                        _ = onOpenEpisode(video)
                    },
                ]
            )
            .padding(
                .horizontal,
                PlaybackSubtitleFocusMetrics.contentInset
            )
        }
        .onAppear {
            store.activate()
        }
        .onChange(of: library.completeLibraryRevision) { _ in
            store.refreshForSourceRevision()
        }
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
    }
}

private struct PlaybackLibraryEpisodeList: View {
    @ObservedObject var store: PlaybackLibrarySessionStore
    @ObservedObject var selection: PlaybackMediaSelectionStore
    @ObservedObject private var library: LibraryStore
    let onOpenEpisode: (CompleteLibraryVideoPresentation) -> Bool

    private let coordinateSpaceName = "playback-library-episodes-scroll"

    init(
        store: PlaybackLibrarySessionStore,
        selection: PlaybackMediaSelectionStore,
        onOpenEpisode: @escaping (CompleteLibraryVideoPresentation) -> Bool
    ) {
        self.store = store
        self.selection = selection
        _library = ObservedObject(wrappedValue: store.libraryStore)
        self.onOpenEpisode = onOpenEpisode
    }

    private var isFirstRowSelection: Bool {
        guard let selectedItemID = selection.selectedItemID,
              let selectedIndex = selection.orderedItemIDs.firstIndex(of: selectedItemID)
        else {
            return false
        }
        return PlaybackMediaSelectionStore.isFirstRow(
            index: selectedIndex,
            itemCount: selection.orderedItemIDs.count,
            columnCount: selection.columnCount
        )
    }

    var body: some View {
        let _ = selection.highlight.syncSelectedDuringRender(selection.selectedItemID)
        GeometryReader { geometry in
            WorkbenchScrollView {
                content(viewportHeight: geometry.size.height)
                    .environment(
                        \.mediaCardGridContainerWidth,
                        max(
                            0,
                            geometry.size.width
                                - PlaybackSubtitleFocusMetrics.contentInset * 2
                        )
                    )
                    .padding(.horizontal, PlaybackSubtitleFocusMetrics.contentInset)
                    .padding(.bottom, PlaybackSubtitleFocusMetrics.contentInset)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .coordinateSpace(name: coordinateSpaceName)
            }
            .onAppear {
                updateGridLayout(containerWidth: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { width in
                updateGridLayout(containerWidth: width)
            }
        }
    }

    @ViewBuilder
    private func content(viewportHeight: CGFloat) -> some View {
        // The overlay reuses the workbench episode grid; it must answer for
        // this layer rather than for the page underneath it.
        contentBody(viewportHeight: viewportHeight)
            .cardHighlightFreeze(selection.highlight)
            .interfaceLayer(.playbackOverlay)
    }

    @ViewBuilder
    private func contentBody(viewportHeight: CGFloat) -> some View {
        if case .loading = store.detailStatus, store.detail == nil {
            PlaybackEmptyHint {
                WorkbenchSpinner()
            }
        } else if let detail = store.detail, !detail.videos.isEmpty {
            CompleteLibraryEpisodeGrid(
                folderTitle: detail.folderTitle,
                videos: detail.videos,
                highlight: selection.highlight,
                itemFrameCoordinateSpace: coordinateSpaceName,
                onItemFramesChange: { frames in
                    selection.recordVisibleFrames(
                        frames,
                        viewportHeight: viewportHeight
                    )
                },
                onOpen: { video in
                    _ = onOpenEpisode(video)
                }
            )
            .background(alignment: .topLeading) {
                PlaybackMediaScrollPositionBridge(
                    restorationOffsetY: selection.scrollOffsetY,
                    restoresInitialOffset: selection.pendingScrollRequest == nil,
                    scrollRequest: selection.pendingScrollRequest,
                    isFirstRowSelection: isFirstRowSelection,
                    itemFramesByID: selection.itemFramesByID,
                    topPadding: 0,
                    bottomPadding: PlaybackSubtitleFocusMetrics.contentInset,
                    onOffsetChanged: selection.recordScrollOffsetY,
                    onScrollRequestHandled: selection.markScrollRequestHandled
                )
                .frame(width: 0, height: 0)
            }
        } else {
            // The folder kept no video the library still holds.
            PlaybackEmptyHint(L("playback.playlist.left_library"))
        }
    }

    private func updateGridLayout(containerWidth: CGFloat) {
        selection.updateAdaptiveGrid(
            containerWidth: max(
                0,
                containerWidth
                    - PlaybackSubtitleFocusMetrics.contentInset * 2
            ),
            minimumItemWidth: WorkbenchControlMetrics
                .redesignLibraryRecentCardMinWidth,
            itemGap: WorkbenchControlMetrics.redesignLibraryRecentGridGap
        )
    }
}

/// Empty State / Empty Hint on the Playback Overlay.
struct PlaybackEmptyHint<Content: View>: View {
    private let content: Content

    init(_ message: String) where Content == Text {
        content = Text(message)
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeLibraryMeta))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
    }
}
