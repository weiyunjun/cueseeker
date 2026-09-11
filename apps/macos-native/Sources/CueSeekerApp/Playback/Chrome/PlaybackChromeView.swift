import AppKit
import SwiftUI

@MainActor
struct PlaybackChromeControls {
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
            canRepeatCurrentCue: appState.playback.canRepeatCurrentCue,
            repeatCurrentCue: { appState.repeatCurrentPlaylistCue() },
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
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @ObservedObject var playback: PlaybackStore
    let viewModel: PlaybackViewModel
    let timeline: PlaybackTimelineInteractionStore
    let controls: PlaybackChromeControls
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
        .background(
            PlaybackChromeTimelineResetter(
                timeline: timeline,
                isSpeedMenuVisible: isSpeedMenuVisibleBinding,
                isTimeHovered: $isTimeHovered
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
        if playback.isSpeedMenuOpen, let anchor {
            GeometryReader { proxy in
                let buttonFrame = proxy[anchor]
                let menuSize = CGSize(
                    width: PlaybackChromeMetrics.speedMenuWidth,
                    height: PlaybackChromeMetrics.speedMenuHeight
                )
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

                    PlaybackChromeSpeedMenu(
                        selectedSpeed: viewModel.playbackSpeed,
                        suppressesInteraction: timeline.isScrubbing
                            || playback.interfaceLayers.isOpen(.commandPanel),
                        highlight: playback.speedMenuHighlight,
                        onSelect: { speed in
                            viewModel.setSpeed(speed)
                            playback.closeSpeedMenu()
                        }
                    )
                    .frame(width: menuWidth, height: menuHeight)
                    .position(x: x, y: y)
                }
                .zIndex(2)
            }
        }
    }


    private var scrubberRow: some View {
        PlaybackProgressScrubber(
            viewModel: viewModel,
            timeline: timeline
        )
            .padding(.horizontal, PlaybackChromeMetrics.chromeHorizontalPadding)
    }

    private var leftGroup: some View {
        HStack(spacing: PlaybackChromeMetrics.leftControlsGap) {
            PlaybackPlayPauseChromeButton(
                viewModel: viewModel,
                timeline: timeline,
                action: controls.togglePlayPause
            )

            HStack(spacing: 0) {
                PlaybackTimelineChromeIconButton(
                    timeline: timeline,
                    icon: .skipBack,
                    iconWeight: .fill,
                    kind: .transport,
                    isDisabled: !controls.canGoPrevious,
                    hasPersistentBase: false,
                    accessibilityLabel: L("playback.previous_video"),
                    action: controls.goPrevious
                )

                PlaybackTimelineChromeIconButton(
                    timeline: timeline,
                    icon: .skipForward,
                    iconWeight: .fill,
                    kind: .transport,
                    isDisabled: !controls.canGoNext,
                    hasPersistentBase: false,
                    accessibilityLabel: L("playback.next_video"),
                    action: controls.goNext
                )
            }
            .frame(height: PlaybackChromeMetrics.capsuleButtonHeight)
            .background(Capsule().fill(PlaybackTheme.controlBackground))

            PlaybackVolumeControl(
                viewModel: viewModel,
                timeline: timeline
            )

            PlaybackChromeTimeCapsule(
                viewModel: viewModel,
                timeline: timeline,
                isTimeHovered: $isTimeHovered
            )
        }
    }

    private var rightGroup: some View {
        HStack(spacing: PlaybackChromeMetrics.rightControlsGap) {
            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: .repeatIcon,
                kind: .transport,
                isDisabled: !controls.canRepeatCurrentCue,
                accessibilityLabel: L("playback.repeat"),
                action: controls.repeatCurrentCue
            )

            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: .image,
                kind: .transport,
                accessibilityLabel: L("playback.copy_screenshot"),
                action: viewModel.copyCurrentFrameScreenshot
            )

            PlaybackSubtitleChromeButton(
                viewModel: viewModel,
                timeline: timeline
            )

            speedControl

            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                icon: controls.isFullscreen ? .cornersIn : .cornersOut,
                kind: .transport,
                isDisabled: controls.isFullscreenToggleDisabled,
                accessibilityLabel: L("playback.fullscreen"),
                action: controls.toggleFullscreen
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
        .anchorPreference(key: PlaybackSpeedButtonAnchorKey.self, value: .bounds) { $0 }
    }


}

private struct PlaybackChromeTimelineResetter: View {
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @Binding var isSpeedMenuVisible: Bool
    @Binding var isTimeHovered: Bool

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onChange(of: timeline.isScrubbing) { isScrubbing in
                if isScrubbing {
                    isSpeedMenuVisible = false
                    isTimeHovered = false
                }
            }
    }
}

private struct PlaybackTimelineChromeIconButton: View {
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    let icon: AppIcon
    var iconWeight: AppIconWeight?
    var kind: PlaybackChromeButtonKind = .circle
    var isSelected = false
    var isDisabled = false
    var hasPersistentBase = true
    let accessibilityLabel: String
    let action: () -> Void

    init(
        timeline: PlaybackTimelineInteractionStore,
        icon: AppIcon,
        iconWeight: AppIconWeight? = nil,
        kind: PlaybackChromeButtonKind = .circle,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        hasPersistentBase: Bool = true,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.timeline = timeline
        self.icon = icon
        self.iconWeight = iconWeight
        self.kind = kind
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.hasPersistentBase = hasPersistentBase
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        PlaybackChromeIconButton(
            icon: icon,
            iconWeight: iconWeight,
            kind: kind,
            isSelected: isSelected,
            isDisabled: isDisabled,
            suppressesInteraction: timeline.isScrubbing,
            hasPersistentBase: hasPersistentBase,
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
            kind: .transport,
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
            kind: .circle,
            isSelected: viewModel.areSubtitlesVisible,
            suppressesInteraction: timeline.isScrubbing,
            accessibilityLabel: L("playback.subtitles"),
            action: viewModel.toggleSubtitles
        )
    }
}

private struct PlaybackChromeTimeCapsule: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @ObservedObject private var scrubTimeStore: PlaybackTimelineScrubTimeStore
    @Binding var isTimeHovered: Bool

    init(
        viewModel: PlaybackViewModel,
        timeline: PlaybackTimelineInteractionStore,
        isTimeHovered: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self.timeline = timeline
        _scrubTimeStore = ObservedObject(wrappedValue: timeline.scrubTimeStore)
        _isTimeHovered = isTimeHovered
    }

    var body: some View {
        HStack(spacing: PlaybackChromeMetrics.timeLabelGap) {
            Text(formatPlaybackTime(scrubTimeStore.scrubTime ?? viewModel.displayedCurrentTime))
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
        .onPointerHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isTimeHovered = timeline.isScrubbing ? false : hovering
            }
        }
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
                .frame(width: PlaybackChromeMetrics.speedButtonWidth, height: PlaybackChromeMetrics.capsuleButtonHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(
            PlaybackChromeCapsuleButtonStyle(
                suppressesInteraction: timeline.isScrubbing
            )
        )
        .focusable(false)
        .accessibilityLabel(L("playback.speed"))
        .playerInteractiveRegion()
        .frame(
            width: PlaybackChromeMetrics.speedButtonWidth,
            height: PlaybackChromeMetrics.capsuleButtonHeight,
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
                    scaleX: 0.88,
                    scaleY: 0.85
                )
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
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

    private var isInteractive: Bool {
        isEnabled && !suppressesInteraction
    }
}
