import SwiftUI

struct PlaybackVolumeControl: View {
    @ObservedObject var viewModel: PlaybackViewModel
    var suppressesInteraction = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                guard !suppressesInteraction else {
                    return
                }
                viewModel.toggleMute()
            } label: {
                Image(systemName: volumeIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .frame(width: 40, height: 40)
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
                    .frame(width: 72, height: 40)

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
        .frame(width: isHovered ? 160 : 40, height: 40, alignment: .leading)
        .background(
            PlaybackCinematicBacking(
                shape: RoundedRectangle(cornerRadius: 20),
                isHovered: !suppressesInteraction && isHovered,
                scaleX: isHovered ? 0.96 : 0.85,
                scaleY: 0.85
            )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.22)) {
                isHovered = suppressesInteraction ? false : hovering
            }
        }
        .onChange(of: suppressesInteraction) { isSuppressed in
            if isSuppressed {
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
            .frame(height: 40, alignment: .center)
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
