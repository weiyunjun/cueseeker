import AppKit
import CoreGraphics
import CueSeekerCore
import SwiftUI

struct WorkbenchLibraryView: View {
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
                                viewportSize: geometry.size,
                                toggleAnchorMenu: toggleAnchorMenu,
                                activeMenuOwnerID: activeMenuOwnerID
                            )
                                .padding(
                                    .top,
                                    WorkbenchControlMetrics.redesignCoverSummaryDetailTopPadding
                                )
                                .padding(
                                    .bottom,
                                    WorkbenchLibraryMetrics.pageBottomPadding
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
        let emptyMinHeight = max(
            0,
            viewportSize.height
                - WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
                - WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
        )
        if case .loading = library.completeLibraryStatus, library.completeLibraryFolderSummaries.isEmpty {
            WorkbenchSpinner()
                .frame(maxWidth: .infinity, minHeight: emptyMinHeight, alignment: .center)
                .workbenchPageInlinePadding()
        } else if case .failed(let message) = library.completeLibraryStatus {
            WorkbenchEmptyHint(icon: .videoQuestion, message: message)
                .frame(minHeight: emptyMinHeight)
                .workbenchPageInlinePadding()
        } else if library.completeLibraryFolderSummaries.isEmpty {
            WorkbenchEmptyHint(icon: .video, message: L("library.empty"))
                .frame(minHeight: emptyMinHeight)
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
        viewportSize: CGSize,
        toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
        activeMenuOwnerID: String?
    ) -> some View {
        let pageEmptyMinHeight = max(
            0,
            viewportSize.height
                - WorkbenchControlMetrics.redesignCoverSummaryDetailTopPadding
                - WorkbenchLibraryMetrics.pageBottomPadding
        )
        if appState.isWorkbenchRouteUnknown(.libraryFolder(folderPath: folderPath)) {
            WorkbenchEmptyHint(
                icon: .videoQuestion,
                message: L("library.folder.not_found")
            )
            .frame(minHeight: pageEmptyMinHeight)
            .workbenchPageInlinePadding()
        } else if let selectedFolder {
            folderDetailContent(
                for: selectedFolder,
                viewportSize: viewportSize,
                pageEmptyMinHeight: pageEmptyMinHeight,
                toggleAnchorMenu: toggleAnchorMenu,
                activeMenuOwnerID: activeMenuOwnerID
            )
        } else {
            WorkbenchSpinner()
                .frame(maxWidth: .infinity, minHeight: pageEmptyMinHeight, alignment: .center)
                .workbenchPageInlinePadding()
        }
    }

    @ViewBuilder
    private func folderDetailContent(
        for folder: CompleteLibraryFolderSummaryPresentation,
        viewportSize: CGSize,
        pageEmptyMinHeight: CGFloat,
        toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
        activeMenuOwnerID: String?
    ) -> some View {
        if case .loading = folderDetailStatus, folderDetail?.folderPath != folder.folderPath {
            WorkbenchSpinner()
                .frame(maxWidth: .infinity, minHeight: pageEmptyMinHeight, alignment: .center)
                .workbenchPageInlinePadding()
        } else if case .failed(let message) = folderDetailStatus {
            WorkbenchEmptyHint(icon: .videoQuestion, message: message)
                .frame(minHeight: pageEmptyMinHeight)
                .workbenchPageInlinePadding()
        } else if let folderDetail, folderDetail.folderPath == folder.folderPath {
            let contentWidth = max(
                0,
                viewportSize.width
                    - WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
                    - WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding
            )
            let episodesEmptyMinHeight = max(
                0,
                pageEmptyMinHeight
                    - CoverSummaryCardLayout.height(forCardWidth: contentWidth)
                    - WorkbenchControlMetrics.redesignCoverSummaryToolbarGap
            )
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
                    emptyMinHeight: episodesEmptyMinHeight,
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
            WorkbenchSpinner()
                .frame(maxWidth: .infinity, minHeight: pageEmptyMinHeight, alignment: .center)
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

private extension WorkbenchLibraryView {
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

enum WorkbenchLibraryMetrics {
    static let pageTopPadding =
        WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
    static let pageBottomPadding =
        WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
    static let sectionSpacing = WorkbenchControlMetrics.redesignSpacing4

    static let recentCardGap = WorkbenchControlMetrics.redesignSpacing2

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
