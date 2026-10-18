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
    let canRepeatCurrentCue: Bool
    let repeatCurrentCue: () -> Void
    let isFullscreen: Bool
    let isFullscreenToggleDisabled: Bool
    let toggleFullscreen: () -> Void
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
            canRepeatCurrentCue: appState.playback.canRepeatCurrentCue,
            repeatCurrentCue: { appState.repeatCurrentPlaylistCue() },
            isFullscreen: isFullscreen,
            isFullscreenToggleDisabled: isFullscreenToggleDisabled,
            toggleFullscreen: fullscreenAction ?? {
                appState.togglePlaybackFullscreenFromUser()
            },
            toggleMoreMenu: { appState.togglePlaybackMoreMenu() }
        )
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

private struct PlaybackSpeedButtonAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
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
    @State private var speedButtonFrame: CGRect = .zero

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
        .background(
            PlaybackChromeTimelineResetter(
                timeline: timeline,
                isSpeedMenuVisible: isSpeedMenuVisibleBinding
            )
        )
        .onDisappear {
            playback.closeSpeedMenu()
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
        VStack(spacing: 0) {
            scrubberRow

            HStack(spacing: 0) {
                leftGroup

                Spacer(minLength: 0)

                rightGroup
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
            LinearGradient(
                colors: [
                    PlaybackTheme.topbarGradientEnd,
                    PlaybackTheme.topbarGradientStart,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    @MainActor
    @ViewBuilder
    private func speedMenuOverlay(anchor: Anchor<CGRect>?) -> some View {
        if playback.isSpeedMenuOpen, let anchor {
            GeometryReader { proxy in
                let buttonFrame = proxy[anchor]
                let menuView = PlaybackChromeSpeedMenu(
                    selectedSpeed: viewModel.playbackSpeed,
                    suppressesInteraction: timeline.isScrubbing
                        || playback.interfaceLayers.isOpen(.commandPanel),
                    highlight: playback.speedMenuHighlight,
                    onSelect: { speed in
                        viewModel.setSpeed(speed)
                        playback.closeSpeedMenu()
                    }
                )
                let menuSize = NSHostingView(rootView: menuView).fittingSize
                // The button sits on the bottom chrome, so the shared rule finds
                // no room below and opens the menu upward.
                let menuFrame = MenuPlacement.openingFrame(
                    anchor: buttonFrame,
                    menuSize: menuSize,
                    in: CGRect(origin: .zero, size: proxy.size),
                    gap: PlaybackChromeMetrics.speedMenuGap,
                    // Keeps the menu inside the same margin the controls use
                    // instead of resting on the window edge.
                    edgeInset: PlaybackChromeMetrics.chromeHorizontalPadding
                )
                let menuWidth = menuSize.width
                let menuHeight = menuSize.height
                let x = menuFrame.midX
                let y = menuFrame.midY

                ZStack(alignment: .topLeading) {
                    MenuGateClientView(
                        gate: playback.interfaceLayers.menuGate,
                        owner: .playbackPage,
                        kind: .playerSpeedMenu,
                        menuFrame: menuFrame,
                        // A press on the speed button is left to the button,
                        // which toggles the menu itself.
                        anchorFrame: buttonFrame,
                        handleKey: { keyCode, isRepeat in
                            playback.handleSpeedMenuKey(
                                keyCode,
                                isRepeat: isRepeat
                            )
                        },
                        dismiss: { _ in
                            DispatchQueue.main.async {
                                playback.closeSpeedMenu()
                            }
                        }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)

                    menuView
                        .frame(width: menuWidth, height: menuHeight)
                        .position(x: x, y: y)
                }
                .zIndex(2)
            }
        }
    }

    private var scrubberRow: some View {
        PlaybackProgressScrubberRow(
            viewModel: viewModel,
            timeline: timeline
        )
        .padding(.horizontal, PlaybackChromeMetrics.progressRowHorizontalPadding)
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

    private var leftGroup: some View {
        HStack(spacing: PlaybackChromeMetrics.controlsGap) {
            PlaybackPlayPauseChromeButton(
                viewModel: viewModel,
                timeline: timeline,
                action: controls.togglePlayPause
            )
            .workbenchTooltip(
                scenarioID: "player.control.play_pause",
                isActive: !timeline.isScrubbing,
                label: viewModel.isPlaying ? L("playback.pause") : L("playback.play"),
                shortcut: .action(.playPause)
            )

            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: .skipBack,
                iconWeight: .fill,
                isDisabled: !controls.canGoPrevious,
                accessibilityLabel: L("playback.previous_video"),
                action: controls.goPrevious
            )
            .workbenchTooltip(
                scenarioID: "player.control.previous",
                isActive: !timeline.isScrubbing,
                label: previousTooltipLabel,
                shortcut: controls.canGoPrevious ? .action(.previous) : .none
            )

            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: .skipForward,
                iconWeight: .fill,
                isDisabled: !controls.canGoNext,
                accessibilityLabel: L("playback.next_video"),
                action: controls.goNext
            )
            .workbenchTooltip(
                scenarioID: "player.control.next",
                isActive: !timeline.isScrubbing,
                label: nextTooltipLabel,
                shortcut: controls.canGoNext ? .action(.next) : .none
            )

            PlaybackVolumeControl(
                viewModel: viewModel,
                timeline: timeline
            )
        }
    }

    private var rightGroup: some View {
        HStack(spacing: PlaybackChromeMetrics.controlsGap) {
            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: .repeatIcon,
                isDisabled: !controls.canRepeatCurrentCue,
                accessibilityLabel: L("playback.repeat"),
                action: controls.repeatCurrentCue
            )
            .workbenchTooltip(
                scenarioID: "player.control.repeat",
                isActive: !timeline.isScrubbing,
                label: controls.canRepeatCurrentCue
                    ? L("playback.repeat")
                    : L("tooltip.player.repeat.disabled"),
                shortcut: controls.canRepeatCurrentCue ? .action(.repeatCue) : .none
            )

            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: .camera,
                accessibilityLabel: L("playback.copy_screenshot"),
                action: viewModel.copyCurrentFrameScreenshot
            )
            .workbenchTooltip(
                scenarioID: "player.control.copy_screenshot",
                isActive: !timeline.isScrubbing,
                label: L("tooltip.player.copy_screenshot"),
                shortcut: .action(.copyScreenshot)
            )

            PlaybackSubtitleChromeButton(
                viewModel: viewModel,
                timeline: timeline
            )
            .workbenchTooltip(
                scenarioID: "player.control.subtitles",
                isActive: !timeline.isScrubbing,
                label: viewModel.areSubtitlesVisible
                    ? L("tooltip.player.subtitles.hide")
                    : L("tooltip.player.subtitles.show"),
                shortcut: .action(.toggleSubtitles)
            )

            speedControl

            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: .dotsThreeVertical,
                isOpen: playback.moreMenu != nil,
                accessibilityLabel: L("playback.more"),
                action: controls.toggleMoreMenu
            )
            .anchorPreference(key: PlaybackMoreButtonAnchorKey.self, value: .bounds) { $0 }

            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: controls.isFullscreen ? .cornersIn : .cornersOut,
                isDisabled: controls.isFullscreenToggleDisabled,
                accessibilityLabel: L("playback.fullscreen"),
                action: controls.toggleFullscreen
            )
            .workbenchTooltip(
                scenarioID: "player.control.fullscreen",
                isActive: !timeline.isScrubbing,
                label: controls.isFullscreenToggleDisabled
                    ? L("tooltip.player.fullscreen.disabled")
                    : (controls.isFullscreen
                        ? L("tooltip.player.fullscreen.exit")
                        : L("tooltip.player.fullscreen.enter")),
                shortcut: controls.isFullscreenToggleDisabled ? .none : .action(.toggleFullscreen)
            )
        }
    }

    private var speedControl: some View {
        PlaybackSpeedChromeButton(
            viewModel: viewModel,
            timeline: timeline,
            isSpeedMenuVisible: isSpeedMenuVisibleBinding,
            speedButtonFrame: $speedButtonFrame
        )
        .workbenchTooltip(
            scenarioID: "player.control.speed",
            isActive: !timeline.isScrubbing && !playback.isSpeedMenuOpen,
            label: L("tooltip.player.speed")
        )
        .anchorPreference(key: PlaybackSpeedButtonAnchorKey.self, value: .bounds) { $0 }
    }
}

