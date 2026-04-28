import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    
    @State private var isVolumeHovered = false
    @State private var isSpeedMenuVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
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
                    // Play/Pause
                    Button(action: {
                        viewModel.togglePlayPause()
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Volume Control
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
                            Slider(value: Binding(
                                get: { viewModel.volume },
                                set: { newValue in
                                    viewModel.volume = newValue
                                    viewModel.setVolume(newValue)
                                }
                            ), in: 0...100)
                            .frame(width: 80)
                            .controlSize(.mini)
                        }
                    }
                    .onHover { hovering in
                        isVolumeHovered = hovering
                    }
                    
                    // Time Display
                    Text("\(formatTime(viewModel.currentTime)) / \(formatTime(viewModel.duration))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Subtitles (CC)
                    Button(action: {
                        print("Subtitles clicked")
                    }) {
                        Image(systemName: "captions.bubble.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Speed Control
                    Button(action: {
                        isSpeedMenuVisible.toggle()
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
                    .popover(isPresented: $isSpeedMenuVisible, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                                Button(action: {
                                    viewModel.setSpeed(speed)
                                    isSpeedMenuVisible = false
                                }) {
                                    HStack {
                                        Text(String(format: "%.1fx", speed))
                                        Spacer()
                                        if abs(viewModel.playbackSpeed - speed) < 0.01 {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .frame(width: 80)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Fullscreen
                    Button(action: {
                        print("Fullscreen clicked")
                        if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                            window.toggleFullScreen(nil)
                        }
                    }) {
                        Image(systemName: "viewfinder")
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
