import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var shiori: ShioriStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var playback: PlaybackStore
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
                case .shiori:
                    shioriPanel
                case .recentWatching:
                    WorkbenchTestRecentWatchingView()
                case .testLibrary:
                    WorkbenchTestLibraryView()
                case .search:
                    workbenchSearchSurface
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
                    // Content padding unified with the card search surface;
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
                            },
                            onExportToAnki: {
                                layoutState.clearSearchFocus()
                                appState.exportShioriGroupToAnki(group)
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

    private var playbackSurface: some View {
        PlaybackView(
            player: appState.playbackPlayer,
            viewModel: playback.playbackViewModel,
            onSurfaceTap: {
                layoutState.clearSearchFocus()
                appState.togglePlaybackFromUser()
            }
        )
    }

    private var workbenchSearchSurface: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            WorkbenchTestSearchView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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






enum SearchCardLayout {
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

struct EqualHeightCardGridLayout: Layout {
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

enum SearchTypography {
    static let groupHeaderSize: CGFloat = 13
    static let bodySize: CGFloat = 14
    static let detailSize: CGFloat = 12
}

func displayTitleWithSoftWrapOpportunities(_ displayTitle: String) -> String {
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
    state: SearchHighlightState,
    highlightBackgroundColor: Color? = nil
) -> AttributedString {
    var highlighted = AttributedString(content)
    let terms = highlightTerms(from: query)

    let bg: Color
    if let customBg = highlightBackgroundColor {
        bg = customBg
    } else {
        switch state {
        case .default:
            bg = SearchHighlightTokens.default
        case .hover:
            bg = SearchHighlightTokens.hover
        case .selected:
            bg = SearchHighlightTokens.onSelected
        }
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
