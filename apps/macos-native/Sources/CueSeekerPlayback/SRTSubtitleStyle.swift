import Foundation

/// How SRT subtitles look and where they sit. Lengths are pixels of a
/// 1080-high picture and scale with the picture's height; ASS subtitles never
/// read it. See `docs/human/requirements/20261016-UI-Subtitle Settings
/// Simplification And Controls Refinement.md`.
public struct SRTSubtitleStyle: Codable, Equatable, Sendable {
    public enum BorderType: String, Codable, CaseIterable, Sendable {
        /// Outlined text with a shadow.
        case outline
        /// A background box behind the cue; its shadow is the box's.
        case backgroundBox

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            switch rawValue {
            case Self.outline.rawValue:
                self = .outline
            case Self.backgroundBox.rawValue, "opaqueBox":
                self = .backgroundBox
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot initialize BorderType from invalid String value \(rawValue)"
                )
            }
        }
    }

    public enum HorizontalAlignment: String, Codable, CaseIterable, Sendable {
        case left
        case center
        case right
    }

    public enum VerticalAlignment: String, Codable, CaseIterable, Sendable {
        case top
        case center
        case bottom
    }

    /// An sRGB color with its opacity, each component in 0...1.
    public struct Color: Codable, Equatable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public var alpha: Double

        public init(red: Double, green: Double, blue: Double, alpha: Double) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

    public static let referenceHeight: Double = 1080
    /// The gap between the text and a Background Box.
    public static let boxPadding: Double = 4
    public static let minimumSize: Double = 1

    /// The chosen font's PostScript name; nil is the system font.
    public var fontName: String?
    /// The font point size at 1080p reference height.
    public var size: Double = 28
    public var isBold = false
    public var isItalic = false
    public var textColor = Color(red: 1, green: 1, blue: 1, alpha: 1)
    public var letterSpacing: Double = 0
    /// Added to the font's own line height between the lines of one cue.
    public var lineSpacing: Double = 6
    public var borderType = BorderType.outline
    public var outlineColor = Color(red: 0, green: 0, blue: 0, alpha: 1)
    public var outlineWidth: Double = 2
    public var backgroundColor = Color(red: 0, green: 0, blue: 0, alpha: 0.5)
    public var blur: Double = 0
    public var shadowColor = Color(red: 0, green: 0, blue: 0, alpha: 0.5)
    public var shadowOffset: Double = 0
    public var horizontalAlignment = HorizontalAlignment.center
    public var marginX: Double = 25
    public var verticalAlignment = VerticalAlignment.bottom
    public var marginY: Double = 22

    public init() {}
}
