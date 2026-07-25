import Foundation

public struct PlaybackSubtitleCue: Equatable, Sendable {
    public let sourceOrdinal: Int
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let text: String

    public init(
        sourceOrdinal: Int = 0,
        startMilliseconds: Int,
        endMilliseconds: Int,
        text: String
    ) {
        self.sourceOrdinal = max(0, sourceOrdinal)
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
    private let intervalTreeLeafCount: Int
    private let intervalTreeMaximumEndMilliseconds: [Int]

    public init(cues: [PlaybackSubtitleCue]) {
        let sortedCues = cues
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.startMilliseconds == $1.startMilliseconds {
                    return $0.sourceOrdinal < $1.sourceOrdinal
                }

                return $0.startMilliseconds < $1.startMilliseconds
        }
        self.cues = sortedCues
        cueStartMilliseconds = sortedCues.map(\.startMilliseconds)

        var leafCount = 1
        while leafCount < sortedCues.count {
            leafCount *= 2
        }
        intervalTreeLeafCount = leafCount
        var intervalTree = Array(repeating: Int.min, count: 2 * leafCount)
        for (index, cue) in sortedCues.enumerated() {
            intervalTree[leafCount + index] = cue.endMilliseconds
        }
        if leafCount > 1 {
            for index in stride(from: leafCount - 1, through: 1, by: -1) {
                intervalTree[index] = max(
                    intervalTree[2 * index],
                    intervalTree[(2 * index) + 1]
                )
            }
        }
        intervalTreeMaximumEndMilliseconds = intervalTree
    }

    public func activeText(at seconds: Double) -> String? {
        guard seconds.isFinite else {
            return nil
        }

        let milliseconds = max(0, Int((seconds * 1_000).rounded(.down)))
        let activeTexts = activeCues(atMilliseconds: milliseconds).map(\.text)
        return activeTexts.isEmpty ? nil : activeTexts.joined(separator: "\n")
    }

    public func activeCues(atMilliseconds milliseconds: Int) -> [PlaybackSubtitleCue] {
        let milliseconds = max(0, milliseconds)
        let upperBound = upperBoundStartMilliseconds(milliseconds)
        guard upperBound > 0 else { return [] }
        var activeCues: [PlaybackSubtitleCue] = []
        appendActiveCues(
            node: 1,
            lowerBound: 0,
            upperBound: intervalTreeLeafCount,
            queryUpperBound: upperBound,
            milliseconds: milliseconds,
            result: &activeCues
        )
        return activeCues
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

    private func appendActiveCues(
        node: Int,
        lowerBound: Int,
        upperBound: Int,
        queryUpperBound: Int,
        milliseconds: Int,
        result: inout [PlaybackSubtitleCue]
    ) {
        guard lowerBound < queryUpperBound,
              intervalTreeMaximumEndMilliseconds[node] > milliseconds
        else {
            return
        }
        if upperBound - lowerBound == 1 {
            guard lowerBound < cues.count else { return }
            let cue = cues[lowerBound]
            if cue.isActive(atMilliseconds: milliseconds) {
                result.append(cue)
            }
            return
        }

        let midpoint = lowerBound + ((upperBound - lowerBound) / 2)
        appendActiveCues(
            node: 2 * node,
            lowerBound: lowerBound,
            upperBound: midpoint,
            queryUpperBound: queryUpperBound,
            milliseconds: milliseconds,
            result: &result
        )
        appendActiveCues(
            node: (2 * node) + 1,
            lowerBound: midpoint,
            upperBound: upperBound,
            queryUpperBound: queryUpperBound,
            milliseconds: milliseconds,
            result: &result
        )
    }
}
