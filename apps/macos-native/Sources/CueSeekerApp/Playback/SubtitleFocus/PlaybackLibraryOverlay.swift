import CueSeekerCore
import SwiftUI

struct PlaybackLibraryOverlay: View {
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
    }

    var body: some View {
        Group {
            switch store.level {
            case .folders:
                PlaybackLibraryFolderLevel(
                    store: store,
                    selection: store.folderSelection
                )
            case .folderDetail(_, let folderTitle):
                if let episodeSelection = store.episodeSelection {
                    VStack(spacing: 0) {
                        LibraryFolderDetailHeader(
                            folderTitle: folderTitle,
                            onBack: {
                                _ = store.returnToFolders()
                            }
                        )
                        .padding(.horizontal, PlaybackSubtitleFocusMetrics.contentInset)
                        .padding(.top, PlaybackSubtitleFocusMetrics.contentInset)

                        PlaybackLibraryEpisodeLevel(
                            store: store,
                            selection: episodeSelection,
                            onOpenEpisode: onOpenEpisode
                        )
                    }
                }
            }
        }
        .onAppear {
            store.activate()
        }
        .onChange(of: library.completeLibraryRevision) { _ in
            store.refreshForSourceRevision()
        }
        .onChange(of: library.libraryPlaybackHistoryRevision) { _ in
            store.refreshForSourceRevision()
        }
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
        .environment(\.colorScheme, .dark)
    }
}

private struct PlaybackLibraryFolderLevel: View {
    @ObservedObject var store: PlaybackLibrarySessionStore
    @ObservedObject var selection: PlaybackMediaSelectionStore

    private let coordinateSpaceName = "playback-library-folders-scroll"
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    content(viewportHeight: geometry.size.height)
                        .padding(PlaybackSubtitleFocusMetrics.contentInset)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .coordinateSpace(name: coordinateSpaceName)
                .onAppear {
                    updateGridWidth(geometry.size.width)
                    scheduleScroll(
                        selection.pendingScrollRequest,
                        using: scrollProxy
                    )
                }
                .onChange(of: geometry.size.width) { width in
                    updateGridWidth(width)
                }
                .onChange(of: selection.scrollRequest) { request in
                    scheduleScroll(
                        request,
                        using: scrollProxy
                    )
                }
                .onDisappear {
                    scrollTask?.cancel()
                    scrollTask = nil
                }
            }
        }
    }

    @ViewBuilder
    private func content(viewportHeight: CGFloat) -> some View {
        if case .loading = store.folderStatus, store.folders.isEmpty {
            PlaybackLibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = store.folderStatus {
            PlaybackLibraryEmptyHint(message)
        } else if store.folders.isEmpty {
            PlaybackLibraryEmptyHint("No library videos yet.")
        } else {
            CompleteLibraryFolderGrid(
                folders: store.folders,
                selectedItemID: selection.selectedItemID,
                itemFrameCoordinateSpace: coordinateSpaceName,
                onItemFramesChange: { frames in
                    selection.recordVisibleFrames(
                        frames,
                        viewportHeight: viewportHeight
                    )
                },
                onOpen: { folder in
                    _ = store.enterFolder(itemID: folder.id)
                }
            )
            .background(alignment: .topLeading) {
                PlaybackMediaScrollPositionBridge(
                    restorationOffsetY: selection.scrollOffsetY,
                    restoresInitialOffset: selection.pendingScrollRequest == nil,
                    onOffsetChanged: selection.recordScrollOffsetY
                )
                .frame(width: 0, height: 0)
            }
        }
    }

    private func updateGridWidth(_ viewportWidth: CGFloat) {
        selection.updateAdaptiveGrid(
            containerWidth: max(
                0,
                viewportWidth - PlaybackSubtitleFocusMetrics.contentInset * 2
            ),
            minimumItemWidth: WorkbenchControlMetrics
                .redesignLibraryRecentCardMinWidth,
            itemGap: WorkbenchControlMetrics.redesignLibraryRecentGridGap
        )
    }

    private func scheduleScroll(
        _ request: PlaybackMediaSelectionScrollRequest?,
        using proxy: ScrollViewProxy
    ) {
        scrollTask?.cancel()
        guard let request else {
            scrollTask = nil
            return
        }
        scrollTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            proxy.scrollTo(request.itemID, anchor: .center)
            selection.markScrollRequestHandled(sequence: request.sequence)
        }
    }
}

private struct PlaybackLibraryEpisodeLevel: View {
    @ObservedObject var store: PlaybackLibrarySessionStore
    @ObservedObject var selection: PlaybackMediaSelectionStore
    let onOpenEpisode: (CompleteLibraryVideoPresentation) -> Bool

    private let coordinateSpaceName = "playback-library-episodes-scroll"
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    content(viewportHeight: geometry.size.height)
                        .padding(.horizontal, PlaybackSubtitleFocusMetrics.contentInset)
                        .padding(.bottom, PlaybackSubtitleFocusMetrics.contentInset)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .coordinateSpace(name: coordinateSpaceName)
                .onAppear {
                    selection.updateColumnCount(1)
                    scheduleScroll(
                        selection.pendingScrollRequest,
                        using: scrollProxy
                    )
                }
                .onChange(of: selection.scrollRequest) { request in
                    scheduleScroll(
                        request,
                        using: scrollProxy
                    )
                }
                .onDisappear {
                    scrollTask?.cancel()
                    scrollTask = nil
                }
            }
        }
    }

    @ViewBuilder
    private func content(viewportHeight: CGFloat) -> some View {
        if case .loading = store.detailStatus, store.detail == nil {
            PlaybackLibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = store.detailStatus {
            PlaybackLibraryEmptyHint(message)
        } else if let detail = store.detail {
            CompleteLibraryEpisodeGrid(
                videos: detail.videos,
                selectedItemID: selection.selectedItemID,
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
                    onOffsetChanged: selection.recordScrollOffsetY
                )
                .frame(width: 0, height: 0)
            }
        } else {
            PlaybackLibraryEmptyHint("No episodes yet.")
        }
    }

    private func scheduleScroll(
        _ request: PlaybackMediaSelectionScrollRequest?,
        using proxy: ScrollViewProxy
    ) {
        scrollTask?.cancel()
        guard let request else {
            scrollTask = nil
            return
        }
        scrollTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            proxy.scrollTo(request.itemID, anchor: .center)
            selection.markScrollRequestHandled(sequence: request.sequence)
        }
    }
}

private struct PlaybackLibraryEmptyHint<Content: View>: View {
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
