import AppKit
import SwiftUI

/// Defines the global cinematic theme parameters and styles for CueSeeker playback interface.
/// Discards standard system light/dark color scheme variation in favor of a cohesive, high-contrast dark theater environment.
public enum PlaybackTheme {

    // MARK: - Subtitle Focus Colors

    private static let subtitleFocusCueSelectedOpacity = 1.0
    private static let subtitleFocusCueGroupSelectedOpacity = 0.68
    private static let subtitleFocusCueUnselectedOpacity = 0.26
    private static let cueMetadataSelectedOpacity = 0.56
    private static let cueMetadataUnselectedLightOpacity = 0.22
    private static let cueMetadataUnselectedDarkOpacity = 0.20

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
            red: 250 / 255,
            green: 251 / 255,
            blue: 253 / 255,
            alpha: 1
        ),
        dark: NSColor(
            red: 24 / 255,
            green: 24 / 255,
            blue: 27 / 255,
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
            red: 15 / 255,
            green: 23 / 255,
            blue: 42 / 255,
            alpha: 1
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(subtitleFocusCueSelectedOpacity)
        )
    )
    static let subtitleFocusCueGroupSelectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 51 / 255,
            green: 65 / 255,
            blue: 85 / 255,
            alpha: 1
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(subtitleFocusCueGroupSelectedOpacity)
        )
    )
    static let subtitleFocusCueUnselectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 15 / 255,
            green: 23 / 255,
            blue: 42 / 255,
            alpha: CGFloat(subtitleFocusCueUnselectedOpacity)
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(subtitleFocusCueUnselectedOpacity)
        )
    )

    /// --color-playback-cue-timeline-muted
    static let cueTimelineMutedNative = subtitleFocusDynamicColor(
        light: NSColor.hex("#D0D5DD"),
        dark: NSColor.hex("#52525B")
    )

    /// --color-playback-cue-metadata-selected
    static let cueMetadataSelectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 15 / 255,
            green: 23 / 255,
            blue: 42 / 255,
            alpha: CGFloat(cueMetadataSelectedOpacity)
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(cueMetadataSelectedOpacity)
        )
    )

    /// --color-playback-cue-metadata-unselected
    static let cueMetadataUnselectedNative = subtitleFocusDynamicColor(
        light: NSColor(
            red: 15 / 255,
            green: 23 / 255,
            blue: 42 / 255,
            alpha: CGFloat(cueMetadataUnselectedLightOpacity)
        ),
        dark: NSColor.white.withAlphaComponent(
            CGFloat(cueMetadataUnselectedDarkOpacity)
        )
    )

    static func cueMetadataNative(isSelected: Bool) -> NSColor {
        isSelected ? cueMetadataSelectedNative : cueMetadataUnselectedNative
    }
    // MARK: - Player Chrome Colors

    /// --color-player-stage-bg
    public static var stageBackground: Color {
        Color.black
    }

    /// --color-player-control-bg-hover
    public static var controlHoverBackground: Color {
        Color.white.opacity(0.16)
    }

    /// --color-player-control-bg-pressed
    public static var controlPressedBackground: Color {
        Color.white.opacity(0.24)
    }

    /// --color-player-control-bg-active
    public static var controlActiveBackground: Color {
        Color.accentColor.opacity(0.26)
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

    /// --color-player-progress-fill
    public static var progressFill: Color {
        Color.accentColor
    }

    /// --color-player-progress-track
    public static var progressTrack: Color {
        Color.white.opacity(0.24)
    }

    /// --color-player-progress-hover-track
    public static var progressHoverTrack: Color {
        Color.white.opacity(0.38)
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

    /// --color-player-error-bg: the error banner reads over any picture, so
    /// the fill is opaque rather than a scrim.
    public static var errorBackground: Color {
        Color(red: 180 / 255, green: 35 / 255, blue: 24 / 255)
    }

    /// --color-player-error-content
    public static var errorContent: Color {
        Color.white
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
    /// --font-size-playback-cue-metadata
    static let metadataFontSize: CGFloat = 14
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
    static let tabFontWeight: Font.Weight = .semibold
    static let tabIndicatorWidth: CGFloat = 24
    static let tabIndicatorHeight: CGFloat = 2
    static let tabSelectionMotionDuration = WorkbenchControlMetrics.redesignSidebarMotionDuration

    static var tabSelectionAnimation: Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: tabSelectionMotionDuration)
    }

    static func tabIndicatorFrame(for tabRect: CGRect) -> CGRect {
        CGRect(
            x: tabRect.midX - tabIndicatorWidth / 2,
            y: tabRect.maxY - tabIndicatorHeight,
            width: tabIndicatorWidth,
            height: tabIndicatorHeight
        )
    }

    static func interpolatedTabTextColor(progress: Double) -> NSColor {
        let clamped = min(1, max(0, progress))
        if clamped <= 0 {
            return WorkbenchRedesignColors.NS.textMuted
        }
        if clamped >= 1 {
            return WorkbenchRedesignColors.NS.textPrimary
        }
        return NSColor(name: nil) { appearance in
            var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            appearance.performAsCurrentDrawingAppearance {
                let start = WorkbenchRedesignColors.NS.textMuted.usingColorSpace(.sRGB)
                    ?? WorkbenchRedesignColors.NS.textMuted
                let end = WorkbenchRedesignColors.NS.textPrimary.usingColorSpace(.sRGB)
                    ?? WorkbenchRedesignColors.NS.textPrimary
                start.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
                end.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            }
            let t = CGFloat(clamped)
            return NSColor(
                srgbRed: r0 + (r1 - r0) * t,
                green: g0 + (g1 - g0) * t,
                blue: b0 + (b1 - b0) * t,
                alpha: a0 + (a1 - a0) * t
            )
        }
    }
}

