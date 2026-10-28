import CSMBClient
import Foundation

public enum FTPError: LocalizedError, Equatable, Sendable {
    case invalidInput(String)
    case invalidAddress
    case invalidPort
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
            return "Invalid FTP folder address."
        case .invalidPort:
            return "Invalid FTP port."
        case .authenticationFailed:
            return "FTP authentication failed. Check username and password."
        case .directoryNotFound:
            return "FTP folder was not found."
        case .notADirectory:
            return "The specified FTP address is not a folder."
        case .targetAlreadyExists:
            return "An item with the same name already exists on the FTP server."
        case .networkError(let message):
            return message
        }
    }
}

public struct FTPRootConfig: RemoteRootConfigurable, Codable, Equatable, Sendable {
    public var rootPath: String
    public var name: String
    public var address: String
    public var port: Int
    public var username: String
    public var password: String

    public init(
        rootPath: String,
        name: String,
        address: String,
        port: Int = FTPAddress.defaultPort,
        username: String,
        password: String
    ) {
        let normalizedPort = (1...65535).contains(port) ? port : FTPAddress.defaultPort
        let canonical = FTPAddress.parseURL(from: rootPath, portOverride: normalizedPort)?.mediaPath
            ?? URL.fromMediaPath(rootPath).mediaPath
        self.rootPath = canonical
        self.name = name
        self.address = FTPAddress.decodedDisplayAddress(address)
        self.port = normalizedPort
        self.username = username
        self.password = password
    }

    public init(
        name: String,
        address: String,
        port: Int = FTPAddress.defaultPort,
        username: String,
        password: String
    ) {
        let normalizedPort = (1...65535).contains(port) ? port : FTPAddress.defaultPort
        let canonical = FTPAddress.parseURL(from: address, portOverride: normalizedPort)?.mediaPath
            ?? URL.fromMediaPath(address).mediaPath
        self.rootPath = canonical
        self.name = name
        self.address = FTPAddress.decodedDisplayAddress(canonical)
        self.port = normalizedPort
        self.username = username
        self.password = password
    }

    public var rootURL: URL {
        URL.fromMediaPath(rootPath)
    }

    public func scopedConfig(for folderURL: URL) -> FTPRootConfig {
        let canonicalFolder = (FTPAddress.parseURL(from: folderURL.mediaPath, portOverride: port) ?? folderURL.standardizedMediaURL).mediaPath
        let resolvedURL = URL.fromMediaPath(canonicalFolder)
        return FTPRootConfig(
            rootPath: canonicalFolder,
            name: FTPAddress.defaultDisplayName(for: resolvedURL),
            address: FTPAddress.decodedDisplayAddress(canonicalFolder),
            port: port,
            username: username,
            password: password
        )
    }
}

public enum FTPAddress {
    public static let defaultPort: Int = 21
    public static let defaultPortString: String = "21"

    public static func decodedDisplayAddress(_ rawAddress: String) -> String {
        RemoteAddressParser.decodedDisplayAddress(rawAddress)
    }

    public static func decodedHost(for url: URL) -> String? {
        RemoteAddressParser.decodedHost(for: url)
    }

    public static func parsePort(_ rawPort: String) -> Int? {
        RemoteAddressParser.parsePort(rawPort)
    }

    public static func parseURL(from rawAddress: String, portOverride: Int? = nil) -> URL? {
        RemoteAddressParser.parseURL(
            from: rawAddress,
            scheme: "ftp",
            defaultPort: defaultPort,
            portOverride: portOverride
        )
    }

    public static func effectivePort(for url: URL, fallbackConfig: FTPRootConfig? = nil) -> Int {
        RemoteAddressParser.effectivePort(
            for: url,
            defaultPort: defaultPort,
            fallbackPort: fallbackConfig?.port
        )
    }

    public static func relativePath(for url: URL) -> String {
        RemoteAddressParser.relativePath(for: url)
    }

