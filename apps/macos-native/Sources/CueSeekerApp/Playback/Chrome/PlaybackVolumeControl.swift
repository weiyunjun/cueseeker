import SwiftUI

struct PlaybackVolumeControl: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .leading) {
            PlaybackChromeIconButton(
                systemName: volumeIcon,
                kind: .transport,
                accessibilityLabel: "Mute",
                action: viewModel.toggleMute
            )

            HStack(spacing: 8) {
                PlaybackVolumeSlider(volume: Binding(
                    get: { viewModel.volume },
                    set: { viewModel.setVolume($0, showsFeedback: false) }
                ))
                .frame(width: 86, height: 18)

                Text("\(Int(viewModel.volume.rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(0.86))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.28), radius: 14, y: 5)
            .opacity(isHovered ? 1 : 0)
            .offset(x: isHovered ? 44 : 40)
            .allowsHitTesting(isHovered)
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .zIndex(10)
        }
        .frame(width: 176, height: 40, alignment: .leading)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
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

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 5)

                Capsule()
                    .fill(Color.black.opacity(0.64))
                    .frame(width: width * progress, height: 5)
            }
            .frame(height: 18, alignment: .center)
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
