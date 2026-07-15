import AppKit
import CoreGraphics
import CueSeekerCore
import SwiftUI

struct WorkbenchTestRecentWatchingView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.sectionSpacing) {
                recentWatchingContent
            }
            .padding(.horizontal, WorkbenchTestLibraryMetrics.pageHorizontalPadding)
            .padding(.vertical, WorkbenchTestLibraryMetrics.pageVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .task {
            appState.hydrateTestRecentWatchingAsync()
        }
    }

    @ViewBuilder
    private var recentWatchingContent: some View {
        if case .loading = library.testRecentWatchingStatus, library.testRecentWatchingItems.isEmpty {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = library.testRecentWatchingStatus {
            LibraryEmptyHint(message)
        } else if library.testRecentWatchingItems.isEmpty {
            LibraryEmptyHint("No recent watching yet.")
        } else {
            RecentWatchingGrid(
                items: library.testRecentWatchingItems,
                onOpen: { item in
                    Task {
                        await appState.openRecentLibraryWatching(item)
                    }
                }
            )
        }
    }
}

struct WorkbenchTestLibraryView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var routeState: WorkbenchRouteState
    @EnvironmentObject private var library: LibraryStore
    @State private var folderDetail: CompleteLibraryFolderDetailPresentation?
    @State private var folderDetailStatus: LibraryStatus = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.sectionSpacing) {
                if let selectedFolder {
                    folderDetailContent(for: selectedFolder)
                } else {
                    completeLibraryContent
                }
            }
            .padding(.horizontal, WorkbenchTestLibraryMetrics.pageHorizontalPadding)
            .padding(.vertical, WorkbenchTestLibraryMetrics.pageVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .task {
            appState.hydrateCompleteLibraryAsync()
        }
        .task(id: folderDetailTaskID) {
            guard let folderPath = selectedFolder?.folderPath else {
                return
            }
            await loadFolderDetail(folderPath: folderPath)
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
            LibraryEmptyHint("No library videos yet.")
        } else {
            CompleteLibraryFolderGrid(
                folders: library.completeLibraryFolderSummaries,
                onOpen: { folder in
                    appState.workbenchLayout.selectTestLibraryFolder(folder)
                }
            )
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
            CompleteLibraryEpisodeGrid(
                videos: folderDetail.videos,
                onOpen: { video in
                    appState.prepareLibraryNavigationVideos(folderDetail.videos)
                    appState.openLibraryVideo(
                        video.libraryVideo,
                        displayTitle: video.displayTitle
                    )
                }
            )
        } else {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var folderDetailTaskID: String {
        guard let selectedFolder else {
            return ""
        }
        return "\(selectedFolder.folderPath)|\(library.completeLibraryRevision)|\(library.libraryPlaybackHistoryRevision)"
    }

    private func closeFolderDetail() {
        appState.workbenchLayout.clearTestLibraryFolder()
        folderDetail = nil
        folderDetailStatus = .idle
    }

    private func reconcileSelectedFolder() {
        guard let selectedFolder else {
            return
        }
        guard let updatedFolder = library.completeLibraryFolderSummaries.first(where: { $0.folderPath == selectedFolder.folderPath }) else {
            if library.completeLibraryStatus != .loading {
                closeFolderDetail()
            }
            return
        }
        appState.workbenchLayout.selectTestLibraryFolder(updatedFolder)
    }

    @MainActor
    private func loadFolderDetail(folderPath: String) async {
        folderDetailStatus = .loading
        do {
            let loadedDetail = try await appState.loadCompleteLibraryFolderDetail(folderPath: folderPath)
            guard !Task.isCancelled,
                  selectedFolder?.folderPath == folderPath else {
                return
            }
            guard let loadedDetail else {
                folderDetail = nil
                folderDetailStatus = .failed("Folder detail is unavailable")
                return
            }
            folderDetail = loadedDetail
            folderDetailStatus = .completed
        } catch {
            guard !Task.isCancelled,
                  selectedFolder?.folderPath == folderPath else {
                return
            }
            folderDetail = nil
            folderDetailStatus = .failed(AppCoordinator.errorMessage(for: error))
        }
    }
}

private extension WorkbenchTestLibraryView {
    var selectedFolder: CompleteLibraryFolderSummaryPresentation? {
        routeState.selectedTestLibraryFolder
    }
}

private enum WorkbenchTestLibraryMetrics {
    static let pageHorizontalPadding: CGFloat = 24
    static let pageVerticalPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let completeSectionTopPadding: CGFloat = 16

    static let sectionTitleSize = WorkbenchControlMetrics.redesignFontSizeSectionTitle

    static let recentGridGap = WorkbenchControlMetrics.redesignLibraryRecentGridGap
    static let recentCardMinWidth = WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth
    static let recentCardMaxWidth = WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth
    static let recentCardGap = WorkbenchControlMetrics.redesignSpacing2
    static let mediaCardHoverPadding = WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding
    static let mediaCardHoverRadius = WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius

    static let folderGridGap = WorkbenchControlMetrics.redesignLibraryRecentGridGap
    static let folderCardMinWidth = WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth
    static let folderCardMaxWidth = WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth
    static let folderCardGap = WorkbenchControlMetrics.redesignSpacing2
    static let detailHeaderGap = WorkbenchControlMetrics.redesignSpacing2
    static let episodeGridTopPadding = WorkbenchControlMetrics.redesignSpacing2
    static let episodeRowMinWidth = WorkbenchControlMetrics.redesignLibraryEpisodeRowMinWidth
    static let episodeGridGap = WorkbenchControlMetrics.redesignLibraryEpisodeGridGap
    static let episodeListItemGap = WorkbenchControlMetrics.redesignLibraryListItemGap
    static let episodeListInfoVerticalGap = WorkbenchControlMetrics.redesignLibraryListInfoVerticalGap
    static let episodeListCardRadius = WorkbenchControlMetrics.redesignLibraryListCardRadius
    static let episodeListCardVerticalPadding = WorkbenchControlMetrics.redesignLibraryListCardVerticalPadding
    static let episodeListCardHorizontalPadding = WorkbenchControlMetrics.redesignLibraryListCardHorizontalPadding
    static let episodeListCoverWidth = WorkbenchControlMetrics.redesignLibraryListCoverWidth
    static let episodeListCoverHeight = WorkbenchControlMetrics.redesignLibraryListCoverHeight
    static let coverHoverScale = WorkbenchControlMetrics.redesignLibraryCoverHoverScale
    static let coverHoverDuration = WorkbenchControlMetrics.redesignLibraryCoverHoverDuration

    static let coverAspectRatio = WorkbenchControlMetrics.redesignLibraryCoverAspectRatio
    static let coverRadius = WorkbenchControlMetrics.redesignLibraryCoverRadius
    static let progressBarHeight = WorkbenchControlMetrics.redesignLibraryProgressBarHeight
    static let timeBadgeRadius = WorkbenchControlMetrics.redesignLibraryTimeBadgeRadius
    static let timeBadgeHorizontalPadding = WorkbenchControlMetrics.redesignLibraryTimeBadgeHorizontalPadding
    static let timeBadgeVerticalPadding = WorkbenchControlMetrics.redesignLibraryTimeBadgeVerticalPadding
    static let timeBadgeInset: CGFloat = 6

    static let titleSize = WorkbenchControlMetrics.redesignFontSizeLibraryTitle
    static let metaSize = WorkbenchControlMetrics.redesignFontSizeLibraryMeta
    static let timeBadgeSize = WorkbenchControlMetrics.redesignFontSizeLibraryTimeBadge
    static let episodeListTitleSize = WorkbenchControlMetrics.redesignFontSizeLibraryListTitle
    static let episodeListSubtitleSize = WorkbenchControlMetrics.redesignFontSizeLibraryListSubtitle
    static let episodeListMetaSize = WorkbenchControlMetrics.redesignFontSizeLibraryListMeta
}

struct LibrarySectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: WorkbenchTestLibraryMetrics.sectionTitleSize, weight: .semibold))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
    }
}

