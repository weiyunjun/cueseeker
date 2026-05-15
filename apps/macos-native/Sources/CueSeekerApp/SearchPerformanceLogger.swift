import Foundation
import os
import CueSeekerCore

struct SearchPerformanceRun: Sendable {
    let id: UInt64
    let startedAt: UInt64
    let query: String
    let queryLength: Int
    let offset: Int
    let limit: Int
    let appending: Bool
    let debounce: Bool
    let folderCount: Int
    let folderPaths: [String]
    let e2eLoggingEnabled: Bool
    let e2eBenchmarkKey: String
}

private struct SearchPerformanceLogEntry: Sendable {
    let timestamp: String
    let sequence: UInt64
    let runID: UInt64
    let event: String
    let elapsedMilliseconds: Double
    let phaseMilliseconds: Double?
    let queryLength: Int
    let offset: Int
    let limit: Int
    let appending: Bool
    let debounce: Bool
    let folderCount: Int
    let resultCount: Int?
    let totalCount: Int?
    let fileSummaryCount: Int?
    let groupCount: Int?
    let renderedRowCount: Int?
    let status: String?
    let entryID: Int64?
    let error: String?
    let extraFields: [SubtitleSearchDiagnosticField]

    var formattedLogLine: String {
        var fields = [
            timestamp,
            "run=\(runID)",
            "sequence=\(sequence)",
            "event=\(event)",
            formatMilliseconds("elapsed", elapsedMilliseconds)
        ]
        if let phaseMilliseconds {
            fields.append(formatMilliseconds("phase", phaseMilliseconds))
        }
        fields.append("queryLength=\(queryLength)")
        fields.append("offset=\(offset)")
        fields.append("limit=\(limit)")
        fields.append("appending=\(appending)")
        fields.append("debounce=\(debounce)")
        fields.append("folders=\(folderCount)")
        append("results", resultCount, to: &fields)
        append("total", totalCount, to: &fields)
        append("fileSummaries", fileSummaryCount, to: &fields)
        append("groups", groupCount, to: &fields)
        append("renderedRows", renderedRowCount, to: &fields)
        append("status", status, to: &fields)
        append("entryID", entryID, to: &fields)
        append("error", error, to: &fields)
        for field in extraFields {
            fields.append("\(field.name)=\(Self.formatValue(field.value))")
        }

        return fields.joined(separator: " ") + "\n"
    }

    private func formatMilliseconds(_ label: String, _ value: Double) -> String {
        String(format: "%@=%.2fms", label, value)
    }

    private func append<T>(_ label: String, _ value: T?, to fields: inout [String]) {
        guard let value else {
            return
        }

        fields.append("\(label)=\(Self.formatValue(String(describing: value)))")
    }

