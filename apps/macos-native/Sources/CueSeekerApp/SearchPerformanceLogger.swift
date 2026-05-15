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
    let schemaVersion = 1
    let timestamp: String
    let sequence: UInt64
    let runID: UInt64
    let event: String
    let query: String
    let returned: Int?
    let total: Int?
    let fileSummaries: Int?
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
    let page: SearchE2EPageSnapshot?
    let firstVisibleResult: SearchE2EResultSnapshot?

    var formattedSummaryLine: String {
        var fields = [
            timestamp,
            "run=\(runID)",
            "sequence=\(sequence)",
            "event=\(formatValue(event))",
            "query=\(formatValue(query))"
        ]
        append("returned", returned, to: &fields)
        append("total", total, to: &fields)
        append("fileSummaries", fileSummaries, to: &fields)
        fields.append("offset=\(offset)")
        fields.append("limit=\(limit)")
        append("groups", groups, to: &fields)
        append("renderedRows", renderedRows, to: &fields)
        append("database", databaseMilliseconds.map(formatMilliseconds), to: &fields)
        fields.append("elapsed=\(formatMilliseconds(elapsedMilliseconds))")
        append("firstVisible", firstVisibleMilliseconds.map(formatMilliseconds), to: &fields)
        append("entryID", firstVisibleResult?.entryID, to: &fields)
        append("rank", firstVisibleResult?.searchRank, to: &fields)
        append("title", firstVisibleResult?.subtitleDisplayTitle, to: &fields)
        append("text", firstVisibleResult?.summaryText, to: &fields)
        fields.append("status=\(formatValue(status))")
        append("error", error, to: &fields)

        return fields.joined(separator: " ") + "\n"
    }

    private func append<T>(_ label: String, _ value: T?, to fields: inout [String]) {
        guard let value else {
            return
        }

        fields.append("\(label)=\(formatValue(String(describing: value)))")
    }

    private func formatMilliseconds(_ value: Double) -> String {
        String(format: "%.2fms", value)
    }

    private func formatValue(_ value: String) -> String {
        guard value.contains(where: { $0.isWhitespace || $0 == "=" || $0 == "\"" }) else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
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

private struct SearchE2EPageSnapshot: Encodable, Sendable {
    let results: [SearchE2EResultSnapshot]
    let totalCount: Int
    let fileSummaries: [SearchE2EFileSummarySnapshot]

    init(page: SubtitleSearchPage) {
        results = page.results.map(SearchE2EResultSnapshot.init)
        totalCount = page.totalCount
        fileSummaries = page.fileSummaries.map(SearchE2EFileSummarySnapshot.init)
    }
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
    private let lock = NSLock()
    private var nextRunID: UInt64 = 0
    private var nextSequence: UInt64 = 0

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
            try write(Data(entry.formattedSummaryLine.utf8), to: Self.summaryLogFileURL())

            if !didAnnounceLogPath {
                didAnnounceLogPath = true
                logger.warning("MARK SearchE2ELog.path \(jsonFileURL.path, privacy: .public)")
                logger.warning("MARK SearchE2ESummaryLog.path \(Self.summaryLogFileURL().path, privacy: .public)")
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

    private static func summaryLogFileURL() -> URL {
        AppLogDirectory.fileURL(
            in: "search-e2e",
            filename: "search-e2e-summary-\(dateStamp()).log"
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

    #if DEBUG
    private static let isDevelopmentBuild = true
    #else
    private static let isDevelopmentBuild = false
    #endif

    static let isEnabled = isDevelopmentBuild
        || diagnosticFlag("CUESEEKER_PERF_SEARCH")
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
            e2eLoggingEnabled: e2eLoggingEnabled
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
        let entry = SearchE2ELogEntry(
            timestamp: timestampString(),
            sequence: state.allocateSequence(),
            runID: run.id,
            event: event,
            query: run.query,
            returned: page?.results.count,
            total: page?.totalCount,
            fileSummaries: page?.fileSummaries.count,
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
            page: page.map(SearchE2EPageSnapshot.init),
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
        let entry = SearchE2ELogEntry(
            timestamp: timestampString(),
            sequence: state.allocateSequence(),
            runID: run.id,
            event: "first_result_row_appeared",
            query: run.query,
            returned: resultCount,
            total: totalCount,
            fileSummaries: fileSummaryCount,
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
            page: nil,
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
