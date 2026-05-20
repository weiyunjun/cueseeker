public struct SubtitleActiveEntryLookup: Sendable {
    private struct Record: Sendable {
        let id: Int64
        let startMilliseconds: Int
        let endMilliseconds: Int
        let prefixMaxEndMilliseconds: Int
    }

    private let records: [Record]

    public init(entries: [SubtitleDatabaseEntry] = []) {
        var maxEndMilliseconds = Int.min
        records = entries
            .sorted { lhs, rhs in
                if lhs.startMilliseconds == rhs.startMilliseconds {
                    lhs.id < rhs.id
                } else {
                    lhs.startMilliseconds < rhs.startMilliseconds
                }
            }
            .map { entry in
                maxEndMilliseconds = max(maxEndMilliseconds, entry.endMilliseconds)
                return Record(
                    id: entry.id,
                    startMilliseconds: entry.startMilliseconds,
                    endMilliseconds: entry.endMilliseconds,
                    prefixMaxEndMilliseconds: maxEndMilliseconds
                )
            }
    }

    public func activeEntryID(atMilliseconds milliseconds: Int) -> Int64? {
        guard let candidateIndex = lastStartedIndex(atMilliseconds: milliseconds) else {
            return nil
        }

        if let activeIndex = earliestActiveIndex(upTo: candidateIndex, atMilliseconds: milliseconds) {
            return records[activeIndex].id
        }

        return records[candidateIndex].id
    }

    private func lastStartedIndex(atMilliseconds milliseconds: Int) -> Int? {
        var low = 0
        var high = records.count - 1
        var result: Int?

        while low <= high {
            let mid = low + (high - low) / 2
            if records[mid].startMilliseconds <= milliseconds {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }

    private func earliestActiveIndex(upTo candidateIndex: Int, atMilliseconds milliseconds: Int) -> Int? {
        var low = 0
        var high = candidateIndex
        var result: Int?

        while low <= high {
            let mid = low + (high - low) / 2
            if records[mid].prefixMaxEndMilliseconds > milliseconds {
                result = mid
                high = mid - 1
            } else {
                low = mid + 1
            }
        }

        return result
    }
}
