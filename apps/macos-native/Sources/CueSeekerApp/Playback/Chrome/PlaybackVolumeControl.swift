import SwiftUI

struct PlaybackVolumeControl: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                guard !timeline.isScrubbing else {
                    return
                }
                viewModel.toggleMute()
            } label: {
                Image(systemName: volumeIcon)
                    .font(.system(size: PlaybackChromeMetrics.circleButtonIconSize, weight: .semibold))
                    .foregroundStyle(PlaybackTheme.textPrimary)
                    .frame(
                        width: PlaybackChromeMetrics.circleButtonSize,
                        height: PlaybackChromeMetrics.capsuleButtonHeight
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mute")

            if isHovered {
                HStack(spacing: 4) {
                    PlaybackVolumeSlider(volume: Binding(
                        get: { viewModel.volume },
                        set: { viewModel.setVolume($0, showsFeedback: false) }
                    ))
                    .frame(width: 72, height: PlaybackChromeMetrics.capsuleButtonHeight)

                    Text("\(Int(viewModel.volume.rounded()))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PlaybackTheme.textPrimary)
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.trailing, 12)
                .transition(.opacity)
            }
        }
        .frame(
            width: isHovered ? 160 : PlaybackChromeMetrics.circleButtonSize,
            height: PlaybackChromeMetrics.capsuleButtonHeight,
            alignment: .leading
        )
        .background(
            PlaybackCinematicBacking(
                shape: RoundedRectangle(cornerRadius: PlaybackChromeMetrics.capsuleButtonHeight / 2),
                isHovered: !timeline.isScrubbing && isHovered,
                scaleX: isHovered ? 0.96 : 0.85,
                scaleY: 0.85
            )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.22)) {
                isHovered = timeline.isScrubbing ? false : hovering
            }
        }
        .onChange(of: timeline.isScrubbing) { isScrubbing in
            if isScrubbing {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isHovered = false
                }
            }
        }
    }

    private var volumeIcon: String {
        viewModel.volume <= 0 ? "speaker.slash.fill" : "speaker.wave.2.fill"
    }
}

private struct PlaybackVolumeSlider: View {
    @Binding var volume: Double

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width)
            let progress = min(max(volume / 100, 0), 1)
            let thumbSize: CGFloat = 10

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 3)

                Capsule()
                    .fill(Color.white)
                    .frame(width: width * progress, height: 3)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: max(0, (width - thumbSize) * progress))
            }
            .frame(height: PlaybackChromeMetrics.capsuleButtonHeight, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        volume = Double(min(max(value.location.x / max(width, 1), 0), 1)) * 100
                    }
            )
        }
    }
}
