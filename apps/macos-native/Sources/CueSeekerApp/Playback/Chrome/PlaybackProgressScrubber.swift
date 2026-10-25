import CoreGraphics
import CueSeekerPlayback
import SwiftUI

@MainActor
final class PlaybackTimelineThumbnailStore: ObservableObject {
    typealias KeyframeLookup = @MainActor (Int) -> Int?
    typealias ThumbnailRequester = @MainActor (
        _ milliseconds: Int,
        _ targetPixelWidth: Int,
        _ completion: @escaping @MainActor (CGImage?, Int, CGSize?) -> Void
    ) -> Void
    typealias CancelRequests = @MainActor () -> Void

    private struct PendingRequest: Equatable {
        let targetMilliseconds: Int
        let keyframeIdentity: Int
        let targetPixelWidth: Int
    }

    @Published private(set) var thumbnailImage: CGImage?
    @Published private(set) var thumbnailAspectRatio: Double?

    private let keyframeLookup: KeyframeLookup
    private let requestThumbnail: ThumbnailRequester
    private let cancelRequests: CancelRequests

    private var isSessionActive = false
    private var displayedKeyframeIdentity: Int?
    private var inFlightRequest: PendingRequest?
    private var pendingLatestRequest: PendingRequest?
    private var activeRequestGeneration: UInt64 = 0

    convenience init(player: PlaybackPlayer) {
        self.init(
            keyframeLookup: { [weak player] milliseconds in
                player?.keyframeTimestampMilliseconds(forTargetMilliseconds: milliseconds)
            },
            requestThumbnail: { [weak player] milliseconds, targetPixelWidth, completion in
                guard let player else {
                    completion(nil, -1, nil)
                    return
                }
                player.requestTimelineThumbnail(
                    atMilliseconds: milliseconds,
                    targetPixelWidth: targetPixelWidth,
                    completion: completion
                )
            },
            cancelRequests: { [weak player] in
                player?.cancelTimelineThumbnailRequests()
            }
        )
    }

    init(
        keyframeLookup: @escaping KeyframeLookup,
        requestThumbnail: @escaping ThumbnailRequester,
        cancelRequests: @escaping CancelRequests
    ) {
        self.keyframeLookup = keyframeLookup
        self.requestThumbnail = requestThumbnail
        self.cancelRequests = cancelRequests
    }

    func updatePreview(
        forSeconds seconds: Double,
        backingScaleFactor: CGFloat
    ) {
        let safeSeconds = seconds.isFinite ? max(0, seconds) : 0
        let targetMilliseconds = max(0, Int((safeSeconds * 1_000).rounded()))
        let resolvedScale = (backingScaleFactor.isFinite && backingScaleFactor > 0)
            ? backingScaleFactor
            : 2.0
        let targetPixelWidth = max(
            1,
            Int((PlaybackChromeMetrics.progressThumbnailWidth * resolvedScale).rounded())
        )
        let keyframeIdentity = keyframeLookup(targetMilliseconds) ?? targetMilliseconds
        let candidate = PendingRequest(
            targetMilliseconds: targetMilliseconds,
            keyframeIdentity: keyframeIdentity,
            targetPixelWidth: targetPixelWidth
        )

        isSessionActive = true

        if let inFlight = inFlightRequest {
            if inFlight.keyframeIdentity == keyframeIdentity {
                pendingLatestRequest = nil
                return
            }
            if pendingLatestRequest?.keyframeIdentity == keyframeIdentity {
                return
            }
            pendingLatestRequest = candidate
            return
        }

        if displayedKeyframeIdentity == keyframeIdentity, thumbnailImage != nil {
            pendingLatestRequest = nil
            return
        }

        startRequest(candidate)
    }

    func clear() {
        let hadActiveState = isSessionActive
            || inFlightRequest != nil
            || pendingLatestRequest != nil
            || thumbnailImage != nil
            || thumbnailAspectRatio != nil
        guard hadActiveState else {
            return
        }

        isSessionActive = false
        displayedKeyframeIdentity = nil
        inFlightRequest = nil
        pendingLatestRequest = nil
        activeRequestGeneration &+= 1
        if thumbnailImage != nil {
            thumbnailImage = nil
        }
        if thumbnailAspectRatio != nil {
            thumbnailAspectRatio = nil
        }
        cancelRequests()
    }