    public static func isHostRoot(_ url: URL) -> Bool {
        guard url.isFTPURL else { return false }
        return relativePath(for: url).isEmpty
    }

    public static func defaultDisplayName(for url: URL) -> String {
        RemoteAddressParser.defaultDisplayName(for: url)
    }
}

public final class FTPConfigurationStore: @unchecked Sendable {
    public static let shared = FTPConfigurationStore()

    private let store: RemoteRootConfigStore<FTPRootConfig>

    public init(userDefaults: UserDefaults? = nil) {
        self.store = RemoteRootConfigStore(
            defaultsKey: "ftpRootConfigs",
            defaultPort: FTPAddress.defaultPort,
            isSchemePath: { $0.isFTPPath },
            userDefaults: userDefaults
        )
    }

    public func save(_ config: FTPRootConfig) { store.save(config) }
    public func upsert(_ config: FTPRootConfig) { store.upsert(config) }
    public func remove(url: URL) { store.remove(url: url) }
    public func remove(forRootPath rootPath: String) { store.remove(forRootPath: rootPath) }
    public func config(for url: URL) -> FTPRootConfig? { store.config(for: url) }
    public func config(forRootPath rootPath: String) -> FTPRootConfig? { store.config(forRootPath: rootPath) }
    public func matchingConfig(forMediaPath mediaPath: String) -> FTPRootConfig? { store.matchingConfig(forMediaPath: mediaPath) }
    public func allConfigs() -> [FTPRootConfig] { store.allConfigs() }
    public func rewriteFolderPathPrefix(from oldPath: String, to newPath: String) {
        store.rewriteFolderPathPrefix(from: oldPath, to: newPath)
    }
}

public typealias FTPDirectoryEntry = RemoteDirectoryEntry

public protocol FTPBackendProtocol: Sendable {
    func listDirectory(
        host: String,
        port: Int,
        relativePath: String,
        username: String,
        password: String
    ) throws -> [FTPDirectoryEntry]

    func stat(
        host: String,
        port: Int,
        relativePath: String,
        username: String,
        password: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date)

    func readRange(
        host: String,
        port: Int,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String
    ) throws -> (data: Data, totalSize: UInt64)

    func streamRange(
        host: String,
        port: Int,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String,
        writeChunk: (UnsafeRawPointer, Int) -> Bool
    ) throws

    func rename(
        host: String,
        port: Int,
        oldRelativePath: String,
        newRelativePath: String,
        username: String,
        password: String
    ) throws
}

public final class NativeFTPBackend: FTPBackendProtocol, @unchecked Sendable {
    public static let shared = NativeFTPBackend()

    public init() {}

