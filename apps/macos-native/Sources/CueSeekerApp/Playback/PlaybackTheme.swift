import SwiftUI

/// Defines the global cinematic theme parameters and styles for CueSeeker playback interface.
/// Discards standard system light/dark color scheme variation in favor of a cohesive, high-contrast dark theater environment.
public enum PlaybackTheme {

    // MARK: - Core Backings & Backgrounds

    /// Premium cinematic semi-translucent pure black surface backing.
    public static var cinematicBacking: Color {
        Color.black.opacity(0.82)
    }

    /// Dark translucent capsule fill for buttons and time display labels.
    public static var capsuleFill: Color {
        Color.white.opacity(0.08)
    }

    /// Dark translucent capsule fill when hovered.
    public static var capsuleHoverFill: Color {
        Color.white.opacity(0.16)
    }

    // MARK: - Foreground Colors (Typography & Glyphs)

    /// Pure white with high contrast for primary texts, active labels, and active buttons.
    public static var textPrimary: Color {
        Color.white.opacity(0.94)
    }

    /// Pure white with medium contrast for metadata, secondary indicators, and secondary metrics.
    public static var textSecondary: Color {
        Color.white.opacity(0.62)
    }

    /// Pure white with low contrast for disabled buttons, secondary timestamps, and borders.
    public static var textTertiary: Color {
        Color.white.opacity(0.34)
    }

    // MARK: - Scrubber & Progress Bar

    /// YouTube-style signature red for active playback progress track.
    public static var progressRed: Color {
        Color.red
    }

    /// Semi-translucent gray for timeline hovered track extension.
    public static var scrubberHoverTrack: Color {
        Color.white.opacity(0.26)
    }

    /// Background track color for the scrubber timeline.
    public static var scrubberTrackBackground: Color {
        Color.white.opacity(0.16)
    }
}
