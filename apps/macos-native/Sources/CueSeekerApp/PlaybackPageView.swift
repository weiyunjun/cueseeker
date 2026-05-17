import SwiftUI

struct PlaybackPageView: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppState
    let onClose: () -> Void
    @State private var activePanel: PlaybackDrawerKind = .results

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = playbackSidebarWidth(
                totalWidth: geometry.size.width,
                isVisible: appState.isPlaybackSidePanelVisible
            )
            let stageWidth = max(0, geometry.size.width - sidebarWidth)

            HStack(spacing: 0) {
                PlaybackVideoStage(
                    playbackSurface: playbackSurface,
                    appState: appState,
                    onClose: onClose
                )
                .frame(width: stageWidth, height: geometry.size.height)

                if sidebarWidth > 0 {
                    PlaybackSidebarShell(
                        appState: appState,
                        activePanel: $activePanel
                    )
                    .frame(width: sidebarWidth, height: geometry.size.height)
                    .transition(.opacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
        .background(Color.black)
        .onAppear {
            refreshSidebarData()
            if let request = appState.playbackDrawerRequest {
                activePanel = request.drawer
            }
        }
        .onChange(of: appState.playbackDrawerRequest?.id) { _ in
            guard let request = appState.playbackDrawerRequest else {
                return
            }

            activePanel = request.drawer
            refreshSidebarData()
        }
        .onChange(of: appState.currentPlaybackSubtitlePath) { _ in
            refreshSidebarData()
        }
    }

    private func refreshSidebarData() {
        appState.refreshSearchNavigationSnapshot()
        appState.refreshCurrentSubtitleEntries()
    }

    private func playbackSidebarWidth(totalWidth: CGFloat, isVisible: Bool) -> CGFloat {
        guard isVisible else {
            return 0
        }

        let maximumPanelWidth: CGFloat = 380
        let minimumPanelWidth: CGFloat = 320
        let minimumStageWidth: CGFloat = 520
        let availablePanelWidth = totalWidth - minimumStageWidth

        guard availablePanelWidth >= minimumPanelWidth else {
            return 0
        }

        return min(maximumPanelWidth, availablePanelWidth)
    }
}

private struct PlaybackVideoStage: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppState
    let onClose: () -> Void
    @State private var isChromeVisible = true
    @State private var chromeHideTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let stageSize = geometry.size
            let frame = aspectFitFrame(
                containerSize: stageSize,
                aspectRatio: videoAspectRatio
            )

            ZStack(alignment: .topLeading) {
                Color.black

                playbackSurface
                    .frame(width: frame.width, height: frame.height)
                    .background(Color.black)
                    .position(x: frame.midX, y: frame.midY)

                PlaybackCloseButton(action: onClose)
                    .offset(x: frame.minX + 18, y: frame.minY + 18)

                if case .failed(let message) = appState.playbackStatus {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .offset(x: frame.minX + 18, y: frame.minY + 72)
                }

                if let viewModel = appState.playbackViewModel {
                    PlaybackChromeView(
                        appState: appState,
                        viewModel: viewModel
                    )
                    .frame(
                        width: max(0, stageSize.width - PlaybackPageMetrics.chromeHorizontalInset * 2),
                        height: PlaybackPageMetrics.chromeHeight
                    )
                    .opacity(isChromeVisible ? 1 : 0)
                    .offset(y: isChromeVisible ? 0 : PlaybackPageMetrics.chromeHiddenOffset)
                    .allowsHitTesting(isChromeVisible)
                    .animation(.easeOut(duration: 0.18), value: isChromeVisible)
                    .position(
                        x: stageSize.width / 2,
                        y: max(
                            PlaybackPageMetrics.chromeHeight / 2,
                            stageSize.height - PlaybackPageMetrics.chromeBottomInset - PlaybackPageMetrics.chromeHeight / 2
                        )
                    )
                }
            }
            .frame(width: stageSize.width, height: stageSize.height)
            .clipped()
            .onAppear {
                showChromeTemporarily()
            }
            .onDisappear {
                chromeHideTask?.cancel()
                chromeHideTask = nil
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(_):
                    showChromeTemporarily()
                case .ended:
                    hideChrome()
                }
            }
        }
    }

    private var videoAspectRatio: CGFloat {
        let ratio = CGFloat(appState.playbackViewModel?.videoAspectRatio ?? 16 / 9)
        return ratio.isFinite && ratio > 0 ? ratio : 16 / 9
    }

    private func aspectFitFrame(containerSize: CGSize, aspectRatio: CGFloat) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let containerRatio = containerSize.width / containerSize.height
        let frameSize: CGSize
        if containerRatio > aspectRatio {
            let height = containerSize.height
            frameSize = CGSize(width: height * aspectRatio, height: height)
        } else {
            let width = containerSize.width
            frameSize = CGSize(width: width, height: width / aspectRatio)
        }

        return CGRect(
            x: (containerSize.width - frameSize.width) / 2,
            y: (containerSize.height - frameSize.height) / 2,
            width: frameSize.width,
            height: frameSize.height
        )
    }

    private func showChromeTemporarily() {
        withAnimation(.easeOut(duration: 0.14)) {
            isChromeVisible = true
        }
        chromeHideTask?.cancel()
        chromeHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else {
                return
            }
            withAnimation(.easeOut(duration: 0.18)) {
                isChromeVisible = false
            }
        }
    }

    private func hideChrome() {
        chromeHideTask?.cancel()
        chromeHideTask = nil
        withAnimation(.easeOut(duration: 0.16)) {
            isChromeVisible = false
        }
    }
}

