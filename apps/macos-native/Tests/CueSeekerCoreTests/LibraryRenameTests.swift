import Foundation
import Testing
@testable import CueSeekerCore

/// A root with one show folder holding two indexed pairs, indexed for real.
///
/// The temporary directory is `/var/...`, which the enumerator reports as
/// `/private/var/...`, so the database holds the root in one form and the
/// files in the other — exactly the mix the rename has to cope with. Requests
/// use the folder path the Edit tree would show, and assertions use the paths
/// the database stores.
private struct RenameFixture {
    let root: URL
    let show: URL
    let databaseURL: URL
    let database: IndexingDatabase

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerRenameTests-\(UUID().uuidString)")
        show = root.appendingPathComponent("Show")
        databaseURL = root.appendingPathComponent("index.sqlite")
        try FileManager.default.createDirectory(at: show, withIntermediateDirectories: true)
        try DatabaseBootstrap.prepare(at: databaseURL)
        database = try IndexingDatabase(path: databaseURL)
        try Self.writePair(baseName: "EP01", subtitleTail: "zh.srt", in: show)
        try Self.writePair(baseName: "EP02", subtitleTail: "srt", in: show)
    }

    static func writePair(baseName: String, subtitleTail: String, in directory: URL) throws {
        try Data("video".utf8).write(to: directory.appendingPathComponent("\(baseName).mkv"))
        try writeSubtitle(name: "\(baseName).\(subtitleTail)", in: directory)
    }

    static func writeSubtitle(name: String, in directory: URL, text: String = "Hello") throws {
        try """
        1
        00:00:01,000 --> 00:00:03,000
        \(text)

        """.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func index() throws {
        let result = try SubtitleIndexer().index(folder: root, into: database)
        try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange(
            affectedFolderPaths: Set(result.affectedFolderPaths)
        )
    }

    /// The stored path of the video whose name is `videoName`.
    func storedVideoPath(_ videoName: String) throws -> String {
        try #require(
            try database.subtitleFiles().first { $0.videoName == videoName }?.videoPath
        )
    }

    /// The stored path of the subtitle file named `subtitleName`.
    func storedSubtitlePath(_ subtitleName: String) throws -> String {
        try #require(
            try database.subtitleFiles().first { $0.subtitlePath.hasSuffix("/" + subtitleName) }?.subtitlePath
        )
    }

    func videoID(_ path: String) throws -> Int64? {
        try sqliteRowID(table: "video_files", pathColumn: "path", path: path, databaseURL: databaseURL)
    }

    func subtitleID(_ path: String) throws -> Int64? {
        try sqliteRowID(table: "subtitle_files", pathColumn: "subtitle_path", path: path, databaseURL: databaseURL)
    }

    func string(_ sql: String) throws -> String? {
        try sqliteStringValue(at: databaseURL, sql: sql)
    }

    func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

