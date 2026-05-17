import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @State private var collapsedLibraryFolderPaths: Set<String> = []

    var body: some View {
        AppPerformanceProbe.measure("SearchView.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.Workbench.body")

            return GeometryReader { geometry in
                let showsPlaybackRoute = appState.isPlaybackPageVisible

                ZStack {
                    mainContent
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipped()

                    if showsPlaybackRoute {
                        PlaybackRewriteRoute(
                            playbackSurface: AnyView(playbackSurface),
                            appState: appState
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .zIndex(10)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .background(LayoutPerformanceProbe(name: "SearchView.root.layout"))
            }
            .onAppear {
                resetCollapsedLibraryFolders()
            }
            .onChange(of: appState.libraryPresentationRevision) { _ in
                resetCollapsedLibraryFolders()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        AppPerformanceProbe.measure("SearchView.mainContent.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count(
                "UI.WorkbenchMainContent.body",
                details: "mode=\(layoutState.panelMode.rawValue)"
            )

            return Group {
                switch layoutState.panelMode {
                case .library:
                    libraryPanel
                case .search:
                    topbarSearchResultsArea
                case .shiori:
                    shioriPanel
                }
            }
        }
    }

    private var libraryPanel: some View {
        AppPerformanceProbe.measure("SearchView.libraryPanel.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.LibraryPanel.body")

            return VStack(alignment: .leading, spacing: 6) {
                libraryHeader

                if appState.selectedFolders.isEmpty {
                    EmptyStateView(
                        title: "No Library",
                        systemImage: "folder",
                        message: "Add subtitle folders in CueSeeker > Settings..., then reindex."
                    )
                    .font(.system(size: SearchTypography.bodySize))
                } else if case .loading = appState.libraryStatus, appState.libraryVideos.isEmpty {
                    EmptyStateView(
                        title: "Loading Library",
                        systemImage: "folder",
                        message: "Reading indexed videos."
                    )
                    .font(.system(size: SearchTypography.bodySize))
                    .overlay {
                        ProgressView()
                            .offset(y: 72)
                    }
                } else if case .failed(let message) = appState.libraryStatus {
                    EmptyStateView(
                        title: "Library Failed",
                        systemImage: "exclamationmark.triangle",
                        message: message
                    )
                    .font(.system(size: SearchTypography.bodySize))
                } else if appState.libraryVideos.isEmpty {
                    EmptyStateView(
                        title: "No Videos",
                        systemImage: "play.rectangle",
                        message: "Reindex subtitle folders to populate Library videos."
                    )
                    .font(.system(size: SearchTypography.bodySize))
                } else {
                    libraryList
                }

                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, AppShellLayout.contentTopPadding)
            .background(Color(nsColor: .textBackgroundColor))
            .background(LayoutPerformanceProbe(name: "SearchView.libraryPanel.layout"))
        }
    }

    private var libraryHeader: some View {
        HStack(spacing: 12) {
            Text("Library")
                .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.leading, 12)
        .padding(.trailing, 28) // 12 + 16px to account for the ScrollView scrollbar width
        .frame(height: 36)
    }

    private var libraryList: some View {
        let rowCount = appState.libraryFolderGroups.reduce(0) { $0 + $1.videos.count }
        UIInvalidationProbe.count(
            "UI.LibraryRows.rendered",
            details: "groups=\(appState.libraryFolderGroups.count) rows=\(rowCount)"
        )

        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.libraryFolderGroups) { group in
                            let isCollapsed = collapsedLibraryFolderPaths.contains(group.folderPath)
                            LibraryFolderGroupView(
                                group: group,
                                isCollapsed: isCollapsed,
                                selectedLibraryVideoPath: appState.selectedLibraryVideo?.videoPath,
                                onToggle: {
                                    appState.clearSearchFocus()
                                    toggleLibraryFolderGroup(group.folderPath, proxy: proxy)
                                },
                                onOpenVideo: { video in
                                    appState.clearSearchFocus()
                                    appState.openLibraryVideo(video)
                                }
                            )
                        }
                    }
                    .frame(width: max(0, geo.size.width - 16), alignment: .leading)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func resetCollapsedLibraryFolders() {
        collapsedLibraryFolderPaths = Set(appState.libraryFolderGroups.map(\.id))
    }

    private func toggleLibraryFolderGroup(_ folderPath: String, proxy: ScrollViewProxy) {
        let wasCollapsed = collapsedLibraryFolderPaths.contains(folderPath)
        UIInvalidationProbe.mark(
            "ACTION UI.LibraryFolder.toggled",
            details: "collapsedBefore=\(wasCollapsed)"
        )
        if wasCollapsed {
            collapsedLibraryFolderPaths.remove(folderPath)
            if let selectedVideoPath = appState.selectedLibraryVideo?.videoPath,
               let group = appState.libraryFolderGroups.first(where: { $0.folderPath == folderPath }),
               group.videos.contains(where: { $0.video.videoPath == selectedVideoPath }) {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(selectedVideoPath, anchor: .center)
                    }
                }
            }
        } else {
            collapsedLibraryFolderPaths.insert(folderPath)
        }
    }

    private var shioriPanel: some View {
        AppPerformanceProbe.measure("SearchView.shioriPanel.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.ShioriPanel.body")

            return GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 6) {
                    shioriHeader

                    if appState.shioris.isEmpty {
                        EmptyStateView(
                            title: "No Shiori",
                            systemImage: "bookmark",
                            message: "Save subtitles from playback to collect Shiori."
                        )
                        .font(.system(size: SearchTypography.bodySize))
                    } else {
                        shioriCardList
                    }

                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, AppShellLayout.contentTopPadding)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .contentShape(Rectangle())
            }
            .background(Color(nsColor: .textBackgroundColor))
            .background(LayoutPerformanceProbe(name: "SearchView.shioriPanel.layout"))
        }
    }

    private var shioriHeader: some View {
        HStack(spacing: 12) {
            Text(shioriSummaryText)
                .font(.system(size: SearchTypography.detailSize))
                .foregroundStyle(.secondary)

            Spacer()

            if appState.hasShioriFileGroups {
                Button {
                    appState.clearSearchFocus()
                    appState.collapseAllShioriGroups()
                } label: {
                    Text("Collapse All")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 28)
        .frame(height: 36)
    }

    private var shioriSummaryText: String {
        "\(appState.shioriCount) shioris in \(appState.shioriFileCount) files"
    }

    private var searchResultSummaryText: String? {
        guard !appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        switch appState.searchStatus {
        case .idle:
            return nil
        case .searching where appState.searchResults.isEmpty:
            return nil
        case .failed where appState.searchResults.isEmpty:
            return nil
        case .searching, .completed, .failed:
            let fileText = appState.searchResultFileCount == 1 ? "file" : "files"
            return "Found \(appState.searchResultTotalCount) results in \(appState.searchResultFileCount) \(fileText)"
        }
    }

    private var shioriCardList: some View {
        UIInvalidationProbe.count(
            "UI.ShioriCards.rendered",
            details: "groups=\(appState.shioriFileGroups.count) rows=\(appState.shioriCount)"
        )

        return GeometryReader { geo in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SearchCardLayout.groupSpacing) {
                    ForEach(appState.shioriFileGroups) { group in
                        ShioriCardGroupView(
                            group: group,
                            selectedShiori: appState.selectedShiori,
                            onToggle: {
                                appState.clearSearchFocus()
                                appState.toggleShioriGroup(group.subtitlePath)
                            },
                            onOpenShiori: { shiori in
                                appState.clearSearchFocus()
                                appState.openShiori(shiori)
                            }
                        )
                    }
                }
                .padding(.horizontal, SearchCardLayout.contentHorizontalPadding)
                .padding(.top, SearchCardLayout.contentTopPadding)
                .padding(.bottom, SearchCardLayout.contentBottomPadding)
                .frame(width: max(0, geo.size.width), alignment: .topLeading)
            }
        }
    }

    private var shioriList: some View {
        UIInvalidationProbe.count(
            "UI.ShioriRows.rendered",
            details: "groups=\(appState.shioriFileGroups.count) rows=\(appState.shioriCount)"
        )

        return GeometryReader { geo in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.shioriFileGroups) { group in
                        ShioriGroupView(
                            group: group,
                            selectedShiori: appState.selectedShiori,
                            onToggle: {
                                appState.clearSearchFocus()
                                appState.toggleShioriGroup(group.subtitlePath)
                            },
                            onOpenShiori: { shiori in
                                appState.clearSearchFocus()
                                appState.openShiori(shiori)
                            }
                        )
                    }
                }
                .frame(width: max(0, geo.size.width - 16), alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }

    private var cardResultsList: some View {
        UIInvalidationProbe.count(
            "UI.SearchCards.rendered",
            details: "groups=\(appState.searchResultGroups.count) rows=\(appState.renderedSearchResultCount)"
        )

        return GeometryReader { geo in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SearchCardLayout.groupSpacing) {
                    ForEach(appState.searchResultGroups) { group in
                        SearchResultCardGroupView(
                            group: group,
                            query: appState.searchQuery,
                            selectedResult: appState.selectedSearchResult,
                            onToggle: {
                                appState.clearSearchFocus()
                                appState.toggleSearchResultGroup(group.subtitlePath)
                            },
                            onOpenResult: { result in
                                appState.clearSearchFocus()
                                appState.openSearchResult(result)
                            },
                            onResultAppear: { result in
                                appState.markSearchResultVisible(result)
                                appState.loadMoreSearchResultsIfNeeded(currentResult: result)
                            }
                        )
                    }

                    searchGlobalLoadMoreTrigger

                    if case .searching = appState.searchStatus, !appState.searchResults.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, SearchCardLayout.contentHorizontalPadding)
                .padding(.top, SearchCardLayout.contentTopPadding)
                .padding(.bottom, SearchCardLayout.contentBottomPadding)
                .frame(width: max(0, geo.size.width), alignment: .topLeading)
            }
        }
    }

    private var resultsList: some View {
        UIInvalidationProbe.count(
            "UI.SearchRows.rendered",
            details: "groups=\(appState.searchResultGroups.count) rows=\(appState.renderedSearchResultCount)"
        )

        return GeometryReader { geo in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.searchResultGroups) { group in
                        SearchResultGroupView(
                            group: group,
                            query: appState.searchQuery,
                            selectedResult: appState.selectedSearchResult,
                            showsThumbnails: appState.searchResultThumbnailsEnabled,
                            onToggle: {
                                appState.clearSearchFocus()
                                appState.toggleSearchResultGroup(group.subtitlePath)
                            },
                            onOpenResult: { result in
                                appState.clearSearchFocus()
                                appState.openSearchResult(result)
                            },
                            onResultAppear: { result in
                                appState.markSearchResultVisible(result)
                                appState.loadMoreSearchResultsIfNeeded(currentResult: result)
                            }
                        )
                    }

                    searchGlobalLoadMoreTrigger

                    if case .searching = appState.searchStatus, !appState.searchResults.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .frame(width: max(0, geo.size.width - 16), alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var searchGlobalLoadMoreTrigger: some View {
        if appState.shouldShowSearchGlobalLoadMoreTrigger {
            Color.clear
                .frame(height: 1)
                .id(appState.searchGlobalLoadMoreTriggerID)
                .onAppear {
                    appState.loadMoreSearchResultsIfNeeded()
                }
        }
    }

    private var playbackSurface: some View {
        PlaybackView(
            player: appState.playbackPlayer,
            viewModel: appState.playbackViewModel,
            fullscreenManager: appState.playbackFullscreenManager,
            onSurfaceTap: {
                appState.clearSearchFocus()
                appState.togglePlaybackFromUser()
            },
            onCopySubtitle: {
                appState.clearSearchFocus()
                appState.copyCurrentSubtitleToClipboard()
            },
            onSaveShiori: {
                appState.clearSearchFocus()
                appState.toggleCurrentShiori()
            },
            isFullscreenToggleDisabled: layoutState.isVideoSizeTransitionInProgress,
            showsInlineControls: false,
            onToggleFullscreen: {
                appState.clearSearchFocus()
                appState.togglePlaybackFullscreenFromUser(
                    onCopySubtitle: {
                        appState.copyCurrentSubtitleToClipboard()
                    },
                    onSaveShiori: {
                        appState.toggleCurrentShiori()
                    }
                )
            }
        )
    }

    private var topbarSearchResultsArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(searchResultSummaryText ?? "Search")
                    .font(.system(size: SearchTypography.detailSize))
                    .foregroundStyle(.secondary)

                Spacer()

                if appState.hasSearchResultGroups {
                    Button {
                        appState.clearSearchFocus()
                        appState.collapseAllSearchResultGroups()
                    } label: {
                        Text("Collapse All")
                            .foregroundStyle(.secondary)
                    }
                    .disabled(!appState.canCollapseAllSearchResultGroups)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, AppShellLayout.contentTopPadding)

            if appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(
                    title: "No Search Query",
                    systemImage: "text.magnifyingglass",
                    message: "Type a query in the topbar Search field and press Return."
                )
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if case .searching = appState.searchStatus, appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "Searching",
                    systemImage: "magnifyingglass",
                    message: "Looking through indexed subtitle text."
                )
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    ProgressView()
                        .offset(y: 72)
                }
            } else if case .failed(let message) = appState.searchStatus, appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "Search Failed",
                    systemImage: "exclamationmark.triangle",
                    message: message
                )
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    systemImage: "tray",
                    message: "No indexed subtitle entries matched this query."
                )
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cardResultsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
    }

}

