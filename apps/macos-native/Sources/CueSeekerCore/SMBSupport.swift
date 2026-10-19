import CSMBClient
import CryptoKit
import Darwin
import Foundation

public enum SMBError: LocalizedError, Equatable, Sendable {
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
            return "Invalid SMB folder address."
        case .invalidPort:
            return "Invalid SMB port."
        case .authenticationFailed:
            return "SMB authentication failed. Check username and password."
        case .directoryNotFound:
            return "SMB folder was not found."
        case .notADirectory:
            return "The specified SMB address is not a folder."
        case .targetAlreadyExists:
            return "An item with the same name already exists on the SMB share."
        case .networkError(let message):
            return message
        }
    }
}

public struct SMBRootConfig: Codable, Equatable, Sendable {
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
        port: Int = SMBAddress.defaultPort,
        username: String,
        password: String
    ) {
        let normalizedPort = (1...65535).contains(port) ? port : SMBAddress.defaultPort
        let canonical = SMBAddress.parseURL(from: rootPath, portOverride: normalizedPort)?.mediaPath
            ?? URL.fromMediaPath(rootPath).mediaPath
        self.rootPath = canonical
        self.name = name
        self.address = SMBAddress.decodedDisplayAddress(address)
        self.port = normalizedPort
        self.username = username
        self.password = password
    }

    public init(
        name: String,
        address: String,
        port: Int = SMBAddress.defaultPort,
        username: String,
        password: String
    ) {
        let normalizedPort = (1...65535).contains(port) ? port : SMBAddress.defaultPort
        let canonical = SMBAddress.parseURL(from: address, portOverride: normalizedPort)?.mediaPath
            ?? URL.fromMediaPath(address).mediaPath
        self.rootPath = canonical
        self.name = name
        self.address = SMBAddress.decodedDisplayAddress(canonical)
        self.port = normalizedPort
        self.username = username
        self.password = password
    }

    public var rootURL: URL {
        URL.fromMediaPath(rootPath)
    }

    public func scopedConfig(for folderURL: URL) -> SMBRootConfig {
        let canonicalFolder = (SMBAddress.parseURL(from: folderURL.mediaPath, portOverride: port) ?? folderURL.standardizedMediaURL).mediaPath
        let resolvedURL = URL.fromMediaPath(canonicalFolder)
        return SMBRootConfig(
            rootPath: canonicalFolder,
            name: SMBAddress.defaultDisplayName(for: resolvedURL),
            address: SMBAddress.decodedDisplayAddress(canonicalFolder),
            port: port,
            username: username,
            password: password
        )
    }
}

public enum SMBAddress {
    public static let defaultPort: Int = 445
    public static let defaultPortString: String = "445"

    public static func decodedDisplayAddress(_ rawAddress: String) -> String {
        WebDAVAddress.decodedDisplayAddress(rawAddress)
    }

    public static func autoCompletedAddressInput(_ rawAddress: String) -> String {
        let decoded = decodedDisplayAddress(rawAddress)
        let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("smb://") {
            let suffix = trimmed.dropFirst("smb://".count)
            return "smb://" + suffix
        }
        if "smb://".hasPrefix(lower) {
            return lower
        }
        if lower.contains("://") {
            return trimmed
        }
        return "smb://" + trimmed
    }

    public static func parsePort(_ rawPort: String) -> Int? {
        let trimmed = rawPort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), (1...65535).contains(value) else {
            return nil
        }
        return value
    }

    public static func parseURL(from rawAddress: String, portOverride: Int? = nil) -> URL? {
        let trimmed = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let withScheme: String
        if let schemeRange = trimmed.range(of: "://") {
            let scheme = String(trimmed[..<schemeRange.lowerBound]).lowercased()
            guard scheme == "smb" else {
                return nil
            }
            withScheme = "smb://" + trimmed[schemeRange.upperBound...]
        } else {
            guard !trimmed.hasPrefix("/") else {
                return nil
            }
            withScheme = "smb://" + trimmed
        }

        guard let schemeRange = withScheme.range(of: "://") else {
            return nil
        }
        let afterScheme = withScheme[schemeRange.upperBound...]
        let authority: Substring
        let rawPathWithQuery: Substring
        if let slashIndex = afterScheme.firstIndex(of: "/") {
            authority = afterScheme[..<slashIndex]
            rawPathWithQuery = afterScheme[slashIndex...]
        } else {
            authority = afterScheme
            rawPathWithQuery = ""
        }

        guard !authority.isEmpty else { return nil }

        let hostWithoutUser: Substring
        if let atIndex = authority.lastIndex(of: "@") {
            hostWithoutUser = authority[authority.index(after: atIndex)...]
        } else {
            hostWithoutUser = authority
        }
        guard !hostWithoutUser.isEmpty else { return nil }

        let hostPart: String
        var portInAddress: Int?
        if hostWithoutUser.hasPrefix("[") {
            guard let closeBracket = hostWithoutUser.firstIndex(of: "]") else { return nil }
            let nextIndex = hostWithoutUser.index(after: closeBracket)
            hostPart = String(hostWithoutUser[hostWithoutUser.index(after: hostWithoutUser.startIndex)..<closeBracket])
            if nextIndex < hostWithoutUser.endIndex {
                let remainder = hostWithoutUser[nextIndex...]
                guard remainder.hasPrefix(":"),
                      let parsedPort = Int(remainder.dropFirst()),
                      (1...65535).contains(parsedPort) else {
                    return nil
                }
                portInAddress = parsedPort
            }
        } else if let colonIndex = hostWithoutUser.lastIndex(of: ":") {
            hostPart = String(hostWithoutUser[..<colonIndex])
            let portString = hostWithoutUser[hostWithoutUser.index(after: colonIndex)...]
            guard let parsedPort = Int(portString), (1...65535).contains(parsedPort) else {
                return nil
            }
            portInAddress = parsedPort
        } else {
            hostPart = String(hostWithoutUser)
        }

        let trimmedHost = hostPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, !trimmedHost.contains(" ") else { return nil }

        let effectivePort: Int
        if let portOverride {
            guard (1...65535).contains(portOverride) else { return nil }
            if portOverride == defaultPort, let portInAddress, portInAddress != defaultPort {
                effectivePort = portInAddress
            } else {
                effectivePort = portOverride
            }
        } else {
            effectivePort = portInAddress ?? defaultPort
        }

        var rawPath = String(rawPathWithQuery)
        if let queryIndex = rawPath.firstIndex(of: "?") {
            rawPath = String(rawPath[..<queryIndex])
        }

        var normalizedPath = decodedDisplayAddress(rawPath)
        if normalizedPath.isEmpty {
            normalizedPath = "/"
        } else if !normalizedPath.hasPrefix("/") {
            normalizedPath = "/" + normalizedPath
        }
        while normalizedPath.count > 1 && normalizedPath.hasSuffix("/") {
            normalizedPath.removeLast()
        }

        var components = URLComponents()
        components.scheme = "smb"
        components.host = trimmedHost
        components.port = (effectivePort == defaultPort) ? nil : effectivePort
        components.path = normalizedPath == "/" ? "" : normalizedPath
        return components.url
    }

    public static func effectivePort(for url: URL, fallbackConfig: SMBRootConfig? = nil) -> Int {
        if let urlPort = url.port, (1...65535).contains(urlPort) {
            return urlPort
        }
        if let configPort = fallbackConfig?.port, (1...65535).contains(configPort) {
            return configPort
        }
        return defaultPort
    }

    public static func splitShareAndRelativePath(for url: URL) -> (share: String?, relativePath: String) {
        let decodedPath = decodedDisplayAddress(url.path)
        let segments = decodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard let share = segments.first, !share.isEmpty else {
            return (nil, "")
        }
        let rel = segments.dropFirst().joined(separator: "/")
        return (share, rel)
    }

    public static func isHostRoot(_ url: URL) -> Bool {
        guard url.isSMBURL else { return false }
        return splitShareAndRelativePath(for: url).share == nil
    }

    public static func defaultDisplayName(for url: URL) -> String {
        WebDAVAddress.defaultDisplayName(for: url)
    }
}

