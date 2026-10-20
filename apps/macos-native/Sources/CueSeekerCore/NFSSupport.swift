import CSMBClient
import Foundation

public enum NFSError: LocalizedError, Equatable, Sendable {
    case invalidInput(String)
    case invalidAddress
    case authenticationFailed
    case directoryNotFound
    case notADirectory
    case targetAlreadyExists
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .invalidAddress:
            return "Invalid NFS folder address."
        case .authenticationFailed:
            return "NFS access denied. Check NAS NFS permissions for this device."
        case .directoryNotFound:
            return "NFS folder was not found."
        case .notADirectory:
            return "The specified NFS address is not a folder."
        case .targetAlreadyExists:
            return "An item with the same name already exists on the NFS share."
        case .networkError(let message):
            return message
        }
    }
}

public struct NFSRootConfig: RemoteRootConfigurable, Codable, Equatable, Sendable {
    public var rootPath: String
    public var name: String
    public var address: String

    public var port: Int {
        get { NFSAddress.defaultPort }
        set {}
    }

    public init(
        rootPath: String,
        name: String,
        address: String
    ) {
        let canonical = NFSAddress.parseURL(from: rootPath)?.mediaPath
            ?? URL.fromMediaPath(rootPath).mediaPath
        self.rootPath = canonical
        self.name = name
        self.address = NFSAddress.decodedDisplayAddress(address)
    }

    public init(
        name: String,
        address: String
    ) {
        let canonical = NFSAddress.parseURL(from: address)?.mediaPath
            ?? URL.fromMediaPath(address).mediaPath
        self.rootPath = canonical
        self.name = name
        self.address = NFSAddress.decodedDisplayAddress(canonical)
    }

    public var rootURL: URL {
        URL.fromMediaPath(rootPath)
    }

    public func scopedConfig(for folderURL: URL) -> NFSRootConfig {
        let canonicalFolder = (NFSAddress.parseURL(from: folderURL.mediaPath) ?? folderURL.standardizedMediaURL).mediaPath
        let resolvedURL = URL.fromMediaPath(canonicalFolder)
        return NFSRootConfig(
            rootPath: canonicalFolder,
            name: NFSAddress.defaultDisplayName(for: resolvedURL),
            address: NFSAddress.decodedDisplayAddress(canonicalFolder)
        )
    }
}

public enum NFSAddress {
    public static let defaultPort: Int = 2049

    public static func decodedDisplayAddress(_ rawAddress: String) -> String {
        RemoteAddressParser.decodedDisplayAddress(rawAddress)
    }

    public static func decodedHost(for url: URL) -> String? {
        RemoteAddressParser.decodedHost(for: url)
    }

    public static func parseURL(from rawAddress: String) -> URL? {
        RemoteAddressParser.parseURL(
            from: rawAddress,
            scheme: "nfs",
            defaultPort: defaultPort,
            portOverride: nil,
            allowCustomPort: false
        )
    }

    public static func relativePath(for url: URL) -> String {
        RemoteAddressParser.relativePath(for: url)
    }

    public static func isHostRoot(_ url: URL) -> Bool {
        guard url.isNFSURL else { return false }
        return relativePath(for: url).isEmpty
    }

    public static func defaultDisplayName(for url: URL) -> String {
        RemoteAddressParser.defaultDisplayName(for: url)
    }
}

public final class NFSConfigurationStore: @unchecked Sendable {
    public static let shared = NFSConfigurationStore()

    private let store: RemoteRootConfigStore<NFSRootConfig>

    public init(userDefaults: UserDefaults? = nil) {
        self.store = RemoteRootConfigStore(
            defaultsKey: "nfsRootConfigs",
            defaultPort: NFSAddress.defaultPort,
            isSchemePath: { $0.isNFSPath },
            userDefaults: userDefaults
        )
    }

