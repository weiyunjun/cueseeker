import Foundation

public enum AppBuildConfiguration: String, Sendable, Equatable {
    case debug = "debug"
    case release = "release"

    public static var current: AppBuildConfiguration {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }
}

public enum AppLogLevel: Int, Comparable, Sendable, CaseIterable {
    case debug = 0
    case info = 1
    case warn = 2
    case error = 3

    public var label: String {
        switch self {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warn:
            return "WARN"
        case .error:
            return "ERROR"
        }
    }

    public static func < (lhs: AppLogLevel, rhs: AppLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static var defaultMinimumLevel: AppLogLevel {
        switch AppBuildConfiguration.current {
        case .debug:
            return .debug
        case .release:
            return .info
        }
    }
}

public enum AppLogCategory: String, Sendable, CaseIterable {
    case app = "App"
    case database = "Database"
    case task = "Task"
    case playback = "Playback"
    case export = "Export"
    case network = "Network"
    case system = "System"
}

public final class AppLogger: @unchecked Sendable {
    public static let defaultMaxFileSizeBytes = 10 * 1024 * 1024
    public static let defaultRetentionDays = 14
    public static let legacyCollageLogFileName = "collage-performance.log"

    public static let shared = AppLogger()

    public let logDirectoryURL: URL
    public let minimumLevel: AppLogLevel
    public let maxFileSizeBytes: Int
    public let retentionDays: Int
    public let isEnabled: Bool

    private let calendar: Calendar
    private let queue = DispatchQueue(
        label: "com.cueseeker.app.logger",
        qos: .utility
    )

    public init(
        logDirectoryURL: URL = AppLogger.defaultLogDirectoryURL(),
        minimumLevel: AppLogLevel = .defaultMinimumLevel,
        maxFileSizeBytes: Int = AppLogger.defaultMaxFileSizeBytes,
        retentionDays: Int = AppLogger.defaultRetentionDays,
        calendar: Calendar = .current,
        isEnabled: Bool = AppLogger.defaultIsEnabled
    ) {
        self.logDirectoryURL = logDirectoryURL
        self.minimumLevel = minimumLevel
        self.maxFileSizeBytes = max(1, maxFileSizeBytes)
        self.retentionDays = max(1, retentionDays)
        self.calendar = calendar
        self.isEnabled = isEnabled
    }

    public static var defaultIsEnabled: Bool {
        !ApplicationInfo.isRunningInUnitTestProcess
            && ProcessInfo.processInfo.processName == ApplicationInfo.name
    }

    public static func defaultBaseLogsDirectoryURL(
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectoryURL.appendingPathComponent(
            "Library/Application Support/\(ApplicationInfo.name)/logs",
            isDirectory: true
        )
    }

    public static func defaultLogDirectoryURL(
        for configuration: AppBuildConfiguration = .current,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        defaultBaseLogsDirectoryURL(homeDirectoryURL: homeDirectoryURL)
            .appendingPathComponent(configuration.rawValue, isDirectory: true)
    }

    public static func logFileName(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        "cueseeker-\(dateString(for: date, timeZone: calendar.timeZone)).log"
    }

    public func logFileURL(for date: Date = Date()) -> URL {
        logDirectoryURL.appendingPathComponent(
            Self.logFileName(for: date, calendar: calendar),
            isDirectory: false
        )
    }

    public func debug(
        _ category: AppLogCategory,
        _ message: String,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        log(
            level: .debug,
            category: category,
            message: message,
            details: details,
            timestamp: timestamp
        )
    }

    public func debug(
        _ category: AppLogCategory,
        _ message: String,
        fields: [(String, String?)],
        timestamp: Date = Date()
    ) {
        log(
            level: .debug,
            category: category,
            message: message,
            details: Self.formatFields(fields),
            timestamp: timestamp
        )
    }

    public func info(
        _ category: AppLogCategory,
        _ message: String,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        log(
            level: .info,
            category: category,
            message: message,
            details: details,
            timestamp: timestamp
        )
    }

    public func info(
        _ category: AppLogCategory,
        _ message: String,
        fields: [(String, String?)],
        timestamp: Date = Date()
    ) {
        log(
            level: .info,
            category: category,
            message: message,
            details: Self.formatFields(fields),
            timestamp: timestamp
        )
    }

    public func warn(
        _ category: AppLogCategory,
        _ message: String,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        log(
            level: .warn,
            category: category,
            message: message,
            details: details,
            timestamp: timestamp
        )
    }

    public func warn(
        _ category: AppLogCategory,
        _ message: String,
        fields: [(String, String?)],
        timestamp: Date = Date()
    ) {
        log(
            level: .warn,
            category: category,
            message: message,
            details: Self.formatFields(fields),
            timestamp: timestamp
        )
    }

    public func error(
        _ category: AppLogCategory,
        _ message: String,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        log(
            level: .error,
            category: category,
            message: message,
            details: details,
            timestamp: timestamp
        )
    }

    public func error(
        _ category: AppLogCategory,
        _ message: String,
        fields: [(String, String?)],
        timestamp: Date = Date()
    ) {
        log(
            level: .error,
            category: category,
            message: message,
            details: Self.formatFields(fields),
            timestamp: timestamp
        )
    }

