import AppKit
import SwiftUI

@MainActor
struct PlaybackChromeControls {
    var isVideoPlaylist: Bool = false
    let canGoPrevious: Bool
    let goPrevious: () -> Void
    let togglePlayPause: () -> Void
    let canGoNext: Bool
    let goNext: () -> Void
    var openPlaybackOverlay: () -> Void = {}
    let repeatCurrentCue: () -> Void
    let isFullscreen: Bool
    let isFullscreenToggleDisabled: Bool
    let toggleFullscreen: () -> Void
    let toggleSubtitleMenu: () -> Void
    let toggleMoreMenu: () -> Void
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
            isVideoPlaylist: appState.isLibraryPlaybackActive,
            canGoPrevious: snapshot.canGoPrevious,
            goPrevious: { appState.goPrevious() },
            togglePlayPause: appState.togglePlaybackFromUser,
            canGoNext: snapshot.canGoNext,
            goNext: { appState.goNext() },
            openPlaybackOverlay: { _ = appState.openPlaybackSubtitleFocusFromUser() },
            repeatCurrentCue: { _ = appState.repeatCurrentPlaylistCue() },
            isFullscreen: isFullscreen,
            isFullscreenToggleDisabled: isFullscreenToggleDisabled,
            toggleFullscreen: fullscreenAction ?? {
                appState.togglePlaybackFullscreenFromUser()
            },
            toggleSubtitleMenu: { appState.togglePlaybackSubtitleMenu() },
            toggleMoreMenu: { appState.togglePlaybackMoreMenu() }
        )
    }
}

/// The Subtitle button's bounds, read by the stage, which lays the Subtitle
/// menu over the whole video rather than inside the bottom chrome.
struct PlaybackSubtitleButtonAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// The More button's bounds, read by the stage, which lays the More menu over
/// the whole video rather than inside the bottom chrome.
struct PlaybackMoreButtonAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// The Speed button's bounds, read by the stage, which lays the Speed menu
/// over the whole video rather than inside the bottom chrome.
struct PlaybackSpeedButtonAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct PlaybackChromeBottomGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                PlaybackTheme.topbarGradientEnd,
                PlaybackTheme.topbarGradientStart,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}