    private static func formatValue(_ value: String) -> String {
        guard value.contains(where: { $0.isWhitespace || $0 == "=" || $0 == "\"" }) else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

private struct SearchE2ELogEntry: Encodable, Sendable {
    let schemaVersion = 2
    let timestamp: String
    let sequence: UInt64
    let runID: UInt64
    let event: String
    let query: String
    let benchmarkMetric: String?
    let warmupMilliseconds: Double?
    let returned: Int?
    let totalCount: Int?
    let fileSummaries: Int?
    let hotAvgMilliseconds: Double?
    let hotRawMilliseconds: [Double]?
    let currentRunKind: String?
    let currentRunMilliseconds: Double?
    let hotRunCount: Int?
    let hotTargetRunCount: Int?
    let hasMore: Bool?
    let offset: Int
    let limit: Int
    let groups: Int?
    let renderedRows: Int?
    let databaseMilliseconds: Double?
    let elapsedMilliseconds: Double
    let firstVisibleMilliseconds: Double?
    let status: String
    let queryLength: Int
    let appending: Bool
    let debounce: Bool
    let folders: [String]
    let error: String?
    let timings: SearchE2ETimingSnapshot
    let ui: SearchE2EUISnapshot
    let sampleResults: [SearchE2EResultSnapshot]?
    let topFileSummaries: [SearchE2EFileSummarySnapshot]?
    let firstVisibleResult: SearchE2EResultSnapshot?

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case timestamp
        case sequence
        case runID
        case event
        case query
        case benchmarkMetric
        case warmupMilliseconds
        case returned
        case totalCount
        case fileSummaries
        case hotAvgMilliseconds
        case hotRawMilliseconds
        case currentRunKind
        case currentRunMilliseconds
        case hotRunCount
        case hotTargetRunCount
        case hasMore
        case offset
        case limit
        case groups
        case renderedRows
        case databaseMilliseconds
        case elapsedMilliseconds
        case firstVisibleMilliseconds
        case status
        case queryLength
        case appending
        case debounce
        case folders
        case error
        case timings
        case ui
        case sampleResults
        case topFileSummaries
        case firstVisibleResult
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(runID, forKey: .runID)
        try container.encode(event, forKey: .event)
        try container.encode(query, forKey: .query)
        try encodeNullable(benchmarkMetric, forKey: .benchmarkMetric, into: &container)
        try encodeNullable(warmupMilliseconds, forKey: .warmupMilliseconds, into: &container)
        try encodeNullable(returned, forKey: .returned, into: &container)
        try encodeNullable(totalCount, forKey: .totalCount, into: &container)
        try encodeNullable(fileSummaries, forKey: .fileSummaries, into: &container)
        try encodeNullable(hotAvgMilliseconds, forKey: .hotAvgMilliseconds, into: &container)
        try encodeNullable(hotRawMilliseconds, forKey: .hotRawMilliseconds, into: &container)
        try encodeNullable(currentRunKind, forKey: .currentRunKind, into: &container)
        try encodeNullable(currentRunMilliseconds, forKey: .currentRunMilliseconds, into: &container)
        try encodeNullable(hotRunCount, forKey: .hotRunCount, into: &container)
        try encodeNullable(hotTargetRunCount, forKey: .hotTargetRunCount, into: &container)
        try encodeNullable(hasMore, forKey: .hasMore, into: &container)
        try container.encode(offset, forKey: .offset)
        try container.encode(limit, forKey: .limit)
        try encodeNullable(groups, forKey: .groups, into: &container)
        try encodeNullable(renderedRows, forKey: .renderedRows, into: &container)
        try encodeNullable(databaseMilliseconds, forKey: .databaseMilliseconds, into: &container)
        try container.encode(elapsedMilliseconds, forKey: .elapsedMilliseconds)
        try encodeNullable(firstVisibleMilliseconds, forKey: .firstVisibleMilliseconds, into: &container)
        try container.encode(status, forKey: .status)
        try container.encode(queryLength, forKey: .queryLength)
        try container.encode(appending, forKey: .appending)
        try container.encode(debounce, forKey: .debounce)
        try container.encode(folders, forKey: .folders)
        try encodeNullable(error, forKey: .error, into: &container)
        try container.encode(timings, forKey: .timings)
        try container.encode(ui, forKey: .ui)
        try encodeNullable(sampleResults, forKey: .sampleResults, into: &container)
        try encodeNullable(topFileSummaries, forKey: .topFileSummaries, into: &container)
        try encodeNullable(firstVisibleResult, forKey: .firstVisibleResult, into: &container)
    }

    private func encodeNullable<T: Encodable>(
        _ value: T?,
        forKey key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}

private struct SearchE2ETimingSnapshot: Encodable, Sendable {
    let elapsedMilliseconds: Double
    let databaseSearchMilliseconds: Double?
    let stateAssignMilliseconds: Double?
    let groupRebuildMilliseconds: Double?
    let statusCompletionMilliseconds: Double?
    let firstVisibleElapsedMilliseconds: Double?
}

private struct SearchE2EUISnapshot: Encodable, Sendable {
    let groupCount: Int?
    let renderedRowCount: Int?
    let firstVisibleEntryID: Int64?
}

private struct SearchE2ESamples: Sendable {
    private static let sampleResultLimit = 5
    private static let fileSummaryLimit = 10

    let sampleResults: [SearchE2EResultSnapshot]
    let topFileSummaries: [SearchE2EFileSummarySnapshot]
    let returned: Int
    let totalCount: Int
    let fileSummaryCount: Int
    let hasMore: Bool

    init(page: SubtitleSearchPage, offset: Int) {
        returned = page.results.count
        totalCount = page.totalCount
        fileSummaryCount = page.fileSummaries.count
        hasMore = offset + page.results.count < page.totalCount
        sampleResults = page.results
            .prefix(Self.sampleResultLimit)
            .map(SearchE2EResultSnapshot.init)
        topFileSummaries = page.fileSummaries
            .prefix(Self.fileSummaryLimit)
            .map(SearchE2EFileSummarySnapshot.init)
    }
}

private struct SearchE2EBenchmarkMeasurement: Sendable {
    let milliseconds: Double
    let returned: Int
    let totalCount: Int
    let fileSummaries: Int
}

private struct SearchE2EBenchmarkSnapshot: Sendable {
    let warmupMilliseconds: Double?
    let returned: Int?
    let totalCount: Int?
    let fileSummaries: Int?
    let hotAvgMilliseconds: Double?
    let hotRawMilliseconds: [Double]
    let currentRunKind: String?
    let currentRunMilliseconds: Double?
    let hotRunCount: Int
    let hotTargetRunCount: Int
}

private struct SearchE2EBenchmarkState: Sendable {
    var warmupMilliseconds: Double?
    var returned: Int?
    var totalCount: Int?
    var fileSummaries: Int?
    var hotRawMilliseconds: [Double] = []
}

private struct SearchE2EResultSnapshot: Encodable, Sendable {
    let entryID: Int64
    let subtitlePath: String
    let subtitleDisplayTitle: String
    let subtitleFormat: String
    let videoPath: String
    let videoName: String
    let startMilliseconds: Int
    let endMilliseconds: Int
    let content: String
    let cueLines: [String]
    let searchRank: Int

    init(result: SubtitleSearchResult) {
        entryID = result.entryID
        subtitlePath = result.subtitlePath
        subtitleDisplayTitle = SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: result.subtitlePath)
        subtitleFormat = result.subtitleFormat.rawValue
        videoPath = result.videoPath
        videoName = result.videoName
        startMilliseconds = result.startMilliseconds
        endMilliseconds = result.endMilliseconds
        content = result.content
        cueLines = result.cueLines
        searchRank = result.searchRank
    }

    var summaryText: String {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }
}

private struct SearchE2EFileSummarySnapshot: Encodable, Sendable {
    let subtitlePath: String
    let subtitleFileName: String
    let subtitleDisplayTitle: String
    let matchCount: Int