struct RecentWatchingGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    let items: [RecentLibraryWatchingPresentation]
    var selectedItemID: String? = nil
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (RecentLibraryWatchingPresentation) -> Void

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
        LibraryCardContextMenuHost { openContextMenu in
            LazyVGrid(columns: columns, alignment: .leading, spacing: WorkbenchTestLibraryMetrics.recentGridGap) {
                ForEach(items) { item in
                    RecentWatchingCard(
                        item: item,
                        isSelected: selectedItemID == item.id,
                        actions: .appState(appState),
                        openContextMenu: openContextMenu
                    ) {
                        onOpen(item)
                    }
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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onPreferenceChange(LibraryItemFramePreferenceKey.self) {
                frames in
                guard itemFrameCoordinateSpace != nil else {
                    return
                }
                onItemFramesChange(frames)
            }
        }
    }
}

private struct LibraryItemFramePreferenceKey: PreferenceKey {
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
    let markVideo: (LibraryVideo, LibraryWatchState) -> Void
    let markFolder: (String, LibraryWatchState) -> Void
    let openVideoContext: (LibraryVideo, String) -> Void

    static func appState(_ appState: AppCoordinator) -> LibraryCardActionHandlers {
        LibraryCardActionHandlers(
            revealFile: { appState.revealFile(atPath: $0) },
            openFolder: { appState.openFolder(atPath: $0) },
            markVideo: { appState.markLibraryVideo($0, as: $1) },
            markFolder: { appState.markCompleteLibraryFolder(folderPath: $0, as: $1) },
            openVideoContext: { appState.openLibraryVideoContext($0, displayTitle: $1) }
        )
    }
}

