import Foundation
import os

private struct CueContextPerformanceEntry: Encodable, Sendable {
    let schemaVersion = 1
    let timestamp: String
    let sequence: UInt64
    let event: String
    let contextID: String
    let elapsedMilliseconds: Double
    let phaseMilliseconds: Double?
    let displayTitle: String?
    let subtitlePath: String?
    let targetEntryID: Int64?
    let rangeLowerBound: Int?
    let rangeUpperBound: Int?
    let returnedRows: Int?
    let totalRows: Int?
    let tableRows: Int?
    let generation: Int?
    let status: String?
    let error: String?
}

private final class CueContextPerformanceLoggerState: @unchecked Sendable {
    private let lock = NSLock()
    private var nextSequence: UInt64 = 0

    func allocateSequence() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        nextSequence += 1
        return nextSequence
    }
}

private final class CueContextPerformanceLogWriter: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "app.cueseeker.cue-context-performance-log",
        qos: .utility
    )
    private let logger = Logger(subsystem: "com.cueseeker.perf", category: "CueContext")
    private let encoder = JSONEncoder()
    private var didAnnounceLogPath = false

    func write(_ entry: CueContextPerformanceEntry) {
        queue.async { [weak self] in
            self?.writeNow(entry)
        }
    }

    private func writeNow(_ entry: CueContextPerformanceEntry) {
        do {
            let fileURL = Self.jsonLogFileURL()
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            var data = try encoder.encode(entry)
            data.append(0x0A)

            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()

            if !didAnnounceLogPath {
                didAnnounceLogPath = true
                logger.warning("MARK CueContextPerformanceLogger.path \(fileURL.path, privacy: .public)")
            }
        } catch {
            logger.error("CueContextPerformanceLogger.writeFailed \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func jsonLogFileURL() -> URL {
        AppLogDirectory.fileURL(
            in: "cue-context",
            filename: "cue-context-\(dateStamp()).jsonl"
        )
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum CueContextPerformanceLogger {
    static let isEnabled = diagnosticFlag("CUESEEKER_PERF_CONTEXT")
        || diagnosticFlag("CUESEEKER_PERF_SEARCH")
        || diagnosticFlag("CUESEEKER_PERF")

    private static let state = CueContextPerformanceLoggerState()
    private static let writer = CueContextPerformanceLogWriter()

    static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    static func elapsedMilliseconds(since start: UInt64) -> Double {
        let end = now()
        return Double(end - start) / 1_000_000
    }

    static func record(
        event: String,
        contextID: UUID,
        startedAt: UInt64,
        phaseStart: UInt64? = nil,
        phaseMilliseconds: Double? = nil,
        displayTitle: String? = nil,
        subtitlePath: String? = nil,
        targetEntryID: Int64? = nil,
        range: Range<Int>? = nil,
        returnedRows: Int? = nil,
        totalRows: Int? = nil,
        tableRows: Int? = nil,
        generation: Int? = nil,
        status: String? = nil,
        error: String? = nil
    ) {
        guard isEnabled else { return }

        let timestamp = now()
        let resolvedPhaseMilliseconds = phaseMilliseconds
            ?? phaseStart.map { Double(timestamp - $0) / 1_000_000 }
        writer.write(CueContextPerformanceEntry(
            timestamp: timestampString(),
            sequence: state.allocateSequence(),
            event: event,
            contextID: contextID.uuidString,
            elapsedMilliseconds: Double(timestamp - startedAt) / 1_000_000,
            phaseMilliseconds: resolvedPhaseMilliseconds,
            displayTitle: displayTitle,
            subtitlePath: subtitlePath,
            targetEntryID: targetEntryID,
            rangeLowerBound: range?.lowerBound,
            rangeUpperBound: range?.upperBound,
            returnedRows: returnedRows,
            totalRows: totalRows,
            tableRows: tableRows,
            generation: generation,
            status: status,
            error: error
        ))
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS ZZZZZ"
        return formatter.string(from: Date())
    }

    private static func diagnosticFlag(_ name: String) -> Bool {
        guard let value = ProcessInfo.processInfo.environment[name] else {
            return false
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !normalized.isEmpty && normalized != "0" && normalized != "false" && normalized != "no"
    }
}
