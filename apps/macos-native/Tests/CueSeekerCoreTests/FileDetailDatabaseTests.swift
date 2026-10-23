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
    #expect(videoInfo?.audioTracks.count == 1)
    #expect(videoInfo?.audioTracks.first?.language == "ja")
    #expect(videoInfo?.audioTracks.first?.channels == 2)
    #expect(videoInfo?.audioTracks.first?.sampleRate == 48000)
    #expect(videoInfo?.audioTracks.first?.bitDepth == 24)
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
