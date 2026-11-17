import AppKit
import CueSeekerCore
import SwiftUI

private final class PlaybackCommandPanelTransitionTracker {
    var lastTargetPage: PlaybackCommandPanelPage?
    var lastPresentedPage: PlaybackCommandPanelPage?
    var lastRecordedPage: PlaybackCommandPanelPage?
    var asyncPreparedPage: PlaybackCommandPanelPage?
    var preparationTask: Task<Void, Never>?

    deinit {
        preparationTask?.cancel()
    }
}

struct PlaybackCommandPanel: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var pointerVisibility:
        PlaybackPointerVisibilityStore
    @Environment(\.displayScale) private var displayScale
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var indexingStore: IndexingStore
    @ObservedObject var searchStore: SearchStore
    @ObservedObject var libraryStore: LibraryStore
    @ObservedObject var excerptStore: ExcerptStore
    @State private var transitionTracker = PlaybackCommandPanelTransitionTracker()
    @State private var asyncPreparedPageRevision: UInt64 = 0

    private func activePage(
        for presentation: PlaybackCommandPanelPresentation
    ) -> PlaybackCommandPanelPage {
        _ = asyncPreparedPageRevision
        let target = presentation.page
        if transitionTracker.lastTargetPage != target {
            transitionTracker.lastTargetPage = target
            transitionTracker.asyncPreparedPage = nil
        }
        if transitionTracker.asyncPreparedPage == target
            || appState.isPlaybackCommandPanelPageReadyForPresentation(target)
        {
            transitionTracker.lastPresentedPage = target
            return target
        }
        return transitionTracker.lastPresentedPage ?? .root
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                WorkbenchRedesignColors.commandPanelScrim

                if let presentation = playback.commandPanelPresentation {
                    let presentedPage = activePage(for: presentation)
                    let panelShape = RoundedRectangle(
                        cornerRadius: PlaybackCommandPanelMetrics.cornerRadius,
                        style: .circular
                    )
                    Group {
                        switch presentedPage {
                        case .root:
                            PlaybackCommandPanelRoot(
                                presentation: presentation,
                                searchStore: searchStore,
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
                                onCopyCurrentCue: {
                                    appState
                                        .copyPlaybackCommandPanelCurrentCue()
                                },
                                onOpenPage: {
                                    appState.presentPlaybackCommandPanelPage($0)
                                },
                                onClose: {
                                    _ = appState.dismissPlaybackCommandPanelFromUser()
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
                                isLoading: appState.isPlaybackCommandPanelRecentVideosLoading,
                                showsNoFolderOnboarding: appState.showsPlaybackCommandPanelNoFolderRecentVideosOnboarding,
                                onGoToFile: {
                                    appState.openFileFromPlaybackCommandPanel()
                                },
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
                                isLoading: appState.isPlaybackCommandPanelRecentExcerptsLoading,
                                showsNoFolderOnboarding: appState.showsPlaybackCommandPanelNoFolderRecentExcerptsOnboarding,
                                onGoToFile: {
                                    appState.openFileFromPlaybackCommandPanel()
                                },
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
                    .background(WorkbenchRedesignColors.bgDialog)
                    .clipShape(panelShape)
                    .overlay(
                        panelShape
                            .strokeBorder(
                                WorkbenchRedesignColors.dialogEdgeHighlight,
                                lineWidth: 1
                            )
                            .allowsHitTesting(false)
                    )
                    // One device pixel wide, left showing strictly outside the
                    // circular panel shape so it never overlaps the panel or
                    // its translucent interior edge highlight.
                    .background(
                        panelShape
                            .inset(by: -1 / displayScale)
                            .fill(WorkbenchRedesignColors.dialogOutline)
                            .clipShape(
                                WorkbenchExteriorClipShape(
                                    cornerRadius: PlaybackCommandPanelMetrics.cornerRadius,
                                    outset: 1 / displayScale + 1,
                                    cornerStyle: .circular
                                ),
                                style: FillStyle(eoFill: true)
                            )
                    )
                    .shadowToken(
                        WorkbenchRedesignColors.shadowDialog,
                        cornerRadius: PlaybackCommandPanelMetrics.cornerRadius
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onAppear {
                schedulePagePreparationIfNeeded(
                    for: playback.commandPanelPresentation?.page
                )
            }
            .onChange(of: playback.commandPanelPresentation?.page) { newPage in
                schedulePagePreparationIfNeeded(for: newPage)
            }
            .onDisappear {
                transitionTracker.preparationTask?.cancel()
                transitionTracker.preparationTask = nil
                transitionTracker.lastTargetPage = nil
                transitionTracker.lastPresentedPage = nil
                transitionTracker.lastRecordedPage = nil
                transitionTracker.asyncPreparedPage = nil
            }
        }
    }

    private func schedulePagePreparationIfNeeded(
        for page: PlaybackCommandPanelPage?
    ) {
        let preparationStartedAt = DebugInteractionLatencyProbe.now()
        let previousLabel = transitionTracker.lastRecordedPage?.diagnosticLabel ?? "closed"
        let didChangePage = transitionTracker.lastRecordedPage != page
            || DebugInteractionLatencyProbe.hasPendingNavigation(domain: "command_panel")
        transitionTracker.preparationTask?.cancel()
        transitionTracker.preparationTask = nil
        guard let page else {
            transitionTracker.lastTargetPage = nil
            transitionTracker.lastPresentedPage = nil
            transitionTracker.lastRecordedPage = nil
            transitionTracker.asyncPreparedPage = nil
            return
        }
        if appState.isPlaybackCommandPanelPageReadyForPresentation(page) {
            transitionTracker.lastPresentedPage = page
            transitionTracker.lastRecordedPage = page
            if didChangePage {
                let swapAt = DebugInteractionLatencyProbe.now()
                DebugInteractionLatencyProbe.recordNavigationPreparation(
                    domain: "command_panel",
                    from: previousLabel,
                    to: page.diagnosticLabel,
                    fallbackTrigger: "command_panel_ready",
                    preparationStartedAt: preparationStartedAt,
                    dataReadyAt: swapAt,
                    coverStats: appState.cachedCommandPanelCoverStats(for: page),
                    containerSwapAt: swapAt
                )
            }
            return
        }
        transitionTracker.preparationTask = Task { @MainActor in
            let metrics = await appState.preparePlaybackCommandPanelPageForPresentation(page)
            guard !Task.isCancelled else {
                return
            }
            let swapAt = DebugInteractionLatencyProbe.now()
            transitionTracker.preparationTask = nil
            transitionTracker.lastTargetPage = page
            transitionTracker.asyncPreparedPage = page
            transitionTracker.lastPresentedPage = page
            transitionTracker.lastRecordedPage = page
            asyncPreparedPageRevision &+= 1
            DebugInteractionLatencyProbe.recordNavigationPreparation(
                domain: "command_panel",
                from: previousLabel,
                to: page.diagnosticLabel,
                fallbackTrigger: "command_panel_async_prepare",
                preparationStartedAt: preparationStartedAt,
                dataReadyAt: metrics.dataReadyAt,
                coverStats: metrics.coverStats,
                containerSwapAt: swapAt
            )
        }
    }

    /// The footer's Open button and Return run the same path.
    private func openSelectedItem() {
        _ = appState.openSelectedPlaybackCommandPanelItem()
    }
}

private enum PlaybackCommandPanelMetrics {
    static let maximumWidth =
        WorkbenchControlMetrics.redesignCommandPanelMaxWidth
    static let maximumHeight =
        WorkbenchControlMetrics.redesignCommandPanelMaxHeight
    static let outerInset =
        WorkbenchControlMetrics.redesignCommandPanelViewportInset
    static let cornerRadius =
        WorkbenchControlMetrics.redesignDialogCornerRadius
    static let contentInset =
        WorkbenchControlMetrics.redesignSpacing5
    static let rowHeight =
        WorkbenchControlMetrics.redesignCommandPanelItemHeight
    static let rowRadius =
        WorkbenchControlMetrics.redesignMenuItemRadius
    static let headerHeight =
        WorkbenchControlMetrics.redesignCommandPanelHeaderHeight
}

private struct PlaybackCommandPanelRoot: View {
    @EnvironmentObject private var localization: AppLocalizationStore
    let presentation: PlaybackCommandPanelPresentation
    @ObservedObject var searchStore: SearchStore
    let allowsHover: Bool
    let onSelect: (Int) -> Void
    @Binding var query: String
    let onSubmitSearch: () -> Bool
    let onCopyCurrentCue: () -> Bool
    let onOpenPage: (PlaybackCommandPanelPage) -> Bool
    let onClose: () -> Void
    let onOpenSelectedItem: () -> Void

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            VStack(spacing: 0) {
                WorkbenchSearchField(
                    placeholder: L("playback.command_panel.search_placeholder"),
                    text: $query,
                    autofocus: true,
                    isSearchAccessibilityFocused: accessibility?.isPlaybackFocused(.commandPanelSearchField) == true,
                    isClearAccessibilityFocused: accessibility?.isPlaybackFocused(.commandPanelSearchClearButton) == true,
                    onSubmit: {
                        guard accessibility?.isPlaybackActive != true else { return }
                        onOpenSelectedItem()
                    },
                    onBindAccessibilityTextField: { field in
                        accessibility?.activeCommandPanelSearchTextField = field
                    }
                )
                .padding(PlaybackCommandPanelMetrics.contentInset)

                VStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                    ForEach(
                        Array(presentation.rootOptions.enumerated()),
                        id: \.offset
                    ) { ordinal, option in
                        let isSelected = presentation.selectedOrdinal == ordinal
                        let isFocused = accessibility?.isPlaybackFocused(
                            .commandPanelRootOption(ordinal)
                        ) == true
                        switch option {
                        case .search:
                            PlaybackCommandPanelRootRow(
                                icon: .magnifyingGlass,
                                title: L("sidebar.search"),
                                detail: query,
                                trailingText: searchResultCountText,
                                isSelected: isSelected,
                                isFocused: isFocused,
                                allowsHover: allowsHover
                            ) {
                                _ = onSubmitSearch()
                            }
                        case .copyCurrentCue:
                            PlaybackCommandPanelRootRow(
                                icon: .copy,
                                title: L("playback.command_panel.copy_current_cue"),
                                detail: presentation.currentCueText.map(
                                    SearchInputNormalizer.singleLine
                                ),
                                trailingText: nil,
                                isSelected: isSelected,
                                isFocused: isFocused,
                                allowsHover: allowsHover
                            ) {
                                _ = onCopyCurrentCue()
                            }
                        case .recentVideos:
                            PlaybackCommandPanelRootRow(
                                icon: .video,
                                title: L("sidebar.recent_videos"),
                                detail: nil,
                                trailingText: nil,
                                isSelected: isSelected,
                                isFocused: isFocused,
                                allowsHover: allowsHover
                            ) {
                                _ = onOpenPage(.recentVideos)
                            }
                        case .recentExcerpts:
                            PlaybackCommandPanelRootRow(
                                icon: .bookmarkSimple,
                                title: L("sidebar.recent_excerpts"),
                                detail: nil,
                                trailingText: nil,
                                isSelected: isSelected,
                                isFocused: isFocused,
                                allowsHover: allowsHover
                            ) {
                                _ = onOpenPage(.recentExcerpts)
                            }
                        }
                    }
                }
                .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)

                Spacer(minLength: 0)

                PlaybackCommandPanelFooter(
                    status: nil,
                    primaryActionTitle: presentation.selectedRootOption
                        == .copyCurrentCue
                        ? L("playback.copy")
                        : L("playback.open"),
                    onClose: onClose,
                    onOpenSelectedItem: onOpenSelectedItem
                )
            }
        }
    }

    private var searchResultCountText: String? {
        searchStore.exactSearchResultTotalCount(matchingQuery: query)
            .map(schemaWorkbenchResultCountText)
    }
}