private struct PlaybackRewriteRoute: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            Color.black

            playbackSurface
                .aspectRatio(
                    CGFloat(appState.playbackViewModel?.videoAspectRatio ?? 16 / 9),
                    contentMode: .fit
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .overlay(alignment: .topLeading) {
                    if case .failed(let message) = appState.playbackStatus {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.system(size: SearchTypography.detailSize))
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                    }
                }
        }
    }
}

private extension View {
    func listRowAction(_ action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text("Activate"), action)
    }
}

private struct LibraryFolderGroupView: View {
    let group: LibraryFolderGroup
    let isCollapsed: Bool
    let selectedLibraryVideoPath: String?
    let onToggle: () -> Void
    let onOpenVideo: (LibraryVideo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LibraryFolderHeader(
                folderTitle: group.folderTitle,
                episodeCount: group.videos.count,
                playingRank: playingRank,
                isCollapsed: isCollapsed,
                onToggle: onToggle
            )

            if !isCollapsed {
                LibraryEpisodeGrid(
                    rows: group.videos,
                    selectedLibraryVideoPath: selectedLibraryVideoPath,
                    onOpenVideo: onOpenVideo
                )
            }
        }
    }

    private var playingRank: Int? {
        guard let path = selectedLibraryVideoPath,
              let index = group.videos.firstIndex(where: { $0.video.videoPath == path })
        else {
            return nil
        }
        return index + 1
    }
}

