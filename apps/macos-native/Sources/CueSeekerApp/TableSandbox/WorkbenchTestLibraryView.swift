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
                LibrarySectionTitle("Recent Watching")

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
                    appState.openLibraryVideo(item.libraryVideo)
                }
            )
        }
    }
}

struct WorkbenchTestLibraryView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        ScrollView {
            LibraryScrollOffsetPersistenceView(offsetY: completeLibraryScrollOffsetY)
                .frame(width: 0, height: 0)

            VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.sectionSpacing) {
                LibrarySectionTitle("Recent Watching")

                recentWatchingContent

                LibrarySectionTitle("Complete Library")
                    .padding(.top, WorkbenchTestLibraryMetrics.completeSectionTopPadding)

                completeLibraryContent
            }
            .padding(.horizontal, WorkbenchTestLibraryMetrics.pageHorizontalPadding)
            .padding(.vertical, WorkbenchTestLibraryMetrics.pageVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .task {
            appState.hydrateRecentWatchingAsync()
            appState.hydrateCompleteLibraryAsync()
        }
        .onChange(of: indexing.selectedFolders) { _ in
            appState.refreshRecentWatching()
            appState.refreshCompleteLibrary()
        }
    }

    private var completeLibraryScrollOffsetY: Binding<CGFloat> {
        Binding(
            get: { library.completeLibraryScrollOffsetY },
            set: { library.completeLibraryScrollOffsetY = max(0, $0) }
        )
    }

    @ViewBuilder
    private var recentWatchingContent: some View {
        if case .loading = library.recentWatchingStatus, library.recentWatchingItems.isEmpty {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = library.recentWatchingStatus {
            LibraryEmptyHint(message)
        } else if library.recentWatchingItems.isEmpty {
            LibraryEmptyHint("No recent watching yet.")
        } else {
            RecentWatchingGrid(
                items: library.recentWatchingItems,
                onOpen: { item in
                    appState.openLibraryVideo(item.libraryVideo)
                }
            )
        }
    }

    @ViewBuilder
    private var completeLibraryContent: some View {
        if case .loading = library.completeLibraryStatus, library.completeLibraryFolders.isEmpty {
            LibraryEmptyHint {
                ProgressView()
                    .controlSize(.small)
            }
        } else if case .failed(let message) = library.completeLibraryStatus {
            LibraryEmptyHint(message)
        } else if library.completeLibraryFolders.isEmpty {
            LibraryEmptyHint("No library videos yet.")
        } else {
            CompleteLibraryList(
                folders: library.completeLibraryFolders,
                expandedFolderPaths: library.completeLibraryExpandedFolderPaths,
                onContinue: { folder in
                    guard let video = folder.continueWatchingVideo else {
                        return
                    }
                    appState.openLibraryVideo(video.libraryVideo)
                },
                onOpenVideo: { video in
                    appState.openLibraryVideo(video.libraryVideo)
                },
                onToggle: { folder in
                    appState.toggleCompleteLibraryFolder(folder.folderPath)
                }
            )
        }
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

    static let completeFolderListGap = WorkbenchControlMetrics.redesignSpacing3
    static let completeFolderExpandedGap = WorkbenchControlMetrics.redesignSpacing2
    static let folderCardMinHeight = WorkbenchControlMetrics.redesignLibraryFolderCardMinHeight
    static let folderCardRadius = WorkbenchControlMetrics.redesignLibraryFolderCardRadius
    static let folderCardVerticalPadding = WorkbenchControlMetrics.redesignLibraryFolderCardVerticalPadding
    static let folderCardHorizontalPadding = WorkbenchControlMetrics.redesignLibraryFolderCardHorizontalPadding
    static let folderCardContentGap = WorkbenchControlMetrics.redesignLibraryFolderCardContentGap
    static let folderCoverWidth = WorkbenchControlMetrics.redesignLibraryFolderCoverWidth
    static let folderInfoGap = WorkbenchControlMetrics.redesignSpacing1
    static let folderActionsGap = WorkbenchControlMetrics.redesignSpacing2
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

private struct LibrarySectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: WorkbenchTestLibraryMetrics.sectionTitleSize, weight: .semibold))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        LibraryWatchStatus(
            positionMilliseconds: item.positionMilliseconds,
            duration: item.playbackDuration ?? item.duration
        )
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

