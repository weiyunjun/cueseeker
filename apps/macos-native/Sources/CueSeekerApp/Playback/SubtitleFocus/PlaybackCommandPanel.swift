import AppKit
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
                WorkbenchRedesignColors.commandPanelScrim

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
                                heldPage: playback.commandPanelHeldPage,
                                windowStore:
                                    playback.commandPanelSearchWindow,
                                keyboardNavigationRequest:
                                    playback.commandPanelSearchKeyboardNavigationRequest,
                                onBack: {
                                    appState.returnPlaybackCommandPanelToRoot()
                                },
                                onSynchronize: {
                                    appState
                                        .synchronizePlaybackCommandPanelSearchResults()
                                },
                                onApplyFacetFilter:
                                    appState.applySearchFacetFilter,
                                onUpdateSortOrder:
                                    appState.updateSearchSortOrder,
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
                                scrollSequence: playback.commandPanelRecentCardScrollSequence,
                                items: appState.playbackCommandPanelRecentVideos,
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
                                            columnCount: $0
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
                                scrollSequence: playback.commandPanelRecentCardScrollSequence,
                                summaries: appState.playbackCommandPanelRecentExcerpts,
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
                                            columnCount: $0
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
                        .fill(WorkbenchRedesignColors.bgDialog)
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
                        icon: .magnifyingGlass,
                        title: L("sidebar.search"),
                        detail: query,
                        isSelected: presentation.selectedOrdinal == 0,
                        allowsHover: allowsHover
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
                    allowsHover: allowsHover
                ) {
                    _ = onOpenPage(.recentVideos)
                }

                PlaybackCommandPanelRootRow(
                    icon: .bookmarkSimple,
                    title: L("sidebar.recent_excerpts"),
                    detail: nil,
                    isSelected: presentation.selectedOrdinal
                        == recentExcerptsOrdinal,
                    allowsHover: allowsHover
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
}

private struct PlaybackCommandPanelRootRow: View {
    let icon: AppIcon
    let title: String
    let detail: String?
    let isSelected: Bool
    let allowsHover: Bool
    let action: () -> Void
    @State private var isHovered = false

    /// Hover only counts while the pointer is visible, and never stacks on top
    /// of `Select` (`isSelected`).
    private var isHoverActive: Bool {
        allowsHover && isHovered && !isSelected
    }

    private var backgroundFill: Color {
        if isSelected {
            return WorkbenchRedesignColors.menuItemSelectedBg
        }
        if isHoverActive {
            return WorkbenchRedesignColors.rowSelected
        }
        return .clear
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
                .fill(backgroundFill)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }
}

struct PlaybackCommandPanelHeaderLayoutGeometry: Equatable, Sendable {
    let leadingFrame: CGRect
    let titleFrame: CGRect
    let trailingFrame: CGRect

    static func resolve(
        bounds: CGRect,
        leadingSize: CGSize,
        naturalTitleSize: CGSize,
        trailingSize: CGSize,
        spacing: CGFloat = WorkbenchControlMetrics.redesignSpacing3
    ) -> Self {
        let leadingFrame = CGRect(
            x: bounds.minX,
            y: bounds.midY - leadingSize.height / 2,
            width: leadingSize.width,
            height: leadingSize.height
        )
        let trailingFrame = CGRect(
            x: bounds.maxX - trailingSize.width,
            y: bounds.midY - trailingSize.height / 2,
            width: trailingSize.width,
            height: trailingSize.height
        )

        let minTitleX = leadingSize.width > 0
            ? bounds.minX + leadingSize.width + spacing
            : bounds.minX
        let maxTitleX = trailingSize.width > 0
            ? bounds.maxX - trailingSize.width - spacing
            : bounds.maxX
        let availableTitleWidth = max(0, maxTitleX - minTitleX)
        let titleWidth = min(max(0, naturalTitleSize.width), availableTitleWidth)
        let idealTitleMinX = bounds.midX - titleWidth / 2
        let clampedTitleMinX = min(
            max(idealTitleMinX, minTitleX),
            max(minTitleX, maxTitleX - titleWidth)
        )
        let titleFrame = CGRect(
            x: clampedTitleMinX,
            y: bounds.midY - naturalTitleSize.height / 2,
            width: titleWidth,
            height: naturalTitleSize.height
        )

        return Self(
            leadingFrame: leadingFrame,
            titleFrame: titleFrame,
            trailingFrame: trailingFrame
        )
    }
}

