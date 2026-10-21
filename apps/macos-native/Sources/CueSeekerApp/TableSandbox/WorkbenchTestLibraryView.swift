import AppKit
import CoreGraphics
import CueSeekerCore
import SwiftUI

struct WorkbenchRecentView: View {
    // Observed so the tab labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var routeState: WorkbenchRouteState
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var excerpt: ExcerptStore
    /// One highlight for the page: only one card may be lit at a time.
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: false
    )

    var body: some View {
        // The menu belongs to the page, not to one tab of it, so the page
        // hosts it.
        LibraryCardContextMenuHost(
            interfaceID: routeState.selectedRecentSection.rawValue
        ) { _ in
        GeometryReader { geometry in
            WorkbenchScrollView {
                VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.sectionSpacing) {
                    switch routeState.selectedRecentSection {
                    case .videos:
                        recentVideosContent(
                            status: library.testRecentWatchingStatus,
                            items: library.testRecentWatchingItems
                        )
                    case .excerpts:
                        recentExcerptsContent(excerpt.recentListSummaries)
                    }
                }
                .padding(.top, WorkbenchTestLibraryMetrics.pageTopPadding)
                .padding(.bottom, WorkbenchTestLibraryMetrics.pageBottomPadding)
                .environment(
                    \.mediaCardGridContainerWidth,
                    WorkbenchControlMetrics.workbenchMediaCardGridWidth(
                        viewportWidth: geometry.size.width
                    )
                )
                .frame(
                    width: geometry.size.width,
                    alignment: .topLeading
                )
                .frame(
                    minHeight: geometry.size.height,
                    alignment: .topLeading
                )
            }
        }
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .cardHighlightFreeze(highlight)
        .onChange(of: routeState.selectedRecentSection) { _ in
            highlight.reset()
            appState.refreshExcerptOnReappearanceIfNeeded()
            appState.refreshRecentOnReappearanceIfNeeded()
        }
        .task {
            appState.hydrateTestRecentWatchingAsync()
            appState.reloadExcerptListOverview()
        }
        .onAppear {
            appState.refreshRecentOnReappearanceIfNeeded()
        }
        .onChange(of: appState.isPlaybackPageVisible) { isVisible in
            if !isVisible {
                appState.reloadExcerptListOverview()
                appState.refreshRecentOnReappearanceIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func recentVideosContent(
        status: LibraryStatus,
        items: [RecentLibraryWatchingPresentation]
    ) -> some View {
        if case .loading = status, items.isEmpty {
            LibraryEmptyHint {
                WorkbenchSpinner()
            }
            .workbenchPageInlinePadding()
        } else if case .failed(let message) = status {
            LibraryEmptyHint(message)
                .workbenchPageInlinePadding()
        } else if items.isEmpty {
            LibraryEmptyHint(L("library.recent_watching_empty"))
                .workbenchPageInlinePadding()
        } else {
            RecentWatchingGrid(
                items: items,
                highlight: highlight,
                onOpen: { item in
                    Task {
                        await appState.openRecentLibraryWatching(item)
                    }
                }
            )
            .workbenchMediaCardGridInlinePadding()
        }
    }

    @ViewBuilder
    private func recentExcerptsContent(
        _ summaries: [ExcerptListSummary]
    ) -> some View {
        if !excerpt.hasLoadedListOverview, summaries.isEmpty {
            LibraryEmptyHint {
                WorkbenchSpinner()
            }
            .workbenchPageInlinePadding()
        } else if summaries.isEmpty {
            LibraryEmptyHint(L("library.recent_excerpts_empty"))
                .workbenchPageInlinePadding()
        } else {
            ExcerptListCardGrid(
                summaries: summaries,
                highlight: highlight,
                groupsByRecentSection: true
            ) { summary in
                appState.openRecentExcerpt(summary)
            }
            .workbenchMediaCardGridInlinePadding()
        }
    }
}

struct WorkbenchTestLibraryView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var routeState: WorkbenchRouteState
    @EnvironmentObject private var library: LibraryStore
    /// The folder list and one folder's detail are two interfaces sharing this
    /// view, so entering the detail starts with nothing lit.
    @StateObject private var highlight = CardHighlightModel(
        keepsCurrentWhenPointerLeaves: false
    )

    private static let libraryOverviewCoordinateSpaceName = "libraryOverviewCoordinateSpace"

    @State private var activeSortMenu: LibrarySortMenuState?
    @State private var sortButtonAnchorFrame: CGRect = .zero
    @StateObject private var sortMenuHighlight = MenuHighlightModel()
    @State private var folderSummaryMoreMenuAnchor = MenuAnchorHandle()

    var body: some View {
        Group {
            if let folderPath = routeState.selectedLibraryFolderPath {
                LibraryCardContextMenuHost(
                    interfaceID: folderPath
                ) { _, toggleAnchorMenu, activeMenuOwnerID in
                    GeometryReader { geometry in
                        WorkbenchScrollView {
                            folderPageContent(
                                folderPath: folderPath,
                                toggleAnchorMenu: toggleAnchorMenu,
                                activeMenuOwnerID: activeMenuOwnerID
                            )
                                .padding(
                                    .top,
                                    WorkbenchControlMetrics.redesignCoverSummaryDetailTopPadding
                                )
                                .padding(
                                    .bottom,
                                    WorkbenchTestLibraryMetrics.pageBottomPadding
                                )
                                .environment(
                                    \.mediaCardGridContainerWidth,
                                    WorkbenchControlMetrics.workbenchMediaCardGridWidth(
                                        viewportWidth: geometry.size.width
                                    )
                                )
                                .frame(
                                    width: geometry.size.width,
                                    alignment: .topLeading
                                )
                                .frame(
                                    minHeight: geometry.size.height,
                                    alignment: .topLeading
                                )
                        }
                    }
                }
            } else {
                GeometryReader { geometry in
                    WorkbenchScrollView {
                        completeLibraryContent(viewportSize: geometry.size)
                            .padding(
                                .top,
                                WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
                            )
                            .padding(
                                .bottom,
                                WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
                            )
                            .environment(
                                \.mediaCardGridContainerWidth,
                                WorkbenchControlMetrics.workbenchMediaCardGridWidth(
                                    viewportWidth: geometry.size.width
                                )
                            )
                            .frame(
                                width: geometry.size.width,
                                alignment: .topLeading
                            )
                            .frame(
                                minHeight: geometry.size.height,
                                alignment: .topLeading
                            )
                    }
                    .coordinateSpace(name: Self.libraryOverviewCoordinateSpaceName)
                    .overlay(alignment: .topLeading) {
                        if let activeSortMenu {
                            let menuFrame = activeSortMenu.menuFrame
                            ZStack(alignment: .topLeading) {
                                MenuGateClientView(
                                    gate: appState.interfaceLayers.menuGate,
                                    owner: .workbenchPage,
                                    kind: .cardMenu,
                                    menuFrame: menuFrame,
                                    anchorFrame: activeSortMenu.anchorFrame,
                                    handleKey: { keyCode, _ in
                                        switch keyCode {
                                        case 53:
                                            dismissSortMenu()
                                            return true
                                        case 126:
                                            _ = sortMenuHighlight.moveHighlight(by: -1)
                                            return true
                                        case 125:
                                            _ = sortMenuHighlight.moveHighlight(by: 1)
                                            return true
                                        case 123, 124:
                                            return true
                                        case 36, 76:
                                            activateHighlightedSortItem()
                                            return true
                                        default:
                                            return false
                                        }
                                    },
                                    dismiss: { _ in
                                        dismissSortMenu()
                                    }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .allowsHitTesting(false)

                                LibrarySortMenuPopover(
                                    selectedOrder: library.sortOrder,
                                    highlight: sortMenuHighlight,
                                    onSelect: { order in
                                        library.sortOrder = order
                                        dismissSortMenu()
                                    },
                                    onDismiss: {
                                        dismissSortMenu()
                                    }
                                )
                                .offset(x: menuFrame.minX, y: menuFrame.minY)
                            }
                            .zIndex(1001)
                        }
                    }
                }
            }
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .cardHighlightFreeze(highlight)
        .onChange(of: routeState.selectedLibraryFolderPath) { _ in
            highlight.reset()
            dismissSortMenu()
        }
        .task {
            appState.hydrateCompleteLibraryAsync()
            appState.hydrateTestRecentWatchingAsync()
        }
        .task(id: folderDetailTaskID) {
            guard let folderPath = selectedFolder?.folderPath else {
                return
            }
            appState.hydrateCompleteLibraryFolderDetailAsync(
                folderPath: folderPath
            )
        }
        .onAppear {
            appState.refreshLibraryOnReappearanceIfNeeded()
        }
    }

    @ViewBuilder
    private func completeLibraryContent(viewportSize: CGSize) -> some View {
        if case .loading = library.completeLibraryStatus, library.completeLibraryFolderSummaries.isEmpty {
            LibraryEmptyHint {
                WorkbenchSpinner()
            }
            .workbenchPageInlinePadding()
        } else if case .failed(let message) = library.completeLibraryStatus {
            LibraryEmptyHint(message)
                .workbenchPageInlinePadding()
        } else if library.completeLibraryFolderSummaries.isEmpty {
            LibraryEmptyHint(L("library.empty"))
                .workbenchPageInlinePadding()
        } else {
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                sortBar(viewportSize: viewportSize)
                    .workbenchPageInlinePadding()

                CompleteLibraryFolderGrid(
                    folders: library.sortedCompleteLibraryFolderSummaries,
                    highlight: highlight,
                    onOpen: { folder in
                        appState.navigateWorkbench(
                            to: .libraryFolder(folderPath: folder.folderPath)
                        )
                    }
                )
                .workbenchMediaCardGridInlinePadding()
            }
        }
    }

    private func sortBar(viewportSize: CGSize) -> some View {
        let folderCount = library.sortedCompleteLibraryFolderSummaries.count
        let countText = folderCount == 1
            ? L("library.folder_count.one")
            : L("library.folder_count.other", folderCount)

        return HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchButton(
                title: library.sortOrder.title,
                icon: .funnelSimple,
                isRedesign: true,
                isOpen: activeSortMenu != nil,
                action: {
                    if activeSortMenu != nil {
                        dismissSortMenu()
                    } else {
                        openSortMenu(anchorFrame: sortButtonAnchorFrame, viewportSize: viewportSize)
                    }
                }
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: LibrarySortAnchorPreferenceKey.self,
                            value: geo.frame(in: .named(Self.libraryOverviewCoordinateSpaceName))
                        )
                }
            )
            .onPreferenceChange(LibrarySortAnchorPreferenceKey.self) { frame in
                sortButtonAnchorFrame = frame
            }

            WorkbenchStatusIndicator(countText)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }

    private func openSortMenu(anchorFrame: CGRect, viewportSize: CGSize) {
        let naturalSize = measuredSortMenuSize()
        let container = CGRect(origin: .zero, size: viewportSize)
        let openingFrame = MenuPlacement.openingFrame(
            anchor: anchorFrame,
            menuSize: naturalSize,
            in: container,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: false
        )
        activeSortMenu = LibrarySortMenuState(
            anchorFrame: anchorFrame,
            menuFrame: openingFrame
        )
        sortMenuHighlight.open(
            selectablePositions: Array(LibrarySortOrder.allCases.indices),
            defaultPosition: 0
        )
    }

    private func dismissSortMenu() {
        activeSortMenu = nil
        sortMenuHighlight.close()
    }

    private func activateHighlightedSortItem() {
        guard let position = sortMenuHighlight.highlightedPosition,
              LibrarySortOrder.allCases.indices.contains(position)
        else {
            return
        }
        let order = LibrarySortOrder.allCases[position]
        library.sortOrder = order
        dismissSortMenu()
    }

    private func measuredSortMenuSize() -> CGSize {
        let host = NSHostingView(
            rootView: LibrarySortMenuPopover(
                selectedOrder: library.sortOrder,
                highlight: sortMenuHighlight,
                onSelect: { _ in },
                onDismiss: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// The history can point at a folder that is no longer indexed; the page
    /// then says so instead of waiting for a detail that will never load.
    @ViewBuilder
    private func folderPageContent(
        folderPath: String,
        toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
        activeMenuOwnerID: String?
    ) -> some View {
        if appState.isWorkbenchRouteUnknown(.libraryFolder(folderPath: folderPath)) {
            WorkbenchEmptyHint(message: L("library.folder.not_found"))
                .workbenchPageInlinePadding()
        } else if let selectedFolder {
            folderDetailContent(
                for: selectedFolder,
                toggleAnchorMenu: toggleAnchorMenu,
                activeMenuOwnerID: activeMenuOwnerID
            )
        } else {
            LibraryEmptyHint {
                WorkbenchSpinner()
            }
            .workbenchPageInlinePadding()
        }
    }

    @ViewBuilder
    private func folderDetailContent(
        for folder: CompleteLibraryFolderSummaryPresentation,
        toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
        activeMenuOwnerID: String?
    ) -> some View {
        if case .loading = folderDetailStatus, folderDetail?.folderPath != folder.folderPath {
            LibraryEmptyHint {
                WorkbenchSpinner()
            }
            .workbenchPageInlinePadding()
        } else if case .failed(let message) = folderDetailStatus {
            LibraryEmptyHint(message)
                .workbenchPageInlinePadding()
        } else if let folderDetail, folderDetail.folderPath == folder.folderPath {
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignCoverSummaryToolbarGap
            ) {
                folderCoverSummary(
                    folder: folder,
                    detail: folderDetail,
                    toggleAnchorMenu: toggleAnchorMenu,
                    activeMenuOwnerID: activeMenuOwnerID
                )
                    .workbenchPageInlinePadding()

                CompleteLibraryEpisodeGrid(
                    folderTitle: folderDetail.folderTitle,
                    videos: folderDetail.videos,
                    highlight: highlight,
                    onOpen: { video in
                        appState.prepareLibraryNavigationVideos(folderDetail.videos)
                        appState.openLibraryVideo(
                            video.libraryVideo,
                            displayTitle: video.displayTitle
                        )
                    }
                )
                .workbenchMediaCardGridInlinePadding()
            }
        } else {
            LibraryEmptyHint {
                WorkbenchSpinner()
            }
            .workbenchPageInlinePadding()
        }
    }

    private func folderCoverSummary(
        folder: CompleteLibraryFolderSummaryPresentation,
        detail: CompleteLibraryFolderDetailPresentation,
        toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
        activeMenuOwnerID: String?
    ) -> some View {
        let recentItem = recentWatchingItem(for: detail)
        let itemCount = detail.videos.count
        let moreMenuOwnerID = "cover-summary-more:\(folder.id)"
        let progress = recentItem.map { item in
            LibraryCoverProgressPresentation(
                positionMilliseconds: item.positionMilliseconds,
                duration: item.playbackDuration ?? item.duration
            ).coverSummaryProgress(episodeNumber: item.episodeNumber)
        }

        return CoverSummaryCard(
            title: detail.folderTitle,
            supportingContent: .metadata(
                primary: L("library.video_subtitle_count", itemCount, itemCount),
                secondary: detail.folderPath
            ),
            progress: progress,
            actionKind: recentItem == nil ? .play : .resume,
            isActionEnabled: isFolderSummaryPlaybackEnabled(
                detail: detail,
                recentItem: recentItem
            ),
            action: {
                openFolderSummaryPlayback(
                    detail: detail,
                    recentItem: recentItem
                )
            },
            secondaryAction: CoverSummarySecondaryAction(
                title: L("library.view_in_file"),
                icon: .folder,
                action: {
                    appState.openLibraryFolderInFile(folderPath: detail.folderPath)
                }
            ),
            moreMenuAnchor: folderSummaryMoreMenuAnchor,
            isMoreMenuOpen: activeMenuOwnerID == moreMenuOwnerID,
            onToggleMoreMenu: {
                toggleAnchorMenu(
                    LibraryFolderCard.contextMenuItems(
                        for: folder,
                        actions: .appState(appState)
                    ),
                    folderSummaryMoreMenuAnchor,
                    moreMenuOwnerID
                )
            }
        ) {
            LibraryCachedCoverImage(
                coverPath: folder.coverPath,
                coverRevision: folder.coverRevision,
                imageVerticalAlignment: .center
            )
        }
    }

    private func isFolderSummaryPlaybackEnabled(
        detail: CompleteLibraryFolderDetailPresentation,
        recentItem: RecentLibraryWatchingPresentation?
    ) -> Bool {
        // A video the database holds can always be opened; a file missing on
        // disk is the player's load failure, not a reason to refuse entry.
        recentItem != nil || !detail.videos.isEmpty
    }

    private func recentWatchingItem(
        for detail: CompleteLibraryFolderDetailPresentation
    ) -> RecentLibraryWatchingPresentation? {
        library.testRecentWatchingItems.first {
            $0.folderPath == detail.folderPath && !$0.updatedAt.isEmpty
        }
    }

    private func openFolderSummaryPlayback(
        detail: CompleteLibraryFolderDetailPresentation,
        recentItem: RecentLibraryWatchingPresentation?
    ) {
        if let recentItem {
            Task {
                await appState.openRecentLibraryWatching(recentItem)
            }
            return
        }

        guard let firstVideo = detail.videos.first else {
            return
        }
        appState.prepareLibraryNavigationVideos(detail.videos)
        appState.openLibraryVideo(
            firstVideo.libraryVideo,
            displayTitle: firstVideo.displayTitle
        )
    }

    private var folderDetailTaskID: String {
        guard let selectedFolder else {
            return ""
        }
        return "\(selectedFolder.folderPath)|\(library.completeLibraryRevision)"
    }

}

private extension WorkbenchTestLibraryView {
    /// The route names the folder by path; the summary is read live, so a
    /// re-index that changes the cover or the count shows without a reload.
    var selectedFolder: CompleteLibraryFolderSummaryPresentation? {
        routeState.selectedLibraryFolderPath.flatMap { folderPath in
            library.completeLibraryFolderSummaries.first {
                $0.folderPath == folderPath
            }
        }
    }

    var folderDetail: CompleteLibraryFolderDetailPresentation? {
        selectedFolder.flatMap {
            library.completeLibraryFolderDetailsByPath[$0.folderPath]
        }
    }

    var folderDetailStatus: LibraryStatus {
        guard let selectedFolder else {
            return .idle
        }
        return library.completeLibraryFolderDetailStatusesByPath[
            selectedFolder.folderPath
        ] ?? .idle
    }
}


private enum WorkbenchTestLibraryMetrics {
    static let pageHorizontalPadding =
        WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
    static let pageTopPadding =
        WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
    static let pageBottomPadding =
        WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
    static let sectionSpacing = WorkbenchControlMetrics.redesignSpacing4
    static let sectionTitleSize = WorkbenchControlMetrics.redesignFontSizeSectionTitle

    static let recentCardGap = WorkbenchControlMetrics.redesignSpacing2
    static let mediaCardHoverPadding = WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding
    static let mediaCardHoverRadius = WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius

    static let coverHoverScale = WorkbenchControlMetrics.redesignLibraryCoverHoverScale
    static let coverHoverDuration = WorkbenchControlMetrics.redesignLibraryCoverHoverDuration

    static let progressBarHeight = WorkbenchControlMetrics.redesignLibraryProgressBarHeight
    static let timeBadgeRadius = WorkbenchControlMetrics.redesignLibraryTimeBadgeRadius
    static let timeBadgeHorizontalPadding = WorkbenchControlMetrics.redesignLibraryTimeBadgeHorizontalPadding
    static let timeBadgeVerticalPadding = WorkbenchControlMetrics.redesignLibraryTimeBadgeVerticalPadding
    static let timeBadgeInset: CGFloat = 6

    static let titleSize = WorkbenchControlMetrics.redesignFontSizeLibraryTitle
    static let metaSize = WorkbenchControlMetrics.redesignFontSizeLibraryMeta
    static let timeBadgeSize = WorkbenchControlMetrics.redesignFontSizeLibraryTimeBadge
}

extension RecentTimeSection {
    var localizedTitle: String {
        switch self {
        case .last7Days:
            return L("recent.section.last_7_days")
        case .last30Days:
            return L("recent.section.last_30_days")
        case .earlier:
            return L("recent.section.earlier")
        case .neverPlayed:
            return L("recent.section.never_played")
        }
    }
}

struct RecentSectionTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeSectionTitle,
                weight: .semibold
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding
            )
    }
}