private struct PlaybackCommandPanelRootRow: View {
    let icon: AppIcon
    let title: String
    let detail: String?
    let trailingText: String?
    let isSelected: Bool
    var isFocused: Bool = false
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
            return WorkbenchRedesignColors.bgHover
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

                if let detail {
                    Text(title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .medium
                        ))
                        .fixedSize(horizontal: true, vertical: false)

                    Text(detail)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .regular
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .medium
                        ))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let trailingText {
                    Text(trailingText)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .regular
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
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
            .workbenchAccessibilityFocusRing(
                isFocused: isFocused,
                cornerRadius: PlaybackCommandPanelMetrics.rowRadius
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }
}

private struct PlaybackCommandPanelSecondaryHeader<Trailing: View>: View {
    @EnvironmentObject private var localization: AppLocalizationStore
    let title: String
    let onBack: () -> Bool
    let trailing: Trailing

    @State private var isBackHovered = false
    @State private var isBackPressed = false

    init(
        title: String,
        onBack: @escaping () -> Bool,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
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
                                    ? WorkbenchRedesignColors.bgPressed
                                    : (isBackHovered
                                        ? WorkbenchRedesignColors.bgHover
                                        : Color.clear)
                            )
                        )
                        .workbenchAccessibilityFocusRing(
                            isFocused: accessibility?.isPlaybackFocused(.commandPanelBackButton) == true,
                            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
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

                HStack(spacing: 0) {
                    WorkbenchSelectableText(
                        title,
                        fullCopyText: title,
                        fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .semibold,
                        color: WorkbenchRedesignColors.textPrimary,
                        lineLimit: 1,
                        truncationMode: .tail,
                        truncationTooltipScenarioID: "truncated.command_panel.secondary_title"
                    )

                    Spacer(minLength: 0)
                }

                trailing
            }
            .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
            .frame(height: PlaybackCommandPanelMetrics.headerHeight)
        }
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
            WorkbenchAccessibilityReader { accessibility in
                let _ = syncAccessibilityCallbacks(
                    accessibility,
                    dismissSortMenu: sortMenu.dismissSortMenu,
                    toggleSortMenu: sortMenu.toggleSortMenu
                )

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
                            isFilterFocused: accessibility?.isPlaybackFocused(.commandPanelFilterButton) == true,
                            isSortFocused: accessibility?.isPlaybackFocused(.commandPanelSortButton) == true,
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
                            .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
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
                .onDisappear {
                    accessibility?.onOpenCommandPanelFilterDialog = nil
                    accessibility?.onToggleCommandPanelSortMenu = nil
                }
            }
        }
        .onDisappear {
            closeFilterDialog()
        }
    }

    private func syncAccessibilityCallbacks(
        _ accessibility: WorkbenchAccessibilityCoordinator?,
        dismissSortMenu: @escaping () -> Void,
        toggleSortMenu: @escaping () -> Void
    ) {
        accessibility?.onOpenCommandPanelFilterDialog = {
            openFilterDialog(dismissSortMenu: dismissSortMenu)
        }
        accessibility?.onToggleCommandPanelSortMenu = toggleSortMenu
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

    private var resultStatus: String? {
        if case .searchResults(let totalCount, let hasMoreResults) = heldPage {
            return PlaybackCueFooterStatus.searchResults(
                totalCount: totalCount,
                previewLimit: PlaybackCommandPanelPresentation.previewLimit,
                hasMoreResults: hasMoreResults
            )
        }
        guard let totalCount = searchStore.exactSearchResultTotalCount(
            matchingQuery: presentation.query
        ) else {
            return nil
        }
        return PlaybackCueFooterStatus.searchResults(
            totalCount: totalCount,
            previewLimit: PlaybackCommandPanelPresentation.previewLimit,
            hasMoreResults: searchStore.hasMoreSearchResults
        )
    }
}

