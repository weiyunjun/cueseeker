import Foundation
import Testing
@testable import CueSeekerCore

private final class InMemorySMBBackend: SMBBackendProtocol, @unchecked Sendable {
    struct Node {
        var isDirectory: Bool
        var data: Data
        var modifiedAt: Date
    }

    private let lock = NSLock()
    var sharesByHost: [String: [String]] = [:]
    var nodesBySharePath: [String: Node] = [:]
    var requiredCredentials: (username: String, password: String)?

    func addShare(host: String, share: String) {
        lock.lock()
        defer { lock.unlock() }
        var list = sharesByHost[host.lowercased(), default: []]
        if !list.contains(share) {
            list.append(share)
        }
        sharesByHost[host.lowercased()] = list
        let rootKey = Self.key(host: host, share: share, relativePath: "")
        nodesBySharePath[rootKey] = Node(isDirectory: true, data: Data(), modifiedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func addDirectory(host: String, share: String, relativePath: String, modifiedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        addShare(host: host, share: share)
        lock.lock()
        defer { lock.unlock() }
        let normalized = Self.normalizeRel(relativePath)
        var current = ""
        for part in normalized.split(separator: "/") {
            current = current.isEmpty ? String(part) : "\(current)/\(part)"
            let key = Self.key(host: host, share: share, relativePath: current)
            if nodesBySharePath[key] == nil {
                nodesBySharePath[key] = Node(isDirectory: true, data: Data(), modifiedAt: modifiedAt)
            }
        }
    }

    func addFile(
        host: String,
        share: String,
        relativePath: String,
        data: Data,
        modifiedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) {
        let normalized = Self.normalizeRel(relativePath)
        let parent = (normalized as NSString).deletingLastPathComponent
        if !parent.isEmpty && parent != "." {
            addDirectory(host: host, share: share, relativePath: parent, modifiedAt: modifiedAt)
        } else {
            addShare(host: host, share: share)
        }
        lock.lock()
        defer { lock.unlock() }
        let key = Self.key(host: host, share: share, relativePath: normalized)
        nodesBySharePath[key] = Node(isDirectory: false, data: data, modifiedAt: modifiedAt)
    }

    private func verifyAuth(username: String, password: String) throws {
        lock.lock()
        let required = requiredCredentials
        lock.unlock()
        if let required {
            guard username == required.username && password == required.password else {
                throw SMBError.authenticationFailed
            }
        }
    }

    func listShares(
        host: String,
        port _: Int,
        username: String,
        password: String
    ) throws -> [String] {
        try verifyAuth(username: username, password: password)
        lock.lock()
        defer { lock.unlock() }
        guard let shares = sharesByHost[host.lowercased()] else {
            throw SMBError.networkError("Host unreachable")
        }
        return shares
    }

    func listDirectory(
        host: String,
        port _: Int,
        share: String,
        relativePath: String,
        username: String,
        password: String
    ) throws -> [SMBDirectoryEntry] {
        try verifyAuth(username: username, password: password)
        lock.lock()
        defer { lock.unlock() }

        let normalized = Self.normalizeRel(relativePath)
        let dirKey = Self.key(host: host, share: share, relativePath: normalized)
        guard let dirNode = nodesBySharePath[dirKey] else {
            throw SMBError.directoryNotFound
        }
        guard dirNode.isDirectory else {
            throw SMBError.notADirectory
        }

        let prefix = normalized.isEmpty ? "" : "\(normalized)/"
        let sharePrefix = "\(host.lowercased())::\(share)::"
        var entries: [SMBDirectoryEntry] = []

        for (fullKey, node) in nodesBySharePath {
            guard fullKey.hasPrefix(sharePrefix) else { continue }
            let rel = String(fullKey.dropFirst(sharePrefix.count))
            guard !rel.isEmpty, rel.hasPrefix(prefix) else { continue }
            let remainder = String(rel.dropFirst(prefix.count))
            guard !remainder.isEmpty, !remainder.contains("/") else { continue }
            entries.append(
                SMBDirectoryEntry(
                    name: remainder,
                    isDirectory: node.isDirectory,
                    fileSize: Int64(node.data.count),
                    modifiedAt: node.modifiedAt
                )
            )
        }
        return entries
    }

    func stat(
        host: String,
        port _: Int,
        share: String,
        relativePath: String,
        username: String,
        password: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        try verifyAuth(username: username, password: password)
        lock.lock()
        defer { lock.unlock() }

        let normalized = Self.normalizeRel(relativePath)
        let key = Self.key(host: host, share: share, relativePath: normalized)
        guard let node = nodesBySharePath[key] else {
            throw SMBError.directoryNotFound
        }
        return (node.isDirectory, Int64(node.data.count), node.modifiedAt)
    }

    func readRange(
        host: String,
        port _: Int,
        share: String,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String
    ) throws -> (data: Data, totalSize: UInt64) {
        try verifyAuth(username: username, password: password)
        lock.lock()
        defer { lock.unlock() }

        let normalized = Self.normalizeRel(relativePath)
        let key = Self.key(host: host, share: share, relativePath: normalized)
        guard let node = nodesBySharePath[key] else {
            throw SMBError.directoryNotFound
        }
        guard !node.isDirectory else {
            throw SMBError.notADirectory
        }
        let total = UInt64(node.data.count)
        guard offset < total, maxLength > 0 else {
            return (Data(), total)
        }
        let end = min(total, offset + maxLength)
        let slice = node.data.subdata(in: Int(offset)..<Int(end))
        return (slice, total)
    }

    func rename(
        host: String,
        port _: Int,
        share: String,
        oldRelativePath: String,
        newRelativePath: String,
        username: String,
        password: String
    ) throws {
        try verifyAuth(username: username, password: password)
        lock.lock()
        defer { lock.unlock() }

        let oldNorm = Self.normalizeRel(oldRelativePath)
        let newNorm = Self.normalizeRel(newRelativePath)
        let oldKey = Self.key(host: host, share: share, relativePath: oldNorm)
        let newKey = Self.key(host: host, share: share, relativePath: newNorm)

        guard let targetNode = nodesBySharePath[oldKey] else {
            throw SMBError.directoryNotFound
        }
        if oldKey != newKey && nodesBySharePath[newKey] != nil {
            throw SMBError.targetAlreadyExists
        }

        nodesBySharePath.removeValue(forKey: oldKey)
        nodesBySharePath[newKey] = targetNode

        if targetNode.isDirectory {
            let oldChildPrefix = Self.key(host: host, share: share, relativePath: oldNorm) + "/"
            let newChildPrefix = Self.key(host: host, share: share, relativePath: newNorm) + "/"
            let childKeys = nodesBySharePath.keys.filter { $0.hasPrefix(oldChildPrefix) }
            for childKey in childKeys {
                if let childNode = nodesBySharePath.removeValue(forKey: childKey) {
                    let suffix = String(childKey.dropFirst(oldChildPrefix.count))
                    nodesBySharePath[newChildPrefix + suffix] = childNode
                }
            }
        }
    }

    private static func normalizeRel(_ path: String) -> String {
        path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .joined(separator: "/")
            .precomposedStringWithCanonicalMapping
    }

    private static func key(host: String, share: String, relativePath: String) -> String {
        "\(host.lowercased())::\(share)::\(relativePath)"
    }
}

@Suite(.serialized)
struct SMBSupportTests {
    @Test
    func smbAddressNormalizesPrefixHostClassificationPercentEncodingAndPorts() throws {
        // Strict case-sensitive "smb://" prefix rule on parseURL:
        // - Lowercase "smb://" is parsed directly
        // - Missing "smb://" has "smb://" prepended in background
        // - Uppercase "SMB://" or other schemes "http://" become "smb://SMB://..." and fail host validation
        #expect(SMBAddress.parseURL(from: "   ") == nil)
        #expect(SMBAddress.parseURL(from: "SMB://nas.local/Media") == nil)
        #expect(SMBAddress.parseURL(from: "http://192.0.2.10/Media") == nil)
        #expect(SMBAddress.parseURL(from: "192.0.2.999/Media") == nil)
        #expect(SMBAddress.parseURL(from: "[not-an-ipv6]/Media") == nil)

        // Host classification: fixed IPv4 / IPv6 vs friendly name
        #expect(SMBAddress.classifyHost("192.0.2.10") == .ipv4("192.0.2.10"))
        #expect(SMBAddress.classifyHost("[fe80::1]") == .ipv6("fe80::1"))
        #expect(SMBAddress.classifyHost("2001:db8::1") == .ipv6("2001:db8::1"))
        #expect(SMBAddress.classifyHost("LEDE") == .friendlyName("LEDE"))
        #expect(SMBAddress.classifyHost("nas.local") == .friendlyName("nas.local"))
        #expect(SMBAddress.classifyHost("weiyunjun的Mac mini") == .friendlyName("weiyunjun的Mac mini"))

        let raw = "nas.local/Media/%E5%8A%A8%E6%BC%AB/NieR:Automata/"
        let parsed = try #require(SMBAddress.parseURL(from: raw, portOverride: 445))
        #expect(parsed.isSMBURL)
        #expect(parsed.isRemoteMediaURL)
        #expect(!SMBAddress.isHostRoot(parsed))
        #expect(parsed.mediaPath == "smb://nas.local/Media/动漫/NieR:Automata")
        #expect(SMBAddress.defaultDisplayName(for: parsed) == "NieR:Automata")

        let split = SMBAddress.splitShareAndRelativePath(for: parsed)
        #expect(split.share == "Media")
        #expect(split.relativePath == "动漫/NieR:Automata")

        let customPortURL = try #require(SMBAddress.parseURL(from: "smb://192.0.2.10/Media/Shows", portOverride: 1445))
        #expect(customPortURL.mediaPath == "smb://192.0.2.10:1445/Media/Shows")
        #expect(SMBAddress.effectivePort(for: customPortURL) == 1445)

        let ipv6URL = try #require(SMBAddress.parseURL(from: "[fe80::1]/Media/动漫", portOverride: 445))
        #expect(ipv6URL.mediaPath == "smb://[fe80::1]/Media/动漫")
        #expect(SMBAddress.decodedHost(for: ipv6URL) == "fe80::1")

        let friendlyWithSpaceAndCJK = try #require(SMBAddress.parseURL(from: "weiyunjun的Mac mini/动漫", portOverride: 445))
        #expect(friendlyWithSpaceAndCJK.mediaPath == "smb://weiyunjun的Mac mini/动漫")
        #expect(SMBAddress.decodedHost(for: friendlyWithSpaceAndCJK) == "weiyunjun的Mac mini")

        let hostOnly = try #require(SMBAddress.parseURL(from: "LEDE", portOverride: 445))
        #expect(SMBAddress.isHostRoot(hostOnly))
        #expect(hostOnly.mediaPath == "smb://LEDE")
        #expect(SMBAddress.defaultDisplayName(for: hostOnly) == "LEDE")

        // Verify SMBHostResolver passes IPv4/IPv6 directly and resolves friendly names to IP
        defer { SMBHostResolver.shared.setCustomResolverForTesting(nil) }
        SMBHostResolver.shared.setCustomResolverForTesting { friendly in
            friendly == "weiyunjun的Mac mini" ? "192.0.2.55" : nil
        }
        #expect(try SMBHostResolver.shared.resolveConnectionHost("192.0.2.10") == "192.0.2.10")
        #expect(try SMBHostResolver.shared.resolveConnectionHost("[fe80::1]") == "fe80::1")
        #expect(try SMBHostResolver.shared.resolveConnectionHost("weiyunjun的Mac mini") == "192.0.2.55")
    }

    @Test
    func libraryRootGroupsGroupNestedSMBFoldersByHostAndPath() {
        let outer = URL.fromMediaPath("smb://nas.local/Media/动漫")
        let inner = URL.fromMediaPath("smb://nas.local/Media/动漫/NieR:Automata")
        let otherShare = URL.fromMediaPath("smb://nas.local/Archive/动漫")
        let localRoot = URL(fileURLWithPath: "/Users/test/Videos")

        let representatives = LibraryRootGroups.representatives(
            of: [inner, outer, otherShare, localRoot]
        )

        #expect(representatives.map(\.mediaPath) == [
            outer.mediaPath,
            otherShare.mediaPath,
            localRoot.mediaPath,
        ])
        #expect(
            LibraryRootGroups.coveringRoot(of: inner, in: [outer, otherShare])?.mediaPath
                == outer.mediaPath
        )
        #expect(
            LibraryRootGroups.representatives(inside: outer, of: [inner, otherShare]).map(\.mediaPath)
                == [inner.mediaPath]
        )
    }

    @Test
    func subtitleIndexerIndexesSMBFolderCachesSubtitlesAndSupportsRenameAndLoopbackStreaming() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "CueSeekerSMBIndexTests-\(UUID().uuidString)",
            isDirectory: true
        )
        let cacheDir = tempRoot.appendingPathComponent("SubtitleCache", isDirectory: true)
        let databaseURL = tempRoot.appendingPathComponent("CueSeeker.sqlite")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let rootURL = URL.fromMediaPath("smb://nas.local/Media/动漫/NieR:Automata")
        let renamedRootURL = URL.fromMediaPath("smb://nas.local/Media/动漫/NieR Automata Ver1.1a")
        defer {
            SMBClient.shared.setCustomBackendForTesting(nil)
            SMBConfigurationStore.shared.remove(url: rootURL)
            SMBConfigurationStore.shared.remove(url: renamedRootURL)
            try? FileManager.default.removeItem(at: tempRoot)
        }

        WebDAVSubtitleCache.shared.setCacheDirectoryURLForTesting(cacheDir)

        let backend = InMemorySMBBackend()
        backend.requiredCredentials = (username: "mediauser", password: "secret")
        let srtContent = """
        1
        00:00:01,000 --> 00:00:03,000
        Everything that lives is designed to end.

        2
        00:00:04,000 --> 00:00:06,000
        SMB indexed subtitle line.
        """
        let fakeVideoBytes = Data((0..<4096).map { UInt8($0 & 0xFF) })

        backend.addFile(
            host: "nas.local",
            share: "Media",
            relativePath: "动漫/NieR:Automata/Episode 01.mkv",
            data: fakeVideoBytes
        )
        backend.addFile(
            host: "nas.local",
            share: "Media",
            relativePath: "动漫/NieR:Automata/Episode 01.srt",
            data: Data(srtContent.utf8)
        )
        SMBClient.shared.setCustomBackendForTesting(backend)

        let config = SMBRootConfig(
            rootPath: rootURL.mediaPath,
            name: "NieR:Automata",
            address: rootURL.mediaPath,
            port: 445,
            username: "mediauser",
            password: "secret"
        )
        SMBConfigurationStore.shared.save(config)

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
            "smb://nas.local/Media/动漫/NieR:Automata/Episode 01.srt"
        )
        let cachedFile = WebDAVSubtitleCache.shared.cachedFileURL(for: expectedSubtitleURL)
        #expect(FileManager.default.fileExists(atPath: cachedFile.path))

        let searchResults = try SearchDatabase(path: databaseURL).search("designed")
        #expect(searchResults.count == 1)
        #expect(
            searchResults.first?.videoPath
                == "smb://nas.local/Media/动漫/NieR:Automata/Episode 01.mkv"
        )

        // Verify loopback HTTP Range server for SMB video streaming
        let videoURL = URL.fromMediaPath("smb://nas.local/Media/动漫/NieR:Automata/Episode 01.mkv")
        let playable = SMBClient.shared.resolvePlayableInput(for: videoURL)
        #expect(playable.inputPath.hasPrefix("http://127.0.0.1:"))

        let streamURL = try #require(URL(string: playable.inputPath))
        var rangeRequest = URLRequest(url: streamURL)
        rangeRequest.setValue("bytes=100-299", forHTTPHeaderField: "Range")
        let (rangeData, response) = try await URLSession.shared.data(for: rangeRequest)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 206)
        #expect(rangeData == fakeVideoBytes.subdata(in: 100..<300))

        // Verify in-App SMB folder rename updates remote share, database, and configuration store
        let renamer = LibraryRenamer(database: indexingDatabase)
        let renamePlan = try renamer.checkConflicts(
            .folder(path: rootURL.mediaPath, newName: "NieR Automata Ver1.1a")
        )
        try renamer.perform(renamePlan)

        let updatedConfig = try #require(SMBConfigurationStore.shared.config(for: renamedRootURL))
        #expect(updatedConfig.name == "NieR Automata Ver1.1a")

        let postRenameResults = try SearchDatabase(path: databaseURL).search("designed")
        #expect(postRenameResults.first?.videoPath == "smb://nas.local/Media/动漫/NieR Automata Ver1.1a/Episode 01.mkv")
    }
}