    private func startRequest(_ request: PendingRequest) {
        activeRequestGeneration &+= 1
        let generation = activeRequestGeneration
        inFlightRequest = request

        requestThumbnail(request.targetMilliseconds, request.targetPixelWidth) { [weak self] image, _, videoSize in
            guard let self,
                 self.isSessionActive,
                 self.activeRequestGeneration == generation
            else {
                return
            }

            self.inFlightRequest = nil
            if let image {
                if let videoSize, videoSize.width > 0, videoSize.height > 0 {
                    let nextAspectRatio = Double(videoSize.width / videoSize.height)
                    if nextAspectRatio.isFinite,
                       nextAspectRatio > 0,
                       self.thumbnailAspectRatio != nextAspectRatio {
                        self.thumbnailAspectRatio = nextAspectRatio
                    }
                }
                self.displayedKeyframeIdentity = request.keyframeIdentity
                self.thumbnailImage = image
            }

            if let nextRequest = self.pendingLatestRequest {
                self.pendingLatestRequest = nil
                if nextRequest.keyframeIdentity != self.displayedKeyframeIdentity || self.thumbnailImage == nil {
                    self.startRequest(nextRequest)
                }
            }
        }
    }
}

struct PlaybackProgressScrubberHoverState: Equatable {
    var isHovered = false
    var isHoveringScrubber = false
    var isDragging = false
    var hoverX: CGFloat? = nil

    mutating func handlePointerHover(_ hovered: Bool) {
        isHovered = hovered
    }

    mutating func handleContinuousHoverActive(x: CGFloat) {
        hoverX = x
        isHoveringScrubber = true
    }

    mutating func handleContinuousHoverEnded() {
        guard !isDragging else {
            return
        }
        hoverX = nil
        isHoveringScrubber = false
    }

    mutating func handleDragChanged(locationX: CGFloat, trackWidth: CGFloat) -> CGFloat {
        isDragging = true
        let clampedX = min(max(locationX, 0), max(0, trackWidth))
        hoverX = clampedX
        return clampedX
    }

    mutating func handleDragEnded(
        location: CGPoint,
        trackWidth: CGFloat,
        hitAreaHeight: CGFloat = PlaybackChromeMetrics.progressHitAreaHeight
    ) -> CGFloat {
        isDragging = false
        let clampedX = min(max(location.x, 0), max(0, trackWidth))
        let hitBounds = CGRect(
            x: 0,
            y: 0,
            width: max(0, trackWidth),
            height: max(0, hitAreaHeight)
        )
        if hitBounds.contains(location) {
            hoverX = clampedX
            isHoveringScrubber = true
            isHovered = true
        } else {
            hoverX = nil
            isHoveringScrubber = false
            isHovered = false
        }
        return clampedX
    }
}

struct PlaybackProgressScrubber: View {
    static let windowCoordinateSpaceName = "PlaybackProgressScrubberWindowSpace"

    @Environment(\.displayScale) private var displayScale
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @ObservedObject private var scrubTimeStore: PlaybackTimelineScrubTimeStore
    @ObservedObject private var thumbnailStore: PlaybackTimelineThumbnailStore
    let windowWidth: CGFloat?
    @State private var hoverState = PlaybackProgressScrubberHoverState()

    init(
        viewModel: PlaybackViewModel,
        timeline: PlaybackTimelineInteractionStore,
        windowWidth: CGFloat? = nil
    ) {
        self.viewModel = viewModel
        self.timeline = timeline
        self.windowWidth = windowWidth
        _scrubTimeStore = ObservedObject(wrappedValue: timeline.scrubTimeStore)
        _thumbnailStore = ObservedObject(wrappedValue: viewModel.timelineThumbnailStore)
    }