@Test
func folderRenameKeepsEveryIDAndRewritesEveryStoredPath() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    let oldVideo = try fixture.storedVideoPath("EP01.mkv")
    let oldSubtitle = try fixture.storedSubtitlePath("EP01.zh.srt")
    let videoID = try #require(try fixture.videoID(oldVideo))
    let subtitleID = try #require(try fixture.subtitleID(oldSubtitle))
    try executeDatabaseTestSQLite(
        at: fixture.databaseURL,
        "INSERT INTO library_watch_states(video_file_id, state, updated_at) VALUES (\(videoID), 'watching', 'now');"
    )

    let renamer = LibraryRenamer(database: fixture.database)
    let plan = try renamer.checkConflicts(.folder(path: fixture.show.path, newName: "Show Renamed"))
    try renamer.perform(plan)

    let newVideo = oldVideo.replacingOccurrences(of: "/Show/", with: "/Show Renamed/")
    let newSubtitle = oldSubtitle.replacingOccurrences(of: "/Show/", with: "/Show Renamed/")
    #expect(fixture.exists(fixture.root.appendingPathComponent("Show Renamed").path))
    #expect(!fixture.exists(fixture.show.path))
    #expect(try fixture.videoID(newVideo) == videoID)
    #expect(try fixture.subtitleID(newSubtitle) == subtitleID)
    #expect(try fixture.videoID(oldVideo) == nil)
    #expect(try fixture.string("SELECT relative_path FROM video_files WHERE id = \(videoID)") == "Show Renamed/EP01.mkv")
    #expect(try fixture.string("SELECT relative_path FROM library_folders WHERE id = (SELECT folder_id FROM video_files WHERE id = \(videoID))") == "Show Renamed")
    #expect(try fixture.string("SELECT subtitle_path FROM subtitle_cue_groups WHERE subtitle_file_id = \(subtitleID) LIMIT 1") == newSubtitle)
    #expect(try fixture.string("SELECT subtitle_path FROM subtitle_playback_finish_metadata WHERE subtitle_file_id = \(subtitleID)") == newSubtitle)
    #expect(try fixture.string("SELECT display_title FROM subtitle_search_order_rows WHERE subtitle_path = '\(newSubtitle)'") == "Show Renamed - 01")
    #expect(try fixture.string("SELECT folder_title FROM library_video_rows WHERE video_path = '\(newVideo)'") == "Show Renamed")
    #expect(try fixture.string("SELECT COUNT(*) FROM library_video_rows WHERE video_path LIKE '%/Show/%'") == "0")
    #expect(try fixture.string("SELECT COUNT(*) FROM subtitle_search_order_rows WHERE subtitle_path LIKE '%/Show/%'") == "0")
    #expect(try fixture.string("SELECT state FROM library_watch_states WHERE video_file_id = \(videoID)") == "watching")
    let oldFolder = (oldVideo as NSString).deletingLastPathComponent
    #expect(plan.affectedFolderPaths == [oldFolder, (newVideo as NSString).deletingLastPathComponent])
}

@Test
func renamingTheRootMovesTheLibraryRowAndKeepsRelativePaths() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    let oldVideo = try fixture.storedVideoPath("EP01.mkv")
    let videoID = try #require(try fixture.videoID(oldVideo))
    let rootName = fixture.root.lastPathComponent
    let movedRoot = fixture.root.deletingLastPathComponent().appendingPathComponent("Moved \(rootName)")
    defer { try? FileManager.default.removeItem(at: movedRoot) }

    let renamer = LibraryRenamer(database: fixture.database)
    try renamer.perform(try renamer.checkConflicts(.folder(path: fixture.root.path, newName: "Moved \(rootName)")))

    let movedDatabaseURL = movedRoot.appendingPathComponent("index.sqlite")
    let newVideo = oldVideo.replacingOccurrences(of: "/\(rootName)/", with: "/Moved \(rootName)/")
    #expect(try sqliteStringValue(at: movedDatabaseURL, sql: "SELECT path FROM search_paths") == movedRoot.path)
    #expect(try sqliteRowID(table: "video_files", pathColumn: "path", path: newVideo, databaseURL: movedDatabaseURL) == videoID)
    #expect(try sqliteStringValue(at: movedDatabaseURL, sql: "SELECT relative_path FROM video_files WHERE id = \(videoID)") == "Show/EP01.mkv")
    #expect(try sqliteStringValue(at: movedDatabaseURL, sql: "SELECT relative_path FROM library_folders WHERE id = (SELECT folder_id FROM video_files WHERE id = \(videoID))") == "Show")
}

@Test
func fileGroupRenameMovesTheVideoAndItsSubtitleAndReordersSiblings() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    let oldVideo = try fixture.storedVideoPath("EP01.mkv")
    let oldSubtitle = try fixture.storedSubtitlePath("EP01.zh.srt")
    let videoID = try #require(try fixture.videoID(oldVideo))
    let subtitleID = try #require(try fixture.subtitleID(oldSubtitle))

    let renamer = LibraryRenamer(database: fixture.database)
    let plan = try renamer.checkConflicts(.fileGroup(videoPath: oldVideo, newBaseName: "EP09"))
    try renamer.perform(plan)

    let newVideo = oldVideo.replacingOccurrences(of: "EP01.mkv", with: "EP09.mkv")
    let newSubtitle = oldSubtitle.replacingOccurrences(of: "EP01.zh.srt", with: "EP09.zh.srt")
    #expect(fixture.exists(newVideo))
    #expect(fixture.exists(newSubtitle))
    #expect(!fixture.exists(oldVideo))
    #expect(try fixture.videoID(newVideo) == videoID)
    #expect(try fixture.subtitleID(newSubtitle) == subtitleID)
    #expect(try fixture.string("SELECT video_name FROM video_files WHERE id = \(videoID)") == "EP09.mkv")
    // EP02 now sorts first, so its Display Title moves up.
    let secondSubtitle = try fixture.storedSubtitlePath("EP02.srt")
    #expect(try fixture.string("SELECT display_title FROM subtitle_search_order_rows WHERE subtitle_path = '\(secondSubtitle)'") == "Show - 01")
    #expect(try fixture.string("SELECT display_title FROM subtitle_search_order_rows WHERE subtitle_path = '\(newSubtitle)'") == "Show - 02")
    #expect(plan.steps.map(\.newPath) == [newVideo, newSubtitle])
}