private struct PlaybackCommandPanelSecondaryHeaderLayout: Layout {
    var spacing: CGFloat = WorkbenchControlMetrics.redesignSpacing3

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let maxHeight = subviews.reduce(CGFloat.zero) { current, subview in
            max(current, subview.sizeThatFits(.unspecified).height)
        }
        return CGSize(
            width: proposal.width ?? 0,
            height: proposal.height ?? maxHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        guard subviews.count >= 2 else {
            return
        }
        let leadingSize = subviews[0].sizeThatFits(.unspecified)
        let naturalTitleSize = subviews[1].sizeThatFits(.unspecified)
        let trailingSize = subviews.count > 2
            ? subviews[2].sizeThatFits(.unspecified)
            : .zero

        let geometry = PlaybackCommandPanelHeaderLayoutGeometry.resolve(
            bounds: bounds,
            leadingSize: leadingSize,
            naturalTitleSize: naturalTitleSize,
            trailingSize: trailingSize,
            spacing: spacing
        )

        subviews[0].place(
            at: geometry.leadingFrame.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(geometry.leadingFrame.size)
        )
        subviews[1].place(
            at: geometry.titleFrame.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(geometry.titleFrame.size)
        )
        if subviews.count > 2 {
            subviews[2].place(
                at: geometry.trailingFrame.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(geometry.trailingFrame.size)
            )
        }
    }
}

private struct PlaybackCommandPanelSecondaryHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Bool
    @ViewBuilder let trailing: () -> Trailing

    @State private var isBackHovered = false
    @State private var isBackPressed = false

    init(
        title: String,
        onBack: @escaping () -> Bool,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        PlaybackCommandPanelSecondaryHeaderLayout(
            spacing: WorkbenchControlMetrics.redesignSpacing3
        ) {
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
                            isBackPressed
                                ? WorkbenchRedesignColors
                                    .popoverSurfaceShortcutButtonPressedBg
                                : (isBackHovered
                                    ? WorkbenchRedesignColors
                                        .popoverSurfaceShortcutButtonHoverBg
                                    : Color.clear)
                        )
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(isPressed: $isBackPressed, isHovered: $isBackHovered))
            .focusable(false)
            .onPointerHover { isBackHovered = $0 }
            .workbenchTooltip(
                scenarioID: "command_panel.header.back",
                label: L("tooltip.command_panel.back"),
                shortcut: .fixed("Esc")
            )
            .accessibilityLabel(L("playback.back"))

            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            trailing()
        }
        .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
        .frame(height: PlaybackCommandPanelMetrics.headerHeight)
    }
}

private extension PlaybackCommandPanelSecondaryHeader where Trailing == EmptyView {
    init(
        title: String,
        onBack: @escaping () -> Bool
    ) {
        self.init(
            title: title,
            onBack: onBack,
            trailing: { EmptyView() }
        )
    }
}

private struct PlaybackCommandPanelSearchResults: View {
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var searchStore: SearchStore
    let heldPage: PlaybackCommandPanelHeldPage?
    let windowStore: PlaybackCueResultSessionWindowStore?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onApplyFacetFilter: (CueFacetFilter) -> Void
    let onUpdateSortOrder: (SearchSortOrder) -> Void
    let onCommitSelection: (PlaybackVirtualReelSelectionCommit) -> Bool
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void
    let onRequestAction: (PlaybackSubtitleFocusAction) -> Void

    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var filterDialog: CueFacetFilterDialogCenter
    @EnvironmentObject private var cueGroupPresentation:
        CueGroupPresentationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sortOptions: [SchemaWorkbenchSortOption] {
        SearchSortOrder.workbenchSortOptions
    }

    private var selectedSortOptionID: String {
        searchStore.searchSortOrder.rawValue
    }

    private var isFilterDialogOpen: Bool {
        filterDialog.session?.source == .search
    }

    private var filterSelectionCount: Int {
        searchStore.searchFacetFilter.selectedOptionCount(
            emptyDistribution: searchStore.emptySearchFacetDistribution,
            snapshot: searchStore.searchFacetSnapshot
        )
    }

