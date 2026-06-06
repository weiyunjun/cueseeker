import Foundation
import Combine
import CueSeekerCore

struct TableSandboxSearchHydrationPage: Equatable {
    let range: Range<Int>
    let results: [SubtitleSearchResult]
    let totalRowCount: Int
}

@MainActor
final class TableSandboxVisibleSearchHydrator: ObservableObject {
    private let debounceNanoseconds: UInt64
    private let overscanRows: Int
    private let maxHydrationRows: Int
    private var task: Task<Void, Never>?
    private var generation = 0

    init(
        debounceNanoseconds: UInt64 = 80_000_000,
        overscanRows: Int = 80,
        maxHydrationRows: Int = 240
    ) {
        self.debounceNanoseconds = debounceNanoseconds
        self.overscanRows = overscanRows
        self.maxHydrationRows = maxHydrationRows
    }

    deinit {
        task?.cancel()
    }

    func cancel() {
        task?.cancel()
        task = nil
        generation += 1
    }

    func schedule(
        visibleRows: Range<Int>,
        totalRowCount: Int,
        isRowLoaded: (Int) -> Bool,
        load: @escaping (Range<Int>) async -> TableSandboxSearchHydrationPage?,
        apply: @escaping (TableSandboxSearchHydrationPage) -> Void
    ) {
        guard let loadRange = missingLoadRange(
            visibleRows: visibleRows,
            totalRowCount: totalRowCount,
            isRowLoaded: isRowLoaded
        ) else {
            return
        }

        generation += 1
        let scheduledGeneration = generation
        task?.cancel()
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            guard let page = await load(loadRange) else { return }
            guard !Task.isCancelled, generation == scheduledGeneration else { return }
            apply(page)
        }
    }

    private func missingLoadRange(
        visibleRows: Range<Int>,
        totalRowCount: Int,
        isRowLoaded: (Int) -> Bool
    ) -> Range<Int>? {
        guard totalRowCount > 0, visibleRows.lowerBound < visibleRows.upperBound else {
            return nil
        }

        let lowerBound = max(0, visibleRows.lowerBound - overscanRows)
        let upperBound = min(totalRowCount, visibleRows.upperBound + overscanRows)
        guard lowerBound < upperBound else { return nil }

        let expandedRange = limitedRange(lowerBound..<upperBound, around: visibleRows)
        var firstMissing: Int?
        var lastMissing: Int?
        for index in expandedRange where !isRowLoaded(index) {
            firstMissing = min(firstMissing ?? index, index)
            lastMissing = max(lastMissing ?? index, index)
        }

        guard let firstMissing, let lastMissing else {
            return nil
        }
        return firstMissing..<(lastMissing + 1)
    }

    private func limitedRange(_ range: Range<Int>, around visibleRows: Range<Int>) -> Range<Int> {
        guard range.count > maxHydrationRows else { return range }
        let visibleCenter = visibleRows.lowerBound + max(0, visibleRows.count / 2)
        let lowerBound = max(range.lowerBound, visibleCenter - maxHydrationRows / 2)
        let upperBound = min(range.upperBound, lowerBound + maxHydrationRows)
        return lowerBound..<upperBound
    }
}
