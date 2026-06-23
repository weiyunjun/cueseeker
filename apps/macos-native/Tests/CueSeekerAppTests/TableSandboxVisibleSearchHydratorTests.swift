import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func tableSandboxVisibleSearchHydratorDefaultsToFiftyRowPages() async throws {
    let hydrator = TableSandboxVisibleSearchHydrator(
        overscanRows: 0,
        smallResultEagerLoadThreshold: 0
    )
    var loadedRanges: [String] = []

    hydrator.schedule(
        visibleRows: 60..<61,
        totalRowCount: 200,
        isRowLoaded: { _ in false },
        load: { range in
            loadedRanges.append(rangeDescription(range))
            return TableSandboxSearchHydrationPage(range: range, results: [], totalRowCount: 200)
        },
        apply: { _ in }
    )

    try await Task.sleep(nanoseconds: 60_000_000)

    #expect(loadedRanges == ["50..<100"])
}

@MainActor
@Test
func tableSandboxVisibleSearchHydratorSkipsAlreadyLoadedRows() async throws {
    let hydrator = TableSandboxVisibleSearchHydrator(
        overscanRows: 0,
        maxHydrationRows: 20,
        smallResultEagerLoadThreshold: 0
    )
    var loadCount = 0

    hydrator.schedule(
        visibleRows: 10..<20,
        totalRowCount: 100,
        isRowLoaded: { _ in true },
        load: { range in
            loadCount += 1
            return TableSandboxSearchHydrationPage(range: range, results: [], totalRowCount: 100)
        },
        apply: { _ in }
    )

    try await Task.sleep(nanoseconds: 20_000_000)

    #expect(loadCount == 0)
}

@MainActor
@Test
func tableSandboxVisibleSearchHydratorCancelsObsoleteViewportRequests() async throws {
    let hydrator = TableSandboxVisibleSearchHydrator(
        overscanRows: 0,
        maxHydrationRows: 20,
        smallResultEagerLoadThreshold: 0,
        maxBackgroundLoads: 1
    )
    var loadedRanges: [String] = []
    var appliedRanges: [String] = []
    let cancelledRanges = RangeRecorder()

    hydrator.schedule(
        visibleRows: 0..<10,
        totalRowCount: 200,
        isRowLoaded: { _ in false },
        load: { range in
            loadedRanges.append(rangeDescription(range))
            await withTaskCancellationHandler {
                try? await Task.sleep(nanoseconds: 100_000_000)
            } onCancel: {
                cancelledRanges.append(rangeDescription(range))
            }
            guard !Task.isCancelled else {
                return nil
            }
            return TableSandboxSearchHydrationPage(range: range, results: [], totalRowCount: 200)
        },
        apply: { page in
            appliedRanges.append(rangeDescription(page.range))
        }
    )
    try await Task.sleep(nanoseconds: 10_000_000)
    hydrator.schedule(
        visibleRows: 100..<110,
        totalRowCount: 200,
        isRowLoaded: { _ in false },
        load: { range in
            loadedRanges.append(rangeDescription(range))
            return TableSandboxSearchHydrationPage(range: range, results: [], totalRowCount: 200)
        },
        apply: { page in
            appliedRanges.append(rangeDescription(page.range))
        }
    )

    try await Task.sleep(nanoseconds: 140_000_000)

    #expect(Set(loadedRanges) == Set(["0..<20", "100..<120"]))
    #expect(Set(cancelledRanges.values) == Set(["0..<20"]))
    #expect(Set(appliedRanges) == Set(["100..<120"]))
}

@MainActor
@Test
func tableSandboxVisibleSearchHydratorDoesNotEagerlyCompleteSmallResultSets() async throws {
    let hydrator = TableSandboxVisibleSearchHydrator(
        overscanRows: 0,
        maxHydrationRows: 100,
        smallResultEagerLoadThreshold: 500,
        maxBackgroundLoads: 4
    )
    var loadedRows = Set(0..<100)
    var loadedRanges: [String] = []

    hydrator.scheduleInitialCompletion(
        totalRowCount: 290,
        isRowLoaded: { loadedRows.contains($0) },
        load: { range in
            loadedRanges.append(rangeDescription(range))
            loadedRows.formUnion(range)
            return TableSandboxSearchHydrationPage(range: range, results: [], totalRowCount: 290)
        },
        apply: { _ in }
    )

    try await Task.sleep(nanoseconds: 60_000_000)

    #expect(loadedRanges.isEmpty)
}

@MainActor
@Test
func tableSandboxVisibleSearchHydratorOnlyLoadsVisiblePages() async throws {
    let hydrator = TableSandboxVisibleSearchHydrator(
        overscanRows: 0,
        maxHydrationRows: 100,
        prefetchPageCount: 1,
        smallResultEagerLoadThreshold: 0,
        maxBackgroundLoads: 4
    )
    var loadedRanges: [String] = []

    hydrator.schedule(
        visibleRows: 100..<110,
        totalRowCount: 300,
        isRowLoaded: { _ in false },
        load: { range in
            loadedRanges.append(rangeDescription(range))
            return TableSandboxSearchHydrationPage(range: range, results: [], totalRowCount: 300)
        },
        apply: { _ in }
    )

    try await Task.sleep(nanoseconds: 60_000_000)

    #expect(Set(loadedRanges) == Set(["100..<200"]))
}

private func rangeDescription(_ range: Range<Int>) -> String {
    "\(range.lowerBound)..<\(range.upperBound)"
}

private final class RangeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: String) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}
