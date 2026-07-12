import Foundation
import SQLite3
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
func indexingPrefersCompleteBasenameMatchAndStoresOneAssociation() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.reference-track.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Complete basename priority.

        """
    )
    let exactVideo = try fixture.writeVideo(name: "Episode.reference-track.mkv")
    _ = try fixture.writeVideo(name: "Episode.mp4")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let result = try SubtitleIndexer().index(folder: fixture.root, into: database)
    let subtitleFiles = try database.subtitleFiles()
    let searchResults = try database.search("priority")
    let storedVideo = URL(
        fileURLWithPath: try #require(subtitleFiles.first?.videoPath)
    ).resolvingSymlinksInPath()
    let searchedVideo = URL(
        fileURLWithPath: try #require(searchResults.first?.videoPath)
    ).resolvingSymlinksInPath()

    #expect(result.indexedSubtitleFiles == 1)
    #expect(subtitleFiles.count == 1)
    #expect(storedVideo == exactVideo.resolvingSymlinksInPath())
    #expect(searchResults.count == 1)
    #expect(searchedVideo == exactVideo.resolvingSymlinksInPath())
}

@Test
func reindexingSwitchesFromFallbackToCompleteBasenameMatch() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.reference-track.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Deterministic rematching.

        """
    )
    let fallbackVideo = try fixture.writeVideo(name: "Episode.mp4")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let initialResult = try indexer.index(folder: fixture.root, into: database)
    let initialFiles = try database.subtitleFiles()

    let exactVideo = try fixture.writeVideo(name: "Episode.reference-track.mkv")
    let rematchedResult = try indexer.index(folder: fixture.root, into: database)
    let rematchedFiles = try database.subtitleFiles()
    let initialVideo = URL(
        fileURLWithPath: try #require(initialFiles.first?.videoPath)
    ).resolvingSymlinksInPath()
    let rematchedVideo = URL(
        fileURLWithPath: try #require(rematchedFiles.first?.videoPath)
    ).resolvingSymlinksInPath()

    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(initialFiles.count == 1)
    #expect(initialVideo == fallbackVideo.resolvingSymlinksInPath())
    #expect(rematchedResult.indexedSubtitleFiles == 1)
    #expect(rematchedResult.skippedUnchangedSubtitleFiles == 0)
    #expect(rematchedFiles.count == 1)
    #expect(rematchedVideo == exactVideo.resolvingSymlinksInPath())
}

