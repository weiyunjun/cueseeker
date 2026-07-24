import Foundation

public enum SRTASSConverter {
    public static func convert(_ contents: String) -> String {
        let dialogues = SRTParser.parseForRendering(contents).map { entry in
            let start = assTimecode(
                milliseconds: entry.startMilliseconds,
                roundsUp: false
            )
            let end = assTimecode(
                milliseconds: entry.endMilliseconds,
                roundsUp: true
            )
            return "Dialogue: 0,\(start),\(end),Default,,25,25,22,,\(assText(entry.text))"
        }

        return """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 1920
        PlayResY: 1080
        WrapStyle: 0
        ScaledBorderAndShadow: yes

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,sans-serif,55,&H00FFFFFF,&H00FFFFFF,&H00000000,&HFF000000,0,0,0,0,100,100,0,0,1,3,0,2,25,25,22,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        \(dialogues.joined(separator: "\n"))
        """
    }

    private static func assTimecode(
        milliseconds: Int,
        roundsUp: Bool
    ) -> String {
        let milliseconds = max(0, milliseconds)
        let centiseconds = (milliseconds + (roundsUp ? 9 : 0)) / 10
        let hours = centiseconds / 360_000
        let minutes = (centiseconds / 6_000) % 60
        let seconds = (centiseconds / 100) % 60
        let fraction = centiseconds % 100
        return String(
            format: "%d:%02d:%02d.%02d",
            hours,
            minutes,
            seconds,
            fraction
        )
    }

    private static func assText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "\r\n", with: "\\N")
            .replacingOccurrences(of: "\r", with: "\\N")
            .replacingOccurrences(of: "\n", with: "\\N")
    }
}
