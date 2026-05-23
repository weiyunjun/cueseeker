import SwiftUI

struct PlaybackProgressScrubber: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @State private var isHovered = false
    @State private var dragTime: Double?
    @State private var hoverX: CGFloat? = nil
    @State private var isHoveringScrubber = false

    var body: some View {
        GeometryReader { geometry in
            let duration = max(0, viewModel.duration)
            let displayTime = dragTime ?? viewModel.displayedCurrentTime
            let progress = duration > 0
                ? min(max(displayTime / duration, 0), 1)
                : 0
            let width = max(0, geometry.size.width)
            let filledWidth = width * progress
            let trackHeight: CGFloat = (isHovered || dragTime != nil) ? 6 : 3

            let targetX = hoverX ?? (dragTime != nil ? filledWidth : nil)
            let tooltipTime: Double = {
                if let hoverX = hoverX {
                    return seekTime(for: hoverX, width: width, duration: duration)
                }
                return dragTime ?? viewModel.displayedCurrentTime
            }()

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.white.opacity(0.68))
                    .frame(width: filledWidth, height: trackHeight)

                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 12, height: 12)
                    .offset(x: filledWidth - 6)
                    .opacity(isHovered || dragTime != nil ? 1 : 0)
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
                        guard duration > 0, width > 0 else {
                            return
                        }
                        dragTime = seekTime(for: value.location.x, width: width, duration: duration)
                    }
                    .onEnded { value in
                        guard duration > 0, width > 0 else {
                            dragTime = nil
                            return
                        }
                        let finalTime = seekTime(for: value.location.x, width: width, duration: duration)
                        dragTime = nil
                        viewModel.seek(to: finalTime)
                    }
            )
            .overlay(
                Group {
                    if let targetX = targetX, (isHoveringScrubber || dragTime != nil), duration > 0 {
                        let isLongDuration = duration >= 3600
                        let tooltipWidth: CGFloat = isLongDuration ? 56 : 42
                        let clampedX = min(max(targetX - tooltipWidth / 2, 0), width - tooltipWidth)

                        Text(formatPlaybackTime(tooltipTime))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PlaybackTheme.textPrimary)
                            .monospacedDigit()
                            .padding(.horizontal, 6)
                            .frame(width: tooltipWidth, height: 22)
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
