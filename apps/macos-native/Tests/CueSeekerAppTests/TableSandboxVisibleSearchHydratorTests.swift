import Testing
@testable import CueSeekerApp

@MainActor
@Test
func tableSandboxVisibleSearchHydratorSkipsAlreadyLoadedRows() async throws {
    let hydrator = TableSandboxVisibleSearchHydrator(
        debounceNanoseconds: 0,
        overscanRows: 0,
        maxHydrationRows: 20
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
func tableSandboxVisibleSearchHydratorCancelsStaleRequests() async throws {
    let hydrator = TableSandboxVisibleSearchHydrator(
        debounceNanoseconds: 20_000_000,
        overscanRows: 0,
        maxHydrationRows: 20
    )
    var appliedRanges: [String] = []

    hydrator.schedule(
        visibleRows: 0..<10,
        totalRowCount: 200,
        isRowLoaded: { _ in false },
        load: { range in
            TableSandboxSearchHydrationPage(range: range, results: [], totalRowCount: 200)
        },
        apply: { page in
            appliedRanges.append("\(page.range.lowerBound)..<\(page.range.upperBound)")
        }
    )
    hydrator.schedule(
        visibleRows: 100..<110,
        totalRowCount: 200,
        isRowLoaded: { _ in false },
        load: { range in
            TableSandboxSearchHydrationPage(range: range, results: [], totalRowCount: 200)
        },
        apply: { page in
            appliedRanges.append("\(page.range.lowerBound)..<\(page.range.upperBound)")
        }
    )

    try await Task.sleep(nanoseconds: 80_000_000)

    #expect(appliedRanges == ["100..<110"])
}