private struct LibraryFolderHeader: View {
    let folderTitle: String
    let episodeCount: Int
    let playingRank: Int?
    let isCollapsed: Bool
    let onToggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14, alignment: .center)
                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                .animation(.easeInOut(duration: 0.16), value: isCollapsed)

            VStack(alignment: .leading, spacing: 2) {
                Text(folderTitle)
                    .font(.system(size: SearchTypography.bodySize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitleText)
                    .font(.system(size: SearchTypography.detailSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, LibraryLayout.folderRowInnerHorizontalPadding)
        .padding(.vertical, LibraryLayout.folderRowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .padding(.leading, LibraryLayout.folderRowOuterLeadingPadding)
        .padding(.trailing, LibraryLayout.folderRowOuterTrailingPadding)
        .onHover { isHovered = $0 }
        .listRowAction(onToggle)
        .focusable(false)
    }

    private var subtitleText: String {
        let label = episodeCount == 1 ? "episode" : "episodes"
        if let rank = playingRank {
            return "\(episodeCount) \(label) · Playing \(rank)"
        }
        return "\(episodeCount) \(label)"
    }
}

private struct LibraryEpisodeGrid: View {
    let rows: [LibraryVideoRow]
    let selectedLibraryVideoPath: String?
    let onOpenVideo: (LibraryVideo) -> Void

    private let columns: [GridItem] = [
        GridItem(
            .adaptive(minimum: LibraryLayout.episodeButtonMinimumWidth),
            spacing: LibraryLayout.episodeGridHorizontalSpacing,
            alignment: .top
        )
    ]

    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: .center,
            spacing: LibraryLayout.episodeGridVerticalSpacing
        ) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                LibraryEpisodeButton(
                    rank: index + 1,
                    isSelected: row.video.videoPath == selectedLibraryVideoPath,
                    action: { onOpenVideo(row.video) }
                )
                .id(row.video.videoPath)
            }
        }
        .padding(.leading, LibraryLayout.episodeGridLeadingPadding)
        .padding(.trailing, LibraryLayout.episodeGridTrailingPadding)
        .padding(.top, LibraryLayout.episodeGridTopPadding)
        .padding(.bottom, LibraryLayout.episodeGridBottomPadding)
    }
}

