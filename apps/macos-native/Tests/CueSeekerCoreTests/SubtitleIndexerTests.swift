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

@Test
func assRenderSegmenterBuildsWindowedScriptsWithOverlappingEvents() throws {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default,Arial,48

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:25.00,0:00:35.00,Default,,0,0,0,fx,{\\blur2}overlap
    Dialogue: 0,0:01:05.00,0:01:06.00,Default,,0,0,0,,late
    """

    let segments = ASSRenderSegmenter.renderSegments(from: contents)

    #expect(segments.count == 2)
    #expect(segments[0].startMilliseconds == 0)
    #expect(segments[0].endMilliseconds == 60_000)
    #expect(segments[0].eventCount == 1)
    #expect(segments[0].scriptText.contains("overlap"))
    #expect(segments[1].eventCount == 1)
    #expect(segments[1].scriptText.contains("late"))
    #expect(segments[1].scriptText.contains("[V4+ Styles]"))
}

@Test
func assRenderSegmenterUsesComplexityBudgetForDenseEffects() throws {
    let denseLines = (0..<1_600)
        .map { index in
            "Dialogue: 0,0:01:25.00,0:02:55.00,Default,,0,0,0,,{\\p1\\clip(m 0 0 l 80 0 80 20 0 20)\\t(0,1000,\\blur8\\alpha&H80&)}m 0 0 l 80 0 80 20 0 20 dense-\(index)"
        }
        .joined(separator: "\n")
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default,Arial,48

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:05.00,0:00:06.00,Default,,0,0,0,,plain
    \(denseLines)
    Dialogue: 0,0:03:05.00,0:03:06.00,Default,,0,0,0,,late
    """

    let segments = ASSRenderSegmenter.renderSegments(from: contents)

    #expect(ASSRenderSegmenter.shouldSegment(format: .ass, fileSize: 256 * 1024))
    #expect(!ASSRenderSegmenter.shouldSegment(format: .ass, fileSize: 256 * 1024 - 1))
    #expect(!ASSRenderSegmenter.shouldSegment(format: .srt, fileSize: 512 * 1024))
    #expect(segments.first?.startMilliseconds == 0)
    #expect(segments.first?.endMilliseconds == 60_000)
    #expect(segments.contains { $0.startMilliseconds == 85_000 && $0.endMilliseconds == 90_000 })
    #expect(segments.contains { $0.startMilliseconds == 170_000 && $0.endMilliseconds == 175_000 })
    #expect(segments.first { $0.startMilliseconds == 85_000 }?.scriptText.contains("dense-0") == true)
    #expect(segments.last?.scriptText.contains("late") == true)
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
