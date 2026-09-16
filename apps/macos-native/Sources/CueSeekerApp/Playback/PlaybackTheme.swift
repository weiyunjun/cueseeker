import AppKit
import SwiftUI

/// Defines the global cinematic theme parameters and styles for CueSeeker playback interface.
/// Discards standard system light/dark color scheme variation in favor of a cohesive, high-contrast dark theater environment.
public enum PlaybackTheme {

    // MARK: - Subtitle Focus Colors

    private static let subtitleFocusCueSelectedOpacity = 0.94
    private static let subtitleFocusCueGroupSelectedOpacity = 0.62
    private static let subtitleFocusCueUnselectedOpacity = 0.34

    private static func subtitleFocusDynamicColor(
        light: NSColor,
        dark: NSColor
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? dark
                : light
        }
    }

    /// --color-subtitle-focus-overlay-bg
    public static var subtitleFocusOverlayBackground: Color {
        Color(nsColor: subtitleFocusOverlayBackgroundNative)
    }

    static let subtitleFocusOverlayBackgroundNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 246 / 255,
            green: 247 / 255,
            blue: 249 / 255,
            alpha: 1
        ),
        dark: NSColor(
            red: 36 / 255,
            green: 36 / 255,
            blue: 38 / 255,
            alpha: 1
        )
    )

    /// --color-subtitle-focus-cue-selected
    public static var subtitleFocusCueSelected: Color {
        Color(nsColor: subtitleFocusCueSelectedNative)
    }

    /// --color-subtitle-focus-cue-group-selected
    public static var subtitleFocusCueGroupSelected: Color {
        Color(nsColor: subtitleFocusCueGroupSelectedNative)
    }

    /// --color-subtitle-focus-cue-unselected
    public static var subtitleFocusCueUnselected: Color {
        Color(nsColor: subtitleFocusCueUnselectedNative)
    }

    static let subtitleFocusCueSelectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 17 / 255,
            green: 24 / 255,
            blue: 39 / 255,
            alpha: 1
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(subtitleFocusCueSelectedOpacity)
        )
    )
    static let subtitleFocusCueGroupSelectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 71 / 255,
            green: 84 / 255,
            blue: 103 / 255,
            alpha: 1
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(subtitleFocusCueGroupSelectedOpacity)
        )
    )
    static let subtitleFocusCueUnselectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 133 / 255,
            green: 139 / 255,
            blue: 149 / 255,
            alpha: 1
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(subtitleFocusCueUnselectedOpacity)
        )
    )

    /// --color-playback-cue-timeline-focused
    static let cueTimelineFocusedNative = subtitleFocusDynamicColor(
        light: NSColor.hex("#667085"),
        dark: NSColor.hex("#71717A")
    )

    /// --color-playback-cue-timeline-muted
    static let cueTimelineMutedNative = subtitleFocusDynamicColor(
        light: NSColor.hex("#D0D5DD"),
        dark: NSColor.hex("#52525B")
    )

    /// --color-playback-cue-metadata
    static let cueMetadataNative = subtitleFocusDynamicColor(
        light: NSColor.hex("#667085"),
        dark: NSColor.hex("#A1A1AA")
    )

    /// --color-playback-module-sidebar-selected
    public static var playbackModuleSidebarSelected: Color {
        Color(nsColor: playbackModuleSidebarSelectedNative)
    }

    /// --color-playback-module-sidebar-unselected
    public static var playbackModuleSidebarUnselected: Color {
        Color(nsColor: playbackModuleSidebarUnselectedNative)
    }

    static let playbackModuleSidebarSelectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 17 / 255,
            green: 24 / 255,
            blue: 39 / 255,
            alpha: 1
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(subtitleFocusCueSelectedOpacity)
        )
    )
    static let playbackModuleSidebarUnselectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 102 / 255,
            green: 112 / 255,
            blue: 133 / 255,
            alpha: 1
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(subtitleFocusCueUnselectedOpacity)
        )
    )
    // MARK: - Player Chrome Colors

    /// --color-player-stage-bg
    public static var stageBackground: Color {
        Color.black
    }

    /// --color-player-control-bg
    public static var controlBackground: Color {
        Color.black.opacity(0.30)
    }

    /// --color-player-control-bg-hover
    public static var controlHoverBackground: Color {
        Color.white.opacity(0.16)
    }

    /// --color-player-task-count-badge-bg
    public static var taskCountBadgeBackground: Color {
        Color.white.opacity(0.16)
    }

    /// --color-player-task-count-badge-bg-hover
    public static var taskCountBadgeHoverBackground: Color {
        Color.white.opacity(0.28)
    }

    /// --color-player-menu-bg
    public static var menuBackground: Color {
        Color.black.opacity(0.55)
    }

    /// --color-player-menu-item-hover-bg
    public static var menuItemHoverBackground: Color {
        Color.white.opacity(0.12)
    }

    /// --color-player-text-primary
    public static var textPrimary: Color {
        Color.white.opacity(0.94)
    }

    /// --color-player-text-secondary
    public static var textSecondary: Color {
        Color.white.opacity(0.62)
    }

    /// --color-player-text-tertiary
    public static var textTertiary: Color {
        Color.white.opacity(0.34)
    }

    /// --color-player-icon-selected
    public static var iconSelected: Color {
        Color(red: 0.10, green: 0.10, blue: 0.12)
    }

    /// --color-player-progress-fill
    public static var progressFill: Color {
        Color.accentColor
    }

    /// --color-player-progress-track
    public static var progressTrack: Color {
        Color.black.opacity(0.60)
    }

    /// --color-player-progress-hover-track
    public static var progressHoverTrack: Color {
        Color.white.opacity(0.35)
    }

    /// --color-player-window-close
    public static var windowClose: Color {
        Color(red: 1.0, green: 95 / 255, blue: 87 / 255)
    }

    /// --color-player-window-minimize
    public static var windowMinimize: Color {
        Color(red: 254 / 255, green: 188 / 255, blue: 46 / 255)
    }

    /// --color-player-window-zoom
    public static var windowZoom: Color {
        Color(red: 40 / 255, green: 200 / 255, blue: 64 / 255)
    }

    /// --color-player-window-control-border
    public static var windowControlBorder: Color {
        Color.black.opacity(0.18)
    }

    /// --color-player-window-control-glyph
    public static var windowControlGlyph: Color {
        Color.black.opacity(0.55)
    }

    /// --color-player-topbar-gradient-start
    public static var topbarGradientStart: Color {
        Color(red: 18 / 255, green: 18 / 255, blue: 24 / 255).opacity(0.66)
    }

    /// --color-player-topbar-gradient-end
    public static var topbarGradientEnd: Color {
        Color(red: 18 / 255, green: 18 / 255, blue: 24 / 255).opacity(0)
    }

    /// --shadow-player-overlay
    public static var overlayShadowColor: Color {
        Color.black.opacity(0.42)
    }

    public static let overlayShadowRadius: CGFloat = 24
    public static let overlayShadowYOffset: CGFloat = 12

    /// --shadow-player-topbar-title
    public static var topbarTitleShadowColor: Color {
        Color.black.opacity(0.50)
    }

    public static let topbarTitleShadowRadius: CGFloat = 2
    public static let topbarTitleShadowYOffset: CGFloat = 1

    /// Premium cinematic semi-translucent pure black surface backing.
    public static var cinematicBacking: Color {
        menuBackground
    }

    /// Dark translucent capsule fill when hovered.
    public static var capsuleHoverFill: Color {
        controlHoverBackground
    }

    /// Compatibility alias for active playback progress track.
    public static var progressRed: Color {
        progressFill
    }

    /// Semi-translucent gray for timeline hovered track extension.
    public static var scrubberHoverTrack: Color {
        progressHoverTrack
    }

    /// Background track color for the scrubber timeline.
    public static var scrubberTrackBackground: Color {
        progressTrack
    }
}

