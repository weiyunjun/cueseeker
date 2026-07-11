import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@Test
func ankiTextHTMLPreservesAllLineEndingsEmptyLinesAndWhitespace() {
    let text = "  A&B  \r\n\r\n<B>\nC\rD\""

    #expect(
        AnkiPackageExporter._textHTMLForTesting(text)
            == "  A&amp;B  <br><br>&lt;B&gt;<br>C<br>D&quot;"
    )
    #expect(AnkiPackageExporter._textHTMLForTesting("\n") == "<br>")
    #expect(AnkiPackageExporter._textHTMLForTesting("") == "")
}

@Test
func ankiEntryMappingUsesExactPrimaryCueContent() {
    let searchContent = " search first \r\n\r\nsearch third "
    let result = SubtitleSearchResult(
        entryID: 10,
        cueGroupID: 20,
        cueEventIndex: 30,
        cueDisplayOrder: 1,
        subtitlePath: "/Media/Search.ass",
        subtitleFormat: .ass,
        videoPath: "/Media/Search.mkv",
        videoName: "Search",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: searchContent,
        cueLines: ["not the exact content"]
    )
    let shioriContent = " shiori first \n\nshiori third "
    let shiori = Shiori(
        id: 40,
        subtitlePath: "/Media/Shiori.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Shiori.mkv",
        videoName: "Shiori",
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        cueEventIndex: 50,
        cueDisplayOrder: 0,
        content: shioriContent,
        isValid: true,
        createdAt: "2026-07-12T00:00:00Z"
    )

    let searchItem = AppCoordinator.ankiExportItem(
        for: result,
        deckDisplayTitle: "Search Deck"
    )
    let shioriItem = AppCoordinator.ankiExportItem(
        for: shiori,
        deckDisplayTitle: "Shiori Deck"
    )

    #expect(searchItem.text == searchContent)
    #expect(shioriItem.text == shioriContent)
    #expect(searchItem.deckDisplayTitle == "Search Deck")
    #expect(shioriItem.deckDisplayTitle == "Shiori Deck")
}

@MainActor
@Test
func subtitleScreenshotEntryMappingCarriesCueOrderingIdentity() throws {
    _ = NSApplication.shared
    let suiteName = "CueSeekerExportMappingTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerExportMappingTests-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
    }
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let result = SubtitleSearchResult(
        entryID: 10,
        cueGroupID: 20,
        cueEventIndex: 30,
        cueDisplayOrder: 2,
        subtitlePath: "/Media/Search.ass",
        subtitleFormat: .ass,
        videoPath: "/Media/Search.mkv",
        videoName: "Search",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "Search Cue",
        cueLines: ["Search Cue"]
    )
    let shiori = Shiori(
        id: 40,
        subtitlePath: "/Media/Shiori.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Shiori.mkv",
        videoName: "Shiori",
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        cueEventIndex: 50,
        cueDisplayOrder: 3,
        content: "Shiori Cue",
        isValid: true,
        createdAt: "2026-07-12T00:00:00Z"
    )

    let searchItem = app.subtitleScreenshotItem(for: result)
    let shioriItem = app.subtitleScreenshotItem(
        for: shiori,
        displayTitle: "Shiori"
    )

    #expect(searchItem.cueEventIndex == 30)
    #expect(searchItem.cueDisplayOrder == 2)
    #expect(shioriItem.cueEventIndex == 50)
    #expect(shioriItem.cueDisplayOrder == 3)
}