public final class SMBConfigurationStore: @unchecked Sendable {
    public static let shared = SMBConfigurationStore()

    private static let defaultsKey = "smbRootConfigs"
    private let lock = NSLock()
    private let userDefaults: UserDefaults
    private var configsByRootPath: [String: SMBRootConfig]

    public init(userDefaults: UserDefaults? = nil) {
        let resolvedDefaults = userDefaults
            ?? UserDefaults(suiteName: ApplicationInfo.preferencesSuiteIdentifier)
            ?? .standard
        self.userDefaults = resolvedDefaults
        self.configsByRootPath = Self.decodeConfigs(from: resolvedDefaults.data(forKey: Self.defaultsKey))
    }

    public func save(_ config: SMBRootConfig) {
        upsert(config)
    }

    public func upsert(_ config: SMBRootConfig) {
        let canonicalKey = URL.fromMediaPath(config.rootPath).mediaPath
        var normalized = config
        normalized.rootPath = canonicalKey
        normalized.address = SMBAddress.decodedDisplayAddress(config.address)
        lock.lock()
        configsByRootPath[canonicalKey] = normalized
        let snapshot = Array(configsByRootPath.values)
        lock.unlock()
        persist(snapshot)
    }

    public func remove(url: URL) {
        remove(forRootPath: url.mediaPath)
    }

    public func remove(forRootPath rootPath: String) {
        let canonicalKey = URL.fromMediaPath(rootPath).mediaPath
        lock.lock()
        configsByRootPath.removeValue(forKey: canonicalKey)
        let snapshot = Array(configsByRootPath.values)
        lock.unlock()
        persist(snapshot)
    }

    public func config(for url: URL) -> SMBRootConfig? {
        config(forRootPath: url.mediaPath)
    }

    public func config(forRootPath rootPath: String) -> SMBRootConfig? {
        let canonicalKey = URL.fromMediaPath(rootPath).mediaPath
        lock.lock()
        defer { lock.unlock() }
        return configsByRootPath[canonicalKey]
    }

    public func matchingConfig(forMediaPath mediaPath: String) -> SMBRootConfig? {
        guard mediaPath.isSMBPath else { return nil }
        let targetURL = URL.fromMediaPath(mediaPath)
        let canonical = targetURL.mediaPath
        lock.lock()
        let allConfigs = Array(configsByRootPath.values)
        lock.unlock()

        if let prefixMatch = allConfigs
            .filter({ config in
                canonical == config.rootPath || canonical.hasPrefix(config.rootPath + "/")
            })
            .max(by: { $0.rootPath.count < $1.rootPath.count }) {
            return prefixMatch
        }

        guard let targetHost = targetURL.host?.lowercased() else { return nil }
        let targetPort = targetURL.port ?? SMBAddress.defaultPort
        return allConfigs.first { config in
            let configURL = URL.fromMediaPath(config.rootPath)
            return configURL.host?.lowercased() == targetHost && config.port == targetPort
        }
    }

    public func allConfigs() -> [SMBRootConfig] {
        lock.lock()
        defer { lock.unlock() }
        return Array(configsByRootPath.values)
    }

