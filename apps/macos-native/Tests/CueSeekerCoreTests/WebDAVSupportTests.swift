import Foundation
import Testing
@testable import CueSeekerCore

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

@Suite(.serialized)
struct WebDAVSupportTests {
    @Test
    func webdavAddressNormalizesPercentEncodingAndColonsInPath() throws {
        let raw = "http://192.168.1.173:5244/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata/"
        let parsed = try #require(WebDAVAddress.parseURL(from: raw))

        #expect(parsed.isWebDAVURL)
        #expect(parsed.mediaPath == "http://192.168.1.173:5244/115/云下载/NieR:Automata")

        let roundTrip = URL.fromMediaPath(parsed.mediaPath)
        #expect(roundTrip.isWebDAVURL)
        #expect(roundTrip.mediaPath == parsed.mediaPath)
        #expect(roundTrip.lastPathComponent == "NieR:Automata")
    }

    @Test
    func libraryRootGroupsGroupNestedWebDAVFoldersByHostAndPath() {
        let outer = URL.fromMediaPath("http://192.168.1.173:5244/115/云下载")
        let inner = URL.fromMediaPath("http://192.168.1.173:5244/115/云下载/NieR:Automata")
        let otherHost = URL.fromMediaPath("http://192.168.1.174:5244/115/云下载")
        let localRoot = URL(fileURLWithPath: "/Users/test/Videos")

        let representatives = LibraryRootGroups.representatives(
            of: [inner, outer, otherHost, localRoot]
        )

        #expect(representatives.map(\.mediaPath) == [
            outer.mediaPath,
            otherHost.mediaPath,
            localRoot.mediaPath,
        ])
        #expect(
            LibraryRootGroups.coveringRoot(of: inner, in: [outer, otherHost])?.mediaPath
                == outer.mediaPath
        )
        #expect(
            LibraryRootGroups.representatives(inside: outer, of: [inner, otherHost]).map(\.mediaPath)
                == [inner.mediaPath]
        )
    }

    @Test
    func validateDirectoryFallsBackToAListDavPrefixAndVerifiesBasicAuth() async throws {
        let suiteName = "CueSeeker.WebDAVTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WebDAVConfigurationStore(userDefaults: defaults)
        let seenRequests = LockedBox<[(method: String, url: String, auth: String?)]>([])

        let client = WebDAVClient(configurationStore: store) { request in
            let urlString = request.url?.absoluteString ?? ""
            let method = request.httpMethod ?? ""
            let auth = request.value(forHTTPHeaderField: "Authorization")
            seenRequests.withValue { $0.append((method, urlString, auth)) }

            if urlString.contains("/dav/115/") {
                let xml = """
                <?xml version="1.0" encoding="utf-8"?>
                <D:multistatus xmlns:D="DAV:">
                  <D:response>
                    <D:href>/dav/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata/</D:href>
                    <D:propstat>
                      <D:prop>
                        <D:resourcetype><D:collection/></D:resourcetype>
                      </D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                </D:multistatus>
                """
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 207,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/xml"]
                )!
                return (Data(xml.utf8), response)
            } else {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 405,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (Data(), response)
            }
        }

        let config = try await client.validateDirectory(
            name: "NieR WebDAV",
            address: "http://192.168.1.173:5244/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata",
            username: "alist",
            password: "secret"
        )

        #expect(config.rootPath == "http://192.168.1.173:5244/115/云下载/NieR:Automata")
        #expect(config.davRootPath == "http://192.168.1.173:5244/dav/115/云下载/NieR:Automata")
        #expect(config.basicAuthorizationValue == "Basic YWxpc3Q6c2VjcmV0")

        let requests = seenRequests.withValue { $0 }
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.method == "PROPFIND" && $0.auth == "Basic YWxpc3Q6c2VjcmV0" })
    }

    @Test
    func resolvePlayableInputStripsBasicAuthOnCrossOrigin302Redirect() throws {
        let suiteName = "CueSeeker.WebDAVRedirectTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WebDAVConfigurationStore(userDefaults: defaults)
        let config = WebDAVRootConfig(
            rootPath: "http://192.168.1.173:5244/115/云下载/NieR:Automata",
            davRootPath: "http://192.168.1.173:5244/dav/115/云下载/NieR:Automata",
            name: "NieR",
            address: "http://192.168.1.173:5244/115/云下载/NieR:Automata",
            username: "admin",
            password: "password123"
        )
        store.save(config)

        let directCDNLink = "https://cdn.115.com/d/115/NieR-01.mkv?sign=l4QvJnyqwqihygH5hTzM4peyncH3EwU9AgYrYIABcNg=:0"
        let seenAuthHeaders = LockedBox<[String?]>([])
        let seenUserAgents = LockedBox<[String?]>([])

        let client = WebDAVClient(configurationStore: store) { request in
            seenAuthHeaders.withValue {
                $0.append(request.value(forHTTPHeaderField: "Authorization"))
            }
            seenUserAgents.withValue {
                $0.append(request.value(forHTTPHeaderField: "User-Agent"))
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": directCDNLink]
            )!
            return (Data(), response)
        }

        let videoURL = URL.fromMediaPath(
            "http://192.168.1.173:5244/115/云下载/NieR:Automata/Episode 01.mkv"
        )
        let resolved = client.resolvePlayableInput(for: videoURL)

        #expect(resolved.inputPath == directCDNLink)
        #expect(resolved.httpHeaders == "User-Agent: \(WebDAVClient.defaultUserAgent)\r\n")
        #expect(seenAuthHeaders.withValue { $0 } == [config.basicAuthorizationValue])
        #expect(seenUserAgents.withValue { $0 } == [WebDAVClient.defaultUserAgent])
    }

    @Test
    func subtitleIndexerIndexesWebDAVFolderAndCachesSubtitlesLocally() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "CueSeekerWebDAVIndexTests-\(UUID().uuidString)",
            isDirectory: true
        )
        let cacheDir = tempRoot.appendingPathComponent("SubtitleCache", isDirectory: true)
        let databaseURL = tempRoot.appendingPathComponent("CueSeeker.sqlite")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        defer {
            WebDAVClient.shared.setCustomHTTPHandlerForTesting(nil)
            try? FileManager.default.removeItem(at: tempRoot)
        }

        WebDAVSubtitleCache.shared.setCacheDirectoryURLForTesting(cacheDir)
        let rootURL = URL.fromMediaPath("http://192.168.1.173:5244/115/云下载/NieR:Automata")
        let config = WebDAVRootConfig(
            rootPath: rootURL.mediaPath,
            davRootPath: "http://192.168.1.173:5244/dav/115/云下载/NieR:Automata",
            name: "NieR:Automata",
            address: rootURL.mediaPath,
            username: "user",
            password: "pw"
        )
        WebDAVConfigurationStore.shared.save(config)
        defer { WebDAVConfigurationStore.shared.remove(url: rootURL) }

        let srtContent = """
        1
        00:00:01,000 --> 00:00:03,000
        Glory to mankind.

        2
        00:00:04,000 --> 00:00:06,000
        WebDAV indexed subtitle line.
        """

        WebDAVClient.shared.setCustomHTTPHandlerForTesting { request in
            let method = request.httpMethod ?? "GET"
            let path = request.url?.path ?? ""
            if method == "PROPFIND" {
                let xml = """
                <?xml version="1.0" encoding="utf-8"?>
                <D:multistatus xmlns:D="DAV:">
                  <D:response>
                    <D:href>/dav/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata/</D:href>
                    <D:propstat>
                      <D:prop>
                        <D:resourcetype><D:collection/></D:resourcetype>
                      </D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                  <D:response>
                    <D:href>/dav/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata/Episode%2001.mkv</D:href>
                    <D:propstat>
                      <D:prop>
                        <D:resourcetype/>
                        <D:getcontentlength>104857600</D:getcontentlength>
                        <D:getlastmodified>Mon, 14 Oct 2026 00:00:00 GMT</D:getlastmodified>
                      </D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                  <D:response>
                    <D:href>/dav/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata/Episode%2001.srt</D:href>
                    <D:propstat>
                      <D:prop>
                        <D:resourcetype/>
                        <D:getcontentlength>\(srtContent.utf8.count)</D:getcontentlength>
                        <D:getlastmodified>Mon, 14 Oct 2026 00:00:00 GMT</D:getlastmodified>
                      </D:prop>
                      <D:status>HTTP/1.1 200 OK</D:status>
                    </D:propstat>
                  </D:response>
                </D:multistatus>
                """
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 207,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/xml"]
                )!
                return (Data(xml.utf8), response)
            } else if path.hasSuffix("Episode 01.srt") {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (Data(srtContent.utf8), response)
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(), response)
        }

        try DatabaseBootstrap.prepare(at: databaseURL)
        let indexingDatabase = try IndexingDatabase(path: databaseURL)
        let libraryID = try indexingDatabase.addSearchPath(rootURL)
        let result = try SubtitleIndexer().index(folder: rootURL, into: indexingDatabase)
        try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange(
            libraryID: libraryID
        )

        #expect(result.scannedSubtitleFiles == 1)
        #expect(result.indexedSubtitleFiles == 1)
        #expect(result.indexedSubtitleEntries == 2)

        let expectedSubtitleURL = URL.fromMediaPath(
            "http://192.168.1.173:5244/115/云下载/NieR:Automata/Episode 01.srt"
        )
        let cachedFile = WebDAVSubtitleCache.shared.cachedFileURL(for: expectedSubtitleURL)
        #expect(FileManager.default.fileExists(atPath: cachedFile.path))

        let searchResults = try SearchDatabase(path: databaseURL).search("mankind")
        #expect(searchResults.count == 1)
        #expect(
            searchResults.first?.videoPath
                == "http://192.168.1.173:5244/115/云下载/NieR:Automata/Episode 01.mkv"
        )

        let playbackEntries = try PlaybackSubtitleDatabase(path: databaseURL)
            .entries(forSubtitleFile: expectedSubtitleURL)
        #expect(playbackEntries.count == 2)
        #expect(playbackEntries.first?.content == "Glory to mankind.")

        let contentDatabase = try IndexedContentDatabase(path: databaseURL)
        let subfolders = try contentDatabase.subfolders(under: rootURL)
        #expect(subfolders.map(\.folderPath) == [rootURL.mediaPath])
        let objects = try contentDatabase.objects(in: rootURL.mediaPath)
        #expect(objects.count == 1)
        #expect(objects.first?.videoName == "Episode 01.mkv")
        #expect(objects.first?.subtitles.count == 1)
        #expect(objects.first?.subtitles.first?.name == "Episode 01.srt")
    }
}