@Test
func indexingSRTStoresLanguageAnalysisAfterVideoMatch() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Japanese.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        今日はみんなで映画を見に行きます。

        2
        00:00:04,000 --> 00:00:06,000
        明日は学校のあとで友達と話します。

        """
    )
    try fixture.writeVideo(name: "Japanese.mkv")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.indexedSubtitleFiles == 1)
    let indexedSubtitlePath = try #require(try database.subtitleFiles().first?.subtitlePath)
    let indexedSubtitleURL = URL(fileURLWithPath: indexedSubtitlePath)
    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: indexedSubtitleURL))

    let detections = try database.languageDetections(forSubtitleFile: indexedSubtitleURL)
    #expect(detections.count == 1)
    let detection = try #require(detections.first)
    #expect(detection.scope == .file)
    #expect(detection.languages == [.japanese])

    let storedEntries = try database.entries(forSubtitleFile: indexedSubtitleURL)
    let firstEntry = try #require(storedEntries.first)
    let secondEntry = try #require(storedEntries.dropFirst().first)
    let languagesByCueGroupID = try database.cueGroupLanguages(forSubtitleFile: indexedSubtitleURL)
    #expect(languagesByCueGroupID[firstEntry.id] == [.japanese])
    #expect(languagesByCueGroupID[secondEntry.id] == [.japanese])
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
func reindexingUnchangedSubtitleFileRefreshesVideoFileMetadata() throws {
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
    let videoURL = try fixture.writeVideo(name: "Episode.mp4")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    _ = try indexer.index(folder: fixture.root, into: database)
    try Data(repeating: 0x42, count: 16).write(to: videoURL)

    let unchangedResult = try indexer.index(folder: fixture.root, into: database)
    let coverVideos = try database.libraryCoverEligibleVideos(under: [fixture.root])
    let coverVideo = try #require(coverVideos.first)

    #expect(unchangedResult.skippedUnchangedSubtitleFiles == 1)
    #expect(coverVideo.fileSize == 16)
}

@Test
func reindexingUnchangedSubtitleFileWithoutLanguageManifestRewritesOnce() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let contents = """
    1
    00:00:01,000 --> 00:00:03,000
    今日はみんなで映画を見に行きます。

    """
    _ = try fixture.writeSubtitle(name: "Episode.srt", contents: contents)
    _ = try fixture.writeVideo(name: "Episode.mp4")
    let scannedSubtitleURL = try #require(SubtitleFileScanner().scanSubtitleFiles(in: fixture.root).first)
    let videoURL = try #require(VideoMatcher().matchingVideo(for: scannedSubtitleURL))
    let metadata = try fixture.subtitleFileMetadata(for: scannedSubtitleURL)

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    try database.migrate()
    try database.replaceEntries(
        subtitleFile: scannedSubtitleURL,
        videoFile: videoURL,
        entries: SRTParser.parse(contents),
        fileSize: metadata.fileSize,
        modifiedAt: metadata.modifiedAt
    )

    #expect(try !database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: scannedSubtitleURL))

    let indexer = SubtitleIndexer()
    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 1)
    #expect(result.indexedSubtitleFiles == 1)
    #expect(result.skippedUnchangedSubtitleFiles == 0)
    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: scannedSubtitleURL))
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
    #expect(searchResults[0].cueLines == ["English line"])
    #expect(searchResults[0].cueGroupLines == ["日本語ライン", "English line"])
    #expect(searchResults[0].startMilliseconds == 1_000)

    let kanaResults = try database.search("ライン")
    #expect(kanaResults.count == 1)
    #expect(kanaResults[0].subtitleFormat == .ass)
    #expect(kanaResults[0].cueLines == ["日本語ライン"])
    #expect(kanaResults[0].cueGroupLines == ["日本語ライン", "English line"])
}

@Test
func indexingASSStoresUsedStyleLanguageAnalysisOnly() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Bilingual.ass",
        contents: """
        [Script Info]
        PlayResX: 1920
        PlayResY: 1080

        [V4+ Styles]
        Format: Name, Alignment, MarginL, MarginR, MarginV
        Style: JP,2,20,20,30
        Style: CN,8,20,20,40
        Style: Unused,2,20,20,30

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.00,JP,,0,0,0,,今日はライブの準備をします
        Dialogue: 0,0:00:01.00,0:00:03.00,CN,,0,0,0,,我们今天准备演出，大家一起学习新的歌曲。
        Dialogue: 0,0:00:04.00,0:00:06.00,JP,,0,0,0,,明日はスタジオで練習します
        """
    )
    try fixture.writeVideo(name: "Bilingual.mkv")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.indexedSubtitleFiles == 1)
    let indexedSubtitlePath = try #require(try database.subtitleFiles().first?.subtitlePath)
    let indexedSubtitleURL = URL(fileURLWithPath: indexedSubtitlePath)
    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: indexedSubtitleURL))

    let detections = try database.languageDetections(forSubtitleFile: indexedSubtitleURL)
    #expect(detections.map(\.scopeKey) == ["CN", "JP"])
    #expect(detections.first { $0.scopeKey == "CN" }?.languages == [.simplifiedChinese])
    #expect(detections.first { $0.scopeKey == "JP" }?.languages == [.japanese])

    let storedEntries = try database.entries(forSubtitleFile: indexedSubtitleURL)
    let firstEntry = try #require(storedEntries.first)
    let secondEntry = try #require(storedEntries.dropFirst().first)
    let languagesByCueGroupID = try database.cueGroupLanguages(forSubtitleFile: indexedSubtitleURL)
    #expect(languagesByCueGroupID[firstEntry.id] == [.japanese, .simplifiedChinese])
    #expect(languagesByCueGroupID[secondEntry.id] == [.japanese])
}

@Test
func indexesASSFontReferencesAndSkipsUnchangedAfterManifest() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Episode.ass",
        contents: """
        [Script Info]
        PlayResX: 1920
        PlayResY: 1080

        [V4+ Styles]
        Format: Name, Fontname, Fontsize
        Style: Default,华文中宋,42
        Style: Title,EPSON 太明朝体Ｂ,28

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,{\\fn汉仪小隶书简}Styled text
        Dialogue: 0,0:00:04.00,0:00:05.00,Title,,0,0,0,,Plain title
        """
    )
    try fixture.writeVideo(name: "Episode.mkv")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let initialResult = try indexer.index(folder: fixture.root, into: database)
    let indexedSubtitlePath = try #require(try database.subtitleFiles().first?.subtitlePath)
    let indexedSubtitleURL = URL(fileURLWithPath: indexedSubtitlePath)
    let references = try database.assFontReferences(forSubtitleFile: indexedSubtitleURL)
    let unchangedResult = try indexer.index(folder: fixture.root, into: database)

    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(references.map(\.fontName) == ["华文中宋", "EPSON 太明朝体Ｂ", "汉仪小隶书简"])
    #expect(references.map(\.source) == [.style, .style, .inlineOverride])
    #expect(try database.hasCurrentASSFontReferenceManifest(forSubtitleFile: indexedSubtitleURL))
    #expect(unchangedResult.indexedSubtitleFiles == 0)
    #expect(unchangedResult.skippedUnchangedSubtitleFiles == 1)
}

@Test
func reindexesUnchangedSubtitleWhenCueIndexAlgorithmVersionIsStale() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Versioned searchable text.

        """
    )
    try fixture.writeVideo(name: "Episode.mkv")

    let database = try SubtitleDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let initialResult = try indexer.index(folder: fixture.root, into: database)
    let initialMetadata = try #require(try database.subtitleFiles().first)
    try executeSQLite(
        at: fixture.databaseURL,
        "UPDATE subtitle_files SET index_algorithm_version = 0;"
    )

    let staleVersionResult = try indexer.index(folder: fixture.root, into: database)
    let refreshedMetadata = try #require(try database.subtitleFiles().first)

    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(initialMetadata.indexAlgorithmVersion == SubtitleCueIndexingRules.algorithmVersion)
    #expect(staleVersionResult.indexedSubtitleFiles == 1)
    #expect(staleVersionResult.skippedUnchangedSubtitleFiles == 0)
    #expect(refreshedMetadata.indexAlgorithmVersion == SubtitleCueIndexingRules.algorithmVersion)
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

    func subtitleFileMetadata(for url: URL) throws -> (fileSize: Int64?, modifiedAt: Date?) {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (
            (attributes[.size] as? NSNumber)?.int64Value,
            attributes[.modificationDate] as? Date
        )
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

private enum SQLiteFixtureError: Error {
    case openFailed(String)
    case executeFailed(String)
}

private func executeSQLite(at url: URL, _ sql: String) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }
    defer {
        sqlite3_close(database)
    }

    var errorMessage: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
        let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
        sqlite3_free(errorMessage)
        throw SQLiteFixtureError.executeFailed(message)
    }
}
