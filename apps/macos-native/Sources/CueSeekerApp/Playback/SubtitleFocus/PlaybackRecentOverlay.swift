import CueSeekerCore
import SwiftUI

struct PlaybackRecentOverlay: View {
    @Environment(\.playbackPointerIsVisible) private var isPointerVisible
    @ObservedObject var store: PlaybackRecentSessionStore
    @ObservedObject private var library: LibraryStore
    @ObservedObject private var selection: PlaybackMediaSelectionStore
    let onOpenItem: (RecentLibraryWatchingPresentation) -> Bool

    private let coordinateSpaceName = "playback-recent-scroll"
    @State private var scrollTask: Task<Void, Never>?

    init(
        store: PlaybackRecentSessionStore,
        onOpenItem: @escaping (RecentLibraryWatchingPresentation) -> Bool
    ) {
        self.store = store
        _library = ObservedObject(wrappedValue: store.libraryStore)
        _selection = ObservedObject(wrappedValue: store.selection)
        self.onOpenItem = onOpenItem
    }

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
                    store.activate()
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
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func content(viewportHeight: CGFloat) -> some View {
        if case .loading = library.testRecentWatchingStatus,
           library.testRecentWatchingItems.isEmpty {
            PlaybackRecentEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = library.testRecentWatchingStatus {
            PlaybackRecentEmptyHint(message)
        } else if library.testRecentWatchingItems.isEmpty {
            PlaybackRecentEmptyHint("No recent watching yet.")
        } else {
            RecentWatchingGrid(
                items: library.testRecentWatchingItems,
                selectedItemID: selection.selectedItemID,
                itemFrameCoordinateSpace: coordinateSpaceName,
                onItemFramesChange: { frames in
                    selection.recordVisibleFrames(
                        frames,
                        viewportHeight: viewportHeight
                    )
                },
                allowsHoverSelection: isPointerVisible,
                onHoverSelection: { item in
                    selection.selectFromPointer(item.id)
                },
                showsContextMenuItem: false,
                onOpen: { item in
                    _ = onOpenItem(item)
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

private struct PlaybackRecentEmptyHint<Content: View>: View {
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