private struct PlaybackCommandPanelSearchReel: View {
    @EnvironmentObject private var localization: AppLocalizationStore
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
                .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
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
                menuOwner: .commandPanel,
                isCoveredByHigherLayer: layerContext.isCovered
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
    let isLoading: Bool
    let emptyIcon: AppEmptyStateIcon
    let emptyMessage: String
    var emptyActionTitle: String? = nil
    var emptyActionIcon: AppIcon? = nil
    var isEmptyActionFocused: Bool = false
    var onEmptyAction: (() -> Void)? = nil
    let footerStatus: String?
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

    private final class ItemFramesStorage {
        var framesByID: [String: CGRect] = [:]
    }

    private let coordinateSpaceName =
        "playback-command-panel-recent-cards-scroll"
    @State private var itemFramesStorage = ItemFramesStorage()
    @State private var itemFramesRevision: UInt64 = 0
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
                    Group {
                        if isLoading {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            WorkbenchEmptyHint(
                                icon: emptyIcon,
                                message: emptyMessage,
                                actionTitle: emptyActionTitle,
                                actionIcon: emptyActionIcon,
                                isActionFocused: isEmptyActionFocused,
                                action: onEmptyAction
                            )
                            .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
                        }
                    }
                    .onAppear {
                        onGridLayoutChange(columnCount)
                    }
                    .onChange(of: columnCount) { newColumnCount in
                        onGridLayoutChange(newColumnCount)
                    }
                } else {
                    let _ = itemFramesRevision
                    WorkbenchScrollView {
                        grid(highlight, coordinateSpaceName) { frames in
                            guard itemFramesStorage.framesByID != frames else {
                                return
                            }
                            itemFramesStorage.framesByID = frames
                            if scrollRequest != nil {
                                itemFramesRevision &+= 1
                            }
                        }
                        .environment(\.mediaCardGridContainerWidth, gridWidth)
                        .background(alignment: .topLeading) {
                            PlaybackMediaScrollPositionBridge(
                                restorationOffsetY: 0,
                                restoresInitialOffset: false,
                                scrollRequest: scrollRequest,
                                isFirstRowSelection: isFirstRowSelection,
                                itemFramesByID: itemFramesStorage.framesByID,
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
                status: isLoading && itemIDs.isEmpty ? nil : footerStatus,
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
    @EnvironmentObject private var localization: AppLocalizationStore
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility
    let presentation: PlaybackCommandPanelPresentation
    let scrollSequence: UInt64
    let items: [RecentLibraryWatchingPresentation]
    let isLoading: Bool
    let showsNoFolderOnboarding: Bool
    let onGoToFile: () -> Void
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
            isLoading: isLoading,
            emptyIcon: showsNoFolderOnboarding ? .folderHint : .video,
            emptyMessage: showsNoFolderOnboarding
                ? L("onboarding.no_folder.message")
                : L("library.recent_watching_empty"),
            emptyActionTitle: showsNoFolderOnboarding
                ? L("onboarding.no_folder.go_to_file")
                : nil,
            emptyActionIcon: showsNoFolderOnboarding ? .folder : nil,
            isEmptyActionFocused: showsNoFolderOnboarding
                && workbenchAccessibility?.isPlaybackFocused(.commandPanelGoToFileButton) == true,
            onEmptyAction: showsNoFolderOnboarding ? onGoToFile : nil,
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
    @EnvironmentObject private var localization: AppLocalizationStore
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility
    let presentation: PlaybackCommandPanelPresentation
    let scrollSequence: UInt64
    let summaries: [ExcerptListSummary]
    let isLoading: Bool
    let showsNoFolderOnboarding: Bool
    let onGoToFile: () -> Void
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
            isLoading: isLoading,
            emptyIcon: showsNoFolderOnboarding ? .folderHint : .excerpt,
            emptyMessage: showsNoFolderOnboarding
                ? L("onboarding.no_folder.message")
                : L("library.recent_excerpts_empty"),
            emptyActionTitle: showsNoFolderOnboarding
                ? L("onboarding.no_folder.go_to_file")
                : nil,
            emptyActionIcon: showsNoFolderOnboarding ? .folder : nil,
            isEmptyActionFocused: showsNoFolderOnboarding
                && workbenchAccessibility?.isPlaybackFocused(.commandPanelGoToFileButton) == true,
            onEmptyAction: showsNoFolderOnboarding ? onGoToFile : nil,
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

/// Footer for Command Panel pages with a primary Return action and an optional
/// root Close (`Esc`) action. Everything else comes from the shared footer.
private struct PlaybackCommandPanelFooter: View {
    @EnvironmentObject private var localization: AppLocalizationStore
    let status: String?
    var primaryActionTitle: String? = nil
    var onClose: (() -> Void)? = nil
    let onOpenSelectedItem: () -> Void

    private var footerActions: [PlaybackCueFooterAction] {
        var actions: [PlaybackCueFooterAction] = []
        if let onClose {
            actions.append(.close(perform: onClose))
        }
        actions.append(
            .primary(
                id: "open",
                title: primaryActionTitle ?? L("playback.open")
            ) {
                onOpenSelectedItem()
            }
        )
        return actions
    }

    var body: some View {
        PlaybackCueFooter(
            surface: .commandPanel,
            status: status,
            actions: footerActions
        )
        .padding(.horizontal, PlaybackCommandPanelMetrics.contentInset)
    }
}
