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

    /// --color-playback-information-badge-bg
    static let informationBadgeBackgroundNative = subtitleFocusDynamicColor(
        light: NSColor.hex("#D1D5DB"),
        dark: NSColor.hex("#18181B")
    )

    /// --color-playback-information-badge-text
    static let informationBadgeTextNative = subtitleFocusDynamicColor(
        light: NSColor.hex("#1F2937"),
        dark: NSColor.hex("#F4F4F5")
    )

    /// --color-playback-information-badge-unselected-bg
    static let informationBadgeUnselectedBackgroundNative =
        subtitleFocusDynamicColor(
            light: NSColor.hex("#E5E7EB"),
            dark: NSColor.hex("#303036")
        )

    /// --color-playback-information-badge-unselected-text
    static let informationBadgeUnselectedTextNative =
        subtitleFocusDynamicColor(
            light: NSColor.hex("#475467"),
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
    /// --spacing-2
    static let informationBadgeGap = WorkbenchControlMetrics.redesignSpacing2
    /// --spacing-2
    static let informationCueGap = WorkbenchControlMetrics.redesignSpacing2
    /// --font-size-caption
    static let informationBadgeFontSize = WorkbenchControlMetrics.redesignFontSizeCaption
    /// --radius-chip
    static let informationBadgeRadius = WorkbenchControlMetrics.redesignChipRadius
    /// --padding-chip-x
    static let informationBadgeHorizontalPadding =
        WorkbenchControlMetrics.redesignChipHorizontalPadding
    /// --padding-chip-y
    static let informationBadgeVerticalPadding =
        WorkbenchControlMetrics.redesignChipVerticalPadding
    /// --height-playback-cue-information-badge
    static let informationBadgeRowHeight: CGFloat = 23
    static var informationHeight: CGFloat {
        informationBadgeRowHeight + informationCueGap
    }
    /// --duration-subtitle-focus-scroll
    static let reelTransitionDuration = 0.22
    static func resolvedReelTransitionDuration(
        reducesMotion: Bool
    ) -> TimeInterval {
        reducesMotion ? 0 : reelTransitionDuration
    }
}

enum PlaybackOverlayMetrics {
    static let tabBarHeight: CGFloat = 54
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

    static let videoTopBarHeight: CGFloat = 46
    static let height: CGFloat = 98
    static let bottomControlsRowHeight: CGFloat = 52
    static let capsuleButtonHeight: CGFloat = 40
    static let circleButtonSize: CGFloat = 40
    static let circleButtonIconSize: CGFloat = 18
    static let speedButtonWidth: CGFloat = 54
    static let speedMenuWidth: CGFloat = 172
    static let speedMenuHeight: CGFloat = 234
    static let speedMenuItemHeight: CGFloat = 30
    static let progressHitAreaHeight: CGFloat = 18
    static let progressTrackHeight: CGFloat = 3
    static let progressTrackHoverHeight: CGFloat = 6
    static let progressTimeCapsuleHeight: CGFloat = 22
    static let progressThumbSize: CGFloat = 12
    static let windowControlButtonSize: CGFloat = 13
    static let windowControlGlyphSize: CGFloat = 7
    static let topbarTitleMaxWidth: CGFloat = 520

    static let chromeHorizontalPadding: CGFloat = 24
    static let chromeBottomPadding: CGFloat = 12
    static let progressTopPadding: CGFloat = 16
    static let capsuleButtonHorizontalPadding: CGFloat = 16
    static let speedMenuPadding: CGFloat = 6
    static let speedMenuItemHorizontalPadding: CGFloat = 8
    static let progressTimeCapsuleHorizontalPadding: CGFloat = 8
    static let topbarHorizontalPadding: CGFloat = 16

    static let leftControlsGap: CGFloat = 8
    static let rightControlsGap: CGFloat = 6
    static let timeLabelGap: CGFloat = 4
    static let windowControlsGap: CGFloat = 8
    static let speedMenuGap: CGFloat = 8

    static let capsuleRadius: CGFloat = 9999
    static let speedMenuRadius: CGFloat = 14
    static let speedMenuItemRadius: CGFloat = 8

    static let timeFontSize: CGFloat = 12
    static let progressTimeFontSize: CGFloat = 10
    static let speedMenuCheckFontSize: CGFloat = 11
    static let speedMenuItemFontSize: CGFloat = 13
    static let topbarTitleFontSize: CGFloat = 13

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
}

/// A unified concentric backing visual element for cinematic buttons and interactive controls.
/// Supports both circular and capsule-like shapes with standardized micro-animation hover/press dynamics.
public struct PlaybackCinematicBacking<S: Shape>: View {
    public let shape: S
    public let isHovered: Bool
    public let isPressed: Bool
    public let scaleX: CGFloat
    public let scaleY: CGFloat

    public init(
        shape: S,
        isHovered: Bool,
        isPressed: Bool = false,
        scaleX: CGFloat = 0.85,
        scaleY: CGFloat = 0.85
    ) {
        self.shape = shape
        self.isHovered = isHovered
        self.isPressed = isPressed
        self.scaleX = scaleX
        self.scaleY = scaleY
    }

    public var body: some View {
        ZStack {
            // Persistent outer base
            shape
                .fill(PlaybackTheme.controlBackground)

            // Concentric inner hover highlight
            if isHovered || isPressed {
                shape
                    .fill(PlaybackTheme.controlHoverBackground)
                    .scaleEffect(x: scaleX, y: scaleY)
            }
        }
    }
}