private struct RecentWatchingCard: View {
    let item: RecentLibraryWatchingPresentation
    let isSelected: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint) -> Void
    let onOpen: () -> Void
    @State private var isHovered = false

    private var isAvailable: Bool {
        FileManager.default.fileExists(atPath: item.videoPath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.recentCardGap) {
            cover

            Text(item.folderTitle)
                .font(.system(size: WorkbenchTestLibraryMetrics.titleSize, weight: .semibold))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Text(episodeLabel)
                    .font(.system(size: WorkbenchTestLibraryMetrics.metaSize, weight: .medium))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .monospacedDigit()

                WatchStatusBadge(status: watchStatus)
            }
        }
        .padding(WorkbenchTestLibraryMetrics.mediaCardHoverPadding)
        .frame(maxWidth: WorkbenchTestLibraryMetrics.recentCardMaxWidth, alignment: .topLeading)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                style: .continuous
            )
            .fill(isHovered && isAvailable ? WorkbenchRedesignColors.libraryMediaCardHoverBg : Color.clear)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(
                    cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                    style: .continuous
                )
                .stroke(
                    WorkbenchRedesignColors.focusRing,
                    lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                )
                .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                .allowsHitTesting(false)
            }
        }
        .opacity(isAvailable ? 1 : 0.55)
        .contentShape(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                style: .continuous
            )
        )
        .onTapGesture {
            guard isAvailable else {
                return
            }
            onOpen()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .libraryCardContextMenuTrigger(
            isEnabled: isAvailable,
            isHovered: isHovered,
            items: recentContextMenuItems,
            openContextMenu: openContextMenu
        )
        .libraryCardCursor(isEnabled: isAvailable)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var cover: some View {
        LibraryCoverWithProgress(
            coverPath: item.coverPath,
            coverRevision: item.coverRevision,
            positionMilliseconds: item.positionMilliseconds,
            duration: item.playbackDuration ?? item.duration
        )
        .libraryCoverHoverEffect(isActive: isHovered && isAvailable)
    }

    private var recentContextMenuItems: [LibraryCardContextMenuItem] {
        [
            LibraryCardContextMenuItem(title: "Open Folder", systemImage: "folder") {
                actions.revealFile(item.videoPath)
            },
            LibraryCardContextMenuItem(title: "Mark as Finished", systemImage: "checkmark.circle") {
                actions.markVideo(item.libraryVideo, .finished)
            },
            LibraryCardContextMenuItem(title: "Mark as Unwatched", systemImage: "circle") {
                actions.markVideo(item.libraryVideo, .unwatched)
            },
            LibraryCardContextMenuItem(title: "Mark as Watching", systemImage: "play.circle") {
                actions.markVideo(item.libraryVideo, .watching)
            },
            LibraryCardContextMenuItem(title: "Context", systemImage: "doc.text") {
                actions.openVideoContext(item.libraryVideo, contextDisplayTitle)
            }
        ]
    }

    private var episodeLabel: String {
        String(format: "EP%02d", item.episodeNumber)
    }

    private var watchStatus: LibraryWatchStatus {
        LibraryWatchStatus(item.watchState)
    }

    private var contextDisplayTitle: String {
        let trimmedDisplayTitle = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDisplayTitle.isEmpty {
            return trimmedDisplayTitle
        }
        return item.folderTitle
    }
}

