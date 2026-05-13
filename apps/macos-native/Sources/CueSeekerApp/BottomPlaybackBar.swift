import SwiftUI

enum BottomPlaybackBarLayout {
    static let reservedHeight: CGFloat = 112
    static let surfaceHeight: CGFloat = 92
    static let surfaceCornerRadius: CGFloat = 15
}

struct BottomPlaybackBar: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if let viewModel = appState.playbackViewModel {
            BottomPlaybackBarContent(
                appState: appState,
                layoutState: appState.workbenchLayout,
                viewModel: viewModel
            )
        } else {
            EmptyBottomPlaybackBar()
        }
    }
}

private struct BottomPlaybackMenuAnchorKey: PreferenceKey {
    static let defaultValue: [BottomPlaybackMenuKind: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [BottomPlaybackMenuKind: Anchor<CGRect>],
        nextValue: () -> [BottomPlaybackMenuKind: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct BottomPlaybackBarContent: View {
    @ObservedObject var appState: AppState
    @ObservedObject var layoutState: WorkbenchLayoutState
    @ObservedObject var viewModel: PlaybackViewModel

    @State private var isVolumeHovered = false

    private var hasPlayback: Bool {
        appState.hasPlaybackSelection
    }

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)

            VStack(spacing: 7) {
                HStack(spacing: 20) {
                    leadingCluster
                        .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

                    transportControls
                        .frame(width: 400)

                    trailingControls
                        .frame(minWidth: 240, maxWidth: .infinity, alignment: .trailing)
                }

                progressRow
                    .frame(maxWidth: 620)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(height: BottomPlaybackBarLayout.surfaceHeight)
            .background(
                RoundedRectangle(cornerRadius: BottomPlaybackBarLayout.surfaceCornerRadius)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: BottomPlaybackBarLayout.surfaceCornerRadius)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, y: 5)
            .padding(.horizontal, 16)
            .zIndex(10)
        }
        .overlayPreferenceValue(BottomPlaybackMenuAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let menu = appState.activeBottomPlaybackMenu,
                   let anchor = anchors[menu] {
                    menuDismissalLayer
                        .zIndex(20)

                    bottomPlaybackMenu(menu)
                        .position(
                            x: proxy[anchor].midX,
                            y: proxy[anchor].minY - menuVerticalOffset(menu)
                        )
                        .zIndex(30)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var leadingCluster: some View {
        HStack(spacing: 14) {
            Button {
                appState.clearSearchFocus()
                appState.togglePlaybackSurfaceFromUser()
            } label: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 9) {
                        Image(systemName: appState.isPlaybackSurfaceExpanded ? "chevron.up" : "chevron.right")
                            .font(.system(size: 15, weight: .bold))

                        Text(appState.currentPlaybackDisplayTitle)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(minWidth: 88, maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 130, maxWidth: 220, alignment: .leading)

                    Image(systemName: appState.isPlaybackSurfaceExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(hasPlayback ? Color.primary : Color.secondary)
                .frame(minWidth: 38, maxWidth: 220, minHeight: 38)
                .padding(.horizontal, 12)
                .contentShape(Capsule())
            }
            .buttonStyle(BottomBarButtonStyle(cornerRadius: 999))
            .disabled(!hasPlayback || layoutState.isVideoSizeTransitionInProgress)
            .help(hasPlayback ? "Expand or collapse video window" : "No video selected")

            volumeControl
        }
    }

    private var volumeControl: some View {
        ZStack(alignment: .leading) {
            Button {
                appState.dismissBottomPlaybackMenu()
                viewModel.toggleMute()
            } label: {
                Image(systemName: volumeIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasPlayback ? Color.secondary : Color.secondary.opacity(0.45))
            .disabled(!hasPlayback)

            if isVolumeHovered && hasPlayback {
                HStack(spacing: 8) {
                    BottomPlayerVolumeSlider(volume: Binding(
                        get: { viewModel.volume },
                        set: { viewModel.setVolume($0, showsFeedback: false) }
                    ))
                    .frame(width: 86, height: 18)

                    Text("\(Int(viewModel.volume.rounded()))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .offset(x: 30)
                .zIndex(3)
            }
        }
        .frame(width: 30, height: 30, alignment: .leading)
        .onHover { hovering in
            isVolumeHovered = hovering
        }
    }

    private var transportControls: some View {
        HStack(spacing: 14) {
            bottomIconButton(
                systemImage: "backward.end.fill",
                help: "Previous episode video",
                isEnabled: appState.canOpenPreviousLibraryVideo
            ) {
                appState.clearSearchFocus()
                appState.openPreviousLibraryVideo()
            }

            bottomIconButton(
                systemImage: "chevron.left",
                help: "Previous search result",
                isEnabled: appState.canOpenPreviousSearchResult
            ) {
                appState.clearSearchFocus()
                appState.openAdjacentSearchResult(.previous)
            }

            Button {
                appState.dismissBottomPlaybackMenu()
                appState.clearSearchFocus()
                appState.togglePlaybackFromUser()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(BottomBarButtonStyle(cornerRadius: 999))
            .disabled(!hasPlayback || appState.playbackStatus.isOpening)
            .help(viewModel.isPlaying ? "Pause" : "Play")

            bottomIconButton(
                systemImage: "chevron.right",
                help: "Next search result",
                isEnabled: appState.canOpenNextSearchResult
            ) {
                appState.clearSearchFocus()
                appState.openAdjacentSearchResult(.next)
            }

            bottomIconButton(
                systemImage: "forward.end.fill",
                help: "Next episode video",
                isEnabled: appState.canOpenNextLibraryVideo
            ) {
                appState.clearSearchFocus()
                appState.openNextLibraryVideo()
            }

            moreMenu
        }
    }

    private var moreMenu: some View {
        Button {
            appState.toggleBottomPlaybackMenu(.more)
        } label: {
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(BottomBarButtonStyle(cornerRadius: 999))
        .disabled(!hasPlayback)
        .help("More actions")
        .frame(width: 36, height: 36)
        .anchorPreference(key: BottomPlaybackMenuAnchorKey.self, value: .bounds) { [.more: $0] }
        .zIndex(appState.activeBottomPlaybackMenu == .more ? 100 : 0)
    }

    private var trailingControls: some View {
        HStack(spacing: 14) {
            bottomIconButton(systemImage: "bookmark", help: "Save Shiori", isEnabled: hasPlayback) {
                appState.clearSearchFocus()
                appState.toggleCurrentShiori()
            }

            bottomIconButton(systemImage: "pencil.tip", help: "Copy Current Subtitle", isEnabled: hasPlayback) {
                appState.clearSearchFocus()
                appState.copyCurrentSubtitleToClipboard()
            }

            bottomIconButton(
                systemImage: viewModel.areSubtitlesVisible ? "captions.bubble.fill" : "captions.bubble",
                help: viewModel.areSubtitlesVisible ? "Hide Subtitles" : "Show Subtitles",
                isEnabled: hasPlayback
            ) {
                viewModel.toggleSubtitles()
            }

            sidePanelToggleControl

            speedControl

            bottomIconButton(
                systemImage: appState.playbackFullscreenManager.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "viewfinder",
                help: appState.playbackFullscreenManager.isFullscreen ? "Exit Fullscreen" : "Fullscreen",
                isEnabled: !appState.isPlaybackFullscreenToggleDisabled
            ) {
                appState.clearSearchFocus()
                appState.togglePlaybackFullscreenFromUser(
                    onCopySubtitle: {
                        appState.copyCurrentSubtitleToClipboard()
                    },
                    onSaveShiori: {
                        appState.toggleCurrentShiori()
                    }
                )
            }
        }
    }

    private var sidePanelToggleControl: some View {
        Button {
            appState.clearSearchFocus()
            appState.togglePlaybackSidePanelFromUser()
        } label: {
            BottomPlaybackSidePanelIcon(
                isSelected: appState.isPlaybackSidePanelVisible && appState.isPlaybackSurfaceExpanded
            )
                .frame(width: 36, height: 36)
        }
        .buttonStyle(BottomBarButtonStyle(cornerRadius: 999))
        .disabled(appState.isPlaybackSidePanelToggleDisabled)
        .help(appState.isPlaybackSidePanelVisible ? "Hide Video Sidebar" : "Show Video Sidebar")
        .frame(width: 36, height: 36)
    }

    private var speedControl: some View {
        Button {
            appState.toggleBottomPlaybackMenu(.speed)
        } label: {
            Text(PlaybackViewModel.formatSpeed(viewModel.playbackSpeed))
                .font(.system(size: 15, weight: .bold))
                .frame(minWidth: 46, minHeight: 30)
                .padding(.horizontal, 4)
        }
        .buttonStyle(BottomBarButtonStyle(cornerRadius: 999))
        .disabled(!hasPlayback)
        .help("Playback speed")
        .frame(minWidth: 54, minHeight: 36)
        .anchorPreference(key: BottomPlaybackMenuAnchorKey.self, value: .bounds) { [.speed: $0] }
        .zIndex(appState.activeBottomPlaybackMenu == .speed ? 100 : 0)
    }

    private var progressRow: some View {
        HStack(spacing: 10) {
            Text(formatTime(viewModel.displayedCurrentTime))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)

            BottomPlayerProgressBar(
                currentTime: viewModel.displayedCurrentTime,
                duration: viewModel.duration,
                isEnabled: hasPlayback,
                onSeek: { time in
                    viewModel.seek(to: time)
                }
            )

            Text(formatTime(viewModel.duration))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
        }
    }

    private var volumeIcon: String {
        if viewModel.volume == 0 {
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

    private var menuDismissalLayer: some View {
        Color.black.opacity(0.001)
            .contentShape(Rectangle())
            .onTapGesture {
                appState.dismissBottomPlaybackMenu()
            }
    }

    @ViewBuilder
    private func bottomPlaybackMenu(_ menu: BottomPlaybackMenuKind) -> some View {
        switch menu {
        case .more:
            VStack(alignment: .leading, spacing: 2) {
                menuItem("Video Folder") {
                    appState.clearSearchFocus()
                    appState.revealCurrentVideoFile()
                }
                menuItem("Subtitle Folder", isEnabled: appState.currentPlaybackSubtitlePath != nil) {
                    appState.clearSearchFocus()
                    appState.revealCurrentSubtitleFile()
                }
                menuItem("Results") {
                    appState.clearSearchFocus()
                    appState.requestPlaybackDrawer(.results)
                }
                menuItem("Subtitles", isEnabled: appState.currentPlaybackSubtitlePath != nil) {
                    appState.clearSearchFocus()
                    appState.requestPlaybackDrawer(.subtitles)
                }
            }
            .padding(6)
            .frame(width: 148, alignment: .leading)
            .background(menuBackground)
            .fixedSize(horizontal: true, vertical: true)

        case .speed:
            VStack(spacing: 2) {
                ForEach(PlaybackViewModel.speedPresets, id: \.self) { speed in
                    Button {
                        viewModel.setSpeed(speed)
                        appState.dismissBottomPlaybackMenu()
                    } label: {
                        HStack(spacing: 12) {
                            Text(PlaybackViewModel.formatSpeed(speed))
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 48, alignment: .leading)

                            Spacer(minLength: 0)

                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .opacity(abs(viewModel.playbackSpeed - speed) < 0.01 ? 1 : 0)
                        }
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 12)
                        .frame(width: 122, height: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 7)
            .background(menuBackground)
            .fixedSize(horizontal: true, vertical: true)
        }
    }

    private func menuVerticalOffset(_ menu: BottomPlaybackMenuKind) -> CGFloat {
        switch menu {
        case .more:
            return 76
        case .speed:
            return 132
        }
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
    }

    private func bottomIconButton(
        systemImage: String,
        help: String,
        isEnabled: Bool,
        dismissesMenus: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            if dismissesMenus {
                appState.dismissBottomPlaybackMenu()
            }
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(BottomBarButtonStyle(cornerRadius: 999))
        .disabled(!isEnabled)
        .help(help)
    }

    private func menuItem(
        _ title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            appState.dismissBottomPlaybackMenu()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else {
            return "00:00"
        }

        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct EmptyBottomPlaybackBar: View {
    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)

            RoundedRectangle(cornerRadius: BottomPlaybackBarLayout.surfaceCornerRadius)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))

                        Text("No video selected")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BottomPlaybackBarLayout.surfaceCornerRadius)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .frame(height: BottomPlaybackBarLayout.surfaceHeight)
                .padding(.horizontal, 16)
        }
    }
}

private struct BottomPlayerProgressBar: View {
    let currentTime: Double
    let duration: Double
    let isEnabled: Bool
    let onSeek: (Double) -> Void

    @State private var isHovering = false
    @State private var dragTime: Double?

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(1, geometry.size.width)
            let safeDuration = max(duration, 1)
            let displayedTime = dragTime ?? currentTime
            let progress = max(0, min(1, displayedTime / safeDuration))
            let progressWidth = totalWidth * progress
            let barHeight: CGFloat = isHovering || dragTime != nil ? 8 : 6

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.16))
                    .frame(height: barHeight)

                Capsule()
                    .fill(Color.primary.opacity(isEnabled ? 0.68 : 0.25))
                    .frame(width: progressWidth, height: barHeight)

                Circle()
                    .fill(Color.primary.opacity(0.78))
                    .frame(width: 12, height: 12)
                    .opacity(isEnabled && (isHovering || dragTime != nil) ? 1 : 0)
                    .offset(x: progressWidth - 6)
            }
            .frame(height: 18, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else {
                            return
                        }

                        let percent = max(0, min(1, value.location.x / totalWidth))
                        dragTime = percent * safeDuration
                    }
                    .onEnded { value in
                        guard isEnabled else {
                            dragTime = nil
                            return
                        }

                        let percent = max(0, min(1, value.location.x / totalWidth))
                        dragTime = nil
                        onSeek(percent * safeDuration)
                    }
            )
        }
        .frame(height: 18)
    }
}