@Test
func aFileEditedSinceTheIndexIsAConflict() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    try RenameFixture.writeSubtitle(name: "EP01.zh.srt", in: fixture.show, text: "Edited outside the App")

    let renamer = LibraryRenamer(database: fixture.database)
    #expect(throws: LibraryRenameConflict.filesChangedSinceIndex) {
        try renamer.checkConflicts(.fileGroup(videoPath: try fixture.storedVideoPath("EP01.mkv"), newBaseName: "EP09"))
    }
    #expect(throws: LibraryRenameConflict.filesChangedSinceIndex) {
        try renamer.checkConflicts(.folder(path: fixture.show.path, newName: "Show Renamed"))
    }
}

@Test
func aPairAddedSinceTheIndexIsAConflict() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    try RenameFixture.writePair(baseName: "EP03", subtitleTail: "srt", in: fixture.show)

    let renamer = LibraryRenamer(database: fixture.database)
    #expect(throws: LibraryRenameConflict.filesChangedSinceIndex) {
        try renamer.checkConflicts(.folder(path: fixture.show.path, newName: "Show Renamed"))
    }
}

@Test
func anExistingNameIsAConflict() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    try FileManager.default.createDirectory(at: fixture.root.appendingPathComponent("Taken"), withIntermediateDirectories: false)

    let renamer = LibraryRenamer(database: fixture.database)
    #expect(throws: LibraryRenameConflict.destinationExists(name: "Taken")) {
        try renamer.checkConflicts(.folder(path: fixture.show.path, newName: "Taken"))
    }
    #expect(throws: LibraryRenameConflict.destinationExists(name: "EP02.mkv")) {
        try renamer.checkConflicts(.fileGroup(videoPath: try fixture.storedVideoPath("EP01.mkv"), newBaseName: "EP02"))
    }
}

@Test
func aNameThatWouldAdoptAnOrphanSubtitleIsAConflict() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try RenameFixture.writeSubtitle(name: "Orphan.srt", in: fixture.show)
    try fixture.index()

    let renamer = LibraryRenamer(database: fixture.database)
    #expect(throws: LibraryRenameConflict.pairingWouldChange(name: "Orphan")) {
        try renamer.checkConflicts(.fileGroup(videoPath: try fixture.storedVideoPath("EP01.mkv"), newBaseName: "Orphan"))
    }
}

@Test
func aDiskFailureMidwayRenamesTheFinishedFilesBack() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    let oldVideo = try fixture.storedVideoPath("EP01.mkv")
    let oldSubtitle = try fixture.storedSubtitlePath("EP01.zh.srt")
    let renamer = LibraryRenamer(database: fixture.database)
    let plan = try renamer.checkConflicts(.fileGroup(videoPath: oldVideo, newBaseName: "EP07"))
    // A directory where the subtitle wants to go makes its rename fail after
    // the video has already been renamed.
    try FileManager.default.createDirectory(at: fixture.show.appendingPathComponent("EP07.zh.srt"), withIntermediateDirectories: false)

    #expect(throws: LibraryRenameError.renameFailed(path: oldSubtitle)) {
        try renamer.perform(plan)
    }
    #expect(fixture.exists(oldVideo))
    #expect(!fixture.exists(fixture.show.appendingPathComponent("EP07.mkv").path))
    #expect(try fixture.videoID(oldVideo) != nil)
}

