import Foundation
import os
import CueSeekerCore

struct SearchPerformanceRun: Sendable {
    let id: UInt64
    let startedAt: UInt64
    let queryLength: Int
    let offset: Int
    let limit: Int
    let appending: Bool
    let debounce: Bool
    let folderCount: Int
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

    static func startRun(
        queryLength: Int,
        offset: Int,
        limit: Int,
        appending: Bool,
        debounce: Bool,
        folderCount: Int
    ) -> SearchPerformanceRun? {
        guard isEnabled else {
            return nil
        }

        let run = SearchPerformanceRun(
            id: state.allocateRunID(),
            startedAt: now(),
            queryLength: queryLength,
            offset: offset,
            limit: limit,
            appending: appending,
            debounce: debounce,
            folderCount: folderCount
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
