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
    let excerptContent = " excerpt first \n\nexcerpt third "
    let excerpt = Excerpt(
        id: 40,
        subtitlePath: "/Media/Excerpt.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Excerpt.mkv",
        videoName: "Excerpt",
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        cueEventIndex: 50,
        cueDisplayOrder: 0,
        content: excerptContent,
        isValid: true,
        createdAt: "2026-07-12T00:00:00Z"
    )

    let searchRow = SubtitleTableRow(
        id: 10,
        primaryCueID: 10,
        subtitlePath: "/Media/Search.ass",
        displayTitle: "Search Title",
        timeRange: "00:01 - 00:02",
        primaryCueText: searchContent,
        cueGroupTexts: ["search before", searchContent, "search after"],
        primaryGroupIndex: 1
    )
    let excerptRow = SubtitleTableRow(
        id: 40,
        primaryCueID: nil,
        subtitlePath: "/Media/Excerpt.srt",
        displayTitle: "Excerpt Title",
        timeRange: "00:03 - 00:04",
        primaryCueText: excerptContent,
        cueGroupTexts: [excerptContent],
        primaryGroupIndex: 0
    )

    let searchItem = AppCoordinator.ankiExportItem(
        for: result,
        row: searchRow,
        deckDisplayTitle: "Search Deck"
    )
    let excerptItem = AppCoordinator.ankiExportItem(
        for: excerpt,
        row: excerptRow,
        deckDisplayTitle: "Excerpt Deck"
    )

    #expect(searchItem.text == searchContent)
    #expect(excerptItem.text == excerptContent)
    #expect(searchItem.deckDisplayTitle == "Search Deck")
    #expect(excerptItem.deckDisplayTitle == "Excerpt Deck")
    // The card shows what the table row shows.
    #expect(searchItem.displayTitle == "Search Title")
    #expect(searchItem.timeRange == "00:01 - 00:02")
    #expect(searchItem.cueGroupOtherTexts == ["search before", "search after"])
    #expect(searchItem.cueID == 10)
    #expect(searchItem.subtitlePath == "/Media/Search.ass")
    #expect(excerptItem.displayTitle == "Excerpt Title")
    #expect(excerptItem.cueGroupOtherTexts.isEmpty)
    #expect(excerptItem.cueID == nil)
    #expect(excerptItem.videoPath == "/Media/Excerpt.mkv")
}

private func ankiCardItem(
    displayTitle: String = "Frieren S01E01",
    timeRange: String = "01:23 - 01:25",
    cueGroupOtherTexts: [String] = ["Line two", "Line <three>"],
    cueID: Int64? = 42
) -> AnkiExportItem {
    AnkiExportItem(
        deckDisplayTitle: "Frieren",
        videoPath: "/Videos/Frieren S01E01.mkv",
        startMilliseconds: 83_000,
        endMilliseconds: 85_000,
        text: "Cue",
        displayTitle: displayTitle,
        timeRange: timeRange,
        cueGroupOtherTexts: cueGroupOtherTexts,
        cueID: cueID,
        subtitlePath: "/Videos/Frieren S01E01.ja.srt"
    )
}

@Test
func ankiDetailLinesFollowTheCheckedItemsInOrder() {
    let options = AnkiExportOptions(
        cueTextSide: .back,
        optionalItems: Set(AnkiExportOptionalItem.allCases)
    )

    let fields = AnkiPackageExporter.detailFields(for: ankiCardItem(), options: options)

    #expect(fields.cueGroup == "Line two<br>Line &lt;three&gt;")
    #expect(fields.source == "Frieren S01E01&nbsp;&nbsp;01:23 - 01:25")
    let hrefs = fields.links
        .components(separatedBy: "<a href=\"")
        .dropFirst()
        .map { $0.prefix { $0 != "\"" } }
    #expect(hrefs == [
        "cueseeker://cue?id=42",
        "file:///Videos/Frieren%20S01E01.ja.srt",
        "file:///Videos/Frieren%20S01E01.mkv",
    ])
    #expect(fields.links.components(separatedBy: "</a>&nbsp;&nbsp;<a").count == 3)
    #expect(fields.links.contains("<svg"))
}

@Test
func ankiDetailLinesLeaveOutUncheckedAndEmptyItems() {
    let defaults = AnkiPackageExporter.detailFields(
        for: ankiCardItem(),
        options: AnkiExportOptions()
    )
    #expect(defaults.cueGroup.isEmpty)
    #expect(defaults.source.isEmpty)
    #expect(defaults.links.isEmpty)

    let everything = AnkiExportOptions(
        cueTextSide: .back,
        optionalItems: Set(AnkiExportOptionalItem.allCases)
    )
    let sparse = AnkiPackageExporter.detailFields(
        for: ankiCardItem(displayTitle: "", cueGroupOtherTexts: [], cueID: nil),
        options: everything
    )
    #expect(sparse.cueGroup.isEmpty)
    #expect(sparse.source == "01:23 - 01:25")
    #expect(!sparse.links.contains("cueseeker://"))
    #expect(sparse.links.components(separatedBy: "<a href=").count == 3)
}

