import CueSeekerCore
import SwiftUI

struct PlaybackCommandPanel: View {
    @EnvironmentObject private var pointerVisibility:
        PlaybackPointerVisibilityStore
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var searchStore: SearchStore
    @ObservedObject var libraryStore: LibraryStore
    @ObservedObject var shioriStore: ShioriStore

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.32)

                if let presentation = playback.commandPanelPresentation {
                    Group {
                        switch presentation.page {
                        case .root:
                            PlaybackCommandPanelRoot(
                                presentation: presentation,
                                query: Binding(
                                    get: { presentation.query },
                                    set: {
                                        appState
                                            .updatePlaybackCommandPanelQuery($0)
                                    }
                                ),
                                onSubmitSearch: {
                                    appState
                                        .submitPlaybackCommandPanelSearch()
                                },
                                onOpenPage: {
                                    appState.presentPlaybackCommandPanelPage($0)
                                }
                            )
                        case .searchResults:
                            PlaybackCommandPanelSearchResults(
                                presentation: presentation,
                                searchStore: searchStore,
                                windowStore:
                                    playback.commandPanelSearchWindow,
                                onBack: {
                                    appState.returnPlaybackCommandPanelToRoot()
                                },
                                onSynchronize: {
                                    appState
                                        .synchronizePlaybackCommandPanelSearchResults()
                                },
                                onCommitSelection: {
                                    appState
                                        .commitPlaybackCommandPanelSearchReelSelection(
                                            $0
                                        )
                                },
                                onCopySelectedText:
                                    appState.copyPlaybackSelectedText,
                                onSearchSelectedText:
                                    appState.searchPlaybackSelectedText
                            )
                        case .recentVideos:
                            PlaybackCommandPanelRecentVideos(
                                presentation: presentation,
                                libraryStore: libraryStore,
                                allowsHover: pointerVisibility.isVisible,
                                onBack: {
                                    appState.returnPlaybackCommandPanelToRoot()
                                },
                                onSynchronize: {
                                    appState
                                        .synchronizePlaybackCommandPanelSelection()
                                },
                                onGridLayoutChange: {
                                    appState
                                        .updatePlaybackCommandPanelRecentVideoGridLayout(
                                            columnCount: $0,
                                            itemFramesByID: $1
                                        )
                                },
                                onOpen: {
                                    appState.openPlaybackCommandPanelRecentVideo(
                                        at: $0
                                    )
                                }
                            )
                        case .recentShioris:
                            PlaybackCommandPanelRecentShioris(
                                presentation: presentation,
                                shioriStore: shioriStore,
                                allowsHover: pointerVisibility.isVisible,
                                onBack: {
                                    appState.returnPlaybackCommandPanelToRoot()
                                },
                                onSynchronize: {
                                    appState
                                        .synchronizePlaybackCommandPanelSelection()
                                },
                                onOpen: {
                                    appState.openPlaybackCommandPanelRecentShiori(
                                        at: $0
                                    )
                                }
                            )
                        }
                    }
                    .frame(
                        width: min(
                            PlaybackCommandPanelMetrics.maximumWidth,
                            max(
                                0,
                                geometry.size.width
                                    - PlaybackCommandPanelMetrics.outerInset * 2
                            )
                        ),
                        height: min(
                            PlaybackCommandPanelMetrics.maximumHeight,
                            max(
                                0,
                                geometry.size.height
                                    - PlaybackCommandPanelMetrics.outerInset * 2
                            )
                        )
                    )
                    .background(WorkbenchRedesignColors.bgPopover)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: PlaybackCommandPanelMetrics.cornerRadius,
                            style: .continuous
                        )
                    )
                    .shadow(
                        color: WorkbenchRedesignColors.shadowPopover.color,
                        radius: WorkbenchRedesignColors.shadowPopover.radius,
                        x: WorkbenchRedesignColors.shadowPopover.x,
                        y: WorkbenchRedesignColors.shadowPopover.y
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
        }
    }
}

private enum PlaybackCommandPanelMetrics {
    static let maximumWidth: CGFloat = 1_040
    static let maximumHeight: CGFloat = 720
    static let outerInset: CGFloat = 40
    static let cornerRadius: CGFloat = 18
    static let contentInset: CGFloat = 20
    static let rowHeight: CGFloat = 48
    static let rowRadius: CGFloat = 10
    static let headerHeight: CGFloat = 58
    static let footerHeight: CGFloat = 48
}

