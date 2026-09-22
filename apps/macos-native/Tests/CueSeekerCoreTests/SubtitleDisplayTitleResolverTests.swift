import Foundation
import Testing
@testable import CueSeekerCore

/// A subtitle is titled by the video it matches, however many subtitles that
/// video has and whatever their extensions, and has that title as soon as
/// Index publishes its core data, before the Library rows are rebuilt; the
/// Library rows then take the same title. See
/// `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing
/// Database Records.md` and `docs/human/requirements/20260923-Bug-Display
/// Title Computed When Index Publishes Core Data.md`.
@Test
func subtitlesTakeTheirVideosDisplayTitle() throws {
    // EP01 has two subtitles and EP02 one; ranked among the .srt files on
    // disk they would read 01, 02 and 03.
    let (root, databaseURL) = try indexedShowFolder(
        videos: ["EP01.mkv", "EP02.mkv"],
        subtitles: ["EP01.sc.srt", "EP01.tc.srt", "EP02.srt"]
    )
    defer {
        try? FileManager.default.removeItem(at: root)
    }
    let connection = try SQLiteDatabase(path: databaseURL)
    let expectedSearchTitles = [
        "EP01.sc.srt": "Show - 01",
        "EP01.tc.srt": "Show - 01",
        "EP02.srt": "Show - 02"
    ]

    // Index step 7 has not rebuilt the Library rows yet.
    #expect(try libraryTitles(connection).isEmpty)
    #expect(try searchTitles(connection) == expectedSearchTitles)

    try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: [root.appendingPathComponent("Show").path]
    )

    #expect(try searchTitles(connection) == expectedSearchTitles)
    #expect(try libraryTitles(connection) == [
        "EP01.mkv": "Show - 01",
        "EP02.mkv": "Show - 02"
    ])
}

/// Upgrading names every video once and brings the stored search titles and
/// Library rows in line with it, including in a library whose Library rows
/// still wait for a rebuild.
@Test
func upgradeNamesVideosAndRealignsStoredTitles() throws {
    let (root, databaseURL) = try indexedShowFolder(
        videos: ["EP01.mkv", "EP02.mkv"],
        subtitles: ["EP01.srt", "EP02.srt"]
    )
    defer {
        try? FileManager.default.removeItem(at: root)
    }
    try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: [root.appendingPathComponent("Show").path]
    )
    let connection = try SQLiteDatabase(path: databaseURL)
    // As schema 53 left it: no title on the video, the video's name in Search
    // for EP02 whose Library row was never rebuilt, a stale Library title.
    try connection.execute(
        """
        UPDATE video_files SET display_title = NULL;
        UPDATE subtitle_search_order_rows SET display_title = 'EP02.mkv'
        WHERE subtitle_file_name = 'EP02.srt';
        DELETE FROM library_video_rows WHERE video_name = 'EP02.mkv';
        UPDATE library_video_rows SET display_title = 'Show - 1';
        PRAGMA user_version = 53;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try searchTitles(connection) == [
        "EP01.srt": "Show - 01",
        "EP02.srt": "Show - 02"
    ])
    #expect(try libraryTitles(connection) == ["EP01.mkv": "Show - 01"])
}

/// Indexes `Show` with the given videos and one-cue subtitles, publishing the
/// core data only, as Index does before it rebuilds the Library rows.
private func indexedShowFolder(
    videos: [String],
    subtitles: [String]
) throws -> (root: URL, databaseURL: URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerDisplayTitleTests-\(UUID().uuidString)")
    let show = root.appendingPathComponent("Show")
    try FileManager.default.createDirectory(at: show, withIntermediateDirectories: true)
    let databaseURL = root.appendingPathComponent("index.sqlite")
    try DatabaseBootstrap.prepare(at: databaseURL)
    for name in videos {
        try Data("video".utf8).write(to: show.appendingPathComponent(name))
    }
    for name in subtitles {
        try """
        1
        00:00:01,000 --> 00:00:03,000
        Hello

        """.write(to: show.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    _ = try SubtitleIndexer().index(folder: root, into: IndexingDatabase(path: databaseURL))
    return (root, databaseURL)
}

private func searchTitles(_ connection: SQLiteDatabase) throws -> [String: String] {
    try titles("SELECT subtitle_file_name, display_title FROM subtitle_search_order_rows;", connection)
}

private func libraryTitles(_ connection: SQLiteDatabase) throws -> [String: String] {
    try titles("SELECT video_name, display_title FROM library_video_rows;", connection)
}

private func titles(_ sql: String, _ connection: SQLiteDatabase) throws -> [String: String] {
    let statement = try connection.prepare(sql)
    var titles: [String: String] = [:]
    while try statement.step() {
        titles[statement.stringColumn(0)] = statement.stringColumn(1)
    }
    return titles
}