private struct LibraryEpisodeButton: View {
    let rank: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text("\(rank)")
            .font(.system(size: SearchTypography.bodySize, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .frame(width: LibraryLayout.episodeButtonMinimumWidth, height: LibraryLayout.episodeButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .listRowAction(action)
            .focusable(false)
            .accessibilityLabel("Episode \(rank)")
    }

    private var textColor: Color {
        isSelected ? .white : .primary
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        }
        if isHovered {
            return Color.primary.opacity(0.08)
        }
        return Color.primary.opacity(0.04)
    }
}

private enum LibraryLayout {
    static let folderRowInnerHorizontalPadding: CGFloat = 12
    static let folderRowVerticalPadding: CGFloat = 8
    static let folderRowOuterLeadingPadding: CGFloat = 12
    static let folderRowOuterTrailingPadding: CGFloat = 12
    static let episodeButtonMinimumWidth: CGFloat = 44
    static let episodeButtonHeight: CGFloat = 36
    static let episodeGridHorizontalSpacing: CGFloat = 8
    static let episodeGridVerticalSpacing: CGFloat = 8
    static let episodeGridLeadingPadding: CGFloat = 32
    static let episodeGridTrailingPadding: CGFloat = 32
    static let episodeGridTopPadding: CGFloat = 6
    static let episodeGridBottomPadding: CGFloat = 10
}

private enum SearchCardLayout {
    static let contentHorizontalPadding: CGFloat = 32
    static let contentTopPadding: CGFloat = 4
    static let contentBottomPadding: CGFloat = 28
    static let groupSpacing: CGFloat = 26
    static let cardMinimumWidth: CGFloat = 280
    static let cardHorizontalSpacing: CGFloat = 12
    static let cardVerticalSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 8
    static let cardMinHeight: CGFloat = 92
}

private struct EqualHeightCardGridLayout: Layout {
    let minimumColumnWidth: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else {
            return .zero
        }

