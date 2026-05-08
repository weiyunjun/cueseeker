import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    let isFullscreen: Bool
    let isFullscreenToggleDisabled: Bool
    let onCopySubtitle: () -> Void
    let onSaveShiori: () -> Void
    let onToggleFullscreen: () -> Void
    
    @State private var isVolumeHovered = false
    @State private var isSpeedMenuVisible = false

    init(
        viewModel: PlaybackViewModel,
        isFullscreen: Bool = false,
        isFullscreenToggleDisabled: Bool = false,
        onCopySubtitle: @escaping () -> Void = {},
        onSaveShiori: @escaping () -> Void = {},
        onToggleFullscreen: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.isFullscreen = isFullscreen
        self.isFullscreenToggleDisabled = isFullscreenToggleDisabled
        self.onCopySubtitle = onCopySubtitle
        self.onSaveShiori = onSaveShiori
        self.onToggleFullscreen = onToggleFullscreen
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            playbackOperationZone
        }
        .overlay(alignment: .bottomTrailing) {
            if isSpeedMenuVisible {
                speedMenuHoverRegion
                    .padding(.trailing, PlaybackControlsLayout.speedMenuTrailingPadding)
                    .padding(.bottom, PlaybackControlsLayout.speedButtonBottomPadding)
                    .zIndex(10)
            }
        }
    }

    private var playbackOperationZone: some View {
        VStack(spacing: 0) {
            CustomProgressBar(
                currentTime: viewModel.displayedCurrentTime,
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

                volumeControl

                Text("\(formatTime(viewModel.displayedCurrentTime)) / \(formatTime(viewModel.duration))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    onSaveShiori()
                }) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(
                            width: PlaybackControlsLayout.iconButtonSize,
                            height: PlaybackControlsLayout.iconButtonSize
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Save Shiori")

                Button(action: {
                    onCopySubtitle()
                }) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(
                            width: PlaybackControlsLayout.iconButtonSize,
                            height: PlaybackControlsLayout.iconButtonSize
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Copy Current Subtitle")

                Button(action: {
                    viewModel.toggleSubtitles()
                }) {
                    Image(systemName: viewModel.areSubtitlesVisible ? "captions.bubble.fill" : "captions.bubble")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(viewModel.areSubtitlesVisible ? 1 : 0.55))
                        .frame(
                            width: PlaybackControlsLayout.iconButtonSize,
                            height: PlaybackControlsLayout.iconButtonSize
                        )
                }
                .buttonStyle(PlainButtonStyle())

                speedControl

                Button(action: {
                    onToggleFullscreen()
                }) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "viewfinder")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(
                            width: PlaybackControlsLayout.iconButtonSize,
                            height: PlaybackControlsLayout.iconButtonSize
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isFullscreenToggleDisabled)
                .opacity(isFullscreenToggleDisabled ? 0.55 : 1)
            }
            .padding(.horizontal, PlaybackControlsLayout.horizontalPadding)
            .padding(.bottom, PlaybackControlsLayout.transportRowBottomPadding)
            .frame(height: PlaybackControlsLayout.transportRowHeight, alignment: .center)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .contentShape(Rectangle())
    }
    
    private var volumeIcon: String {
        if viewModel.volume == 0 { return "speaker.slash.fill" }
        if viewModel.volume < 33 { return "speaker.wave.1.fill" }
        if viewModel.volume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var volumeControl: some View {
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
                        viewModel.setVolume(newValue, showsFeedback: false)
                    }
                ))
                .frame(width: 80, height: 20)

                Text("\(Int(viewModel.volume.rounded()))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .frame(height: 24, alignment: .center)
        .onHover { hovering in
            isVolumeHovered = hovering
        }
    }

    private var speedControl: some View {
        speedButton
            .onHover { hovering in
                if hovering {
                    showSpeedMenu()
                }
            }
    }

    private var speedButton: some View {
        Button {
            showSpeedMenu()
        } label: {
            Text(PlaybackViewModel.formatSpeed(viewModel.playbackSpeed))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: true, vertical: false)
                .frame(
                    width: PlaybackControlsLayout.speedMenuWidth,
                    height: PlaybackControlsLayout.speedButtonHeight,
                    alignment: .center
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var speedMenuHoverRegion: some View {
        VStack(spacing: 0) {
            PlaybackSpeedMenu(
                selectedSpeed: viewModel.playbackSpeed,
                onSelect: { speed in
                    viewModel.setSpeed(speed)
                    hideSpeedMenu()
                }
            )

            Color.clear
                .frame(
                    width: PlaybackControlsLayout.speedMenuWidth,
                    height: PlaybackControlsLayout.speedButtonHeight
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    showSpeedMenu()
                }
        }
        .frame(width: PlaybackControlsLayout.speedMenuWidth)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                showSpeedMenu()
            } else {
                hideSpeedMenu()
            }
        }
    }

    private func showSpeedMenu() {
        isSpeedMenuVisible = true
    }

    private func hideSpeedMenu() {
        isSpeedMenuVisible = false
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds.isNaN || seconds.isInfinite ? 0 : seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

private enum PlaybackControlsLayout {
    static let horizontalPadding: CGFloat = 12
    static let transportRowBottomPadding: CGFloat = 12
    static let transportRowHeight: CGFloat = 36
    static let trailingControlSpacing: CGFloat = 16
    static let iconButtonSize: CGFloat = 24
    static let speedMenuWidth: CGFloat = 96
    static let speedButtonHeight: CGFloat = 24
    static let speedMenuTrailingPadding = horizontalPadding + iconButtonSize + trailingControlSpacing
    static let speedButtonBottomPadding = transportRowBottomPadding + ((transportRowHeight - speedButtonHeight) / 2)
}

private struct PlaybackSpeedMenu: View {
    let selectedSpeed: Double
    let onSelect: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(PlaybackViewModel.speedPresets, id: \.self) { speed in
                Button {
                    onSelect(speed)
                } label: {
                    HStack(spacing: 10) {
                        Text(PlaybackViewModel.formatSpeed(speed))
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
                    .frame(width: PlaybackControlsLayout.speedMenuWidth, height: 28)
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