@MainActor
struct PlaybackChromeView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    let controls: PlaybackChromeControls
    var showsBackgroundGradient: Bool = true

    var body: some View {
        chromeSurface
            .frame(height: PlaybackChromeMetrics.height, alignment: .bottom)
            .onDisappear {
                playback.closeSpeedMenu()
                playback.closeSubtitleMenu()
            }
    }

    /// Toggling the menu goes through the store, which also seeds the highlight
    /// with the speed already in effect.
    private var isSpeedMenuVisibleBinding: Binding<Bool> {
        Binding(
            get: { playback.isSpeedMenuOpen },
            set: { isVisible in
                if isVisible {
                    playback.openSpeedMenu(
                        defaultPosition: PlaybackViewModel.speedPresetIndex(
                            for: viewModel.playbackSpeed
                        )
                    )
                } else {
                    playback.closeSpeedMenu()
                }
            }
        )
    }

    private var chromeSurface: some View {
        WorkbenchAccessibilityReader { accessibility in
            VStack(spacing: 0) {
                scrubberRow

                HStack(spacing: 0) {
                    leftGroup(accessibility: accessibility)

                    Spacer(minLength: 0)

                    rightGroup(accessibility: accessibility)
                }
                .padding(.horizontal, PlaybackChromeMetrics.chromeHorizontalPadding)
                .frame(height: PlaybackChromeMetrics.bottomControlsRowHeight)
                .padding(.bottom, PlaybackChromeMetrics.chromeBottomPadding)
            }
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {}
            )
            .padding(.top, PlaybackChromeMetrics.progressTopPadding)
            .background(
                Group {
                    if showsBackgroundGradient {
                        PlaybackChromeBottomGradient()
                    }
                }
            )
        }
    }

    private var scrubberRow: some View {
        GeometryReader { rowGeometry in
            PlaybackProgressScrubberRow(
                viewModel: viewModel,
                timeline: timeline,
                windowWidth: rowGeometry.size.width
            )
            .padding(.horizontal, PlaybackChromeMetrics.progressRowHorizontalPadding)
            .coordinateSpace(name: PlaybackProgressScrubber.windowCoordinateSpaceName)
        }
        .frame(height: PlaybackChromeMetrics.progressHitAreaHeight)
    }

    private var previousTooltipLabel: String {
        if controls.isVideoPlaylist {
            return controls.canGoPrevious
                ? L("tooltip.player.previous.video")
                : L("tooltip.player.previous.video.disabled")
        }
        return controls.canGoPrevious
            ? L("tooltip.player.previous.cue")
            : L("tooltip.player.previous.cue.disabled")
    }

    private var nextTooltipLabel: String {
        if controls.isVideoPlaylist {
            return controls.canGoNext
                ? L("tooltip.player.next.video")
                : L("tooltip.player.next.video.disabled")
        }
        return controls.canGoNext
            ? L("tooltip.player.next.cue")
            : L("tooltip.player.next.cue.disabled")
    }

    private func leftGroup(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        HStack(spacing: PlaybackChromeMetrics.controlsGap) {
            PlaybackPlayPauseChromeButton(
                viewModel: viewModel,
                isFocused: accessibility?.isPlaybackFocused(.playerPlayPause) == true,
                action: controls.togglePlayPause
            )
            .workbenchTooltip(
                scenarioID: "player.control.play_pause",
                label: viewModel.isPlaying ? L("playback.pause") : L("playback.play"),
                shortcut: .action(.playPause)
            )

            PlaybackChromeIconButton(
                icon: .skipBack,
                iconWeight: .fill,
                isDisabled: !controls.canGoPrevious,
                isFocused: accessibility?.isPlaybackFocused(.playerPrevious) == true,
                accessibilityLabel: L("playback.previous_video"),
                action: controls.goPrevious
            )
            .workbenchTooltip(
                scenarioID: "player.control.previous",
                label: previousTooltipLabel,
                shortcut: controls.canGoPrevious ? .action(.previous) : .none
            )

            PlaybackChromeIconButton(
                icon: .skipForward,
                iconWeight: .fill,
                isDisabled: !controls.canGoNext,
                isFocused: accessibility?.isPlaybackFocused(.playerNext) == true,
                accessibilityLabel: L("playback.next_video"),
                action: controls.goNext
            )
            .workbenchTooltip(
                scenarioID: "player.control.next",
                label: nextTooltipLabel,
                shortcut: controls.canGoNext ? .action(.next) : .none
            )

            PlaybackVolumeControl(
                viewModel: viewModel,
                timeline: timeline,
                isFocused: accessibility?.isPlaybackFocused(.playerMute) == true
            )
        }
    }

    private func rightGroup(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        HStack(spacing: PlaybackChromeMetrics.controlsGap) {
            PlaybackChromeIconButton(
                icon: .list,
                isFocused: accessibility?.isPlaybackFocused(.playerPlaybackOverlay) == true,
                accessibilityLabel: L("settings.shortcuts.action.openPlaybackOverlay"),
                action: controls.openPlaybackOverlay
            )
            .workbenchTooltip(
                scenarioID: "player.control.playback_overlay",
                label: L("settings.shortcuts.action.openPlaybackOverlay"),
                shortcut: .action(.openPlaybackOverlay)
            )

            PlaybackChromeIconButton(
                icon: .repeatIcon,
                isFocused: accessibility?.isPlaybackFocused(.playerRepeat) == true,
                accessibilityLabel: L("playback.repeat"),
                action: controls.repeatCurrentCue
            )
            .workbenchTooltip(
                scenarioID: "player.control.repeat",
                label: L("playback.repeat"),
                shortcut: .action(.repeatCue)
            )

            PlaybackChromeIconButton(
                icon: .camera,
                isFocused: accessibility?.isPlaybackFocused(.playerCopyScreenshot) == true,
                accessibilityLabel: L("playback.copy_screenshot"),
                action: viewModel.copyCurrentFrameScreenshot
            )
            .workbenchTooltip(
                scenarioID: "player.control.copy_screenshot",
                label: L("tooltip.player.copy_screenshot"),
                shortcut: .action(.copyScreenshot)
            )

            PlaybackChromeIconButton(
                icon: .subtitles,
                isOpen: playback.subtitleMenu != nil,
                isFocused: accessibility?.isPlaybackFocused(.playerSubtitlesMenu) == true,
                accessibilityLabel: L("playback.subtitles"),
                action: controls.toggleSubtitleMenu
            )
            .anchorPreference(key: PlaybackSubtitleButtonAnchorKey.self, value: .bounds) { $0 }

            speedControl(isFocused: accessibility?.isPlaybackFocused(.playerSpeedMenu) == true)

            PlaybackChromeIconButton(
                icon: .dotsThreeVertical,
                isOpen: playback.moreMenu != nil,
                isFocused: accessibility?.isPlaybackFocused(.playerMoreMenu) == true,
                accessibilityLabel: L("playback.more"),
                action: controls.toggleMoreMenu
            )
            .anchorPreference(key: PlaybackMoreButtonAnchorKey.self, value: .bounds) { $0 }

            PlaybackChromeIconButton(
                icon: controls.isFullscreen ? .cornersIn : .cornersOut,
                isDisabled: controls.isFullscreenToggleDisabled,
                isFocused: accessibility?.isPlaybackFocused(.playerFullscreen) == true,
                accessibilityLabel: L("playback.fullscreen"),
                action: controls.toggleFullscreen
            )
            .workbenchTooltip(
                scenarioID: "player.control.fullscreen",
                label: controls.isFullscreenToggleDisabled
                    ? L("tooltip.player.fullscreen.disabled")
                    : (controls.isFullscreen
                        ? L("tooltip.player.fullscreen.exit")
                        : L("tooltip.player.fullscreen.enter")),
                shortcut: controls.isFullscreenToggleDisabled ? .none : .action(.toggleFullscreen)
            )
        }
    }

    private func speedControl(isFocused: Bool) -> some View {
        PlaybackSpeedChromeButton(
            viewModel: viewModel,
            isSpeedMenuVisible: isSpeedMenuVisibleBinding,
            isFocused: isFocused
        )
        .workbenchTooltip(
            scenarioID: "player.control.speed",
            isActive: !playback.isSpeedMenuOpen,
            label: L("tooltip.player.speed")
        )
        .anchorPreference(key: PlaybackSpeedButtonAnchorKey.self, value: .bounds) { $0 }
    }
}