private struct PlaybackCommandPanelRoot: View {
    let presentation: PlaybackCommandPanelPresentation
    @Binding var query: String
    let onSubmitSearch: () -> Bool
    let onOpenPage: (PlaybackCommandPanelPage) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            WorkbenchSearchField(
                placeholder: "Search",
                text: $query,
                isRedesign: true,
                autofocus: true,
                placesInsertionPointAtEndOnAutofocus: true
            ) {
                _ = onSubmitSearch()
            }
            .padding(PlaybackCommandPanelMetrics.contentInset)

            VStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                if !query.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty {
                    PlaybackCommandPanelRootRow(
                        systemImage: "magnifyingglass",
                        title: "Search",
                        detail: query,
                        isSelected: presentation.selectedOrdinal == 0
                    ) {
                        _ = onSubmitSearch()
                    }
                }

                PlaybackCommandPanelRootRow(
                    systemImage: "play.rectangle",
                    title: "Recent Videos",
                    detail: nil,
                    isSelected: presentation.selectedOrdinal
                        == (trimmedQuery.isEmpty ? 0 : 1)
                ) {
                    _ = onOpenPage(.recentVideos)
                }

                PlaybackCommandPanelRootRow(
                    systemImage: "bookmark",
                    title: "Recent Shioris",
                    detail: nil,
                    isSelected: presentation.selectedOrdinal
                        == (trimmedQuery.isEmpty ? 1 : 2)
                ) {
                    _ = onOpenPage(.recentShioris)
                }
            }
            .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)

            Spacer(minLength: 0)

            PlaybackCommandPanelFooter(status: nil)
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PlaybackCommandPanelRootRow: View {
    let systemImage: String
    let title: String
    let detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                Image(systemName: systemImage)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignControlIconSize,
                        weight: .medium
                    ))
                    .frame(
                        width: WorkbenchControlMetrics.redesignControlIconSize,
                        height: WorkbenchControlMetrics.redesignControlIconSize
                    )

                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .medium
                    ))

                if let detail {
                    Text(detail)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .regular
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing3)
            .frame(
                maxWidth: .infinity,
                minHeight: PlaybackCommandPanelMetrics.rowHeight,
                maxHeight: PlaybackCommandPanelMetrics.rowHeight
            )
            .background {
                RoundedRectangle(
                    cornerRadius: PlaybackCommandPanelMetrics.rowRadius,
                    style: .continuous
                )
                .fill(
                    isSelected
                        ? WorkbenchRedesignColors.rowSelected
                        : Color.clear
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .pointerOnHover(isEnabled: true)
    }
}

private struct PlaybackCommandPanelSecondaryHeader: View {
    let title: String
    let onBack: () -> Bool

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)

            HStack {
                Button {
                    _ = onBack()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(
                            size: WorkbenchControlMetrics
                                .redesignControlIconSize,
                            weight: .semibold
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.iconDefault)
                        .frame(
                            width: PlaybackCommandPanelMetrics.rowHeight,
                            height: PlaybackCommandPanelMetrics.rowHeight
                        )
                        .background {
                            RoundedRectangle(
                                cornerRadius:
                                    PlaybackCommandPanelMetrics.rowRadius,
                                style: .continuous
                            )
                            .fill(WorkbenchRedesignColors.bgHover)
                        }
                }
                .buttonStyle(.plain)
                .focusable(false)
                .pointerOnHover(isEnabled: true)
                .accessibilityLabel("Back")

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
        .frame(height: PlaybackCommandPanelMetrics.headerHeight)
    }
}