private struct PlaybackChromeTimelineResetter: View {
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @Binding var isSpeedMenuVisible: Bool

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onChange(of: timeline.isScrubbing) { isScrubbing in
                if isScrubbing {
                    isSpeedMenuVisible = false
                }
            }
    }
}

private struct PlaybackTimelineChromeIconButton: View {
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    let icon: AppIcon
    var iconWeight: AppIconWeight?
    var isSelected = false
    var isOpen = false
    var isDisabled = false
    let accessibilityLabel: String
    let action: () -> Void

    init(
        timeline: PlaybackTimelineInteractionStore,
        icon: AppIcon,
        iconWeight: AppIconWeight? = nil,
        isSelected: Bool = false,
        isOpen: Bool = false,
        isDisabled: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.timeline = timeline
        self.icon = icon
        self.iconWeight = iconWeight
        self.isSelected = isSelected
        self.isOpen = isOpen
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        PlaybackChromeIconButton(
            icon: icon,
            iconWeight: iconWeight,
            isSelected: isSelected,
            isOpen: isOpen,
            isDisabled: isDisabled,
            suppressesInteraction: timeline.isScrubbing,
            accessibilityLabel: accessibilityLabel,
            action: action
        )
    }
}

private struct PlaybackPlayPauseChromeButton: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    let action: () -> Void

    var body: some View {
        PlaybackChromeIconButton(
            icon: viewModel.isPlaying ? .pause : .play,
            iconWeight: .fill,
            suppressesInteraction: timeline.isScrubbing,
            accessibilityLabel: viewModel.isPlaying ? L("playback.pause") : L("playback.play"),
            action: action
        )
    }
}

