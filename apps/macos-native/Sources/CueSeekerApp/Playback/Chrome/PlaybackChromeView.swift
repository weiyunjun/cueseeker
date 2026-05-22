import AppKit
import SwiftUI

@MainActor
struct PlaybackChromeControls {
    let canOpenPreviousEpisode: Bool
    let openPreviousEpisode: () -> Void
    let canOpenPreviousResult: Bool
    let openPreviousResult: () -> Void
    let togglePlayPause: () -> Void
    let canOpenNextResult: Bool
    let openNextResult: () -> Void
    let canOpenNextEpisode: Bool
    let openNextEpisode: () -> Void
    let toggleShiori: () -> Void
    let copySubtitle: () -> Void
    let isSidePanelVisible: Bool
    let canToggleSidePanel: Bool
    let toggleSidePanel: () -> Void
    let isFullscreen: Bool
    let isFullscreenToggleDisabled: Bool
    let toggleFullscreen: () -> Void
}

@MainActor
extension PlaybackChromeControls {
    static func appState(
        _ appState: AppCoordinator,
        fullscreenAction: (() -> Void)? = nil
    ) -> PlaybackChromeControls {
        PlaybackChromeControls(
            canOpenPreviousEpisode: appState.canOpenPreviousLibraryVideo,
            openPreviousEpisode: appState.openPreviousLibraryVideo,
            canOpenPreviousResult: appState.canOpenPreviousSearchResult,
            openPreviousResult: {
                appState.openAdjacentSearchResult(.previous)
            },
            togglePlayPause: appState.togglePlaybackFromUser,
            canOpenNextResult: appState.canOpenNextSearchResult,
            openNextResult: {
                appState.openAdjacentSearchResult(.next)
            },
            canOpenNextEpisode: appState.canOpenNextLibraryVideo,
            openNextEpisode: appState.openNextLibraryVideo,
            toggleShiori: {
                _ = appState.toggleCurrentShiori()
            },
            copySubtitle: {
                _ = appState.copyCurrentSubtitleToClipboard()
            },
            isSidePanelVisible: appState.playback.isPlaybackSidePanelVisible,
            canToggleSidePanel: appState.hasPlaybackSelection,
            toggleSidePanel: appState.togglePlaybackSidePanelFromUser,
            isFullscreen: appState.playbackFullscreenManager.isFullscreen,
            isFullscreenToggleDisabled: appState.isPlaybackFullscreenToggleDisabled,
            toggleFullscreen: fullscreenAction ?? {
                appState.togglePlaybackFullscreenFromUser()
            }
        )
    }
}

private struct PlaybackSpeedButtonAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