        let availableWidth = max(0, proposal.width ?? minimumColumnWidth)
        let columns = columnCount(for: availableWidth)
        let columnWidth = widthPerColumn(availableWidth: availableWidth, columns: columns)
        let rowHeights = measuredRowHeights(
            subviews: subviews,
            columns: columns,
            columnWidth: columnWidth
        )
        let totalHeight = rowHeights.reduce(CGFloat.zero, +)
            + verticalSpacing * CGFloat(max(0, rowHeights.count - 1))

        return CGSize(width: availableWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else {
            return
        }

        let columns = columnCount(for: bounds.width)
        let columnWidth = widthPerColumn(availableWidth: bounds.width, columns: columns)
        let rowHeights = measuredRowHeights(
            subviews: subviews,
            columns: columns,
            columnWidth: columnWidth
        )

        var y = bounds.minY
        for rowIndex in 0..<rowHeights.count {
            let rowHeight = rowHeights[rowIndex]
            let rowStart = rowIndex * columns
            let rowEnd = min(rowStart + columns, subviews.count)

            for index in rowStart..<rowEnd {
                let column = index - rowStart
                let x = bounds.minX + CGFloat(column) * (columnWidth + horizontalSpacing)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: columnWidth, height: rowHeight)
                )
            }

            y += rowHeight + verticalSpacing
        }
    }

    private func columnCount(for availableWidth: CGFloat) -> Int {
        guard availableWidth > 0 else {
            return 1
        }

        return max(
            1,
            Int((availableWidth + horizontalSpacing) / (minimumColumnWidth + horizontalSpacing))
        )
    }

    private func widthPerColumn(availableWidth: CGFloat, columns: Int) -> CGFloat {
        let totalSpacing = horizontalSpacing * CGFloat(max(0, columns - 1))
        return max(0, (availableWidth - totalSpacing) / CGFloat(max(1, columns)))
    }

    private func measuredRowHeights(
        subviews: Subviews,
        columns: Int,
        columnWidth: CGFloat
    ) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { rowStart in
            let rowEnd = min(rowStart + columns, subviews.count)
            return (rowStart..<rowEnd).reduce(CGFloat.zero) { height, index in
                max(
                    height,
                    subviews[index].sizeThatFits(
                        ProposedViewSize(width: columnWidth, height: nil)
                    ).height
                )
            }
        }
    }
}

