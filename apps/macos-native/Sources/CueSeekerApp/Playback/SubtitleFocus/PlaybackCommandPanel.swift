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
    @ObservedObject var excerptStore: ExcerptStore

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
                                },
                                onOpenSelectedItem: openSelectedItem
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
                                    appState.searchPlaybackSelectedText,
                                onRequestAction: { action in
                                    _ = appState
                                        .requestPlaybackCommandPanelSearchAction(
                                            action
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
                                onGridLayoutChange: {
                                    appState
                                        .updatePlaybackCommandPanelRecentCardGridLayout(
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
                                },
                                onOpenSelectedItem: openSelectedItem
                            )
                        case .recentExcerpts:
                            PlaybackCommandPanelRecentExcerpts(
                                presentation: presentation,
                                excerptStore: excerptStore,
                                onBack: {
                                    appState.returnPlaybackCommandPanelToRoot()
                                },
                                onSynchronize: {
                                    appState
                                        .synchronizePlaybackCommandPanelSelection()
                                },
                                onGridLayoutChange: {
                                    appState
                                        .updatePlaybackCommandPanelRecentCardGridLayout(
                                            columnCount: $0,
                                            itemFramesByID: $1
                                        )
                                },
                                onSelect: {
                                    appState
                                        .selectPlaybackCommandPanelItem(at: $0)
                                },
                                onOpen: {
                                    appState.openPlaybackCommandPanelRecentExcerpt(
                                        at: $0
                                    )
                                },
                                onOpenSelectedItem: openSelectedItem
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
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: PlaybackCommandPanelMetrics.cornerRadius,
                            style: .continuous
                        )
                    )
                    // The shadow belongs to the panel's shape, not to the
                    // panel. Applied to the whole surface it is cast by every
                    // leaf inside it. The backing shape sits behind the clip
                    // so the clip cannot cut the shadow off.
                    .background(
                        RoundedRectangle(
                            cornerRadius: PlaybackCommandPanelMetrics.cornerRadius,
                            style: .continuous
                        )
                        .fill(WorkbenchRedesignColors.bgPopover)
                        .shadowToken(
                            WorkbenchRedesignColors.shadowPopover,
                            cornerRadius: PlaybackCommandPanelMetrics.cornerRadius
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
        }
    }

    /// The footer's Open button and Return run the same path.
    private func openSelectedItem() {
        _ = appState.openSelectedPlaybackCommandPanelItem()
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
}

private struct PlaybackCommandPanelRoot: View {
    let presentation: PlaybackCommandPanelPresentation
    let allowsHover: Bool
    let onSelect: (Int) -> Void
    @Binding var query: String
    let onSubmitSearch: () -> Bool
    let onOpenPage: (PlaybackCommandPanelPage) -> Bool
    let onOpenSelectedItem: () -> Void

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
                        icon: .magnifyingGlass,
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
                    icon: .video,
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
                    icon: .bookmarkSimple,
                    title: L("sidebar.recent_excerpts"),
                    detail: nil,
                    isSelected: presentation.selectedOrdinal
                        == recentExcerptsOrdinal,
                    allowsHover: allowsHover,
                    onHoverChange: {
                        hoverChanged($0, ordinal: recentExcerptsOrdinal)
                    }
                ) {
                    _ = onOpenPage(.recentExcerpts)
                }
            }
            .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)

            Spacer(minLength: 0)

            PlaybackCommandPanelFooter(
                status: nil,
                onOpenSelectedItem: onOpenSelectedItem
            )
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var recentVideosOrdinal: Int {
        trimmedQuery.isEmpty ? 0 : 1
    }

    private var recentExcerptsOrdinal: Int {
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
    let icon: AppIcon
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
                AppIconImage(icon, size: WorkbenchControlMetrics.redesignControlIconSize)
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
        .buttonStyle(StaticButtonStyle())
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

    @State private var isBackHovered = false

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
                    AppIconImage(
                        .arrowLeft,
                        size: WorkbenchControlMetrics.redesignControlIconSize
                    )
                        .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                        .frame(
                            width: WorkbenchControlMetrics
                                .redesignIconButtonSize,
                            height: WorkbenchControlMetrics
                                .redesignIconButtonSize
                        )
                        .background(
                            RoundedRectangle(
                                cornerRadius: WorkbenchControlMetrics
                                    .redesignCornerRadius,
                                style: .continuous
                            )
                            .fill(
                                isBackHovered
                                    ? WorkbenchRedesignColors
                                        .popoverSurfaceShortcutButtonHoverBg
                                    : Color.clear
                            )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
                .onPointerHover { isBackHovered = $0 }
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
    let onRequestAction: (PlaybackSubtitleFocusAction) -> Void

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
                surface: .commandPanel,
                status: resultStatus,
                actions: PlaybackCueFooterAction.cueActions(
                    playTitle: L("playback.play"),
                    request: onRequestAction
                )
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
    @Environment(\.interfaceLayerContext) private var layerContext
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
            // A dialog drawn over the panel owns the wheel, even where it lies
            // over the reel; the reel lets it through untouched.
            allowsNativeWheelInput: { [isCovered = layerContext.isCovered] in !isCovered },
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

/// The Command Panel's two Recent pages. They differ only in their title, the
/// card grid they show and the count in the footer; grid walking, scrolling and
/// highlight ownership are the same for both, so one page serves them.
private struct PlaybackCommandPanelRecentCards<Grid: View>: View {
    let title: String
    let presentation: PlaybackCommandPanelPresentation
    /// In display order, so the panel's ordinal and the card the pointer is on
    /// name the same item.
    let itemIDs: [String]
    let footerStatus: String
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onGridLayoutChange: (Int, [String: CGRect]) -> Void
    let onSelect: (Int) -> Void
    let onOpenSelectedItem: () -> Void
    @ViewBuilder let grid: (
        _ highlight: CardHighlightModel,
        _ coordinateSpaceName: String,
        _ onItemFramesChange: @escaping ([String: CGRect]) -> Void
    ) -> Grid

    private let coordinateSpaceName =
        "playback-command-panel-recent-cards-scroll"
    @State private var itemFramesByID: [String: CGRect] = [:]
    /// The page keeps navigating with its own ordinal; this owns which card is
    /// lit and decides when the pointer may move it.
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: true
    )

    private var selectedItemID: String? {
        guard let ordinal = presentation.selectedOrdinal,
              itemIDs.indices.contains(ordinal)
        else {
            return nil
        }
        return itemIDs[ordinal]
    }

    var body: some View {
        VStack(spacing: 0) {
            PlaybackCommandPanelSecondaryHeader(
                title: title,
                onBack: onBack
            )

            GeometryReader { geometry in
                let columnCount = PlaybackCommandPanelCardGrid.columnCount(
                    containerWidth: max(
                        0,
                        geometry.size.width
                            - PlaybackCommandPanelMetrics.contentInset * 2
                    )
                )

                ScrollViewReader { proxy in
                    WorkbenchScrollView {
                        grid(highlight, coordinateSpaceName) { frames in
                            itemFramesByID = frames
                            onGridLayoutChange(columnCount, frames)
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
                              let anchor = PlaybackCommandPanelCardGrid
                                  .scrollAnchor(
                                      for: selectedItemID,
                                      orderedItemIDs: itemIDs,
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
                status: footerStatus,
                onOpenSelectedItem: onOpenSelectedItem
            )
        }
        .cardHighlightFreeze(highlight)
        .onAppear {
            highlight.adopt = { adoptedID in
                guard let adoptedID,
                      let ordinal = itemIDs.firstIndex(of: adoptedID)
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
        .onChange(of: itemIDs) { _ in
            onSynchronize()
        }
    }
}

/// How wide a row of Recent cards is, and where the panel has to scroll to put
/// the keyboard's card on screen.
enum PlaybackCommandPanelCardGrid {
    static func columnCount(containerWidth: CGFloat) -> Int {
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

private struct PlaybackCommandPanelRecentVideos: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var libraryStore: LibraryStore
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onGridLayoutChange: (Int, [String: CGRect]) -> Void
    let onSelect: (Int) -> Void
    let onOpen: (Int) -> Void
    let onOpenSelectedItem: () -> Void

    private var items: [RecentLibraryWatchingPresentation] {
        libraryStore.testRecentWatchingItems
    }

    var body: some View {
        PlaybackCommandPanelRecentCards(
            title: L("sidebar.recent_videos"),
            presentation: presentation,
            itemIDs: items.map(\.id),
            footerStatus: PlaybackCueFooterStatus.videos(totalCount: items.count),
            onBack: onBack,
            onSynchronize: onSynchronize,
            onGridLayoutChange: onGridLayoutChange,
            onSelect: onSelect,
            onOpenSelectedItem: onOpenSelectedItem
        ) { highlight, coordinateSpaceName, onItemFramesChange in
            RecentWatchingGrid(
                items: items,
                highlight: highlight,
                itemFrameCoordinateSpace: coordinateSpaceName,
                onItemFramesChange: onItemFramesChange
            ) { item in
                if let ordinal = items.firstIndex(where: { $0.id == item.id }) {
                    onOpen(ordinal)
                }
            }
        }
    }
}

private struct PlaybackCommandPanelRecentExcerpts: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var excerptStore: ExcerptStore
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onGridLayoutChange: (Int, [String: CGRect]) -> Void
    let onSelect: (Int) -> Void
    let onOpen: (Int) -> Void
    let onOpenSelectedItem: () -> Void

    private var summaries: [ExcerptListSummary] {
        excerptStore.recentListSummaries
    }

    var body: some View {
        PlaybackCommandPanelRecentCards(
            title: L("sidebar.recent_excerpts"),
            presentation: presentation,
            itemIDs: summaries.map { String($0.id) },
            footerStatus: PlaybackCueFooterStatus.excerptLists(totalCount: summaries.count),
            onBack: onBack,
            onSynchronize: onSynchronize,
            onGridLayoutChange: onGridLayoutChange,
            onSelect: onSelect,
            onOpenSelectedItem: onOpenSelectedItem
        ) { highlight, coordinateSpaceName, onItemFramesChange in
            ExcerptListCardGrid(
                summaries: summaries,
                highlight: highlight,
                itemFrameCoordinateSpace: coordinateSpaceName,
                onItemFramesChange: onItemFramesChange
            ) { summary in
                if let ordinal = summaries.firstIndex(where: {
                    $0.id == summary.id
                }) {
                    onOpen(ordinal)
                }
            }
        }
    }
}

/// The pages whose only key is Return. Everything else about the footer comes
/// from the shared component.
private struct PlaybackCommandPanelFooter: View {
    let status: String?
    let onOpenSelectedItem: () -> Void

    var body: some View {
        PlaybackCueFooter(
            surface: .commandPanel,
            status: status,
            actions: [
                .primary(id: "open", title: L("playback.open")) {
                    onOpenSelectedItem()
                },
            ]
        )
        .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
    }
}