    public func save(_ config: NFSRootConfig) { store.save(config) }
    public func upsert(_ config: NFSRootConfig) { store.upsert(config) }
    public func remove(url: URL) { store.remove(url: url) }
    public func remove(forRootPath rootPath: String) { store.remove(forRootPath: rootPath) }
    public func config(for url: URL) -> NFSRootConfig? { store.config(for: url) }
    public func config(forRootPath rootPath: String) -> NFSRootConfig? { store.config(forRootPath: rootPath) }
    public func matchingConfig(forMediaPath mediaPath: String) -> NFSRootConfig? { store.matchingConfig(forMediaPath: mediaPath) }
    public func allConfigs() -> [NFSRootConfig] { store.allConfigs() }
    public func rewriteFolderPathPrefix(from oldPath: String, to newPath: String) {
        store.rewriteFolderPathPrefix(from: oldPath, to: newPath)
    }
}

public typealias NFSDirectoryEntry = RemoteDirectoryEntry

public protocol NFSBackendProtocol: Sendable {
    func listExports(host: String) throws -> [String]

    func listDirectory(
        host: String,
        relativePath: String
    ) throws -> [NFSDirectoryEntry]

    func stat(
        host: String,
        relativePath: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date)

    func readRange(
        host: String,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64
    ) throws -> (data: Data, totalSize: UInt64)

    func rename(
        host: String,
        oldRelativePath: String,
        newRelativePath: String
    ) throws
}

public final class NativeNFSBackend: NFSBackendProtocol, @unchecked Sendable {
    public static let shared = NativeNFSBackend()

    public init() {}

    public func listExports(host: String) throws -> [String] {
        var exportList = csmb_share_list_t(names: nil, count: 0)
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            cnfs_list_exports(hostC, &exportList, &errPtr)
        }
        defer {
            csmb_free_share_list(&exportList)
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw Self.mapError(code, errPtr: errPtr)
        }
        var exports: [String] = []
        if let rawNames = exportList.names {
            for idx in 0..<exportList.count {
                if let ptr = rawNames[idx] {
                    let cleaned = Self.cleanRelativePath(String(cString: ptr)).precomposedStringWithCanonicalMapping
                    if !cleaned.isEmpty && !exports.contains(cleaned) {
                        exports.append(cleaned)
                    }
                }
            }
        }
        return exports
    }

    public func listDirectory(
        host: String,
        relativePath: String
    ) throws -> [NFSDirectoryEntry] {
        var dirList = csmb_dir_list_t(entries: nil, count: 0)
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            relativePath.withCString { relC in
                cnfs_list_directory(hostC, relC, &dirList, &errPtr)
            }
        }
        defer {
            csmb_free_dir_list(&dirList)
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw Self.mapError(code, errPtr: errPtr)
        }
        var results: [NFSDirectoryEntry] = []
        if let entries = dirList.entries {
            results.reserveCapacity(dirList.count)
            for idx in 0..<dirList.count {
                let raw = entries[idx]
                guard let namePtr = raw.name else { continue }
                let name = String(cString: namePtr).precomposedStringWithCanonicalMapping
                results.append(
                    NFSDirectoryEntry(
                        name: name,
                        isDirectory: raw.is_directory != 0,
                        fileSize: Int64(bitPattern: raw.size_bytes),
                        modifiedAt: Date(timeIntervalSince1970: TimeInterval(raw.modified_at_epoch))
                    )
                )
            }
        }
        return results
    }

    public func stat(
        host: String,
        relativePath: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        var isDir: Int32 = 0
        var sizeBytes: UInt64 = 0
        var modifiedEpoch: Int64 = 0
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            relativePath.withCString { relC in
                cnfs_stat(hostC, relC, &isDir, &sizeBytes, &modifiedEpoch, &errPtr)
            }
        }
        defer {
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw Self.mapError(code, errPtr: errPtr)
        }
        return (
            isDirectory: isDir != 0,
            fileSize: Int64(bitPattern: sizeBytes),
            modifiedAt: Date(timeIntervalSince1970: TimeInterval(modifiedEpoch))
        )
    }

    public func readRange(
        host: String,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64
    ) throws -> (data: Data, totalSize: UInt64) {
        var bufPtr: UnsafeMutablePointer<UInt8>?
        var bytesRead: Int = 0
        var totalSize: UInt64 = 0
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            relativePath.withCString { relC in
                cnfs_read_file_range(
                    hostC,
                    relC,
                    offset,
                    maxLength,
                    &bufPtr,
                    &bytesRead,
                    &totalSize,
                    &errPtr
                )
            }
        }
        defer {
            if let bufPtr { csmb_free_buffer(bufPtr) }
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw Self.mapError(code, errPtr: errPtr)
        }
        let data: Data
        if let bufPtr, bytesRead > 0 {
            data = Data(bytes: bufPtr, count: bytesRead)
        } else {
            data = Data()
        }
        return (data, totalSize)
    }

    public func rename(
        host: String,
        oldRelativePath: String,
        newRelativePath: String
    ) throws {
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            oldRelativePath.withCString { oldC in
                newRelativePath.withCString { newC in
                    cnfs_rename(hostC, oldC, newC, &errPtr)
                }
            }
        }
        defer {
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw Self.mapError(code, errPtr: errPtr)
        }
    }

    static func cleanRelativePath(_ raw: String) -> String {
        raw.split(separator: "/", omittingEmptySubsequences: true).map(String.init).joined(separator: "/")
    }

    private static func mapError(
        _ code: csmb_error_code_t,
        errPtr: UnsafeMutablePointer<CChar>?
    ) -> NFSError {
        let message = errPtr.map { String(cString: $0) } ?? "NFS connection failed."
        switch code {
        case CSMB_ERR_AUTH:
            return .authenticationFailed
        case CSMB_ERR_NOT_FOUND:
            return .directoryNotFound
        case CSMB_ERR_NOT_DIR:
            return .notADirectory
        case CSMB_ERR_EXISTS:
            return .targetAlreadyExists
        default:
            return .networkError(message)
        }
    }
}