private struct PlaybackPlayPauseChromeButton: View {
    @ObservedObject var viewModel: PlaybackViewModel
    var isFocused: Bool = false
    let action: () -> Void

    var body: some View {
        PlaybackChromeIconButton(
            icon: viewModel.isPlaying ? .pause : .play,
            iconWeight: .fill,
            isFocused: isFocused,
            accessibilityLabel: viewModel.isPlaying ? L("playback.pause") : L("playback.play"),
            action: action
        )
    }
}

private struct PlaybackProgressScrubberRow: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @ObservedObject private var scrubTimeStore: PlaybackTimelineScrubTimeStore
    let windowWidth: CGFloat?

    init(
        viewModel: PlaybackViewModel,
        timeline: PlaybackTimelineInteractionStore,
        windowWidth: CGFloat? = nil
    ) {
        self.viewModel = viewModel
        self.timeline = timeline
        self.windowWidth = windowWidth
        _scrubTimeStore = ObservedObject(wrappedValue: timeline.scrubTimeStore)
    }

    var body: some View {
        HStack(spacing: PlaybackChromeMetrics.progressTimeGap) {
            Text(formatPlaybackSeconds(displayedCurrentSeconds))
                .font(.system(
                    size: PlaybackChromeMetrics.timeFontSize,
                    weight: .semibold,
                    design: .monospaced
                ))
                .monospacedDigit()
                .foregroundStyle(PlaybackTheme.textPrimary)
                .fixedSize(horizontal: true, vertical: false)

            PlaybackProgressScrubber(
                viewModel: viewModel,
                timeline: timeline,
                windowWidth: windowWidth
            )

            Text("-\(formatPlaybackSeconds(displayedRemainingSeconds))")
                .font(.system(
                    size: PlaybackChromeMetrics.timeFontSize,
                    weight: .semibold,
                    design: .monospaced
                ))
                .monospacedDigit()
                .foregroundStyle(PlaybackTheme.textPrimary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: PlaybackChromeMetrics.progressHitAreaHeight)
    }

    private var displayedCurrentSeconds: Int {
        let raw = scrubTimeStore.scrubTime ?? viewModel.displayedCurrentTime
        let safeSeconds = raw.isFinite ? max(0, raw) : 0
        return Int(safeSeconds.rounded(.down))
    }

    private var displayedRemainingSeconds: Int {
        let safeDuration = viewModel.duration.isFinite ? max(0, viewModel.duration) : 0
        let totalSeconds = Int(safeDuration.rounded(.down))
        return max(0, totalSeconds - displayedCurrentSeconds)
    }
}

private struct PlaybackSpeedChromeButton: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @Binding var isSpeedMenuVisible: Bool
    var isFocused: Bool = false

    var body: some View {
        Button {
            isSpeedMenuVisible.toggle()
        } label: {
            Text(PlaybackViewModel.formatSpeed(viewModel.playbackSpeed))
                .font(.system(size: PlaybackChromeMetrics.timeFontSize, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, PlaybackChromeMetrics.speedButtonHorizontalPadding)
                .frame(height: WorkbenchControlMetrics.redesignIconButtonSize)
                .workbenchAccessibilityFocusRing(
                    isFocused: isFocused,
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                    isPlayerChrome: true
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(
            PlaybackSpeedChromeButtonStyle(
                isOpen: isSpeedMenuVisible
            )
        )
        .focusable(false)
        .accessibilityLabel(L("playback.speed"))
        .playerInteractiveRegion()
        .fixedSize(horizontal: true, vertical: false)
        .frame(
            height: WorkbenchControlMetrics.redesignIconButtonSize,
            alignment: .center
        )
    }
}

private func formatPlaybackSeconds(_ totalSeconds: Int) -> String {
    let clampedSeconds = max(0, totalSeconds)
    let hours = clampedSeconds / 3_600
    let minutes = (clampedSeconds % 3_600) / 60
    let seconds = clampedSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

private struct PlaybackSpeedChromeButtonStyle: ButtonStyle {
    var isOpen = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                    style: .continuous
                )
                .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .onPointerHover { isHovered = $0 }
            .onChange(of: configuration.isPressed) { newValue in
                if newValue {
                    isHovered = true
                } else if (NSEvent.pressedMouseButtons & 1) != 0 {
                    isHovered = false
                }
            }
    }

    private var foregroundColor: Color {
        isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return PlaybackTheme.controlPressedBackground
        }
        if isHovered || isOpen {
            return PlaybackTheme.controlHoverBackground
        }
        return Color.clear
    }
}