enum PlaybackChromeMetrics {
    static let horizontalInset: CGFloat = 0
    static let bottomInset: CGFloat = 0

    /// --height-player-bottom-control-bar: 90px
    static let height: CGFloat = 90
    /// --height-player-bottom-controls-row: 44px
    static let bottomControlsRowHeight: CGFloat = 44
    /// --padding-player-speed-button-x: 10px
    static let speedButtonHorizontalPadding: CGFloat = 10
    /// --width-player-volume-slider: 68px
    static let volumeSliderWidth: CGFloat = 68
    /// --size-player-volume-thumb: 10px
    static let volumeThumbSize: CGFloat = 10
    /// --width-player-volume-value: 32px
    static let volumeValueWidth: CGFloat = 32
    /// --padding-player-volume-trailing: 10px
    static let volumeTrailingPadding: CGFloat = 10
    /// --duration-player-volume-expand: 0.18s
    static let volumeExpandDuration: Double = 0.18
    static let volumeExpandedWidth: CGFloat =
        WorkbenchControlMetrics.redesignIconButtonSize
        + volumeSliderWidth
        + WorkbenchControlMetrics.redesignSpacing1
        + volumeValueWidth
        + volumeTrailingPadding

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

    /// How long each line of the error banner stays: 5s. See
    /// `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing
    /// Database Records.md`.
    static let errorDuration: TimeInterval = 5
    /// --radius-player-error: 10px
    static let errorRadius: CGFloat = 10
    /// --font-size-player-error: 13px
    static let errorFontSize: CGFloat = 13
    /// --line-height-player-error: 20px
    static let errorLineHeight: CGFloat = 20
    /// --size-player-error-icon: 16px
    static let errorIconSize: CGFloat = 16
    /// --padding-player-error-x: 12px
    static let errorHorizontalPadding: CGFloat = 12
    /// --padding-player-error-y: 10px
    static let errorVerticalPadding: CGFloat = 10
    /// What the documented line height adds to the font's own line, set half
    /// above and half below each line as CSS line-height does.
    static let errorLeading: CGFloat = {
        let font = NSFont.systemFont(ofSize: errorFontSize, weight: .medium)
        return max(0, errorLineHeight - (font.ascender - font.descender + font.leading))
    }()

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
    /// --padding-player-chrome-x + --spacing-2: 32px
    static let progressRowHorizontalPadding: CGFloat =
        chromeHorizontalPadding + WorkbenchControlMetrics.redesignSpacing2
    static let chromeBottomPadding: CGFloat = 12
    static let progressTopPadding: CGFloat = 16
    static let progressTimeCapsuleHorizontalPadding: CGFloat = 8
    static let topbarHorizontalPadding: CGFloat = 16

