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

    @Published private(set) var thumbnailImage: CGImage?
    @Published private(set) var thumbnailAspectRatio: Double?

    private let keyframeLookup: KeyframeLookup
    private let requestThumbnail: ThumbnailRequester
    private let cancelRequests: CancelRequests
    private let debounceDelay: TimeInterval

    private var isSessionActive = false
    private var activeTargetKeyframeIdentity: Int?
    private var displayedKeyframeIdentity: Int?
    private var inFlightKeyframeIdentity: Int?
    private var debounceTask: Task<Void, Never>?
    private var activeRequestGeneration: UInt64 = 0

    convenience init(player: PlaybackPlayer) {
        self.init(
            debounceDelay: PlaybackChromeMetrics.progressThumbnailDebounceDelay,
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
        debounceDelay: TimeInterval = PlaybackChromeMetrics.progressThumbnailDebounceDelay,
        keyframeLookup: @escaping KeyframeLookup,
        requestThumbnail: @escaping ThumbnailRequester,
        cancelRequests: @escaping CancelRequests
    ) {
        self.debounceDelay = debounceDelay
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

        if !isSessionActive {
            isSessionActive = true
            activeTargetKeyframeIdentity = keyframeIdentity
            performThumbnailRequest(
                targetMilliseconds: targetMilliseconds,
                keyframeIdentity: keyframeIdentity,
                targetPixelWidth: targetPixelWidth
            )
            return
        }

        guard keyframeIdentity != activeTargetKeyframeIdentity else {
            return
        }

        activeTargetKeyframeIdentity = keyframeIdentity
        debounceTask?.cancel()
        debounceTask = nil

        if (displayedKeyframeIdentity == keyframeIdentity && thumbnailImage != nil && inFlightKeyframeIdentity == nil)
            || inFlightKeyframeIdentity == keyframeIdentity {
            return
        }

        let delayNanoseconds = UInt64(max(0, debounceDelay) * 1_000_000_000)
        debounceTask = Task { @MainActor [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled,
                  let self,
                  self.isSessionActive,
                  self.activeTargetKeyframeIdentity == keyframeIdentity
            else {
                return
            }
            self.debounceTask = nil
            self.performThumbnailRequest(
                targetMilliseconds: targetMilliseconds,
                keyframeIdentity: keyframeIdentity,
                targetPixelWidth: targetPixelWidth
            )
        }
    }

    func clear() {
        let hadActiveState = isSessionActive
            || debounceTask != nil
            || inFlightKeyframeIdentity != nil
            || thumbnailImage != nil
            || thumbnailAspectRatio != nil
        guard hadActiveState else {
            return
        }

        isSessionActive = false
        activeTargetKeyframeIdentity = nil
        displayedKeyframeIdentity = nil
        inFlightKeyframeIdentity = nil
        debounceTask?.cancel()
        debounceTask = nil
        activeRequestGeneration &+= 1
        if thumbnailImage != nil {
            thumbnailImage = nil
        }
        if thumbnailAspectRatio != nil {
            thumbnailAspectRatio = nil
        }
        cancelRequests()
    }

    private func performThumbnailRequest(
        targetMilliseconds: Int,
        keyframeIdentity: Int,
        targetPixelWidth: Int
    ) {
        activeRequestGeneration &+= 1
        let generation = activeRequestGeneration
        inFlightKeyframeIdentity = keyframeIdentity

        requestThumbnail(targetMilliseconds, targetPixelWidth) { [weak self] image, _, videoSize in
            guard let self,
                  self.isSessionActive,
                  self.activeRequestGeneration == generation
            else {
                return
            }

            self.inFlightKeyframeIdentity = nil
            guard let image else {
                return
            }

            if let videoSize, videoSize.width > 0, videoSize.height > 0 {
                let nextAspectRatio = Double(videoSize.width / videoSize.height)
                if nextAspectRatio.isFinite,
                   nextAspectRatio > 0,
                   self.thumbnailAspectRatio != nextAspectRatio {
                    self.thumbnailAspectRatio = nextAspectRatio
                }
            }
            self.displayedKeyframeIdentity = keyframeIdentity
            self.thumbnailImage = image
        }
    }
}

struct PlaybackProgressScrubber: View {
    @Environment(\.displayScale) private var displayScale
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @ObservedObject private var scrubTimeStore: PlaybackTimelineScrubTimeStore
    @ObservedObject private var thumbnailStore: PlaybackTimelineThumbnailStore
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var hoverX: CGFloat? = nil
    @State private var isHoveringScrubber = false

    init(
        viewModel: PlaybackViewModel,
        timeline: PlaybackTimelineInteractionStore
    ) {
        self.viewModel = viewModel
        self.timeline = timeline
        _scrubTimeStore = ObservedObject(wrappedValue: timeline.scrubTimeStore)
        _thumbnailStore = ObservedObject(wrappedValue: viewModel.timelineThumbnailStore)
    }

    var body: some View {
        GeometryReader { geometry in
            let duration = viewModel.duration.isFinite ? max(0, viewModel.duration) : 0
            let hasDuration = duration > 0
            let isScrubbing = hasDuration && scrubTimeStore.scrubTime != nil
            let isInteractiveHover = hasDuration && isHovered
            let displayTime = scrubTimeStore.scrubTime ?? viewModel.displayedCurrentTime
            let progress = hasDuration
                ? min(max(displayTime / duration, 0), 1)
                : 0
            let width = max(0, geometry.size.width)
            let filledWidth = width * progress
            let trackHeight: CGFloat = (isInteractiveHover || isScrubbing)
                ? PlaybackChromeMetrics.progressTrackHoverHeight
                : PlaybackChromeMetrics.progressTrackHeight

            let targetX = isScrubbing ? filledWidth : hoverX
            let tooltipTime: Double = {
                if let scrubTime = scrubTimeStore.scrubTime {
                    return scrubTime
                }
                if let hoverX = hoverX {
                    return seekTime(for: hoverX, width: width, duration: duration)
                }
                return viewModel.displayedCurrentTime
            }()

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PlaybackTheme.progressTrack)
                    .frame(height: trackHeight)

                if !isScrubbing, isInteractiveHover, isHoveringScrubber, let hoverX = hoverX {
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
                isHovered = hovered
                syncThumbnailPreview(width: width, duration: duration)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoverX = point.x
                    isHoveringScrubber = true
                case .ended:
                    hoverX = nil
                    isHoveringScrubber = false
                }
                syncThumbnailPreview(width: width, duration: duration)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard hasDuration, width > 0 else {
                            return
                        }
                        beginScrubbingIfNeeded()
                        let targetTime = seekTime(for: value.location.x, width: width, duration: duration)
                        scrubTimeStore.scrubTime = targetTime
                        viewModel.updateTimelineScrubbing(to: targetTime)
                        viewModel.updateTimelineThumbnailPreview(
                            at: targetTime,
                            backingScaleFactor: displayScale
                        )
                    }
                    .onEnded { value in
                        guard hasDuration, width > 0 else {
                            if isDragging {
                                viewModel.cancelTimelineScrubbing()
                                endScrubbingIfNeeded()
                            }
                            syncThumbnailPreview(width: width, duration: duration)
                            return
                        }
                        let finalTime = seekTime(for: value.location.x, width: width, duration: duration)
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
                    if let targetX = targetX, ((isInteractiveHover && isHoveringScrubber) || isScrubbing) {
                        if let thumbnailImage = thumbnailStore.thumbnailImage {
                            let aspectRatio = thumbnailStore.thumbnailAspectRatio ?? viewModel.videoAspectRatio
                            let thumbnailSize = PlaybackChromeMetrics.progressThumbnailSize(
                                aspectRatio: aspectRatio
                            )
                            PlaybackProgressTimeCapsulePlacementLayout(targetX: targetX) {
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

                        PlaybackProgressTimeCapsulePlacementLayout(targetX: targetX) {
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
            if isDragging {
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

        if isHovered, isHoveringScrubber, let hoverX {
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
        guard !isDragging else {
            return
        }

        isDragging = true
        viewModel.beginTimelineScrubbing()
        timeline.isScrubbing = true
    }

    private func endScrubbingIfNeeded() {
        guard isDragging else {
            return
        }

        isDragging = false
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

    static func clampedX(
        targetX: CGFloat,
        capsuleWidth: CGFloat,
        containerWidth: CGFloat
    ) -> CGFloat {
        let maxX = max(0, containerWidth - max(0, capsuleWidth))
        return min(max(targetX - max(0, capsuleWidth) / 2, 0), maxX)
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
            containerWidth: bounds.width
        )
        subview.place(
            at: CGPoint(x: bounds.minX + x, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(naturalSize)
        )
    }
}
