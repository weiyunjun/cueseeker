import Foundation

public struct PlaybackSubtitleCue: Equatable, Sendable {
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let text: String

    public init(startMilliseconds: Int, endMilliseconds: Int, text: String) {
        self.startMilliseconds = max(0, startMilliseconds)
        self.endMilliseconds = max(self.startMilliseconds, endMilliseconds)
        self.text = text
    }

    public func isActive(atMilliseconds milliseconds: Int) -> Bool {
        milliseconds >= startMilliseconds && milliseconds < endMilliseconds
    }
}

public struct PlaybackSubtitleTrack: Equatable, Sendable {
    public static let empty = PlaybackSubtitleTrack(cues: [])

    public let cues: [PlaybackSubtitleCue]

    public init(cues: [PlaybackSubtitleCue]) {
        self.cues = cues
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.startMilliseconds == $1.startMilliseconds {
                    return $0.endMilliseconds < $1.endMilliseconds
                }

                return $0.startMilliseconds < $1.startMilliseconds
            }
    }

    public func activeText(at seconds: Double) -> String? {
        guard seconds.isFinite else {
            return nil
        }

        let milliseconds = max(0, Int((seconds * 1_000).rounded(.down)))
        let activeTexts = cues
            .filter { $0.isActive(atMilliseconds: milliseconds) }
            .map(\.text)

        guard !activeTexts.isEmpty else {
            return nil
        }

        return activeTexts.joined(separator: "\n")
    }
}