struct RecentWatchingGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    @Environment(\.libraryCardContextMenuOpen) private var pageContextMenuOpen
    let items: [RecentLibraryWatchingPresentation]
    @ObservedObject var highlight: CardHighlightModel
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (RecentLibraryWatchingPresentation) -> Void

    var body: some View {
        if let pageContextMenuOpen {
            sectionedGrid(openContextMenu: pageContextMenuOpen)
        } else {
            LibraryCardContextMenuHost { sectionedGrid(openContextMenu: $0) }
        }
    }

    private func sectionedGrid(
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        let sections = RecentTimeSection.group(
            items,
            timestamp: \.updatedAt
        )
        return VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing3
        ) {
            ForEach(sections, id: \.section) { entry in
                VStack(
                    alignment: .leading,
                    spacing: WorkbenchControlMetrics.redesignSpacing3
                ) {
                    RecentSectionTitleView(title: entry.section.localizedTitle)

                    LibraryOverviewGrid {
                        ForEach(entry.items) { item in
                            LibraryVideoCard(
                                content: LibraryVideoCardContent(item),
                                highlight: highlight,
                                isSelected: highlight.isSelected(item.id),
                                isHovered: highlight.isHovered(item.id),
                                actions: .appState(appState),
                                openContextMenu: openContextMenu,
                                onOpen: { onOpen(item) }
                            )
                            .background {
                                if let itemFrameCoordinateSpace {
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: LibraryItemFramePreferenceKey.self,
                                            value: [
                                                item.id: proxy.frame(
                                                    in: .named(itemFrameCoordinateSpace)
                                                )
                                            ]
                                        )
                                    }
                                }
                            }
                            .id(item.id)
                        }
                    }
                }
            }
        }
        .onPreferenceChange(LibraryItemFramePreferenceKey.self) { frames in
            guard itemFrameCoordinateSpace != nil else {
                return
            }
            onItemFramesChange(frames)
        }
    }
}

