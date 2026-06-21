import AppKit
import CueSeekerCore
import SwiftUI

struct WorkbenchTestLibraryView: View {
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
            appState.hydrateRecentWatchingAsync()
        }
        .onChange(of: indexing.selectedFolders) { _ in
            appState.refreshRecentWatching()
        }
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
}

private enum WorkbenchTestLibraryMetrics {
    static let pageHorizontalPadding: CGFloat = 24
    static let pageVerticalPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16

    static let sectionTitleSize = WorkbenchControlMetrics.redesignFontSizeSectionTitle

    static let recentGridGap = WorkbenchControlMetrics.redesignLibraryRecentGridGap
    static let recentCardMinWidth = WorkbenchControlMetrics.redesignLibraryRecentCardMinWidth
    static let recentCardMaxWidth = WorkbenchControlMetrics.redesignLibraryRecentCardMaxWidth
    static let recentCardGap = WorkbenchControlMetrics.redesignSpacing2
    static let mediaCardHoverPadding = WorkbenchControlMetrics.redesignLibraryMediaCardHoverPadding
    static let mediaCardHoverRadius = WorkbenchControlMetrics.redesignLibraryMediaCardHoverRadius

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

    @ViewBuilder
    private var coverImage: some View {
        if let coverPath,
           let image = NSImage(contentsOfFile: coverPath) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Rectangle()
                .fill(WorkbenchRedesignColors.libraryCoverPlaceholderBg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private enum LibraryWatchStatus: Equatable {
    case unwatched
    case watching
    case finished

    init(positionMilliseconds: Int, duration: Double?) {
        let positionSeconds = Double(max(0, positionMilliseconds)) / 1_000
        guard positionSeconds > 0 else {
            self = .unwatched
            return
        }

        guard let duration, duration.isFinite, duration > 0 else {
            self = .watching
            return
        }

        if positionSeconds >= duration * 0.95 || duration - positionSeconds <= 1 {
            self = .finished
        } else {
            self = .watching
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
