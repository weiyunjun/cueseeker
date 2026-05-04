import Foundation
import Testing
import CueSeekerCore

@Test
func alistResolverBuildsAPIPathFromWebDAVRootAndRelativePath() throws {
    let path = try AListResolver.apiPath(
        webDAVRootPath: "/dav/baidu",
        sourceRelativePath: "[BeanSub&FZSD]/Episode 01.mkv"
    )

    #expect(path == "/baidu/[BeanSub&FZSD]/Episode 01.mkv")
}

@Test
func alistResolverHandlesRootDAVMount() throws {
    let path = try AListResolver.apiPath(
        webDAVRootPath: "/dav",
        sourceRelativePath: "Anime/Episode 01.mkv"
    )

    #expect(path == "/Anime/Episode 01.mkv")
}

@Test
func databaseStoresRemoteMediaSourceAndSearchesWithinRemoteScope() throws {
    let databaseURL = temporaryRemoteDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let sourceID = try database.addRemoteMediaSource(
        provider: .alist,
        rootURL: URL(string: "http://example.test:5244/dav/baidu/")!,
        displayName: "AList Baidu",
        credentialRef: "credential-ref"
    )

    try database.replaceCueGroups(
        subtitlePath: "webdav://\(sourceID)/Season/Episode 01.ass",
        videoPath: "webdav://\(sourceID)/Season/Episode 01.mkv",
        videoName: "Episode 01.mkv",
        format: .ass,
        cueGroups: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:03.00",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "remote searchable line"
            ).cueGroup(eventIndex: 0)
        ],
        sourceID: sourceID,
        subtitleRelativePath: "Season/Episode 01.ass",
        videoRelativePath: "Season/Episode 01.mkv",
        fileSize: 123,
        modifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
        videoFileSize: 456,
        videoModifiedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    let sources = try database.remoteMediaSources()
    #expect(sources.count == 1)
    let source = try #require(sources.first)
    #expect(source.id == sourceID)
    #expect(source.type == .webdav)
    #expect(source.provider == .alist)
    #expect(source.path == "http://example.test:5244/dav/baidu")
    #expect(source.displayName == "AList Baidu")
    #expect(source.credentialRef == "credential-ref")

    let unscopedResults = try database.search("remote")
    #expect(unscopedResults.count == 1)
    #expect(unscopedResults[0].subtitleSourceID == sourceID)
    #expect(unscopedResults[0].subtitleSourceRelativePath == "Season/Episode 01.ass")
    #expect(unscopedResults[0].videoSourceID == sourceID)
    #expect(unscopedResults[0].videoSourceRelativePath == "Season/Episode 01.mkv")

    #expect(try database.search("remote", under: [], remoteSourceIDs: []).isEmpty)
    #expect(try database.search("remote", under: [], remoteSourceIDs: [sourceID]).count == 1)
}

private func temporaryRemoteDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerRemoteDatabaseTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
}
