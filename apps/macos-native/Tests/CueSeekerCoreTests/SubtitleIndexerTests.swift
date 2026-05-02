import Foundation
import Testing
import CueSeekerCore

@Test
func indexesFolderIntoSQLiteSearchDatabase() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Movie.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Hello searchable world.

        2
        00:00:04,000 --> 00:00:06,000
        Another indexed line.

        """
    )
    try fixture.writeVideo(name: "Movie.mkv")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 1)
    #expect(result.indexedSubtitleFiles == 1)
    #expect(result.indexedSubtitleEntries == 2)
    #expect(result.skippedMissingVideo == 0)

    let searchResults = try database.search("searchable")
    #expect(searchResults.count == 1)
    #expect(searchResults[0].videoName == "Movie.mkv")
    #expect(searchResults[0].startMilliseconds == 1_000)

    let subtitleFiles = try database.subtitleFiles()
    #expect(subtitleFiles.count == 1)
    #expect(subtitleFiles[0].subtitlePath.hasSuffix("Movie.srt"))
    #expect(subtitleFiles[0].videoName == "Movie.mkv")
}

@Test
func skipsSubtitleFileWhenMatchingVideoIsMissing() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "MissingVideo.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        This should not be indexed.

        """
    )

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 1)
    #expect(result.indexedSubtitleFiles == 0)
    #expect(result.indexedSubtitleEntries == 0)
    #expect(result.skippedMissingVideo == 1)
    #expect(try database.search("indexed").isEmpty)
}

@Test
func reindexingFolderRemovesStaleSubtitleEntries() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let subtitleURL = try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Old searchable text.

        """
    )
    try fixture.writeVideo(name: "Episode.mp4")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    _ = try indexer.index(folder: fixture.root, into: database)
    #expect(try database.search("Old").count == 1)

    try FileManager.default.removeItem(at: subtitleURL)

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 0)
    #expect(result.indexedSubtitleFiles == 0)
    #expect(try database.search("Old").isEmpty)
    #expect(try database.subtitleFiles().isEmpty)
}

@Test
func reindexingFolderReplacesChangedSubtitleContent() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Old searchable text.

        """
    )
    try fixture.writeVideo(name: "Episode.mp4")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    _ = try indexer.index(folder: fixture.root, into: database)

    try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:09,000 --> 00:00:11,000
        Fresh searchable text.

        """
    )

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.indexedSubtitleEntries == 1)
    #expect(try database.search("Old").isEmpty)

    let freshResults = try database.search("Fresh")
    #expect(freshResults.count == 1)
    #expect(freshResults[0].startMilliseconds == 9_000)
}

@Test
func reindexingUnchangedSubtitleFileSkipsRewrite() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Stable searchable text.

        """
    )
    try fixture.writeVideo(name: "Episode.mp4")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let initialResult = try indexer.index(folder: fixture.root, into: database)
    let unchangedResult = try indexer.index(folder: fixture.root, into: database)

    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(unchangedResult.scannedSubtitleFiles == 1)
    #expect(unchangedResult.indexedSubtitleFiles == 0)
    #expect(unchangedResult.indexedSubtitleEntries == 0)
    #expect(unchangedResult.skippedUnchangedSubtitleFiles == 1)

    let searchResults = try database.search("Stable")
    #expect(searchResults.count == 1)
    #expect(searchResults[0].content == "Stable searchable text.")
}

@Test
func indexesASSFilesAsGroupedCueResults() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Movie.scjp.ass",
        contents: """
        [Script Info]
        PlayResX: 1920
        PlayResY: 1080

        [V4+ Styles]
        Format: Name, Alignment, MarginL, MarginR, MarginV
        Style: Top,8,20,20,40
        Style: Bottom,2,20,20,30

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.00,Bottom,,0,0,0,,English line
        Dialogue: 0,0:00:01.00,0:00:03.00,Top,,0,0,0,,日本語ライン
        Dialogue: 0,0:00:04.00,0:00:06.00,Bottom,,0,0,0,,Another line
        """
    )
    try fixture.writeVideo(name: "Movie.mkv")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 1)
    #expect(result.indexedSubtitleFiles == 1)
    #expect(result.indexedSubtitleEntries == 2)

    let searchResults = try database.search("English")
    #expect(searchResults.count == 1)
    #expect(searchResults[0].subtitleFormat == .ass)
    #expect(searchResults[0].videoName == "Movie.mkv")
    #expect(searchResults[0].cueLines == ["日本語ライン", "English line"])
    #expect(searchResults[0].startMilliseconds == 1_000)
}

private struct IndexingFixture {
    let root: URL
    let databaseURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerIndexerTests-\(UUID().uuidString)")
        databaseURL = root.appendingPathComponent("index.sqlite")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @discardableResult
    func writeSubtitle(name: String, contents: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @discardableResult
    func writeVideo(name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data().write(to: url)
        return url
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
