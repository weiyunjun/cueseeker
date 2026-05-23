import SwiftUI

/// Defines the global cinematic theme parameters and styles for CueSeeker playback interface.
/// Discards standard system light/dark color scheme variation in favor of a cohesive, high-contrast dark theater environment.
public enum PlaybackTheme {

    // MARK: - Core Backings & Backgrounds

    /// Premium cinematic semi-translucent pure black surface backing.
    public static var cinematicBacking: Color {
        Color.black.opacity(0.55)
    }

    /// Dark translucent capsule fill for buttons and time display labels.
    public static var capsuleFill: Color {
        Color.black.opacity(0.30)
    }

    /// Dark translucent capsule fill when hovered.
    public static var capsuleHoverFill: Color {
        Color.white.opacity(0.16)
    }

    /// Unified background highlight for selected and hovered menu items.
    public static var menuItemHighlight: Color {
        Color.white.opacity(0.12)
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
        Color.white.opacity(0.35)
    }

    /// Background track color for the scrubber timeline.
    public static var scrubberTrackBackground: Color {
        Color.black.opacity(0.60)
    }
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
                .fill(PlaybackTheme.capsuleFill)

            // Concentric inner hover highlight
            if isHovered || isPressed {
                shape
                    .fill(PlaybackTheme.capsuleHoverFill)
                    .scaleEffect(x: scaleX, y: scaleY)
            }
        }
    }
}
