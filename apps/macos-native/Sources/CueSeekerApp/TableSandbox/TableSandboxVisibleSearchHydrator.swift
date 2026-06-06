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
    private enum HydrationPriority: Int {
        case viewport = 0
        case prefetch = 1
        case background = 2
    }

    private struct PendingRequest {
        let page: Int
        var priority: HydrationPriority
        var sequence: Int
    }

    private struct ActiveRequest {
        let priority: HydrationPriority
        let task: Task<Void, Never>
    }

    private let pageSize: Int
    private let prefetchPageCount: Int
    private let smallResultEagerLoadThreshold: Int
    private let maxBackgroundLoads: Int
    private var pendingRequests: [Int: PendingRequest] = [:]
    private var inFlightRequests: [Int: ActiveRequest] = [:]
    private var isRowLoaded: ((Int) -> Bool)?
    private var load: ((Range<Int>) async -> TableSandboxSearchHydrationPage?)?
    private var apply: ((TableSandboxSearchHydrationPage) -> Void)?
    private var generation = 0
    private var sequence = 0

    init(
        debounceNanoseconds: UInt64 = 0,
        overscanRows: Int = 80,
        maxHydrationRows: Int = 240,
        pageSize: Int? = nil,
        prefetchPageCount: Int? = nil,
        smallResultEagerLoadThreshold: Int = 2_000,
        maxBackgroundLoads: Int = 2
    ) {
        _ = debounceNanoseconds
        let resolvedPageSize = max(1, pageSize ?? maxHydrationRows)
        self.pageSize = resolvedPageSize
        self.prefetchPageCount = max(0, prefetchPageCount ?? Int(ceil(Double(overscanRows) / Double(resolvedPageSize))))
        self.smallResultEagerLoadThreshold = max(0, smallResultEagerLoadThreshold)
        self.maxBackgroundLoads = max(1, maxBackgroundLoads)
    }

    func cancel() {
        reset()
    }

    func reset() {
        generation += 1
        pendingRequests.removeAll()
        inFlightRequests.values.forEach { $0.task.cancel() }
        inFlightRequests.removeAll()
    }

    func schedule(
        visibleRows: Range<Int>,
        totalRowCount: Int,
        isRowLoaded: @escaping (Int) -> Bool,
        load: @escaping (Range<Int>) async -> TableSandboxSearchHydrationPage?,
        apply: @escaping (TableSandboxSearchHydrationPage) -> Void
    ) {
        configure(isRowLoaded: isRowLoaded, load: load, apply: apply)
        guard totalRowCount > 0, visibleRows.lowerBound < visibleRows.upperBound else {
            return
        }

        let clampedVisibleRows = clamp(visibleRows, totalRowCount: totalRowCount)
        guard clampedVisibleRows.lowerBound < clampedVisibleRows.upperBound else {
            return
        }

        enqueuePages(overlapping: clampedVisibleRows, totalRowCount: totalRowCount, priority: .viewport)
        enqueuePrefetchPages(around: clampedVisibleRows, totalRowCount: totalRowCount)
        enqueueSmallResultCompletion(totalRowCount: totalRowCount)
        drainBackgroundQueue(totalRowCount: totalRowCount)
    }

    func scheduleInitialCompletion(
        totalRowCount: Int,
        isRowLoaded: @escaping (Int) -> Bool,
        load: @escaping (Range<Int>) async -> TableSandboxSearchHydrationPage?,
        apply: @escaping (TableSandboxSearchHydrationPage) -> Void
    ) {
        configure(isRowLoaded: isRowLoaded, load: load, apply: apply)
        enqueueSmallResultCompletion(totalRowCount: totalRowCount)
        drainBackgroundQueue(totalRowCount: totalRowCount)
    }

    private func configure(
        isRowLoaded: @escaping (Int) -> Bool,
        load: @escaping (Range<Int>) async -> TableSandboxSearchHydrationPage?,
        apply: @escaping (TableSandboxSearchHydrationPage) -> Void
    ) {
        self.isRowLoaded = isRowLoaded
        self.load = load
        self.apply = apply
    }

    private func enqueuePages(
        overlapping rows: Range<Int>,
        totalRowCount: Int,
        priority: HydrationPriority
    ) {
        guard let pages = pageIndexes(overlapping: rows, totalRowCount: totalRowCount) else {
            return
        }
        for page in pages {
            enqueuePage(page, totalRowCount: totalRowCount, priority: priority)
        }
    }

    private func enqueuePrefetchPages(around visibleRows: Range<Int>, totalRowCount: Int) {
        guard prefetchPageCount > 0,
              let visiblePages = pageIndexes(overlapping: visibleRows, totalRowCount: totalRowCount)
        else {
            return
        }
        let lastPage = pageIndex(for: totalRowCount - 1)
        for distance in 1...prefetchPageCount {
            let before = visiblePages.lowerBound - distance
            if before >= 0 {
                enqueuePage(before, totalRowCount: totalRowCount, priority: .prefetch)
            }
            let after = visiblePages.upperBound + distance
            if after <= lastPage {
                enqueuePage(after, totalRowCount: totalRowCount, priority: .prefetch)
            }
        }
    }

    private func enqueueSmallResultCompletion(totalRowCount: Int) {
        guard totalRowCount > 0, totalRowCount <= smallResultEagerLoadThreshold else {
            return
        }
        let lastPage = pageIndex(for: totalRowCount - 1)
        for page in 0...lastPage {
            enqueuePage(page, totalRowCount: totalRowCount, priority: .background)
        }
    }

    private func enqueuePage(_ page: Int, totalRowCount: Int, priority: HydrationPriority) {
        guard inFlightRequests[page] == nil,
              missingRange(forPage: page, totalRowCount: totalRowCount) != nil
        else {
            return
        }

        if priority == .viewport {
            pendingRequests.removeValue(forKey: page)
            startPage(page, totalRowCount: totalRowCount, priority: priority)
            return
        }

        sequence += 1
        if let existing = pendingRequests[page] {
            let bestPriority = existing.priority.rawValue <= priority.rawValue ? existing.priority : priority
            pendingRequests[page] = PendingRequest(
                page: page,
                priority: bestPriority,
                sequence: existing.sequence
            )
        } else {
            pendingRequests[page] = PendingRequest(page: page, priority: priority, sequence: sequence)
        }
    }

    private func drainBackgroundQueue(totalRowCount: Int) {
        guard load != nil, apply != nil else { return }

        while backgroundInFlightCount < maxBackgroundLoads {
            guard let request = pendingRequests.values.sorted(by: pendingRequestSort).first else {
                return
            }
            pendingRequests.removeValue(forKey: request.page)
            guard missingRange(forPage: request.page, totalRowCount: totalRowCount) != nil else {
                continue
            }
            startPage(request.page, totalRowCount: totalRowCount, priority: request.priority)
        }
    }

    private func startPage(_ page: Int, totalRowCount: Int, priority: HydrationPriority) {
        guard inFlightRequests[page] == nil,
              let range = missingRange(forPage: page, totalRowCount: totalRowCount),
              let load,
              let apply
        else {
            return
        }

        let requestGeneration = generation
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.completePage(page, generation: requestGeneration, totalRowCount: totalRowCount)
            }
            guard !Task.isCancelled,
                  let pageResult = await load(range),
                  !Task.isCancelled,
                  self.generation == requestGeneration
            else {
                return
            }
            apply(pageResult)
        }
        inFlightRequests[page] = ActiveRequest(priority: priority, task: task)
    }

    private func completePage(_ page: Int, generation requestGeneration: Int, totalRowCount: Int) {
        guard generation == requestGeneration else {
            return
        }
        inFlightRequests.removeValue(forKey: page)
        drainBackgroundQueue(totalRowCount: totalRowCount)
    }

    private var backgroundInFlightCount: Int {
        inFlightRequests.values.filter { $0.priority != .viewport }.count
    }

    private func pendingRequestSort(_ lhs: PendingRequest, _ rhs: PendingRequest) -> Bool {
        if lhs.priority.rawValue != rhs.priority.rawValue {
            return lhs.priority.rawValue < rhs.priority.rawValue
        }
        return lhs.sequence < rhs.sequence
    }

    private func missingRange(forPage page: Int, totalRowCount: Int) -> Range<Int>? {
        guard let isRowLoaded else { return nil }
        let range = pageRange(page, totalRowCount: totalRowCount)
        guard range.lowerBound < range.upperBound else { return nil }

        var firstMissing: Int?
        var lastMissing: Int?
        for index in range where !isRowLoaded(index) {
            firstMissing = min(firstMissing ?? index, index)
            lastMissing = max(lastMissing ?? index, index)
        }
        guard let firstMissing, let lastMissing else {
            return nil
        }
        return firstMissing..<(lastMissing + 1)
    }

    private func pageIndexes(overlapping rows: Range<Int>, totalRowCount: Int) -> ClosedRange<Int>? {
        guard totalRowCount > 0 else { return nil }
        let clamped = clamp(rows, totalRowCount: totalRowCount)
        guard clamped.lowerBound < clamped.upperBound else { return nil }
        return pageIndex(for: clamped.lowerBound)...pageIndex(for: clamped.upperBound - 1)
    }

    private func pageRange(_ page: Int, totalRowCount: Int) -> Range<Int> {
        let lowerBound = max(0, page * pageSize)
        let upperBound = min(totalRowCount, lowerBound + pageSize)
        return lowerBound..<upperBound
    }

    private func pageIndex(for row: Int) -> Int {
        max(0, row / pageSize)
    }

    private func clamp(_ rows: Range<Int>, totalRowCount: Int) -> Range<Int> {
        let lowerBound = min(max(0, rows.lowerBound), totalRowCount)
        let upperBound = min(max(lowerBound, rows.upperBound), totalRowCount)
        return lowerBound..<upperBound
    }
}