private struct PlaybackCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))

                Text("Close")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(height: 42)
            .padding(.leading, 13)
            .padding(.trailing, 16)
            .contentShape(Capsule())
        }
        .buttonStyle(PlaybackCloseButtonStyle())
        .accessibilityLabel("Close video")
    }
}

private struct PlaybackCloseButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .background(.ultraThinMaterial, in: Capsule())
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        Color.white.opacity(isHovered ? 0.24 : 0.16),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.42), radius: 20, y: 12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.72), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color(red: 0.14, green: 0.14, blue: 0.17).opacity(0.78)
        }
        if isHovered {
            return Color(red: 0.16, green: 0.16, blue: 0.19).opacity(0.72)
        }
        return Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.58)
    }
}

private struct PlaybackChromeView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var viewModel: PlaybackViewModel
    @State private var isSpeedMenuVisible = false

    var body: some View {
        VStack(spacing: 0) {
            scrubberRow

            ZStack {
                HStack(spacing: 0) {
                    PlaybackVolumeControl(viewModel: viewModel)

                    Spacer(minLength: 0)

                    operationsCluster
                }
                .padding(.horizontal, 28)

                transportCluster
            }
            .frame(height: 58)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.48))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.36), radius: 26, y: 14)
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }

    private var scrubberRow: some View {
        HStack(spacing: 12) {
            Text(formatPlaybackTime(viewModel.displayedCurrentTime))
                .frame(width: 46, alignment: .leading)

            PlaybackProgressScrubber(viewModel: viewModel)

            Text(formatPlaybackTime(viewModel.duration))
                .frame(width: 46, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.82))
        .monospacedDigit()
        .padding(.horizontal, 28)
        .frame(height: 34)
    }

    private var transportCluster: some View {
        HStack(spacing: 8) {
            PlaybackChromeIconButton(
                systemName: "backward.end.fill",
                kind: .transport,
                isDisabled: !appState.canOpenPreviousLibraryVideo,
                accessibilityLabel: "Previous episode",
                action: appState.openPreviousLibraryVideo
            )

            PlaybackChromeIconButton(
                systemName: "chevron.left",
                kind: .transport,
                isDisabled: !appState.canOpenPreviousSearchResult,
                accessibilityLabel: "Previous result",
                action: {
                    appState.openAdjacentSearchResult(.previous)
                }
            )

            PlaybackChromeIconButton(
                systemName: viewModel.isPlaying ? "pause.fill" : "play.fill",
                kind: .primaryTransport,
                accessibilityLabel: viewModel.isPlaying ? "Pause" : "Play",
                action: appState.togglePlaybackFromUser
            )

            PlaybackChromeIconButton(
                systemName: "chevron.right",
                kind: .transport,
                isDisabled: !appState.canOpenNextSearchResult,
                accessibilityLabel: "Next result",
                action: {
                    appState.openAdjacentSearchResult(.next)
                }
            )

            PlaybackChromeIconButton(
                systemName: "forward.end.fill",
                kind: .transport,
                isDisabled: !appState.canOpenNextLibraryVideo,
                accessibilityLabel: "Next episode",
                action: appState.openNextLibraryVideo
            )
        }
    }

    private var operationsCluster: some View {
        HStack(spacing: 6) {
            PlaybackChromeIconButton(
                systemName: "bookmark",
                accessibilityLabel: "Shiori",
                action: {
                    _ = appState.toggleCurrentShiori()
                }
            )

            PlaybackChromeIconButton(
                systemName: "doc.on.doc",
                accessibilityLabel: "Copy current subtitle",
                action: {
                    _ = appState.copyCurrentSubtitleToClipboard()
                }
            )

            PlaybackChromeIconButton(
                systemName: viewModel.areSubtitlesVisible ? "captions.bubble.fill" : "captions.bubble",
                isSelected: viewModel.areSubtitlesVisible,
                accessibilityLabel: "Subtitles",
                action: viewModel.toggleSubtitles
            )

            PlaybackChromeIconButton(
                systemName: "list.bullet",
                isSelected: appState.isPlaybackSidePanelVisible,
                accessibilityLabel: "Results panel",
                action: appState.togglePlaybackSidePanelFromUser
            )

            speedControl

            PlaybackChromeIconButton(
                systemName: appState.playbackFullscreenManager.isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "viewfinder",
                isDisabled: appState.isPlaybackFullscreenToggleDisabled,
                accessibilityLabel: "Fullscreen",
                action: {
                    appState.togglePlaybackFullscreenFromUser(
                        onCopySubtitle: {
                            _ = appState.copyCurrentSubtitleToClipboard()
                        },
                        onSaveShiori: {
                            _ = appState.toggleCurrentShiori()
                        }
                    )
                }
            )
        }
    }

    private var speedControl: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                isSpeedMenuVisible.toggle()
            } label: {
                Text(PlaybackViewModel.formatSpeed(viewModel.playbackSpeed))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: 54, height: 28)
                    .contentShape(Capsule())
            }
            .buttonStyle(PlaybackChromeCapsuleButtonStyle(isActive: isSpeedMenuVisible))
            .accessibilityLabel("Playback speed")

            if isSpeedMenuVisible {
                PlaybackChromeSpeedMenu(
                    selectedSpeed: viewModel.playbackSpeed,
                    onSelect: { speed in
                        viewModel.setSpeed(speed)
                        isSpeedMenuVisible = false
                    }
                )
                .offset(y: -40)
                .zIndex(20)
            }
        }
        .frame(width: 54, height: 32)
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

