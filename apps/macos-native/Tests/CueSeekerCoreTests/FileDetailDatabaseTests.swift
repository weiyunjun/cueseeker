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
        INSERT INTO video_files (path, video_name, file_size, duration, video_width, video_height, frame_rate, video_codec, audio_tracks, modified_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
    let tracks = [VideoAudioTrack(language: "ja", title: "Main", codec: "flac", channels: 2)]
    let tracksJSON = String(data: try JSONEncoder().encode(tracks), encoding: .utf8) ?? "[]"
    try statement.bind(tracksJSON, at: 9)
    try statement.bind(1700000000.0, at: 10)
    _ = try statement.step()

    let videoInfo = try database.fileDetailVideoInfo(for: videoPath)
    #expect(videoInfo != nil)
    #expect(videoInfo?.name == "TestVideo.mkv")
    #expect(videoInfo?.videoWidth == 1920)
    #expect(videoInfo?.videoHeight == 1080)
    #expect(videoInfo?.frameRate == 24.0)
    #expect(videoInfo?.videoCodec == "hevc")
    #expect(videoInfo?.audioTracks.count == 1)
    #expect(videoInfo?.audioTracks.first?.language == "ja")
    #expect(videoInfo?.audioTracks.first?.channels == 2)
}