private struct SearchResultCardGroupView: View {
    let group: SearchResultFileGroup
    let query: String
    let selectedResult: SubtitleSearchResult?
    let onToggle: () -> Void
    let onOpenResult: (SubtitleSearchResult) -> Void
    let onResultAppear: (SubtitleSearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardGroupHeader(
                title: group.subtitleDisplayTitle,
                countText: resultCountText,
                isCollapsed: group.isCollapsed,
                isSelected: selectedResult?.subtitlePath == group.subtitlePath,
                onToggle: onToggle
            )

            if !group.isCollapsed {
                EqualHeightCardGridLayout(
                    minimumColumnWidth: SearchCardLayout.cardMinimumWidth,
                    horizontalSpacing: SearchCardLayout.cardHorizontalSpacing,
                    verticalSpacing: SearchCardLayout.cardVerticalSpacing
                ) {
                    ForEach(group.results, id: \.entryID) { result in
                        SearchResultCard(
                            result: result,
                            query: query,
                            isSelected: selectedResult?.entryID == result.entryID
                        )
                        .listRowAction {
                            onOpenResult(result)
                        }
                        .id(result.entryID)
                        .focusable(false)
                        .onAppear {
                            onResultAppear(result)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultCountText: String {
        "\(group.totalCount) \(group.totalCount == 1 ? "result" : "results")"
    }
}

private struct ShioriCardGroupView: View {
    let group: ShioriFileGroup
    let selectedShiori: Shiori?
    let onToggle: () -> Void
    let onOpenShiori: (Shiori) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardGroupHeader(
                title: group.subtitleDisplayTitle,
                countText: "\(group.totalCount) \(group.totalCount == 1 ? "shiori" : "shioris")",
                isCollapsed: group.isCollapsed,
                isSelected: selectedShiori?.subtitlePath == group.subtitlePath,
                onToggle: onToggle
            )

            if !group.isCollapsed {
                EqualHeightCardGridLayout(
                    minimumColumnWidth: SearchCardLayout.cardMinimumWidth,
                    horizontalSpacing: SearchCardLayout.cardHorizontalSpacing,
                    verticalSpacing: SearchCardLayout.cardVerticalSpacing
                ) {
                    ForEach(Array(group.shioris.enumerated()), id: \.element.id) { index, shiori in
                        ShioriCard(
                            shiori: shiori,
                            rank: index + 1,
                            isSelected: selectedShiori?.id == shiori.id
                        )
                        .listRowAction {
                            onOpenShiori(shiori)
                        }
                        .focusable(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CardGroupHeader: View {
    let title: String
    let countText: String
    let isCollapsed: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.16), value: isCollapsed)

                Text(displayTitleWithSoftWrapOpportunities(title))
                    .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.68))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(countText)
                    .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

private struct SearchResultCard: View {
    let result: SubtitleSearchResult
    let query: String
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        let textColor: Color = isSelected ? .white : Color.primary.opacity(0.88)
        let secondaryTextColor: Color = isSelected ? .white.opacity(0.82) : Color.primary.opacity(0.48)
        let highlightState: SearchHighlightState = isSelected
            ? .selected
            : (isHovered ? .hover : .default)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("#\(result.searchRank + 1)")
                    .font(.system(size: SearchTypography.bodySize, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .monospacedDigit()

                Spacer(minLength: 8)

                Text(formatTimestamp(result.startMilliseconds))
                    .font(.system(size: SearchTypography.bodySize, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(highlightedContent(
                        line,
                        query: query,
                        textColor: textColor,
                        state: highlightState
                    ))
                    .font(.system(size: SearchTypography.bodySize, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(nil)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(
            maxWidth: .infinity,
            minHeight: SearchCardLayout.cardMinHeight,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SearchCardLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: SearchCardLayout.cardCornerRadius)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(result.videoName), \(formatTimestamp(result.startMilliseconds))")
    }

    private var displayLines: [String] {
        subtitleDisplayLines(content: result.content, cueLines: result.cueLines)
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.accentColor
        }
        if isHovered {
            return Color.primary.opacity(0.075)
        }
        return Color.primary.opacity(0.045)
    }

    private var cardBorder: Color {
        if isSelected {
            return Color.clear
        }
        if isHovered {
            return Color.primary.opacity(0.07)
        }
        return Color.clear
    }
}

private struct ShioriCard: View {
    let shiori: Shiori
    let rank: Int
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        let textColor: Color = isSelected ? .white : Color.primary.opacity(0.88)
        let secondaryTextColor: Color = isSelected ? .white.opacity(0.82) : Color.primary.opacity(0.48)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("#\(rank)")
                    .font(.system(size: SearchTypography.bodySize, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .monospacedDigit()

                Spacer(minLength: 8)

                Text(formatTimestamp(shiori.startMilliseconds))
                    .font(.system(size: SearchTypography.bodySize, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: SearchTypography.bodySize, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(nil)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(
            maxWidth: .infinity,
            minHeight: SearchCardLayout.cardMinHeight,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SearchCardLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: SearchCardLayout.cardCornerRadius)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(shiori.videoName), \(formatTimestamp(shiori.startMilliseconds))")
    }

    private var displayLines: [String] {
        subtitleDisplayLines(content: shiori.content, cueLines: shiori.cueLines)
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.accentColor
        }
        if isHovered {
            return Color.primary.opacity(0.075)
        }
        return Color.primary.opacity(0.045)
    }

    private var cardBorder: Color {
        if isSelected {
            return Color.clear
        }
        if isHovered {
            return Color.primary.opacity(0.07)
        }
        return Color.clear
    }
}

private struct SearchResultGroupHeader: View {
    let group: SearchResultFileGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Text(headerText)
            .font(.system(size: SearchTypography.groupHeaderSize))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 7)
            .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
            .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowAction(onToggle)
        .focusable(false)
    }

    private var headerText: AttributedString {
        var displayTitle = AttributedString(displayTitleWithSoftWrapOpportunities(group.subtitleDisplayTitle))
        displayTitle.foregroundColor = isSelected ? .primary : Color.primary.opacity(0.76)

        var count = AttributedString("  \(resultCountText)")
        count.foregroundColor = Color.secondary

        displayTitle.append(count)
        return displayTitle
    }

    private var resultCountText: String {
        "\(group.totalCount) \(group.totalCount == 1 ? "result" : "results")"
    }
}

private struct SearchResultGroupView: View {
    let group: SearchResultFileGroup
    let query: String
    let selectedResult: SubtitleSearchResult?
    let showsThumbnails: Bool
    let onToggle: () -> Void
    let onOpenResult: (SubtitleSearchResult) -> Void
    let onResultAppear: (SubtitleSearchResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SearchResultGroupHeader(
                group: group,
                isSelected: selectedResult?.subtitlePath == group.subtitlePath,
                onToggle: onToggle
            )

            if !group.isCollapsed {
                ForEach(group.results, id: \.entryID) { result in
                    let isSelected = selectedResult?.entryID == result.entryID

                    SearchResultRow(
                        result: result,
                        query: query,
                        isSelected: isSelected,
                        showsThumbnail: showsThumbnails
                    )
                    .listRowAction {
                        onOpenResult(result)
                    }
                    .id(result.entryID)
                    .focusable(false)
                    .onAppear {
                        onResultAppear(result)
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            SearchResultGroupRail(
                isCollapsed: group.isCollapsed,
                showsLine: !group.isCollapsed && !group.results.isEmpty,
                onToggle: onToggle
            )
        }
    }
}

private struct ShioriGroupHeader: View {
    let group: ShioriFileGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Text(headerText)
            .font(.system(size: SearchTypography.groupHeaderSize))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 7)
            .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
            .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowAction(onToggle)
        .focusable(false)
    }

    private var headerText: AttributedString {
        var displayTitle = AttributedString(displayTitleWithSoftWrapOpportunities(group.subtitleDisplayTitle))
        displayTitle.foregroundColor = isSelected ? .primary : Color.primary.opacity(0.76)

        var count = AttributedString("  \(shioriCountText)")
        count.foregroundColor = Color.secondary

        displayTitle.append(count)
        return displayTitle
    }

    private var shioriCountText: String {
        "\(group.totalCount) \(group.totalCount == 1 ? "shiori" : "shioris")"
    }
}

private struct ShioriGroupView: View {
    let group: ShioriFileGroup
    let selectedShiori: Shiori?
    let onToggle: () -> Void
    let onOpenShiori: (Shiori) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ShioriGroupHeader(
                group: group,
                isSelected: selectedShiori?.subtitlePath == group.subtitlePath,
                onToggle: onToggle
            )

            if !group.isCollapsed {
                ForEach(group.shioris) { shiori in
                    ShioriRowView(
                        shiori: shiori,
                        isSelected: selectedShiori?.id == shiori.id
                    )
                    .listRowAction {
                        onOpenShiori(shiori)
                    }
                    .focusable(false)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            SearchResultGroupRail(
                isCollapsed: group.isCollapsed,
                showsLine: !group.isCollapsed && !group.shioris.isEmpty,
                onToggle: onToggle
            )
        }
    }
}

private struct ShioriRowView: View {
    let shiori: Shiori
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        let rowTextColor: Color = isSelected ? .white : Color.primary.opacity(0.86)
        let rowBackgroundColor: Color = if isSelected {
            Color.accentColor
        } else if isHovered {
            Color.primary.opacity(0.06)
        } else {
            Color.clear
        }

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: SearchTypography.bodySize))
                        .foregroundStyle(rowTextColor)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, SearchLayout.resultTextLeadingPadding)
            .padding(.trailing, SearchLayout.resultTextHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
            .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var displayLines: [String] {
        shiori.cueLines.isEmpty ? [shiori.content] : shiori.cueLines
    }
}

private struct SearchResultGroupRail: View {
    let isCollapsed: Bool
    let showsLine: Bool
    let onToggle: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let lineTop = SearchLayout.groupRailChevronTopPadding
                + SearchLayout.groupRailChevronSize
                + SearchLayout.groupRailLineTopSpacing
            let lineHeight = max(CGFloat.zero, geometry.size.height - lineTop)
            let lineX = SearchLayout.resultOuterHorizontalPadding
                + SearchLayout.groupDisclosureWidth / 2

            ZStack(alignment: .topLeading) {
                if showsLine && lineHeight > 0 {
                    Rectangle()
                        .fill(.tertiary)
                        .opacity(0.55)
                        .frame(width: SearchLayout.groupRailLineWidth, height: lineHeight)
                        .offset(
                            x: lineX - SearchLayout.groupRailLineWidth / 2,
                            y: lineTop
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: SearchLayout.groupRailChevronSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: SearchLayout.groupDisclosureWidth,
                        height: SearchLayout.groupRailChevronSize,
                        alignment: .center
                    )
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.16), value: isCollapsed)
                    .listRowAction(onToggle)
                    .accessibilityLabel(isCollapsed ? "Expand group" : "Collapse group")
                .focusable(false)
                .offset(
                    x: SearchLayout.resultOuterHorizontalPadding,
                    y: SearchLayout.groupRailChevronTopPadding
                )
            }
        }
        .frame(width: SearchLayout.resultSelectionLeadingPadding)
    }
}

private struct SearchResultRow: View {
    let result: SubtitleSearchResult
    let query: String
    let isSelected: Bool
    let showsThumbnail: Bool
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?
    @State private var isThumbnailFailed = false

    var body: some View {
        if showsThumbnail {
            rowContent
                .task(id: result.entryID) {
                    await loadThumbnail()
                }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        let rowTextColor: Color = isSelected ? .white : Color.primary.opacity(0.86)
        let rowBackgroundColor: Color = if isSelected {
            Color.accentColor
        } else if isHovered {
            Color.primary.opacity(0.06)
        } else {
            Color.clear
        }
        let highlightState: SearchHighlightState = isSelected
            ? .selected
            : (isHovered ? .hover : .default)

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                if showsThumbnail {
                    thumbnailView
                }

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                        Text(highlightedContent(
                            line,
                            query: query,
                            textColor: rowTextColor,
                            state: highlightState
                        ))
                        .font(.system(size: SearchTypography.bodySize))
                        .foregroundStyle(rowTextColor)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, SearchLayout.resultTextLeadingPadding)
            .padding(.trailing, SearchLayout.resultTextHorizontalPadding)
            .background(rowBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
            .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private func loadThumbnail() async {
        let attrs = try? FileManager.default.attributesOfItem(atPath: result.videoPath)
        let fileSize = attrs?[.size] as? Int64
        let modifiedAt = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970
        let request = ThumbnailRequest(
            videoPath: result.videoPath,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            timestampMilliseconds: (result.startMilliseconds + result.endMilliseconds) / 2,
            priority: result.searchRank
        )
        let cacheKey = await ThumbnailCache.shared.cacheKey(for: request)
        if let imageData = await ThumbnailGenerator.shared.generate(request: request, cacheKey: cacheKey) {
            if !Task.isCancelled {
                thumbnailImage = NSImage(data: imageData)
            }
        } else if !Task.isCancelled {
            isThumbnailFailed = true
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isThumbnailFailed {
                VStack {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.1))
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
            }
        }
        .frame(width: 160, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 6)
    }

    private var displayLines: [String] {
        let lines = result.cueLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [result.content] : lines
    }
}

enum SearchHighlightState {
    case `default`
    case hover
    case selected
}

enum SearchHighlightTokens {
    static let `default` = Color(red: 1.0, green: 224.0 / 255.0, blue: 102.0 / 255.0)
    static let hover = Color(red: 1.0, green: 203.0 / 255.0, blue: 31.0 / 255.0)
    static let onSelected = Color.white.opacity(0.30)
}

private enum SearchTypography {
    static let groupHeaderSize: CGFloat = 13
    static let bodySize: CGFloat = 14
    static let detailSize: CGFloat = 12
}

private enum SearchLayout {
    static let resultOuterHorizontalPadding: CGFloat = 12
    static let groupDisclosureWidth: CGFloat = 16
    static let groupRailChevronSize: CGFloat = 10
    static let groupRailChevronTopPadding: CGFloat = 9
    static let groupRailLineTopSpacing: CGFloat = 8
    static let groupRailLineWidth: CGFloat = 1.5
    static let resultContentLeadingOffset: CGFloat = 5
    static let resultSelectionLeadingPadding: CGFloat = resultOuterHorizontalPadding + groupDisclosureWidth + resultContentLeadingOffset
    static let resultTextHorizontalPadding: CGFloat = 10
    static let resultTextLeadingPadding: CGFloat = resultTextHorizontalPadding
}

private func displayTitleWithSoftWrapOpportunities(_ displayTitle: String) -> String {
    let zeroWidthSpace = "\u{200B}"
    let softBreakCharacters: Set<Character> = ["]", ".", "_", "-"]
    var wrapped = ""

    for character in displayTitle {
        wrapped.append(character)
        if softBreakCharacters.contains(character) {
            wrapped.append(zeroWidthSpace)
        }
    }

    return wrapped
}

private func highlightedContent(
    _ content: String,
    query: String,
    textColor: Color,
    state: SearchHighlightState
) -> AttributedString {
    var highlighted = AttributedString(content)
    let terms = highlightTerms(from: query)

    let bg: Color
    switch state {
    case .default:
        bg = SearchHighlightTokens.default
    case .hover:
        bg = SearchHighlightTokens.hover
    case .selected:
        bg = SearchHighlightTokens.onSelected
    }

    for term in terms {
        var searchRange = content.startIndex..<content.endIndex

        while let match = content.range(
            of: term,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            if let lowerBound = AttributedString.Index(match.lowerBound, within: highlighted),
               let upperBound = AttributedString.Index(match.upperBound, within: highlighted) {
                highlighted[lowerBound..<upperBound].inlinePresentationIntent = .stronglyEmphasized
                highlighted[lowerBound..<upperBound].backgroundColor = bg
                highlighted[lowerBound..<upperBound].foregroundColor = textColor
            }

            guard match.upperBound < content.endIndex else {
                break
            }

            searchRange = match.upperBound..<content.endIndex
        }
    }

    return highlighted
}

private func highlightTerms(from query: String) -> [String] {
    Array(
        Set(
            query.unicodeScalars
                .split(whereSeparator: { !$0.properties.isAlphabetic && $0.properties.numericType == nil })
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    )
}

private func formatTimestamp(_ milliseconds: Int) -> String {
    let totalSeconds = milliseconds / 1_000
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

private func subtitleDisplayLines(content: String, cueLines: [String]) -> [String] {
    let lines = (cueLines.isEmpty ? content.components(separatedBy: .newlines) : cueLines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    return lines.isEmpty ? [content] : lines
}