private struct CompleteLibraryList: View {
    let folders: [CompleteLibraryFolderPresentation]
    let expandedFolderPaths: Set<String>
    let onContinue: (CompleteLibraryFolderPresentation) -> Void
    let onOpenVideo: (CompleteLibraryVideoPresentation) -> Void
    let onToggle: (CompleteLibraryFolderPresentation) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.completeFolderListGap) {
            ForEach(folders) { folder in
                VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.completeFolderExpandedGap) {
                    LibraryFolderCard(
                        folder: folder,
                        isExpanded: expandedFolderPaths.contains(folder.folderPath),
                        onContinue: { onContinue(folder) },
                        onToggle: { onToggle(folder) }
                    )

                    if expandedFolderPaths.contains(folder.folderPath) {
                        CompleteLibraryEpisodeGrid(
                            videos: folder.videos,
                            onOpen: onOpenVideo
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LibraryFolderCard: View {
    let folder: CompleteLibraryFolderPresentation
    let isExpanded: Bool
    let onContinue: () -> Void
    let onToggle: () -> Void
    @State private var isHovered = false

    private var continueVideo: CompleteLibraryVideoPresentation? {
        folder.continueWatchingVideo
    }

    private var isContinueAvailable: Bool {
        guard let continueVideo else {
            return false
        }
        return FileManager.default.fileExists(atPath: continueVideo.videoPath)
    }

    var body: some View {
        HStack(spacing: WorkbenchTestLibraryMetrics.folderCardContentGap) {
            LibraryCoverWithProgress(
                coverPath: coverPath,
                positionMilliseconds: continueVideo?.positionMilliseconds ?? 0,
                duration: continueVideo?.playbackDuration ?? continueVideo?.duration
            )
            .frame(width: WorkbenchTestLibraryMetrics.folderCoverWidth)

            VStack(alignment: .leading, spacing: WorkbenchTestLibraryMetrics.folderInfoGap) {
                Text(folder.folderTitle)
                    .font(.system(size: WorkbenchTestLibraryMetrics.titleSize, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)

                Text(lastWatchedText)
                    .font(.system(size: WorkbenchTestLibraryMetrics.metaSize, weight: .medium))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: WorkbenchTestLibraryMetrics.folderActionsGap) {
                WorkbenchButton(
                    title: "Continue Watching",
                    systemImage: "play",
                    isRedesign: true,
                    action: onContinue
                )
                .disabled(!isContinueAvailable)

                LibraryFolderDisclosureButton(
                    isExpanded: isExpanded,
                    action: onToggle
                )
            }
        }
        .padding(.vertical, WorkbenchTestLibraryMetrics.folderCardVerticalPadding)
        .padding(.horizontal, WorkbenchTestLibraryMetrics.folderCardHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: WorkbenchTestLibraryMetrics.folderCardMinHeight, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.folderCardRadius,
                style: .continuous
            )
            .fill(isHovered ? WorkbenchRedesignColors.bgHover : WorkbenchRedesignColors.bgSurface)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchTestLibraryMetrics.folderCardRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchRedesignColors.borderControl, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var coverPath: String? {
        folder.folderCoverPath
            ?? continueVideo?.coverPath
            ?? folder.videos.first?.coverPath
    }

    private var lastWatchedText: String {
        guard let episodeNumber = folder.lastWatchedEpisodeNumber else {
            return "Last Watched: None"
        }
        return String(format: "Last Watched: EP%02d", episodeNumber)
    }
}

private struct LibraryFolderDisclosureButton: View {
    let isExpanded: Bool
    let action: () -> Void
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .font(.system(size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS, weight: .semibold))
                .foregroundStyle(WorkbenchRedesignColors.iconDefault)
                .frame(
                    width: WorkbenchControlMetrics.redesignIconButtonSize,
                    height: WorkbenchControlMetrics.redesignIconButtonSize
                )
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .background(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                        style: .continuous
                    )
                    .fill(isHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
                )
                .overlay(
                    Group {
                        if isFocused {
                            RoundedRectangle(
                                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth,
                                style: .continuous
                            )
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                        }
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.16), value: isExpanded)
        .animation(.easeOut(duration: 0.12), value: isHovered)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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
            maxPixelSize: maxPixelSize
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

    var cacheKey: String {
        "\(path)|\(maxPixelSize)"
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

private struct LibraryScrollOffsetPersistenceView: NSViewRepresentable {
    @Binding var offsetY: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(offsetY: $offsetY)
    }

    func makeNSView(context: Context) -> LibraryScrollOffsetReaderView {
        let view = LibraryScrollOffsetReaderView()
        view.desiredOffsetY = offsetY
        view.onOffsetChange = { offsetY in
            context.coordinator.offsetY.wrappedValue = offsetY
        }
        return view
    }

    func updateNSView(_ nsView: LibraryScrollOffsetReaderView, context: Context) {
        context.coordinator.offsetY = $offsetY
        nsView.desiredOffsetY = offsetY
        nsView.onOffsetChange = { offsetY in
            context.coordinator.offsetY.wrappedValue = offsetY
        }
        nsView.restoreIfNeeded()
    }

    static func dismantleNSView(_ nsView: LibraryScrollOffsetReaderView, coordinator: Coordinator) {
        nsView.stopObserving()
    }

    final class Coordinator {
        var offsetY: Binding<CGFloat>

        init(offsetY: Binding<CGFloat>) {
            self.offsetY = offsetY
        }
    }
}

private final class LibraryScrollOffsetReaderView: NSView {
    var desiredOffsetY: CGFloat = 0
    var onOffsetChange: ((CGFloat) -> Void)?

    private weak var observedClipView: NSClipView?
    private var boundsObserver: NSObjectProtocol?
    private var didRestoreInitialOffset = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleAttachAndRestore()
    }

    func restoreIfNeeded() {
        attachIfNeeded()

        guard !didRestoreInitialOffset,
              desiredOffsetY > 0,
              let clipView = observedClipView,
              let scrollView = clipView.enclosingScrollView,
              let documentView = scrollView.documentView
        else {
            if desiredOffsetY <= 0 {
                didRestoreInitialOffset = true
            }
            return
        }

        let maxOffsetY = max(0, documentView.bounds.height - clipView.bounds.height)
        guard maxOffsetY > 0 else {
            return
        }

        let restoredOffsetY = min(max(0, desiredOffsetY), maxOffsetY)
        didRestoreInitialOffset = true
        clipView.scroll(to: CGPoint(x: clipView.bounds.origin.x, y: restoredOffsetY))
        scrollView.reflectScrolledClipView(clipView)
        onOffsetChange?(restoredOffsetY)
    }

    func stopObserving() {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
        boundsObserver = nil
        observedClipView = nil
    }

    private func scheduleAttachAndRestore() {
        DispatchQueue.main.async { [weak self] in
            self?.attachIfNeeded()
            self?.restoreIfNeeded()
        }
    }

    private func attachIfNeeded() {
        guard let scrollView = enclosingScrollView else {
            return
        }

        let clipView = scrollView.contentView
        guard observedClipView !== clipView else {
            return
        }

        stopObserving()
        observedClipView = clipView
        clipView.postsBoundsChangedNotifications = true
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleBoundsChanged()
            }
        }
    }

    private func handleBoundsChanged() {
        restoreIfNeeded()
        guard didRestoreInitialOffset,
              let clipView = observedClipView
        else {
            return
        }
        onOffsetChange?(max(0, clipView.bounds.origin.y))
    }
}
