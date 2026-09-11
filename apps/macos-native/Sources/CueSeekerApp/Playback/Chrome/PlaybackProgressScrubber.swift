import SwiftUI

struct PlaybackProgressScrubber: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @ObservedObject private var scrubTimeStore: PlaybackTimelineScrubTimeStore
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var hoverX: CGFloat? = nil
    @State private var isHoveringScrubber = false
    @State private var tooltipWidth: CGFloat = PlaybackChromeMetrics.progressTimeCapsuleMinWidth

    init(
        viewModel: PlaybackViewModel,
        timeline: PlaybackTimelineInteractionStore
    ) {
        self.viewModel = viewModel
        self.timeline = timeline
        _scrubTimeStore = ObservedObject(wrappedValue: timeline.scrubTimeStore)
    }

    var body: some View {
        GeometryReader { geometry in
            let duration = max(0, viewModel.duration)
            let isScrubbing = scrubTimeStore.scrubTime != nil
            let displayTime = scrubTimeStore.scrubTime ?? viewModel.displayedCurrentTime
            let progress = duration > 0
                ? min(max(displayTime / duration, 0), 1)
                : 0
            let width = max(0, geometry.size.width)
            let filledWidth = width * progress
            let trackHeight: CGFloat = (isHovered || isScrubbing)
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

                if !isScrubbing, isHoveringScrubber, let hoverX = hoverX {
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
                    .opacity(isHovered || isScrubbing ? 1 : 0)
            }
            .frame(height: PlaybackChromeMetrics.progressHitAreaHeight, alignment: .center)
            .contentShape(Rectangle())
            .playerInteractiveRegion()
            .onPointerHover { isHovered = $0 }
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoverX = point.x
                    isHoveringScrubber = true
                case .ended:
                    hoverX = nil
                    isHoveringScrubber = false
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        beginScrubbingIfNeeded()
                        guard duration > 0, width > 0 else {
                            return
                        }
                        let targetTime = seekTime(for: value.location.x, width: width, duration: duration)
                        scrubTimeStore.scrubTime = targetTime
                        viewModel.updateTimelineScrubbing(to: targetTime)
                    }
                    .onEnded { value in
                        guard duration > 0, width > 0 else {
                            viewModel.cancelTimelineScrubbing()
                            endScrubbingIfNeeded()
                            return
                        }
                        let finalTime = seekTime(for: value.location.x, width: width, duration: duration)
                        scrubTimeStore.scrubTime = finalTime
                        viewModel.endTimelineScrubbing(to: finalTime)
                        endScrubbingIfNeeded()
                    }
            )
            .overlay(
                Group {
                    if let targetX = targetX, (isHoveringScrubber || isScrubbing), duration > 0 {
                        let clampedX = min(max(targetX - tooltipWidth / 2, 0), width - tooltipWidth)

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
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear { tooltipWidth = geo.size.width }
                                        .onChange(of: geo.size.width) { tooltipWidth = $0 }
                                }
                            )
                            .background(
                                PlaybackCinematicBacking(
                                    shape: Capsule(),
                                    isHovered: false
                                )
                            )
                            .offset(x: clampedX, y: PlaybackChromeMetrics.progressTimeCapsuleYOffset)
                            .allowsHitTesting(false)
                    }
                },
                alignment: .topLeading
            )
        }
        .frame(height: PlaybackChromeMetrics.progressHitAreaHeight)
        .onDisappear {
            if isDragging {
                viewModel.cancelTimelineScrubbing()
            }
            endScrubbingIfNeeded()
        }
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