enum PlaybackSubtitleFocusMetrics {
    /// --padding-subtitle-focus-cue-y
    static let cueVerticalPadding: CGFloat = 8
    /// --gap-subtitle-focus-cue
    static let cueGap: CGFloat = 8
    /// --gap-subtitle-focus-internal-line
    static let internalLineGap: CGFloat = 3
    static var minimumNaturalCueHeight: CGFloat {
        cueLineHeight + cueVerticalPadding * 2
    }
    /// --width-subtitle-focus-content-max
    static let contentMaxWidth: CGFloat = 960
    /// --spacing-8
    static let contentInset: CGFloat = 32
    /// --font-size-subtitle-focus-cue
    static let cueFontSize: CGFloat = 24
    /// --line-height-subtitle-focus-cue
    static let cueLineHeight: CGFloat = 32
    /// --font-weight-subtitle-focus-cue
    static let cueFontWeight = NSFont.Weight.semibold
    /// --font-size-subtitle-focus-cue-group
    static let cueGroupFontSize: CGFloat = 20
    /// --line-height-subtitle-focus-cue-group
    static let cueGroupLineHeight: CGFloat = 28
    /// --font-weight-subtitle-focus-cue-group
    static let cueGroupFontWeight = NSFont.Weight.medium
    /// --gap-playback-cue-metadata
    static let metadataCueGap = WorkbenchControlMetrics.redesignSpacing2
    /// --gap-playback-cue-metadata-item
    static let metadataItemGap = WorkbenchControlMetrics.redesignSpacing3
    /// --font-size-caption
    static let metadataFontSize = WorkbenchControlMetrics.redesignFontSizeCaption
    /// --font-weight-playback-cue-metadata
    static let metadataFontWeight = NSFont.Weight.regular
    /// --line-height-playback-cue-metadata
    static let metadataLineHeight: CGFloat = 16
    static var metadataHeight: CGFloat {
        metadataCueGap + metadataLineHeight
    }
    /// --duration-subtitle-focus-scroll
    static let reelTransitionDuration = 0.22
    static func resolvedReelTransitionDuration(
        reducesMotion: Bool
    ) -> TimeInterval {
        reducesMotion ? 0 : reelTransitionDuration
    }
}

