import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func requestingVocabularyEntryCreationSelectsVocabularyModeAndPresentsEditor() async throws {
    try await withTemporaryVocabularyApp { app in
        #expect(app.workbenchLayout.panelMode == .search)
        #expect(!app.vocabulary.isAddVocabularyEntryEditorPresented)

        app.requestVocabularyEntryCreation()

        #expect(app.workbenchLayout.panelMode == .vocabulary)
        #expect(app.vocabulary.isAddVocabularyEntryEditorPresented)
    }
}

@MainActor
@Test
func addingVocabularyEntryPersistsEntryAndClosesEditor() async throws {
    try await withTemporaryVocabularyApp { app in
        app.requestVocabularyEntryCreation()

        let entry = try app.addVocabularyEntry(
            term: "  resonance  ",
            explanation: "  Continued sound after the source stops.  "
        )
        let database = try #require(app.subtitleDatabase)
        let persistedEntries = try database.vocabularyEntries()

        #expect(entry.term == "resonance")
        #expect(entry.explanation == "Continued sound after the source stops.")
        #expect(app.vocabulary.entries == persistedEntries)
        #expect(app.vocabulary.selectedEntryID == entry.id)
        #expect(!app.vocabulary.isAddVocabularyEntryEditorPresented)
    }
}

@MainActor
@Test
func applyingVocabularyEntriesSelectsNewestEntryWhenSelectionIsMissing() async throws {
    try await withTemporaryVocabularyApp { app in
        let database = try #require(app.subtitleDatabase)
        let older = try database.addVocabularyEntry(
            term: "older",
            explanation: "Older entry",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let newer = try database.addVocabularyEntry(
            term: "newer",
            explanation: "Newer entry",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        app.applyVocabularyEntries(try database.vocabularyEntries())

        #expect(app.vocabulary.entries.map(\.id) == [newer.id, older.id])
        #expect(app.vocabulary.selectedEntryID == newer.id)
    }
}

@Test
func vocabularyCreatedAtFormatterFailsExplicitlyForInvalidTimestamps() {
    #expect(VocabularyEntryCreatedAtFormatter.displayText(createdAt: "not-a-date") == "Failed to load")
}

@MainActor
@Test
func vocabularyExamplesDeriveFromMatchingShioris() async throws {
    try await withTemporaryVocabularyApp { app in
        let database = try #require(app.subtitleDatabase)
        let subtitleFile = URL(fileURLWithPath: "/Media/Show/Episode 1.srt")
        let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
        try database.replaceEntries(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:03,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 3_000,
                    text: "I felt resonance.\n共鳴を感じた。"
                ),
                SubtitleEntry(
                    sequenceNumber: 2,
                    startTimecode: "00:00:04,000",
                    endTimecode: "00:00:05,000",
                    startMilliseconds: 4_000,
                    endMilliseconds: 5_000,
                    text: "A quiet unrelated line."
                )
            ]
        )

        let matchingSelection = try #require(try database.cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: 1_500
        ))
        let unrelatedSelection = try #require(try database.cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: 4_500
        ))
        let matchingShiori = try database.upsertShiori(
            subtitleFile: subtitleFile,
            subtitleFormat: .srt,
            videoFile: videoFile,
            videoName: videoFile.lastPathComponent,
            selection: matchingSelection
        )
        _ = try database.upsertShiori(
            subtitleFile: subtitleFile,
            subtitleFormat: .srt,
            videoFile: videoFile,
            videoName: videoFile.lastPathComponent,
            selection: unrelatedSelection
        )
        let entry = try database.addVocabularyEntry(
            term: "RESONANCE",
            explanation: "Continued sound after the source stops."
        )

        let examples = VocabularyExampleDeriver.examples(
            for: entry,
            shioris: try database.shioris(),
            displayTitlesBySubtitlePath: [
                subtitleFile.path: "Show - 01"
            ]
        )

        #expect(examples.map(\.shiori.id) == [matchingShiori.id])
        #expect(examples[0].id == "\(entry.id)-\(matchingShiori.id)")
        #expect(examples[0].term == "RESONANCE")
        #expect(examples[0].sourceText == "Show - 01 · 00:01")
        #expect(examples[0].displayLines == ["I felt resonance.", "共鳴を感じた。"])
    }
}