private struct PlaybackProgressScrubber: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @State private var isHovered = false
    @State private var dragTime: Double?

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
        }
        .frame(height: 18)
    }

    private func seekTime(for xPosition: CGFloat, width: CGFloat, duration: Double) -> Double {
        let progress = Double(min(max(xPosition / max(width, 1), 0), 1))
        return progress * duration
    }
}

private struct PlaybackVolumeControl: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .leading) {
            PlaybackChromeIconButton(
                systemName: volumeIcon,
                accessibilityLabel: "Mute",
                action: viewModel.toggleMute
            )

            if isHovered {
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
                .offset(x: 36)
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .zIndex(10)
            }
        }
        .frame(width: 176, height: 32, alignment: .leading)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
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

private struct PlaybackChromeSpeedMenu: View {
    let selectedSpeed: Double
    let onSelect: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(PlaybackViewModel.speedPresets, id: \.self) { speed in
                Button {
                    onSelect(speed)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .opacity(abs(selectedSpeed - speed) < 0.01 ? 1 : 0)
                            .frame(width: 14)

                        Text(PlaybackViewModel.formatSpeed(speed))
                            .font(.system(size: 13, weight: abs(selectedSpeed - speed) < 0.01 ? .bold : .medium))
                            .monospacedDigit()

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 8)
                    .frame(width: 160, height: 30)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlaybackChromeMenuButtonStyle(isSelected: abs(selectedSpeed - speed) < 0.01))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.86))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.42), radius: 24, y: 12)
    }
}

private enum PlaybackChromeButtonKind {
    case circle
    case transport
    case primaryTransport

    var size: CGFloat {
        switch self {
        case .circle:
            return 32
        case .transport:
            return 40
        case .primaryTransport:
            return 44
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .circle:
            return 15
        case .transport:
            return 18
        case .primaryTransport:
            return 20
        }
    }
}