@Test
func ankiCardTemplatesPutTheCueTextOnTheChosenSide() {
    let back = AnkiPackageExporter._cardTemplatesForTesting(cueTextSide: .back)
    #expect(back.question.contains("{{Audio}}"))
    #expect(back.question.contains("{{Image}}"))
    #expect(!back.question.contains("{{Text}}"))
    #expect(back.answer.hasPrefix("{{FrontSide}}"))
    #expect(back.answer.contains("{{Text}}"))

    let front = AnkiPackageExporter._cardTemplatesForTesting(cueTextSide: .front)
    #expect(front.question.contains("{{Text}}"))
    #expect(!front.question.contains("{{Audio}}"))
    #expect(front.answer.hasPrefix("{{FrontSide}}"))
    #expect(front.answer.contains("{{Audio}}"))
    #expect(front.answer.contains("{{Image}}"))

    // Top to bottom: Cue Text, Cue Group Text, Display Title with Time Range,
    // then the links; a line whose field is empty is not drawn.
    let textSide = front.question
    let order = ["{{Text}}", "{{#CueGroup}}", "{{#Source}}", "{{#Links}}"].compactMap {
        textSide.range(of: $0)?.lowerBound
    }
    #expect(order.count == 4)
    #expect(order == order.sorted())
}

/// Anki takes an incoming note type for an existing one with the same id, or
/// the next id up, when field and template names match; the two sides must
/// never be taken for each other.
@Test
func ankiNoteTypesOfTheTwoSidesCannotBeTakenForEachOther() {
    let back = AnkiPackageExporter._noteTypeForTesting(cueTextSide: .back)
    let front = AnkiPackageExporter._noteTypeForTesting(cueTextSide: .front)

    #expect(back.templateName != front.templateName)
    #expect(back.name != front.name)
    #expect(abs(back.id - front.id) > 1_000)
}

@MainActor
@Test
func ankiExportChoicesAreRememberedAcrossLaunches() throws {
    let suiteName = "CueSeekerAnkiExportSettingsTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

    let firstLaunch = SettingsStore(userDefaults: userDefaults)
    #expect(firstLaunch.ankiExportOptions == AnkiExportOptions(cueTextSide: .back, optionalItems: [.screenshot]))
    #expect(firstLaunch.ankiExportFolderPath == nil)

    firstLaunch.ankiExportOptions = AnkiExportOptions(
        cueTextSide: .front,
        optionalItems: [.deepLink, .timeRange]
    )
    firstLaunch.ankiExportFolderPath = "/Users/reader/Anki"

    let secondLaunch = SettingsStore(userDefaults: userDefaults)
    #expect(secondLaunch.ankiExportOptions == AnkiExportOptions(cueTextSide: .front, optionalItems: [.deepLink, .timeRange]))
    #expect(secondLaunch.ankiExportFolderPath == "/Users/reader/Anki")
}

@MainActor
@Test
func ankiExportSessionNamesThePackageAndChecksTheName() {
    var reportedOptions: [AnkiExportOptions] = []
    let session = AnkiExportSession(
        items: [ankiCardItem()],
        options: AnkiExportOptions(),
        folderURL: URL(fileURLWithPath: "/Exports", isDirectory: true),
        onOptionsChange: { reportedOptions.append($0) }
    )

    #expect(session.fileName.hasPrefix("CueSeeker-"))
    #expect(session.destinationURL.lastPathComponent == session.fileName)

    session.fileName = "Deck"
    #expect(session.destinationURL.path == "/Exports/Deck.apkg")
    session.fileName = "Deck.APKG"
    #expect(session.destinationURL.path == "/Exports/Deck.APKG")

    session.fileName = " "
    #expect(!session.validate())
    #expect(session.validationMessage == L("rename.validation.empty"))
    session.fileName = "Deck/1"
    #expect(!session.validate())
    #expect(session.validationMessage == L("rename.validation.invalid"))
    session.fileName = "Deck"
    #expect(session.validate())
    #expect(session.validationMessage == nil)

    session.options.toggle(.deepLink)
    session.options.cueTextSide = .front
    #expect(reportedOptions.last == AnkiExportOptions(cueTextSide: .front, optionalItems: [.screenshot, .deepLink]))
}

@MainActor
@Test
func subtitleScreenshotEntryMappingCarriesCueOrderingIdentity() throws {
    _ = NSApplication.shared
    let suiteName = "CueSeekerExportMappingTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerExportMappingTests-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
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
    let excerpt = Excerpt(
        id: 40,
        subtitlePath: "/Media/Excerpt.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Excerpt.mkv",
        videoName: "Excerpt",
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        cueEventIndex: 50,
        cueDisplayOrder: 3,
        content: "Excerpt Cue",
        isValid: true,
        createdAt: "2026-07-12T00:00:00Z"
    )

    let searchItem = app.subtitleScreenshotItem(for: result)
    let excerptItem = app.subtitleScreenshotItem(
        for: excerpt,
        displayTitle: "Excerpt"
    )

    #expect(searchItem.cueEventIndex == 30)
    #expect(searchItem.cueDisplayOrder == 2)
    #expect(excerptItem.cueEventIndex == 50)
    #expect(excerptItem.cueDisplayOrder == 3)
}
