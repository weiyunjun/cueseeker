import Foundation
import Testing
@testable import CueSeekerCore

extension UserDefaults {
    static func temporary(suiteName: String) -> UserDefaults? {
        let plistURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(suiteName).plist")
        return UserDefaults(suiteName: plistURL.path)
    }

    func removePersistentDomainAndPlist(forName suiteName: String) {
        let path = suiteName.hasPrefix("/")
            ? suiteName
            : FileManager.default.temporaryDirectory
                .appendingPathComponent("\(suiteName).plist").path
        removePersistentDomain(forName: path)
        removePersistentDomain(forName: suiteName)
        _ = synchronize()
        try? FileManager.default.removeItem(atPath: path)
        let homePlistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(suiteName).plist")
        try? FileManager.default.removeItem(at: homePlistURL)
    }
}

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
        #expect(WebDAVAddress.defaultDisplayName(for: parsed) == "NieR:Automata")

        // Missing scheme auto-completes to http:// while preserving port and path
        let schemeless = try #require(
            WebDAVAddress.parseURL(from: "192.168.1.173:5244/115/%E4%BA%91%E4%B8%8B%E8%BD%BD/NieR:Automata/")
        )
        #expect(schemeless.isWebDAVURL)
        #expect(schemeless.mediaPath == parsed.mediaPath)

        // Case-insensitive http:// and https:// prefixes
        let upperHTTP = try #require(WebDAVAddress.parseURL(from: "HTTP://192.168.1.173:5244/dav"))
        #expect(upperHTTP.mediaPath == "http://192.168.1.173:5244/dav")
        let mixedHTTPS = try #require(WebDAVAddress.parseURL(from: "Https://nas.local:8443/dav/"))
        #expect(mixedHTTPS.mediaPath == "https://nas.local:8443/dav")

        // Unbracketed IPv6, bracketed IPv6 with port, and user@ prefix stripping
        let bareIPv6 = try #require(WebDAVAddress.parseURL(from: "2001:db8::1/dav/动漫"))
        #expect(bareIPv6.mediaPath == "http://[2001:db8::1]/dav/动漫")
        let bracketedIPv6Port = try #require(WebDAVAddress.parseURL(from: "https://[fe80::1]:5244/dav"))
        #expect(bracketedIPv6Port.mediaPath == "https://[fe80::1]:5244/dav")
        let withUserPrefix = try #require(WebDAVAddress.parseURL(from: "admin:pass@192.168.1.173:5244/dav"))
        #expect(withUserPrefix.mediaPath == "http://192.168.1.173:5244/dav")

        // Rejects non-WebDAV schemes, out-of-range IPv4, invalid IPv6, and out-of-range ports
        #expect(WebDAVAddress.parseURL(from: "   ") == nil)
        #expect(WebDAVAddress.parseURL(from: "smb://192.168.1.173/dav") == nil)
        #expect(WebDAVAddress.parseURL(from: "ftp://192.168.1.173/dav") == nil)
        #expect(WebDAVAddress.parseURL(from: "nfs://192.168.1.173/dav") == nil)
        #expect(WebDAVAddress.parseURL(from: "192.168.1.999:5244/dav") == nil)
        #expect(WebDAVAddress.parseURL(from: "[not-an-ipv6]/dav") == nil)
        #expect(WebDAVAddress.parseURL(from: "192.168.1.173:70000/dav") == nil)
        #expect(WebDAVAddress.parseURL(from: "192.168.1.173:0/dav") == nil)

        let rootOnly = try #require(WebDAVAddress.parseURL(from: "http://192.168.1.173:5244/"))
        #expect(WebDAVAddress.defaultDisplayName(for: rootOnly) == "192.168.1.173")

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
        let defaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        defer { defaults.removePersistentDomainAndPlist(forName: suiteName) }

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
        let defaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        defer { defaults.removePersistentDomainAndPlist(forName: suiteName) }

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

        #expect(WebDAVClient.defaultUserAgent == "pan.baidu.com")
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
        let databaseURL = tempRoot.appendingPathComponent("CueSeeker.sqlite")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let rootURL = URL.fromMediaPath("http://192.168.1.173:5244/115/云下载/NieR:Automata")
        defer {
            WebDAVClient.shared.setCustomHTTPHandlerForTesting(nil)
            WebDAVConfigurationStore.shared.remove(url: rootURL)
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let config = WebDAVRootConfig(
            rootPath: rootURL.mediaPath,
            davRootPath: "http://192.168.1.173:5244/dav/115/云下载/NieR:Automata",
            name: "NieR:Automata",
            address: rootURL.mediaPath,
            username: "user",
            password: "pw"
        )
        WebDAVConfigurationStore.shared.save(config)

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

    @Test
    func subtitleCacheAndConfigurationStoreIsolateDebugReleaseAndUnitTests() throws {
        let fakeAppSupport = URL(
            fileURLWithPath: "/Users/testuser/Library/Application Support",
            isDirectory: true
        )
        #expect(
            WebDAVSubtitleCache.defaultCacheDirectoryURL(
                for: .debug,
                baseApplicationSupportDirectoryURL: fakeAppSupport
            ).path == "/Users/testuser/Library/Application Support/CueSeeker/debug/WebDAVSubtitleCache"
        )
        #expect(
            WebDAVSubtitleCache.defaultCacheDirectoryURL(
                for: .release,
                baseApplicationSupportDirectoryURL: fakeAppSupport
            ).path == "/Users/testuser/Library/Application Support/CueSeeker/release/WebDAVSubtitleCache"
        )
        #expect(
            WebDAVSubtitleCache.defaultCacheDirectoryURL().standardizedFileURL
                == ApplicationInfo.unitTestSubtitleCacheDirectoryURL.standardizedFileURL
        )

        let debugSuite = "CueSeeker.WebDAVDebugSuite.\(UUID().uuidString)"
        let releaseSuite = "CueSeeker.WebDAVReleaseSuite.\(UUID().uuidString)"
        let debugDefaults = try #require(UserDefaults.temporary(suiteName: debugSuite))
        let releaseDefaults = try #require(UserDefaults.temporary(suiteName: releaseSuite))
        defer {
            debugDefaults.removePersistentDomainAndPlist(forName: debugSuite)
            releaseDefaults.removePersistentDomainAndPlist(forName: releaseSuite)
        }

        let debugStore = WebDAVConfigurationStore(userDefaults: debugDefaults)
        let releaseStore = WebDAVConfigurationStore(userDefaults: releaseDefaults)
        let debugConfig = WebDAVRootConfig(
            rootPath: "http://192.168.1.173:5244/dav/baidu/NieR",
            davRootPath: "http://192.168.1.173:5244/dav/baidu/NieR",
            name: "NieR Debug",
            address: "http://192.168.1.173:5244/dav/baidu/NieR",
            username: "alist",
            password: "secret"
        )
        debugStore.save(debugConfig)

        #expect(
            debugStore.matchingConfig(
                forMediaPath: "http://192.168.1.173:5244/dav/baidu/NieR/Episode 01.mkv"
            )?.name == "NieR Debug"
        )
        #expect(
            releaseStore.matchingConfig(
                forMediaPath: "http://192.168.1.173:5244/dav/baidu/NieR/Episode 01.mkv"
            ) == nil
        )
    }

    @Test
    func validateDirectoryAllowsAnonymousCredentialsWithoutAuthorizationHeader() async throws {
        let suiteName = "CueSeeker.WebDAVAnonTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        defer { defaults.removePersistentDomainAndPlist(forName: suiteName) }

        let store = WebDAVConfigurationStore(userDefaults: defaults)
        let seenAuthHeaders = LockedBox<[String?]>([])

        let client = WebDAVClient(configurationStore: store) { request in
            seenAuthHeaders.withValue { $0.append(request.value(forHTTPHeaderField: "Authorization")) }
            let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>/dav/Public/Anime/</D:href>
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
        }

        let config = try await client.validateDirectory(
            name: "",
            address: "http://192.168.1.173:5244/dav/Public/Anime",
            username: "",
            password: ""
        )

        #expect(config.name == "Anime")
        #expect(config.username.isEmpty)
        #expect(config.password.isEmpty)
        #expect(config.basicAuthorizationValue == nil)
        #expect(seenAuthHeaders.withValue { $0 } == [nil])
    }

    @Test
    func webdavFolderAndFileGroupRenameUpdatesDatabaseSubtitleCacheAndRootConfigAndRollsBackOnFailure() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerWebDAVRenameTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let databaseURL = tempDir.appendingPathComponent("index.sqlite")
        let rootURL = URL.fromMediaPath("http://192.168.1.173:5244/115/云下载/Show")
        let renamedRootURL = URL.fromMediaPath("http://192.168.1.173:5244/115/云下载/Show Renamed")
        defer {
            WebDAVClient.shared.setCustomHTTPHandlerForTesting(nil)
            WebDAVConfigurationStore.shared.remove(url: rootURL)
            WebDAVConfigurationStore.shared.remove(url: renamedRootURL)
            try? FileManager.default.removeItem(at: tempDir)
        }
        let config = WebDAVRootConfig(
            rootPath: rootURL.mediaPath,
            davRootPath: "http://192.168.1.173:5244/dav/115/云下载/Show",
            name: "Custom Show Name",
            address: rootURL.mediaPath,
            username: "",
            password: ""
        )
        WebDAVConfigurationStore.shared.save(config)

        let srtContent = """
        1
        00:00:01,000 --> 00:00:03,000
        Anonymous WebDAV rename line.
        """

        // Track simulated remote WebDAV paths (DAV paths without trailing slash) -> isDirectory
        let remoteItems = LockedBox<[String: Bool]>([
            "/dav/115/云下载": true,
            "/dav/115/云下载/Show": true,
            "/dav/115/云下载/Show/EP01.mkv": false,
            "/dav/115/云下载/Show/EP01.srt": false,
        ])
        let moveHistory = LockedBox<[(from: String, to: String)]>([])
        let failSecondMove = LockedBox<Bool>(false)

        WebDAVClient.shared.setCustomHTTPHandlerForTesting { request in
            let method = request.httpMethod ?? "GET"
            let rawPath = request.url?.path ?? ""
            let decodedPath = (rawPath.removingPercentEncoding ?? rawPath).precomposedStringWithCanonicalMapping
            let cleanPath = decodedPath.count > 1 && decodedPath.hasSuffix("/")
                ? String(decodedPath.dropLast())
                : decodedPath
            let depth = request.value(forHTTPHeaderField: "Depth") ?? "0"

            if method == "PROPFIND" {
                let items = remoteItems.withValue { $0 }
                guard let isDir = items[cleanPath] else {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 404,
                        httpVersion: "HTTP/1.1",
                        headerFields: nil
                    )!
                    return (Data(), response)
                }

                var responseBlocks: [String] = []
                func xmlBlock(path: String, isCollection: Bool) -> String {
                    let href = isCollection ? path + "/" : path
                    let encodedHref = href.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? href
                    if isCollection {
                        return """
                        <D:response>
                          <D:href>\(encodedHref)</D:href>
                          <D:propstat>
                            <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                            <D:status>HTTP/1.1 200 OK</D:status>
                          </D:propstat>
                        </D:response>
                        """
                    } else {
                        return """
                        <D:response>
                          <D:href>\(encodedHref)</D:href>
                          <D:propstat>
                            <D:prop>
                              <D:resourcetype/>
                              <D:getcontentlength>\(srtContent.utf8.count)</D:getcontentlength>
                              <D:getlastmodified>Mon, 14 Oct 2026 00:00:00 GMT</D:getlastmodified>
                            </D:prop>
                            <D:status>HTTP/1.1 200 OK</D:status>
                          </D:propstat>
                        </D:response>
                        """
                    }
                }

                responseBlocks.append(xmlBlock(path: cleanPath, isCollection: isDir))
                if isDir && depth == "1" {
                    let prefix = cleanPath + "/"
                    for (itemPath, itemIsDir) in items.sorted(by: { $0.key < $1.key }) where itemPath.hasPrefix(prefix) {
                        let remainder = itemPath.dropFirst(prefix.count)
                        if !remainder.contains("/") {
                            responseBlocks.append(xmlBlock(path: itemPath, isCollection: itemIsDir))
                        }
                    }
                }

                let xml = """
                <?xml version="1.0" encoding="utf-8"?>
                <D:multistatus xmlns:D="DAV:">
                \(responseBlocks.joined(separator: "\n"))
                </D:multistatus>
                """
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 207,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/xml"]
                )!
                return (Data(xml.utf8), response)
            } else if method == "GET" {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (Data(srtContent.utf8), response)
            } else if method == "MOVE" {
                let destHeader = request.value(forHTTPHeaderField: "Destination") ?? ""
                let destURL = URL(string: destHeader)
                let destRawPath = destURL?.path ?? ""
                let destDecoded = (destRawPath.removingPercentEncoding ?? destRawPath).precomposedStringWithCanonicalMapping
                let cleanDest = destDecoded.count > 1 && destDecoded.hasSuffix("/")
                    ? String(destDecoded.dropLast())
                    : destDecoded

                let shouldFail = failSecondMove.withValue { flag -> Bool in
                    if flag && cleanPath.hasSuffix(".srt") {
                        return true
                    }
                    return false
                }
                if shouldFail {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 403,
                        httpVersion: "HTTP/1.1",
                        headerFields: nil
                    )!
                    return (Data(), response)
                }

                moveHistory.withValue { $0.append((from: cleanPath, to: cleanDest)) }
                remoteItems.withValue { items in
                    var updated: [String: Bool] = [:]
                    for (k, v) in items {
                        if k == cleanPath {
                            updated[cleanDest] = v
                        } else if k.hasPrefix(cleanPath + "/") {
                            let suffix = String(k.dropFirst(cleanPath.count))
                            updated[cleanDest + suffix] = v
                        } else {
                            updated[k] = v
                        }
                    }
                    items = updated
                }
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 201,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (Data(), response)
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
        _ = try SubtitleIndexer().index(folder: rootURL, into: indexingDatabase)
        try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange(libraryID: libraryID)

        let renamer = LibraryRenamer(database: indexingDatabase)
        let initialVideoPath = "http://192.168.1.173:5244/115/云下载/Show/EP01.mkv"
        let initialSubtitlePath = "http://192.168.1.173:5244/115/云下载/Show/EP01.srt"

        // 1. Test rollback when second file MOVE fails (403 Forbidden)
        failSecondMove.withValue { $0 = true }
        let failingPlan = try renamer.checkConflicts(
            .fileGroup(videoPath: initialVideoPath, newBaseName: "EP09")
        )
        #expect(throws: LibraryRenameError.renameFailed(path: initialSubtitlePath)) {
            try renamer.perform(failingPlan)
        }
        // Video must have been rolled back on WebDAV server
        #expect(remoteItems.withValue { $0["/dav/115/云下载/Show/EP01.mkv"] } == false)
        #expect(remoteItems.withValue { $0["/dav/115/云下载/Show/EP09.mkv"] } == nil)
        failSecondMove.withValue { $0 = false }

        // 2. Test successful file group rename on WebDAV
        let filePlan = try renamer.checkConflicts(
            .fileGroup(videoPath: initialVideoPath, newBaseName: "EP02")
        )
        try renamer.perform(filePlan)

        let movedSubtitleURL = URL.fromMediaPath("http://192.168.1.173:5244/115/云下载/Show/EP02.srt")
        #expect(
            FileManager.default.fileExists(
                atPath: WebDAVSubtitleCache.shared.cachedFileURL(for: movedSubtitleURL).path
            )
        )
        let searchAfterFileRename = try SearchDatabase(path: databaseURL).search("Anonymous")
        #expect(
            searchAfterFileRename.first?.videoPath
                == "http://192.168.1.173:5244/115/云下载/Show/EP02.mkv"
        )

        // 3. Test successful WebDAV root folder rename (updates config rootPath, davRootPath, address, and name)
        let folderPlan = try renamer.checkConflicts(
            .folder(path: rootURL.mediaPath, newName: "Show Renamed")
        )
        try renamer.perform(folderPlan)

        let updatedConfig = try #require(WebDAVConfigurationStore.shared.config(for: renamedRootURL))
        #expect(updatedConfig.rootPath == "http://192.168.1.173:5244/115/云下载/Show Renamed")
        #expect(updatedConfig.davRootPath == "http://192.168.1.173:5244/dav/115/云下载/Show Renamed")
        #expect(updatedConfig.address == "http://192.168.1.173:5244/115/云下载/Show Renamed")
        #expect(updatedConfig.name == "Show Renamed")

        let searchAfterFolderRename = try SearchDatabase(path: databaseURL).search("Anonymous")
        #expect(
            searchAfterFolderRename.first?.videoPath
                == "http://192.168.1.173:5244/115/云下载/Show Renamed/EP02.mkv"
        )
    }

    @Test
    func connectAndBrowseDirectoryFiltersUnsupportedFilesOrdersFoldersFirstAndScopesSubfolderConfig() async throws {
        let suiteName = "CueSeeker.WebDAVBrowserTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        defer { defaults.removePersistentDomainAndPlist(forName: suiteName) }

        let store = WebDAVConfigurationStore(userDefaults: defaults)
        let client = WebDAVClient(configurationStore: store) { request in
            let urlString = request.url?.absoluteString ?? ""
            guard urlString.contains("/dav/115/") else {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 405,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (Data(), response)
            }

            let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>/dav/115/%E5%8A%A8%E6%BC%AB/</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/115/%E5%8A%A8%E6%BC%AB/Season%2010/</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/115/%E5%8A%A8%E6%BC%AB/Season%202/</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/115/%E5%8A%A8%E6%BC%AB/Preview.mp4</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype/></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/115/%E5%8A%A8%E6%BC%AB/Preview.ass</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype/></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/115/%E5%8A%A8%E6%BC%AB/poster.jpg</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype/></D:prop>
                  <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
              </D:response>
              <D:response>
                <D:href>/dav/115/%E5%8A%A8%E6%BC%AB/tvshow.nfo</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype/></D:prop>
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
        }

        let connected = try await client.connectAndBrowseDirectory(
            address: "http://192.168.1.5:5244/115/动漫",
            username: "admin",
            password: "secret"
        )

        #expect(connected.config.rootPath == "http://192.168.1.5:5244/115/动漫")
        #expect(connected.config.davRootPath == "http://192.168.1.5:5244/dav/115/动漫")
        #expect(connected.config.name == "动漫")
        #expect(connected.items.map(\.name) == ["Season 2", "Season 10", "Preview.ass", "Preview.mp4"])
        #expect(connected.items.map(\.kind) == [.folder, .folder, .subtitle, .video])

        let season2URL = connected.items[0].url
        let scoped = connected.config.scopedConfig(for: season2URL)
        #expect(scoped.rootPath == "http://192.168.1.5:5244/115/动漫/Season 2")
        #expect(scoped.davRootPath == "http://192.168.1.5:5244/dav/115/动漫/Season 2")
        #expect(scoped.name == "Season 2")
        #expect(scoped.address == "http://192.168.1.5:5244/115/动漫/Season 2")
        #expect(scoped.username == "admin")
        #expect(scoped.password == "secret")
    }

    @Test
    func connectAndBrowseDirectoryRemembersAListDAVOriginOnSubsequentConnections() async throws {
        let suiteName = "CueSeeker.WebDAVOriginCacheTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        defer { defaults.removePersistentDomainAndPlist(forName: suiteName) }

        let requestedPaths = LockedBox<[String]>([])
        let client = WebDAVClient(
            configurationStore: WebDAVConfigurationStore(userDefaults: defaults)
        ) { request in
            let path = request.url?.path ?? ""
            requestedPaths.withValue { $0.append(path) }
            guard path.hasPrefix("/dav/") else {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 405,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (Data(), response)
            }
            let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <D:multistatus xmlns:D="DAV:">
              <D:response>
                <D:href>\(path.hasSuffix("/") ? path : path + "/")</D:href>
                <D:propstat>
                  <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop>
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
        }

        _ = try await client.connectAndBrowseDirectory(
            address: "http://192.168.1.99:5244/115/Movies",
            username: "admin",
            password: "secret"
        )
        #expect(requestedPaths.withValue { $0 } == ["/115/Movies", "/dav/115/Movies"])

        requestedPaths.withValue { $0.removeAll() }
        let second = try await client.connectAndBrowseDirectory(
            address: "http://192.168.1.99:5244/115/Anime",
            username: "admin",
            password: "secret"
        )
        #expect(second.config.davRootPath == "http://192.168.1.99:5244/dav/115/Anime")
        #expect(requestedPaths.withValue { $0 } == ["/dav/115/Anime"])
    }
}