private struct LibraryVideoCardGrid<Item: Identifiable>: View
where Item.ID == String {
    @EnvironmentObject private var appState: AppCoordinator
    /// Set when the page already hosts the menu at its own root. The grid then
    /// uses that host, so the menu covers the whole page instead of only the
    /// grid it was opened from.
    @Environment(\.libraryCardContextMenuOpen) private var pageContextMenuOpen
    let items: [Item]
    @ObservedObject var highlight: CardHighlightModel
    let itemFrameCoordinateSpace: String?
    let onItemFramesChange: ([String: CGRect]) -> Void
    let content: (Item) -> LibraryVideoCardContent
    let onOpen: (Item) -> Void

    var body: some View {
        if let pageContextMenuOpen {
            grid(openContextMenu: pageContextMenuOpen)
        } else {
            LibraryCardContextMenuHost { grid(openContextMenu: $0) }
        }
    }

    private func grid(
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        LibraryOverviewGrid {
            ForEach(items) { item in
                LibraryVideoCard(
                    content: content(item),
                    highlight: highlight,
                    isSelected: highlight.isSelected(item.id),
                    isHovered: highlight.isHovered(item.id),
                    actions: .appState(appState),
                    openContextMenu: openContextMenu,
                    onOpen: { onOpen(item) }
                )
                .background {
                    if let itemFrameCoordinateSpace {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: LibraryItemFramePreferenceKey.self,
                                value: [
                                    item.id: proxy.frame(
                                        in: .named(itemFrameCoordinateSpace)
                                    )
                                ]
                            )
                        }
                    }
                }
                .id(item.id)
            }
        }
        .onPreferenceChange(LibraryItemFramePreferenceKey.self) { frames in
            guard itemFrameCoordinateSpace != nil else {
                return
            }
            onItemFramesChange(frames)
        }
    }
}

