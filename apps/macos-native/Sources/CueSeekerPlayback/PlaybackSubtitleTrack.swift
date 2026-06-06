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
    private let cueStartMilliseconds: [Int]
    private let prefixMaximumEndMilliseconds: [Int]

    public init(cues: [PlaybackSubtitleCue]) {
        let sortedCues = cues
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.startMilliseconds == $1.startMilliseconds {
                    return $0.endMilliseconds < $1.endMilliseconds
                }

                return $0.startMilliseconds < $1.startMilliseconds
            }
        self.cues = sortedCues
        cueStartMilliseconds = sortedCues.map(\.startMilliseconds)

        var maximumEndMilliseconds = 0
        prefixMaximumEndMilliseconds = sortedCues.map { cue in
            maximumEndMilliseconds = max(maximumEndMilliseconds, cue.endMilliseconds)
            return maximumEndMilliseconds
        }
    }

    public func activeText(at seconds: Double) -> String? {
        guard seconds.isFinite else {
            return nil
        }

        let milliseconds = max(0, Int((seconds * 1_000).rounded(.down)))
        var activeTexts: [String] = []
        var index = upperBoundStartMilliseconds(milliseconds) - 1
        while index >= 0, prefixMaximumEndMilliseconds[index] > milliseconds {
            let cue = cues[index]
            if cue.isActive(atMilliseconds: milliseconds) {
                activeTexts.append(cue.text)
            }
            index -= 1
        }

        guard !activeTexts.isEmpty else {
            return nil
        }

        return activeTexts.reversed().joined(separator: "\n")
    }

    private func upperBoundStartMilliseconds(_ milliseconds: Int) -> Int {
        var lowerBound = 0
        var upperBound = cueStartMilliseconds.count
        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            if cueStartMilliseconds[midpoint] <= milliseconds {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }
        return lowerBound
    }
}
