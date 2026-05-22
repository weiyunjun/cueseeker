import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var shiori: ShioriStore
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.colorScheme) private var colorScheme
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
                        PlaybackPageView(
                            playbackSurface: AnyView(playbackSurface),
                            appState: appState,
                            onClose: {
                                layoutState.clearSearchFocus()
                                appState.stopPlayback()
                            }
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
            .onChange(of: library.libraryPresentationRevision) { _ in
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

                if indexing.selectedFolders.isEmpty {
                    InfoPageStateView(state: .libraryNoLibrary)
                    .font(.system(size: SearchTypography.bodySize))
                } else if case .loading = library.libraryStatus, library.libraryVideos.isEmpty {
                    InfoPageStateView(state: .libraryLoading)
                    .font(.system(size: SearchTypography.bodySize))
                    .overlay {
                        ProgressView()
                            .offset(y: 72)
                    }
                } else if case .failed(let message) = library.libraryStatus {
                    InfoPageStateView(state: .libraryFailed(message))
                    .font(.system(size: SearchTypography.bodySize))
                } else if library.libraryVideos.isEmpty {
                    InfoPageStateView(state: .libraryNoVideos)
                    .font(.system(size: SearchTypography.bodySize))
                } else {
                    libraryList
                }

                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, AppShellLayout.contentTopPadding)
            .background(LiquidGlassTokens(colorScheme: colorScheme).pageBackground)
            .background(LayoutPerformanceProbe(name: "SearchView.libraryPanel.layout"))
            .task {
                appState.hydrateLibraryAsync()
            }
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
        let rowCount = library.libraryFolderGroups.reduce(0) { $0 + $1.videos.count }
        UIInvalidationProbe.count(
            "UI.LibraryRows.rendered",
            details: "groups=\(library.libraryFolderGroups.count) rows=\(rowCount)"
        )

        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    // Content padding unified with Search (cardResultsList);
                    // groups carry their own vertical rhythm so LazyVStack
                    // spacing is 0 (P5.3 Confirmed Pixel Spec, owner decision 1).
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(library.libraryFolderGroups) { group in
                            let isCollapsed = collapsedLibraryFolderPaths.contains(group.folderPath)
                            LibraryFolderGroupView(
                                group: group,
                                isCollapsed: isCollapsed,
                                selectedLibraryVideoPath: library.selectedLibraryVideo?.videoPath,
                                onToggle: {
                                    layoutState.clearSearchFocus()
                                    toggleLibraryFolderGroup(group.folderPath, proxy: proxy)
                                },
                                onOpenVideo: { video in
                                    layoutState.clearSearchFocus()
                                    appState.openLibraryVideo(video)
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
    }

    private func resetCollapsedLibraryFolders() {
        collapsedLibraryFolderPaths = Set(library.libraryFolderGroups.map(\.id))
    }

    private func toggleLibraryFolderGroup(_ folderPath: String, proxy: ScrollViewProxy) {
        let wasCollapsed = collapsedLibraryFolderPaths.contains(folderPath)
        UIInvalidationProbe.mark(
            "ACTION UI.LibraryFolder.toggled",
            details: "collapsedBefore=\(wasCollapsed)"
        )
        if wasCollapsed {
            collapsedLibraryFolderPaths.remove(folderPath)
            if let selectedVideoPath = library.selectedLibraryVideo?.videoPath,
               let group = library.libraryFolderGroups.first(where: { $0.folderPath == folderPath }),
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

                    if shiori.shioris.isEmpty {
                        InfoPageStateView(state: .shioriEmpty)
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
            .background(LiquidGlassTokens(colorScheme: colorScheme).pageBackground)
            .background(LayoutPerformanceProbe(name: "SearchView.shioriPanel.layout"))
            .task {
                appState.hydrateShiorisAsync()
            }
        }
    }

    private var shioriHeader: some View {
        HStack(spacing: 12) {
            Text(shioriSummaryText)
                .font(.system(size: SearchTypography.detailSize))
                .foregroundStyle(.secondary)

            Spacer()

            if shiori.hasShioriFileGroups {
                Button {
                    layoutState.clearSearchFocus()
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
        "\(shiori.shioriCount) shioris in \(shiori.shioriFileCount) files"
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
            details: "groups=\(shiori.shioriFileGroups.count) rows=\(shiori.shioriCount)"
        )

        return GeometryReader { geo in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SearchCardLayout.groupSpacing) {
                    ForEach(shiori.shioriFileGroups) { group in
                        ShioriCardGroupView(
                            group: group,
                            onToggle: {
                                layoutState.clearSearchFocus()
                                appState.toggleShioriGroup(group.subtitlePath)
                            },
                            onOpenShiori: { shiori in
                                layoutState.clearSearchFocus()
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
                            onToggle: {
                                layoutState.clearSearchFocus()
                                appState.toggleSearchResultGroup(group.subtitlePath)
                            },
                            onOpenResult: { result in
                                layoutState.clearSearchFocus()
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
            onSurfaceTap: {
                layoutState.clearSearchFocus()
                appState.togglePlaybackFromUser()
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
                        layoutState.clearSearchFocus()
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
                InfoPageStateView(state: .searchNoQuery)
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if case .searching = appState.searchStatus, appState.searchResults.isEmpty {
                InfoPageStateView(state: .searching)
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    ProgressView()
                        .offset(y: 72)
                }
            } else if case .failed(let message) = appState.searchStatus, appState.searchResults.isEmpty {
                InfoPageStateView(state: .searchFailed(message))
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.searchResults.isEmpty {
                InfoPageStateView(state: .searchNoResults)
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cardResultsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LiquidGlassTokens(colorScheme: colorScheme).pageBackground)
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
        // v6 `.library-group`: top/bottom padding + a bottom margin, and
        // intentionally NO bottom hairline (owner decision 3, a deliberate
        // surface difference vs the Search `.group`).
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
        .padding(.top, LibraryLayout.groupTopPadding)
        .padding(.bottom, LibraryLayout.groupBottomPadding + LibraryLayout.groupBottomMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // v6 `.library-group-header`: align-items flex-start, gap 10, padding
        // 8 8 8 4, max width 720, radius 7 + subtle hover; shared chevron in a
        // 16pt box (text-3, 0°/90° over 160ms) with a 2pt top inset.
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: LibraryLayout.folderHeaderGap) {
                Image(systemName: "chevron.right")
                    .font(.system(size: LibraryLayout.chevronGlyph, weight: .semibold))
                    .foregroundStyle(tokens.text3)
                    .frame(
                        width: LibraryLayout.chevronBox,
                        height: LibraryLayout.chevronBox,
                        alignment: .center
                    )
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.16), value: isCollapsed)
                    .padding(.top, LibraryLayout.chevronTopInset)

                VStack(alignment: .leading, spacing: LibraryLayout.headingLineGap) {
                    Text(folderTitle)
                        .font(.system(size: LibraryLayout.titleSize, weight: .bold))
                        .foregroundStyle(tokens.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitleText)
                        .font(.system(size: LibraryLayout.countSize))
                        .foregroundStyle(tokens.text3)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(LibraryLayout.folderHeaderInsets)
            .frame(maxWidth: LibraryLayout.folderHeaderMaxWidth, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: LibraryLayout.folderHeaderCornerRadius,
                    style: .continuous
                )
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
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

    var body: some View {
        // v6 `.library-episode-grid`: a wrapping flow (not a fixed-column
        // grid) with gap 10, left-indented 30 to express folder→episode
        // hierarchy. A flow honors the content-driven episode width so a long
        // rank (`EP120`) widens its own card instead of forcing a uniform
        // column (owner decision 2).
        WrapFlowLayout(
            horizontalSpacing: LibraryLayout.gridGap,
            verticalSpacing: LibraryLayout.gridGap
        ) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                LibraryEpisodeButton(
                    rank: index + 1,
                    isPlaying: row.video.videoPath == selectedLibraryVideoPath,
                    action: { onOpenVideo(row.video) }
                )
                .id(row.video.videoPath)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, LibraryLayout.gridLeadingIndent)
        .padding(.top, LibraryLayout.gridTopPadding)
        .padding(.bottom, LibraryLayout.gridBottomPadding)
    }
}

private struct LibraryEpisodeButton: View {
    let rank: Int
    let isPlaying: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(episodeLabel)
                .font(.system(size: LibraryLayout.episodeLabelSize, weight: .bold))
                .monospacedDigit()
        }
        .buttonStyle(
            LibraryEpisodeButtonStyle(
                isPlaying: isPlaying,
                isHovered: isHovered,
                tokens: LiquidGlassTokens(colorScheme: colorScheme)
            )
        )
        .onHover { isHovered = $0 }
        .focusable(false)
        .accessibilityLabel("Episode \(rank)")
    }

    // EP01-style compact rank label (finding H / doc 12 §7.2). `%02d` keeps
    // `EP01` at the 66pt minimum width while `EP120` widens its own card.
    private var episodeLabel: String {
        String(format: "EP%02d", rank)
    }
}

/// Library episode tile: the shared `LiquidGlassTokens` card skin drawn
/// directly (doc 11 §5). The Library-launched "playing" state is the doc 12
/// §7.2 mandated indicator (white-elevated fill + 2pt accent outline, no
/// shadow), NOT the shared selectable-card selected treatment.
private struct LibraryEpisodeButtonStyle: ButtonStyle {
    let isPlaying: Bool
    let isHovered: Bool
    let tokens: LiquidGlassTokens

    func makeBody(configuration: Configuration) -> some View {
        let lifted = isHovered && !isPlaying
        let shape = RoundedRectangle(
            cornerRadius: LibraryLayout.episodeCornerRadius,
            style: .continuous
        )

        return configuration.label
            .foregroundStyle(isPlaying ? tokens.textOnSelectedCard : tokens.text)
            .padding(.horizontal, LibraryLayout.episodeHorizontalPadding)
            .frame(minWidth: LibraryLayout.episodeMinWidth)
            .frame(height: LibraryLayout.episodeHeight)
            .background {
                shape
                    .fill(
                        isPlaying
                            ? tokens.playingIndicatorFill
                            : (lifted ? tokens.cardHoverFill : tokens.cardFill)
                    )
                    .overlay {
                        shape.strokeBorder(
                            isPlaying
                                ? tokens.selectedRing
                                : (lifted ? tokens.cardHoverHairline : tokens.cardHairline),
                            lineWidth: isPlaying ? 2 : 0.5
                        )
                    }
                    .shadow(
                        color: isPlaying
                            ? .clear
                            : (lifted ? tokens.cardHoverShadow : tokens.cardShadow),
                        radius: isPlaying ? 0 : (lifted ? 7 : 1.5),
                        x: 0,
                        y: isPlaying ? 0 : (lifted ? 4 : 1)
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Wrapping flow layout for the Library episode grid — places content-width
/// children left to right, wrapping to the next line at the container width.
private struct WrapFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + horizontalSpacing + size.width > maxWidth {
                totalHeight += rowHeight + verticalSpacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? horizontalSpacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        widestRow = max(widestRow, rowWidth)
        return CGSize(
            width: maxWidth.isFinite ? maxWidth : widestRow,
            height: totalHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private enum LibraryLayout {
    static let groupTopPadding: CGFloat = 12
    static let groupBottomPadding: CGFloat = 10
    static let groupBottomMargin: CGFloat = 6
    static let folderHeaderMaxWidth: CGFloat = 720
    static let folderHeaderInsets = EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 8)
    static let folderHeaderCornerRadius: CGFloat = 7
    static let folderHeaderGap: CGFloat = 10
    static let chevronBox: CGFloat = 16
    static let chevronGlyph: CGFloat = 10
    static let chevronTopInset: CGFloat = 2
    static let headingLineGap: CGFloat = 2
    static let titleSize: CGFloat = 13.5
    static let countSize: CGFloat = 12
    static let episodeMinWidth: CGFloat = 66
    static let episodeHeight: CGFloat = 42
    static let episodeHorizontalPadding: CGFloat = 14
    static let episodeCornerRadius: CGFloat = 8
    static let episodeLabelSize: CGFloat = 12.5
    static let gridGap: CGFloat = 10
    static let gridLeadingIndent: CGFloat = 30
    static let gridTopPadding: CGFloat = 8
    static let gridBottomPadding: CGFloat = 12
}

private enum SearchCardLayout {
    static let contentHorizontalPadding: CGFloat = 24
    static let contentTopPadding: CGFloat = 4
    static let contentBottomPadding: CGFloat = 28
    static let groupSpacing: CGFloat = 26
    static let cardMinimumWidth: CGFloat = 280
    static let cardHorizontalSpacing: CGFloat = 10
    static let cardVerticalSpacing: CGFloat = 10
    static let cardCornerRadius: CGFloat = 10
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
    let onToggle: () -> Void
    let onOpenResult: (SubtitleSearchResult) -> Void
    let onResultAppear: (SubtitleSearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardGroupHeader(
                title: group.subtitleDisplayTitle,
                countText: resultCountText,
                isCollapsed: group.isCollapsed,
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
                            onOpen: { onOpenResult(result) }
                        )
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
    let onToggle: () -> Void
    let onOpenShiori: (Shiori) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardGroupHeader(
                title: group.subtitleDisplayTitle,
                countText: "\(group.totalCount) \(group.totalCount == 1 ? "shiori" : "shioris")",
                isCollapsed: group.isCollapsed,
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
                            onOpen: { onOpenShiori(shiori) }
                        )
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
    let onToggle: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tokens.text3)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.16), value: isCollapsed)

                Text(displayTitleWithSoftWrapOpportunities(title))
                    .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(tokens.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(countText)
                    .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                    .foregroundStyle(tokens.text3)
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
    let onOpen: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Main-page cards retain no playback selection visual (doc 12 §6.4,
        // doc 11 §5/§7; audit finding F). Surface is the shared token-driven
        // LiquidGlassSelectableCard; content / highlight / equal-height are
        // unchanged from before P5.2.
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)
        let textColor = tokens.text.opacity(0.88)
        let secondaryTextColor = tokens.text3
        let highlightState: SearchHighlightState = isHovered ? .hover : .default

        LiquidGlassSelectableCard(
            cornerRadius: SearchCardLayout.cardCornerRadius,
            action: onOpen
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("#\(result.searchRank + 1)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
                        .monospacedDigit()

                    Spacer(minLength: 8)

                    Text(formatTimestamp(result.startMilliseconds))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
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
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(nil)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(
                maxWidth: .infinity,
                minHeight: SearchCardLayout.cardMinHeight,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(result.videoName), \(formatTimestamp(result.startMilliseconds))")
    }

    private var displayLines: [String] {
        subtitleDisplayLines(content: result.content, cueLines: result.cueLines)
    }
}

private struct ShioriCard: View {
    let shiori: Shiori
    let rank: Int
    let onOpen: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Shiori has no `.shiori-card` overrides in v6: this is the P5.2-B
        // `.result-card` spec verbatim (the shared LiquidGlassSelectableCard),
        // so P5.4-B introduces no new pixel values. Main-page cards retain no
        // playback selection visual (doc 12 §6.4, doc 11 §5/§7; finding F);
        // the vestigial `isSelected` plumbing is excised in P5.4-2.
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)
        let textColor = tokens.text.opacity(0.88)
        let secondaryTextColor = tokens.text3

        LiquidGlassSelectableCard(
            cornerRadius: SearchCardLayout.cardCornerRadius,
            action: onOpen
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("#\(rank)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
                        .monospacedDigit()

                    Spacer(minLength: 8)

                    Text(formatTimestamp(shiori.startMilliseconds))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(textColor)
                            .lineLimit(nil)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(
                maxWidth: .infinity,
                minHeight: SearchCardLayout.cardMinHeight,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
        .accessibilityLabel("\(shiori.videoName), \(formatTimestamp(shiori.startMilliseconds))")
    }

    private var displayLines: [String] {
        subtitleDisplayLines(content: shiori.content, cueLines: shiori.cueLines)
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

func highlightedContent(
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

func formatTimestamp(_ milliseconds: Int) -> String {
    let totalSeconds = milliseconds / 1_000
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

func subtitleDisplayLines(content: String, cueLines: [String]) -> [String] {
    let lines = (cueLines.isEmpty ? content.components(separatedBy: .newlines) : cueLines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    return lines.isEmpty ? [content] : lines
}
