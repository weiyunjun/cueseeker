import SwiftUI

struct PlaybackVolumeControl: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            PlaybackChromeIconButton(
                systemName: volumeIcon,
                kind: .transport,
                hasPersistentBase: false,
                accessibilityLabel: "Mute",
                action: viewModel.toggleMute
            )
            .frame(width: 40, height: 40)

            PlaybackVolumeSlider(volume: Binding(
                get: { viewModel.volume },
                set: { viewModel.setVolume($0, showsFeedback: false) }
            ))
            .frame(width: isHovered ? 72 : 0)
            .opacity(isHovered ? 1 : 0)
            .clipped()
        }
        .frame(width: isHovered ? 128 : 40, height: 40, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.10))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.22)) {
                isHovered = hovering
            }
        }
    }

    private var volumeIcon: String {
        if viewModel.volume <= 0 {
            return "speaker.slash.fill"
        }
        if viewModel.volume < 33 {
            return "speaker.wave.1.fill"
        }
        if viewModel.volume < 66 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
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
