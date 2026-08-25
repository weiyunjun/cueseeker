import CueSeekerCore
import SwiftUI

struct PlaybackCommandPanel: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
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
                                allowsHover: pointerVisibility.isVisible,
                                onSelect: {
                                    appState
                                        .selectPlaybackCommandPanelItem(at: $0)
                                },
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
                                onSelect: {
                                    appState
                                        .selectPlaybackCommandPanelItem(at: $0)
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
                                onSelect: {
                                    appState
                                        .selectPlaybackCommandPanelItem(at: $0)
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
                    // The panel reuses grids written for the workbench page.
                    // They must answer for this layer, not for the page the
                    // panel is covering.
                    .interfaceLayer(.commandPanel)
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
    static let footerHeight = PlaybackCueFooterMetrics.height
}

private struct PlaybackCommandPanelRoot: View {
    let presentation: PlaybackCommandPanelPresentation
    let allowsHover: Bool
    let onSelect: (Int) -> Void
    @Binding var query: String
    let onSubmitSearch: () -> Bool
    let onOpenPage: (PlaybackCommandPanelPage) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            WorkbenchSearchField(
                placeholder: L("sidebar.search"),
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
                        title: L("sidebar.search"),
                        detail: query,
                        isSelected: presentation.selectedOrdinal == 0,
                        allowsHover: allowsHover,
                        onHoverChange: { hoverChanged($0, ordinal: 0) }
                    ) {
                        _ = onSubmitSearch()
                    }
                }

                PlaybackCommandPanelRootRow(
                    systemImage: "play.rectangle",
                    title: L("sidebar.recent_videos"),
                    detail: nil,
                    isSelected: presentation.selectedOrdinal
                        == recentVideosOrdinal,
                    allowsHover: allowsHover,
                    onHoverChange: {
                        hoverChanged($0, ordinal: recentVideosOrdinal)
                    }
                ) {
                    _ = onOpenPage(.recentVideos)
                }

                PlaybackCommandPanelRootRow(
                    systemImage: "bookmark",
                    title: L("sidebar.recent_shioris"),
                    detail: nil,
                    isSelected: presentation.selectedOrdinal
                        == recentShiorisOrdinal,
                    allowsHover: allowsHover,
                    onHoverChange: {
                        hoverChanged($0, ordinal: recentShiorisOrdinal)
                    }
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

    private var recentVideosOrdinal: Int {
        trimmedQuery.isEmpty ? 0 : 1
    }

    private var recentShiorisOrdinal: Int {
        trimmedQuery.isEmpty ? 1 : 2
    }

    private func hoverChanged(_ isHovered: Bool, ordinal: Int) {
        guard isHovered else {
            return
        }
        onSelect(ordinal)
    }
}

private struct PlaybackCommandPanelRootRow: View {
    let systemImage: String
    let title: String
    let detail: String?
    let isSelected: Bool
    let allowsHover: Bool
    let onHoverChange: (Bool) -> Void
    let action: () -> Void
    @State private var isHovered = false

    /// Hover only counts while the pointer is visible, so keyboard navigation
    /// cannot be pulled back by a pointer resting on another row.
    private var isHoverActive: Bool {
        allowsHover && isHovered
    }

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
        .onPointerHover { isHovered = $0 }
        .onChange(of: isHoverActive) { isActive in
            onHoverChange(isActive)
        }
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
                .accessibilityLabel(L("playback.back"))

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
                        viewportSize: geometry.size,
                        reducesMotion: reduceMotion,
                        onCommitSelection: onCommitSelection,
                        onCopySelectedText: onCopySelectedText,
                        onSearchSelectedText: onSearchSelectedText
                    )
                }
            }

            PlaybackCueFooter(
                status: resultStatus,
                actionTitle: L("playback.play")
            )
            .padding(
                .horizontal,
                PlaybackCommandPanelMetrics.contentInset
            )
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
        PlaybackCueFooterStatus.searchResults(
            totalCount: resultTotalCount,
            previewLimit: PlaybackCommandPanelPresentation.previewLimit,
            hasMoreResults: searchStore.hasMoreSearchResults
        )
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
    @Environment(\.interfaceLayers) private var interfaceLayers
    let showsCueGroup: Bool
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
            onKeyboardMotionChanged: { _ in },
            interfaceLayers: interfaceLayers,
            menuOwner: .commandPanel
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

