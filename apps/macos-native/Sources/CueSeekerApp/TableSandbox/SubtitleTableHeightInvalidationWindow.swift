import Foundation

struct SubtitleTableHeightInvalidationWindow: Equatable {
    let range: Range<Int>
    let visibleCount: Int

    var invalidatedCount: Int {
        range.count
    }

    var indexSet: IndexSet {
        IndexSet(integersIn: range)
    }

    static func make(visibleRows: NSRange, rowCount: Int, overscan: Int) -> SubtitleTableHeightInvalidationWindow? {
        guard rowCount > 0, visibleRows.location != NSNotFound, visibleRows.length > 0 else {
            return nil
        }

        let visibleLowerBound = min(max(0, visibleRows.location), rowCount)
        let visibleUpperBound = min(max(visibleLowerBound, visibleRows.location + visibleRows.length), rowCount)
        guard visibleLowerBound < visibleUpperBound else {
            return nil
        }

        let safeOverscan = max(0, overscan)
        let lowerBound = max(0, visibleLowerBound - safeOverscan)
        let upperBound = min(rowCount, visibleUpperBound + safeOverscan)

        return SubtitleTableHeightInvalidationWindow(
            range: lowerBound..<upperBound,
            visibleCount: visibleUpperBound - visibleLowerBound
        )
    }
}