private struct HostRoutingNFSBackend: NFSBackendProtocol {
    let byHost: [String: any NFSBackendProtocol]
    let fallback: any NFSBackendProtocol

    private func backend(for host: String) -> any NFSBackendProtocol {
        byHost[host.lowercased()] ?? fallback
    }

    func listExports(host: String) throws -> [String] {
        try backend(for: host).listExports(host: host)
    }

    func listDirectory(
        host: String,
        relativePath: String
    ) throws -> [NFSDirectoryEntry] {
        try backend(for: host).listDirectory(
            host: host,
            relativePath: relativePath
        )
    }

    func stat(
        host: String,
        relativePath: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        try backend(for: host).stat(
            host: host,
            relativePath: relativePath
        )
    }

    func readRange(
        host: String,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64
    ) throws -> (data: Data, totalSize: UInt64) {
        try backend(for: host).readRange(
            host: host,
            relativePath: relativePath,
            offset: offset,
            maxLength: maxLength
        )
    }

    func rename(
        host: String,
        oldRelativePath: String,
        newRelativePath: String
    ) throws {
        try backend(for: host).rename(
            host: host,
            oldRelativePath: oldRelativePath,
            newRelativePath: newRelativePath
        )
    }
}

public final class NFSClient: @unchecked Sendable {
    public static let shared = NFSClient()

    private let configurationStore: NFSConfigurationStore
    private let lock = NSLock()
    private var customBackend: (any NFSBackendProtocol)?
    private var customBackendsByHost: [String: any NFSBackendProtocol] = [:]
    private var cachedFileSizes: [String: UInt64] = [:]

    public init(
        configurationStore: NFSConfigurationStore = .shared,
        customBackend: (any NFSBackendProtocol)? = nil
    ) {
        self.configurationStore = configurationStore
        self.customBackend = customBackend
    }

    public func setCustomBackendForTesting(
        _ backend: (any NFSBackendProtocol)?,
        forHost host: String? = nil
    ) {
        lock.lock()
        if let host {
            let key = host.lowercased()
            if let backend {
                customBackendsByHost[key] = backend
            } else {
                customBackendsByHost.removeValue(forKey: key)
            }
        } else {
            customBackend = backend
        }
        cachedFileSizes.removeAll()
        lock.unlock()
    }