@MainActor
struct PlaybackChromeView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    let controls: PlaybackChromeControls
    @State private var isSpeedMenuVisible = false
    @State private var speedMenuEventMonitor: Any?

    private var canGoPrevious: Bool {
        controls.canOpenPreviousResult || controls.canOpenPreviousEpisode
    }

    private func goPrevious() {
        if controls.canOpenPreviousResult {
            controls.openPreviousResult()
        } else if controls.canOpenPreviousEpisode {
            controls.openPreviousEpisode()
        }
    }

    private var canGoNext: Bool {
        controls.canOpenNextResult || controls.canOpenNextEpisode
    }

    private func goNext() {
        if controls.canOpenNextResult {
            controls.openNextResult()
        } else if controls.canOpenNextEpisode {
            controls.openNextEpisode()
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .allowsHitTesting(false)

            chromeSurface
                .zIndex(1)
        }
        .frame(height: PlaybackChromeMetrics.interactiveHeight, alignment: .bottom)
        .overlayPreferenceValue(PlaybackSpeedButtonAnchorKey.self) { anchor in
            speedMenuOverlay(anchor: anchor)
        }
        .onChange(of: isSpeedMenuVisible) { isVisible in
            if isVisible {
                installSpeedMenuDismissMonitor()
            } else {
                removeSpeedMenuDismissMonitor()
            }
        }
        .onDisappear {
            removeSpeedMenuDismissMonitor()
        }
    }

    private var chromeSurface: some View {
        VStack(spacing: 0) {
            scrubberRow
                .padding(.top, 16)

            HStack(spacing: 0) {
                leftGroup

                Spacer(minLength: 0)

                rightGroup
            }
            .padding(.horizontal, 24)
            .frame(height: 52)
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.88),
                    Color.black.opacity(0.78),
                    Color.black.opacity(0.48),
                    Color.black.opacity(0.12),
                    Color.clear
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func speedMenuOverlay(anchor: Anchor<CGRect>?) -> some View {
        if isSpeedMenuVisible, let anchor {
            GeometryReader { proxy in
                let buttonFrame = proxy[anchor]
                let menuWidth = PlaybackChromeMetrics.speedMenuWidth
                let menuHeight = PlaybackChromeMetrics.speedMenuHeight
                let x = min(
                    max(buttonFrame.maxX - menuWidth / 2, menuWidth / 2),
                    proxy.size.width - menuWidth / 2
                )
                let y = max(
                    menuHeight / 2,
                    buttonFrame.minY - PlaybackChromeMetrics.speedMenuGap - menuHeight / 2
                )

                PlaybackChromeSpeedMenu(
                    selectedSpeed: viewModel.playbackSpeed,
                    onSelect: { speed in
                        viewModel.setSpeed(speed)
                        isSpeedMenuVisible = false
                    }
                )
                .frame(width: menuWidth, height: menuHeight)
                .position(x: x, y: y)
                .zIndex(2)
            }
        }
    }

    private var scrubberRow: some View {
        PlaybackProgressScrubber(viewModel: viewModel)
            .padding(.horizontal, 24)
    }

    private var leftGroup: some View {
        HStack(spacing: 8) {
            PlaybackChromeIconButton(
                systemName: viewModel.isPlaying ? "pause.fill" : "play.fill",
                kind: .primaryTransport,
                accessibilityLabel: viewModel.isPlaying ? "Pause" : "Play",
                action: controls.togglePlayPause
            )

            PlaybackChromeIconButton(
                systemName: "backward.end.fill",
                kind: .transport,
                isDisabled: !canGoPrevious,
                accessibilityLabel: "Previous video",
                action: goPrevious
            )

            PlaybackChromeIconButton(
                systemName: "forward.end.fill",
                kind: .transport,
                isDisabled: !canGoNext,
                accessibilityLabel: "Next video",
                action: goNext
            )

            PlaybackVolumeControl(viewModel: viewModel)
                .padding(.leading, 4)

            HStack(spacing: 4) {
                Text(formatPlaybackTime(viewModel.displayedCurrentTime))
                    .foregroundStyle(PlaybackTheme.textPrimary)
                Text("/")
                    .foregroundStyle(PlaybackTheme.textTertiary)
                Text(formatPlaybackTime(viewModel.duration))
                    .foregroundStyle(PlaybackTheme.textSecondary)
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .padding(.leading, 8)
        }
    }

    private var rightGroup: some View {
        HStack(spacing: 6) {
            PlaybackChromeIconButton(
                systemName: "bookmark",
                accessibilityLabel: "Shiori",
                action: controls.toggleShiori
            )

            PlaybackChromeIconButton(
                icon: .copy,
                accessibilityLabel: "Copy current subtitle",
                action: controls.copySubtitle
            )

            PlaybackChromeIconButton(
                systemName: viewModel.areSubtitlesVisible ? "captions.bubble.fill" : "captions.bubble",
                isSelected: viewModel.areSubtitlesVisible,
                accessibilityLabel: "Subtitles",
                action: viewModel.toggleSubtitles
            )

            PlaybackChromeIconButton(
                systemName: "list.bullet",
                isSelected: controls.isSidePanelVisible,
                isDisabled: !controls.canToggleSidePanel,
                accessibilityLabel: "Results panel",
                action: controls.toggleSidePanel
            )

            speedControl

            PlaybackChromeIconButton(
                systemName: controls.isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "viewfinder",
                isDisabled: controls.isFullscreenToggleDisabled,
                accessibilityLabel: "Fullscreen",
                action: controls.toggleFullscreen
            )
        }
    }

    private var speedControl: some View {
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
        .frame(width: 54, height: 32, alignment: .center)
        .anchorPreference(key: PlaybackSpeedButtonAnchorKey.self, value: .bounds) { $0 }
    }

    private func installSpeedMenuDismissMonitor() {
        removeSpeedMenuDismissMonitor()
        speedMenuEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            if isSpeedMenuVisible {
                DispatchQueue.main.async {
                    isSpeedMenuVisible = false
                }
            }
            return event
        }
    }

    private func removeSpeedMenuDismissMonitor() {
        if let speedMenuEventMonitor {
            NSEvent.removeMonitor(speedMenuEventMonitor)
            self.speedMenuEventMonitor = nil
        }
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed || isActive || isHovered {
            return Color.white.opacity(0.20)
        }
        return Color.white.opacity(0.12)
    }
}

enum PlaybackChromeMetrics {
    static let horizontalInset: CGFloat = 0
    static let bottomInset: CGFloat = 0
    static let height: CGFloat = 98
    static let timeLabelWidth: CGFloat = 70
    static let videoTopBarHeight: CGFloat = 46
    static let speedMenuWidth: CGFloat = 172
    static let speedMenuHeight: CGFloat = 234
    static let speedMenuGap: CGFloat = 8
    static let interactiveHeight: CGFloat = height + speedMenuHeight + speedMenuGap + 24
    static let hiddenOffset: CGFloat = interactiveHeight + 28
}