struct CompleteLibraryFolderGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    let folders: [CompleteLibraryFolderSummaryPresentation]
    var selectedItemID: String? = nil
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (CompleteLibraryFolderSummaryPresentation) -> Void

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: WorkbenchTestLibraryMetrics.folderCardMinWidth,
                    maximum: WorkbenchTestLibraryMetrics.folderCardMaxWidth
                ),
                spacing: WorkbenchTestLibraryMetrics.folderGridGap,
                alignment: .topLeading
            )
        ]
    }

    var body: some View {
        LibraryCardContextMenuHost { openContextMenu in
            LazyVGrid(columns: columns, alignment: .leading, spacing: WorkbenchTestLibraryMetrics.folderGridGap) {
                ForEach(folders) { folder in
                    LibraryFolderCard(
                        folder: folder,
                        isSelected: selectedItemID == folder.id,
                        actions: .appState(appState),
                        openContextMenu: openContextMenu
                    ) {
                        onOpen(folder)
                    }
                    .background {
                        if let itemFrameCoordinateSpace {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: LibraryItemFramePreferenceKey.self,
                                    value: [
                                        folder.id: proxy.frame(
                                            in: .named(itemFrameCoordinateSpace)
                                        )
                                    ]
                                )
                            }
                        }
                    }
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
}

private struct LibraryFolderCard: View {
    let folder: CompleteLibraryFolderSummaryPresentation
    let isSelected: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint) -> Void
    let onOpen: () -> Void
    @State private var isHovered = false

    private var isAvailable: Bool {
        folder.episodeCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.folderCardGap) {
            cover

            Text(folder.folderTitle)
                .font(.system(size: WorkbenchTestLibraryMetrics.titleSize, weight: .semibold))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WorkbenchTestLibraryMetrics.mediaCardHoverPadding)
        .frame(maxWidth: WorkbenchTestLibraryMetrics.folderCardMaxWidth, alignment: .topLeading)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                style: .continuous
            )
            .fill(isHovered && isAvailable ? WorkbenchRedesignColors.libraryMediaCardHoverBg : Color.clear)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(
                    cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                    style: .continuous
                )
                .stroke(
                    WorkbenchRedesignColors.focusRing,
                    lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                )
                .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                .allowsHitTesting(false)
            }
        }
        .opacity(isAvailable ? 1 : 0.55)
        .contentShape(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                style: .continuous
            )
        )
        .onTapGesture {
            guard isAvailable else {
                return
            }
            onOpen()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .libraryCardContextMenuTrigger(
            isEnabled: isAvailable,
            isHovered: isHovered,
            items: folderContextMenuItems,
            openContextMenu: openContextMenu
        )
        .libraryCardCursor(isEnabled: isAvailable)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var cover: some View {
        LibraryCoverWithBadge(
            coverPath: folder.coverPath,
            coverRevision: folder.coverRevision,
            badgeText: episodeCountText
        )
        .libraryCoverHoverEffect(isActive: isHovered && isAvailable)
    }

    private var folderContextMenuItems: [LibraryCardContextMenuItem] {
        [
            LibraryCardContextMenuItem(title: "Open Folder", systemImage: "folder") {
                actions.openFolder(folder.folderPath)
            },
            LibraryCardContextMenuItem(title: "Mark All as Finished", systemImage: "checkmark.circle") {
                actions.markFolder(folder.folderPath, .finished)
            },
            LibraryCardContextMenuItem(title: "Mark All as Unwatched", systemImage: "circle") {
                actions.markFolder(folder.folderPath, .unwatched)
            },
            LibraryCardContextMenuItem(title: "Mark All as Watching", systemImage: "play.circle") {
                actions.markFolder(folder.folderPath, .watching)
            }
        ]
    }

    private var episodeCountText: String {
        folder.episodeCount == 1 ? "1 episode" : "\(folder.episodeCount) episodes"
    }
}

