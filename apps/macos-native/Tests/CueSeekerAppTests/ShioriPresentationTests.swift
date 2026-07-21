import AppKit
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func removeShioriDoesNotHydrateLegacyPresentationWhenTableOnly() throws {
    let suiteName = "CueSeekerShioriPresentationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerShioriPresentationTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerShioriPresentationTests.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.subtitleDatabase)
    let first = try makeShiori(
        in: database,
        id: 1,
        content: "first saved cue"
    )
    _ = try makeShiori(
        in: database,
        id: 2,
        content: "second saved cue"
    )

    #expect(try database.shioriCount() == 2)
    #expect(app.shiori.residentRelations.isEmpty)

    #expect(app.removeShiori(first, reloadPresentation: true))

    #expect(try database.shioriCount() == 1)
    #expect(app.shiori.residentRelations.isEmpty)
    #expect(!app.shiori.tableHasLoadedInitialPage)
}

private func makeShiori(
    in database: SubtitleDatabase,
    id: Int,
    content: String
) throws -> Shiori {
    let subtitleFile = URL(fileURLWithPath: "/Media/Shiori-\(id).srt")
    let videoFile = URL(fileURLWithPath: "/Media/Shiori-\(id).mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: content
            )
        ]
    )
    let selection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    return try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: "Shiori-\(id).mkv",
        selection: selection
    )
}