@Test
func aDatabaseFailureRenamesEverythingBack() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    let oldVideo = try fixture.storedVideoPath("EP01.mkv")
    let readOnly = try IndexingDatabase(path: fixture.databaseURL, access: .readOnly)
    let renamer = LibraryRenamer(database: readOnly)
    let plan = try renamer.checkConflicts(.folder(path: fixture.show.path, newName: "Show Renamed"))

    #expect(throws: LibraryRenameError.self) {
        try renamer.perform(plan)
    }
    #expect(fixture.exists(fixture.show.path))
    #expect(!fixture.exists(fixture.root.appendingPathComponent("Show Renamed").path))
    #expect(try fixture.videoID(oldVideo) != nil)
}

@Test
func aCaseOnlyRenameSucceeds() throws {
    let fixture = try RenameFixture()
    defer { fixture.cleanUp() }
    try fixture.index()
    let oldVideo = try fixture.storedVideoPath("EP01.mkv")
    let renamer = LibraryRenamer(database: fixture.database)

    try renamer.perform(try renamer.checkConflicts(.folder(path: fixture.show.path, newName: "show")))

    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).contains("show"))
    #expect(try fixture.videoID(oldVideo.replacingOccurrences(of: "/Show/", with: "/show/")) != nil)
}

@Test
func fileGroupNamingFindsTheSharedBaseName() {
    #expect(LibraryFileGroupNaming.commonBaseName(videoName: "EP01.mkv", subtitleNames: ["EP01.zh.ass"]) == "EP01")
    #expect(LibraryFileGroupNaming.commonBaseName(videoName: "EP01.1080p.mkv", subtitleNames: ["EP01.ass"]) == "EP01")
    #expect(LibraryFileGroupNaming.commonBaseName(videoName: "Show.S01E01.mkv", subtitleNames: ["Show.S01E01.ass", "Show.S01E01.zh.srt"]) == "Show.S01E01")
    #expect(LibraryFileGroupNaming.commonBaseName(videoName: "EP01.mkv", subtitleNames: ["Other.ass"]) == nil)
    #expect(LibraryFileGroupNaming.renamedFileName("EP01.zh.ass", baseName: "EP01", newBaseName: "A.B") == "A.B.zh.ass")
    #expect(LibraryFileGroupNaming.renamedFileName("EP01.1080p.mkv", baseName: "EP01", newBaseName: "X") == "X.1080p.mkv")
}

@Test
func nameValidatorAppliesTheDialogRules() {
    #expect(LibraryRenameNameValidator.validate("", currentName: "A") == .empty)
    #expect(LibraryRenameNameValidator.validate("   ", currentName: "A") == .empty)
    #expect(LibraryRenameNameValidator.validate("A", currentName: "A") == .unchanged)
    #expect(LibraryRenameNameValidator.validate("e\u{0301}", currentName: "\u{00E9}") == .unchanged)
    #expect(LibraryRenameNameValidator.validate("a", currentName: "A") == nil)
    #expect(LibraryRenameNameValidator.validate(".hidden", currentName: "A") == .invalid)
    #expect(LibraryRenameNameValidator.validate("name.", currentName: "A") == .invalid)
    #expect(LibraryRenameNameValidator.validate("name ", currentName: "A") == .invalid)
    #expect(LibraryRenameNameValidator.validate("a:b", currentName: "A") == .invalid)
    #expect(LibraryRenameNameValidator.validate("a/b", currentName: "A") == .invalid)
    #expect(LibraryRenameNameValidator.validate("con", currentName: "A") == .invalid)
    #expect(LibraryRenameNameValidator.validate("COM1.txt", currentName: "A") == .invalid)
    #expect(LibraryRenameNameValidator.validate("Ave.Mujica EP01", currentName: "A") == nil)
}

@Test
func pathRewritingKeepsEachPathsOwnForm() {
    #expect(LibraryRenamer.rewrite("/private/var/x/Show/EP01.mkv", from: "/var/x/Show", to: "/var/x/Show Renamed") == "/private/var/x/Show Renamed/EP01.mkv")
    #expect(LibraryRenamer.rewrite("/var/x/Show", from: "/private/var/x/Show", to: "/private/var/x/New") == "/var/x/New")
    #expect(LibraryRenamer.rewrite("/Volumes/A/Show/EP01.mkv", from: "/Volumes/A/Show", to: "/Volumes/A/New") == "/Volumes/A/New/EP01.mkv")
    #expect(LibraryRenamer.rewrite("/Volumes/A/Showcase/EP01.mkv", from: "/Volumes/A/Show", to: "/Volumes/A/New") == nil)
}
