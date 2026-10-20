import Foundation

struct StoredCueIdentity: Equatable, Sendable {
    let cueID: Int64
    let sourceFormat: SubtitleFormat
    let sourceStyle: String?
    let sourceIdentityRemainder: String
    let startMilliseconds: Int
    let endMilliseconds: Int
    let content: String
}

struct CueIdentityAssignment: Equatable, Sendable {
    let cueID: Int64
    let previousContent: String
}

enum CueIdentityReconciler {
    static func reconcile(
        storedCues: [StoredCueIdentity],
        newCues: [SubtitleCueLine]
    ) -> [Int: CueIdentityAssignment] {
        var assignments: [Int: CueIdentityAssignment] = [:]
        var remainingStored = Set(storedCues.indices)
        var remainingNew = Set(newCues.indices)

        let storedByExactKey = Dictionary(
            grouping: storedCues.indices,
            by: { ExactKey(storedCues[$0]) }
        )
        let newByExactKey = Dictionary(
            grouping: newCues.indices,
            by: { ExactKey(newCues[$0]) }
        )

        for key in Set(storedByExactKey.keys).intersection(newByExactKey.keys) {
            guard let storedIndices = storedByExactKey[key],
                  let newIndices = newByExactKey[key],
                  storedIndices.count == 1,
                  newIndices.count == 1,
                  let storedIndex = storedIndices.first,
                  let newIndex = newIndices.first
            else {
                continue
            }
            assignments[newIndex] = assignment(for: storedCues[storedIndex])
            remainingStored.remove(storedIndex)
            remainingNew.remove(newIndex)
        }

        var storedCandidatesByNew: [Int: [Int]] = [:]
        var newCandidatesByStored: [Int: [Int]] = [:]
        for newIndex in remainingNew {
            for storedIndex in remainingStored where isLocalEdit(
                from: storedCues[storedIndex],
                to: newCues[newIndex]
            ) {
                storedCandidatesByNew[newIndex, default: []].append(storedIndex)
                newCandidatesByStored[storedIndex, default: []].append(newIndex)
            }
        }

        for newIndex in remainingNew {
            guard let storedCandidates = storedCandidatesByNew[newIndex],
                  storedCandidates.count == 1,
                  let storedIndex = storedCandidates.first,
                  newCandidatesByStored[storedIndex]?.count == 1
            else {
                continue
            }
            assignments[newIndex] = assignment(for: storedCues[storedIndex])
        }

        return assignments
    }

    private static func assignment(for cue: StoredCueIdentity) -> CueIdentityAssignment {
        CueIdentityAssignment(cueID: cue.cueID, previousContent: cue.content)
    }

    private static func isLocalEdit(
        from stored: StoredCueIdentity,
        to newCue: SubtitleCueLine
    ) -> Bool {
        guard stored.sourceFormat == newCue.sourceFormat else {
            return false
        }

        let timestampChanged = stored.startMilliseconds != newCue.startMilliseconds
            || stored.endMilliseconds != newCue.endMilliseconds
        let contentChanged = stored.content != newCue.content

        switch stored.sourceFormat {
        case .srt, .vtt:
            return [timestampChanged, contentChanged].filter(\.self).count == 1
        case .ass:
            guard stored.sourceStyle == newCue.sourceStyle else {
                return false
            }
            let remainderChanged =
                stored.sourceIdentityRemainder != newCue.sourceIdentityRemainder
            return [timestampChanged, contentChanged, remainderChanged]
                .filter(\.self)
                .count == 1
        }
    }

    private struct ExactKey: Hashable {
        let sourceFormat: SubtitleFormat
        let sourceStyle: String?
        let sourceIdentityRemainder: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let content: String

        init(_ cue: StoredCueIdentity) {
            sourceFormat = cue.sourceFormat
            sourceStyle = cue.sourceStyle
            sourceIdentityRemainder = cue.sourceIdentityRemainder
            startMilliseconds = cue.startMilliseconds
            endMilliseconds = cue.endMilliseconds
            content = cue.content
        }

        init(_ cue: SubtitleCueLine) {
            sourceFormat = cue.sourceFormat
            sourceStyle = cue.sourceStyle
            sourceIdentityRemainder = cue.sourceIdentityRemainder
            startMilliseconds = cue.startMilliseconds
            endMilliseconds = cue.endMilliseconds
            content = cue.content
        }
    }
}