    var body: some View {
        SchemaWorkbenchSortMenuHost(
            sortOptions: sortOptions,
            selectedSortOptionID: selectedSortOptionID,
            onSelectSortOption: selectSortOption,
            isFilterDialogOpen: isFilterDialogOpen
        ) { sortMenu in
            VStack(spacing: 0) {
                PlaybackCommandPanelSecondaryHeader(
                    title: presentation.query,
                    onBack: onBack
                ) {
                    SchemaWorkbenchFilterAndSortControls(
                        filterSelectionCount: filterSelectionCount,
                        isFilterDialogOpen: isFilterDialogOpen,
                        sortTitle: sortMenu.sortTitle,
                        isSortMenuOpen: sortMenu.isSortMenuOpen,
                        sortButtonAnchor: sortMenu.sortButtonAnchor,
                        onFilter: {
                            openFilterDialog(dismissSortMenu: sortMenu.dismissSortMenu)
                        },
                        onSort: sortMenu.toggleSortMenu
                    )
                }

                GeometryReader { geometry in
                    if let windowStore {
                        PlaybackCommandPanelSearchReel(
                            windowStore: windowStore,
                            isSearching: searchStore.isSearching,
                            showsCueGroup: cueGroupPresentation.isEnabled,
                            viewportSize: geometry.size,
                            keyboardNavigationRequest: keyboardNavigationRequest,
                            reducesMotion: reduceMotion,
                            onCommitSelection: onCommitSelection,
                            onCopySelectedText: onCopySelectedText,
                            onSearchSelectedText: onSearchSelectedText
                        )
                    } else if !searchStore.isSearching {
                        WorkbenchEmptyHint(
                            icon: .searchNoResults,
                            message: L("table.search_no_results")
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
        }
        .onAppear(perform: onSynchronize)
        .onChange(of: searchStore.resultRevision) { _ in
            onSynchronize()
        }
        .onDisappear {
            closeFilterDialog()
        }
    }

    private func openFilterDialog(dismissSortMenu: () -> Void) {
        dismissSortMenu()
        filterDialog.session = CueFacetFilterDialogSession(
            source: .search,
            filter: searchStore.searchFacetFilter,
            apply: { [onApplyFacetFilter] newFilter in
                onApplyFacetFilter(newFilter)
            }
        )
    }

    private func closeFilterDialog() {
        guard filterDialog.session?.source == .search else { return }
        filterDialog.session = nil
    }

    private func selectSortOption(_ optionID: String) {
        guard let order = SearchSortOrder(rawValue: optionID),
              searchStore.searchSortOrder != order
        else {
            return
        }
        onUpdateSortOrder(order)
    }

    private var resultStatus: String {
        if case .searchResults(let totalCount, let hasMoreResults) = heldPage {
            return PlaybackCueFooterStatus.searchResults(
                totalCount: totalCount,
                previewLimit: PlaybackCommandPanelPresentation.previewLimit,
                hasMoreResults: hasMoreResults
            )
        }
        return PlaybackCueFooterStatus.searchResults(
            totalCount: resultTotalCount,
            previewLimit: PlaybackCommandPanelPresentation.previewLimit,
            hasMoreResults: searchStore.hasMoreSearchResults
        )
    }

    private var resultTotalCount: Int {
        max(
            searchStore.searchResultTotalCount,
            searchStore.searchResults.count
        )
    }
}

private struct PlaybackCommandPanelSearchReel: View {
    @ObservedObject var windowStore: PlaybackCueResultSessionWindowStore
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    let isSearching: Bool
    let showsCueGroup: Bool
    let viewportSize: CGSize
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
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

        if windowStore.snapshot.totalCount == 0 {
            if !isSearching {
                WorkbenchEmptyHint(
                    icon: .searchNoResults,
                    message: L("table.search_no_results")
                )
            }
        } else {
            PlaybackCueResultReelRepresentable(
                windowStore: windowStore,
                showsCueGroup: showsCueGroup,
                selectedOrdinal: windowStore.selectedOrdinal,
                uiProbeScope: nil,
                keyboardNavigationRequest: keyboardNavigationRequest,
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
}

/// The Command Panel's two Recent pages. They differ only in their title, the
/// card grid they show and the count in the footer; grid walking, scrolling and
/// highlight ownership are the same for both, so one page serves them.
private struct PlaybackCommandPanelRecentCards<Grid: View>: View {
    let title: String
    let presentation: PlaybackCommandPanelPresentation
    let scrollSequence: UInt64
    /// In display order, so the panel's ordinal and the card the pointer is on
    /// name the same item.
    let itemIDs: [String]
    let sectionItemCounts: [Int]
    let emptyIcon: AppEmptyStateIcon
    let emptyMessage: String
    let footerStatus: String
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onGridLayoutChange: (Int) -> Void
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

    private var scrollRequest: PlaybackMediaSelectionScrollRequest? {
        guard scrollSequence > 0, let selectedItemID else {
            return nil
        }
        return PlaybackMediaSelectionScrollRequest(
            sequence: scrollSequence,
            itemID: selectedItemID
        )
    }

    var body: some View {
        let _ = highlight.syncSelectedDuringRender(selectedItemID)

        VStack(spacing: 0) {
            PlaybackCommandPanelSecondaryHeader(
                title: title,
                onBack: onBack
            )

            GeometryReader { geometry in
                let gridWidth = max(
                    0,
                    geometry.size.width
                        - PlaybackCommandPanelMetrics.contentInset * 2
                )
                let columnCount = PlaybackCommandPanelCardGrid.columnCount(
                    containerWidth: gridWidth
                )
                let isFirstRowSelection: Bool = {
                    guard let ordinal = presentation.selectedOrdinal,
                          itemIDs.indices.contains(ordinal)
                    else {
                        return false
                    }
                    return PlaybackMediaSelectionStore.isFirstRow(
                        index: ordinal,
                        itemCount: itemIDs.count,
                        columnCount: columnCount,
                        sectionItemCounts: sectionItemCounts
                    )
                }()

                if itemIDs.isEmpty {
                    WorkbenchEmptyHint(
                        icon: emptyIcon,
                        message: emptyMessage
                    )
                    .onAppear {
                        onGridLayoutChange(columnCount)
                    }
                    .onChange(of: columnCount) { newColumnCount in
                        onGridLayoutChange(newColumnCount)
                    }
                } else {
                    WorkbenchScrollView {
                        grid(highlight, coordinateSpaceName) { frames in
                            itemFramesByID = frames
                        }
                        .environment(\.mediaCardGridContainerWidth, gridWidth)
                        .background(alignment: .topLeading) {
                            PlaybackMediaScrollPositionBridge(
                                restorationOffsetY: 0,
                                restoresInitialOffset: false,
                                scrollRequest: scrollRequest,
                                isFirstRowSelection: isFirstRowSelection,
                                itemFramesByID: itemFramesByID,
                                topPadding: WorkbenchControlMetrics.redesignSpacing2,
                                bottomPadding: WorkbenchControlMetrics.redesignSpacing2,
                                onOffsetChanged: { _ in }
                            )
                            .frame(width: 0, height: 0)
                        }
                        .padding(
                            .horizontal,
                            PlaybackCommandPanelMetrics.contentInset
                        )
                        .padding(
                            .vertical,
                            WorkbenchControlMetrics.redesignSpacing2
                        )
                        .coordinateSpace(name: coordinateSpaceName)
                    }
                    .onAppear {
                        onGridLayoutChange(columnCount)
                    }
                    .onChange(of: columnCount) { newColumnCount in
                        onGridLayoutChange(newColumnCount)
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
            highlight.setSelected(selectedItemID)
            onSynchronize()
        }
        .onChange(of: selectedItemID) { itemID in
            highlight.setSelected(itemID)
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
        WorkbenchControlMetrics.mediaCardGridColumnCount(
            containerWidth: containerWidth,
            maxColumns: WorkbenchControlMetrics
                .redesignLibraryRecentGridMaxColumnsWithoutSidebar
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
    let scrollSequence: UInt64
    let items: [RecentLibraryWatchingPresentation]
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onGridLayoutChange: (Int) -> Void
    let onSelect: (Int) -> Void
    let onOpen: (Int) -> Void
    let onOpenSelectedItem: () -> Void

    var body: some View {
        PlaybackCommandPanelRecentCards(
            title: L("sidebar.recent_videos"),
            presentation: presentation,
            scrollSequence: scrollSequence,
            itemIDs: items.map(\.id),
            sectionItemCounts: RecentTimeSection.group(
                items,
                timestamp: \.updatedAt
            ).map(\.items.count),
            emptyIcon: .video,
            emptyMessage: L("library.recent_watching_empty"),
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
    let scrollSequence: UInt64
    let summaries: [ExcerptListSummary]
    let onBack: () -> Bool
    let onSynchronize: () -> Void
    let onGridLayoutChange: (Int) -> Void
    let onSelect: (Int) -> Void
    let onOpen: (Int) -> Void
    let onOpenSelectedItem: () -> Void

    var body: some View {
        PlaybackCommandPanelRecentCards(
            title: L("sidebar.recent_excerpts"),
            presentation: presentation,
            scrollSequence: scrollSequence,
            itemIDs: summaries.map { String($0.id) },
            sectionItemCounts: RecentTimeSection.group(
                summaries,
                timestamp: \.list.recentPlayedAt
            ).map(\.items.count),
            emptyIcon: .excerpt,
            emptyMessage: L("library.recent_excerpts_empty"),
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
                groupsByRecentSection: true,
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