/// Shared by the video card grid and the Excerpt card grid: both report where
/// their cards sit so the Command Panel can walk them with the arrow keys.
struct LibraryItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(
        value: inout [String: CGRect],
        nextValue: () -> [String: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

@MainActor
private struct LibraryCardActionHandlers {
    let revealFile: (String) -> Void
    let openFolder: (String) -> Void
    let changeCover: (LibraryUserCoverTarget, String?, String?) -> Void
    let markVideo: (LibraryVideo, LibraryWatchState) -> Void
    let markFolder: (String, LibraryWatchState) -> Void

    static func appState(_ appState: AppCoordinator) -> LibraryCardActionHandlers {
        LibraryCardActionHandlers(
            revealFile: { appState.revealFile(atPath: $0) },
            openFolder: { appState.openFolder(atPath: $0) },
            changeCover: { target, coverPath, coverRevision in
                appState.beginChangingLibraryCover(
                    target: target,
                    currentCoverPath: coverPath,
                    currentCoverRevision: coverRevision
                )
            },
            markVideo: { appState.markLibraryVideo($0, as: $1) },
            markFolder: { appState.markCompleteLibraryFolder(folderPath: $0, as: $1) }
        )
    }
}

private struct LibraryVideoCardContent {
    let videoPath: String
    let folderTitle: String
    let episodeNumber: Int
    let positionMilliseconds: Int
    let duration: Double?
    let coverPath: String?
    let coverRevision: String?
    let watchStatus: LibraryWatchStatus
    let libraryVideo: LibraryVideo

    init(_ item: RecentLibraryWatchingPresentation) {
        videoPath = item.videoPath
        folderTitle = item.folderTitle
        episodeNumber = item.episodeNumber
        positionMilliseconds = item.positionMilliseconds
        duration = item.playbackDuration ?? item.duration
        coverPath = item.coverPath
        coverRevision = item.coverRevision
        watchStatus = LibraryWatchStatus(item.watchState)
        libraryVideo = item.libraryVideo
    }

    init(
        folderTitle: String,
        video: CompleteLibraryVideoPresentation
    ) {
        videoPath = video.videoPath
        self.folderTitle = folderTitle
        episodeNumber = video.episodeNumber
        positionMilliseconds = video.positionMilliseconds
        duration = video.playbackDuration ?? video.duration
        coverPath = video.coverPath
        coverRevision = video.coverRevision
        watchStatus = LibraryWatchStatus(video.watchState)
        libraryVideo = video.libraryVideo
    }
}

private struct LibraryVideoCard: View {
    let content: LibraryVideoCardContent
    let highlight: CardHighlightModel
    let isSelected: Bool
    let isHovered: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    let onOpen: () -> Void

    private var cardID: String {
        content.videoPath
    }

    private var isHighlighted: Bool {
        isSelected || isHovered
    }

    var body: some View {
        Button {
            highlight.notePress(id: cardID)
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.recentCardGap) {
                cover

                Text(content.folderTitle)
                    .font(.system(size: WorkbenchTestLibraryMetrics.titleSize, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Text(episodeLabel)
                        .font(.system(size: WorkbenchTestLibraryMetrics.metaSize, weight: .medium))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .monospacedDigit()

                    WatchStatusBadge(status: content.watchStatus)
                }
            }
        }
        .buttonStyle(
            LibraryOverviewCardButtonStyle(
                isSelected: isSelected,
                isHovered: isHovered
            )
        )
        .focusable(false)
        .onHover { highlight.noteHover($0, id: cardID, showsHand: true) }
        .libraryCardContextMenuTrigger(
            isEnabled: true,
            ownerID: cardID,
            items: contextMenuItems,
            openContextMenu: { items, point, ownerID in
                highlight.notePress(id: cardID)
                openContextMenu(items, point, ownerID)
            }
        )
        .accessibilityLabel(
            "\(content.folderTitle), \(episodeLabel), \(content.watchStatus.title)"
        )
    }

    private var cover: some View {
        LibraryCoverWithProgress(
            coverPath: content.coverPath,
            coverRevision: content.coverRevision,
            positionMilliseconds: content.positionMilliseconds,
            duration: content.duration
        )
        .libraryCoverHoverEffect(
            isActive: isHighlighted
        )
    }

    private var contextMenuItems: [LibraryCardContextMenuItem] {
        [
            LibraryCardContextMenuItem(title: L("library.open_folder"), icon: .folder) {
                actions.revealFile(content.videoPath)
            },
            LibraryCardContextMenuItem(
                title: LibraryCoverContextMenuItem.title,
                icon: LibraryCoverContextMenuItem.icon
            ) {
                actions.changeCover(
                    .video(path: content.videoPath),
                    content.coverPath,
                    content.coverRevision
                )
            },
            LibraryCardContextMenuItem(title: L("library.mark_finished"), icon: .checkCircle) {
                actions.markVideo(content.libraryVideo, .finished)
            },
            LibraryCardContextMenuItem(title: L("library.mark_unwatched"), icon: .circle) {
                actions.markVideo(content.libraryVideo, .unwatched)
            },
            LibraryCardContextMenuItem(title: L("library.mark_watching"), icon: .playCircle) {
                actions.markVideo(content.libraryVideo, .watching)
            }
        ]
    }

    private var episodeLabel: String {
        String(format: "EP%02d", content.episodeNumber)
    }
}

struct CompleteLibraryFolderGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    let folders: [CompleteLibraryFolderSummaryPresentation]
    @ObservedObject var highlight: CardHighlightModel
    let onOpen: (CompleteLibraryFolderSummaryPresentation) -> Void

    var body: some View {
        LibraryCardContextMenuHost { openContextMenu in
            LibraryOverviewGrid {
                ForEach(folders) { folder in
                    LibraryFolderCard(
                        folder: folder,
                        highlight: highlight,
                        isSelected: highlight.isSelected(folder.id),
                        isHovered: highlight.isHovered(folder.id),
                        actions: .appState(appState),
                        openContextMenu: openContextMenu
                    ) {
                        onOpen(folder)
                    }
                }
            }
        }
    }
}

private struct LibraryFolderCard: View {
    let folder: CompleteLibraryFolderSummaryPresentation
    let highlight: CardHighlightModel
    let isSelected: Bool
    let isHovered: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    let onOpen: () -> Void

    private var isAvailable: Bool {
        folder.episodeCount > 0
    }

    private var cardID: String {
        folder.id
    }

    private var isHighlighted: Bool {
        isSelected || isHovered
    }

    var body: some View {
        Button {
            guard isAvailable else {
                return
            }
            highlight.notePress(id: cardID)
            onOpen()
        } label: {
            LibraryOverviewCardContent(title: folder.folderTitle) {
                cover
            }
        }
        .buttonStyle(
            LibraryOverviewCardButtonStyle(
                isSelected: isSelected,
                isHovered: isHovered,
                isEnabled: isAvailable
            )
        )
        .disabled(!isAvailable)
        .onHover { highlight.noteHover($0, id: cardID, showsHand: isAvailable) }
        .libraryCardContextMenuTrigger(
            isEnabled: isAvailable,
            ownerID: cardID,
            items: folderContextMenuItems,
            openContextMenu: { items, point, ownerID in
                highlight.notePress(id: cardID)
                openContextMenu(items, point, ownerID)
            }
        )
        .accessibilityLabel(folder.folderTitle)
    }

    private var cover: some View {
        LibraryCoverWithBadge(
            coverPath: folder.coverPath,
            coverRevision: folder.coverRevision,
            badgeText: episodeCountText
        )
        .libraryCoverHoverEffect(
            isActive: isHighlighted && isAvailable
        )
    }

    private var folderContextMenuItems: [LibraryCardContextMenuItem] {
        Self.contextMenuItems(for: folder, actions: actions)
    }

    static func contextMenuItems(
        for folder: CompleteLibraryFolderSummaryPresentation,
        actions: LibraryCardActionHandlers
    ) -> [LibraryCardContextMenuItem] {
        [
            LibraryCardContextMenuItem(title: L("library.open_folder"), icon: .folder) {
                actions.openFolder(folder.folderPath)
            },
            LibraryCardContextMenuItem(
                title: LibraryCoverContextMenuItem.title,
                icon: LibraryCoverContextMenuItem.icon
            ) {
                actions.changeCover(
                    .folder(path: folder.folderPath),
                    folder.coverPath,
                    folder.coverRevision
                )
            },
            LibraryCardContextMenuItem(title: L("library.mark_all_finished"), icon: .checkCircle) {
                actions.markFolder(folder.folderPath, .finished)
            },
            LibraryCardContextMenuItem(title: L("library.mark_all_unwatched"), icon: .circle) {
                actions.markFolder(folder.folderPath, .unwatched)
            },
            LibraryCardContextMenuItem(title: L("library.mark_all_watching"), icon: .playCircle) {
                actions.markFolder(folder.folderPath, .watching)
            }
        ]
    }

    private var episodeCountText: String {
        folder.episodeCount == 1
            ? L("library.episode_count.one")
            : L("library.episode_count.other", folder.episodeCount)
    }
}

struct CompleteLibraryEpisodeGrid: View {
    let folderTitle: String
    let videos: [CompleteLibraryVideoPresentation]
    @ObservedObject var highlight: CardHighlightModel
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (CompleteLibraryVideoPresentation) -> Void

    var body: some View {
        if videos.isEmpty {
            LibraryEmptyHint(L("library.episodes_empty"))
        } else {
            LibraryVideoCardGrid(
                items: videos,
                highlight: highlight,
                itemFrameCoordinateSpace: itemFrameCoordinateSpace,
                onItemFramesChange: onItemFramesChange,
                content: {
                    LibraryVideoCardContent(
                        folderTitle: folderTitle,
                        video: $0
                    )
                },
                onOpen: onOpen
            )
        }
    }
}

private enum LibraryCardContextMenuCoordinateSpace {
    static let name = "LibraryCardContextMenuCoordinateSpace"
}

/// The card whose menu is open reports its new anchor through this, so the menu
/// travels with the card when the page scrolls or the grid reflows.
private struct LibraryCardContextMenuAnchorUpdateKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ((CGPoint) -> Void)? = nil
}

