import Foundation
import Testing
@testable import CueSeekerCore

private let seasonOne = URL(fileURLWithPath: "/Media/Show/Season 1")
private let show = URL(fileURLWithPath: "/Media/Show")
private let other = URL(fileURLWithPath: "/Media/Other")

@Test
func rootGroupsStandWhereTheirEarliestRootStands() {
    // Added in the order Season 1, Other, Show: Show holds Season 1, so its
    // group takes Season 1's place ahead of Other.
    #expect(
        LibraryRootGroups.representatives(of: [seasonOne, other, show])
            == [show, other]
    )
    #expect(LibraryRootGroups.coveringRoot(of: seasonOne, in: [seasonOne, show]) == show)
    #expect(LibraryRootGroups.coveringRoot(of: show, in: [seasonOne]) == nil)
    #expect(
        LibraryRootGroups.representatives(inside: show, of: [seasonOne, other])
            == [seasonOne]
    )
}

@Test
func rootGroupsCompareWholePathComponents() {
    let showExtra = URL(fileURLWithPath: "/Media/Show Extra")

    #expect(!LibraryRootGroups.holds(show, showExtra))
    #expect(LibraryRootGroups.holds(show, seasonOne))
    #expect(LibraryRootGroups.holds(show, show))
    #expect(LibraryRootGroups.representatives(of: [show, showExtra]) == [show, showExtra])
}

/// Adding a folder that holds an indexed root folds that root into it without
/// parsing its files again, and removing the outer folder while the inner one
/// stays hands the inner files back with the same rows.
@Test
func anOuterRootAdoptsAndReturnsTheRootItHolds() throws {
    let container = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerNestedRoots-\(UUID().uuidString)")
    let outer = container.appendingPathComponent("Show", isDirectory: true)
    let inner = outer.appendingPathComponent("Season 1", isDirectory: true)
    let sibling = outer.appendingPathComponent("Season 2", isDirectory: true)
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: container)
        removeTemporaryDatabase(at: databaseURL)
    }
    try writeEpisode(named: "Inner", text: "inner line", in: inner)
    try writeEpisode(named: "Sibling", text: "sibling line", in: sibling)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)

    _ = try SubtitleIndexer().index(folder: inner, into: database)
    let innerSubtitle = try #require(try database.subtitleFiles().first?.subtitlePath)
    let innerSubtitleID = try #require(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: innerSubtitle,
        databaseURL: databaseURL
    ))

    let outerResult = try SubtitleIndexer().index(folder: outer, into: database)

    #expect(outerResult.indexedSubtitleFiles == 1)
    #expect(outerResult.skippedUnchangedSubtitleFiles == 1)
    #expect(try database.libraryPathRecords().map(\.rootURL.path) == [outer.standardizedFileURL.path])
    #expect(try relativePath(of: innerSubtitle, in: databaseURL) == "Season 1/Inner.srt")
    #expect(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: innerSubtitle,
        databaseURL: databaseURL
    ) == innerSubtitleID)

    try database.removeIndexedFolder(outer, keepingNestedRoots: [inner])

    #expect(try database.libraryPathRecords().map(\.rootURL.path) == [inner.standardizedFileURL.path])
    #expect(try relativePath(of: innerSubtitle, in: databaseURL) == "Inner.srt")
    #expect(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: innerSubtitle,
        databaseURL: databaseURL
    ) == innerSubtitleID)
    #expect(try database.subtitleFiles().map(\.subtitlePath) == [innerSubtitle])
}

private func writeEpisode(named name: String, text: String, in folder: URL) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try """
    1
    00:00:01,000 --> 00:00:02,000
    \(text)

    """.write(
        to: folder.appendingPathComponent("\(name).srt"),
        atomically: true,
        encoding: .utf8
    )
    try Data([0]).write(to: folder.appendingPathComponent("\(name).mkv"))
}

private func relativePath(of subtitlePath: String, in databaseURL: URL) throws -> String? {
    try sqliteStringValue(
        at: databaseURL,
        sql: "SELECT relative_path FROM subtitle_files WHERE subtitle_path = '\(subtitlePath)';"
    )
}