    public static func formatFields(_ fields: [(String, String?)]) -> String {
        fields.compactMap { key, rawValue in
            guard let rawValue else { return nil }
            let sanitized = sanitizeSingleLine(rawValue)
            if sanitized.isEmpty
                || sanitized.contains(" ")
                || sanitized.contains("\"")
                || sanitized.contains("=") {
                let escaped = sanitized.replacingOccurrences(of: "\"", with: "\\\"")
                return "\(key)=\"\(escaped)\""
            }
            return "\(key)=\(sanitized)"
        }.joined(separator: " ")
    }

    public func log(
        level: AppLogLevel,
        category: AppLogCategory,
        message: String,
        details: String? = nil,
        timestamp: Date = Date()
    ) {
        guard isEnabled, level >= minimumLevel else {
            return
        }

        let line = Self.formatLine(
            level: level,
            category: category,
            message: message,
            details: details,
            timestamp: timestamp,
            timeZone: calendar.timeZone
        )
        let targetURL = logFileURL(for: timestamp)
        queue.async { [weak self] in
            self?.appendLine(line, to: targetURL)
        }
    }

    public func performStartupMaintenance(now: Date = Date()) {
        guard isEnabled else {
            return
        }
        queue.async { [weak self] in
            self?.cleanupExpiredAndLegacyLogs(now: now)
        }
    }

    public func flush() {
        queue.sync {}
    }

    public static func formatLine(
        level: AppLogLevel,
        category: AppLogCategory,
        message: String,
        details: String? = nil,
        timestamp: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let sanitizedMessage = sanitizeSingleLine(message)
        let base = "\(timestampString(for: timestamp, timeZone: timeZone)) [\(level.label)] [\(category.rawValue)] \(sanitizedMessage)"
        guard let details else {
            return base
        }
        let sanitizedDetails = sanitizeSingleLine(details)
        guard !sanitizedDetails.isEmpty else {
            return base
        }
        return "\(base) | \(sanitizedDetails)"
    }

    private func appendLine(_ line: String, to fileURL: URL) {
        let lineData = Data((line + "\n").utf8)
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(
                at: logDirectoryURL,
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forUpdating: fileURL)
                defer {
                    try? handle.close()
                }
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
            } else {
                try lineData.write(to: fileURL, options: .atomic)
            }

            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? NSNumber,
               fileSize.intValue > maxFileSizeBytes {
                let existingData = try Data(contentsOf: fileURL)
                let trimmedData = Self.trimLogDataIfNeeded(
                    existingData,
                    maxFileSizeBytes: maxFileSizeBytes
                )
                try trimmedData.write(to: fileURL, options: .atomic)
            }
        } catch {
            // Local file logging is diagnostic and must never disrupt app workflows.
        }
    }

    private func cleanupExpiredAndLegacyLogs(now: Date) {
        let fileManager = FileManager.default

        let legacyCollageLogURL = logDirectoryURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.legacyCollageLogFileName, isDirectory: false)
        if fileManager.fileExists(atPath: legacyCollageLogURL.path) {
            try? fileManager.removeItem(at: legacyCollageLogURL)
        }

        guard let entries = try? fileManager.contentsOfDirectory(
            at: logDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let startOfToday = calendar.startOfDay(for: now)
        guard let cutoffDate = calendar.date(
            byAdding: .day,
            value: -retentionDays,
            to: startOfToday
        ) else {
            return
        }

        for fileURL in entries where fileURL.pathExtension.lowercased() == "log" {
            let fileName = fileURL.lastPathComponent
            if let fileDay = Self.parseLogFileDate(
                fromFileName: fileName,
                timeZone: calendar.timeZone
            ) {
                if fileDay < cutoffDate {
                    try? fileManager.removeItem(at: fileURL)
                }
            } else if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modifiedDate = values.contentModificationDate,
                      modifiedDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    static func trimLogDataIfNeeded(
        _ data: Data,
        maxFileSizeBytes: Int
    ) -> Data {
        guard data.count > maxFileSizeBytes else {
            return data
        }

        let newline = UInt8(ascii: "\n")
        let targetDropCount = max(data.count / 2, data.count - maxFileSizeBytes)
        let searchLimit = max(0, data.count - 1)

        var cutIndex: Int?
        if targetDropCount > 0,
           targetDropCount <= searchLimit,
           data[targetDropCount - 1] == newline {
            cutIndex = targetDropCount
        } else if targetDropCount < searchLimit,
                  let forwardNewline = data[targetDropCount..<searchLimit].firstIndex(of: newline) {
            cutIndex = forwardNewline + 1
        } else if targetDropCount > 0,
                  let backwardNewline = data[0..<min(targetDropCount, searchLimit)].lastIndex(of: newline),
                  backwardNewline + 1 <= data.count,
                  data.count - (backwardNewline + 1) <= maxFileSizeBytes {
            cutIndex = backwardNewline + 1
        }

        if let cutIndex, cutIndex < data.count {
            return Data(data[cutIndex...])
        }
        return Data(data.suffix(maxFileSizeBytes))
    }

    private static func parseLogFileDate(
        fromFileName fileName: String,
        timeZone: TimeZone
    ) -> Date? {
        let prefix = "cueseeker-"
        let suffix = ".log"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else {
            return nil
        }
        let datePart = String(
            fileName.dropFirst(prefix.count).dropLast(suffix.count)
        )
        guard datePart.count == 10 else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: datePart)
    }

    private static func dateString(
        for date: Date,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func timestampString(
        for date: Date,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private static func sanitizeSingleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