enum PlaybackCueTimelineMetrics {
    /// --gap-playback-cue-timeline-marker-inline
    static let markerHorizontalGap = WorkbenchControlMetrics.redesignSpacing6
    /// --size-playback-cue-timeline-dot
    static let dotSize = WorkbenchControlMetrics.redesignSpacing2
    /// --width-playback-cue-timeline-connector
    static let connectorWidth: CGFloat = 1
    /// --gap-playback-cue-timeline-connector-marker
    static let connectorMarkerGap = WorkbenchControlMetrics.redesignSpacing2
}

enum PlaybackCollageSelectionMetrics {
    /// Provisional --size-playback-collage-checkbox: 31px icon box (document: 24px)
    static let checkboxSize: CGFloat = 31
}

enum PlaybackOverlayMetrics {
    static let tabGap = WorkbenchControlMetrics.redesignSpacing4
    static let tabHorizontalPadding = WorkbenchControlMetrics.redesignSpacing2
    static let tabIndicatorGap = WorkbenchControlMetrics.redesignSpacing1
    static let tabFontSize = WorkbenchControlMetrics.redesignFontSizeBody
    static let tabIndicatorWidth: CGFloat = 24
    static let tabIndicatorHeight: CGFloat = 2
}

enum PlaybackChromeMetrics {
    static let horizontalInset: CGFloat = 0
    static let bottomInset: CGFloat = 0

    static let height: CGFloat = 98
    static let bottomControlsRowHeight: CGFloat = 52
    static let capsuleButtonHeight: CGFloat = 40
    static let circleButtonSize: CGFloat = 40
    /// Provisional --size-player-circle-button-icon: 23px icon box (document: 18px)
    static let circleButtonIconSize: CGFloat = 23
    static let speedButtonWidth: CGFloat = 54
    static let speedMenuWidth: CGFloat = 184
    static let speedMenuHeight: CGFloat = 246
    static let speedMenuItemHeight: CGFloat = 30
    static let progressHitAreaHeight: CGFloat = 18
    static let progressTrackHeight: CGFloat = 3
    static let progressTrackHoverHeight: CGFloat = 6
    static let progressTimeCapsuleHeight: CGFloat = 22
    static let progressThumbSize: CGFloat = 12
    static let windowControlButtonSize: CGFloat = 13
    static let windowControlGlyphSize: CGFloat = 7
    static let topbarTitleMaxWidth: CGFloat = 520
    /// --duration-player-ui-idle-hide: 3s
    static let idleHideDuration: TimeInterval = 3

    /// --height-playback-feedback: 52px, a floor rather than a fixed height so
    /// a wrapped message can grow past it.
    static let feedbackMinimumHeight: CGFloat = 52
    /// --width-playback-feedback-max: 520px
    static let feedbackMaxWidth: CGFloat = 520
    /// --radius-playback-feedback: 16px
    static let feedbackRadius: CGFloat = 16
    /// Provisional --size-playback-feedback-icon: 31px icon box (document: 24px)
    static let feedbackIconSize: CGFloat = 31
    /// --font-size-playback-feedback: 18px
    static let feedbackFontSize: CGFloat = 18

    static let chromeHorizontalPadding: CGFloat = 24
    static let chromeBottomPadding: CGFloat = 12
    static let progressTopPadding: CGFloat = 16
    static let capsuleButtonHorizontalPadding: CGFloat = 16
    /// The speed menu keeps the padding every menu shared before menus were
    /// tightened; its own width and height are fixed numbers measured against
    /// this one, and it is not part of that change.
    static let speedMenuPadding: CGFloat = 12
    static let speedMenuItemHorizontalPadding: CGFloat = 8
    static let progressTimeCapsuleHorizontalPadding: CGFloat = 8
    static let topbarHorizontalPadding: CGFloat = 16

