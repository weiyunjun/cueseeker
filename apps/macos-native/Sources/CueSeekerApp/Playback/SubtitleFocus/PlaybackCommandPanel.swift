import CueSeekerCore
import SwiftUI

struct PlaybackCommandPanel: View {
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
                                onBack: {
                                    appState.returnPlaybackCommandPanelToRoot()
                                },
                                onSynchronize: {
                                    appState
                                        .synchronizePlaybackCommandPanelSearchResults()
                                },
                                onOpen: {
                                    appState.requestPlaybackCommandPanelSearchAction(
                                        .playFromThisCue,
                                        ordinal: $0
                                    )
                                }
                            )
                        case .recentVideos:
                            PlaybackCommandPanelRecentVideos(
                                presentation: presentation,
                                libraryStore: libraryStore,
                                onBack: {
                                    appState.returnPlaybackCommandPanelToRoot()
                                },
                                onSynchronize: {
                                    appState
                                        .synchronizePlaybackCommandPanelSelection()
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
    static let searchResultRowMinimumHeight: CGFloat = 68
    static let contextWidthFraction: CGFloat = 0.22
    static let contextCoverMaximumWidth: CGFloat = 180
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
                showsFocusRing: false,
                autofocus: true
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
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onOpen: (Int) -> Void

    private var previewResults: [SubtitleSearchResult] {
        Array(
            searchStore.searchResults.prefix(
                PlaybackCommandPanelPresentation.previewLimit
            )
        )
    }

    private var selectedResult: SubtitleSearchResult? {
        guard let ordinal = presentation.selectedOrdinal,
              previewResults.indices.contains(ordinal)
        else {
            return nil
        }
        return previewResults[ordinal]
    }

    var body: some View {
        VStack(spacing: 0) {
            PlaybackCommandPanelSecondaryHeader(
                title: presentation.query,
                onBack: onBack
            )

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    PlaybackCommandPanelSearchContext(
                        result: selectedResult,
                        videoPresentation:
                            presentation.selectedVideoPresentation
                    )
                    .frame(
                        width: geometry.size.width
                            * PlaybackCommandPanelMetrics.contextWidthFraction
                    )
                    .frame(maxHeight: .infinity)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(
                                spacing: WorkbenchControlMetrics.redesignSpacing1
                            ) {
                                ForEach(
                                    Array(previewResults.enumerated()),
                                    id: \.element.entryID
                                ) { ordinal, result in
                                    PlaybackCommandPanelSearchResultRow(
                                        result: result,
                                        isSelected:
                                            presentation.selectedOrdinal
                                                == ordinal
                                    ) {
                                        onOpen(ordinal)
                                    }
                                    .id(ordinal)
                                }
                            }
                            .padding(
                                .horizontal,
                                PlaybackCommandPanelMetrics.contentInset
                            )
                            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
                        }
                        .onChange(
                            of: presentation.selectedOrdinal
                        ) { selectedOrdinal in
                            guard let selectedOrdinal else {
                                return
                            }
                            withAnimation(.easeOut(duration: 0.16)) {
                                proxy.scrollTo(selectedOrdinal, anchor: .center)
                            }
                        }
                    }
                }
            }

            PlaybackCommandPanelFooter(status: resultStatus)
        }
        .onAppear(perform: onSynchronize)
        .onChange(of: searchStore.resultRevision) { _ in
            onSynchronize()
        }
    }

    private var resultStatus: String {
        let totalCount = max(
            searchStore.searchResultTotalCount,
            searchStore.searchResults.count
        )
        if totalCount > PlaybackCommandPanelPresentation.previewLimit
            || searchStore.hasMoreSearchResults {
            return "Showing first \(PlaybackCommandPanelPresentation.previewLimit) results"
        }
        return "\(totalCount) results"
    }
}

private struct PlaybackCommandPanelRecentVideos: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var libraryStore: LibraryStore
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onOpen: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlaybackCommandPanelSecondaryHeader(
                title: "Recent Videos",
                onBack: onBack
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(
                        spacing: WorkbenchControlMetrics.redesignSpacing2
                    ) {
                        ForEach(
                            Array(
                                libraryStore
                                    .testRecentWatchingItems
                                    .enumerated()
                            ),
                            id: \.element.id
                        ) { ordinal, item in
                            PlaybackCommandPanelRecentVideoRow(
                                item: item,
                                isSelected:
                                    presentation.selectedOrdinal == ordinal
                            ) {
                                onOpen(ordinal)
                            }
                            .id(ordinal)
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
                .onChange(of: presentation.selectedOrdinal) {
                    selectedOrdinal in
                    guard let selectedOrdinal else {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(selectedOrdinal, anchor: .center)
                    }
                }
            }

            PlaybackCommandPanelFooter(
                status: "\(libraryStore.testRecentWatchingItems.count) videos"
            )
        }
        .onAppear(perform: onSynchronize)
        .onChange(
            of: libraryStore.testRecentWatchingItems.map(\.id)
        ) { _ in
            onSynchronize()
        }
    }
}