/// Which card the open menu belongs to, or nil when no menu is open.
private struct LibraryCardContextMenuOwnerKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

/// The nearest enclosing host's opener. A page that hosts the menu at its own
/// root publishes it here, so a grid inside that page hands its cards the page's
/// host instead of standing up one of its own.
private struct LibraryCardContextMenuOpenKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (([LibraryCardContextMenuItem], CGPoint, String) -> Void)? = nil
}

private struct LibraryCardContextMenuToggleAnchorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void)? = nil
}

extension EnvironmentValues {
    var libraryCardContextMenuAnchorUpdate: ((CGPoint) -> Void)? {
        get { self[LibraryCardContextMenuAnchorUpdateKey.self] }
        set { self[LibraryCardContextMenuAnchorUpdateKey.self] = newValue }
    }

    var libraryCardContextMenuOpen: (([LibraryCardContextMenuItem], CGPoint, String) -> Void)? {
        get { self[LibraryCardContextMenuOpenKey.self] }
        set { self[LibraryCardContextMenuOpenKey.self] = newValue }
    }

    var libraryCardContextMenuToggleAnchor: (([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void)? {
        get { self[LibraryCardContextMenuToggleAnchorKey.self] }
        set { self[LibraryCardContextMenuToggleAnchorKey.self] = newValue }
    }

    /// The card the open menu hangs off. A card that matches keeps its
    /// highlight while every other card is frozen.
    var libraryCardContextMenuOwner: String? {
        get { self[LibraryCardContextMenuOwnerKey.self] }
        set { self[LibraryCardContextMenuOwnerKey.self] = newValue }
    }
}

struct LibraryCardContextMenuItem: Identifiable {
    let title: String
    let icon: AppIcon
    var isEnabled = true
    let action: () -> Void

    var id: String {
        title
    }
}

enum LibraryCoverContextMenuItem {
    static let title = L("library.change_cover")
    static let icon = AppIcon.export
}

private struct LibraryCardContextMenuState: Identifiable {
    let id = UUID()
    /// Which card or control the menu hangs off. The card compares it with its
    /// own id to decide whether it is the one that stays lit.
    let ownerID: String
    var anchorPoint: CGPoint
    var anchorSize: CGSize = .zero
    var anchorFrame: CGRect? = nil
    let items: [LibraryCardContextMenuItem]
    /// Measured and decided when the menu opened. From then on the menu only
    /// translates, so nothing can send it to the other side mid-scroll.
    let menuSize: CGSize
    /// The room the side it opened on had for it, when that was less than the
    /// menu wanted. It scrolls the rest, and keeps this for as long as it stays
    /// open.
    let maximumHeight: CGFloat
    let placementOffset: CGSize
}

/// Answers "how much of this page can the reader see", which is what a menu
/// measures the room below a card against. Asked at the moment of the click, the
/// way the table asks its own scroll view, so nothing has to be published ahead
/// of time or kept in step.
@MainActor
private final class LibraryCardMenuHostGeometry {
    weak var probe: LibraryCardMenuViewportProbe.ProbeView?

    var visibleRect: CGRect {
        guard let probe else {
            return .zero
        }
        // A page that is not inside a scroll view is visible in full.
        let visible = probe.visibleRect
        return visible.isEmpty ? probe.bounds : visible
    }

    func anchorFrame(for handle: MenuAnchorHandle) -> CGRect? {
        guard let probe, let windowFrame = handle.windowFrame, probe.window != nil else {
            return nil
        }
        return probe.convert(windowFrame, from: nil)
    }
}

/// Sits behind the page at its exact size and reports what of it is unclipped.
private struct LibraryCardMenuViewportProbe: NSViewRepresentable {
    let geometry: LibraryCardMenuHostGeometry

    func makeNSView(context _: Context) -> ProbeView {
        let view = ProbeView()
        geometry.probe = view
        return view
    }

    func updateNSView(_ nsView: ProbeView, context _: Context) {
        geometry.probe = nsView
    }

    final class ProbeView: NSView {
        /// SwiftUI measures top-left down; this view has to answer in the same
        /// direction or every "below" becomes an "above".
        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

struct LibraryCardContextMenuHost<Content: View>: View {
    @Environment(\.interfaceLayers) private var interfaceLayers
    /// The menu belongs to the layer its cards are on. Registering it against
    /// the workbench page from inside the Command Panel hands the gate a menu
    /// it considers covered, so the menu takes no keys, no outside press and
    /// no scroll ban, and the panel's own cards keep following the pointer.
    @Environment(\.interfaceLayerContext) private var layerContext
    /// Names the interface whose cards this host is showing. A host that spans
    /// several interfaces — the Recent page hosts one menu for its overview and
    /// both of its sections — closes the menu when the interface changes under
    /// it, because the card it hangs off is no longer on screen.
    var interfaceID: String = ""
    @State private var activeMenu: LibraryCardContextMenuState?
    @StateObject private var highlight = MenuHighlightModel()
    @State private var geometry = LibraryCardMenuHostGeometry()
    private let buildContent: (
        _ openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void,
        _ toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
        _ activeOwnerID: String?
    ) -> Content

    init(
        interfaceID: String = "",
        @ViewBuilder content: @escaping (_ openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void) -> Content
    ) {
        self.interfaceID = interfaceID
        self.buildContent = { openContextMenu, _, _ in
            content(openContextMenu)
        }
    }

    init(
        interfaceID: String = "",
        @ViewBuilder content: @escaping (
            _ openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void,
            _ toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
            _ activeOwnerID: String?
        ) -> Content
    ) {
        self.interfaceID = interfaceID
        self.buildContent = content
    }

    var body: some View {
        buildContent(openContextMenu, toggleAnchorMenu, activeMenu?.ownerID)
            .onChange(of: interfaceID) { _ in
                dismissContextMenu()
            }
            .environment(\.libraryCardContextMenuAnchorUpdate, updateAnchorPoint)
            .environment(\.libraryCardContextMenuOpen, openContextMenu)
            .environment(\.libraryCardContextMenuToggleAnchor, toggleAnchorMenu)
            .environment(\.libraryCardContextMenuOwner, activeMenu?.ownerID)
            .coordinateSpace(name: LibraryCardContextMenuCoordinateSpace.name)
            .background(LibraryCardMenuViewportProbe(geometry: geometry))
            .overlay(alignment: .topLeading) {
                if let activeMenu {
                    let menuFrame = menuFrame(for: activeMenu)
                    ZStack(alignment: .topLeading) {
                        MenuGateClientView(
                            gate: interfaceLayers?.menuGate,
                            owner: layerContext.layer,
                            // On a playback layer the key owner offers keys to
                            // the gate before the Command Panel navigates, so
                            // the menu must take them there.
                            kind: .cardMenu,
                            menuFrame: menuFrame,
                            anchorFrame: activeMenu.anchorFrame,
                            handleKey: { keyCode, _ in
                                // Every arrow and Enter belongs to the open
                                // menu; the card grid and the page under it
                                // must not respond to any of them.
                                switch keyCode {
                                case 53:
                                    dismissContextMenu()
                                    return true
                                case 126:
                                    _ = highlight.moveHighlight(by: -1)
                                    return true
                                case 125:
                                    _ = highlight.moveHighlight(by: 1)
                                    return true
                                case 123, 124:
                                    return true
                                case 36, 76:
                                    _ = activateHighlightedItem()
                                    return true
                                default:
                                    return false
                                }
                            },
                            dismiss: { _ in
                                dismissContextMenu(openedAs: activeMenu.id)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)

                        LibraryCardContextMenu(
                            items: activeMenu.items,
                            highlight: highlight,
                            maximumHeight: activeMenu.maximumHeight,
                            onDismiss: { dismissContextMenu() }
                        )
                        .offset(
                            CGSize(
                                width: menuFrame.minX,
                                height: menuFrame.minY
                            )
                        )
                    }
                    .id(activeMenu.id)
                    .zIndex(1000)
                }
            }
    }

    /// Measures the menu, chooses its side once, and remembers the offset — the
    /// same order the table's menus follow.
    private func openContextMenu(
        items: [LibraryCardContextMenuItem],
        anchorPoint: CGPoint,
        ownerID: String
    ) {
        openMenu(
            items: items,
            anchor: CGRect(origin: anchorPoint, size: .zero),
            anchorFrame: nil,
            ownerID: ownerID
        )
    }

    private func toggleAnchorMenu(
        items: [LibraryCardContextMenuItem],
        anchor: MenuAnchorHandle,
        ownerID: String
    ) {
        if activeMenu?.ownerID == ownerID {
            dismissContextMenu()
            return
        }
        guard let anchorRect = geometry.anchorFrame(for: anchor) else {
            return
        }
        openMenu(
            items: items,
            anchor: anchorRect,
            anchorFrame: anchorRect,
            ownerID: ownerID
        )
    }

    private func openMenu(
        items: [LibraryCardContextMenuItem],
        anchor: CGRect,
        anchorFrame: CGRect?,
        ownerID: String
    ) {
        let naturalSize = measuredMenuSize(
            for: items,
            maximumHeight: MenuMetrics.maximumHeight
        )
        let place = { (menuSize: CGSize) in
            MenuPlacement.openingFrame(
                anchor: anchor,
                menuSize: menuSize,
                in: geometry.visibleRect,
                gap: WorkbenchControlMetrics.redesignSpacing1,
                shrinksToFit: true
            )
        }
        var menuSize = naturalSize
        var maximumHeight = MenuMetrics.maximumHeight
        var openingFrame = place(naturalSize)
        if openingFrame.height < naturalSize.height {
            // Held to the room on its side, the menu gains its scrollbar and
            // widens, so it is measured and placed again.
            maximumHeight = openingFrame.height
            menuSize = measuredMenuSize(for: items, maximumHeight: maximumHeight)
            openingFrame = place(menuSize)
        }
        activeMenu = LibraryCardContextMenuState(
            ownerID: ownerID,
            anchorPoint: anchor.origin,
            anchorSize: anchor.size,
            anchorFrame: anchorFrame,
            items: items,
            menuSize: menuSize,
            maximumHeight: maximumHeight,
            placementOffset: MenuPlacement.offset(from: anchor, to: openingFrame)
        )
        highlight.open(
            selectablePositions: items.indices.filter { items[$0].isEnabled }
        )
    }

    private func measuredMenuSize(
        for items: [LibraryCardContextMenuItem],
        maximumHeight: CGFloat
    ) -> CGSize {
        let host = NSHostingView(
            rootView: LibraryCardContextMenu(
                items: items,
                highlight: highlight,
                maximumHeight: maximumHeight,
                onDismiss: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// Closes the menu that was open when the caller decided to close it. A
    /// right-click relay opens the next menu on the same press, and the order
    /// two event monitors run in is not ours to choose, so a late dismissal
    /// must not take the new menu with it.
    private func dismissContextMenu(openedAs id: UUID? = nil) {
        if let id, activeMenu?.id != id {
            return
        }
        activeMenu = nil
        highlight.close()
    }

    /// Moves the open menu with its card. The side it opened on is already in
    /// `placementOffset`, so this is pure translation.
    private func updateAnchorPoint(_ anchorPoint: CGPoint) {
        guard activeMenu != nil, activeMenu?.anchorPoint != anchorPoint else {
            return
        }
        activeMenu?.anchorPoint = anchorPoint
    }

    /// Enter runs whatever the highlight sits on, so the keyboard and the
    /// pointer commit through one path.
    @discardableResult
    private func activateHighlightedItem() -> Bool {
        guard let position = highlight.highlightedPosition,
              let items = activeMenu?.items,
              items.indices.contains(position),
              items[position].isEnabled
        else {
            return false
        }
        let item = items[position]
        dismissContextMenu()
        item.action()
        return true
    }

    /// Pure translation. The side and the distance were settled when the menu
    /// opened, so a scrolling page moves the menu and never re-decides it.
    private func menuFrame(for menu: LibraryCardContextMenuState) -> CGRect {
        MenuPlacement.followingFrame(
            anchor: CGRect(origin: menu.anchorPoint, size: menu.anchorSize),
            offset: menu.placementOffset,
            menuSize: menu.menuSize
        )
    }
}

private struct LibraryCardContextMenu: View {
    let items: [LibraryCardContextMenuItem]
    @ObservedObject var highlight: MenuHighlightModel
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            isRedesign: true,
            maximumHeight: maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { position, item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        icon: item.icon,
                        isRedesign: true,
                        showsCheckmarkSlot: false,
                        isEnabled: item.isEnabled,
                        action: {
                            onDismiss()
                            item.action()
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
            .frame(minWidth: 220, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct LibraryCardContextMenuTriggerModifier: ViewModifier {
    let isEnabled: Bool
    let ownerID: String
    let items: [LibraryCardContextMenuItem]
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.libraryCardContextMenuOwner) private var contextMenuOwnerID
    @Environment(\.libraryCardContextMenuAnchorUpdate) private var updateAnchor
    /// Set on the one card the open menu belongs to, so only that card reports
    /// where it moved to.
    @State private var localAnchorPoint: CGPoint?

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(LibraryCardContextMenuCoordinateSpace.name))
                // An open menu is not a reason to refuse: the press that
                // closed it is the same press that opens this card's menu.
                LibraryCardRightClickMonitor(
                    isEnabled: isEnabled && !layerContext.isCovered,
                    menuGate: interfaceLayers?.menuGate
                ) { localPoint in
                    localAnchorPoint = localPoint
                    openContextMenu(
                        items,
                        CGPoint(
                            x: frame.minX + localPoint.x,
                            y: frame.minY + localPoint.y
                        ),
                        ownerID
                    )
                }
                .onChange(of: frame.origin) { origin in
                    guard contextMenuOwnerID != nil, let localAnchorPoint else {
                        return
                    }
                    updateAnchor?(
                        CGPoint(
                            x: origin.x + localAnchorPoint.x,
                            y: origin.y + localAnchorPoint.y
                        )
                    )
                }
                .onChange(of: contextMenuOwnerID == nil) { isClosed in
                    if isClosed {
                        localAnchorPoint = nil
                    }
                }
            }
        )
    }
}

private struct LibraryCardRightClickMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let menuGate: MenuGate?
    let onRightClick: (CGPoint) -> Void

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(
            isEnabled: isEnabled,
            menuGate: menuGate,
            onRightClick: onRightClick
        )
    }

    final class MonitoringView: NSView {
        nonisolated(unsafe) private var monitor: Any?
        private var isEnabled = false
        private weak var menuGate: MenuGate?
        private var onRightClick: ((CGPoint) -> Void)?

        override var isFlipped: Bool {
            true
        }

        func update(
            isEnabled: Bool,
            menuGate: MenuGate?,
            onRightClick: @escaping (CGPoint) -> Void
        ) {
            self.isEnabled = isEnabled
            self.menuGate = menuGate
            self.onRightClick = onRightClick
            updateMonitor()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateMonitor()
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func updateMonitor() {
            guard isEnabled, window != nil else {
                removeMonitor()
                return
            }
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
                guard let self else {
                    return event
                }
                guard event.window === self.window else {
                    return event
                }

                let localPoint = self.convert(event.locationInWindow, from: nil)
                // Only the part of the card the reader can actually see answers:
                // a card the page has scrolled out of view must not claim a
                // press made over whatever covers it.
                guard self.bounds.intersection(self.visibleRect).contains(localPoint) else {
                    return event
                }

                // Card monitors are installed when cards appear, before any
                // menu opens, so they see a right-click before the gate's own
                // monitor does. Routing through the gate first lets an open
                // menu swallow a right-click inside its own surface or close
                // before this card opens its menu.
                if let menuGate = self.menuGate {
                    guard menuGate.route(event) != nil else {
                        return nil
                    }
                }

                self.onRightClick?(localPoint)
                return nil
            }
        }

        private func removeMonitor() {
            guard let monitor else {
                return
            }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

private struct LibraryCoverHoverEffectModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? WorkbenchTestLibraryMetrics.coverHoverScale : 1)
            .animation(.easeOut(duration: WorkbenchTestLibraryMetrics.coverHoverDuration), value: isActive)
    }
}

extension View {
    func libraryCardContextMenuTrigger(
        isEnabled: Bool,
        ownerID: String,
        items: [LibraryCardContextMenuItem],
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        modifier(
            LibraryCardContextMenuTriggerModifier(
                isEnabled: isEnabled,
                ownerID: ownerID,
                items: items,
                openContextMenu: openContextMenu
            )
        )
    }

    func libraryCoverHoverEffect(isActive: Bool) -> some View {
        modifier(LibraryCoverHoverEffectModifier(isActive: isActive))
    }
}

struct LibraryCoverWithProgress: View {
    let coverPath: String?
    let coverRevision: String?
    let positionMilliseconds: Int
    let duration: Double?

    private var presentation: LibraryCoverProgressPresentation {
        LibraryCoverProgressPresentation(
            positionMilliseconds: positionMilliseconds,
            duration: duration
        )
    }

    private var progressFraction: Double? {
        presentation.progressFraction
    }

    var body: some View {
        LibraryCoverFrame {
            ZStack(alignment: .bottomLeading) {
                coverImage

                if let progressFraction {
                    progressTrack(progressFraction: progressFraction)
                }

                Text(timeBadgeText)
                    .font(.system(size: WorkbenchTestLibraryMetrics.timeBadgeSize, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.libraryTimeBadgeText)
                    .monospacedDigit()
                    .padding(.horizontal, WorkbenchTestLibraryMetrics.timeBadgeHorizontalPadding)
                    .padding(.vertical, WorkbenchTestLibraryMetrics.timeBadgeVerticalPadding)
                    .background(
                        RoundedRectangle(
                            cornerRadius: WorkbenchTestLibraryMetrics.timeBadgeRadius,
                            style: .continuous
                        )
                        .fill(WorkbenchRedesignColors.libraryTimeBadgeBg)
                    )
                    .padding(.trailing, WorkbenchTestLibraryMetrics.timeBadgeInset)
                    .padding(.bottom, WorkbenchTestLibraryMetrics.timeBadgeInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private var coverImage: some View {
        LibraryCachedCoverImage(
            coverPath: coverPath,
            coverRevision: coverRevision
        )
    }

    private func progressTrack(progressFraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(WorkbenchRedesignColors.libraryProgressTrack)

                Rectangle()
                    .fill(WorkbenchRedesignColors.libraryProgressFill)
                    .frame(width: proxy.size.width * progressFraction)
            }
        }
        .frame(height: WorkbenchTestLibraryMetrics.progressBarHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var timeBadgeText: String {
        presentation.timeBadgeText
    }
}

struct LibraryCoverProgressPresentation: Equatable {
    let positionMilliseconds: Int
    let duration: Double?

    var progressFraction: Double? {
        guard let duration, duration.isFinite, duration > 0 else {
            return nil
        }

        let durationMilliseconds = duration * 1_000
        guard durationMilliseconds > 0 else {
            return nil
        }

        let progress = min(1, max(0, Double(max(0, positionMilliseconds)) / durationMilliseconds))
        return progress > 0 ? progress : nil
    }

    var timeBadgeText: String {
        guard let duration, duration.isFinite, duration > 0 else {
            return Self.formatTime(milliseconds: positionMilliseconds)
        }

        let current = Self.formatTime(milliseconds: positionMilliseconds)
        return "\(current)/\(Self.formatTime(seconds: duration))"
    }

    func coverSummaryProgress(episodeNumber: Int) -> CoverSummaryProgress {
        let episodeLabel = String(format: "EP%02d", episodeNumber)
        let current = Self.formatTime(milliseconds: positionMilliseconds)
        let timeText: String
        let fraction: Double
        if let duration, duration.isFinite, duration > 0 {
            timeText = "\(current) / \(Self.formatTime(seconds: duration))"
            let durationMilliseconds = duration * 1_000
            fraction = durationMilliseconds > 0
                ? min(1, max(0, Double(max(0, positionMilliseconds)) / durationMilliseconds))
                : 0
        } else {
            timeText = current
            fraction = 0
        }
        return CoverSummaryProgress(
            labelText: "\(episodeLabel)  \(timeText)",
            fraction: fraction
        )
    }

    private static func formatTime(milliseconds: Int) -> String {
        formatTime(seconds: Double(max(0, milliseconds)) / 1_000)
    }

    private static func formatTime(seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct LibraryCoverWithBadge: View {
    let coverPath: String?
    let coverRevision: String?
    let badgeText: String

    var body: some View {
        LibraryCoverFrame {
            ZStack(alignment: .bottomTrailing) {
                LibraryCachedCoverImage(
                    coverPath: coverPath,
                    coverRevision: coverRevision
                )

                Text(badgeText)
                    .font(.system(size: WorkbenchTestLibraryMetrics.timeBadgeSize, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.libraryTimeBadgeText)
                    .monospacedDigit()
                    .padding(.horizontal, WorkbenchTestLibraryMetrics.timeBadgeHorizontalPadding)
                    .padding(.vertical, WorkbenchTestLibraryMetrics.timeBadgeVerticalPadding)
                    .background(
                        RoundedRectangle(
                            cornerRadius: WorkbenchTestLibraryMetrics.timeBadgeRadius,
                            style: .continuous
                        )
                        .fill(WorkbenchRedesignColors.libraryTimeBadgeBg)
                    )
                    .padding(.trailing, WorkbenchTestLibraryMetrics.timeBadgeInset)
                    .padding(.bottom, WorkbenchTestLibraryMetrics.timeBadgeInset)
            }
        }
    }
}

struct LibraryCachedCoverImage: View {
    let coverPath: String?
    let coverRevision: String?
    var imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top

    @State private var loadedImage: LoadedImage?
    @State private var activeRequestID: UUID?
    @State private var loadFailed = false

    private struct LoadedImage {
        let key: LibraryCoverImageKey
        let image: CGImage
    }

    private var key: LibraryCoverImageKey? {
        LibraryCoverImageKey.current(path: coverPath, revision: coverRevision)
    }

    private var currentImage: CGImage? {
        if let key, let loadedImage, loadedImage.key == key {
            return loadedImage.image
        }
        if let key, let cached = LibraryCoverImagePipeline.shared.cachedImage(for: key) {
            return cached
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let currentImage {
                LibraryCoverFillImage(
                    image: currentImage,
                    verticalAlignment: imageVerticalAlignment
                )
            } else if key != nil && !loadFailed {
                Color.clear
            } else {
                defaultCover
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: key) {
            await loadImage(for: key)
        }
        .onDisappear {
            activeRequestID = nil
        }
    }

    private var defaultCover: some View {
        ZStack {
            Rectangle()
                .fill(WorkbenchRedesignColors.libraryCoverPlaceholderBg)

            AppIconImage(.video, size: WorkbenchControlMetrics.redesignCoverPlaceholderIconSize)
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .accessibilityHidden(true)
        }
    }

    @MainActor
    private func loadImage(for key: LibraryCoverImageKey?) async {
        guard let key else {
            activeRequestID = nil
            loadedImage = nil
            loadFailed = false
            return
        }

        if let cached = LibraryCoverImagePipeline.shared.cachedImage(for: key) {
            activeRequestID = nil
            loadedImage = LoadedImage(key: key, image: cached)
            loadFailed = false
            return
        }

        let requestID = UUID()
        activeRequestID = requestID

        if loadedImage?.key != key {
            loadFailed = false
        }

        do {
            let image = try await LibraryCoverImagePipeline.shared.image(for: key)
            try Task.checkCancellation()

            guard activeRequestID == requestID else {
                return
            }

            if let image {
                loadedImage = LoadedImage(key: key, image: image)
                loadFailed = false
            } else {
                loadedImage = nil
                loadFailed = true
            }
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestID == requestID else {
                return
            }
            loadedImage = nil
            loadFailed = true
        }
    }
}

enum LibraryWatchStatus: Equatable {
    case unwatched
    case watching
    case finished

    init(positionMilliseconds: Int, duration: Double?) {
        self.init(
            LibraryWatchState(
                positionMilliseconds: positionMilliseconds,
                duration: duration
            )
        )
    }

    init(_ state: LibraryWatchState) {
        switch state {
        case .unwatched:
            self = .unwatched
        case .watching:
            self = .watching
        case .finished:
            self = .finished
        }
    }

    var title: String {
        switch self {
        case .unwatched:
            return L("facet.watch_status.unwatched")
        case .watching:
            return L("facet.watch_status.watching")
        case .finished:
            return L("facet.watch_status.finished")
        }
    }

    var foregroundColor: Color {
        switch self {
        case .unwatched:
            return WorkbenchRedesignColors.watchStatusUnwatchedText
        case .watching:
            return WorkbenchRedesignColors.watchStatusWatchingText
        case .finished:
            return WorkbenchRedesignColors.watchStatusFinishedText
        }
    }

    var fillColor: Color {
        switch self {
        case .unwatched:
            return WorkbenchRedesignColors.watchStatusUnwatchedBg
        case .watching:
            return WorkbenchRedesignColors.watchStatusWatchingBg
        case .finished:
            return WorkbenchRedesignColors.watchStatusFinishedBg
        }
    }
}

struct WatchStatusBadge: View {
    let status: LibraryWatchStatus

    var body: some View {
        WorkbenchBadge(
            title: status.title,
            foregroundColor: status.foregroundColor,
            fillColor: status.fillColor
        )
    }
}


private struct LibraryEmptyHint<Content: View>: View {
    private let content: Content

    init(_ message: String) where Content == Text {
        content = Text(message)
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(size: WorkbenchTestLibraryMetrics.metaSize))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
    }
}

struct LibrarySortMenuState: Identifiable {
    let id = UUID()
    let anchorFrame: CGRect
    let menuFrame: CGRect
}

private struct LibrarySortAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct LibrarySortMenuPopover: View {
    let selectedOrder: LibrarySortOrder
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (LibrarySortOrder) -> Void
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            isRedesign: true,
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(LibrarySortOrder.allCases.enumerated()), id: \.element.id) { position, order in
                    WorkbenchPopoverRow(
                        title: order.title,
                        isSelected: selectedOrder == order,
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        isRedesign: true,
                        showsCheckmarkSlot: true,
                        action: {
                            onDismiss()
                            onSelect(order)
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

