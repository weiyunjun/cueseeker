import Foundation
import Testing
@testable import CueSeekerCore

private final class InMemoryFTPBackend: FTPBackendProtocol, @unchecked Sendable {
    struct Node {
        var isDirectory: Bool
        var data: Data
        var modifiedAt: Date
    }

    private let lock = NSLock()
    var nodesByHostPath: [String: Node] = [:]
    var requiredCredentials: (username: String, password: String)?

    func addRoot(host: String) {
        lock.lock()
        defer { lock.unlock() }
        let rootKey = Self.key(host: host, relativePath: "")
        if nodesByHostPath[rootKey] == nil {
            nodesByHostPath[rootKey] = Node(
                isDirectory: true,
                data: Data(),
                modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }
    }

    func addDirectory(
        host: String,
        relativePath: String,
        modifiedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) {
        addRoot(host: host)
        lock.lock()
        defer { lock.unlock() }
        let normalized = Self.normalizeRel(relativePath)
        var current = ""
        for part in normalized.split(separator: "/") {
            current = current.isEmpty ? String(part) : "\(current)/\(part)"
            let key = Self.key(host: host, relativePath: current)
            if nodesByHostPath[key] == nil {
                nodesByHostPath[key] = Node(isDirectory: true, data: Data(), modifiedAt: modifiedAt)
            }
        }
    }

    func addFile(
        host: String,
        relativePath: String,
        data: Data,
        modifiedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) {
        let normalized = Self.normalizeRel(relativePath)
        let parent = (normalized as NSString).deletingLastPathComponent
        if !parent.isEmpty && parent != "." {
            addDirectory(host: host, relativePath: parent, modifiedAt: modifiedAt)
        } else {
            addRoot(host: host)
        }
        lock.lock()
        defer { lock.unlock() }
        let key = Self.key(host: host, relativePath: normalized)
        nodesByHostPath[key] = Node(isDirectory: false, data: data, modifiedAt: modifiedAt)
    }

    private func verifyAuth(username: String, password: String) throws {
        lock.lock()
        let required = requiredCredentials
        lock.unlock()
        if let required {
            guard username == required.username && password == required.password else {
                throw FTPError.authenticationFailed
            }
        }
    }

    func listDirectory(
        host: String,
        port _: Int,
        relativePath: String,
        username: String,
        password: String
    ) throws -> [FTPDirectoryEntry] {
        try verifyAuth(username: username, password: password)
        lock.lock()
        defer { lock.unlock() }

        let normalized = Self.normalizeRel(relativePath)
        let dirKey = Self.key(host: host, relativePath: normalized)
        guard let dirNode = nodesByHostPath[dirKey] else {
            throw FTPError.directoryNotFound
        }
        guard dirNode.isDirectory else {
            throw FTPError.notADirectory
        }

        let prefix = normalized.isEmpty ? "" : "\(normalized)/"
        let hostPrefix = "\(host.lowercased())::"
        var entries: [FTPDirectoryEntry] = []

        for (fullKey, node) in nodesByHostPath {
            guard fullKey.hasPrefix(hostPrefix) else { continue }
            let rel = String(fullKey.dropFirst(hostPrefix.count))
            guard !rel.isEmpty, rel.hasPrefix(prefix) else { continue }
            let remainder = String(rel.dropFirst(prefix.count))
            guard !remainder.isEmpty, !remainder.contains("/") else { continue }
            entries.append(
                FTPDirectoryEntry(
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
        relativePath: String,
        username: String,
        password: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        try verifyAuth(username: username, password: password)
        lock.lock()
        defer { lock.unlock() }

        let normalized = Self.normalizeRel(relativePath)
        let key = Self.key(host: host, relativePath: normalized)
        guard let node = nodesByHostPath[key] else {
            throw FTPError.directoryNotFound
        }
        return (node.isDirectory, Int64(node.data.count), node.modifiedAt)
    }

    func readRange(
        host: String,
        port _: Int,
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
        let key = Self.key(host: host, relativePath: normalized)
        guard let node = nodesByHostPath[key] else {
            throw FTPError.directoryNotFound
        }
        guard !node.isDirectory else {
            throw FTPError.notADirectory
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
        let oldKey = Self.key(host: host, relativePath: oldNorm)
        let newKey = Self.key(host: host, relativePath: newNorm)

        guard let targetNode = nodesByHostPath[oldKey] else {
            throw FTPError.directoryNotFound
        }
        if oldKey != newKey && nodesByHostPath[newKey] != nil {
            throw FTPError.targetAlreadyExists
        }

        nodesByHostPath.removeValue(forKey: oldKey)
        nodesByHostPath[newKey] = targetNode

        if targetNode.isDirectory {
            let oldChildPrefix = Self.key(host: host, relativePath: oldNorm) + "/"
            let newChildPrefix = Self.key(host: host, relativePath: newNorm) + "/"
            let childKeys = nodesByHostPath.keys.filter { $0.hasPrefix(oldChildPrefix) }
            for childKey in childKeys {
                if let childNode = nodesByHostPath.removeValue(forKey: childKey) {
                    let suffix = String(childKey.dropFirst(oldChildPrefix.count))
                    nodesByHostPath[newChildPrefix + suffix] = childNode
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

    private static func key(host: String, relativePath: String) -> String {
        "\(host.lowercased())::\(relativePath)"
    }
}

private final class InMemoryNFSBackend: NFSBackendProtocol, @unchecked Sendable {
    struct Node {
        var isDirectory: Bool
        var data: Data
        var modifiedAt: Date
    }

    private let lock = NSLock()
    var exportsByHost: [String: [String]] = [:]
    var nodesByHostPath: [String: Node] = [:]

    func addExport(host: String, exportPath: String) {
        lock.lock()
        defer { lock.unlock() }
        let normalizedExport = Self.normalizeRel(exportPath)
        var list = exportsByHost[host.lowercased(), default: []]
        if !list.contains(normalizedExport) {
            list.append(normalizedExport)
        }
        exportsByHost[host.lowercased()] = list

        var current = ""
        for part in normalizedExport.split(separator: "/") {
            current = current.isEmpty ? String(part) : "\(current)/\(part)"
            let key = Self.key(host: host, relativePath: current)
            if nodesByHostPath[key] == nil {
                nodesByHostPath[key] = Node(
                    isDirectory: true,
                    data: Data(),
                    modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
                )
            }
        }
    }

    func addDirectory(
        host: String,
        exportPath: String,
        relativeSubpath: String,
        modifiedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) {
        addExport(host: host, exportPath: exportPath)
        lock.lock()
        defer { lock.unlock() }
        let fullRel = Self.normalizeRel(
            relativeSubpath.isEmpty ? exportPath : "\(exportPath)/\(relativeSubpath)"
        )
        var current = ""
        for part in fullRel.split(separator: "/") {
            current = current.isEmpty ? String(part) : "\(current)/\(part)"
            let key = Self.key(host: host, relativePath: current)
            if nodesByHostPath[key] == nil {
                nodesByHostPath[key] = Node(isDirectory: true, data: Data(), modifiedAt: modifiedAt)
            }
        }
    }

    func addFile(
        host: String,
        exportPath: String,
        relativeSubpath: String,
        data: Data,
        modifiedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) {
        let fullRel = Self.normalizeRel("\(exportPath)/\(relativeSubpath)")
        let parent = (fullRel as NSString).deletingLastPathComponent
        let exportNorm = Self.normalizeRel(exportPath)
        if parent.hasPrefix(exportNorm), parent.count > exportNorm.count {
            let sub = String(parent.dropFirst(exportNorm.count + 1))
            addDirectory(host: host, exportPath: exportPath, relativeSubpath: sub, modifiedAt: modifiedAt)
        } else {
            addExport(host: host, exportPath: exportPath)
        }
        lock.lock()
        defer { lock.unlock() }
        let key = Self.key(host: host, relativePath: fullRel)
        nodesByHostPath[key] = Node(isDirectory: false, data: data, modifiedAt: modifiedAt)
    }

    func listExports(host: String) throws -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let exports = exportsByHost[host.lowercased()] else {
            throw NFSError.networkError("Host unreachable")
        }
        return exports
    }

    func listDirectory(
        host: String,
        relativePath: String
    ) throws -> [NFSDirectoryEntry] {
        lock.lock()
        defer { lock.unlock() }

        let normalized = Self.normalizeRel(relativePath)
        let dirKey = Self.key(host: host, relativePath: normalized)
        guard let dirNode = nodesByHostPath[dirKey] else {
            throw NFSError.directoryNotFound
        }
        guard dirNode.isDirectory else {
            throw NFSError.notADirectory
        }

        let prefix = normalized.isEmpty ? "" : "\(normalized)/"
        let hostPrefix = "\(host.lowercased())::"
        var entries: [NFSDirectoryEntry] = []

        for (fullKey, node) in nodesByHostPath {
            guard fullKey.hasPrefix(hostPrefix) else { continue }
            let rel = String(fullKey.dropFirst(hostPrefix.count))
            guard !rel.isEmpty, rel.hasPrefix(prefix) else { continue }
            let remainder = String(rel.dropFirst(prefix.count))
            guard !remainder.isEmpty, !remainder.contains("/") else { continue }
            entries.append(
                NFSDirectoryEntry(
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
        relativePath: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        lock.lock()
        defer { lock.unlock() }

        let normalized = Self.normalizeRel(relativePath)
        let key = Self.key(host: host, relativePath: normalized)
        guard let node = nodesByHostPath[key] else {
            throw NFSError.directoryNotFound
        }
        return (node.isDirectory, Int64(node.data.count), node.modifiedAt)
    }

    func readRange(
        host: String,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64
    ) throws -> (data: Data, totalSize: UInt64) {
        lock.lock()
        defer { lock.unlock() }

        let normalized = Self.normalizeRel(relativePath)
        let key = Self.key(host: host, relativePath: normalized)
        guard let node = nodesByHostPath[key] else {
            throw NFSError.directoryNotFound
        }
        guard !node.isDirectory else {
            throw NFSError.notADirectory
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
        oldRelativePath: String,
        newRelativePath: String
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        let oldNorm = Self.normalizeRel(oldRelativePath)
        let newNorm = Self.normalizeRel(newRelativePath)
        let oldKey = Self.key(host: host, relativePath: oldNorm)
        let newKey = Self.key(host: host, relativePath: newNorm)

        guard let targetNode = nodesByHostPath[oldKey] else {
            throw NFSError.directoryNotFound
        }
        if oldKey != newKey && nodesByHostPath[newKey] != nil {
            throw NFSError.targetAlreadyExists
        }

        nodesByHostPath.removeValue(forKey: oldKey)
        nodesByHostPath[newKey] = targetNode

        if targetNode.isDirectory {
            let oldChildPrefix = Self.key(host: host, relativePath: oldNorm) + "/"
            let newChildPrefix = Self.key(host: host, relativePath: newNorm) + "/"
            let childKeys = nodesByHostPath.keys.filter { $0.hasPrefix(oldChildPrefix) }
            for childKey in childKeys {
                if let childNode = nodesByHostPath.removeValue(forKey: childKey) {
                    let suffix = String(childKey.dropFirst(oldChildPrefix.count))
                    nodesByHostPath[newChildPrefix + suffix] = childNode
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

    private static func key(host: String, relativePath: String) -> String {
        "\(host.lowercased())::\(relativePath)"
    }
}

@Suite(.serialized)
struct FTPNFSSupportTests {
    @Test
    func ftpAddressNormalizesPrefixPercentEncodingAndPorts() throws {
        #expect(FTPAddress.parseURL(from: "   ") == nil)
        #expect(FTPAddress.parseURL(from: "FTP://nas.local/Media") == nil)
        #expect(FTPAddress.parseURL(from: "http://192.0.2.10/Media") == nil)
        #expect(FTPAddress.parseURL(from: "192.0.2.999/Media") == nil)
        #expect(FTPAddress.parseURL(from: "[not-an-ipv6]/Media") == nil)

        let raw = "nas.local/Media/%E5%8A%A8%E6%BC%AB/NieR:Automata/"
        let parsed = try #require(FTPAddress.parseURL(from: raw, portOverride: 21))
        #expect(parsed.isFTPURL)
        #expect(parsed.isRemoteMediaURL)
        #expect(!FTPAddress.isHostRoot(parsed))
        #expect(parsed.mediaPath == "ftp://nas.local/Media/动漫/NieR:Automata")
        #expect(FTPAddress.defaultDisplayName(for: parsed) == "NieR:Automata")
        #expect(FTPAddress.relativePath(for: parsed) == "Media/动漫/NieR:Automata")

        let customPortURL = try #require(FTPAddress.parseURL(from: "ftp://192.0.2.10/Media/Shows", portOverride: 2121))
        #expect(customPortURL.mediaPath == "ftp://192.0.2.10:2121/Media/Shows")
        #expect(FTPAddress.effectivePort(for: customPortURL) == 2121)

        let hostOnly = try #require(FTPAddress.parseURL(from: "192.168.1.100", portOverride: 21))
        #expect(FTPAddress.isHostRoot(hostOnly))
        #expect(hostOnly.mediaPath == "ftp://192.168.1.100")
        #expect(FTPAddress.defaultDisplayName(for: hostOnly) == "192.168.1.100")
    }

    @Test
    func nfsAddressNormalizesSlashAndColonSyntaxWithoutMisinterpretingPathAsPort() throws {
        #expect(NFSAddress.parseURL(from: "   ") == nil)
        #expect(NFSAddress.parseURL(from: "NFS://192.168.1.100/volume1/video") == nil)
        #expect(NFSAddress.parseURL(from: "http://192.168.1.100/volume1/video") == nil)
        #expect(NFSAddress.parseURL(from: "192.0.2.999:/volume1/video") == nil)

        let slashForm = try #require(NFSAddress.parseURL(from: "192.168.1.100/volume1/video/%E5%8A%A8%E6%BC%AB/"))
        let prefixForm = try #require(NFSAddress.parseURL(from: "nfs://192.168.1.100/volume1/video/动漫"))
        let colonForm = try #require(NFSAddress.parseURL(from: "192.168.1.100:/volume1/video/动漫"))
        let prefixColonForm = try #require(NFSAddress.parseURL(from: "nfs://192.168.1.100:/volume1/video/动漫"))

        #expect(slashForm.isNFSURL)
        #expect(slashForm.isRemoteMediaURL)
        #expect(slashForm.mediaPath == "nfs://192.168.1.100/volume1/video/动漫")
        #expect(prefixForm.mediaPath == slashForm.mediaPath)
        #expect(colonForm.mediaPath == slashForm.mediaPath)
        #expect(prefixColonForm.mediaPath == slashForm.mediaPath)
        #expect(!NFSAddress.isHostRoot(slashForm))
        #expect(NFSAddress.defaultDisplayName(for: slashForm) == "动漫")
        #expect(NFSAddress.relativePath(for: slashForm) == "volume1/video/动漫")

        let ipv6ColonForm = try #require(NFSAddress.parseURL(from: "[fe80::1]:/volume1/video"))
        #expect(ipv6ColonForm.mediaPath == "nfs://[fe80::1]/volume1/video")
        #expect(NFSAddress.decodedHost(for: ipv6ColonForm) == "fe80::1")

        let hostOnly = try #require(NFSAddress.parseURL(from: "192.168.1.100:"))
        #expect(NFSAddress.isHostRoot(hostOnly))
        #expect(hostOnly.mediaPath == "nfs://192.168.1.100")
        #expect(NFSAddress.defaultDisplayName(for: hostOnly) == "192.168.1.100")
    }

    @Test
    func libraryRootGroupsGroupNestedFTPAndNFSFoldersByHostAndPath() {
        let ftpOuter = URL.fromMediaPath("ftp://nas.local:2121/Media/动漫")
        let ftpInner = URL.fromMediaPath("ftp://nas.local:2121/Media/动漫/NieR:Automata")
        let nfsOuter = URL.fromMediaPath("nfs://192.168.1.100/volume1/video/动漫")
        let nfsInner = URL.fromMediaPath("nfs://192.168.1.100/volume1/video/动漫/Frieren")

        let representatives = LibraryRootGroups.representatives(
            of: [ftpInner, ftpOuter, nfsInner, nfsOuter]
        )
        #expect(representatives.map(\.mediaPath) == [
            ftpOuter.mediaPath,
            nfsOuter.mediaPath,
        ])
        #expect(
            LibraryRootGroups.coveringRoot(of: ftpInner, in: [ftpOuter, nfsOuter])?.mediaPath
                == ftpOuter.mediaPath
        )
        #expect(
            LibraryRootGroups.coveringRoot(of: nfsInner, in: [ftpOuter, nfsOuter])?.mediaPath
                == nfsOuter.mediaPath
        )
    }

    @Test
    func subtitleIndexerIndexesFTPAndNFSFoldersStreamsViaLoopbackAndSupportsInAppRename() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "CueSeekerFTPNFSIndexTests-\(UUID().uuidString)",
            isDirectory: true
        )
        let cacheDir = tempRoot.appendingPathComponent("SubtitleCache", isDirectory: true)
        let databaseURL = tempRoot.appendingPathComponent("CueSeeker.sqlite")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let ftpRootURL = URL.fromMediaPath("ftp://nas.local:2121/Media/动漫/NieR:Automata")
        let ftpRenamedRootURL = URL.fromMediaPath("ftp://nas.local:2121/Media/动漫/NieR Automata Ver1.1a")
        let nfsRootURL = URL.fromMediaPath("nfs://192.168.1.100/volume1/video/动漫/Frieren")
        let nfsRenamedRootURL = URL.fromMediaPath("nfs://192.168.1.100/volume1/video/动漫/Sousou no Frieren")

        defer {
            FTPClient.shared.setCustomBackendForTesting(nil, forHost: "nas.local")
            NFSClient.shared.setCustomBackendForTesting(nil, forHost: "192.168.1.100")
            FTPConfigurationStore.shared.remove(url: ftpRootURL)
            FTPConfigurationStore.shared.remove(url: ftpRenamedRootURL)
            NFSConfigurationStore.shared.remove(url: nfsRootURL)
            NFSConfigurationStore.shared.remove(url: nfsRenamedRootURL)
            try? FileManager.default.removeItem(at: tempRoot)
        }

        WebDAVSubtitleCache.shared.setCacheDirectoryURLForTesting(cacheDir)

        let fakeVideoBytes = Data((0..<4096).map { UInt8($0 & 0xFF) })

        // Configure in-memory FTP backend
        let ftpBackend = InMemoryFTPBackend()
        ftpBackend.requiredCredentials = (username: "ftpuser", password: "ftppassword")
        let ftpSRT = """
        1
        00:00:01,000 --> 00:00:03,000
        FTP indexed subtitle line.
        """
        ftpBackend.addFile(
            host: "nas.local",
            relativePath: "Media/动漫/NieR:Automata/Episode 01.mkv",
            data: fakeVideoBytes
        )
        ftpBackend.addFile(
            host: "nas.local",
            relativePath: "Media/动漫/NieR:Automata/Episode 01.srt",
            data: Data(ftpSRT.utf8)
        )
        FTPClient.shared.setCustomBackendForTesting(ftpBackend, forHost: "nas.local")
        FTPConfigurationStore.shared.save(
            FTPRootConfig(
                rootPath: ftpRootURL.mediaPath,
                name: "NieR:Automata",
                address: ftpRootURL.mediaPath,
                port: 2121,
                username: "ftpuser",
                password: "ftppassword"
            )
        )

        // Configure in-memory NFS backend
        let nfsBackend = InMemoryNFSBackend()
        let nfsSRT = """
        1
        00:00:02,000 --> 00:00:05,000
        NFS indexed subtitle line.
        """
        nfsBackend.addFile(
            host: "192.168.1.100",
            exportPath: "volume1/video",
            relativeSubpath: "动漫/Frieren/Episode 01.mkv",
            data: fakeVideoBytes
        )
        nfsBackend.addFile(
            host: "192.168.1.100",
            exportPath: "volume1/video",
            relativeSubpath: "动漫/Frieren/Episode 01.srt",
            data: Data(nfsSRT.utf8)
        )
        NFSClient.shared.setCustomBackendForTesting(nfsBackend, forHost: "192.168.1.100")
        NFSConfigurationStore.shared.save(
            NFSRootConfig(
                rootPath: nfsRootURL.mediaPath,
                name: "Frieren",
                address: nfsRootURL.mediaPath
            )
        )

        try DatabaseBootstrap.prepare(at: databaseURL)
        let indexingDatabase = try IndexingDatabase(path: databaseURL)

        let ftpLibID = try indexingDatabase.addSearchPath(ftpRootURL)
        let ftpResult = try SubtitleIndexer().index(folder: ftpRootURL, into: indexingDatabase)
        try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange(libraryID: ftpLibID)
        #expect(ftpResult.indexedSubtitleFiles == 1)
        #expect(ftpResult.indexedSubtitleEntries == 1)

        let nfsLibID = try indexingDatabase.addSearchPath(nfsRootURL)
        let nfsResult = try SubtitleIndexer().index(folder: nfsRootURL, into: indexingDatabase)
        try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange(libraryID: nfsLibID)
        #expect(nfsResult.indexedSubtitleFiles == 1)
        #expect(nfsResult.indexedSubtitleEntries == 1)

        // Search verification
        let ftpSearch = try SearchDatabase(path: databaseURL).search("FTP indexed")
        #expect(ftpSearch.first?.videoPath == "ftp://nas.local:2121/Media/动漫/NieR:Automata/Episode 01.mkv")

        let nfsSearch = try SearchDatabase(path: databaseURL).search("NFS indexed")
        #expect(nfsSearch.first?.videoPath == "nfs://192.168.1.100/volume1/video/动漫/Frieren/Episode 01.mkv")

        // Verify loopback HTTP Range server for FTP & NFS video streaming
        let ftpVideoURL = URL.fromMediaPath("ftp://nas.local:2121/Media/动漫/NieR:Automata/Episode 01.mkv")
        let ftpPlayable = FTPClient.shared.resolvePlayableInput(for: ftpVideoURL)
        #expect(ftpPlayable.inputPath.hasPrefix("http://127.0.0.1:"))

        let ftpStreamURL = try #require(URL(string: ftpPlayable.inputPath))
        var ftpRangeReq = URLRequest(url: ftpStreamURL)
        ftpRangeReq.setValue("bytes=64-191", forHTTPHeaderField: "Range")
        let (ftpRangeData, ftpResponse) = try await URLSession.shared.data(for: ftpRangeReq)
        #expect((ftpResponse as? HTTPURLResponse)?.statusCode == 206)
        #expect(ftpRangeData == fakeVideoBytes.subdata(in: 64..<192))

        let nfsVideoURL = URL.fromMediaPath("nfs://192.168.1.100/volume1/video/动漫/Frieren/Episode 01.mkv")
        let nfsPlayable = NFSClient.shared.resolvePlayableInput(for: nfsVideoURL)
        #expect(nfsPlayable.inputPath.hasPrefix("http://127.0.0.1:"))

        let nfsStreamURL = try #require(URL(string: nfsPlayable.inputPath))
        var nfsRangeReq = URLRequest(url: nfsStreamURL)
        nfsRangeReq.setValue("bytes=128-255", forHTTPHeaderField: "Range")
        let (nfsRangeData, nfsResponse) = try await URLSession.shared.data(for: nfsRangeReq)
        #expect((nfsResponse as? HTTPURLResponse)?.statusCode == 206)
        #expect(nfsRangeData == fakeVideoBytes.subdata(in: 128..<256))

        // Verify in-app folder rename for both FTP and NFS
        let renamer = LibraryRenamer(database: indexingDatabase)
        let ftpPlan = try renamer.checkConflicts(
            .folder(path: ftpRootURL.mediaPath, newName: "NieR Automata Ver1.1a")
        )
        try renamer.perform(ftpPlan)
        #expect(FTPConfigurationStore.shared.config(for: ftpRenamedRootURL)?.name == "NieR Automata Ver1.1a")

        let nfsPlan = try renamer.checkConflicts(
            .folder(path: nfsRootURL.mediaPath, newName: "Sousou no Frieren")
        )
        try renamer.perform(nfsPlan)
        #expect(NFSConfigurationStore.shared.config(for: nfsRenamedRootURL)?.name == "Sousou no Frieren")
    }

    @Test
    func nativeFTPBackendDecodesUTF8AndGB18030EntryNames() {
        let utf8Sample: [UInt8] = Array("匹诺曹的谎言".utf8) + [0]
        let decodedUTF8 = utf8Sample.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count) {
                NativeFTPBackend.decodeEntryName($0)
            }
        }
        #expect(decodedUTF8 == "匹诺曹的谎言")

        let gbkCases: [(bytes: [UInt8], expected: String)] = [
            ([0xC8, 0xBA, 0xEA, 0xCD, 0xB1, 0xB8, 0xB7, 0xDD, 0x00], "群晖备份"),
            ([0xC8, 0xBA, 0xEA, 0xCD, 0x20, 0xD0, 0xC2, 0x00], "群晖 新"),
            ([0xC6, 0xA5, 0xC5, 0xB5, 0xB2, 0xDC, 0xB5, 0xC4, 0xBB, 0xD1, 0xD1, 0xD4, 0x00], "匹诺曹的谎言")
        ]
        for item in gbkCases {
            let decoded = item.bytes.withUnsafeBufferPointer { buf in
                buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count) {
                    NativeFTPBackend.decodeEntryName($0)
                }
            }
            #expect(decoded == item.expected)
        }
    }
}