private struct PlaybackCommandPanelRecentVideoRow: View {
    let item: RecentLibraryWatchingPresentation
    let isSelected: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(
                alignment: .center,
                spacing: WorkbenchControlMetrics.redesignSpacing4
            ) {
                LibraryCoverWithProgress(
                    coverPath: item.coverPath,
                    coverRevision: item.coverRevision,
                    positionMilliseconds: item.positionMilliseconds,
                    duration: item.playbackDuration ?? item.duration
                )
                .frame(
                    width: WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth
                )

                VStack(
                    alignment: .leading,
                    spacing: WorkbenchControlMetrics.redesignSpacing2
                ) {
                    Text(item.folderTitle)
                        .font(.system(
                            size: WorkbenchControlMetrics
                                .redesignFontSizeLibraryTitle,
                            weight: .semibold
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                        Text(String(format: "EP%02d", item.episodeNumber))
                            .font(.system(
                                size: WorkbenchControlMetrics
                                    .redesignFontSizeLibraryMeta,
                                weight: .medium
                            ))
                            .foregroundStyle(WorkbenchRedesignColors.textMuted)
                            .monospacedDigit()

                        WatchStatusBadge(
                            status: LibraryWatchStatus(item.watchState)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(WorkbenchControlMetrics.redesignSpacing3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(
                    cornerRadius:
                        WorkbenchControlMetrics.redesignLibraryListCardRadius,
                    style: .continuous
                )
                .fill(
                    isSelected
                        ? WorkbenchRedesignColors.libraryMediaCardHoverBg
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

private struct PlaybackCommandPanelRecentShioris: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var shioriStore: ShioriStore
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onOpen: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlaybackCommandPanelSecondaryHeader(
                title: "Recent Shioris",
                onBack: onBack
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            Array(shioriStore.recentListSummaries.enumerated()),
                            id: \.element.id
                        ) { ordinal, summary in
                            RecentShioriResumeRow(
                                summary: summary,
                                isSelected:
                                    presentation.selectedOrdinal == ordinal
                            ) {
                                onOpen(ordinal)
                            }
                            .id(ordinal)
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
                .onChange(of: presentation.selectedOrdinal) {
                    selectedOrdinal in
                    guard let selectedOrdinal else {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(selectedOrdinal, anchor: .center)
                    }
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

private struct PlaybackCommandPanelSearchContext: View {
    let result: SubtitleSearchResult?
    let videoPresentation: CompleteLibraryVideoPresentation?

    var body: some View {
        GeometryReader { geometry in
            let coverWidth = min(
                PlaybackCommandPanelMetrics.contextCoverMaximumWidth,
                max(
                    0,
                    geometry.size.width
                        - PlaybackCommandPanelMetrics.contentInset * 2
                )
            )
            let coverHeight = coverWidth
                / WorkbenchControlMetrics.redesignLibraryCoverAspectRatio

            VStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                LibraryCachedCoverImage(
                    coverPath: videoPresentation?.coverPath,
                    coverRevision: videoPresentation?.coverRevision
                )
                .frame(width: coverWidth, height: coverHeight)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            WorkbenchControlMetrics.redesignLibraryCoverRadius,
                        style: .continuous
                    )
                )

                if let result {
                    Text(
                        videoPresentation?.displayTitle
                            ?? result.displayTitle
                    )
                    .font(.system(
                        size: WorkbenchControlMetrics
                            .redesignFontSizeLibraryMeta,
                        weight: .medium
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                    Text(result.timeRange)
                        .font(.system(
                            size: WorkbenchControlMetrics
                                .redesignFontSizeLibraryMeta,
                            weight: .regular
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .monospacedDigit()
                }
            }
            .frame(width: geometry.size.width)
            .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
        }
    }
}

private struct PlaybackCommandPanelSearchResultRow: View {
    let result: SubtitleSearchResult
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignSpacing1
            ) {
                Text(result.content)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? WorkbenchRedesignColors.textPrimary
                            : WorkbenchRedesignColors.textMuted
                    )
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(result.displayTitle)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
            }
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignSpacing4
            )
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing3)
            .frame(
                maxWidth: .infinity,
                minHeight:
                    PlaybackCommandPanelMetrics.searchResultRowMinimumHeight,
                alignment: .leading
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

private struct PlaybackCommandPanelFooter: View {
    let status: String?

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