private struct PlaybackSubtitleChromeButton: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore

    var body: some View {
        PlaybackChromeIconButton(
            icon: .subtitles,
            isSelected: viewModel.areSubtitlesVisible,
            suppressesInteraction: timeline.isScrubbing,
            accessibilityLabel: L("playback.subtitles"),
            action: viewModel.toggleSubtitles
        )
    }
}

private struct PlaybackProgressScrubberRow: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @ObservedObject private var scrubTimeStore: PlaybackTimelineScrubTimeStore

    init(
        viewModel: PlaybackViewModel,
        timeline: PlaybackTimelineInteractionStore
    ) {
        self.viewModel = viewModel
        self.timeline = timeline
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
                timeline: timeline
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
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @Binding var isSpeedMenuVisible: Bool
    @Binding var speedButtonFrame: CGRect

    var body: some View {
        Button {
            guard !timeline.isScrubbing else {
                return
            }
            isSpeedMenuVisible.toggle()
        } label: {
            Text(PlaybackViewModel.formatSpeed(viewModel.playbackSpeed))
                .font(.system(size: PlaybackChromeMetrics.timeFontSize, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, PlaybackChromeMetrics.speedButtonHorizontalPadding)
                .frame(height: WorkbenchControlMetrics.redesignIconButtonSize)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(
            PlaybackSpeedChromeButtonStyle(
                isOpen: isSpeedMenuVisible,
                suppressesInteraction: timeline.isScrubbing
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
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        updateSpeedButtonFrame(geo.frame(in: .global))
                    }
                    .onChange(of: geo.frame(in: .global)) { newFrame in
                        updateSpeedButtonFrame(newFrame)
                    }
            }
        )
    }

    private func updateSpeedButtonFrame(_ newFrame: CGRect) {
        guard speedButtonFrame != newFrame else {
            return
        }
        speedButtonFrame = newFrame
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
    var suppressesInteraction = false
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
                .fill(backgroundColor)
            )
            .onPointerHover { isHovered = suppressesInteraction ? false : $0 }
            .onChange(of: suppressesInteraction) { isSuppressed in
                if isSuppressed {
                    isHovered = false
                }
            }
    }

    private var foregroundColor: Color {
        isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary
    }

    private var backgroundColor: Color {
        guard isInteractive else {
            return Color.clear
        }
        if isHovered || isOpen {
            return PlaybackTheme.controlHoverBackground
        }
        return Color.clear
    }

    private var isInteractive: Bool {
        isEnabled && !suppressesInteraction
    }
}
