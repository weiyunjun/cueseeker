import AppKit
import SwiftUI

@MainActor
struct PlaybackChromeControls {
    let canGoPrevious: Bool
    let goPrevious: () -> Void
    let togglePlayPause: () -> Void
    let canGoNext: Bool
    let goNext: () -> Void
    let toggleShiori: () -> Void
    let copySubtitle: () -> Void
    let isFullscreen: Bool
    let isFullscreenToggleDisabled: Bool
    let toggleFullscreen: () -> Void
}

@MainActor
extension PlaybackChromeControls {
    static func appState(
        _ appState: AppCoordinator,
        snapshot: PlaybackChromeSnapshot,
        isFullscreen: Bool,
        isFullscreenToggleDisabled: Bool,
        fullscreenAction: (() -> Void)? = nil
    ) -> PlaybackChromeControls {
        PlaybackChromeControls(
            canGoPrevious: snapshot.canGoPrevious,
            goPrevious: { appState.goPrevious() },
            togglePlayPause: appState.togglePlaybackFromUser,
            canGoNext: snapshot.canGoNext,
            goNext: { appState.goNext() },
            toggleShiori: {
                _ = appState.toggleCurrentShiori()
            },
            copySubtitle: {
                _ = appState.copyCurrentSubtitleToClipboard()
            },
            isFullscreen: isFullscreen,
            isFullscreenToggleDisabled: isFullscreenToggleDisabled,
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
    @EnvironmentObject private var playback: PlaybackStore
    @State private var isSpeedMenuVisible = false
    @State private var speedMenuEventMonitor: Any?
    @State private var speedButtonFrame: CGRect = .zero
    @State private var isTimeHovered = false

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
        .onChange(of: playback.isTimelineScrubbing) { isScrubbing in
            if isScrubbing {
                isSpeedMenuVisible = false
                isTimeHovered = false
            }
        }
        .onDisappear {
            removeSpeedMenuDismissMonitor()
        }
    }

    private var chromeSurface: some View {
        VStack(spacing: 0) {
            scrubberRow
                .padding(.top, PlaybackChromeMetrics.progressTopPadding)

            HStack(spacing: 0) {
                leftGroup

                Spacer(minLength: 0)

                rightGroup
            }
            .padding(.horizontal, PlaybackChromeMetrics.chromeHorizontalPadding)
            .frame(height: PlaybackChromeMetrics.bottomControlsRowHeight)
            .padding(.bottom, PlaybackChromeMetrics.chromeBottomPadding)
        }
        .contentShape(Rectangle())
    }

    @MainActor
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
                let calculatedY = buttonFrame.minY - PlaybackChromeMetrics.speedMenuGap - menuHeight / 2
                let maxMenuCenterY = proxy.size.width > 0
                    ? proxy.size.height - PlaybackChromeMetrics.height + PlaybackChromeMetrics.speedMenuOverlapClearance - menuHeight / 2
                    : calculatedY
                let y = max(
                    menuHeight / 2,
                    min(calculatedY, maxMenuCenterY)
                )

                PlaybackChromeSpeedMenu(
                    selectedSpeed: viewModel.playbackSpeed,
                    suppressesInteraction: playback.isTimelineScrubbing,
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
        PlaybackProgressScrubber(
            viewModel: viewModel,
            scrubTime: Binding(
                get: { playback.timelineScrubTime },
                set: { playback.timelineScrubTime = $0 }
            ),
            onScrubbingChanged: { playback.isTimelineScrubbing = $0 }
        )
            .padding(.horizontal, PlaybackChromeMetrics.chromeHorizontalPadding)
    }

    private var leftGroup: some View {
        HStack(spacing: PlaybackChromeMetrics.leftControlsGap) {
            PlaybackChromeIconButton(
                systemName: viewModel.isPlaying ? "pause.fill" : "play.fill",
                kind: .transport,
                suppressesInteraction: playback.isTimelineScrubbing,
                accessibilityLabel: viewModel.isPlaying ? "Pause" : "Play",
                action: controls.togglePlayPause
            )

            HStack(spacing: 0) {
                PlaybackChromeIconButton(
                    systemName: "backward.end.fill",
                    kind: .transport,
                    isDisabled: !controls.canGoPrevious,
                    suppressesInteraction: playback.isTimelineScrubbing,
                    hasPersistentBase: false,
                    accessibilityLabel: "Previous video",
                    action: controls.goPrevious
                )

                PlaybackChromeIconButton(
                    systemName: "forward.end.fill",
                    kind: .transport,
                    isDisabled: !controls.canGoNext,
                    suppressesInteraction: playback.isTimelineScrubbing,
                    hasPersistentBase: false,
                    accessibilityLabel: "Next video",
                    action: controls.goNext
                )
            }
            .frame(height: PlaybackChromeMetrics.capsuleButtonHeight)
            .background(Capsule().fill(PlaybackTheme.controlBackground))

            PlaybackVolumeControl(
                viewModel: viewModel,
                suppressesInteraction: playback.isTimelineScrubbing
            )

            HStack(spacing: PlaybackChromeMetrics.timeLabelGap) {
                Text(formatPlaybackTime(playback.timelineScrubTime ?? viewModel.displayedCurrentTime))
                    .foregroundStyle(PlaybackTheme.textPrimary)
                Text("/")
                    .foregroundStyle(PlaybackTheme.textTertiary)
                Text(formatPlaybackTime(viewModel.duration))
                    .foregroundStyle(PlaybackTheme.textPrimary)
            }
            .font(.system(size: PlaybackChromeMetrics.timeFontSize, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .padding(.horizontal, PlaybackChromeMetrics.capsuleButtonHorizontalPadding)
            .frame(height: PlaybackChromeMetrics.capsuleButtonHeight)
            .background(
                PlaybackCinematicBacking(
                    shape: Capsule(),
                    isHovered: isTimeHovered,
                    scaleX: 0.92,
                    scaleY: 0.85
                )
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isTimeHovered = playback.isTimelineScrubbing ? false : hovering
                }
            }
        }
    }

    private var rightGroup: some View {
        HStack(spacing: PlaybackChromeMetrics.rightControlsGap) {
            HStack(spacing: 0) {
                PlaybackChromeIconButton(
                    systemName: "bookmark",
                    kind: .transport,
                    suppressesInteraction: playback.isTimelineScrubbing,
                    hasPersistentBase: false,
                    accessibilityLabel: "Shiori",
                    action: controls.toggleShiori
                )

                PlaybackChromeIconButton(
                    icon: .copy,
                    kind: .transport,
                    suppressesInteraction: playback.isTimelineScrubbing,
                    hasPersistentBase: false,
                    accessibilityLabel: "Copy current subtitle",
                    action: controls.copySubtitle
                )

                PlaybackChromeIconButton(
                    systemName: viewModel.areSubtitlesVisible ? "captions.bubble.fill" : "captions.bubble",
                    kind: .transport,
                    isSelected: false,
                    suppressesInteraction: playback.isTimelineScrubbing,
                    hasPersistentBase: false,
                    accessibilityLabel: "Subtitles",
                    action: viewModel.toggleSubtitles
                )
            }
            .frame(height: PlaybackChromeMetrics.capsuleButtonHeight)
            .background(Capsule().fill(PlaybackTheme.controlBackground))

            speedControl

            PlaybackChromeIconButton(
                systemName: controls.isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "viewfinder",
                kind: .transport,
                isDisabled: controls.isFullscreenToggleDisabled,
                suppressesInteraction: playback.isTimelineScrubbing,
                accessibilityLabel: "Fullscreen",
                action: controls.toggleFullscreen
            )
        }
    }

    private var speedControl: some View {
        Button {
            guard !playback.isTimelineScrubbing else {
                return
            }
            isSpeedMenuVisible.toggle()
        } label: {
            Text(PlaybackViewModel.formatSpeed(viewModel.playbackSpeed))
                .font(.system(size: PlaybackChromeMetrics.timeFontSize, weight: .semibold))
                .monospacedDigit()
                .frame(width: PlaybackChromeMetrics.speedButtonWidth, height: PlaybackChromeMetrics.capsuleButtonHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(
            PlaybackChromeCapsuleButtonStyle(
                suppressesInteraction: playback.isTimelineScrubbing
            )
        )
        .accessibilityLabel("Playback speed")
        .frame(
            width: PlaybackChromeMetrics.speedButtonWidth,
            height: PlaybackChromeMetrics.capsuleButtonHeight,
            alignment: .center
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        speedButtonFrame = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { newFrame in
                        speedButtonFrame = newFrame
                    }
            }
        )
        .anchorPreference(key: PlaybackSpeedButtonAnchorKey.self, value: .bounds) { $0 }
    }

    private func installSpeedMenuDismissMonitor() {
        removeSpeedMenuDismissMonitor()
        speedMenuEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            if isSpeedMenuVisible {
                if let window = event.window {
                    let windowHeight = window.contentView?.bounds.height ?? 0
                    let clickPoint = CGPoint(
                        x: event.locationInWindow.x,
                        y: windowHeight - event.locationInWindow.y
                    )
                    if speedButtonFrame.contains(clickPoint) {
                        // Let the button action handle toggling isSpeedMenuVisible to false
                        return event
                    }
                }
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
    var suppressesInteraction = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                PlaybackCinematicBacking(
                    shape: Capsule(),
                    isHovered: isInteractive && isHovered,
                    isPressed: isInteractive && configuration.isPressed,
                    scaleX: 0.88,
                    scaleY: 0.85
                )
            )
            .scaleEffect(configuration.isPressed && isInteractive ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = suppressesInteraction ? false : $0 }
            .onChange(of: suppressesInteraction) { isSuppressed in
                if isSuppressed {
                    isHovered = false
                }
            }
    }

    private var foregroundColor: Color {
        isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary
    }

    private var isInteractive: Bool {
        isEnabled && !suppressesInteraction
    }
}
