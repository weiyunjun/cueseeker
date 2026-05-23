import SwiftUI

struct PlaybackProgressScrubber: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @Binding var scrubTime: Double?
    var onScrubbingChanged: (Bool) -> Void = { _ in }
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var hoverX: CGFloat? = nil
    @State private var isHoveringScrubber = false
    @State private var tooltipWidth: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let duration = max(0, viewModel.duration)
            let isScrubbing = scrubTime != nil
            let displayTime = scrubTime ?? viewModel.displayedCurrentTime
            let progress = duration > 0
                ? min(max(displayTime / duration, 0), 1)
                : 0
            let width = max(0, geometry.size.width)
            let filledWidth = width * progress
            let trackHeight: CGFloat = (isHovered || isScrubbing) ? 6 : 3

            let targetX = isScrubbing ? filledWidth : hoverX
            let tooltipTime: Double = {
                if let scrubTime {
                    return scrubTime
                }
                if let hoverX = hoverX {
                    return seekTime(for: hoverX, width: width, duration: duration)
                }
                return viewModel.displayedCurrentTime
            }()

            ZStack(alignment: .leading) {
                // 1. Base track (Persistent 0.60 Capsule Fill)
                Capsule()
                    .fill(PlaybackTheme.scrubberTrackBackground)
                    .frame(height: trackHeight)

                // 2. Hover highlight track (Only active between 0 and cursor position)
                if !isScrubbing, isHoveringScrubber, let hoverX = hoverX {
                    Capsule()
                        .fill(PlaybackTheme.scrubberHoverTrack)
                        .frame(width: max(0, hoverX), height: trackHeight)
                }

                // 3. Active progress track (YouTube signature red)
                Capsule()
                    .fill(PlaybackTheme.progressRed)
                    .frame(width: filledWidth, height: trackHeight)

                // 4. Scrubber Thumb (YouTube signature red)
                Circle()
                    .fill(PlaybackTheme.progressRed)
                    .frame(width: 12, height: 12)
                    .offset(x: filledWidth - 6)
                    .opacity(isHovered || isScrubbing ? 1 : 0)
            }
            .frame(height: 18, alignment: .center)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
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
                        scrubTime = targetTime
                        viewModel.updateTimelineScrubbing(to: targetTime)
                    }
                    .onEnded { value in
                        guard duration > 0, width > 0 else {
                            viewModel.cancelTimelineScrubbing()
                            endScrubbingIfNeeded()
                            return
                        }
                        let finalTime = seekTime(for: value.location.x, width: width, duration: duration)
                        scrubTime = finalTime
                        viewModel.endTimelineScrubbing(to: finalTime)
                        endScrubbingIfNeeded()
                    }
            )
            .overlay(
                Group {
                    if let targetX = targetX, (isHoveringScrubber || isScrubbing), duration > 0 {
                        let clampedX = min(max(targetX - tooltipWidth / 2, 0), width - tooltipWidth)

                        Text(formatPlaybackTime(tooltipTime))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PlaybackTheme.textPrimary)
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .frame(height: 22)
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
                            .offset(x: clampedX, y: -24)
                            .allowsHitTesting(false)
                    }
                },
                alignment: .topLeading
            )
        }
        .frame(height: 18)
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
        onScrubbingChanged(true)
    }

    private func endScrubbingIfNeeded() {
        guard isDragging else {
            return
        }

        isDragging = false
        scrubTime = nil
        onScrubbingChanged(false)
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
