import Foundation
import os
import CueSeekerCore

struct SearchCursorLogSnapshot: Sendable {
    let offset: Int

    init(_ cursor: SubtitleSearchCursor) {
        offset = cursor.offset
    }
}

struct SearchPerformanceRun: Sendable {
    let id: UInt64
    let startedAt: UInt64
    let query: String
    let queryLength: Int
    let offset: Int
    let cursor: SearchCursorLogSnapshot
    let limit: Int
    let appending: Bool
    let debounce: Bool
    let folderCount: Int
    let folderPaths: [String]
}

private final class SearchPerformanceLoggerState: @unchecked Sendable {
    private let lock = NSLock()
    private var nextRunID: UInt64 = 1

    func allocateRunID() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        let id = nextRunID
        nextRunID += 1
        return id
    }
}

enum SearchPerformanceLogger {
    private static let state = SearchPerformanceLoggerState()
    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "Search")

    static let isEnabled = diagnosticFlag("CUESEEKER_PERF_SEARCH")
        || diagnosticFlag("CUESEEKER_PERF_UI")
        || diagnosticFlag("CUESEEKER_PERF")

    static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    static func elapsedMilliseconds(since start: UInt64) -> Double {
        milliseconds(between: start, and: now())
    }

    static func startRun(
        query: String,
        queryLength: Int,
        offset: Int,
        cursor: SubtitleSearchCursor? = nil,
        limit: Int,
        appending: Bool,
        debounce: Bool,
        folderPaths: [String]
    ) -> SearchPerformanceRun? {
        let resolvedCursor = cursor ?? SubtitleSearchCursor(offset: offset)
        let run = SearchPerformanceRun(
            id: state.allocateRunID(),
            startedAt: now(),
            query: query,
            queryLength: queryLength,
            offset: offset,
            cursor: SearchCursorLogSnapshot(resolvedCursor),
            limit: limit,
            appending: appending,
            debounce: debounce,
            folderCount: folderPaths.count,
            folderPaths: folderPaths
        )
        mark(run, "search_requested")
        return run
    }

    static func mark(
        _ run: SearchPerformanceRun?,
        _ event: String,
        phaseStart: UInt64? = nil,
        resultCount: Int? = nil,
        totalCount: Int? = nil,
        fileSummaryCount: Int? = nil,
        groupCount: Int? = nil,
        renderedRowCount: Int? = nil,
        status: String? = nil,
        entryID: Int64? = nil,
        error: String? = nil
    ) {
        mark(
            run,
            event,
            phaseStart: phaseStart,
            phaseMilliseconds: nil,
            resultCount: resultCount,
            totalCount: totalCount,
            fileSummaryCount: fileSummaryCount,
            groupCount: groupCount,
            renderedRowCount: renderedRowCount,
            status: status,
            entryID: entryID,
            error: error,
            extraFields: []
        )
    }

    static func coreDiagnosticsSink(for run: SearchPerformanceRun?) -> SubtitleSearchDiagnosticSink? {
        guard let run, isEnabled else {
            return nil
        }

        return { event in
            mark(
                run,
                "db.\(event.name)",
                phaseMilliseconds: event.phaseMilliseconds,
                extraFields: event.fields
            )
        }
    }

    private static func mark(
        _ run: SearchPerformanceRun?,
        _ event: String,
        phaseStart: UInt64? = nil,
        phaseMilliseconds: Double? = nil,
        resultCount: Int? = nil,
        totalCount: Int? = nil,
        fileSummaryCount: Int? = nil,
        groupCount: Int? = nil,
        renderedRowCount: Int? = nil,
        status: String? = nil,
        entryID: Int64? = nil,
        error: String? = nil,
        extraFields: [SubtitleSearchDiagnosticField]
    ) {
        guard let run, isEnabled else {
            return
        }

        let timestamp = now()
        let resolvedPhaseMilliseconds = phaseMilliseconds
            ?? phaseStart.map { milliseconds(between: $0, and: timestamp) }
        let elapsed = milliseconds(between: run.startedAt, and: timestamp)
        var msg = "run=\(run.id) event=\(event) elapsed=\(String(format: "%.2fms", elapsed))"
        if let resolvedPhaseMilliseconds {
            msg += " phase=\(String(format: "%.2fms", resolvedPhaseMilliseconds))"
        }
        if let status {
            msg += " status=\(status)"
        }
        if let error {
            msg += " error=\(error)"
        }
        logger.debug("\(msg, privacy: .public)")
    }

    private static func milliseconds(between start: UInt64, and end: UInt64) -> Double {
        guard end >= start else {
            return 0
        }
        return Double(end - start) / 1_000_000
    }

    private static func diagnosticFlag(_ name: String) -> Bool {
        guard let value = ProcessInfo.processInfo.environment[name] else {
            return false
        }
        return value == "1" || value.caseInsensitiveCompare("true") == .orderedSame
    }
}