    public func rewriteFolderPathPrefix(from oldPath: String, to newPath: String) {
        guard oldPath.isSMBPath, newPath.isSMBPath else { return }
        let canonicalOld = URL.fromMediaPath(oldPath).mediaPath
        let canonicalNew = URL.fromMediaPath(newPath).mediaPath
        let newLeafName = LibraryRenamer.lastPathComponent(of: canonicalNew)

        lock.lock()
        var updatedConfigs: [String: SMBRootConfig] = [:]
        var changed = false
        for (_, var config) in configsByRootPath {
            if config.rootPath == canonicalOld {
                config.rootPath = canonicalNew
                config.address = SMBAddress.decodedDisplayAddress(canonicalNew)
                config.name = newLeafName
                updatedConfigs[canonicalNew] = config
                changed = true
            } else if config.rootPath.hasPrefix(canonicalOld + "/") {
                let suffix = String(config.rootPath.dropFirst(canonicalOld.count))
                let rewrittenRoot = canonicalNew + suffix
                config.rootPath = rewrittenRoot
                config.address = SMBAddress.decodedDisplayAddress(rewrittenRoot)
                updatedConfigs[rewrittenRoot] = config
                changed = true
            } else {
                updatedConfigs[config.rootPath] = config
            }
        }
        if changed {
            configsByRootPath = updatedConfigs
        }
        let snapshot = Array(configsByRootPath.values)
        lock.unlock()
        if changed {
            persist(snapshot)
        }
    }

    private func persist(_ configs: [SMBRootConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        userDefaults.set(data, forKey: Self.defaultsKey)
    }

    private static func decodeConfigs(from data: Data?) -> [String: SMBRootConfig] {
        guard let data,
              let decoded = try? JSONDecoder().decode([SMBRootConfig].self, from: data) else {
            return [:]
        }
        var result: [String: SMBRootConfig] = [:]
        for var config in decoded {
            let key = URL.fromMediaPath(config.rootPath).mediaPath
            config.rootPath = key
            config.address = SMBAddress.decodedDisplayAddress(config.address)
            result[key] = config
        }
        return result
    }
}

public struct SMBDirectoryEntry: Equatable, Sendable {
    public let name: String
    public let isDirectory: Bool
    public let fileSize: Int64
    public let modifiedAt: Date

    public init(name: String, isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        self.name = name
        self.isDirectory = isDirectory
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
    }
}

public protocol SMBBackendProtocol: Sendable {
    func listShares(
        host: String,
        port: Int,
        username: String,
        password: String
    ) throws -> [String]

    func listDirectory(
        host: String,
        port: Int,
        share: String,
        relativePath: String,
        username: String,
        password: String
    ) throws -> [SMBDirectoryEntry]

    func stat(
        host: String,
        port: Int,
        share: String,
        relativePath: String,
        username: String,
        password: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date)

    func readRange(
        host: String,
        port: Int,
        share: String,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String
    ) throws -> (data: Data, totalSize: UInt64)

    func rename(
        host: String,
        port: Int,
        share: String,
        oldRelativePath: String,
        newRelativePath: String,
        username: String,
        password: String
    ) throws
}

public final class NativeCSMBBackend: SMBBackendProtocol, @unchecked Sendable {
    public static let shared = NativeCSMBBackend()

    public init() {}

    public func listShares(
        host: String,
        port: Int,
        username: String,
        password: String
    ) throws -> [String] {
        var shareList = csmb_share_list_t(names: nil, count: 0)
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            username.withCString { userC in
                password.withCString { passC in
                    csmb_list_shares(hostC, Int32(port), userC, passC, &shareList, &errPtr)
                }
            }
        }
        defer {
            csmb_free_share_list(&shareList)
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw Self.mapError(code, errPtr: errPtr)
        }
        var names: [String] = []
        if let rawNames = shareList.names {
            for idx in 0..<shareList.count {
                if let namePtr = rawNames[idx] {
                    names.append(String(cString: namePtr).precomposedStringWithCanonicalMapping)
                }
            }
        }
        return names
    }

    public func listDirectory(
        host: String,
        port: Int,
        share: String,
        relativePath: String,
        username: String,
        password: String
    ) throws -> [SMBDirectoryEntry] {
        let session = try connectSession(
            host: host,
            port: port,
            share: share,
            username: username,
            password: password
        )
        defer { csmb_session_disconnect(session) }
        return try Self.listDirectory(on: session, relativePath: relativePath)
    }

    public func stat(
        host: String,
        port: Int,
        share: String,
        relativePath: String,
        username: String,
        password: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        let session = try connectSession(
            host: host,
            port: port,
            share: share,
            username: username,
            password: password
        )
        defer { csmb_session_disconnect(session) }
        return try Self.stat(on: session, relativePath: relativePath)
    }