private struct BottomPlayerVolumeSlider: View {
    @Binding var volume: Double

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(1, geometry.size.width)
            let percent = max(0, min(1, volume / 100))
            let activeWidth = totalWidth * percent

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.16))
                    .frame(height: 5)

                Capsule()
                    .fill(Color.primary.opacity(0.64))
                    .frame(width: activeWidth, height: 5)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nextPercent = max(0, min(1, value.location.x / totalWidth))
                        volume = nextPercent * 100
                    }
            )
        }
    }
}

private struct BottomBarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor(configuration: configuration))
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        guard isEnabled else {
            return Color.white.opacity(0.52)
        }

        if configuration.isPressed {
            return Color.white.opacity(0.78)
        }

        return Color.white
    }
}

private struct BottomPlaybackSidePanelIcon: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    dot
                        .frame(width: 4, height: 4)

                    line
                        .frame(width: 13, height: 4)
                }
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var dot: some View {
        if isSelected {
            Circle()
        } else {
            Circle()
                .strokeBorder(lineWidth: 1.5)
        }
    }

    @ViewBuilder
    private var line: some View {
        if isSelected {
            Capsule()
                .frame(height: 2.5)
        } else {
            Capsule()
                .strokeBorder(lineWidth: 1.5)
        }
    }
}
