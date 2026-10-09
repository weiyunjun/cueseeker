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
    videoPath: String = "/Videos/Frieren S01E01.mkv",
    displayTitle: String = "Frieren S01E01",
    timeRange: String = "01:23 - 01:25",
    cueGroupOtherTexts: [String] = ["Line two", "Line <three>"],
    cueID: Int64? = 42
) -> AnkiExportItem {
    AnkiExportItem(
        deckDisplayTitle: "Frieren",
        videoPath: videoPath,
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
        frontItems: [.screenshot, .audio],
        backItems: [.cueText, .cueGroupText, .displayTitle, .timeRange, .deepLink]
    )

    let fields = AnkiPackageExporter.detailFields(for: ankiCardItem(), options: options)

    #expect(fields.cueGroup == "Line two<br>Line &lt;three&gt;")
    #expect(fields.displayTitle == "Frieren S01E01")
    #expect(fields.timeRange == "01:23 - 01:25")
    #expect(fields.deepLink.contains("cueseeker://cue?id=42"))
    #expect(fields.deepLink.contains("<svg"))
}

@Test
func ankiDetailLinesLeaveOutUncheckedAndEmptyItems() {
    let defaults = AnkiPackageExporter.detailFields(
        for: ankiCardItem(),
        options: AnkiExportOptions()
    )
    #expect(defaults.cueGroup.isEmpty)
    #expect(defaults.displayTitle.isEmpty)
    #expect(defaults.timeRange.isEmpty)
    #expect(defaults.deepLink.isEmpty)

    let everything = AnkiExportOptions(
        frontItems: AnkiCardItem.allCases,
        backItems: []
    )
    let sparse = AnkiPackageExporter.detailFields(
        for: ankiCardItem(displayTitle: "", cueGroupOtherTexts: [], cueID: nil),
        options: everything
    )
    #expect(sparse.cueGroup.isEmpty)
    #expect(sparse.displayTitle.isEmpty)
    #expect(sparse.timeRange == "01:23 - 01:25")
    #expect(sparse.deepLink.isEmpty)
}

@Test
func ankiCardTemplatesPutItemsOnTheChosenSidesInOrder() {
    let options = AnkiExportOptions(
        frontItems: [.displayTitle, .audio],
        backItems: [.cueText, .screenshot]
    )
    let templates = AnkiPackageExporter._cardTemplatesForTesting(options: options)
    #expect(templates.question.contains("{{DisplayTitle}}"))
    #expect(templates.question.contains("{{Audio}}"))
    #expect(!templates.question.contains("{{Text}}"))
    #expect(!templates.question.contains("{{Image}}"))
    #expect(templates.answer.hasPrefix("{{FrontSide}}"))
    #expect(templates.answer.contains("{{Text}}"))
    #expect(templates.answer.contains("{{Image}}"))

    let titleRange = templates.question.range(of: "{{DisplayTitle}}")!.lowerBound
    let audioRange = templates.question.range(of: "{{Audio}}")!.lowerBound
    #expect(titleRange < audioRange)
}

@Test
func ankiNoteTypesOfDifferentLayoutsHaveDistinctIDs() {
    let options1 = AnkiExportOptions(frontItems: [.audio], backItems: [.cueText])
    let options2 = AnkiExportOptions(frontItems: [.cueText], backItems: [.audio])

    let type1 = AnkiPackageExporter._noteTypeForTesting(options: options1)
    let type2 = AnkiPackageExporter._noteTypeForTesting(options: options2)

    #expect(type1.id != type2.id)
}

@MainActor
@Test
func ankiExportChoicesAreRememberedAcrossLaunches() throws {
    let suiteName = "CueSeekerAnkiExportSettingsTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

    let firstLaunch = SettingsStore(userDefaults: userDefaults)
    #expect(firstLaunch.ankiExportOptions == AnkiExportOptions(frontItems: [.audio], backItems: [.cueText]))
    #expect(firstLaunch.ankiExportFolderPath == nil)

    firstLaunch.ankiExportOptions = AnkiExportOptions(
        frontItems: [.cueText, .displayTitle],
        backItems: [.audio, .deepLink]
    )
    firstLaunch.ankiExportFolderPath = "/Users/reader/Anki"

    let secondLaunch = SettingsStore(userDefaults: userDefaults)
    #expect(secondLaunch.ankiExportOptions == AnkiExportOptions(
        frontItems: [.cueText, .displayTitle],
        backItems: [.audio, .deepLink]
    ))
    #expect(secondLaunch.ankiExportFolderPath == "/Users/reader/Anki")
}

@MainActor
@Test
func ankiExportSessionNamesThePackageAndChecksTheNameAndSides() {
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

    // Layout validation: empty Front or Back
    session.options.frontItems = []
    #expect(!session.validate())
    #expect(session.frontValidationError == L("anki_export.validation.front_empty"))

    session.moveItem(.audio, to: .front, at: 0)
    #expect(session.frontValidationError == nil)
    #expect(session.options.frontItems == [.audio])

    session.options.backItems = []
    #expect(!session.validate())
    #expect(session.backValidationError == L("anki_export.validation.back_empty"))

    session.moveItem(.cueText, to: .back, at: 0)
    #expect(session.backValidationError == nil)
    #expect(session.options.backItems == [.cueText])
    #expect(session.validate())
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

@Test
func ankiExportResolvesDefaultAudioTracksInBackground() throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerAnkiAudioTrackTests-\(UUID().uuidString).sqlite")
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let indexing = try IndexingDatabase(path: databaseURL)
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode.mkv")
    try indexing.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode.srt"),
        videoFile: videoFile,
        entries: [SubtitleEntry(
            sequenceNumber: 1,
            startTimecode: "00:00:01,000",
            endTimecode: "00:00:02,000",
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            text: "Audio tracks"
        )]
    )
    let library = try LibraryDatabase(path: databaseURL)
    let tracks = [
        VideoAudioTrack(language: "jpn", title: nil, codec: "opus", channels: 2),
        VideoAudioTrack(language: "eng", title: "Commentary", codec: "aac", channels: 6),
    ]
    try library.updateVideoMetadata(
        videoFile: videoFile,
        duration: 120,
        videoWidth: 1920,
        videoHeight: 1080,
        frameRate: 24,
        videoCodec: "h264",
        audioTracks: tracks
    )
    try library.setDefaultAudioTrackIndex(1, forVideoFile: videoFile)

    let item = ankiCardItem(videoPath: videoFile.path)
    #expect(item.audioTrackIndex == 0)

    let resolved = AppCoordinator.resolveDefaultAudioTracks(in: [item], using: library)
    #expect(resolved.count == 1)
    #expect(resolved[0].audioTrackIndex == 1)
}