    static let leftControlsGap: CGFloat = 8
    static let rightControlsGap: CGFloat = 6
    static let timeLabelGap: CGFloat = 4
    static let windowControlsGap: CGFloat = 8
    /// Provisional --gap-player-window-controls-return: after the window
    /// controls to the return button, pending the owner's value.
    static let windowControlsReturnGap = topbarHorizontalPadding
    static let speedMenuGap: CGFloat = 8

    static let capsuleRadius: CGFloat = 9999
    static let speedMenuRadius: CGFloat = 14
    static let speedMenuItemRadius: CGFloat = 8

    static let timeFontSize: CGFloat = 12
    static let progressTimeFontSize: CGFloat = 10
    /// Provisional --font-size-player-speed-menu-check: 14px icon box (document: 11px)
    static let speedMenuCheckFontSize: CGFloat = 14
    static let speedMenuItemFontSize: CGFloat = 13

    static let speedMenuItemVerticalGap: CGFloat = 2
    static let speedMenuItemContentGap: CGFloat = 10
    static let speedMenuCheckColumnWidth: CGFloat = 14
    static let speedMenuItemWidth: CGFloat = speedMenuWidth - speedMenuPadding * 2
    static let speedMenuOverlayTopPadding: CGFloat = 24
    static let speedMenuOverlapClearance: CGFloat = 20
    static let hiddenOffsetPadding: CGFloat = 28
    static let progressTimeCapsuleMinWidth: CGFloat = 44
    static let progressTimeCapsuleGap: CGFloat = 2
    static let progressTimeCapsuleYOffset: CGFloat = -(progressTimeCapsuleHeight + progressTimeCapsuleGap)
    static let windowControlBorderWidth: CGFloat = 0.5
    static let windowControlZoomGlyphSize: CGFloat = windowControlGlyphSize - 2

    static let interactiveHeight: CGFloat = height + speedMenuHeight + speedMenuGap + speedMenuOverlayTopPadding
    static let hiddenOffset: CGFloat = interactiveHeight + hiddenOffsetPadding

    /// Where the return button starts in the player and Playback Overlay top
    /// bars: after the window controls, or at the bar's own padding once the
    /// system titlebar has taken them over in fullscreen.
    @MainActor
    static func topbarReturnLeadingInset(isFullscreen: Bool) -> CGFloat {
        guard !isFullscreen else {
            return topbarHorizontalPadding
        }

        return WorkbenchControlMetrics.redesignSpacing6
            + AppWindowControls.clusterWidth
            + windowControlsReturnGap
    }

    /// A trailing function region of `buttonCount` Icon Buttons.
    static func topbarButtonGroupWidth(buttonCount: Int) -> CGFloat {
        CGFloat(buttonCount) * WorkbenchControlMetrics.redesignIconButtonSize
            + CGFloat(max(0, buttonCount - 1)) * WorkbenchControlMetrics.redesignSpacing1
    }

    /// What a centred title or Tabs may occupy: the bar minus twice the wider
    /// side, so it stays on the bar's centre line and reaches neither the
    /// return button nor the trailing buttons.
    @MainActor
    static func topbarCenterMaxWidth(
        barWidth: CGFloat,
        isFullscreen: Bool,
        trailingButtonCount: Int,
        trailingPadding: CGFloat
    ) -> CGFloat {
        let leading = topbarReturnLeadingInset(isFullscreen: isFullscreen)
            + WorkbenchControlMetrics.redesignIconButtonSize
        let trailing = trailingPadding
            + topbarButtonGroupWidth(buttonCount: trailingButtonCount)
        return max(0, barWidth - 2 * (max(leading, trailing) + topbarHorizontalPadding))
    }
}

/// A unified concentric backing visual element for cinematic buttons and interactive controls.
/// Supports both circular and capsule-like shapes with a standardized micro-animation hover dynamic.
public struct PlaybackCinematicBacking<S: Shape>: View {
    public let shape: S
    public let isHovered: Bool
    public let scaleX: CGFloat
    public let scaleY: CGFloat

    public init(
        shape: S,
        isHovered: Bool,
        scaleX: CGFloat = 0.85,
        scaleY: CGFloat = 0.85
    ) {
        self.shape = shape
        self.isHovered = isHovered
        self.scaleX = scaleX
        self.scaleY = scaleY
    }

    public var body: some View {
        ZStack {
            // Persistent outer base
            shape
                .fill(PlaybackTheme.controlBackground)

            // Concentric inner hover highlight
            if isHovered {
                shape
                    .fill(PlaybackTheme.controlHoverBackground)
                    .scaleEffect(x: scaleX, y: scaleY)
            }
        }
    }
}
