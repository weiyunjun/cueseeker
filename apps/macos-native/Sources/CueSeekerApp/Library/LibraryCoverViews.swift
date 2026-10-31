import CoreGraphics
import CueSeekerCore
import SwiftUI

struct LibraryCoverBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: WorkbenchLibraryMetrics.timeBadgeSize, weight: .semibold))
            .foregroundStyle(WorkbenchRedesignColors.libraryTimeBadgeText)
            .monospacedDigit()
            .padding(.horizontal, WorkbenchLibraryMetrics.timeBadgeHorizontalPadding)
            .padding(.vertical, WorkbenchLibraryMetrics.timeBadgeVerticalPadding)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchLibraryMetrics.timeBadgeRadius,
                    style: .continuous
                )
                .fill(WorkbenchRedesignColors.libraryTimeBadgeBg)
            )
            .padding(.leading, WorkbenchLibraryMetrics.timeBadgeInset)
            .padding(.bottom, WorkbenchLibraryMetrics.timeBadgeInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .allowsHitTesting(false)
    }
}

struct LibraryCoverMoreButton: View {
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.libraryCardContextMenuAnchorUpdate) private var updateAnchor
    let isVisible: Bool
    let isOpen: Bool
    var isFocused: Bool = false
    let anchor: MenuAnchorHandle
    var onHoverChange: (Bool) -> Void = { _ in }
    let action: () -> Void

    @State private var didOpenFromButton = false

    var body: some View {
        WorkbenchIconButton(
            icon: .dotsThree,
            iconWeight: .fill,
            isOpen: isOpen,
            isFocused: isFocused,
            defaultBackground: WorkbenchRedesignColors.libraryCoverActionBg,
            hoverBackground: WorkbenchRedesignColors.libraryCoverActionBgHover,
            pressedBackground: WorkbenchRedesignColors.libraryCoverActionBgPressed,
            openBackground: WorkbenchRedesignColors.libraryCoverActionBgHover,
            iconColor: WorkbenchRedesignColors.libraryTimeBadgeText,
            openIconColor: WorkbenchRedesignColors.libraryTimeBadgeText,
            isFrozen: layerContext.isFrozen && !isOpen,
            onHoverChange: { hovered in
                onHoverChange(hovered && isVisible)
            },
            action: {
                didOpenFromButton = !isOpen
                action()
            }
        )
        .background(MenuAnchorProbe(handle: anchor))
        .background(
            GeometryReader { proxy in
                let origin = proxy.frame(
                    in: .named(LibraryCardContextMenuCoordinateSpace.name)
                ).origin
                Color.clear
                    .onChange(of: origin) { newOrigin in
                        guard isOpen, didOpenFromButton else {
                            return
                        }
                        updateAnchor?(newOrigin)
                    }
            }
        )
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .onChange(of: isVisible) { visible in
            if !visible {
                onHoverChange(false)
            }
        }
        .onChange(of: isOpen) { open in
            if !open {
                didOpenFromButton = false
            }
        }
        .padding(.trailing, WorkbenchLibraryMetrics.timeBadgeInset)
        .padding(.bottom, WorkbenchLibraryMetrics.timeBadgeInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

struct LibraryCoverWithProgress: View {
    @Environment(\.mediaCardCoverSize) private var environmentCoverSize
    let coverPath: String?
    let coverRevision: String?
    let positionMilliseconds: Int
    let duration: Double?
    var showsMoreButton: Bool = false
    var isMoreMenuOpen: Bool = false
    var isMoreButtonFocused: Bool = false
    var moreMenuAnchor: MenuAnchorHandle? = nil
    var onMoreHoverChange: (Bool) -> Void = { _ in }
    var onToggleMoreMenu: (() -> Void)? = nil

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
                LibraryCachedCoverImage(
                    coverPath: coverPath,
                    coverRevision: coverRevision
                ) {
                    if let progressFraction {
                        progressTrack(progressFraction: progressFraction)
                    }

                    LibraryCoverBadge(text: timeBadgeText)
                }
                .allowsHitTesting(false)

                if let moreMenuAnchor, let onToggleMoreMenu {
                    LibraryCoverMoreButton(
                        isVisible: showsMoreButton,
                        isOpen: isMoreMenuOpen,
                        isFocused: isMoreButtonFocused,
                        anchor: moreMenuAnchor,
                        onHoverChange: onMoreHoverChange,
                        action: onToggleMoreMenu
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func progressTrack(progressFraction: Double) -> some View {
        if let environmentCoverSize, environmentCoverSize.width > 0 {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(WorkbenchRedesignColors.libraryProgressTrack)

                Rectangle()
                    .fill(WorkbenchRedesignColors.libraryProgressFill)
                    .frame(width: environmentCoverSize.width * progressFraction)
            }
            .frame(
                width: environmentCoverSize.width,
                height: WorkbenchLibraryMetrics.progressBarHeight
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(WorkbenchRedesignColors.libraryProgressTrack)

                    Rectangle()
                        .fill(WorkbenchRedesignColors.libraryProgressFill)
                        .frame(width: proxy.size.width * progressFraction)
                }
            }
            .frame(height: WorkbenchLibraryMetrics.progressBarHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
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

struct LibraryCoverWithBadge: View {
    let coverPath: String?
    let coverRevision: String?
    let badgeText: String
    var showsMoreButton: Bool = false
    var isMoreMenuOpen: Bool = false
    var isMoreButtonFocused: Bool = false
    var moreMenuAnchor: MenuAnchorHandle? = nil
    var onMoreHoverChange: (Bool) -> Void = { _ in }
    var onToggleMoreMenu: (() -> Void)? = nil

    var body: some View {
        LibraryCoverFrame {
            ZStack(alignment: .bottomLeading) {
                LibraryCachedCoverImage(
                    coverPath: coverPath,
                    coverRevision: coverRevision
                ) {
                    LibraryCoverBadge(text: badgeText)
                }
                .allowsHitTesting(false)

                if let moreMenuAnchor, let onToggleMoreMenu {
                    LibraryCoverMoreButton(
                        isVisible: showsMoreButton,
                        isOpen: isMoreMenuOpen,
                        isFocused: isMoreButtonFocused,
                        anchor: moreMenuAnchor,
                        onHoverChange: onMoreHoverChange,
                        action: onToggleMoreMenu
                    )
                }
            }
        }
    }
}

struct LibraryCachedCoverImage<Overlay: View>: View {
    let coverPath: String?
    let coverRevision: String?
    var imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top
    private let overlay: Overlay

    @State private var loadedImage: LoadedImage?
    @State private var activeRequestID: UUID?
    @State private var loadFailed = false

    private struct LoadedImage {
        let key: LibraryCoverImageKey
        let image: CGImage
    }

    init(
        coverPath: String?,
        coverRevision: String?,
        imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top
    ) where Overlay == EmptyView {
        self.coverPath = coverPath
        self.coverRevision = coverRevision
        self.imageVerticalAlignment = imageVerticalAlignment
        self.overlay = EmptyView()
    }

    init(
        coverPath: String?,
        coverRevision: String?,
        imageVerticalAlignment: LibraryCoverImageFillLayout.VerticalAlignment = .top,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.coverPath = coverPath
        self.coverRevision = coverRevision
        self.imageVerticalAlignment = imageVerticalAlignment
        self.overlay = overlay()
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

    private var isDecodeFailed: Bool {
        if loadFailed {
            return true
        }
        guard let key else {
            return false
        }
        return LibraryCoverImagePipeline.shared.hasFailedDecode(for: key)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let currentImage {
                LibraryCoverFillImage(
                    image: currentImage,
                    verticalAlignment: imageVerticalAlignment
                )
                overlay
            } else if key != nil && !isDecodeFailed {
                Color.clear
            } else {
                defaultCover
                overlay
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
            if activeRequestID != nil {
                activeRequestID = nil
            }
            if loadedImage?.key != key || loadFailed {
                loadedImage = LoadedImage(key: key, image: cached)
                loadFailed = false
            }
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
