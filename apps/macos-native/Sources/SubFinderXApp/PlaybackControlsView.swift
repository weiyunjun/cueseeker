import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    let isFullscreen: Bool
    let onToggleFullscreen: () -> Void
    
    @State private var isVolumeHovered = false
    @State private var isSpeedMenuVisible = false

    init(
        viewModel: PlaybackViewModel,
        isFullscreen: Bool = false,
        onToggleFullscreen: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.isFullscreen = isFullscreen
        self.onToggleFullscreen = onToggleFullscreen
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            playbackOperationZone
        }
        .overlay(alignment: .bottomTrailing) {
            if isSpeedMenuVisible {
                PlaybackSpeedMenu(
                    selectedSpeed: viewModel.playbackSpeed,
                    onSelect: { speed in
                        viewModel.setSpeed(speed)
                        isSpeedMenuVisible = false
                    }
                )
                .padding(.trailing, 44)
                .padding(.bottom, 44)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.14), value: isSpeedMenuVisible)
    }

    private var playbackOperationZone: some View {
        VStack(spacing: 0) {
            CustomProgressBar(
                currentTime: $viewModel.currentTime,
                duration: viewModel.duration,
                onSeek: { time in
                    viewModel.seek(to: time)
                }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            HStack(spacing: 16) {
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())

                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.setVolume(viewModel.volume > 0 ? 0 : 100)
                    }) {
                        Image(systemName: volumeIcon)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 20)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if isVolumeHovered {
                        CustomVolumeSlider(volume: Binding(
                            get: { viewModel.volume },
                            set: { newValue in
                                viewModel.volume = newValue
                                viewModel.setVolume(newValue)
                            }
                        ))
                        .frame(width: 80, height: 20)
                    }
                }
                .onHover { hovering in
                    isVolumeHovered = hovering
                }

                Text("\(formatTime(viewModel.currentTime)) / \(formatTime(viewModel.duration))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    viewModel.toggleSubtitles()
                }) {
                    Image(systemName: viewModel.areSubtitlesVisible ? "captions.bubble.fill" : "captions.bubble")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(viewModel.areSubtitlesVisible ? 1 : 0.55))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    DispatchQueue.main.async {
                        isSpeedMenuVisible.toggle()
                    }
                }) {
                    HStack(spacing: 2) {
                        Text(String(format: "%.1fx", viewModel.playbackSpeed))
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    onToggleFullscreen()
                }) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "viewfinder")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSpeedMenuVisible {
                isSpeedMenuVisible = false
            }
        }
    }
    
    private var volumeIcon: String {
        if viewModel.volume == 0 { return "speaker.slash.fill" }
        if viewModel.volume < 33 { return "speaker.wave.1.fill" }
        if viewModel.volume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds.isNaN || seconds.isInfinite ? 0 : seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

private struct PlaybackSpeedMenu: View {
    let selectedSpeed: Double
    let onSelect: (Double) -> Void

    private let speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(speeds, id: \.self) { speed in
                Button {
                    onSelect(speed)
                } label: {
                    HStack(spacing: 10) {
                        Text(formatSpeed(speed))
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 42, alignment: .leading)

                        Spacer(minLength: 0)

                        if abs(selectedSpeed - speed) < 0.01 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(width: 96, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.82))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 4)
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed.rounded() == speed {
            return String(format: "%.0fx", speed)
        }

        if (speed * 10).rounded() == speed * 10 {
            return String(format: "%.1fx", speed)
        }

        return String(format: "%.2fx", speed)
    }
}

struct CustomVolumeSlider: View {
    @Binding var volume: Double

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let thumbX = totalWidth * (max(0, min(100, volume)) / 100)
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)
                
                Rectangle()
                    .fill(Color.white)
                    .frame(width: thumbX, height: 3)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .offset(x: thumbX - 5)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percent = max(0, min(1, value.location.x / totalWidth))
                        volume = percent * 100
                    }
            )
        }
    }
}
