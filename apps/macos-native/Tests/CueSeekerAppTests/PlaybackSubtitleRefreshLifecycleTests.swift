import AppKit
import Foundation
import Testing
import CueSeekerCore
import CueSeekerPlayback
@testable import CueSeekerApp

@MainActor
@Test
func playbackSRTSourceCarriesSpeakerDisplayCues() async throws {
    try await withTemporarySubtitleRefreshApp { app, database in
        let subtitleFile = URL(fileURLWithPath: "/Media/Speaker.srt")
        try database.replaceEntries(
            subtitleFile: subtitleFile,
            videoFile: URL(fileURLWithPath: "/Media/Speaker.mkv"),
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:02,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000,
                    text: "speaker first"
                )
            ]
        )
        let searchDatabase = try #require(app.searchDatabase)
        let result = try #require(
            try searchDatabase.searchPage("speaker", limit: 1).results.first
        )
        let playbackDatabase = try #require(app.playbackSubtitleDatabase)
        let line = try #require(
            try playbackDatabase.cueLineRecords(forSubtitleFile: subtitleFile).first
        )
        try database.replaceCueLineSpeakers(
            forSubtitleFile: subtitleFile,
            assignments: [
                SubtitleCueLineSpeakerAssignment(
                    cueLineID: line.id,
                    speakers: ["疑似高松灯", "长崎素世"]
                )
            ]
        )
        app.settings.playbackSpeakerDisplayEnabled = true

        let source = try #require(app.playbackSubtitleSource(for: result))

        #expect(source.format == .srt)
        #expect(source.speakerDisplayCues.first?.cleanText == "speaker first")
        #expect(source.speakerDisplayCues.first?.speakers == ["疑似高松灯", "长崎素世"])
    }
}

@MainActor
private func withTemporarySubtitleRefreshApp(
    _ body: @MainActor (AppCoordinator, IndexingDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerSubtitleRefreshTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSubtitleRefreshTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    try await body(app, database)
}
