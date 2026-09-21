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
            WorkbenchScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.sectionSpacing) {
                sectionTabs

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
                .workbenchPageInlinePadding()
                .padding(.top, WorkbenchTestLibraryMetrics.pageTopPadding)
                .padding(.bottom, WorkbenchTestLibraryMetrics.pageBottomPadding)
                .frame(
                    width: max(
                        geometry.size.width,
                        AppShellLayout.pageContentMinimumWidth
                    ),
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
        }
        .task {
            appState.hydrateTestRecentWatchingAsync()
            appState.reloadExcerptListOverview()
        }
        .onChange(of: appState.isPlaybackPageVisible) { isVisible in
            if !isVisible {
                appState.reloadExcerptListOverview()
            }
        }
    }

    /// The same Tabs as the Library page, flush with the content's left edge.
    private var sectionTabs: some View {
        WorkbenchTabs(
            items: WorkbenchRecentSection.allCases.map {
                .init(
                    value: $0,
                    label: $0.label,
                    accessibilityIdentifier: "recent-segment-\($0.rawValue)"
                )
            },
            selection: routeState.selectedRecentSection,
            isLeadingEdgeAligned: true
        ) { section in
            appState.workbenchLayout.selectRecentSection(section)
        }
    }

    @ViewBuilder
    private func recentVideosContent(
        status: LibraryStatus,
        items: [RecentLibraryWatchingPresentation]
    ) -> some View {
        if case .loading = status, items.isEmpty {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = status {
            LibraryEmptyHint(message)
        } else if items.isEmpty {
            LibraryEmptyHint(L("library.recent_watching_empty"))
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
        }
    }

    @ViewBuilder
    private func recentExcerptsContent(
        _ summaries: [ExcerptListSummary]
    ) -> some View {
        if !excerpt.hasLoadedListOverview, summaries.isEmpty {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if summaries.isEmpty {
            LibraryEmptyHint(L("library.recent_excerpts_empty"))
        } else {
            ExcerptListCardGrid(
                summaries: summaries,
                highlight: highlight
            ) { summary in
                appState.openRecentExcerpt(summary)
            }
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
    /// The two interfaces pick their segment separately: moving between them
    /// starts again on Video.
    @State private var segment: LibraryContentSegment = .video

    var body: some View {
        Group {
            if let folderPath = routeState.selectedLibraryFolderPath {
                GeometryReader { geometry in
                    WorkbenchScrollView([.vertical, .horizontal]) {
                        folderPageContent(folderPath: folderPath)
                            .workbenchPageInlinePadding()
                            .padding(
                                .top,
                                WorkbenchControlMetrics.redesignCoverSummaryDetailTopPadding
                            )
                            .padding(
                                .bottom,
                                WorkbenchTestLibraryMetrics.pageBottomPadding
                            )
                            .frame(
                                width: max(
                                    geometry.size.width,
                                    AppShellLayout.pageContentMinimumWidth
                                ),
                                alignment: .topLeading
                            )
                            .frame(
                                minHeight: geometry.size.height,
                                alignment: .topLeading
                            )
                    }
                }
            } else {
                LibraryOverviewLayout(
                    summaryText: completeLibrarySummaryText,
                    actionTitle: L("settings.library.add_folder"),
                    action: openFilePage
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: WorkbenchTestLibraryMetrics.sectionSpacing
                    ) {
                        segmentTabs

                        switch segment {
                        case .video:
                            completeLibraryContent
                        case .metadata:
                            fileTreeContent(
                                scope: library.fileTreeRoots.isEmpty
                                    ? nil
                                    : .roots(library.fileTreeRoots)
                            )
                        }
                    }
                }
            }
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .cardHighlightFreeze(highlight)
        .onChange(of: routeState.selectedLibraryFolderPath) { _ in
            highlight.reset()
            segment = .video
        }
        .onChange(of: segment) { _ in
            // Video and File are interfaces of their own.
            AppPointerShape.reset()
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
        .onChange(of: indexing.selectedFolders) { _ in
            closeFolderDetail()
        }
        .onChange(of: library.completeLibraryRevision) { _ in
            reconcileSelectedFolder()
        }
    }

    @ViewBuilder
    private var completeLibraryContent: some View {
        if case .loading = library.completeLibraryStatus, library.completeLibraryFolderSummaries.isEmpty {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = library.completeLibraryStatus {
            LibraryEmptyHint(message)
        } else if library.completeLibraryFolderSummaries.isEmpty {
            LibraryEmptyHint(L("library.empty"))
        } else {
            CompleteLibraryFolderGrid(
                folders: library.completeLibraryFolderSummaries,
                highlight: highlight,
                onOpen: { folder in
                    appState.navigateWorkbench(
                        to: .libraryFolder(folderPath: folder.folderPath)
                    )
                }
            )
        }
    }

    /// The history can point at a folder that is no longer indexed; the page
    /// then says so instead of waiting for a detail that will never load.
    @ViewBuilder
    private func folderPageContent(folderPath: String) -> some View {
        if let selectedFolder {
            folderDetailContent(for: selectedFolder)
        } else if appState.isWorkbenchRouteUnknown(
            .libraryFolder(folderPath: folderPath)
        ) {
            WorkbenchUnknownPage()
        } else {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func folderDetailContent(for folder: CompleteLibraryFolderSummaryPresentation) -> some View {
        if case .loading = folderDetailStatus, folderDetail?.folderPath != folder.folderPath {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = folderDetailStatus {
            LibraryEmptyHint(message)
        } else if let folderDetail, folderDetail.folderPath == folder.folderPath {
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignSpacing6
            ) {
                folderCoverSummary(folder: folder, detail: folderDetail)

                VStack(
                    alignment: .leading,
                    spacing: WorkbenchTestLibraryMetrics.sectionSpacing
                ) {
                    segmentTabs

                    switch segment {
                    case .video:
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
                    case .metadata:
                        fileTreeContent(
                            scope: fileTreeFolder(
                                folderPath: folderDetail.folderPath
                            ).map { .folder($0) }
                        )
                    }
                }
            }
        } else {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var segmentTabs: some View {
        WorkbenchTabs(
            items: LibraryContentSegment.allCases.map {
                .init(
                    value: $0,
                    label: $0.label,
                    accessibilityIdentifier: "library-segment-\($0.rawValue)"
                )
            },
            selection: segment,
            isLeadingEdgeAligned: true
        ) { selected in
            segment = selected
        }
    }

    @ViewBuilder
    private func fileTreeContent(scope: LibraryFileTree.Scope?) -> some View {
        Group {
            if case .loading = library.fileTreeStatus, library.fileTreeRoots.isEmpty {
                LibraryEmptyHint {
                    ProgressView()
                        .controlSize(.small)
                }
            } else if case .failed(let message) = library.fileTreeStatus {
                LibraryEmptyHint(message)
            } else if let scope {
                LibraryFileTree(scope: scope)
            } else {
                LibraryEmptyHint(L("library.file.empty"))
            }
        }
        .task(id: library.completeLibraryRevision) {
            appState.hydrateLibraryFileTreeAsync()
        }
    }

    /// The folder cards and the file tree group by the same folder path, so a
    /// detail can show its own subtree without reading the database again.
    private func fileTreeFolder(folderPath: String) -> IndexedContentFolder? {
        library.fileTreeRoots
            .lazy
            .flatMap(\.folders)
            .first { $0.folderPath == folderPath }
    }

    private func folderCoverSummary(
        folder: CompleteLibraryFolderSummaryPresentation,
        detail: CompleteLibraryFolderDetailPresentation
    ) -> some View {
        let recentItem = recentWatchingItem(for: detail)
        let itemCount = detail.videos.count

        return CoverSummaryCard(
            title: detail.folderTitle,
            supportingContent: .metadata(
                primary: L("library.video_subtitle_count", itemCount, itemCount),
                secondary: detail.folderPath
            ),
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
            $0.folderPath == detail.folderPath
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

    /// The folder being looked at is gone: going back to the overview is a
    /// step of its own, like any other page change.
    private func closeFolderDetail() {
        appState.navigateWorkbench(to: .library)
    }

    private func reconcileSelectedFolder() {
        guard routeState.selectedLibraryFolderPath != nil,
              selectedFolder == nil,
              library.completeLibraryStatus != .loading
        else {
            return
        }
        closeFolderDetail()
    }

    private var completeLibrarySummaryText: String {
        let folders = library.completeLibraryFolderSummaries
        let itemCount = folders.reduce(0) { count, folder in
            count + folder.episodeCount
        }
        return L("library.folder_summary", folders.count, itemCount)
            + L("library.subtitle_count", itemCount)
    }

    /// Adding a folder now belongs to the File page, so the Library action is
    /// a jump to that page rather than a Settings window.
    private func openFilePage() {
        appState.performUserInitiatedAppCommand {
            appState.activateWorkbenchPanelMode(.file)
        }
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

enum LibraryContentSegment: String, CaseIterable {
    case video
    case metadata

    var label: String {
        switch self {
        case .video:
            L("library.segment.video")
        case .metadata:
            L("library.segment.metadata")
        }
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

    static let recentGridGap = WorkbenchControlMetrics.redesignLibraryRecentGridGap
    static let recentCardMinWidth = WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth
    static let recentCardMaxWidth = WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth
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

struct RecentWatchingGrid: View {
    let items: [RecentLibraryWatchingPresentation]
    @ObservedObject var highlight: CardHighlightModel
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (RecentLibraryWatchingPresentation) -> Void

    var body: some View {
        LibraryVideoCardGrid(
            items: items,
            highlight: highlight,
            itemFrameCoordinateSpace: itemFrameCoordinateSpace,
            onItemFramesChange: onItemFramesChange,
            content: LibraryVideoCardContent.init,
            onOpen: onOpen
        )
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

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: WorkbenchTestLibraryMetrics.recentCardMinWidth,
                    maximum: WorkbenchTestLibraryMetrics.recentCardMaxWidth
                ),
                spacing: WorkbenchTestLibraryMetrics.recentGridGap,
                alignment: .topLeading
            )
        ]
    }

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
        LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: WorkbenchTestLibraryMetrics.recentGridGap
        ) {
            ForEach(items) { item in
                LibraryVideoCard(
                    content: content(item),
                    highlight: highlight,
                    isCurrent: highlight.currentID == item.id,
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let isCurrent: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    let onOpen: () -> Void

    private var cardID: String {
        content.videoPath
    }

    var body: some View {
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
        .padding(WorkbenchTestLibraryMetrics.mediaCardHoverPadding)
        .frame(maxWidth: WorkbenchTestLibraryMetrics.recentCardMaxWidth, alignment: .topLeading)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                style: .continuous
            )
            .fill(
                isCurrent
                    ? WorkbenchRedesignColors.libraryMediaCardHoverBg
                    : Color.clear
            )
        )
        // The card answers the pointer over its whole rectangle, corners
        // included, so the tap, the hand and Hover share one area. The rounded
        // background is appearance only and does not narrow it.
        .contentShape(Rectangle())
        .onTapGesture {
            highlight.notePress(id: cardID)
            onOpen()
        }
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
        .animation(
            .easeOut(duration: WorkbenchTestLibraryMetrics.coverHoverDuration),
            value: isCurrent
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
            isActive: isCurrent
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
                        isCurrent: highlight.currentID == folder.id,
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
    let isCurrent: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    let onOpen: () -> Void

    private var isAvailable: Bool {
        folder.episodeCount > 0
    }

    private var cardID: String {
        folder.id
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
                isCurrent: isCurrent,
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
            isActive: isCurrent && isAvailable
        )
    }

    private var folderContextMenuItems: [LibraryCardContextMenuItem] {
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

extension EnvironmentValues {
    var libraryCardContextMenuAnchorUpdate: ((CGPoint) -> Void)? {
        get { self[LibraryCardContextMenuAnchorUpdateKey.self] }
        set { self[LibraryCardContextMenuAnchorUpdateKey.self] = newValue }
    }

    var libraryCardContextMenuOpen: (([LibraryCardContextMenuItem], CGPoint, String) -> Void)? {
        get { self[LibraryCardContextMenuOpenKey.self] }
        set { self[LibraryCardContextMenuOpenKey.self] = newValue }
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
    /// Which card the menu hangs off. The card compares it with its own id to
    /// decide whether it is the one that stays lit.
    let ownerID: String
    var anchorPoint: CGPoint
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
    @ViewBuilder var content: (_ openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void) -> Content

    var body: some View {
        content(openContextMenu)
            .onChange(of: interfaceID) { _ in
                dismissContextMenu()
            }
            .environment(\.libraryCardContextMenuAnchorUpdate, updateAnchorPoint)
            .environment(\.libraryCardContextMenuOpen, openContextMenu)
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
        let naturalSize = measuredMenuSize(
            for: items,
            maximumHeight: MenuMetrics.maximumHeight
        )
        let anchor = CGRect(origin: anchorPoint, size: .zero)
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
            anchorPoint: anchorPoint,
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
            anchor: CGRect(origin: menu.anchorPoint, size: .zero),
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
                        isHighlighted: highlight.highlightedPosition == position,
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
                    isEnabled: isEnabled && !layerContext.isCovered
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
    let onRightClick: (CGPoint) -> Void

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(isEnabled: isEnabled, onRightClick: onRightClick)
    }

    final class MonitoringView: NSView {
        nonisolated(unsafe) private var monitor: Any?
        private var isEnabled = false
        private var onRightClick: ((CGPoint) -> Void)?

        override var isFlipped: Bool {
            true
        }

        func update(isEnabled: Bool, onRightClick: @escaping (CGPoint) -> Void) {
            self.isEnabled = isEnabled
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

    private struct LoadedImage {
        let key: LibraryCoverImageKey
        let image: CGImage
    }

    var body: some View {
        Group {
            if let key,
               let loadedImage,
               loadedImage.key == key {
                LibraryCoverFillImage(
                    image: loadedImage.image,
                    verticalAlignment: imageVerticalAlignment
                )
            } else {
                ZStack {
                    Rectangle()
                        .fill(WorkbenchRedesignColors.libraryCoverPlaceholderBg)

                    AppIconImage(.video, size: WorkbenchControlMetrics.redesignCoverPlaceholderIconSize)
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: key) {
            await loadImage(for: key)
        }
        .onDisappear {
            activeRequestID = nil
            loadedImage = nil
        }
    }

    private var key: LibraryCoverImageKey? {
        LibraryCoverImageKey.current(path: coverPath, revision: coverRevision)
    }

    @MainActor
    private func loadImage(for key: LibraryCoverImageKey?) async {
        guard let key else {
            activeRequestID = nil
            loadedImage = nil
            return
        }
        let requestID = UUID()
        activeRequestID = requestID
        if loadedImage?.key != key {
            loadedImage = nil
        }

        do {
            let image = try await LibraryCoverImagePipeline.shared.image(for: key)
            try Task.checkCancellation()
            guard activeRequestID == requestID else {
                return
            }
            loadedImage = image.map { LoadedImage(key: key, image: $0) }
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestID == requestID else {
                return
            }
            loadedImage = nil
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

/// What a history entry shows when the page it points to is gone.
struct WorkbenchUnknownPage: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    var body: some View {
        LibraryEmptyHint(L("page.unknown.message"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