private struct PlaybackCommandPanelSearchResults: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var searchStore: SearchStore
    let windowStore: PlaybackCueResultSessionWindowStore?
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onCommitSelection: (PlaybackVirtualReelSelectionCommit) -> Bool
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void

    @EnvironmentObject private var cueGroupPresentation:
        CueGroupPresentationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            PlaybackCommandPanelSecondaryHeader(
                title: presentation.query,
                onBack: onBack
            )

            GeometryReader { geometry in
                if let windowStore {
                    PlaybackCommandPanelSearchReel(
                        windowStore: windowStore,
                        showsCueGroup: cueGroupPresentation.isEnabled,
                        positionTotalCount: resultTotalCount,
                        viewportSize: geometry.size,
                        reducesMotion: reduceMotion,
                        onCommitSelection: onCommitSelection,
                        onCopySelectedText: onCopySelectedText,
                        onSearchSelectedText: onSearchSelectedText
                    )
                }
            }

            PlaybackCommandPanelFooter(status: resultStatus)
        }
        .onAppear(perform: onSynchronize)
        .onChange(of: searchStore.resultRevision) { _ in
            onSynchronize()
        }
        .onChange(of: searchStore.filteredSearchResultTotalCount) { _ in
            onSynchronize()
        }
    }

    private var resultStatus: String {
        if resultTotalCount > PlaybackCommandPanelPresentation.previewLimit
            || searchStore.hasMoreSearchResults {
            return "Showing first \(PlaybackCommandPanelPresentation.previewLimit) results"
        }
        return "\(resultTotalCount) results"
    }

    private var resultTotalCount: Int {
        max(
            searchStore.filteredSearchResultTotalCount ?? 0,
            searchStore.projectedSearchResults.count
        )
    }
}

private struct PlaybackCommandPanelSearchReel: View {
    @ObservedObject var windowStore: PlaybackCueResultSessionWindowStore
    let showsCueGroup: Bool
    let positionTotalCount: Int
    let viewportSize: CGSize
    let reducesMotion: Bool
    let onCommitSelection: (PlaybackVirtualReelSelectionCommit) -> Bool
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void

    var body: some View {
        let contentInset = PlaybackSubtitleFocusMetrics.contentInset
        let reelViewportHeight = max(
            0,
            viewportSize.height - contentInset * 2
        )

        PlaybackCueResultReelRepresentable(
            windowStore: windowStore,
            showsCueGroup: showsCueGroup,
            positionTotalCount: positionTotalCount,
            selectedOrdinal: windowStore.selectedOrdinal,
            uiProbeScope: nil,
            keyboardNavigationRequest: nil,
            reducesMotion: reducesMotion,
            isInteractionEnabled: true,
            cancelsWheelMotion: false,
            onCommitSelection: onCommitSelection,
            onCopySelectedText: onCopySelectedText,
            onSearchSelectedText: onSearchSelectedText,
            allowsNativeWheelInput: { true },
            allowsNativeScrollbarInput: { true },
            onScrollbarDraggingChanged: { _ in },
            onNativeMotionGateChanged: { _ in },
            onKeyboardMotionChanged: { _ in }
        )
        .id("command-search:\(windowStore.reelDatasetID ?? "empty")")
        .frame(
            width: viewportSize.width,
            height: reelViewportHeight,
            alignment: .top
        )
        .offset(y: contentInset)
    }
}

private struct PlaybackCommandPanelRecentVideos: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var libraryStore: LibraryStore
    let allowsHover: Bool
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onGridLayoutChange: (Int, [String: CGRect]) -> Void
    let onOpen: (Int) -> Void

    private let coordinateSpaceName =
        "playback-command-panel-recent-videos-scroll"

    private var items: [RecentLibraryWatchingPresentation] {
        libraryStore.testRecentWatchingItems
    }

    private var selectedItemID: String? {
        guard let ordinal = presentation.selectedOrdinal,
              items.indices.contains(ordinal)
        else {
            return nil
        }
        return items[ordinal].id
    }

    var body: some View {
        VStack(spacing: 0) {
            PlaybackCommandPanelSecondaryHeader(
                title: "Recent Videos",
                onBack: onBack
            )

            GeometryReader { geometry in
                let columnCount = adaptiveColumnCount(
                    containerWidth: max(
                        0,
                        geometry.size.width
                            - PlaybackCommandPanelMetrics.contentInset * 2
                    )
                )

                ScrollViewReader { proxy in
                    WorkbenchScrollView {
                        RecentWatchingGrid(
                            items: items,
                            selectedItemID: selectedItemID,
                            itemFrameCoordinateSpace: coordinateSpaceName,
                            onItemFramesChange: { frames in
                                onGridLayoutChange(columnCount, frames)
                            },
                            allowsHover: allowsHover
                        ) { item in
                            if let ordinal = items.firstIndex(where: {
                                $0.id == item.id
                            }) {
                                onOpen(ordinal)
                            }
                        }
                        .padding(
                            .horizontal,
                            PlaybackCommandPanelMetrics.contentInset
                        )
                        .padding(
                            .vertical,
                            WorkbenchControlMetrics.redesignSpacing2
                        )
                    }
                    .coordinateSpace(name: coordinateSpaceName)
                    .onAppear {
                        onGridLayoutChange(columnCount, [:])
                    }
                    .onChange(of: columnCount) { columnCount in
                        onGridLayoutChange(columnCount, [:])
                        scrollToSelected(using: proxy)
                    }
                    .onChange(of: selectedItemID) { _ in
                        scrollToSelected(using: proxy)
                    }
                }
            }

            PlaybackCommandPanelFooter(
                status: "\(libraryStore.testRecentWatchingItems.count) videos",
                showsHorizontalNavigation: true
            )
        }
        .onAppear(perform: onSynchronize)
        .onChange(
            of: libraryStore.testRecentWatchingItems.map(\.id)
        ) { _ in
            onSynchronize()
        }
    }

    private func adaptiveColumnCount(containerWidth: CGFloat) -> Int {
        let minimumWidth = WorkbenchControlMetrics
            .redesignLibraryRecentCardMinWidth
        let gap = WorkbenchControlMetrics.redesignLibraryRecentGridGap
        return max(
            1,
            Int((containerWidth + gap) / (minimumWidth + gap))
        )
    }

    private func scrollToSelected(using proxy: ScrollViewProxy) {
        guard let selectedItemID else {
            return
        }
        proxy.scrollTo(selectedItemID)
    }
}