    init(summary: SubtitleSearchFileSummary) {
        subtitlePath = summary.subtitlePath
        subtitleFileName = summary.subtitleFileName
        subtitleDisplayTitle = summary.subtitleDisplayTitle
        matchCount = summary.matchCount
    }
}

private final class SearchPerformanceLoggerState: @unchecked Sendable {
    private static let e2eHotTargetRunCount = 5

    private let lock = NSLock()
    private var nextRunID: UInt64 = 0
    private var nextSequence: UInt64 = 0
    private var e2eBenchmarkStates: [String: SearchE2EBenchmarkState] = [:]

    func allocateRunID() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        nextRunID += 1
        return nextRunID
    }

    func allocateSequence() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        nextSequence += 1
        return nextSequence
    }

    func recordE2EBenchmark(
        key: String,
        measurement: SearchE2EBenchmarkMeasurement
    ) -> SearchE2EBenchmarkSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var state = e2eBenchmarkStates[key] ?? SearchE2EBenchmarkState()
        let currentRunKind: String
        if state.warmupMilliseconds == nil {
            state.warmupMilliseconds = measurement.milliseconds
            currentRunKind = "warmup"
        } else if state.hotRawMilliseconds.count < Self.e2eHotTargetRunCount {
            state.hotRawMilliseconds.append(measurement.milliseconds)
            currentRunKind = "hot"
        } else {
            currentRunKind = "hot_extra"
        }

        state.returned = measurement.returned
        state.totalCount = measurement.totalCount
        state.fileSummaries = measurement.fileSummaries
        e2eBenchmarkStates[key] = state

        return snapshot(
            from: state,
            currentRunKind: currentRunKind,
            currentRunMilliseconds: measurement.milliseconds
        )
    }

    func e2eBenchmarkSnapshot(key: String) -> SearchE2EBenchmarkSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        guard let state = e2eBenchmarkStates[key] else {
            return nil
        }

        return snapshot(
            from: state,
            currentRunKind: nil,
            currentRunMilliseconds: nil
        )
    }

    private func snapshot(
        from state: SearchE2EBenchmarkState,
        currentRunKind: String?,
        currentRunMilliseconds: Double?
    ) -> SearchE2EBenchmarkSnapshot {
        let hotAvg = state.hotRawMilliseconds.isEmpty
            ? nil
            : state.hotRawMilliseconds.reduce(0, +) / Double(state.hotRawMilliseconds.count)

        return SearchE2EBenchmarkSnapshot(
            warmupMilliseconds: state.warmupMilliseconds,
            returned: state.returned,
            totalCount: state.totalCount,
            fileSummaries: state.fileSummaries,
            hotAvgMilliseconds: hotAvg,
            hotRawMilliseconds: state.hotRawMilliseconds,
            currentRunKind: currentRunKind,
            currentRunMilliseconds: currentRunMilliseconds,
            hotRunCount: state.hotRawMilliseconds.count,
            hotTargetRunCount: Self.e2eHotTargetRunCount
        )
    }
}