    var activeBackend: any NFSBackendProtocol {
        lock.lock()
        defer { lock.unlock() }
        let fallback = customBackend ?? NativeNFSBackend.shared
        if customBackendsByHost.isEmpty {
            return fallback
        }
        return HostRoutingNFSBackend(byHost: customBackendsByHost, fallback: fallback)
    }

    public func connectAndBrowseDirectory(
        address: String
    ) async throws -> (config: NFSRootConfig, items: [WebDAVBrowserItem]) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            throw NFSError.invalidInput("Address is required.")
        }
        guard let rootURL = NFSAddress.parseURL(from: trimmedAddress) else {
            throw NFSError.invalidAddress
        }

        try Task.checkCancellation()

        let effectiveName = NFSAddress.defaultDisplayName(for: rootURL)
        let rootMediaPath = rootURL.mediaPath
        let initialConfig = NFSRootConfig(
            rootPath: rootMediaPath,
            name: effectiveName,
            address: rootMediaPath
        )

        return try await Task.detached(priority: .userInitiated) { [self] in
            try Task.checkCancellation()
            let items = try self.listBrowserItems(at: rootURL, config: initialConfig)
            return (initialConfig, items)
        }.value
    }

    public func browseDirectory(
        at folderURL: URL,
        baseConfig: NFSRootConfig
    ) async throws -> [WebDAVBrowserItem] {
        let normalizedURL = NFSAddress.parseURL(from: folderURL.mediaPath)
            ?? folderURL.standardizedMediaURL
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) { [self] in
            try Task.checkCancellation()
            return try self.listBrowserItems(at: normalizedURL, config: baseConfig)
        }.value
    }

    public func scanDirectoryTree(rootURL: URL) throws -> [WebDAVRemoteFile] {
        let endpoint = resolveEndpoint(for: rootURL.mediaPath)
        guard !endpoint.host.isEmpty, !endpoint.relativePath.isEmpty else {
            throw NFSError.invalidAddress
        }

        var results: [WebDAVRemoteFile] = []
        var visitedDirectories: Set<String> = []
        let backend = activeBackend

        try RemoteDirectoryListingHelper.scanDirectoryRecursive(
            directoryURL: endpoint.url,
            relativePath: endpoint.relativePath,
            appendChild: { dirURL, name in
                Self.appendingChildComponent(name, to: dirURL)
            },
            listEntries: { relPath in
                try backend.listDirectory(
                    host: endpoint.host,
                    relativePath: relPath
                )
            },
            cacheFileSize: { [weak self] size, path in
                self?.cacheFileSize(size, forMediaPath: path)
            },
            visitedDirectories: &visitedDirectories,
            results: &results
        )

        return results.sorted { $0.url.mediaPath < $1.url.mediaPath }
    }

    public func downloadData(from url: URL) throws -> Data {
        guard url.isNFSURL else {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        }
        let (data, _) = try readRange(from: url, offset: 0, maxLength: UInt64(Int.max))
        return data
    }

    public func readRange(
        from url: URL,
        offset: UInt64,
        maxLength: UInt64
    ) throws -> (data: Data, totalSize: UInt64) {
        let endpoint = resolveEndpoint(for: url.mediaPath)
        guard !endpoint.host.isEmpty, !endpoint.relativePath.isEmpty else {
            throw NFSError.directoryNotFound
        }
        let result = try activeBackend.readRange(
            host: endpoint.host,
            relativePath: endpoint.relativePath,
            offset: offset,
            maxLength: maxLength
        )
        cacheFileSize(result.totalSize, forMediaPath: endpoint.url.mediaPath)
        return result
    }

    public func statFileSize(for url: URL) throws -> UInt64 {
        let canonical = url.mediaPath
        lock.lock()
        if let cached = cachedFileSizes[canonical] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let endpoint = resolveEndpoint(for: canonical)
        guard !endpoint.host.isEmpty, !endpoint.relativePath.isEmpty else {
            throw NFSError.directoryNotFound
        }
        let st = try activeBackend.stat(
            host: endpoint.host,
            relativePath: endpoint.relativePath
        )
        guard !st.isDirectory else {
            throw NFSError.notADirectory
        }
        let size = UInt64(max(0, st.fileSize))
        cacheFileSize(size, forMediaPath: canonical)
        return size
    }

    public func directoryExists(
        at directoryPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) throws -> Bool {
        let endpoint = resolveEndpoint(for: directoryPath, peerPathInSameDirectory: peerPath)
        guard !endpoint.host.isEmpty, !endpoint.relativePath.isEmpty else {
            return false
        }
        do {
            let st = try activeBackend.stat(
                host: endpoint.host,
                relativePath: endpoint.relativePath
            )
            return st.isDirectory
        } catch NFSError.directoryNotFound, NFSError.notADirectory {
            return false
        }
    }

    public func fileExists(
        at filePath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) throws -> Bool {
        let endpoint = resolveEndpoint(for: filePath, peerPathInSameDirectory: peerPath)
        guard !endpoint.host.isEmpty, !endpoint.relativePath.isEmpty else {
            return false
        }
        do {
            let st = try activeBackend.stat(
                host: endpoint.host,
                relativePath: endpoint.relativePath
            )
            return !st.isDirectory
        } catch NFSError.directoryNotFound, NFSError.notADirectory {
            return false
        }
    }

    public func resourceExists(
        at targetPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) throws -> Bool {
        let endpoint = resolveEndpoint(for: targetPath, peerPathInSameDirectory: peerPath)
        guard !endpoint.host.isEmpty, !endpoint.relativePath.isEmpty else {
            return false
        }
        do {
            _ = try activeBackend.stat(
                host: endpoint.host,
                relativePath: endpoint.relativePath
            )
            return true
        } catch NFSError.directoryNotFound {
            return false
        }
    }

    public func listDirectoryItemsInParent(of childPath: String) throws -> [String: Bool]? {
        let parentPath = LibraryRenamer.parentPath(of: childPath)
        guard parentPath != childPath else {
            return nil
        }
        let endpoint = resolveEndpoint(for: parentPath, peerPathInSameDirectory: childPath)
        guard !endpoint.host.isEmpty, !endpoint.relativePath.isEmpty else {
            return nil
        }
        let entries = try activeBackend.listDirectory(
            host: endpoint.host,
            relativePath: endpoint.relativePath
        )
        var items: [String: Bool] = [:]
        for entry in entries {
            let name = entry.name.precomposedStringWithCanonicalMapping
            guard !name.isEmpty else { continue }
            items[name] = entry.isDirectory
        }
        return items
    }

    public func moveItem(
        fromPath: String,
        toPath: String,
        isDirectory _: Bool
    ) throws {
        let source = resolveEndpoint(for: fromPath, peerPathInSameDirectory: toPath)
        let destination = resolveEndpoint(for: toPath, peerPathInSameDirectory: fromPath)
        guard !source.host.isEmpty,
              !source.relativePath.isEmpty,
              !destination.relativePath.isEmpty else {
            throw NFSError.invalidAddress
        }
        try activeBackend.rename(
            host: source.host,
            oldRelativePath: source.relativePath,
            newRelativePath: destination.relativePath
        )
        lock.lock()
        if let size = cachedFileSizes.removeValue(forKey: source.url.mediaPath) {
            cachedFileSizes[destination.url.mediaPath] = size
        }
        lock.unlock()
    }

    public func resolvePlayableInput(for url: URL) -> WebDAVPlayableInput {
        guard url.isNFSURL else {
            return WebDAVPlayableInput(url: url.path, httpHeaders: nil)
        }
        if let streamURL = RemoteMediaStreamServer.shared.registerAndResolveHTTPURL(
            for: url,
            routePrefix: "nfs",
            registration: .init(
                statFileSize: { [self] in
                    try self.statFileSize(for: url)
                },
                streamRange: { [self] fd, rangeHeader in
                    RemoteMediaStreamServer.streamFromRangeReader(
                        fd: fd,
                        rangeHeader: rangeHeader,
                        statFileSize: { try self.statFileSize(for: url) },
                        readRange: { offset, maxLength in
                            try self.readRange(from: url, offset: offset, maxLength: maxLength).data
                        }
                    )
                }
            )
        ) {
            return WebDAVPlayableInput(url: streamURL, httpHeaders: nil)
        }
        return WebDAVPlayableInput(url: url.mediaPath, httpHeaders: nil)
    }

    // MARK: - Internal Helpers

    struct ResolvedEndpoint {
        let url: URL
        let host: String
        let relativePath: String
        let config: NFSRootConfig
    }

    func resolveEndpoint(
        for targetPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) -> ResolvedEndpoint {
        let matchedConfig = configurationStore.matchingConfig(forMediaPath: targetPath)
            ?? peerPath.flatMap { configurationStore.matchingConfig(forMediaPath: $0) }
        let targetURL = NFSAddress.parseURL(from: targetPath)
            ?? URL.fromMediaPath(targetPath)
        let host = NFSAddress.decodedHost(for: targetURL) ?? ""
        let relativePath = NFSAddress.relativePath(for: targetURL)
        let config = matchedConfig ?? NFSRootConfig(
            rootPath: targetURL.mediaPath,
            name: NFSAddress.defaultDisplayName(for: targetURL),
            address: targetURL.mediaPath
        )
        return ResolvedEndpoint(
            url: targetURL,
            host: host,
            relativePath: relativePath,
            config: config
        )
    }

    private func cacheFileSize(_ size: UInt64, forMediaPath mediaPath: String) {
        lock.lock()
        cachedFileSizes[mediaPath] = size
        lock.unlock()
    }

    private func listBrowserItems(
        at directoryURL: URL,
        config _: NFSRootConfig
    ) throws -> [WebDAVBrowserItem] {
        guard let host = NFSAddress.decodedHost(for: directoryURL), !host.isEmpty else {
            throw NFSError.invalidAddress
        }
        let relativePath = NFSAddress.relativePath(for: directoryURL)
        let backend = activeBackend

        if relativePath.isEmpty {
            let exports = try backend.listExports(host: host)
            var foldersByPath: [String: WebDAVBrowserItem] = [:]
            for rawExport in exports {
                try Task.checkCancellation()
                let cleaned = NativeNFSBackend.cleanRelativePath(rawExport).precomposedStringWithCanonicalMapping
                if cleaned.isEmpty || cleaned.hasPrefix(".") {
                    continue
                }
                let exportURL = Self.appendingChildComponent(cleaned, to: directoryURL)
                let item = WebDAVBrowserItem(url: exportURL, name: cleaned, kind: .folder)
                foldersByPath[item.id] = item
            }
            return RemoteDirectoryListingHelper.sortBrowserItems(folders: Array(foldersByPath.values), files: [])
        }

        let entries = try backend.listDirectory(
            host: host,
            relativePath: relativePath
        )

        return try RemoteDirectoryListingHelper.buildBrowserItems(
            entries: entries,
            directoryURL: directoryURL,
            appendChild: { dirURL, name in
                Self.appendingChildComponent(name, to: dirURL)
            },
            cacheFileSize: { [weak self] size, path in
                self?.cacheFileSize(size, forMediaPath: path)
            }
        )
    }

    private static func appendingChildComponent(
        _ name: String,
        to directoryURL: URL
    ) -> URL {
        let baseMediaPath = directoryURL.mediaPath
        let combined = baseMediaPath.hasSuffix("/") ? "\(baseMediaPath)\(name)" : "\(baseMediaPath)/\(name)"
        return NFSAddress.parseURL(from: combined) ?? directoryURL.appendingPathComponent(name)
    }
}
