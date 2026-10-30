import Foundation
import Testing
@testable import CueSeekerCore

@Suite("AppLogger Tests")
struct AppLoggerTests {
    @Test
    func defaultLogDirectorySeparatesDebugAndReleaseConfigurations() {
        let fakeHome = URL(fileURLWithPath: "/Users/testuser", isDirectory: true)
        let debugURL = AppLogger.defaultLogDirectoryURL(
            for: .debug,
            homeDirectoryURL: fakeHome
        )
        let releaseURL = AppLogger.defaultLogDirectoryURL(
            for: .release,
            homeDirectoryURL: fakeHome
        )

        #expect(debugURL.path == "/Users/testuser/Library/Application Support/CueSeeker/logs/debug")
        #expect(releaseURL.path == "/Users/testuser/Library/Application Support/CueSeeker/logs/release")
        #expect(AppLogger.shared.isEnabled == false)
    }

    @Test
    func dailyLogFileNameAndStructuredSingleLineFormatting() throws {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = try #require(TimeZone(secondsFromGMT: 8 * 3600))
        calendar.timeZone = timeZone

        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 10,
            day: 30,
            hour: 14,
            minute: 23,
            second: 1,
            nanosecond: 105_000_000
        )
        let timestamp = try #require(components.date)

        #expect(
            AppLogger.logFileName(for: timestamp, calendar: calendar)
                == "cueseeker-2026-10-30.log"
        )

        let line = AppLogger.formatLine(
            level: .info,
            category: .app,
            message: "App launched\nwith newline",
            details: AppLogger.formatFields([
                ("version", "1.2.0"),
                ("file", "Episode 01.mkv"),
                ("ignored", nil)
            ]),
            timestamp: timestamp,
            timeZone: timeZone
        )

        #expect(
            line == "2026-10-30 14:23:01.105 [INFO] [App] App launched with newline | version=1.2.0 file=\"Episode 01.mkv\""
        )
    }

    @Test
    func minimumLevelFilteringForReleaseAndDebug() throws {
        let baseTempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeeker-AppLoggerTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: baseTempURL)
        }

        let releaseDirURL = baseTempURL.appendingPathComponent("release", isDirectory: true)
        let releaseLogger = AppLogger(
            logDirectoryURL: releaseDirURL,
            minimumLevel: .info,
            isEnabled: true
        )
        releaseLogger.debug(.playback, "Player seek requested", details: "target_ms=1000")
        releaseLogger.info(.app, "App launched", details: "config=release")
        releaseLogger.warn(.playback, "Hardware decode fallback", details: "file=\"test.mkv\"")
        releaseLogger.error(.database, "Database query failed", details: "code=1")
        releaseLogger.flush()

        let releaseLines = try String(contentsOf: releaseLogger.logFileURL(), encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        #expect(releaseLines.count == 3)
        #expect(releaseLines[0].contains("[INFO] [App] App launched | config=release"))
        #expect(releaseLines[1].contains("[WARN] [Playback] Hardware decode fallback | file=\"test.mkv\""))
        #expect(releaseLines[2].contains("[ERROR] [Database] Database query failed | code=1"))

        let debugDirURL = baseTempURL.appendingPathComponent("debug", isDirectory: true)
        let debugLogger = AppLogger(
            logDirectoryURL: debugDirURL,
            minimumLevel: .debug,
            isEnabled: true
        )
        debugLogger.debug(.playback, "Player seek requested", details: "target_ms=1000")
        debugLogger.info(.search, "Search completed", details: "query=\"hello\" results=12")
        debugLogger.info(.excerpt, "Cue saved to excerpt", details: "list=\"Favorites\"")
        debugLogger.info(.library, "Library overview loaded", details: "folders=5")
        debugLogger.info(.task, "Task completed", details: "type=add_folder")
        debugLogger.warn(.network, "WebDAV redirect warning", details: "host=nas.local")
        debugLogger.error(.export, "Anki export failed", details: "reason=io")
        debugLogger.info(.system, "Controller connected", details: "vendor=\"DualSense\"")
        debugLogger.flush()

        let debugLines = try String(contentsOf: debugLogger.logFileURL(), encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        #expect(debugLines.count == 8)
        #expect(debugLines[0].contains("[DEBUG] [Playback] Player seek requested"))
        #expect(debugLines[1].contains("[INFO] [Search] Search completed | query=\"hello\" results=12"))
        #expect(debugLines[2].contains("[INFO] [Excerpt] Cue saved to excerpt | list=\"Favorites\""))
        #expect(debugLines[3].contains("[INFO] [Library] Library overview loaded | folders=5"))
        #expect(debugLines[4].contains("[INFO] [Task] Task completed"))
        #expect(debugLines[5].contains("[WARN] [Network] WebDAV redirect warning"))
        #expect(debugLines[6].contains("[ERROR] [Export] Anki export failed"))
        #expect(debugLines[7].contains("[INFO] [System] Controller connected"))
    }

    @Test
    func trimsOldestLinesWhenMaxFileSizeIsExceeded() throws {
        let tempDirURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeeker-AppLoggerTrim-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirURL)
        }

        let sampleLine = AppLogger.formatLine(
            level: .info,
            category: .task,
            message: "Step finished",
            details: "index=1"
        )
        let singleLineBytes = sampleLine.utf8.count + 1
        let logger = AppLogger(
            logDirectoryURL: tempDirURL,
            minimumLevel: .info,
            maxFileSizeBytes: singleLineBytes * 3,
            isEnabled: true
        )

        for index in 1...4 {
            logger.info(.task, "Step finished", details: "index=\(index)")
        }
        logger.flush()

        let logURL = logger.logFileURL()
        let data = try Data(contentsOf: logURL)
        #expect(data.count <= singleLineBytes * 3)

        let lines = try String(contentsOf: logURL, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        #expect(lines.count == 2)
        #expect(lines[0].contains("index=3"))
        #expect(lines[1].contains("index=4"))
    }

    @Test
    func startupMaintenanceRemovesLogsOlderThanRetentionWindowAndLegacyCollageLog() throws {
        let baseLogsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeeker-AppLoggerRetention-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: baseLogsURL)
        }

        let releaseDirURL = baseLogsURL.appendingPathComponent("release", isDirectory: true)
        try FileManager.default.createDirectory(
            at: releaseDirURL,
            withIntermediateDirectories: true
        )

        var calendar = Calendar(identifier: .gregorian)
        let timeZone = try #require(TimeZone(secondsFromGMT: 0))
        calendar.timeZone = timeZone

        let now = try #require(
            DateComponents(
                calendar: calendar,
                timeZone: timeZone,
                year: 2026,
                month: 10,
                day: 30,
                hour: 10,
                minute: 0
            ).date
        )

        let expiredFileURL = releaseDirURL.appendingPathComponent("cueseeker-2026-10-15.log")
        let boundaryKeptFileURL = releaseDirURL.appendingPathComponent("cueseeker-2026-10-16.log")
        let todayFileURL = releaseDirURL.appendingPathComponent("cueseeker-2026-10-30.log")
        let legacyCollageFileURL = baseLogsURL.appendingPathComponent(AppLogger.legacyCollageLogFileName)

        for fileURL in [expiredFileURL, boundaryKeptFileURL, todayFileURL, legacyCollageFileURL] {
            try Data("test\n".utf8).write(to: fileURL)
        }

        let logger = AppLogger(
            logDirectoryURL: releaseDirURL,
            minimumLevel: .info,
            retentionDays: 14,
            calendar: calendar,
            isEnabled: true
        )
        logger.performStartupMaintenance(now: now)
        logger.flush()

        #expect(!FileManager.default.fileExists(atPath: expiredFileURL.path))
        #expect(FileManager.default.fileExists(atPath: boundaryKeptFileURL.path))
        #expect(FileManager.default.fileExists(atPath: todayFileURL.path))
        #expect(!FileManager.default.fileExists(atPath: legacyCollageFileURL.path))
    }
}
