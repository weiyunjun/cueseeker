import AppKit
import CueSeekerCore
import ImageIO
import SwiftUI

struct WorkbenchTestRecentWatchingView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
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
        .onChange(of: indexing.selectedFolders) { _ in
            appState.refreshTestRecentWatching()
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
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
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
            appState.refreshCompleteLibrary()
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
                    layoutState.selectTestLibraryFolder(folder)
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
                    appState.openLibraryVideo(video.libraryVideo)
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
        layoutState.clearTestLibraryFolder()
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
        layoutState.selectTestLibraryFolder(updatedFolder)
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
        layoutState.selectedTestLibraryFolder
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
    static let episodeCardWidth = WorkbenchControlMetrics.redesignLibraryEpisodeCardWidth
    static let episodeCardGap = WorkbenchControlMetrics.redesignSpacing2
    static let episodeGridCardGap = WorkbenchControlMetrics.redesignLibraryEpisodeGridCardGap

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

private struct RecentWatchingGrid: View {
    let items: [RecentLibraryWatchingPresentation]
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
        LazyVGrid(columns: columns, alignment: .leading, spacing: WorkbenchTestLibraryMetrics.recentGridGap) {
            ForEach(items) { item in
                RecentWatchingCard(item: item) {
                    onOpen(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecentWatchingCard: View {
    let item: RecentLibraryWatchingPresentation
    let onOpen: () -> Void
    @State private var isHovered = false
    @State private var hasPushedCursor = false

    private var isAvailable: Bool {
        FileManager.default.fileExists(atPath: item.videoPath)
    }

    var body: some View {
        Button(action: {
            guard isAvailable else {
                return
            }
            onOpen()
        }) {
            VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.recentCardGap) {
                LibraryCoverWithProgress(
                    coverPath: item.coverPath,
                    positionMilliseconds: item.positionMilliseconds,
                    duration: item.playbackDuration ?? item.duration
                )

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
            .opacity(isAvailable ? 1 : 0.55)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(LibraryMediaCardButtonStyle())
        .disabled(!isAvailable)
        .onHover { hovering in
            isHovered = hovering
            updateCursor(isHovering: hovering)
        }
        .onDisappear {
            resetCursor()
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var episodeLabel: String {
        String(format: "EP%02d", item.episodeNumber)
    }

    private var watchStatus: LibraryWatchStatus {
        LibraryWatchStatus(item.watchState)
    }

    private func updateCursor(isHovering: Bool) {
        guard isHovering else {
            resetCursor()
            return
        }
        guard !hasPushedCursor else {
            return
        }
        if isAvailable {
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

private struct CompleteLibraryFolderGrid: View {
    let folders: [CompleteLibraryFolderSummaryPresentation]
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
        LazyVGrid(columns: columns, alignment: .leading, spacing: WorkbenchTestLibraryMetrics.folderGridGap) {
            ForEach(folders) { folder in
                LibraryFolderCard(folder: folder) {
                    onOpen(folder)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LibraryFolderCard: View {
    let folder: CompleteLibraryFolderSummaryPresentation
    let onOpen: () -> Void
    @State private var isHovered = false
    @State private var hasPushedCursor = false

    private var isAvailable: Bool {
        folder.episodeCount > 0
    }

    var body: some View {
        Button(action: {
            guard isAvailable else {
                return
            }
            onOpen()
        }) {
            VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.folderCardGap) {
                LibraryCoverWithBadge(
                    coverPath: folder.coverPath,
                    badgeText: episodeCountText
                )

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
            .opacity(isAvailable ? 1 : 0.55)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(LibraryMediaCardButtonStyle())
        .disabled(!isAvailable)
        .onHover { hovering in
            isHovered = hovering
            updateCursor(isHovering: hovering)
        }
        .onDisappear {
            resetCursor()
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var episodeCountText: String {
        folder.episodeCount == 1 ? "1 episode" : "\(folder.episodeCount) episodes"
    }

    private func updateCursor(isHovering: Bool) {
        guard isHovering else {
            resetCursor()
            return
        }
        guard !hasPushedCursor else {
            return
        }
        if isAvailable {
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

private struct CompleteLibraryEpisodeGrid: View {
    let videos: [CompleteLibraryVideoPresentation]
    let onOpen: (CompleteLibraryVideoPresentation) -> Void

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: WorkbenchTestLibraryMetrics.episodeCardWidth,
                    maximum: WorkbenchTestLibraryMetrics.episodeCardWidth
                ),
                spacing: WorkbenchTestLibraryMetrics.episodeGridCardGap,
                alignment: .topLeading
            )
        ]
    }

    var body: some View {
        if videos.isEmpty {
            LibraryEmptyHint("No episodes yet.")
        } else {
            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: WorkbenchTestLibraryMetrics.episodeGridCardGap
            ) {
                ForEach(videos) { video in
                    LibraryEpisodeCard(video: video) {
                        onOpen(video)
                    }
                }
            }
            .padding(.top, WorkbenchTestLibraryMetrics.episodeGridTopPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LibraryEpisodeCard: View {
    let video: CompleteLibraryVideoPresentation
    let onOpen: () -> Void
    @State private var isHovered = false
    @State private var hasPushedCursor = false

    private var isAvailable: Bool {
        FileManager.default.fileExists(atPath: video.videoPath)
    }

    var body: some View {
        Button(action: {
            guard isAvailable else {
                return
            }
            onOpen()
        }) {
            VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.episodeCardGap) {
                LibraryCoverWithProgress(
                    coverPath: video.coverPath,
                    positionMilliseconds: video.positionMilliseconds,
                    duration: video.playbackDuration ?? video.duration
                )

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Text(episodeLabel)
                        .font(.system(size: WorkbenchTestLibraryMetrics.metaSize, weight: .medium))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .monospacedDigit()

                    WatchStatusBadge(status: LibraryWatchStatus(video.watchState))
                }
            }
            .padding(WorkbenchTestLibraryMetrics.mediaCardHoverPadding)
            .frame(width: WorkbenchTestLibraryMetrics.episodeCardWidth, alignment: .topLeading)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                    style: .continuous
                )
                .fill(isHovered && isAvailable ? WorkbenchRedesignColors.libraryMediaCardHoverBg : Color.clear)
            )
            .opacity(isAvailable ? 1 : 0.55)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: WorkbenchTestLibraryMetrics.mediaCardHoverRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(LibraryMediaCardButtonStyle())
        .disabled(!isAvailable)
        .onHover { hovering in
            isHovered = hovering
            updateCursor(isHovering: hovering)
        }
        .onDisappear {
            resetCursor()
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var episodeLabel: String {
        String(format: "EP%02d", video.episodeNumber)
    }

    private func updateCursor(isHovering: Bool) {
        guard isHovering else {
            resetCursor()
            return
        }
        guard !hasPushedCursor else {
            return
        }
        if isAvailable {
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

private struct LibraryMediaCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? WorkbenchControlMetrics.redesignLibraryMediaCardPressedScale : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct LibraryCoverWithProgress: View {
    let coverPath: String?
    let positionMilliseconds: Int
    let duration: Double?

    private var progress: Double? {
        guard let duration, duration.isFinite, duration > 0 else {
            return nil
        }
        let durationMilliseconds = duration * 1_000
        guard durationMilliseconds > 0 else {
            return nil
        }
        return min(1, max(0, Double(max(0, positionMilliseconds)) / durationMilliseconds))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            coverImage

            progressTrack

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
        GeometryReader { proxy in
            LibraryDownsampledCoverImage(
                coverPath: coverPath,
                displaySize: proxy.size
            )
        }
    }

    private var progressTrack: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(WorkbenchRedesignColors.libraryProgressTrack)

                Rectangle()
                    .fill(WorkbenchRedesignColors.libraryProgressFill)
                    .frame(width: proxy.size.width * (progress ?? 0))
            }
        }
        .frame(height: WorkbenchTestLibraryMetrics.progressBarHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var timeBadgeText: String {
        let current = Self.formatTime(milliseconds: positionMilliseconds)
        guard let duration, duration.isFinite, duration > 0 else {
            return current
        }
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
    let badgeText: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { proxy in
                LibraryDownsampledCoverImage(
                    coverPath: coverPath,
                    displaySize: proxy.size
                )
            }

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

private struct LibraryDownsampledCoverImage: View {
    let coverPath: String?
    let displaySize: CGSize

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(WorkbenchRedesignColors.libraryCoverPlaceholderBg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: request?.cacheKey) {
            await loadImage()
        }
    }

    private var request: LibraryCoverImageRequest? {
        guard let coverPath else {
            return nil
        }
        guard displaySize.width.isFinite,
              displaySize.height.isFinite,
              displaySize.width > 1,
              displaySize.height > 1 else {
            return nil
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let maxDimension = max(displaySize.width, displaySize.height)
        let maxPixelSize = max(1, Int((maxDimension * scale).rounded(.up)))
        return LibraryCoverImageRequest(
            path: coverPath,
            maxPixelSize: maxPixelSize,
            fileVersion: LibraryCoverImageFileVersion.current(forPath: coverPath)
        )
    }

    @MainActor
    private func loadImage() async {
        guard let request else {
            image = nil
            return
        }

        if let cachedImage = LibraryCoverImageCache.shared.image(for: request.cacheKey) {
            image = cachedImage
            return
        }

        image = nil

        let loadedImage = await Task.detached(priority: .utility) {
            LibraryCoverImageLoader.load(
                path: request.path,
                maxPixelSize: request.maxPixelSize
            )
        }.value

        guard self.request == request else {
            return
        }
        guard let loadedImage else {
            image = nil
            return
        }

        LibraryCoverImageCache.shared.insert(
            loadedImage.image,
            cost: loadedImage.cost,
            for: request.cacheKey
        )
        image = loadedImage.image
    }
}

private struct LibraryCoverImageRequest: Equatable, Sendable {
    let path: String
    let maxPixelSize: Int
    let fileVersion: LibraryCoverImageFileVersion

    var cacheKey: String {
        "\(path)|\(maxPixelSize)|\(fileVersion.cacheKeyComponent)"
    }
}

private struct LibraryCoverImageFileVersion: Equatable, Sendable {
    let byteCount: UInt64?
    let modificationTimeNanoseconds: Int64?

    static func current(forPath path: String) -> LibraryCoverImageFileVersion {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return LibraryCoverImageFileVersion(
                byteCount: nil,
                modificationTimeNanoseconds: nil
            )
        }

        let byteCount = (attributes[.size] as? NSNumber)?.uint64Value
        let modificationTimeNanoseconds = (attributes[.modificationDate] as? Date).map { date in
            Int64((date.timeIntervalSince1970 * 1_000_000_000).rounded())
        }

        return LibraryCoverImageFileVersion(
            byteCount: byteCount,
            modificationTimeNanoseconds: modificationTimeNanoseconds
        )
    }

    var cacheKeyComponent: String {
        let byteCountComponent = byteCount.map(String.init) ?? "missing-size"
        let modificationTimeComponent = modificationTimeNanoseconds.map(String.init) ?? "missing-mtime"
        return "\(byteCountComponent)|\(modificationTimeComponent)"
    }
}

private struct LibraryLoadedCoverImage: @unchecked Sendable {
    let image: NSImage
    let cost: Int
}

@MainActor
private final class LibraryCoverImageCache {
    static let shared = LibraryCoverImageCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.totalCostLimit = 48 * 1_024 * 1_024
        cache.countLimit = 256
    }

    func image(for key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: NSImage, cost: Int, for key: String) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

private enum LibraryCoverImageLoader {
    static func load(path: String, maxPixelSize: Int) -> LibraryLoadedCoverImage? {
        guard maxPixelSize > 0 else {
            return nil
        }

        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let imageSource = CGImageSourceCreateWithURL(
            URL(fileURLWithPath: path) as CFURL,
            sourceOptions as CFDictionary
        ) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            imageSource,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            return nil
        }

        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
        let cost = max(1, cgImage.bytesPerRow * cgImage.height)
        return LibraryLoadedCoverImage(image: image, cost: cost)
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