struct PlaybackCommandPanelRecentVideos: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var libraryStore: LibraryStore
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onGridLayoutChange: (Int, [String: CGRect]) -> Void
    let onSelect: (Int) -> Void
    let onOpen: (Int) -> Void

    private let coordinateSpaceName =
        "playback-command-panel-recent-videos-scroll"
    @State private var itemFramesByID: [String: CGRect] = [:]
    /// The page keeps navigating with its own ordinal; this owns which card is
    /// lit and decides when the pointer may move it.
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: true
    )

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
                title: L("sidebar.recent_videos"),
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
                            highlight: highlight,
                            itemFrameCoordinateSpace: coordinateSpaceName,
                            onItemFramesChange: { frames in
                                itemFramesByID = frames
                                onGridLayoutChange(columnCount, frames)
                            }
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
                    .task(id: selectedItemID) {
                        await Task.yield()
                        guard !Task.isCancelled,
                              let selectedItemID,
                              let anchor = Self.scrollAnchor(
                                  for: selectedItemID,
                                  orderedItemIDs: items.map(\.id),
                                  itemFramesByID: itemFramesByID,
                                  viewportHeight: geometry.size.height
                              )
                        else {
                            return
                        }
                        proxy.scrollTo(selectedItemID, anchor: anchor)
                    }
                }
            }

            PlaybackCommandPanelFooter(
                status: L("playback.video_count", libraryStore.testRecentWatchingItems.count),
                showsHorizontalNavigation: true
            )
        }
        .cardHighlightFreeze(highlight)
        .onAppear {
            highlight.adopt = { adoptedID in
                guard let adoptedID,
                      let ordinal = items.firstIndex(where: {
                          $0.id == adoptedID
                      })
                else {
                    return
                }
                onSelect(ordinal)
            }
            highlight.setCurrent(selectedItemID)
            onSynchronize()
        }
        .onChange(of: selectedItemID) { itemID in
            highlight.setCurrent(itemID)
        }
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

    static func scrollAnchor(
        for itemID: String,
        orderedItemIDs: [String],
        itemFramesByID: [String: CGRect],
        viewportHeight: CGFloat
    ) -> UnitPoint? {
        if let frame = itemFramesByID[itemID] {
            if frame.minY < 0 {
                return .top
            }
            if frame.maxY > viewportHeight {
                return .bottom
            }
            return nil
        }

        guard let selectedOrdinal = orderedItemIDs.firstIndex(of: itemID) else {
            return nil
        }
        let measuredOrdinals = itemFramesByID.keys.compactMap { measuredID in
            orderedItemIDs.firstIndex(of: measuredID)
        }
        if let firstMeasuredOrdinal = measuredOrdinals.min(),
           selectedOrdinal < firstMeasuredOrdinal {
            return .top
        }
        if let lastMeasuredOrdinal = measuredOrdinals.max(),
           selectedOrdinal > lastMeasuredOrdinal {
            return .bottom
        }
        return nil
    }
}

private struct PlaybackCommandPanelRecentShioris: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var shioriStore: ShioriStore
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onSelect: (Int) -> Void
    let onOpen: (Int) -> Void

    /// The row the pointer moved the selection onto. It is already on screen,
    /// so that change must not scroll the list under the cursor.
    @State private var pointerSelectedItemID: Int64?
    /// The page keeps navigating with its own ordinal; this owns which card is
    /// lit and decides when the pointer may move it.
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: true
    )

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
                title: L("sidebar.recent_shioris"),
                onBack: onBack
            )

            ScrollViewReader { proxy in
                WorkbenchScrollView {
                    RecentShioriResumeList(
                        summaries: summaries,
                        highlight: highlight
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
                    guard let selectedItemID,
                          selectedItemID != pointerSelectedItemID
                    else {
                        return
                    }
                    proxy.scrollTo(selectedItemID)
                }
            }

            PlaybackCommandPanelFooter(
                status: L("playback.shiori_count", shioriStore.recentListSummaries.count)
            )
        }
        .cardHighlightFreeze(highlight)
        .onAppear {
            highlight.adopt = { adoptedID in
                guard let adoptedID,
                      let ordinal = summaries.firstIndex(where: {
                          String($0.id) == adoptedID
                      })
                else {
                    return
                }
                pointerSelectedItemID = summaries[ordinal].id
                onSelect(ordinal)
            }
            highlight.setCurrent(selectedItemID.map(String.init))
            onSynchronize()
        }
        .onChange(of: selectedItemID) { itemID in
            highlight.setCurrent(itemID.map(String.init))
        }
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
                Text(L("playback.navigate"))
            }

            Text(L("playback.open"))
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