    var body: some View {
        GeometryReader { geometry in
            let duration = viewModel.duration.isFinite ? max(0, viewModel.duration) : 0
            let hasDuration = duration > 0
            let isScrubbing = hasDuration && scrubTimeStore.scrubTime != nil
            let isInteractiveHover = hasDuration && hoverState.isHovered
            let displayTime = scrubTimeStore.scrubTime ?? viewModel.displayedCurrentTime
            let progress = hasDuration
                ? min(max(displayTime / duration, 0), 1)
                : 0
            let width = max(0, geometry.size.width)
            let scrubberOriginXInWindow = geometry.frame(in: .named(Self.windowCoordinateSpaceName)).minX
            let filledWidth = width * progress
            let trackHeight: CGFloat = (isInteractiveHover || isScrubbing)
                ? PlaybackChromeMetrics.progressTrackHoverHeight
                : PlaybackChromeMetrics.progressTrackHeight

            let targetX = isScrubbing ? filledWidth : hoverState.hoverX
            let tooltipTime: Double = {
                if let scrubTime = scrubTimeStore.scrubTime {
                    return scrubTime
                }
                if let hoverX = hoverState.hoverX {
                    return seekTime(for: hoverX, width: width, duration: duration)
                }
                return viewModel.displayedCurrentTime
            }()

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PlaybackTheme.progressTrack)
                    .frame(height: trackHeight)

                if !isScrubbing, isInteractiveHover, hoverState.isHoveringScrubber, let hoverX = hoverState.hoverX {
                    Capsule()
                        .fill(PlaybackTheme.progressHoverTrack)
                        .frame(width: max(0, hoverX), height: trackHeight)
                }

                Capsule()
                    .fill(PlaybackTheme.progressFill)
                    .frame(width: filledWidth, height: trackHeight)

                Circle()
                    .fill(PlaybackTheme.progressFill)
                    .frame(
                        width: PlaybackChromeMetrics.progressThumbSize,
                        height: PlaybackChromeMetrics.progressThumbSize
                    )
                    .offset(x: filledWidth - PlaybackChromeMetrics.progressThumbSize / 2)
                    .opacity(isInteractiveHover || isScrubbing ? 1 : 0)
            }
            .frame(height: PlaybackChromeMetrics.progressHitAreaHeight, alignment: .center)
            .contentShape(Rectangle())
            .playerInteractiveRegion()
            .onPointerHover { hovered in
                hoverState.handlePointerHover(hovered)
                if !hoverState.isDragging {
                    syncThumbnailPreview(width: width, duration: duration)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoverState.handleContinuousHoverActive(x: point.x)
                case .ended:
                    hoverState.handleContinuousHoverEnded()
                }
                if !hoverState.isDragging {
                    syncThumbnailPreview(width: width, duration: duration)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard hasDuration, width > 0 else {
                            return
                        }
                        beginScrubbingIfNeeded()
                        let clampedX = hoverState.handleDragChanged(
                            locationX: value.location.x,
                            trackWidth: width
                        )
                        let targetTime = seekTime(for: clampedX, width: width, duration: duration)
                        scrubTimeStore.scrubTime = targetTime
                        viewModel.updateTimelineScrubbing(to: targetTime)
                        viewModel.updateTimelineThumbnailPreview(
                            at: targetTime,
                            backingScaleFactor: displayScale
                        )
                    }
                    .onEnded { value in
                        guard hasDuration, width > 0 else {
                            if hoverState.isDragging {
                                viewModel.cancelTimelineScrubbing()
                                endScrubbingIfNeeded()
                            }
                            _ = hoverState.handleDragEnded(
                                location: value.location,
                                trackWidth: width
                            )
                            syncThumbnailPreview(width: width, duration: duration)
                            return
                        }
                        let clampedX = hoverState.handleDragEnded(
                            location: value.location,
                            trackWidth: width
                        )
                        let finalTime = seekTime(for: clampedX, width: width, duration: duration)
                        scrubTimeStore.scrubTime = finalTime
                        viewModel.endTimelineScrubbing(to: finalTime)
                        endScrubbingIfNeeded()
                        syncThumbnailPreview(width: width, duration: duration)
                    }
            )
            .onChange(of: viewModel.duration) { _ in
                let nextDuration = viewModel.duration.isFinite ? max(0, viewModel.duration) : 0
                syncThumbnailPreview(width: width, duration: nextDuration)
            }
            .overlay(
                Group {
                    if let targetX = targetX, ((isInteractiveHover && hoverState.isHoveringScrubber) || isScrubbing) {
                        if let thumbnailImage = thumbnailStore.thumbnailImage {
                            let aspectRatio = thumbnailStore.thumbnailAspectRatio ?? viewModel.videoAspectRatio
                            let thumbnailSize = PlaybackChromeMetrics.progressThumbnailSize(
                                aspectRatio: aspectRatio
                            )
                            PlaybackProgressTimeCapsulePlacementLayout(
                                targetX: targetX,
                                containerOriginXInWindow: scrubberOriginXInWindow,
                                windowWidth: windowWidth
                            ) {
                                Image(
                                    decorative: thumbnailImage,
                                    scale: max(1, displayScale),
                                    orientation: .up
                                )
                                .resizable()
                                .interpolation(.high)
                                .frame(
                                    width: thumbnailSize.width,
                                    height: thumbnailSize.height
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: PlaybackChromeMetrics.progressThumbnailRadius,
                                        style: .continuous
                                    )
                                )
                            }
                            .offset(
                                y: PlaybackChromeMetrics.progressThumbnailYOffset(
                                    thumbnailHeight: thumbnailSize.height
                                )
                            )
                            .allowsHitTesting(false)
                        }

                        PlaybackProgressTimeCapsulePlacementLayout(
                            targetX: targetX,
                            containerOriginXInWindow: scrubberOriginXInWindow,
                            windowWidth: windowWidth
                        ) {
                            Text(formatPlaybackTime(tooltipTime))
                                .font(.system(
                                    size: PlaybackChromeMetrics.progressTimeFontSize,
                                    weight: .semibold,
                                    design: .monospaced
                                ))
                                .foregroundStyle(PlaybackTheme.textPrimary)
                                .monospacedDigit()
                                .padding(.horizontal, PlaybackChromeMetrics.progressTimeCapsuleHorizontalPadding)
                                .frame(height: PlaybackChromeMetrics.progressTimeCapsuleHeight)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                                        style: .continuous
                                    )
                                    .fill(PlaybackTheme.menuBackground)
                                )
                        }
                        .offset(y: PlaybackChromeMetrics.progressTimeCapsuleYOffset)
                        .allowsHitTesting(false)
                    }
                }
                .transaction { $0.animation = nil },
                alignment: .topLeading
            )
        }
        .frame(height: PlaybackChromeMetrics.progressHitAreaHeight)
        .onDisappear {
            if hoverState.isDragging {
                viewModel.cancelTimelineScrubbing()
            }
            endScrubbingIfNeeded()
            viewModel.clearTimelineThumbnailPreview()
        }
    }

    private func syncThumbnailPreview(width: CGFloat, duration: Double) {
        guard duration > 0, width > 0 else {
            viewModel.clearTimelineThumbnailPreview()
            return
        }

        if let scrubTime = scrubTimeStore.scrubTime {
            viewModel.updateTimelineThumbnailPreview(
                at: scrubTime,
                backingScaleFactor: displayScale
            )
            return
        }

        if hoverState.isHovered, hoverState.isHoveringScrubber, let hoverX = hoverState.hoverX {
            let targetTime = seekTime(for: hoverX, width: width, duration: duration)
            viewModel.updateTimelineThumbnailPreview(
                at: targetTime,
                backingScaleFactor: displayScale
            )
            return
        }

        viewModel.clearTimelineThumbnailPreview()
    }

    private func beginScrubbingIfNeeded() {
        guard !hoverState.isDragging else {
            return
        }

        hoverState.isDragging = true
        viewModel.beginTimelineScrubbing()
        timeline.isScrubbing = true
    }

    private func endScrubbingIfNeeded() {
        hoverState.isDragging = false
        scrubTimeStore.scrubTime = nil
        timeline.isScrubbing = false
    }

    private func seekTime(for xPosition: CGFloat, width: CGFloat, duration: Double) -> Double {
        let progress = Double(min(max(xPosition / max(width, 1), 0), 1))
        return progress * duration
    }

    private func formatPlaybackTime(_ seconds: Double) -> String {
        let safeSeconds = seconds.isFinite ? max(0, seconds) : 0
        let totalSeconds = Int(safeSeconds.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PlaybackProgressTimeCapsulePlacementLayout: Layout {
    let targetX: CGFloat
    var containerOriginXInWindow: CGFloat = 0
    var windowWidth: CGFloat? = nil
    var windowEdgeInset: CGFloat = PlaybackChromeMetrics.progressWindowEdgeClampInset

    static func clampedX(
        targetX: CGFloat,
        capsuleWidth: CGFloat,
        containerWidth: CGFloat,
        containerOriginXInWindow: CGFloat = 0,
        windowWidth: CGFloat? = nil,
        windowEdgeInset: CGFloat = PlaybackChromeMetrics.progressWindowEdgeClampInset
    ) -> CGFloat {
        let resolvedItemWidth = max(0, capsuleWidth)
        if let windowWidth, windowWidth.isFinite, windowWidth > 0 {
            let resolvedInset = max(0, windowEdgeInset)
            let minX = -containerOriginXInWindow + resolvedInset
            let maxX = max(minX, windowWidth - containerOriginXInWindow - resolvedInset - resolvedItemWidth)
            return min(max(targetX - resolvedItemWidth / 2, minX), maxX)
        }
        let maxX = max(0, containerWidth - resolvedItemWidth)
        return min(max(targetX - resolvedItemWidth / 2, 0), maxX)
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let naturalHeight = subviews.first?.sizeThatFits(.unspecified).height ?? 0
        return CGSize(
            width: proposal.width ?? 0,
            height: proposal.height ?? naturalHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else {
            return
        }
        let naturalSize = subview.sizeThatFits(.unspecified)
        let x = Self.clampedX(
            targetX: targetX,
            capsuleWidth: naturalSize.width,
            containerWidth: bounds.width,
            containerOriginXInWindow: containerOriginXInWindow,
            windowWidth: windowWidth,
            windowEdgeInset: windowEdgeInset
        )
        subview.place(
            at: CGPoint(x: bounds.minX + x, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(naturalSize)
        )
    }
}