struct LibraryFolderDetailHeader: View {
    let folderTitle: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: WorkbenchTestLibraryMetrics.detailHeaderGap) {
            WorkbenchIconButton(
                systemImage: "chevron.left",
                isRedesign: true,
                action: onBack
            )

            Text(folderTitle)
                .font(.system(size: WorkbenchTestLibraryMetrics.sectionTitleSize, weight: .semibold))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompleteLibraryEpisodeGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    let videos: [CompleteLibraryVideoPresentation]
    var selectedItemID: String? = nil
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (CompleteLibraryVideoPresentation) -> Void

    var body: some View {
        if videos.isEmpty {
            LibraryEmptyHint("No episodes yet.")
        } else {
            LibraryCardContextMenuHost { openContextMenu in
                LazyVStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.episodeGridGap) {
                    ForEach(videos) { video in
                        LibraryEpisodeCard(
                            video: video,
                            isSelected: selectedItemID == video.id,
                            actions: .appState(appState),
                            openContextMenu: openContextMenu
                        ) {
                            onOpen(video)
                        }
                        .frame(
                            minWidth: WorkbenchTestLibraryMetrics.episodeRowMinWidth,
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .background {
                            if let itemFrameCoordinateSpace {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: LibraryItemFramePreferenceKey.self,
                                        value: [
                                            video.id: proxy.frame(
                                                in: .named(itemFrameCoordinateSpace)
                                            )
                                        ]
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.top, WorkbenchTestLibraryMetrics.episodeGridTopPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onPreferenceChange(LibraryItemFramePreferenceKey.self) {
                    frames in
                    guard itemFrameCoordinateSpace != nil else {
                        return
                    }
                    onItemFramesChange(frames)
                }
            }
        }
    }
}

private struct LibraryEpisodeCard: View {
    let video: CompleteLibraryVideoPresentation
    let isSelected: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint) -> Void
    let onOpen: () -> Void
    @State private var isHovered = false

    private var isAvailable: Bool {
        FileManager.default.fileExists(atPath: video.videoPath)
    }

    var body: some View {
        HStack(alignment: .center, spacing: WorkbenchTestLibraryMetrics.episodeListItemGap) {
            cover

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Text(displayTitle)
                        .font(.system(size: WorkbenchTestLibraryMetrics.episodeListTitleSize, weight: .semibold))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    WatchStatusBadge(status: LibraryWatchStatus(video.watchState))
                        .fixedSize()
                }

                Spacer(minLength: WorkbenchTestLibraryMetrics.episodeListInfoVerticalGap)

                Text("字幕文件：\(subtitleFileName)")
                    .font(.system(size: WorkbenchTestLibraryMetrics.episodeListSubtitleSize))
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let metadataText {
                    Spacer(minLength: WorkbenchTestLibraryMetrics.episodeListInfoVerticalGap)

                    Text(metadataText)
                        .font(.system(size: WorkbenchTestLibraryMetrics.episodeListMetaSize))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Spacer(minLength: WorkbenchTestLibraryMetrics.episodeListInfoVerticalGap)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: WorkbenchTestLibraryMetrics.episodeListCoverHeight,
                maxHeight: WorkbenchTestLibraryMetrics.episodeListCoverHeight,
                alignment: .topLeading
            )
        }
        .padding(.vertical, WorkbenchTestLibraryMetrics.episodeListCardVerticalPadding)
        .padding(.horizontal, WorkbenchTestLibraryMetrics.episodeListCardHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            if isSelected {
                RoundedRectangle(
                    cornerRadius: WorkbenchTestLibraryMetrics.episodeListCardRadius,
                    style: .continuous
                )
                .stroke(
                    WorkbenchRedesignColors.focusRing,
                    lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                )
                .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                .allowsHitTesting(false)
            }
        }
        .opacity(isAvailable ? 1 : 0.55)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityLabel("\(displayTitle), \(LibraryWatchStatus(video.watchState).title)")
    }

    private var cover: some View {
        LibraryCoverWithProgress(
            coverPath: video.coverPath,
            coverRevision: video.coverRevision,
            positionMilliseconds: video.positionMilliseconds,
            duration: video.playbackDuration ?? video.duration
        )
        .libraryCoverHoverEffect(isActive: isHovered && isAvailable)
        .frame(
            width: WorkbenchTestLibraryMetrics.episodeListCoverWidth,
            height: WorkbenchTestLibraryMetrics.episodeListCoverHeight
        )
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                style: .continuous
            )
            .fill(isHovered && isAvailable ? WorkbenchRedesignColors.libraryMediaCardHoverBg : Color.clear)
            .padding(-WorkbenchTestLibraryMetrics.mediaCardHoverPadding)
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                style: .continuous
            )
        )
        .onTapGesture {
            guard isAvailable else {
                return
            }
            onOpen()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .libraryCardContextMenuTrigger(
            isEnabled: isAvailable,
            isHovered: isHovered,
            items: episodeContextMenuItems,
            openContextMenu: openContextMenu
        )
        .libraryCardCursor(isEnabled: isAvailable)
    }

    private var episodeContextMenuItems: [LibraryCardContextMenuItem] {
        [
            LibraryCardContextMenuItem(title: "Open Folder", systemImage: "folder") {
                actions.revealFile(video.videoPath)
            },
            LibraryCardContextMenuItem(title: "Mark as Finished", systemImage: "checkmark.circle") {
                actions.markVideo(video.libraryVideo, .finished)
            },
            LibraryCardContextMenuItem(title: "Mark as Unwatched", systemImage: "circle") {
                actions.markVideo(video.libraryVideo, .unwatched)
            },
            LibraryCardContextMenuItem(title: "Mark as Watching", systemImage: "play.circle") {
                actions.markVideo(video.libraryVideo, .watching)
            },
            LibraryCardContextMenuItem(title: "Context", systemImage: "doc.text") {
                actions.openVideoContext(video.libraryVideo, displayTitle)
            }
        ]
    }

    private var displayTitle: String {
        let trimmedDisplayTitle = video.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDisplayTitle.isEmpty {
            return trimmedDisplayTitle
        }
        return String(format: "EP%02d", video.episodeNumber)
    }

    private var subtitleFileName: String {
        URL(fileURLWithPath: video.subtitlePath).lastPathComponent
    }

    private var metadataText: String? {
        let parts = [
            video.fileSize.flatMap(Self.formatFileSize),
            Self.formatResolution(width: video.videoWidth, height: video.videoHeight),
            video.frameRate.flatMap(Self.formatFrameRate),
            video.videoCodec.flatMap(Self.formatCodec)
        ].compactMap { $0 }

        if parts.isEmpty {
            return nil
        }
        return parts.joined(separator: " ")
    }

    private static func formatFileSize(_ fileSize: Int64) -> String? {
        guard fileSize > 0 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    private static func formatResolution(width: Int?, height: Int?) -> String? {
        guard let width, let height, width > 0, height > 0 else {
            return nil
        }
        return "\(width)x\(height)"
    }

    private static func formatFrameRate(_ frameRate: Double) -> String? {
        guard frameRate.isFinite, frameRate > 0 else {
            return nil
        }

        let rounded = (frameRate * 100).rounded() / 100
        if rounded.rounded() == rounded {
            return String(format: "%.0f fps", rounded)
        }
        let value = String(format: "%.2f", rounded)
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        return "\(value) fps"
    }

    private static func formatCodec(_ codec: String) -> String? {
        let trimmed = codec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return trimmed.uppercased()
    }
}

private enum LibraryCardContextMenuCoordinateSpace {
    static let name = "LibraryCardContextMenuCoordinateSpace"
}

private struct LibraryCardContextMenuIsOpenKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var libraryCardContextMenuIsOpen: Bool {
        get { self[LibraryCardContextMenuIsOpenKey.self] }
        set { self[LibraryCardContextMenuIsOpenKey.self] = newValue }
    }
}