    /// --spacing-1: 4px
    static let controlsGap = WorkbenchControlMetrics.redesignSpacing1
    /// --spacing-3: 12px
    static let progressTimeGap = WorkbenchControlMetrics.redesignSpacing3
    static let windowControlsGap: CGFloat = 8
    /// Provisional --gap-player-window-controls-return: after the window
    /// controls to the return button, pending the owner's value.
    static let windowControlsReturnGap = topbarHorizontalPadding
    static let speedMenuGap: CGFloat = 8

    /// Provisional --max-width-player-audio-track-menu: the widest the audio
    /// track submenus grow to; longer names wrap inside it.
    static let audioTrackMenuMaxWidth: CGFloat = 300

    static let timeFontSize: CGFloat = 12
    static let progressTimeFontSize: CGFloat = 10

    static let speedMenuOverlayTopPadding: CGFloat = 24
    static let hiddenOffsetPadding: CGFloat = 28
    static let progressTimeCapsuleMinWidth: CGFloat = 44
    /// --spacing-1: 4px
    static let progressTimeCapsuleGap = WorkbenchControlMetrics.redesignSpacing1
    static let progressTimeCapsuleYOffset: CGFloat = -(progressTimeCapsuleHeight + progressTimeCapsuleGap)
    static let windowControlBorderWidth: CGFloat = 0.5
    static let windowControlZoomGlyphSize: CGFloat = windowControlGlyphSize - 2

    private static let speedMenuContentHeight: CGFloat =
        CGFloat(7) * WorkbenchControlMetrics.redesignMenuItemHeight + MenuMetrics.padding * 2
    static let interactiveHeight: CGFloat = height + speedMenuContentHeight + speedMenuGap + speedMenuOverlayTopPadding
    static let hiddenOffset: CGFloat = interactiveHeight + hiddenOffsetPadding
    /// From the top of the 18px progress scrubber hit area down through the
    /// 44px controls row and 12px bottom padding (`74px`). The 16px
    /// `progressTopPadding` above it belongs to the playback stage tap area.
    static let bottomControlRegionHeight: CGFloat =
        progressHitAreaHeight + bottomControlsRowHeight + chromeBottomPadding

    /// The playback stage region where a single click toggles play/pause.
    /// When Player UI is visible, spans from the bottom of the 54px top bar
    /// to the top of the 18px progress scrubber hit area (`height - 74px`).
    /// When Player UI is hidden, spans the full window (`100% × 100%`).
    static func stageTapInteractiveRect(
        stageSize: CGSize,
        isPlayerUIVisible: Bool
    ) -> CGRect {
        let width = max(0, stageSize.width)
        let height = max(0, stageSize.height)
        guard isPlayerUIVisible else {
            return CGRect(x: 0, y: 0, width: width, height: height)
        }
        let topInset = WorkbenchControlMetrics.redesignAppTopbarHeight
        let bottomInset = bottomControlRegionHeight
        let interactiveStageHeight = max(0, height - topInset - bottomInset)
        return CGRect(
            x: 0,
            y: min(topInset, height),
            width: width,
            height: interactiveStageHeight
        )
    }

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