private struct PlaybackChromeIconButton: View {
    let systemName: String
    var kind: PlaybackChromeButtonKind = .circle
    var isSelected = false
    var isDisabled = false
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: kind.symbolSize, weight: .semibold))
                .frame(width: kind.size, height: kind.size)
                .contentShape(Circle())
        }
        .buttonStyle(PlaybackChromeIconButtonStyle(kind: kind, isSelected: isSelected))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.34 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PlaybackChromeIconButtonStyle: ButtonStyle {
    let kind: PlaybackChromeButtonKind
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .background(materialBackground(isPressed: configuration.isPressed))
            )
            .overlay(
                Circle()
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.94 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.72), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return .white.opacity(0.46)
        }
        return isSelected ? Color(red: 0.10, green: 0.10, blue: 0.12) : .white.opacity(0.96)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return .clear
        }
        if isSelected {
            return Color.white.opacity(isPressed ? 0.82 : 0.92)
        }
        if isHovered || isPressed {
            return Color.white.opacity(isPressed ? 0.14 : 0.18)
        }
        return .clear
    }

    @ViewBuilder
    private func materialBackground(isPressed: Bool) -> some View {
        if isEnabled && (isHovered || isSelected || isPressed) {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }

    private var borderColor: Color {
        guard isEnabled else {
            return .clear
        }
        if isSelected {
            return Color.white.opacity(0.7)
        }
        return isHovered ? Color.white.opacity(0.10) : .clear
    }

    private var shadowColor: Color {
        isSelected ? Color.black.opacity(0.22) : Color.black.opacity(0)
    }

    private var shadowRadius: CGFloat {
        isSelected ? 4 : 0
    }

    private var shadowY: CGFloat {
        isSelected ? 1 : 0
    }
}

private struct PlaybackChromeCapsuleButtonStyle: ButtonStyle {
    let isActive: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .background(.ultraThinMaterial, in: Capsule())
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.72), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed || isActive || isHovered {
            return Color.white.opacity(0.20)
        }
        return Color.white.opacity(0.12)
    }
}

private struct PlaybackChromeMenuButtonStyle: ButtonStyle {
    let isSelected: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed || isHovered {
            return Color.white.opacity(0.14)
        }
        if isSelected {
            return Color.white.opacity(0.10)
        }
        return .clear
    }
}

private struct PlaybackSidebarShell: View {
    @ObservedObject var appState: AppState
    @Binding var activePanel: PlaybackDrawerKind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 2) {
                    sidebarTab(.results, title: "Search Results")
                    sidebarTab(.subtitles, title: "Subtitles")
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.black.opacity(0.06))
                )

                Text(summaryText)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.42))
                    .monospacedDigit()
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 0.5)
            }

            Spacer(minLength: 0)
        }
        .background(
            Color(red: 0.972, green: 0.972, blue: 0.98).opacity(0.55)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 0.5)
        }
    }

    private func sidebarTab(_ panel: PlaybackDrawerKind, title: String) -> some View {
        Button {
            activePanel = panel
            switch panel {
            case .results:
                appState.refreshSearchNavigationSnapshot()
            case .subtitles:
                appState.refreshCurrentSubtitleEntries()
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: activePanel == panel ? .semibold : .medium))
                .foregroundStyle(activePanel == panel ? Color.primary.opacity(0.9) : Color.primary.opacity(0.48))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(activePanel == panel ? Color.white.opacity(0.85) : Color.clear)
                        .shadow(color: .black.opacity(activePanel == panel ? 0.08 : 0), radius: 2, y: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        switch activePanel {
        case .results:
            let groupedCount = appState.searchNavigationResultGroups.reduce(0) { $0 + $1.results.count }
            let fallbackCount = appState.searchResultTotalCount > 0
                ? appState.searchResultTotalCount
                : appState.searchResults.count
            let count = appState.searchNavigationSnapshot?.totalCount
                ?? (groupedCount > 0 ? groupedCount : fallbackCount)
            return "\(count) \(count == 1 ? "result" : "results")"
        case .subtitles:
            let count = appState.currentSubtitleEntries.count
            return "\(count) \(count == 1 ? "subtitle" : "subtitles")"
        }
    }
}

private enum PlaybackPageMetrics {
    static let chromeHorizontalInset: CGFloat = 20
    static let chromeBottomInset: CGFloat = 20
    static let chromeHeight: CGFloat = 106
    static let chromeHiddenOffset: CGFloat = 128
}
