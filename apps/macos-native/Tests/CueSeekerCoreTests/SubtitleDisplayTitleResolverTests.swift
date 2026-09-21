import Foundation
import Testing
@testable import CueSeekerCore

/// A subtitle is titled by the video it matches, however many subtitles that
/// video has and whatever their extensions. See
/// `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing
/// Database Records.md`.
@Test
func subtitlesTakeTheirVideosDisplayTitle() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerDisplayTitleTests-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: root)
    }
    let show = root.appendingPathComponent("Show")
    try FileManager.default.createDirectory(at: show, withIntermediateDirectories: true)
    let databaseURL = root.appendingPathComponent("index.sqlite")
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)

    for name in ["EP01.mkv", "EP02.mkv"] {
        try Data("video".utf8).write(to: show.appendingPathComponent(name))
    }
    // EP01 has two subtitles and EP02 one; ranked among the .srt files on
    // disk they would read 01, 02 and 03.
    for name in ["EP01.sc.srt", "EP01.tc.srt", "EP02.srt"] {
        try """
        1
        00:00:01,000 --> 00:00:03,000
        Hello

        """.write(to: show.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    let result = try SubtitleIndexer().index(folder: root, into: database)
    try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set(result.affectedFolderPaths)
    )

    let connection = try SQLiteDatabase(path: databaseURL)
    let statement = try connection.prepare(
        """
        SELECT subtitle_file_name, display_title
        FROM subtitle_search_order_rows
        ORDER BY subtitle_file_name;
        """
    )
    var titles: [String: String] = [:]
    while try statement.step() {
        titles[statement.stringColumn(0)] = statement.stringColumn(1)
    }

    #expect(titles == [
        "EP01.sc.srt": "Show - 01",
        "EP01.tc.srt": "Show - 01",
        "EP02.srt": "Show - 02"
    ])
}