    public func readRange(
        host: String,
        port: Int,
        share: String,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String
    ) throws -> (data: Data, totalSize: UInt64) {
        let session = try connectSession(
            host: host,
            port: port,
            share: share,
            username: username,
            password: password
        )
        defer { csmb_session_disconnect(session) }

        var bufPtr: UnsafeMutablePointer<UInt8>?
        var bytesRead: Int = 0
        var totalSize: UInt64 = 0
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = relativePath.withCString { relC in
            csmb_session_read_file_range(
                session,
                relC,
                offset,
                maxLength,
                &bufPtr,
                &bytesRead,
                &totalSize,
                &errPtr
            )
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
        port: Int,
        share: String,
        oldRelativePath: String,
        newRelativePath: String,
        username: String,
        password: String
    ) throws {
        let session = try connectSession(
            host: host,
            port: port,
            share: share,
            username: username,
            password: password
        )
        defer { csmb_session_disconnect(session) }

        var errPtr: UnsafeMutablePointer<CChar>?
        let code = oldRelativePath.withCString { oldC in
            newRelativePath.withCString { newC in
                csmb_session_rename(session, oldC, newC, &errPtr)
            }
        }
        defer {
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw Self.mapError(code, errPtr: errPtr)
        }
    }

    func connectSession(
        host: String,
        port: Int,
        share: String,
        username: String,
        password: String
    ) throws -> OpaquePointer {
        var sessionPtr: OpaquePointer?
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = host.withCString { hostC in
            share.withCString { shareC in
                username.withCString { userC in
                    password.withCString { passC in
                        csmb_session_connect(
                            hostC,
                            Int32(port),
                            shareC,
                            userC,
                            passC,
                            &sessionPtr,
                            &errPtr
                        )
                    }
                }
            }
        }
        defer {
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        guard code == CSMB_OK, let sessionPtr else {
            throw Self.mapError(code, errPtr: errPtr)
        }
        return sessionPtr
    }

    static func listDirectory(
        on session: OpaquePointer,
        relativePath: String
    ) throws -> [SMBDirectoryEntry] {
        var dirList = csmb_dir_list_t(entries: nil, count: 0)
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = relativePath.withCString { relC in
            csmb_session_list_directory(session, relC, &dirList, &errPtr)
        }
        defer {
            csmb_free_dir_list(&dirList)
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw mapError(code, errPtr: errPtr)
        }
        var results: [SMBDirectoryEntry] = []
        if let entries = dirList.entries {
            results.reserveCapacity(dirList.count)
            for idx in 0..<dirList.count {
                let raw = entries[idx]
                guard let namePtr = raw.name else { continue }
                let name = String(cString: namePtr).precomposedStringWithCanonicalMapping
                results.append(
                    SMBDirectoryEntry(
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

    static func stat(
        on session: OpaquePointer,
        relativePath: String
    ) throws -> (isDirectory: Bool, fileSize: Int64, modifiedAt: Date) {
        var isDir: Int32 = 0
        var sizeBytes: UInt64 = 0
        var modifiedEpoch: Int64 = 0
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = relativePath.withCString { relC in
            csmb_session_stat(session, relC, &isDir, &sizeBytes, &modifiedEpoch, &errPtr)
        }
        defer {
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        if code != CSMB_OK {
            throw mapError(code, errPtr: errPtr)
        }
        return (
            isDirectory: isDir != 0,
            fileSize: Int64(bitPattern: sizeBytes),
            modifiedAt: Date(timeIntervalSince1970: TimeInterval(modifiedEpoch))
        )
    }

    static func mapError(
        _ code: csmb_error_code_t,
        errPtr: UnsafeMutablePointer<CChar>?
    ) -> SMBError {
        let message = errPtr.map { String(cString: $0) } ?? "SMB connection failed."
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

public final class SMBClient: @unchecked Sendable {
    public static let shared = SMBClient()

    private let configurationStore: SMBConfigurationStore
    private let lock = NSLock()
    private var customBackend: (any SMBBackendProtocol)?
    private var cachedFileSizes: [String: UInt64] = [:]

    public init(
        configurationStore: SMBConfigurationStore = .shared,
        customBackend: (any SMBBackendProtocol)? = nil
    ) {
        self.configurationStore = configurationStore
        self.customBackend = customBackend
    }

    public func setCustomBackendForTesting(_ backend: (any SMBBackendProtocol)?) {
        lock.lock()
        customBackend = backend
        cachedFileSizes.removeAll()
        lock.unlock()
    }

    var activeBackend: any SMBBackendProtocol {
        lock.lock()
        defer { lock.unlock() }
        return customBackend ?? NativeCSMBBackend.shared
    }

    var hasCustomBackend: Bool {
        lock.lock()
        defer { lock.unlock() }
        return customBackend != nil
    }

    public func connectAndBrowseDirectory(
        address: String,
        port: String,
        username: String,
        password: String
    ) async throws -> (config: SMBRootConfig, items: [WebDAVBrowserItem]) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            throw SMBError.invalidInput("Address is required.")
        }
        guard !trimmedPort.isEmpty else {
            throw SMBError.invalidInput("Port is required.")
        }
        guard let parsedPort = SMBAddress.parsePort(trimmedPort) else {
            throw SMBError.invalidPort
        }
        guard let rootURL = SMBAddress.parseURL(from: trimmedAddress, portOverride: parsedPort) else {
            throw SMBError.invalidAddress
        }

        try Task.checkCancellation()

        let effectiveName = SMBAddress.defaultDisplayName(for: rootURL)
        let rootMediaPath = rootURL.mediaPath
        let initialConfig = SMBRootConfig(
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
        baseConfig: SMBRootConfig
    ) async throws -> [WebDAVBrowserItem] {
        let normalizedURL = SMBAddress.parseURL(from: folderURL.mediaPath, portOverride: baseConfig.port)
            ?? folderURL.standardizedMediaURL
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) { [self] in
            try Task.checkCancellation()
            return try self.listBrowserItems(at: normalizedURL, config: baseConfig)
        }.value
    }

    public func scanDirectoryTree(rootURL: URL) throws -> [WebDAVRemoteFile] {
        let endpoint = resolveEndpoint(for: rootURL.mediaPath)
        guard let share = endpoint.share, !share.isEmpty else {
            throw SMBError.invalidAddress
        }

        var results: [WebDAVRemoteFile] = []
        var visitedDirectories: Set<String> = []
        let backend = activeBackend

        if !hasCustomBackend, let nativeBackend = backend as? NativeCSMBBackend {
            let session = try nativeBackend.connectSession(
                host: endpoint.host,
                port: endpoint.port,
                share: share,
                username: endpoint.config.username,
                password: endpoint.config.password
            )
            defer { csmb_session_disconnect(session) }
            try scanDirectoryRecursive(
                directoryURL: endpoint.url,
                relativePath: endpoint.relativePath,
                listEntries: { relPath in
                    try NativeCSMBBackend.listDirectory(on: session, relativePath: relPath)
                },
                visitedDirectories: &visitedDirectories,
                results: &results
            )
        } else {
            try scanDirectoryRecursive(
                directoryURL: endpoint.url,
                relativePath: endpoint.relativePath,
                listEntries: { relPath in
                    try backend.listDirectory(
                        host: endpoint.host,
                        port: endpoint.port,
                        share: share,
                        relativePath: relPath,
                        username: endpoint.config.username,
                        password: endpoint.config.password
                    )
                },
                visitedDirectories: &visitedDirectories,
                results: &results
            )
        }

        return results.sorted { $0.url.mediaPath < $1.url.mediaPath }
    }

    public func downloadData(from url: URL) throws -> Data {
        guard url.isSMBURL else {
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
        guard let share = endpoint.share, !share.isEmpty, !endpoint.relativePath.isEmpty else {
            throw SMBError.directoryNotFound
        }
        let result = try activeBackend.readRange(
            host: endpoint.host,
            port: endpoint.port,
            share: share,
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
        guard let share = endpoint.share, !share.isEmpty, !endpoint.relativePath.isEmpty else {
            throw SMBError.directoryNotFound
        }
        let st = try activeBackend.stat(
            host: endpoint.host,
            port: endpoint.port,
            share: share,
            relativePath: endpoint.relativePath,
            username: endpoint.config.username,
            password: endpoint.config.password
        )
        guard !st.isDirectory else {
            throw SMBError.notADirectory
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
        guard let share = endpoint.share, !share.isEmpty else {
            return false
        }
        do {
            let st = try activeBackend.stat(
                host: endpoint.host,
                port: endpoint.port,
                share: share,
                relativePath: endpoint.relativePath,
                username: endpoint.config.username,
                password: endpoint.config.password
            )
            return st.isDirectory
        } catch SMBError.directoryNotFound, SMBError.notADirectory {
            return false
        }
    }

    public func fileExists(
        at filePath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) throws -> Bool {
        let endpoint = resolveEndpoint(for: filePath, peerPathInSameDirectory: peerPath)
        guard let share = endpoint.share, !share.isEmpty, !endpoint.relativePath.isEmpty else {
            return false
        }
        do {
            let st = try activeBackend.stat(
                host: endpoint.host,
                port: endpoint.port,
                share: share,
                relativePath: endpoint.relativePath,
                username: endpoint.config.username,
                password: endpoint.config.password
            )
            return !st.isDirectory
        } catch SMBError.directoryNotFound, SMBError.notADirectory {
            return false
        }
    }

    public func resourceExists(
        at targetPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) throws -> Bool {
        let endpoint = resolveEndpoint(for: targetPath, peerPathInSameDirectory: peerPath)
        guard let share = endpoint.share, !share.isEmpty else {
            return false
        }
        do {
            _ = try activeBackend.stat(
                host: endpoint.host,
                port: endpoint.port,
                share: share,
                relativePath: endpoint.relativePath,
                username: endpoint.config.username,
                password: endpoint.config.password
            )
            return true
        } catch SMBError.directoryNotFound {
            return false
        }
    }

    public func listDirectoryItemsInParent(of childPath: String) throws -> [String: Bool]? {
        let parentPath = LibraryRenamer.parentPath(of: childPath)
        guard parentPath != childPath else {
            return nil
        }
        let endpoint = resolveEndpoint(for: parentPath, peerPathInSameDirectory: childPath)
        guard let share = endpoint.share, !share.isEmpty else {
            return nil
        }
        let entries = try activeBackend.listDirectory(
            host: endpoint.host,
            port: endpoint.port,
            share: share,
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
        guard let sourceShare = source.share,
              let destShare = destination.share,
              sourceShare.caseInsensitiveCompare(destShare) == .orderedSame,
              !source.relativePath.isEmpty,
              !destination.relativePath.isEmpty else {
            throw SMBError.invalidAddress
        }
        try activeBackend.rename(
            host: source.host,
            port: source.port,
            share: sourceShare,
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

    public func resolvePlayableInput(for url: URL) -> WebDAVPlayableInput {
        guard url.isSMBURL else {
            return WebDAVPlayableInput(url: url.path, httpHeaders: nil)
        }
        if let streamURL = SMBStreamServer.shared.registerAndResolveHTTPURL(for: url, client: self) {
            return WebDAVPlayableInput(url: streamURL, httpHeaders: nil)
        }
        return WebDAVPlayableInput(url: url.mediaPath, httpHeaders: nil)
    }

    // MARK: - Internal Helpers

    struct ResolvedEndpoint {
        let url: URL
        let host: String
        let port: Int
        let share: String?
        let relativePath: String
        let config: SMBRootConfig
    }

    func resolveEndpoint(
        for targetPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) -> ResolvedEndpoint {
        let matchedConfig = configurationStore.matchingConfig(forMediaPath: targetPath)
            ?? peerPath.flatMap { configurationStore.matchingConfig(forMediaPath: $0) }
        let targetURL = SMBAddress.parseURL(from: targetPath, portOverride: matchedConfig?.port)
            ?? URL.fromMediaPath(targetPath)
        let host = targetURL.host ?? ""
        let port = SMBAddress.effectivePort(for: targetURL, fallbackConfig: matchedConfig)
        let (share, relativePath) = SMBAddress.splitShareAndRelativePath(for: targetURL)
        let config = matchedConfig ?? SMBRootConfig(
            rootPath: targetURL.mediaPath,
            name: SMBAddress.defaultDisplayName(for: targetURL),
            address: targetURL.mediaPath,
            port: port,
            username: "",
            password: ""
        )
        return ResolvedEndpoint(
            url: targetURL,
            host: host,
            port: port,
            share: share,
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
        config: SMBRootConfig
    ) throws -> [WebDAVBrowserItem] {
        guard let host = directoryURL.host, !host.isEmpty else {
            throw SMBError.invalidAddress
        }
        let port = SMBAddress.effectivePort(for: directoryURL, fallbackConfig: config)
        let (share, relativePath) = SMBAddress.splitShareAndRelativePath(for: directoryURL)
        let backend = activeBackend

        if share == nil {
            let shares = try backend.listShares(
                host: host,
                port: port,
                username: config.username,
                password: config.password
            )
            var foldersByPath: [String: WebDAVBrowserItem] = [:]
            for rawShare in shares {
                try Task.checkCancellation()
                let shareName = rawShare.precomposedStringWithCanonicalMapping
                if shareName.isEmpty || shareName.hasPrefix(".") || shareName.hasSuffix("$") {
                    continue
                }
                let shareURL = Self.appendingChildComponent(
                    shareName,
                    to: directoryURL,
                    port: port
                )
                let item = WebDAVBrowserItem(url: shareURL, name: shareName, kind: .folder)
                foldersByPath[item.id] = item
            }
            return Self.sortBrowserItems(folders: Array(foldersByPath.values), files: [])
        }

        let entries = try backend.listDirectory(
            host: host,
            port: port,
            share: share!,
            relativePath: relativePath,
            username: config.username,
            password: config.password
        )

        var foldersByPath: [String: WebDAVBrowserItem] = [:]
        var filesByPath: [String: WebDAVBrowserItem] = [:]

        for entry in entries {
            try Task.checkCancellation()
            let name = entry.name.precomposedStringWithCanonicalMapping
            if name.isEmpty || name.hasPrefix(".") {
                continue
            }
            let childURL = Self.appendingChildComponent(
                name,
                to: directoryURL,
                port: port
            )
            if entry.isDirectory {
                let item = WebDAVBrowserItem(url: childURL, name: name, kind: .folder)
                foldersByPath[item.id] = item
            } else {
                let ext = (name as NSString).pathExtension.lowercased()
                if VideoMatcher.defaultVideoExtensions.contains(ext) {
                    let item = WebDAVBrowserItem(url: childURL, name: name, kind: .video)
                    filesByPath[item.id] = item
                    if entry.fileSize > 0 {
                        cacheFileSize(UInt64(entry.fileSize), forMediaPath: childURL.mediaPath)
                    }
                } else if SubtitleFileScanner.supportedSubtitleExtensions.contains(ext) {
                    let item = WebDAVBrowserItem(url: childURL, name: name, kind: .subtitle)
                    filesByPath[item.id] = item
                    if entry.fileSize > 0 {
                        cacheFileSize(UInt64(entry.fileSize), forMediaPath: childURL.mediaPath)
                    }
                }
            }
        }

        return Self.sortBrowserItems(
            folders: Array(foldersByPath.values),
            files: Array(filesByPath.values)
        )
    }

    private func scanDirectoryRecursive(
        directoryURL: URL,
        relativePath: String,
        listEntries: (String) throws -> [SMBDirectoryEntry],
        visitedDirectories: inout Set<String>,
        results: inout [WebDAVRemoteFile]
    ) throws {
        try Task.checkCancellation()
        let dirMediaPath = directoryURL.mediaPath
        guard visitedDirectories.insert(dirMediaPath).inserted else {
            return
        }

        let port = directoryURL.port ?? SMBAddress.defaultPort
        let entries = try listEntries(relativePath)
        for entry in entries {
            try Task.checkCancellation()
            let name = entry.name.precomposedStringWithCanonicalMapping
            if name.isEmpty || name.hasPrefix(".") {
                continue
            }
            let childURL = Self.appendingChildComponent(name, to: directoryURL, port: port)
            let childRelPath = relativePath.isEmpty ? name : "\(relativePath)/\(name)"

            if entry.isDirectory {
                try scanDirectoryRecursive(
                    directoryURL: childURL,
                    relativePath: childRelPath,
                    listEntries: listEntries,
                    visitedDirectories: &visitedDirectories,
                    results: &results
                )
            } else {
                if entry.fileSize > 0 {
                    cacheFileSize(UInt64(entry.fileSize), forMediaPath: childURL.mediaPath)
                }
                results.append(
                    WebDAVRemoteFile(
                        url: childURL,
                        fileSize: entry.fileSize,
                        modifiedAt: entry.modifiedAt
                    )
                )
            }
        }
    }

    private static func appendingChildComponent(
        _ name: String,
        to directoryURL: URL,
        port: Int
    ) -> URL {
        let baseMediaPath = directoryURL.mediaPath
        let combined = baseMediaPath.hasSuffix("/") ? "\(baseMediaPath)\(name)" : "\(baseMediaPath)/\(name)"
        return SMBAddress.parseURL(from: combined, portOverride: port) ?? directoryURL.appendingPathComponent(name)
    }

    private static func sortBrowserItems(
        folders: [WebDAVBrowserItem],
        files: [WebDAVBrowserItem]
    ) -> [WebDAVBrowserItem] {
        let sortedFolders = folders.sorted {
            let cmp = $0.name.localizedStandardCompare($1.name)
            if cmp != .orderedSame {
                return cmp == .orderedAscending
            }
            return $0.id < $1.id
        }
        let sortedFiles = files.sorted {
            let cmp = $0.name.localizedStandardCompare($1.name)
            if cmp != .orderedSame {
                return cmp == .orderedAscending
            }
            return $0.id < $1.id
        }
        return sortedFolders + sortedFiles
    }
}

final class SMBStreamServer: @unchecked Sendable {
    static let shared = SMBStreamServer()

    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var boundPort: UInt16 = 0
    private var urlsByToken: [String: (url: URL, client: SMBClient)] = [:]
    private let acceptQueue = DispatchQueue(label: "com.cueseeker.smb.stream.accept", qos: .userInitiated)
    private let connectionQueue = DispatchQueue(
        label: "com.cueseeker.smb.stream.connection",
        qos: .userInitiated,
        attributes: .concurrent
    )

    func registerAndResolveHTTPURL(for smbURL: URL, client: SMBClient) -> String? {
        let canonical = smbURL.mediaPath
        let digest = SHA256.hash(data: Data(canonical.utf8))
        let token = digest.prefix(16).map { String(format: "%02x", $0) }.joined()

        lock.lock()
        if listenFD < 0 {
            startListenerLocked()
        }
        let port = boundPort
        if port > 0 {
            urlsByToken[token] = (smbURL, client)
        }
        lock.unlock()

        guard port > 0 else { return nil }
        let leaf = smbURL.lastPathComponent.isEmpty ? "stream.bin" : smbURL.lastPathComponent
        let encodedLeaf = leaf.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "stream.bin"
        return "http://127.0.0.1:\(port)/smb/\(token)/\(encodedLeaf)"
    }

    private func startListenerLocked() {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var yes: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindRC = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindRC == 0, Darwin.listen(fd, 128) == 0 else {
            Darwin.close(fd)
            return
        }

        var boundAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameRC = withUnsafeMutablePointer(to: &boundAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(fd, $0, &addrLen)
            }
        }
        guard nameRC == 0 else {
            Darwin.close(fd)
            return
        }

        listenFD = fd
        boundPort = UInt16(bigEndian: boundAddr.sin_port)

        acceptQueue.async { [weak self] in
            self?.acceptLoop(serverFD: fd)
        }
    }

    private func acceptLoop(serverFD: Int32) {
        while true {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.accept(serverFD, $0, &clientLen)
                }
            }
            if clientFD < 0 {
                if errno == EINTR {
                    continue
                }
                break
            }
            connectionQueue.async { [weak self] in
                self?.handleClient(fd: clientFD)
            }
        }
    }

    private func handleClient(fd: Int32) {
        var yes: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
        defer { Darwin.close(fd) }

        guard let requestHeader = Self.readHTTPHeader(from: fd) else {
            return
        }
        let lines = requestHeader.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return }
        let method = String(parts[0]).uppercased()
        let path = String(parts[1])

        guard method == "GET" || method == "HEAD" else {
            Self.writeAll(to: fd, string: "HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n")
            return
        }

        let pathSegments = path.split(separator: "/", omittingEmptySubsequences: true)
        guard pathSegments.count >= 2, pathSegments[0] == "smb" else {
            Self.writeAll(to: fd, string: "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
            return
        }
        let token = String(pathSegments[1])

        lock.lock()
        let entry = urlsByToken[token]
        lock.unlock()

        guard let (smbURL, client) = entry else {
            Self.writeAll(to: fd, string: "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
            return
        }

        var rangeHeader: String?
        for line in lines.dropFirst() {
            if line.lowercased().hasPrefix("range:") {
                rangeHeader = String(line.dropFirst("range:".count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        if method == "HEAD" {
            guard let totalSize = try? client.statFileSize(for: smbURL) else {
                Self.writeAll(to: fd, string: "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
                return
            }
            let headers = [
                "HTTP/1.1 200 OK",
                "Content-Type: application/octet-stream",
                "Accept-Ranges: bytes",
                "Content-Length: \(totalSize)",
                "Connection: close",
                "\r\n"
            ].joined(separator: "\r\n")
            Self.writeAll(to: fd, string: headers)
            return
        }

        if !client.hasCustomBackend {
            streamNativeSMBFile(fd: fd, smbURL: smbURL, client: client, rangeHeader: rangeHeader)
        } else {
            streamMockSMBFile(fd: fd, smbURL: smbURL, client: client, rangeHeader: rangeHeader)
        }
    }

    private func streamNativeSMBFile(
        fd: Int32,
        smbURL: URL,
        client: SMBClient,
        rangeHeader: String?
    ) {
        let endpoint = client.resolveEndpoint(for: smbURL.mediaPath)
        guard let share = endpoint.share, !share.isEmpty, !endpoint.relativePath.isEmpty else {
            Self.writeAll(to: fd, string: "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
            return
        }

        guard let session = try? NativeCSMBBackend.shared.connectSession(
            host: endpoint.host,
            port: endpoint.port,
            share: share,
            username: endpoint.config.username,
            password: endpoint.config.password
        ) else {
            Self.writeAll(to: fd, string: "HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n")
            return
        }
        defer { csmb_session_disconnect(session) }

        var fileHandle: OpaquePointer?
        var totalSize: UInt64 = 0
        var maxReadSize: UInt32 = 262144
        var errPtr: UnsafeMutablePointer<CChar>?
        let openCode = endpoint.relativePath.withCString { relC in
            csmb_file_open(session, relC, &fileHandle, &totalSize, &maxReadSize, &errPtr)
        }
        if let errPtr { csmb_free_buffer(errPtr) }
        guard openCode == CSMB_OK, let fileHandle else {
            Self.writeAll(to: fd, string: "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
            return
        }
        defer { csmb_file_close(fileHandle) }

        guard let range = Self.resolveByteRange(rangeHeader: rangeHeader, totalSize: totalSize) else {
            let notSatisfiable = [
                "HTTP/1.1 416 Range Not Satisfiable",
                "Content-Range: bytes */\(totalSize)",
                "Connection: close",
                "\r\n"
            ].joined(separator: "\r\n")
            Self.writeAll(to: fd, string: notSatisfiable)
            return
        }

        let headerLines: [String]
        if range.isPartial {
            headerLines = [
                "HTTP/1.1 206 Partial Content",
                "Content-Type: application/octet-stream",
                "Accept-Ranges: bytes",
                "Content-Range: bytes \(range.start)-\(range.end)/\(totalSize)",
                "Content-Length: \(range.length)",
                "Connection: close",
                "\r\n"
            ]
        } else {
            headerLines = [
                "HTTP/1.1 200 OK",
                "Content-Type: application/octet-stream",
                "Accept-Ranges: bytes",
                "Content-Length: \(range.length)",
                "Connection: close",
                "\r\n"
            ]
        }
        guard Self.writeAll(to: fd, string: headerLines.joined(separator: "\r\n")) else {
            return
        }

        guard range.length > 0 else { return }

        let chunkCap = max(65536, min(Int(maxReadSize), 524288))
        var buffer = [UInt8](repeating: 0, count: chunkCap)
        var currentOffset = range.start
        var remaining = range.length

        while remaining > 0 {
            let toRead = UInt32(min(UInt64(chunkCap), remaining))
            var bytesRead: Int = 0
            var readErr: UnsafeMutablePointer<CChar>?
            let readCode = buffer.withUnsafeMutableBufferPointer { bufPtr in
                csmb_file_pread(
                    fileHandle,
                    currentOffset,
                    bufPtr.baseAddress,
                    toRead,
                    &bytesRead,
                    &readErr
                )
            }
            if let readErr { csmb_free_buffer(readErr) }
            if readCode != CSMB_OK || bytesRead <= 0 {
                break
            }
            let wrote = buffer.withUnsafeBytes { rawBuf in
                Self.writeAll(to: fd, baseAddress: rawBuf.baseAddress!, count: bytesRead)
            }
            if !wrote {
                break
            }
            currentOffset += UInt64(bytesRead)
            remaining -= UInt64(bytesRead)
        }
    }

    private func streamMockSMBFile(
        fd: Int32,
        smbURL: URL,
        client: SMBClient,
        rangeHeader: String?
    ) {
        guard let totalSize = try? client.statFileSize(for: smbURL) else {
            Self.writeAll(to: fd, string: "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
            return
        }
        guard let range = Self.resolveByteRange(rangeHeader: rangeHeader, totalSize: totalSize) else {
            let notSatisfiable = [
                "HTTP/1.1 416 Range Not Satisfiable",
                "Content-Range: bytes */\(totalSize)",
                "Connection: close",
                "\r\n"
            ].joined(separator: "\r\n")
            Self.writeAll(to: fd, string: notSatisfiable)
            return
        }
        let headerLines: [String]
        if range.isPartial {
            headerLines = [
                "HTTP/1.1 206 Partial Content",
                "Content-Type: application/octet-stream",
                "Accept-Ranges: bytes",
                "Content-Range: bytes \(range.start)-\(range.end)/\(totalSize)",
                "Content-Length: \(range.length)",
                "Connection: close",
                "\r\n"
            ]
        } else {
            headerLines = [
                "HTTP/1.1 200 OK",
                "Content-Type: application/octet-stream",
                "Accept-Ranges: bytes",
                "Content-Length: \(range.length)",
                "Connection: close",
                "\r\n"
            ]
        }
        guard Self.writeAll(to: fd, string: headerLines.joined(separator: "\r\n")) else {
            return
        }
        guard range.length > 0,
              let (data, _) = try? client.readRange(from: smbURL, offset: range.start, maxLength: range.length) else {
            return
        }
        _ = data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return true }
            return Self.writeAll(to: fd, baseAddress: base, count: rawBuf.count)
        }
    }

    private struct ResolvedByteRange {
        let start: UInt64
        let end: UInt64
        let length: UInt64
        let isPartial: Bool
    }

    private static func resolveByteRange(
        rangeHeader: String?,
        totalSize: UInt64
    ) -> ResolvedByteRange? {
        guard let rangeHeader,
              rangeHeader.lowercased().hasPrefix("bytes=") else {
            let end = totalSize > 0 ? totalSize - 1 : 0
            return ResolvedByteRange(start: 0, end: end, length: totalSize, isPartial: false)
        }
        guard totalSize > 0 else {
            return nil
        }
        let spec = rangeHeader.dropFirst("bytes=".count).split(separator: ",").first ?? ""
        let parts = spec.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return nil
        }
        let startStr = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let endStr = String(parts[1]).trimmingCharacters(in: .whitespaces)

        if startStr.isEmpty {
            guard let suffixLen = UInt64(endStr), suffixLen > 0 else { return nil }
            let start = suffixLen >= totalSize ? 0 : (totalSize - suffixLen)
            let end = totalSize - 1
            return ResolvedByteRange(start: start, end: end, length: end - start + 1, isPartial: true)
        }

        guard let start = UInt64(startStr), start < totalSize else {
            return nil
        }
        let end: UInt64
        if endStr.isEmpty {
            end = totalSize - 1
        } else if let parsedEnd = UInt64(endStr) {
            end = min(parsedEnd, totalSize - 1)
        } else {
            return nil
        }
        guard start <= end else { return nil }
        return ResolvedByteRange(start: start, end: end, length: end - start + 1, isPartial: true)
    }

    private static func readHTTPHeader(from fd: Int32) -> String? {
        var accumulated = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        let delimiter = Data([13, 10, 13, 10]) // \r\n\r\n
        while accumulated.count < 16384 {
            let n = Darwin.read(fd, &buf, buf.count)
            if n <= 0 {
                break
            }
            accumulated.append(buf, count: n)
            if accumulated.range(of: delimiter) != nil {
                break
            }
        }
        guard !accumulated.isEmpty else { return nil }
        return String(data: accumulated, encoding: .utf8)
    }

    @discardableResult
    private static func writeAll(to fd: Int32, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return true }
            return writeAll(to: fd, baseAddress: base, count: rawBuf.count)
        }
    }

    private static func writeAll(to fd: Int32, baseAddress: UnsafeRawPointer, count: Int) -> Bool {
        var totalWritten = 0
        while totalWritten < count {
            let n = Darwin.write(fd, baseAddress.advanced(by: totalWritten), count - totalWritten)
            if n < 0 {
                if errno == EINTR {
                    continue
                }
                return false
            }
            if n == 0 {
                return false
            }
            totalWritten += n
        }
        return true
    }
}
