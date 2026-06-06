import Foundation
import os

private struct TableRenderingPerformanceEntry: Encodable, Sendable {
    let schemaVersion = 1
    let timestamp: String
    let sequence: UInt64
    let event: String
    let table: String
    let reason: String?
    let elapsedMilliseconds: Double?
    let totalMilliseconds: Double?
    let maxMilliseconds: Double?
    let rowCount: Int?
    let oldRowCount: Int?
    let newRowCount: Int?
    let sourceCount: Int?
    let visibleRows: Int?
    let measuredRows: Int?
    let configuredCells: Int?
    let cacheHits: Int?
    let cacheMisses: Int?
    let estimatedRows: Int?
    let width: Double?
    let changed: Bool?
}

private final class TableRenderingPerformanceLoggerState: @unchecked Sendable {
    private let lock = NSLock()
    private var nextSequence: UInt64 = 0

    func allocateSequence() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        nextSequence += 1
        return nextSequence
    }
}

private final class TableRenderingPerformanceLogWriter: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "app.cueseeker.table-rendering-log",
        qos: .utility
    )
    private let logger = Logger(subsystem: "com.cueseeker.perf", category: "TableRendering")
    private let encoder = JSONEncoder()
    private var didAnnounceLogPath = false

    func write(_ entry: TableRenderingPerformanceEntry) {
        queue.async { [weak self] in
            self?.writeNow(entry)
        }
    }

    private func writeNow(_ entry: TableRenderingPerformanceEntry) {
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
                logger.warning("MARK TableRenderingPerformanceLogger.path \(fileURL.path, privacy: .public)")
            }
        } catch {
            logger.error("TableRenderingPerformanceLogger.writeFailed \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func jsonLogFileURL() -> URL {
        AppLogDirectory.fileURL(
            in: "table-rendering",
            filename: "table-rendering-\(dateStamp()).jsonl"
        )
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum TableRenderingPerformanceLogger {
    static let isEnabled = diagnosticFlag("CUESEEKER_PERF_TABLE")
        || diagnosticFlag("CUESEEKER_PERF")

    private static let state = TableRenderingPerformanceLoggerState()
    private static let writer = TableRenderingPerformanceLogWriter()

    static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    static func elapsedMilliseconds(since start: UInt64) -> Double {
        let end = now()
        return Double(end - start) / 1_000_000
    }

    static func record(
        event: String,
        table: String,
        reason: String? = nil,
        elapsedMilliseconds: Double? = nil,
        totalMilliseconds: Double? = nil,
        maxMilliseconds: Double? = nil,
        rowCount: Int? = nil,
        oldRowCount: Int? = nil,
        newRowCount: Int? = nil,
        sourceCount: Int? = nil,
        visibleRows: Int? = nil,
        measuredRows: Int? = nil,
        configuredCells: Int? = nil,
        cacheHits: Int? = nil,
        cacheMisses: Int? = nil,
        estimatedRows: Int? = nil,
        width: Double? = nil,
        changed: Bool? = nil
    ) {
        guard isEnabled else {
            return
        }

        writer.write(TableRenderingPerformanceEntry(
            timestamp: timestamp(),
            sequence: state.allocateSequence(),
            event: event,
            table: table,
            reason: reason,
            elapsedMilliseconds: elapsedMilliseconds,
            totalMilliseconds: totalMilliseconds,
            maxMilliseconds: maxMilliseconds,
            rowCount: rowCount,
            oldRowCount: oldRowCount,
            newRowCount: newRowCount,
            sourceCount: sourceCount,
            visibleRows: visibleRows,
            measuredRows: measuredRows,
            configuredCells: configuredCells,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            estimatedRows: estimatedRows,
            width: width,
            changed: changed
        ))
    }

    private static func timestamp() -> String {
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