private struct LibraryCardContextMenuItem: Identifiable {
    let title: String
    let systemImage: String
    let action: () -> Void

    var id: String {
        title
    }
}

private struct LibraryCardContextMenuState: Identifiable {
    let id = UUID()
    let anchorPoint: CGPoint
    let items: [LibraryCardContextMenuItem]
}

private struct LibraryCardContextMenuHost<Content: View>: View {
    @State private var activeMenu: LibraryCardContextMenuState?
    @State private var menuSize: CGSize = .zero
    @ViewBuilder var content: (_ openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint) -> Void) -> Content

    var body: some View {
        content(openContextMenu)
            .environment(\.libraryCardContextMenuIsOpen, activeMenu != nil)
            .coordinateSpace(name: LibraryCardContextMenuCoordinateSpace.name)
            .overlay(alignment: .topLeading) {
                if let activeMenu {
                    GeometryReader { proxy in
                        let menuFrame = menuFrame(for: activeMenu, in: proxy.size)
                        ZStack(alignment: .topLeading) {
                            LibraryCardMenuDismissMonitor(
                                isActive: true,
                                menuFrame: menuFrame,
                                onDismiss: dismissContextMenu
                            )
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .allowsHitTesting(false)

                            Color.clear
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    dismissContextMenu()
                                }

                            LibraryCardContextMenu(
                                items: activeMenu.items,
                                onDismiss: dismissContextMenu
                            )
                            .background(
                                GeometryReader { menuProxy in
                                    Color.clear.preference(
                                        key: LibraryCardContextMenuSizePreferenceKey.self,
                                        value: menuProxy.size
                                    )
                                }
                            )
                            .offset(menuOffset(for: activeMenu, in: proxy.size))
                        }
                    }
                    .zIndex(1000)
                    .onPreferenceChange(LibraryCardContextMenuSizePreferenceKey.self) { newSize in
                        guard menuSize != newSize else {
                            return
                        }
                        menuSize = newSize
                    }
                }
            }
    }

    private func openContextMenu(items: [LibraryCardContextMenuItem], anchorPoint: CGPoint) {
        menuSize = .zero
        activeMenu = LibraryCardContextMenuState(anchorPoint: anchorPoint, items: items)
    }

    private func dismissContextMenu() {
        activeMenu = nil
    }

    private func menuFrame(for menu: LibraryCardContextMenuState, in containerSize: CGSize) -> CGRect {
        let offset = menuOffset(for: menu, in: containerSize)
        let size = resolvedMenuSize(for: menu)
        return CGRect(
            x: offset.width,
            y: offset.height,
            width: size.width,
            height: size.height
        )
    }

    private func menuOffset(for menu: LibraryCardContextMenuState, in containerSize: CGSize) -> CGSize {
        let resolvedSize = resolvedMenuSize(for: menu)
        let maxX = max(0, containerSize.width - resolvedSize.width)
        let maxY = max(0, containerSize.height - resolvedSize.height)
        let x = min(max(0, menu.anchorPoint.x), maxX)
        let y = min(max(0, menu.anchorPoint.y), maxY)
        return CGSize(width: x, height: y)
    }

    private func resolvedMenuSize(for menu: LibraryCardContextMenuState) -> CGSize {
        let fallbackSize = CGSize(
            width: 220,
            height: CGFloat(menu.items.count * 40 + 8)
        )
        return CGSize(
            width: menuSize.width > 0 ? menuSize.width : fallbackSize.width,
            height: menuSize.height > 0 ? menuSize.height : fallbackSize.height
        )
    }
}