    public func listDirectory(
        host: String,
        port: Int,
        relativePath: String,
        username: String,
        password: String
    ) throws -> [FTPDirectoryEntry] {
        var dirList = csmb_dir_list_t(entries: nil, count: 0)
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            relativePath.withCString { relC in
                username.withCString { userC in
                    password.withCString { passC in
                        cftp_list_directory(hostC, Int32(port), relC, userC, passC, &dirList, &errPtr)
                    }
                }
            }
        }
        defer {
            csmb_free_dir_list(&dirList)
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw Self.mapError(code, errPtr: errPtr)
        }
        var results: [FTPDirectoryEntry] = []
        if let entries = dirList.entries {
            results.reserveCapacity(dirList.count)
            for idx in 0..<dirList.count {
                let raw = entries[idx]
                guard let namePtr = raw.name else { continue }
                let name = Self.decodeEntryName(namePtr)
                results.append(
                    FTPDirectoryEntry(
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
        port: Int,
        relativePath: String,
        username: String,
        password: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        var isDir: Int32 = 0
        var sizeBytes: UInt64 = 0
        var modifiedEpoch: Int64 = 0
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            relativePath.withCString { relC in
                username.withCString { userC in
                    password.withCString { passC in
                        cftp_stat(hostC, Int32(port), relC, userC, passC, &isDir, &sizeBytes, &modifiedEpoch, &errPtr)
                    }
                }
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
        port: Int,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String
    ) throws -> (data: Data, totalSize: UInt64) {
        var bufPtr: UnsafeMutablePointer<UInt8>?
        var bytesRead: Int = 0
        var totalSize: UInt64 = 0
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            relativePath.withCString { relC in
                username.withCString { userC in
                    password.withCString { passC in
                        cftp_read_file_range(
                            hostC,
                            Int32(port),
                            relC,
                            offset,
                            maxLength,
                            userC,
                            passC,
                            &bufPtr,
                            &bytesRead,
                            &totalSize,
                            &errPtr
                        )
                    }
                }
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

    private final class StreamBox {
        let writeChunk: (UnsafeRawPointer, Int) -> Bool
        init(_ writeChunk: @escaping (UnsafeRawPointer, Int) -> Bool) {
            self.writeChunk = writeChunk
        }
    }

    public func streamRange(
        host: String,
        port: Int,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String,
        writeChunk: (UnsafeRawPointer, Int) -> Bool
    ) throws {
        guard maxLength > 0 else { return }
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = withoutActuallyEscaping(writeChunk) { escapingWrite in
            let box = StreamBox(escapingWrite)
            let userData = Unmanaged.passUnretained(box).toOpaque()
            let cb: csmb_stream_write_fn = { dataPtr, length, rawUser in
                guard let dataPtr, let rawUser else { return 0 }
                let streamBox = Unmanaged<StreamBox>.fromOpaque(rawUser).takeUnretainedValue()
                return streamBox.writeChunk(UnsafeRawPointer(dataPtr), length) ? 1 : 0
            }
            return host.withCString { hostC in
                relativePath.withCString { relC in
                    username.withCString { userC in
                        password.withCString { passC in
                            cftp_stream_file_range(
                                hostC,
                                Int32(port),
                                relC,
                                offset,
                                maxLength,
                                userC,
                                passC,
                                cb,
                                userData,
                                &errPtr
                            )
                        }
                    }
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

    public func rename(
        host: String,
        port: Int,
        oldRelativePath: String,
        newRelativePath: String,
        username: String,
        password: String
    ) throws {
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            oldRelativePath.withCString { oldC in
                newRelativePath.withCString { newC in
                    username.withCString { userC in
                        password.withCString { passC in
                            cftp_rename(hostC, Int32(port), oldC, newC, userC, passC, &errPtr)
                        }
                    }
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

    static func decodeEntryName(_ ptr: UnsafePointer<CChar>) -> String {
        if let utf8 = String(validatingUTF8: ptr) {
            return utf8.precomposedStringWithCanonicalMapping
        }
        let byteCount = strlen(ptr)
        let data = Data(bytes: ptr, count: byteCount)
        let gb18030Encoding = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        if let gbDecoded = String(data: data, encoding: gb18030Encoding) {
            return gbDecoded.precomposedStringWithCanonicalMapping
        }
        return String(cString: ptr).precomposedStringWithCanonicalMapping
    }

    private static func mapError(
        _ code: csmb_error_code_t,
        errPtr: UnsafeMutablePointer<CChar>?
    ) -> FTPError {
        let message = errPtr.map { String(cString: $0) } ?? "FTP connection failed."
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

private struct HostRoutingFTPBackend: FTPBackendProtocol {
    let byHost: [String: any FTPBackendProtocol]
    let fallback: any FTPBackendProtocol

    private func backend(for host: String) -> any FTPBackendProtocol {
        byHost[host.lowercased()] ?? fallback
    }

    func listDirectory(
        host: String,
        port: Int,
        relativePath: String,
        username: String,
        password: String
    ) throws -> [FTPDirectoryEntry] {
        try backend(for: host).listDirectory(
            host: host,
            port: port,
            relativePath: relativePath,
            username: username,
            password: password
        )
    }

    func stat(
        host: String,
        port: Int,
        relativePath: String,
        username: String,
        password: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        try backend(for: host).stat(
            host: host,
            port: port,
            relativePath: relativePath,
            username: username,
            password: password
        )
    }

    func readRange(
        host: String,
        port: Int,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String
    ) throws -> (data: Data, totalSize: UInt64) {
        try backend(for: host).readRange(
            host: host,
            port: port,
            relativePath: relativePath,
            offset: offset,
            maxLength: maxLength,
            username: username,
            password: password
        )
    }

    func streamRange(
        host: String,
        port: Int,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String,
        writeChunk: (UnsafeRawPointer, Int) -> Bool
    ) throws {
        try backend(for: host).streamRange(
            host: host,
            port: port,
            relativePath: relativePath,
            offset: offset,
            maxLength: maxLength,
            username: username,
            password: password,
            writeChunk: writeChunk
        )
    }

    func rename(
        host: String,
        port: Int,
        oldRelativePath: String,
        newRelativePath: String,
        username: String,
        password: String
    ) throws {
        try backend(for: host).rename(
            host: host,
            port: port,
            oldRelativePath: oldRelativePath,
            newRelativePath: newRelativePath,
            username: username,
            password: password
        )
    }
}

public final class FTPClient: @unchecked Sendable {
    public static let shared = FTPClient()

    private let configurationStore: FTPConfigurationStore
    private let lock = NSLock()
    private var customBackend: (any FTPBackendProtocol)?
    private var customBackendsByHost: [String: any FTPBackendProtocol] = [:]
    private var cachedFileSizes: [String: UInt64] = [:]

    public init(
        configurationStore: FTPConfigurationStore = .shared,
        customBackend: (any FTPBackendProtocol)? = nil
    ) {
        self.configurationStore = configurationStore
        self.customBackend = customBackend
    }

    public func setCustomBackendForTesting(
        _ backend: (any FTPBackendProtocol)?,
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

    var activeBackend: any FTPBackendProtocol {
        lock.lock()
        defer { lock.unlock() }
        let fallback = customBackend ?? NativeFTPBackend.shared
        if customBackendsByHost.isEmpty {
            return fallback
        }
        return HostRoutingFTPBackend(byHost: customBackendsByHost, fallback: fallback)
    }

    public func connectAndBrowseDirectory(
        address: String,
        port: String,
        username: String,
        password: String
    ) async throws -> (config: FTPRootConfig, items: [WebDAVBrowserItem]) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            throw FTPError.invalidInput("Address is required.")
        }
        guard !trimmedPort.isEmpty else {
            throw FTPError.invalidInput("Port is required.")
        }
        guard let parsedPort = FTPAddress.parsePort(trimmedPort) else {
            throw FTPError.invalidPort
        }
        guard let rootURL = FTPAddress.parseURL(from: trimmedAddress, portOverride: parsedPort) else {
            throw FTPError.invalidAddress
        }

        try Task.checkCancellation()

        let effectiveName = FTPAddress.defaultDisplayName(for: rootURL)
        let rootMediaPath = rootURL.mediaPath
        let initialConfig = FTPRootConfig(
            rootPath: rootMediaPath,
            name: effectiveName,
            address: rootMediaPath,
            port: parsedPort,
            username: trimmedUsername,
            password: password
        )

        return try await Task.detached(priority: .userInitiated) { [self] in
            try Task.checkCancellation()
            let items = try self.listBrowserItems(at: rootURL, config: initialConfig)
            return (initialConfig, items)
        }.value
    }

    public func browseDirectory(
        at folderURL: URL,
        baseConfig: FTPRootConfig
    ) async throws -> [WebDAVBrowserItem] {
        let normalizedURL = FTPAddress.parseURL(from: folderURL.mediaPath, portOverride: baseConfig.port)
            ?? folderURL.standardizedMediaURL
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) { [self] in
            try Task.checkCancellation()
            return try self.listBrowserItems(at: normalizedURL, config: baseConfig)
        }.value
    }

    public func scanDirectoryTree(rootURL: URL) throws -> [WebDAVRemoteFile] {
        let endpoint = resolveEndpoint(for: rootURL.mediaPath)
        guard !endpoint.host.isEmpty else {
            throw FTPError.invalidAddress
        }

        var results: [WebDAVRemoteFile] = []
        var visitedDirectories: Set<String> = []
        let backend = activeBackend
        let port = endpoint.port

        try RemoteDirectoryListingHelper.scanDirectoryRecursive(
            directoryURL: endpoint.url,
            relativePath: endpoint.relativePath,
            appendChild: { dirURL, name in
                Self.appendingChildComponent(name, to: dirURL, port: port)
            },
            listEntries: { relPath in
                try backend.listDirectory(
                    host: endpoint.host,
                    port: endpoint.port,
                    relativePath: relPath,
                    username: endpoint.config.username,
                    password: endpoint.config.password
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
        guard url.isFTPURL else {
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
            throw FTPError.directoryNotFound
        }
        let result = try activeBackend.readRange(
            host: endpoint.host,
            port: endpoint.port,
            relativePath: endpoint.relativePath,
            offset: offset,
            maxLength: maxLength,
            username: endpoint.config.username,
            password: endpoint.config.password
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
            throw FTPError.directoryNotFound
        }
        let st = try activeBackend.stat(
            host: endpoint.host,
            port: endpoint.port,
            relativePath: endpoint.relativePath,
            username: endpoint.config.username,
            password: endpoint.config.password
        )
        guard !st.isDirectory else {
            throw FTPError.notADirectory
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
        guard !endpoint.host.isEmpty else {
            return false
        }
        do {
            let st = try activeBackend.stat(
                host: endpoint.host,
                port: endpoint.port,
                relativePath: endpoint.relativePath,
                username: endpoint.config.username,
                password: endpoint.config.password
            )
            return st.isDirectory
        } catch FTPError.directoryNotFound, FTPError.notADirectory {
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
                port: endpoint.port,
                relativePath: endpoint.relativePath,
                username: endpoint.config.username,
                password: endpoint.config.password
            )
            return !st.isDirectory
        } catch FTPError.directoryNotFound, FTPError.notADirectory {
            return false
        }
    }

    public func resourceExists(
        at targetPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) throws -> Bool {
        let endpoint = resolveEndpoint(for: targetPath, peerPathInSameDirectory: peerPath)
        guard !endpoint.host.isEmpty else {
            return false
        }
        do {
            _ = try activeBackend.stat(
                host: endpoint.host,
                port: endpoint.port,
                relativePath: endpoint.relativePath,
                username: endpoint.config.username,
                password: endpoint.config.password
            )
            return true
        } catch FTPError.directoryNotFound {
            return false
        }
    }

    public func listDirectoryItemsInParent(of childPath: String) throws -> [String: Bool]? {
        let parentPath = LibraryRenamer.parentPath(of: childPath)
        guard parentPath != childPath else {
            return nil
        }
        let endpoint = resolveEndpoint(for: parentPath, peerPathInSameDirectory: childPath)
        guard !endpoint.host.isEmpty else {
            return nil
        }
        let entries = try activeBackend.listDirectory(
            host: endpoint.host,
            port: endpoint.port,
            relativePath: endpoint.relativePath,
            username: endpoint.config.username,
            password: endpoint.config.password
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
            throw FTPError.invalidAddress
        }
        try activeBackend.rename(
            host: source.host,
            port: source.port,
            oldRelativePath: source.relativePath,
            newRelativePath: destination.relativePath,
            username: source.config.username,
            password: source.config.password
        )
        lock.lock()
        if let size = cachedFileSizes.removeValue(forKey: source.url.mediaPath) {
            cachedFileSizes[destination.url.mediaPath] = size
        }
        lock.unlock()
    }

    public func streamRange(
        from url: URL,
        offset: UInt64,
        maxLength: UInt64,
        writeChunk: (UnsafeRawPointer, Int) -> Bool
    ) throws {
        let endpoint = resolveEndpoint(for: url.mediaPath)
        guard !endpoint.host.isEmpty, !endpoint.relativePath.isEmpty else {
            throw FTPError.directoryNotFound
        }
        try activeBackend.streamRange(
            host: endpoint.host,
            port: endpoint.port,
            relativePath: endpoint.relativePath,
            offset: offset,
            maxLength: maxLength,
            username: endpoint.config.username,
            password: endpoint.config.password,
            writeChunk: writeChunk
        )
    }

    public func resolvePlayableInput(for url: URL) -> WebDAVPlayableInput {
        guard url.isFTPURL else {
            return WebDAVPlayableInput(url: url.path, httpHeaders: nil)
        }
        if let streamURL = RemoteMediaStreamServer.shared.registerAndResolveHTTPURL(
            for: url,
            routePrefix: "ftp",
            registration: .init(
                statFileSize: { [self] in
                    try self.statFileSize(for: url)
                },
                streamRange: { [self] fd, rangeHeader in
                    RemoteMediaStreamServer.streamContinuousRange(
                        fd: fd,
                        rangeHeader: rangeHeader,
                        statFileSize: { try self.statFileSize(for: url) },
                        streamBody: { offset, maxLength, writeChunk in
                            try self.streamRange(
                                from: url,
                                offset: offset,
                                maxLength: maxLength,
                                writeChunk: writeChunk
                            )
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
        let port: Int
        let relativePath: String
        let config: FTPRootConfig
    }

    func resolveEndpoint(
        for targetPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) -> ResolvedEndpoint {
        let matchedConfig = configurationStore.matchingConfig(forMediaPath: targetPath)
            ?? peerPath.flatMap { configurationStore.matchingConfig(forMediaPath: $0) }
        let targetURL = FTPAddress.parseURL(from: targetPath, portOverride: matchedConfig?.port)
            ?? URL.fromMediaPath(targetPath)
        let host = FTPAddress.decodedHost(for: targetURL) ?? ""
        let port = FTPAddress.effectivePort(for: targetURL, fallbackConfig: matchedConfig)
        let relativePath = FTPAddress.relativePath(for: targetURL)
        let config = matchedConfig ?? FTPRootConfig(
            rootPath: targetURL.mediaPath,
            name: FTPAddress.defaultDisplayName(for: targetURL),
            address: targetURL.mediaPath,
            port: port,
            username: "",
            password: ""
        )
        return ResolvedEndpoint(
            url: targetURL,
            host: host,
            port: port,
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
        config: FTPRootConfig
    ) throws -> [WebDAVBrowserItem] {
        guard let host = FTPAddress.decodedHost(for: directoryURL), !host.isEmpty else {
            throw FTPError.invalidAddress
        }
        let port = FTPAddress.effectivePort(for: directoryURL, fallbackConfig: config)
        let relativePath = FTPAddress.relativePath(for: directoryURL)
        let entries = try activeBackend.listDirectory(
            host: host,
            port: port,
            relativePath: relativePath,
            username: config.username,
            password: config.password
        )

        return try RemoteDirectoryListingHelper.buildBrowserItems(
            entries: entries,
            directoryURL: directoryURL,
            appendChild: { dirURL, name in
                Self.appendingChildComponent(name, to: dirURL, port: port)
            },
            cacheFileSize: { [weak self] size, path in
                self?.cacheFileSize(size, forMediaPath: path)
            }
        )
    }

    private static func appendingChildComponent(
        _ name: String,
        to directoryURL: URL,
        port: Int
    ) -> URL {
        let baseMediaPath = directoryURL.mediaPath
        let combined = baseMediaPath.hasSuffix("/") ? "\(baseMediaPath)\(name)" : "\(baseMediaPath)/\(name)"
        return FTPAddress.parseURL(from: combined, portOverride: port) ?? directoryURL.appendingPathComponent(name)
    }
}