@MainActor
@Test
func openingVocabularyExampleUsesAllVocabularyExamplesAsPlaylist() async throws {
    try await withTemporaryVocabularyApp { app in
        let database = try #require(app.subtitleDatabase)
        let subtitleFile = URL(fileURLWithPath: "/Media/Show/Episode 1.srt")
        let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
        try database.replaceEntries(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:03,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 3_000,
                    text: "I felt resonance."
                ),
                SubtitleEntry(
                    sequenceNumber: 2,
                    startTimecode: "00:00:04,000",
                    endTimecode: "00:00:06,000",
                    startMilliseconds: 4_000,
                    endMilliseconds: 6_000,
                    text: "The echo returned."
                )
            ]
        )

        let resonanceSelection = try #require(try database.cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: 1_500
        ))
        let echoSelection = try #require(try database.cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: 4_500
        ))
        _ = try database.upsertShiori(
            subtitleFile: subtitleFile,
            subtitleFormat: .srt,
            videoFile: videoFile,
            videoName: videoFile.lastPathComponent,
            selection: resonanceSelection
        )
        _ = try database.upsertShiori(
            subtitleFile: subtitleFile,
            subtitleFormat: .srt,
            videoFile: videoFile,
            videoName: videoFile.lastPathComponent,
            selection: echoSelection
        )
        _ = try database.addVocabularyEntry(
            term: "resonance",
            explanation: "Continued sound after the source stops.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        _ = try database.addVocabularyEntry(
            term: "echo",
            explanation: "A reflected sound.",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        app.shiori.shioris = try database.shioris()
        app.applyVocabularyEntries(try database.vocabularyEntries())
        let examples = VocabularyExampleDeriver.allExamples(
            for: app.vocabulary.entries,
            shioris: app.shiori.shioris,
            displayTitlesBySubtitlePath: [
                subtitleFile.path: "Show - 01"
            ]
        )
        let firstExample = try #require(examples.first)
        app.playback.activePlaybackDrawerKind = .subtitles

        app.openVocabularyExample(firstExample, playlist: examples)

        #expect(examples.count == 2)
        #expect(app.activePlaybackSource == .vocabulary)
        #expect(app.vocabulary.playbackExamples.map(\.id) == examples.map(\.id))
        #expect(app.vocabulary.selectedPlaybackExampleID == firstExample.id)
        #expect(app.shiori.selectedShiori?.id == firstExample.shiori.id)
        #expect(app.currentPlaybackVideoPath == videoFile.path)
        #expect(app.currentPlaybackSubtitlePath == subtitleFile.path)
        #expect(app.currentPlaybackDisplayTitle == "Show - 01")
        #expect(app.playback.activePlaybackDrawerKind == .subtitles)
        #expect(!app.playback.isPlaybackSidePanelVisible)
        #expect(app.playback.isPlaybackSurfaceExpanded)
        #expect(!app.canOpenPreviousVocabularyExample)
        #expect(app.canOpenNextVocabularyExample)

        app.openNextVocabularyExample()

        #expect(app.vocabulary.selectedPlaybackExampleID == examples[1].id)
        #expect(app.shiori.selectedShiori?.id == examples[1].shiori.id)
        #expect(app.canOpenPreviousVocabularyExample)
        #expect(!app.canOpenNextVocabularyExample)
        #expect(app.playback.activePlaybackDrawerKind == .subtitles)
        #expect(!app.playback.isPlaybackSidePanelVisible)

        app.openShiori(firstExample.shiori, recordsNavigationHistory: false)

        #expect(app.activePlaybackSource == .shiori)
        #expect(app.vocabulary.playbackExamples.isEmpty)
        #expect(app.vocabulary.selectedPlaybackExampleID == nil)
        await Task.yield()
        await Task.yield()
    }
}

@MainActor
private func withTemporaryVocabularyApp(
    _ body: @MainActor (AppCoordinator) async throws -> Void
) async throws {
    let suiteName = "CueSeekerVocabularyStoreTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVocabularyStoreTests-\(UUID().uuidString)")
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
    try #require(app.subtitleDatabase != nil)
    try await body(app)
}