private struct PlaybackCommandPanelRecentShioris: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var shioriStore: ShioriStore
    let allowsHover: Bool
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onOpen: (Int) -> Void

    private var summaries: [ShioriListSummary] {
        shioriStore.recentListSummaries
    }

    private var selectedItemID: Int64? {
        guard let ordinal = presentation.selectedOrdinal,
              summaries.indices.contains(ordinal)
        else {
            return nil
        }
        return summaries[ordinal].id
    }

    var body: some View {
        VStack(spacing: 0) {
            PlaybackCommandPanelSecondaryHeader(
                title: "Recent Shioris",
                onBack: onBack
            )

            ScrollViewReader { proxy in
                WorkbenchScrollView {
                    RecentShioriResumeList(
                        summaries: summaries,
                        selectedItemID: selectedItemID,
                        allowsHover: allowsHover
                    ) { summary in
                        if let ordinal = summaries.firstIndex(where: {
                            $0.id == summary.id
                        }) {
                            onOpen(ordinal)
                        }
                    }
                    .padding(
                        .horizontal,
                        PlaybackCommandPanelMetrics.contentInset
                    )
                    .padding(
                        .vertical,
                        WorkbenchControlMetrics.redesignSpacing2
                    )
                }
                .onChange(of: selectedItemID) { selectedItemID in
                    guard let selectedItemID else {
                        return
                    }
                    proxy.scrollTo(selectedItemID)
                }
            }

            PlaybackCommandPanelFooter(
                status: "\(shioriStore.recentListSummaries.count) shioris"
            )
        }
        .onAppear(perform: onSynchronize)
        .onChange(of: shioriStore.recentListSummaries.map(\.id)) { _ in
            onSynchronize()
        }
    }
}

private struct PlaybackCommandPanelFooter: View {
    let status: String?
    var showsHorizontalNavigation = false

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            if let status {
                Text(status)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
            }

            Spacer(minLength: 0)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                if showsHorizontalNavigation {
                    PlaybackCommandPanelKeycap(symbol: "←")
                    PlaybackCommandPanelKeycap(symbol: "→")
                }
                PlaybackCommandPanelKeycap(symbol: "↑")
                PlaybackCommandPanelKeycap(symbol: "↓")
                Text("Navigate")
            }

            Text("Open")
            PlaybackCommandPanelKeycap(symbol: "↩")
        }
        .font(.system(
            size: WorkbenchControlMetrics.redesignFontSizeBody,
            weight: .medium
        ))
        .foregroundStyle(WorkbenchRedesignColors.textMuted)
        .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
        .frame(height: PlaybackCommandPanelMetrics.footerHeight)
    }
}

private struct PlaybackCommandPanelKeycap: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .semibold
            ))
            .frame(minWidth: 24, minHeight: 22)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignSpacing1,
                    style: .continuous
                )
                .fill(WorkbenchRedesignColors.bgHover)
            }
    }
}