private final class SearchE2ELogWriter: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "app.cueseeker.search-e2e-log",
        qos: .utility
    )
    private let logger = Logger(subsystem: "com.cueseeker.perf", category: "SearchE2E")
    private let encoder = JSONEncoder()
    private var didAnnounceLogPath = false

    func write(_ entry: SearchE2ELogEntry) {
        queue.async { [weak self] in
            self?.writeNow(entry)
        }
    }

    private func writeNow(_ entry: SearchE2ELogEntry) {
        do {
            let jsonFileURL = Self.jsonLogFileURL()
            var data = try encoder.encode(entry)
            data.append(0x0A)
            try write(data, to: jsonFileURL)

            if !didAnnounceLogPath {
                didAnnounceLogPath = true
                logger.warning("MARK SearchE2ELog.path \(jsonFileURL.path, privacy: .public)")
            }
        } catch {
            logger.error("SearchE2ELog.writeFailed \(error.localizedDescription, privacy: .public)")
        }
    }

    private func write(_ data: Data, to fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
    }

    private static func jsonLogFileURL() -> URL {
        AppLogDirectory.fileURL(
            in: "search-e2e",
            filename: "search-e2e-\(dateStamp()).jsonl"
        )
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private final class SearchPerformanceLogWriter: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "app.cueseeker.search-performance-log",
        qos: .utility
    )
    private let logger = Logger(subsystem: "com.cueseeker.perf", category: "Search")
    private var didAnnounceLogPath = false

    func write(_ entry: SearchPerformanceLogEntry) {
        queue.async { [weak self] in
            self?.writeNow(entry)
        }
    }

    private func writeNow(_ entry: SearchPerformanceLogEntry) {
        do {
            let fileURL = Self.logFileURL()
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let data = Data(entry.formattedLogLine.utf8)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()

            if !didAnnounceLogPath {
                didAnnounceLogPath = true
                logger.warning("MARK SearchPerformanceLogger.path \(fileURL.path, privacy: .public)")
            }
        } catch {
            logger.error("SearchPerformanceLogger.writeFailed \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func logFileURL() -> URL {
        AppLogDirectory.fileURL(
            in: "search-timing",
            filename: "search-timing-\(dateStamp()).log"
        )
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum SearchPerformanceLogger {
    private static let state = SearchPerformanceLoggerState()
    private static let writer = SearchPerformanceLogWriter()
    private static let e2eWriter = SearchE2ELogWriter()

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
        limit: Int,
        appending: Bool,
        debounce: Bool,
        folderPaths: [String],
        e2eLoggingEnabled: Bool
    ) -> SearchPerformanceRun? {
        guard isEnabled || e2eLoggingEnabled else {
            return nil
        }

        let run = SearchPerformanceRun(
            id: state.allocateRunID(),
            startedAt: now(),
            query: query,
            queryLength: queryLength,
            offset: offset,
            limit: limit,
            appending: appending,
            debounce: debounce,
            folderCount: folderPaths.count,
            folderPaths: folderPaths,
            e2eLoggingEnabled: e2eLoggingEnabled,
            e2eBenchmarkKey: e2eBenchmarkKey(
                query: query,
                offset: offset,
                limit: limit,
                folderPaths: folderPaths
            )
        )
        mark(run, "search_requested")
        return run
    }

    static func writeE2ESearchPage(
        _ run: SearchPerformanceRun?,
        event: String,
        page: SubtitleSearchPage?,
        databaseSearchMilliseconds: Double? = nil,
        stateAssignMilliseconds: Double? = nil,
        groupRebuildMilliseconds: Double? = nil,
        statusCompletionMilliseconds: Double? = nil,
        groupCount: Int? = nil,
        renderedRowCount: Int? = nil,
        status: String,
        error: String? = nil
    ) {
        guard let run, run.e2eLoggingEnabled else {
            return
        }

        let timestamp = now()
        let elapsedMilliseconds = milliseconds(between: run.startedAt, and: timestamp)
        let samples = page.map { SearchE2ESamples(page: $0, offset: run.offset) }
        let benchmark = makeE2EBenchmarkSnapshot(
            for: run,
            page: page,
            elapsedMilliseconds: elapsedMilliseconds,
            status: status
        )
        let entry = SearchE2ELogEntry(
            timestamp: timestampString(),
            sequence: state.allocateSequence(),
            runID: run.id,
            event: event,
            query: run.query,
            benchmarkMetric: benchmark == nil ? nil : "elapsedMilliseconds",
            warmupMilliseconds: benchmark?.warmupMilliseconds,
            returned: benchmark?.returned ?? samples?.returned,
            totalCount: benchmark?.totalCount ?? samples?.totalCount,
            fileSummaries: benchmark?.fileSummaries ?? samples?.fileSummaryCount,
            hotAvgMilliseconds: benchmark?.hotAvgMilliseconds,
            hotRawMilliseconds: benchmark?.hotRawMilliseconds,
            currentRunKind: benchmark?.currentRunKind,
            currentRunMilliseconds: benchmark?.currentRunMilliseconds,
            hotRunCount: benchmark?.hotRunCount,
            hotTargetRunCount: benchmark?.hotTargetRunCount,
            hasMore: samples?.hasMore,
            offset: run.offset,
            limit: run.limit,
            groups: groupCount,
            renderedRows: renderedRowCount,
            databaseMilliseconds: databaseSearchMilliseconds,
            elapsedMilliseconds: elapsedMilliseconds,
            firstVisibleMilliseconds: nil,
            status: status,
            queryLength: run.queryLength,
            appending: run.appending,
            debounce: run.debounce,
            folders: run.folderPaths,
            error: error,
            timings: SearchE2ETimingSnapshot(
                elapsedMilliseconds: elapsedMilliseconds,
                databaseSearchMilliseconds: databaseSearchMilliseconds,
                stateAssignMilliseconds: stateAssignMilliseconds,
                groupRebuildMilliseconds: groupRebuildMilliseconds,
                statusCompletionMilliseconds: statusCompletionMilliseconds,
                firstVisibleElapsedMilliseconds: nil
            ),
            ui: SearchE2EUISnapshot(
                groupCount: groupCount,
                renderedRowCount: renderedRowCount,
                firstVisibleEntryID: nil
            ),
            sampleResults: samples?.sampleResults,
            topFileSummaries: samples?.topFileSummaries,
            firstVisibleResult: nil
        )
        e2eWriter.write(entry)
    }

    static func writeE2EFirstVisible(
        _ run: SearchPerformanceRun?,
        result: SubtitleSearchResult,
        resultCount: Int,
        totalCount: Int,
        fileSummaryCount: Int,
        groupCount: Int,
        renderedRowCount: Int
    ) {
        guard let run, run.e2eLoggingEnabled else {
            return
        }

        let timestamp = now()
        let elapsedMilliseconds = milliseconds(between: run.startedAt, and: timestamp)
        let benchmark = state.e2eBenchmarkSnapshot(key: run.e2eBenchmarkKey)
        let entry = SearchE2ELogEntry(
            timestamp: timestampString(),
            sequence: state.allocateSequence(),
            runID: run.id,
            event: "first_result_row_appeared",
            query: run.query,
            benchmarkMetric: benchmark == nil ? nil : "elapsedMilliseconds",
            warmupMilliseconds: benchmark?.warmupMilliseconds,
            returned: benchmark?.returned ?? resultCount,
            totalCount: benchmark?.totalCount ?? totalCount,
            fileSummaries: benchmark?.fileSummaries ?? fileSummaryCount,
            hotAvgMilliseconds: benchmark?.hotAvgMilliseconds,
            hotRawMilliseconds: benchmark?.hotRawMilliseconds,
            currentRunKind: benchmark?.currentRunKind,
            currentRunMilliseconds: benchmark?.currentRunMilliseconds,
            hotRunCount: benchmark?.hotRunCount,
            hotTargetRunCount: benchmark?.hotTargetRunCount,
            hasMore: resultCount < totalCount,
            offset: run.offset,
            limit: run.limit,
            groups: groupCount,
            renderedRows: renderedRowCount,
            databaseMilliseconds: nil,
            elapsedMilliseconds: elapsedMilliseconds,
            firstVisibleMilliseconds: elapsedMilliseconds,
            status: "visible",
            queryLength: run.queryLength,
            appending: run.appending,
            debounce: run.debounce,
            folders: run.folderPaths,
            error: nil,
            timings: SearchE2ETimingSnapshot(
                elapsedMilliseconds: elapsedMilliseconds,
                databaseSearchMilliseconds: nil,
                stateAssignMilliseconds: nil,
                groupRebuildMilliseconds: nil,
                statusCompletionMilliseconds: nil,
                firstVisibleElapsedMilliseconds: elapsedMilliseconds
            ),
            ui: SearchE2EUISnapshot(
                groupCount: groupCount,
                renderedRowCount: renderedRowCount,
                firstVisibleEntryID: result.entryID
            ),
            sampleResults: nil,
            topFileSummaries: nil,
            firstVisibleResult: SearchE2EResultSnapshot(result: result)
        )
        e2eWriter.write(entry)
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
        let entry = SearchPerformanceLogEntry(
            timestamp: timestampString(),
            sequence: state.allocateSequence(),
            runID: run.id,
            event: event,
            elapsedMilliseconds: milliseconds(between: run.startedAt, and: timestamp),
            phaseMilliseconds: resolvedPhaseMilliseconds,
            queryLength: run.queryLength,
            offset: run.offset,
            limit: run.limit,
            appending: run.appending,
            debounce: run.debounce,
            folderCount: run.folderCount,
            resultCount: resultCount,
            totalCount: totalCount,
            fileSummaryCount: fileSummaryCount,
            groupCount: groupCount,
            renderedRowCount: renderedRowCount,
            status: status,
            entryID: entryID,
            error: error,
            extraFields: extraFields
        )
        writer.write(entry)
    }

    private static func makeE2EBenchmarkSnapshot(
        for run: SearchPerformanceRun,
        page: SubtitleSearchPage?,
        elapsedMilliseconds: Double,
        status: String
    ) -> SearchE2EBenchmarkSnapshot? {
        guard let page else {
            return state.e2eBenchmarkSnapshot(key: run.e2eBenchmarkKey)
        }

        guard status == "completed" else {
            return state.e2eBenchmarkSnapshot(key: run.e2eBenchmarkKey)
        }

        return state.recordE2EBenchmark(
            key: run.e2eBenchmarkKey,
            measurement: SearchE2EBenchmarkMeasurement(
                milliseconds: elapsedMilliseconds,
                returned: page.results.count,
                totalCount: page.totalCount,
                fileSummaries: page.fileSummaries.count
            )
        )
    }

    private static func e2eBenchmarkKey(
        query: String,
        offset: Int,
        limit: Int,
        folderPaths: [String]
    ) -> String {
        ([query, "offset=\(offset)", "limit=\(limit)"] + folderPaths)
            .joined(separator: "\u{1F}")
    }

    private static func milliseconds(between start: UInt64, and end: UInt64) -> Double {
        Double(end - start) / 1_000_000
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS ZZZZZ"
        return formatter.string(from: Date())
    }

    private static func diagnosticFlag(_ name: String) -> Bool {
        let argumentName = "--" + name.lowercased().replacingOccurrences(of: "_", with: "-")
        if ProcessInfo.processInfo.arguments.contains(argumentName) {
            return true
        }

        let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()

        switch value {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
