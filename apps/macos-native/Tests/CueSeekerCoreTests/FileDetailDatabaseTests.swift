import Foundation
import Testing
@testable import CueSeekerCore

@Test
func testSubtitleTextDecoderDetectedEncodingName() {
    let utf8Data = Data("Hello, world!".utf8)
    #expect(SubtitleTextDecoder.detectedEncodingName(in: utf8Data) == "UTF-8")

    let utf8BomData = Data([0xEF, 0xBB, 0xBF]) + utf8Data
    #expect(SubtitleTextDecoder.detectedEncodingName(in: utf8BomData) == "UTF-8 (BOM)")

    let utf16LeData = Data([0xFF, 0xFE]) + Data("Hello".utf8)
    #expect(SubtitleTextDecoder.detectedEncodingName(in: utf16LeData) == "UTF-16 LE")
}

@Test
func testFileDetailDatabaseQueries() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try LibraryDatabase(path: databaseURL)

    // Insert video
    let videoPath = "/Media/TestVideo.mkv"
    let statement = try database.database.prepare(
        """
        INSERT INTO video_files (path, video_name, file_size, duration, video_width, video_height, frame_rate, video_codec, video_bit_depth, video_pixel_format, audio_tracks, modified_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
    )
    try statement.bind(videoPath, at: 1)
    try statement.bind("TestVideo.mkv", at: 2)
    try statement.bind(Int64(1024 * 1024 * 50), at: 3)
    try statement.bind(125.5, at: 4)
    try statement.bind(1920, at: 5)
    try statement.bind(1080, at: 6)
    try statement.bind(24.0, at: 7)
    try statement.bind("hevc", at: 8)
    try statement.bind(10, at: 9)
    try statement.bind("yuv420p10le", at: 10)
    let tracks = [
        VideoAudioTrack(
            language: "ja",
            title: "Main",
            codec: "flac",
            channels: 2,
            sampleRate: 48000,
            bitDepth: 24
        )
    ]
    let tracksJSON = String(data: try JSONEncoder().encode(tracks), encoding: .utf8) ?? "[]"
    try statement.bind(tracksJSON, at: 11)
    try statement.bind(1700000000.0, at: 12)
    _ = try statement.step()

    let videoInfo = try database.fileDetailVideoInfo(for: videoPath)
    #expect(videoInfo != nil)
    #expect(videoInfo?.name == "TestVideo.mkv")
    #expect(videoInfo?.videoWidth == 1920)
    #expect(videoInfo?.videoHeight == 1080)
    #expect(videoInfo?.frameRate == 24.0)
    #expect(videoInfo?.videoCodec == "hevc")
    #expect(videoInfo?.videoBitDepth == 10)
    #expect(videoInfo?.videoPixelFormat == "yuv420p10le")
    #expect(videoInfo?.containerFormat == nil)
    #expect(videoInfo?.audioTracks.count == 1)
    #expect(videoInfo?.audioTracks.first?.language == "ja")
    #expect(videoInfo?.audioTracks.first?.channels == 2)
    #expect(videoInfo?.audioTracks.first?.sampleRate == 48000)
    #expect(videoInfo?.audioTracks.first?.bitDepth == 24)

    try database.updateVideoMetadata(
        videoFile: URL(fileURLWithPath: videoPath),
        duration: 125.5,
        videoWidth: 1920,
        videoHeight: 1080,
        frameRate: 24.0,
        videoCodec: "hevc",
        videoBitDepth: 10,
        videoPixelFormat: "yuv420p10le",
        containerFormat: "mp4",
        audioTracks: tracks
    )
    let updatedVideoInfo = try database.fileDetailVideoInfo(for: videoPath)
    #expect(updatedVideoInfo?.containerFormat == "mp4")
}

@Test
func testSubtitleRawCueCounter() {
    let assContents = """
    [Script Info]
    Title: Sample
    Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,Outside events should be ignored

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,First line
    Comment: 0,0:00:03.00,0:00:05.00,Default,,0,0,0,,Comment line ignored
    dialogue: 0,0:00:05.00,0:00:07.00,Default,,0,0,0,,{\\pos(100,100)}
    DIALOGUE: 0,0:00:07.00,0:00:09.00,Default,,0,0,0,,{\\p1}m 0 0 l 10 10{\\p0}

    [Fonts]
    Dialogue: 0,0:00:09.00,0:00:10.00,Default,,0,0,0,,After events should be ignored
    """
    #expect(SubtitleRawCueCounter.count(in: assContents, format: .ass) == 3)
    #expect(SubtitleRawCueCounter.count(in: assContents, format: .ssa) == 3)

    let srtContents = """
    1
    00:00:01,000 --> 00:00:03,000
    Hello world

    2
    00:00:04,000 --> 00:00:06,000
    <i></i>

    3
    00:00:07,000 --> 00:00:09,000
    Another cue
    """
    #expect(SubtitleRawCueCounter.count(in: srtContents, format: .srt) == 3)

    let vttContents = """
    WEBVTT

    00:00:01.000 --> 00:00:03.000
    First VTT cue

    00:00:04.000 --> 00:00:06.000
    Second VTT cue
    """
    #expect(SubtitleRawCueCounter.count(in: vttContents, format: .vtt) == 2)
}

@Test
func testSubtitleIndexerStoresRawCueCountAndReindexesWhenNull() throws {
    struct ProgressStep: Equatable {
        let completed: Int
        let total: Int

        init(_ completed: Int, _ total: Int) {
            self.completed = completed
            self.total = total
        }
    }

    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerRawCueCountTests-\(UUID().uuidString)")
    let databaseURL = tempRoot.appendingPathComponent("index.sqlite")
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleURL = tempRoot.appendingPathComponent("Episode.ass")
    let unpairedSubtitleURL = tempRoot.appendingPathComponent("Unpaired.srt")
    let videoURL = tempRoot.appendingPathComponent("Episode.mkv")
    let assScript = """
    [Script Info]
    ScriptType: v4.00+

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Spoken line
    Dialogue: 0,0:00:04.00,0:00:06.00,Default,,0,0,0,,{override only}
    Dialogue: 0,0:00:07.00,0:00:09.00,Default,,0,0,0,,   
    """
    let unpairedSrt = """
    1
    00:00:01,000 --> 00:00:03,000
    Unpaired line
    """
    try assScript.write(to: subtitleURL, atomically: true, encoding: .utf8)
    try unpairedSrt.write(to: unpairedSubtitleURL, atomically: true, encoding: .utf8)
    try Data().write(to: videoURL)

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    let indexer = SubtitleIndexer()

    nonisolated(unsafe) var firstProgress: [ProgressStep] = []
    let firstResult = try indexer.index(
        folder: tempRoot,
        into: indexingDatabase,
        onProgress: { completed, total in
            firstProgress.append(ProgressStep(completed, total))
        }
    )
    #expect(firstResult.indexedSubtitleFiles == 1)
    #expect(firstResult.skippedUnchangedSubtitleFiles == 0)
    #expect(firstResult.skippedMissingVideo == 1)
    #expect(firstProgress == [ProgressStep(0, 1), ProgressStep(1, 1)])

    let storedMetadata = try #require(try indexingDatabase.subtitleFiles().first)
    #expect(storedMetadata.rawCueCount == 3)

    let libraryDatabase = try LibraryDatabase(path: databaseURL)
    let detailInfo = try #require(
        try libraryDatabase.fileDetailSubtitleInfo(for: storedMetadata.subtitlePath)
    )
    #expect(detailInfo.rawCueCount == 3)
    #expect(detailInfo.cueCount == 1)

    nonisolated(unsafe) var secondProgress: [ProgressStep] = []
    let secondResult = try indexer.index(
        folder: tempRoot,
        into: indexingDatabase,
        onProgress: { completed, total in
            secondProgress.append(ProgressStep(completed, total))
        }
    )
    #expect(secondResult.indexedSubtitleFiles == 0)
    #expect(secondResult.skippedUnchangedSubtitleFiles == 1)
    #expect(secondProgress == [ProgressStep(0, 0)])

    try executeDatabaseTestSQLite(
        at: databaseURL,
        "UPDATE subtitle_files SET raw_cue_count = NULL;"
    )
    #expect(try indexingDatabase.subtitleFiles().first?.rawCueCount == nil)

    nonisolated(unsafe) var thirdProgress: [ProgressStep] = []
    let thirdResult = try indexer.index(
        folder: tempRoot,
        into: indexingDatabase,
        onProgress: { completed, total in
            thirdProgress.append(ProgressStep(completed, total))
        }
    )
    #expect(thirdResult.indexedSubtitleFiles == 1)
    #expect(thirdResult.skippedUnchangedSubtitleFiles == 0)
    #expect(!thirdResult.hasIndexedContentChanges)
    #expect(thirdProgress == [ProgressStep(0, 1), ProgressStep(1, 1)])
    #expect(try indexingDatabase.subtitleFiles().first?.rawCueCount == 3)
}

@Test
func testFileDetailFolderInfoCountsAndDirectVsNestedFiles() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerFolderDetailCounts-\(UUID().uuidString)")
        .standardizedFileURL
    let databaseURL = tempRoot.appendingPathComponent("index.sqlite")
    let mediaRoot = tempRoot.appendingPathComponent("Media", isDirectory: true)
    try FileManager.default.createDirectory(at: mediaRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    let libraryDatabase = try LibraryDatabase(path: databaseURL)
    let indexer = SubtitleIndexer()

    // 1. Empty root folder added with 0 paired files
    try indexingDatabase.addSearchPath(mediaRoot)
    let emptyRootInfo = try libraryDatabase.fileDetailFolderInfo(
        for: mediaRoot.path,
        isRootFolder: true
    )
    #expect(emptyRootInfo.isRootFolder)
    #expect(emptyRootInfo.folderCount == 0)
    #expect(emptyRootInfo.videoCount == 0)
    #expect(emptyRootInfo.subtitleCount == 0)
    #expect(emptyRootInfo.addedAt != nil)
    #expect(emptyRootInfo.updatedAt != nil)

    let sampleSrt = """
    1
    00:00:01,000 --> 00:00:03,000
    Hello world
    """
    func writePairedMedia(in dir: URL, baseName: String, subtitleExtensions: [String] = ["srt"]) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data().write(to: dir.appendingPathComponent("\(baseName).mkv"))
        for ext in subtitleExtensions {
            try sampleSrt.write(
                to: dir.appendingPathComponent("\(baseName).\(ext)"),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    // 2. Two subfolders with paired video+subtitle, plus a 3rd subfolder with only an unpaired subtitle
    let showA = mediaRoot.appendingPathComponent("ShowA", isDirectory: true)
    let showB = mediaRoot.appendingPathComponent("ShowB", isDirectory: true)
    let unpairedDir = mediaRoot.appendingPathComponent("UnpairedOnly", isDirectory: true)
    try writePairedMedia(in: showA, baseName: "Ep01", subtitleExtensions: ["srt", "en.srt"])
    try writePairedMedia(in: showB, baseName: "Ep01", subtitleExtensions: ["srt"])
    try FileManager.default.createDirectory(at: unpairedDir, withIntermediateDirectories: true)
    try sampleSrt.write(
        to: unpairedDir.appendingPathComponent("Orphan.srt"),
        atomically: true,
        encoding: .utf8
    )

    _ = try indexer.index(folder: mediaRoot, into: indexingDatabase)
    let twoSubfoldersRootInfo = try libraryDatabase.fileDetailFolderInfo(
        for: mediaRoot.path,
        isRootFolder: true
    )
    #expect(twoSubfoldersRootInfo.folderCount == 2)
    #expect(twoSubfoldersRootInfo.videoCount == 2)
    #expect(twoSubfoldersRootInfo.subtitleCount == 3)

    // 3. Direct paired video+subtitle at root level plus those 2 subfolders -> folderCount excludes root itself (still 2)
    try writePairedMedia(in: mediaRoot, baseName: "RootMovie", subtitleExtensions: ["srt"])
    _ = try indexer.index(folder: mediaRoot, into: indexingDatabase)
    let rootWithDirectFilesInfo = try libraryDatabase.fileDetailFolderInfo(
        for: mediaRoot.path,
        isRootFolder: true
    )
    #expect(rootWithDirectFilesInfo.folderCount == 2)
    #expect(rootWithDirectFilesInfo.videoCount == 3)
    #expect(rootWithDirectFilesInfo.subtitleCount == 4)

    // 4. Add a nested child folder under ShowB and verify Level 2 subfolder query (isRootFolder: false)
    // counts only direct paired video+subtitle in ShowB and sets folderCount == 0
    let showBSpecials = showB.appendingPathComponent("Specials", isDirectory: true)
    try writePairedMedia(in: showBSpecials, baseName: "OVA", subtitleExtensions: ["srt", "ja.srt"])
    _ = try indexer.index(folder: mediaRoot, into: indexingDatabase)

    let showBInfo = try libraryDatabase.fileDetailFolderInfo(
        for: showB.path,
        isRootFolder: false
    )
    #expect(!showBInfo.isRootFolder)
    #expect(showBInfo.folderCount == 0)
    #expect(showBInfo.videoCount == 1)
    #expect(showBInfo.subtitleCount == 1)
    #expect(showBInfo.addedAt != nil)
    #expect(showBInfo.updatedAt != nil)

    let showAInfo = try libraryDatabase.fileDetailFolderInfo(
        for: showA.path,
        isRootFolder: false
    )
    #expect(showAInfo.folderCount == 0)
    #expect(showAInfo.videoCount == 1)
    #expect(showAInfo.subtitleCount == 2)
}

@Test
func testFileDetailFolderInfoNestedRootsRenameAndTombstoneNonPreservation() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerFolderDetailLifecycle-\(UUID().uuidString)")
        .standardizedFileURL
    let databaseURL = tempRoot.appendingPathComponent("index.sqlite")
    let mediaRoot = tempRoot.appendingPathComponent("Media", isDirectory: true)
    let moviesDir = mediaRoot.appendingPathComponent("Movies", isDirectory: true)
    let animeRoot = mediaRoot.appendingPathComponent("Anime", isDirectory: true)
    let show1Dir = animeRoot.appendingPathComponent("Show1", isDirectory: true)
    try FileManager.default.createDirectory(at: moviesDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: show1Dir, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let sampleSrt = """
    1
    00:00:01,000 --> 00:00:03,000
    Hello world
    """
    try Data().write(to: moviesDir.appendingPathComponent("Film.mkv"))
    try sampleSrt.write(to: moviesDir.appendingPathComponent("Film.srt"), atomically: true, encoding: .utf8)
    try Data().write(to: show1Dir.appendingPathComponent("Ep1.mkv"))
    try sampleSrt.write(to: show1Dir.appendingPathComponent("Ep1.srt"), atomically: true, encoding: .utf8)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    let libraryDatabase = try LibraryDatabase(path: databaseURL)
    let indexer = SubtitleIndexer()

    let isoFormatter = ISO8601DateFormatter()
    let t1String = "2026-01-01T00:00:00Z"
    let t2String = "2026-01-02T00:00:00Z"
    let t3String = "2026-01-03T00:00:00Z"
    let t1 = try #require(isoFormatter.date(from: t1String))
    let t2 = try #require(isoFormatter.date(from: t2String))
    let t3 = try #require(isoFormatter.date(from: t3String))

    // 1. Index parent root /Media first and pin its initial timestamps to t1
    _ = try indexer.index(folder: mediaRoot, into: indexingDatabase)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        UPDATE library_root_folders SET created_at = '\(t1String)', updated_at = '\(t1String)';
        UPDATE search_paths SET created_at = '\(t1String)', updated_at = '\(t1String)', last_successful_index_at = '\(t1String)';
        UPDATE library_folders SET created_at = '\(t1String)', updated_at = '\(t1String)';
        """
    )

    let initialMediaInfo = try libraryDatabase.fileDetailFolderInfo(for: mediaRoot.path, isRootFolder: true)
    #expect(initialMediaInfo.addedAt == t1)
    #expect(initialMediaInfo.updatedAt == t1)

    // 2. Add /Media/Anime as a covered root -> gets its own addedAt (> t1) and inherits /Media's updatedAt (== t1)
    try indexingDatabase.recordCoveredRootFolderAddition(animeRoot, coveredBy: mediaRoot)
    let coveredAnimeInfo = try libraryDatabase.fileDetailFolderInfo(for: animeRoot.path, isRootFolder: true)
    #expect(coveredAnimeInfo.folderCount == 1)
    #expect(coveredAnimeInfo.videoCount == 1)
    #expect(coveredAnimeInfo.subtitleCount == 1)
    #expect(try #require(coveredAnimeInfo.addedAt) > t1)
    #expect(coveredAnimeInfo.updatedAt == t1)

    // Pin /Media/Anime's created_at to t2 before indexing /Media/Anime alone
    try executeDatabaseTestSQLite(
        at: databaseURL,
        "UPDATE library_root_folders SET created_at = '\(t2String)' WHERE path = '\(animeRoot.path)';"
    )

    // 3. Index /Media/Anime alone -> /Media/Anime and its subfolder Show1 advance updatedAt, while /Media stays at t1
    _ = try indexer.index(folder: animeRoot, into: indexingDatabase)
    let animeAfterSubIndex = try libraryDatabase.fileDetailFolderInfo(for: animeRoot.path, isRootFolder: true)
    let show1AfterSubIndex = try libraryDatabase.fileDetailFolderInfo(for: show1Dir.path, isRootFolder: false)
    let mediaAfterSubIndex = try libraryDatabase.fileDetailFolderInfo(for: mediaRoot.path, isRootFolder: true)
    let moviesAfterSubIndex = try libraryDatabase.fileDetailFolderInfo(for: moviesDir.path, isRootFolder: false)

    #expect(animeAfterSubIndex.addedAt == t2)
    #expect(try #require(animeAfterSubIndex.updatedAt) > t2)
    #expect(show1AfterSubIndex.addedAt == t1)
    #expect(show1AfterSubIndex.updatedAt == animeAfterSubIndex.updatedAt)
    #expect(mediaAfterSubIndex.addedAt == t1)
    #expect(mediaAfterSubIndex.updatedAt == t1)
    #expect(moviesAfterSubIndex.updatedAt == t1)

    // 4. Pin updated_at to t3 and re-index /Media -> both /Media and /Media/Anime (and subfolders) refresh updatedAt
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        UPDATE library_root_folders SET updated_at = '\(t3String)';
        UPDATE library_folders SET updated_at = '\(t3String)';
        """
    )
    _ = try indexer.index(folder: mediaRoot, into: indexingDatabase)
    let mediaAfterParentReindex = try libraryDatabase.fileDetailFolderInfo(for: mediaRoot.path, isRootFolder: true)
    let animeAfterParentReindex = try libraryDatabase.fileDetailFolderInfo(for: animeRoot.path, isRootFolder: true)
    let show1AfterParentReindex = try libraryDatabase.fileDetailFolderInfo(for: show1Dir.path, isRootFolder: false)

    let refreshedUpdatedAt = try #require(mediaAfterParentReindex.updatedAt)
    #expect(refreshedUpdatedAt > t3)
    #expect(mediaAfterParentReindex.addedAt == t1)
    #expect(animeAfterParentReindex.addedAt == t2)
    #expect(animeAfterParentReindex.updatedAt == refreshedUpdatedAt)
    #expect(show1AfterParentReindex.addedAt == t1)
    #expect(show1AfterParentReindex.updatedAt == refreshedUpdatedAt)

    // 5. In-App folder rename via applyRename preserves addedAt and updatedAt while updating path
    let renamedShow1Dir = animeRoot.appendingPathComponent("Show1Renamed", isDirectory: true)
    try FileManager.default.moveItem(at: show1Dir, to: renamedShow1Dir)
    let renamePlan = LibraryRenamePlan(
        request: .folder(path: show1Dir.path, newName: "Show1Renamed"),
        steps: [LibraryRenameStep(oldPath: show1Dir.path, newPath: renamedShow1Dir.path)],
        affectedFolderPaths: [show1Dir.path, renamedShow1Dir.path]
    )
    try indexingDatabase.applyRename(renamePlan)

    let renamedShow1Info = try libraryDatabase.fileDetailFolderInfo(
        for: renamedShow1Dir.path,
        isRootFolder: false
    )
    #expect(renamedShow1Info.path == renamedShow1Dir.path)
    #expect(renamedShow1Info.name == "Show1Renamed")
    #expect(renamedShow1Info.videoCount == 1)
    #expect(renamedShow1Info.subtitleCount == 1)
    #expect(renamedShow1Info.addedAt == t1)
    #expect(renamedShow1Info.updatedAt == refreshedUpdatedAt)

    // 6. Tombstone non-preservation of addedAt: removing a folder and re-indexing assigns a new addedAt
    try indexingDatabase.removeIndexedFolder(mediaRoot)
    try indexingDatabase.removeRootFolderMetadata(animeRoot)
    _ = try indexer.index(folder: mediaRoot, into: indexingDatabase)

    let readdedMediaInfo = try libraryDatabase.fileDetailFolderInfo(for: mediaRoot.path, isRootFolder: true)
    let readdedShow1Info = try libraryDatabase.fileDetailFolderInfo(for: renamedShow1Dir.path, isRootFolder: false)
    #expect(try #require(readdedMediaInfo.addedAt) > t3)
    #expect(try #require(readdedShow1Info.addedAt) > t3)
}

@Test
func testFileDetailPairedItemsOrderingAndFrozenSnapshot() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPairedDetailItems-\(UUID().uuidString)")
        .standardizedFileURL
    let databaseURL = tempRoot.appendingPathComponent("index.sqlite")
    let showDir = tempRoot.appendingPathComponent("Show", isDirectory: true)
    try FileManager.default.createDirectory(at: showDir, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    let videoURL = showDir.appendingPathComponent("Ep01.mkv")
    let subAssURL = showDir.appendingPathComponent("Ep01.ass")
    let subChsURL = showDir.appendingPathComponent("Ep01.chs.srt")
    let subJpnURL = showDir.appendingPathComponent("Ep01.jpn.srt")

    try Data("video".utf8).write(to: videoURL)
    let sampleSrt = """
    1
    00:00:01,000 --> 00:00:03,000
    Hello world
    """
    let sampleAss = """
    [Script Info]
    ScriptType: v4.00+

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Ass line 1
    Dialogue: 0,0:00:04.00,0:00:06.00,Default,,0,0,0,,Ass line 2
    """
    try sampleAss.write(to: subAssURL, atomically: true, encoding: .utf8)
    try sampleSrt.write(to: subChsURL, atomically: true, encoding: .utf8)
    try sampleSrt.write(to: subJpnURL, atomically: true, encoding: .utf8)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    let libraryDatabase = try LibraryDatabase(path: databaseURL)
    let indexer = SubtitleIndexer()

    _ = try indexer.index(folder: tempRoot, into: indexingDatabase)

    let fromVideo = try libraryDatabase.fileDetailPairedItems(forVideoPath: videoURL.path)
    #expect(fromVideo.count == 4)
    #expect(fromVideo[0].isVideo)
    #expect(fromVideo[0].name == "Ep01.mkv")
    #expect(!fromVideo[1].isVideo)
    #expect(fromVideo[1].name == "Ep01.ass")
    #expect(fromVideo[2].name == "Ep01.chs.srt")
    #expect(fromVideo[3].name == "Ep01.jpn.srt")

    let fromSubtitle = try libraryDatabase.fileDetailPairedItems(forSubtitlePath: subChsURL.path)
    #expect(fromSubtitle == fromVideo)

    // Mutate database after taking snapshot and verify the frozen snapshot array remains unchanged
    try executeDatabaseTestSQLite(
        at: databaseURL,
        "UPDATE video_files SET video_codec = 'av1', duration = 999.0 WHERE path = '\(videoURL.path)';"
    )
    if case .video(let frozenVideoInfo) = fromSubtitle[0] {
        #expect(frozenVideoInfo.videoCodec == nil)
        #expect(frozenVideoInfo.duration == nil)
    } else {
        Issue.record("Expected first paired item to be video")
    }
}