private struct LibraryCardMenuDismissMonitor: NSViewRepresentable {
    let isActive: Bool
    let menuFrame: CGRect
    let onDismiss: () -> Void

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(isActive: isActive, menuFrame: menuFrame, onDismiss: onDismiss)
    }

    final class MonitoringView: NSView {
        nonisolated(unsafe) private var monitor: Any?
        private var isActive = false
        private var menuFrame = CGRect.zero
        private var onDismiss: (() -> Void)?

        override var isFlipped: Bool {
            true
        }

        func update(isActive: Bool, menuFrame: CGRect, onDismiss: @escaping () -> Void) {
            self.isActive = isActive
            self.menuFrame = menuFrame
            self.onDismiss = onDismiss
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
            guard isActive, window != nil else {
                removeMonitor()
                return
            }
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self else {
                    return event
                }
                guard event.window === self.window else {
                    return event
                }

                let localPoint = self.convert(event.locationInWindow, from: nil)
                guard !self.menuFrame.contains(localPoint) else {
                    return event
                }

                self.onDismiss?()
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

private struct LibraryCardContextMenuSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct LibraryCardContextMenu: View {
    let items: [LibraryCardContextMenuItem]
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        systemImage: item.systemImage,
                        isRedesign: true,
                        showsCheckmarkSlot: false,
                        isEnabled: true,
                        action: {
                            onDismiss()
                            item.action()
                        }
                    )
                }
            }
            .frame(minWidth: 220, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct LibraryCardContextMenuTriggerModifier: ViewModifier {
    let isEnabled: Bool
    let isHovered: Bool
    let items: [LibraryCardContextMenuItem]
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint) -> Void
    @Environment(\.libraryCardContextMenuIsOpen) private var isContextMenuOpen

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(LibraryCardContextMenuCoordinateSpace.name))
                LibraryCardRightClickMonitor(isEnabled: isEnabled && isHovered && !isContextMenuOpen) { localPoint in
                    openContextMenu(
                        items,
                        CGPoint(
                            x: frame.minX + localPoint.x,
                            y: frame.minY + localPoint.y
                        )
                    )
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
                guard self.bounds.contains(localPoint) else {
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

private struct LibraryCardCursorModifier: ViewModifier {
    let isEnabled: Bool
    @State private var hasPushedCursor = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                updateCursor(isHovering: hovering)
            }
            .onChange(of: isEnabled) { _ in
                resetCursor()
            }
            .onDisappear {
                resetCursor()
            }
    }

    private func updateCursor(isHovering: Bool) {
        guard isHovering else {
            resetCursor()
            return
        }
        guard !hasPushedCursor else {
            return
        }
        if isEnabled {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.operationNotAllowed.push()
        }
        hasPushedCursor = true
    }

    private func resetCursor() {
        guard hasPushedCursor else {
            return
        }
        NSCursor.pop()
        hasPushedCursor = false
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

private extension View {
    func libraryCardCursor(isEnabled: Bool) -> some View {
        modifier(LibraryCardCursorModifier(isEnabled: isEnabled))
    }

    func libraryCardContextMenuTrigger(
        isEnabled: Bool,
        isHovered: Bool,
        items: [LibraryCardContextMenuItem],
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint) -> Void
    ) -> some View {
        modifier(
            LibraryCardContextMenuTriggerModifier(
                isEnabled: isEnabled,
                isHovered: isHovered,
                items: items,
                openContextMenu: openContextMenu
            )
        )
    }

    func libraryCoverHoverEffect(isActive: Bool) -> some View {
        modifier(LibraryCoverHoverEffectModifier(isActive: isActive))
    }
}

private struct LibraryCoverWithProgress: View {
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
        .aspectRatio(WorkbenchTestLibraryMetrics.coverAspectRatio, contentMode: .fit)
        .clipShape(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.coverRadius,
                style: .continuous
            )
        )
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
        .aspectRatio(WorkbenchTestLibraryMetrics.coverAspectRatio, contentMode: .fit)
        .clipShape(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.coverRadius,
                style: .continuous
            )
        )
    }
}

private struct LibraryCachedCoverImage: View {
    let coverPath: String?
    let coverRevision: String?

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
                Image(decorative: loadedImage.image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(WorkbenchRedesignColors.libraryCoverPlaceholderBg)
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

private enum LibraryWatchStatus: Equatable {
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
            return "Unwatched"
        case .watching:
            return "Watching"
        case .finished:
            return "Finished"
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

private struct WatchStatusBadge: View {
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
