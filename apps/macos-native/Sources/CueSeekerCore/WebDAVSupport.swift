import CryptoKit
import Foundation

public enum WebDAVError: LocalizedError, Equatable, Sendable {
    case invalidInput(String)
    case invalidAddress
    case authenticationFailed
    case directoryNotFound
    case notADirectory
    case httpError(statusCode: Int)
    case invalidResponse
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .invalidAddress:
            return "Invalid WebDAV folder address."
        case .authenticationFailed:
            return "WebDAV authentication failed. Check username and password."
        case .directoryNotFound:
            return "WebDAV folder was not found."
        case .notADirectory:
            return "The specified WebDAV address is not a folder."
        case .httpError(let statusCode):
            return "WebDAV server returned HTTP \(statusCode)."
        case .invalidResponse:
            return "Invalid response from WebDAV server."
        case .networkError(let message):
            return message
        }
    }
}

public struct WebDAVRootConfig: Codable, Equatable, Sendable {
    public var rootPath: String
    public var davRootPath: String
    public var name: String
    public var address: String
    public var username: String
    public var password: String

    public init(
        rootPath: String,
        davRootPath: String? = nil,
        name: String,
        address: String,
        username: String,
        password: String
    ) {
        self.rootPath = rootPath
        self.davRootPath = davRootPath ?? rootPath
        self.name = name
        self.address = WebDAVAddress.decodedDisplayAddress(address)
        self.username = username
        self.password = password
    }

    public init(
        name: String,
        address: String,
        username: String,
        password: String
    ) {
        let canonical = URL.fromMediaPath(address).mediaPath
        self.rootPath = canonical
        self.davRootPath = canonical
        self.name = name
        self.address = WebDAVAddress.decodedDisplayAddress(address)
        self.username = username
        self.password = password
    }

    public var rootURL: URL {
        URL.fromMediaPath(rootPath)
    }

    public var basicAuthorizationValue: String? {
        guard !username.isEmpty || !password.isEmpty else { return nil }
        let raw = "\(username):\(password)"
        guard let data = raw.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }

    public var ffmpegHTTPHeaders: String? {
        WebDAVClient.ffmpegHTTPHeaders(includingAuthorizationFrom: self)
    }

    public func scopedConfig(for folderURL: URL) -> WebDAVRootConfig {
        let canonicalFolder = folderURL.standardizedMediaURL.mediaPath
        let canonicalRoot = URL.fromMediaPath(rootPath).mediaPath
        let canonicalDAVRoot = URL.fromMediaPath(davRootPath).mediaPath
        let scopedDAVRoot: String
        if canonicalDAVRoot == canonicalRoot {
            scopedDAVRoot = canonicalFolder
        } else if canonicalFolder == canonicalRoot {
            scopedDAVRoot = canonicalDAVRoot
        } else if canonicalFolder.hasPrefix(canonicalRoot + "/") {
            let suffix = String(canonicalFolder.dropFirst(canonicalRoot.count))
            scopedDAVRoot = canonicalDAVRoot + suffix
        } else {
            scopedDAVRoot = canonicalFolder
        }

        let resolvedURL = URL.fromMediaPath(canonicalFolder)
        return WebDAVRootConfig(
            rootPath: canonicalFolder,
            davRootPath: scopedDAVRoot,
            name: WebDAVAddress.defaultDisplayName(for: resolvedURL),
            address: WebDAVAddress.decodedDisplayAddress(canonicalFolder),
            username: username,
            password: password
        )
    }
}

public enum WebDAVBrowserItemKind: String, Codable, Equatable, Sendable {
    case folder
    case video
    case subtitle
}

public struct WebDAVBrowserItem: Identifiable, Equatable, Sendable {
    public let url: URL
    public let name: String
    public let kind: WebDAVBrowserItemKind

    public var id: String {
        url.mediaPath
    }

    public init(url: URL, name: String, kind: WebDAVBrowserItemKind) {
        self.url = url.standardizedMediaURL
        self.name = name
        self.kind = kind
    }
}

public struct WebDAVRemoteFile: Equatable, Sendable {
    public let url: URL
    public let fileSize: Int64
    public let modifiedAt: Date

    public init(url: URL, fileSize: Int64, modifiedAt: Date) {
        self.url = url
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
    }
}

public struct WebDAVPlayableInput: Equatable, Sendable {
    public let url: String
    public let httpHeaders: String?

    public var inputPath: String {
        url
    }

    public init(url: String, httpHeaders: String?) {
        self.url = url
        self.httpHeaders = httpHeaders
    }
}

extension String {
    public var isWebDAVPath: Bool {
        let lower = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://")
    }

    public var isSMBPath: Bool {
        let lower = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.hasPrefix("smb://")
    }

    public var isRemoteMediaPath: Bool {
        isWebDAVPath || isSMBPath
    }
}

extension URL {
    public var isWebDAVURL: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    public var isSMBURL: Bool {
        scheme?.lowercased() == "smb"
    }

    public var isRemoteMediaURL: Bool {
        isWebDAVURL || isSMBURL
    }

    public var mediaPath: String {
        if isWebDAVURL || isSMBURL {
            guard let scheme = scheme?.lowercased(),
                  let host = host, !host.isEmpty else {
                return absoluteString
            }
            let portSegment: String
            if isSMBURL {
                if let port, port != SMBAddress.defaultPort {
                    portSegment = ":\(port)"
                } else {
                    portSegment = ""
                }
            } else {
                portSegment = port.map { ":\($0)" } ?? ""
            }
            var decodedPath = WebDAVAddress.decodedDisplayAddress(path)
            if decodedPath.isEmpty {
                decodedPath = "/"
            } else if !decodedPath.hasPrefix("/") {
                decodedPath = "/" + decodedPath
            }
            while decodedPath.count > 1 && decodedPath.hasSuffix("/") {
                decodedPath.removeLast()
            }
            if decodedPath == "/" {
                return "\(scheme)://\(host)\(portSegment)"
            }
            return "\(scheme)://\(host)\(portSegment)\(decodedPath)"
        }

        var normalized = standardizedFileURL.path
        while normalized.count > 1 && normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    public var standardizedMediaURL: URL {
        if isWebDAVURL || isSMBURL {
            return URL.fromMediaPath(mediaPath)
        }
        return standardizedFileURL
    }

    public static func fromMediaPath(_ rawPath: String) -> URL {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isSMBPath {
            if let parsed = SMBAddress.parseURL(from: trimmed) {
                return parsed
            }
            return URL(string: trimmed) ?? URL(fileURLWithPath: rawPath)
        }
        guard trimmed.isWebDAVPath else {
            return URL(fileURLWithPath: rawPath).standardizedFileURL
        }
        if let parsed = WebDAVAddress.parseURL(from: trimmed) {
            return parsed
        }
        return URL(string: trimmed) ?? URL(fileURLWithPath: rawPath)
    }
}

public enum WebDAVAddress {
    public static func decodedDisplayAddress(_ rawAddress: String) -> String {
        var result = rawAddress
        for _ in 0..<2 where containsPercentEncodingPattern(result) {
            guard let decoded = result.removingPercentEncoding, decoded != result else {
                break
            }
            result = decoded
        }
        return result.precomposedStringWithCanonicalMapping
    }

    public static func parseURL(from rawAddress: String) -> URL? {
        let trimmed = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let schemeRange = trimmed.range(of: "://") else {
            return nil
        }
        let scheme = String(trimmed[..<schemeRange.lowerBound]).lowercased()
        guard scheme == "http" || scheme == "https" else {
            return nil
        }

        let afterScheme = trimmed[schemeRange.upperBound...]
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

        let hostPart: String
        var portValue: Int?
        if authority.hasPrefix("[") {
            // IPv6 host
            guard let closeBracket = authority.firstIndex(of: "]") else { return nil }
            let nextIndex = authority.index(after: closeBracket)
            hostPart = String(authority[ authority.index(after: authority.startIndex)..<closeBracket ])
            if nextIndex < authority.endIndex {
                let remainder = authority[nextIndex...]
                guard remainder.hasPrefix(":"),
                      let parsedPort = Int(remainder.dropFirst()) else {
                    return nil
                }
                portValue = parsedPort
            }
        } else if let colonIndex = authority.lastIndex(of: ":") {
            hostPart = String(authority[..<colonIndex])
            let portString = authority[authority.index(after: colonIndex)...]
            guard let parsedPort = Int(portString) else { return nil }
            portValue = parsedPort
        } else {
            hostPart = String(authority)
        }

        guard !hostPart.isEmpty else { return nil }

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
        components.scheme = scheme
        components.host = hostPart
        components.port = portValue
        components.path = normalizedPath == "/" ? "" : normalizedPath
        return components.url
    }

    public static func defaultDisplayName(for url: URL) -> String {
        let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let lastSegment = trimmedPath.split(separator: "/").last, !lastSegment.isEmpty {
            let raw = String(lastSegment)
            return raw.removingPercentEncoding ?? raw
        }
        if let host = url.host, !host.isEmpty {
            return host
        }
        return url.mediaPath
    }

    private static func containsPercentEncodingPattern(_ value: String) -> Bool {
        let utf8 = Array(value.utf8)
        guard utf8.count >= 3 else { return false }
        for index in 0..<(utf8.count - 2) where utf8[index] == UInt8(ascii: "%") {
            if isHexDigit(utf8[index + 1]) && isHexDigit(utf8[index + 2]) {
                return true
            }
        }
        return false
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
            || (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "f"))
            || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "F"))
    }
}

public final class WebDAVConfigurationStore: @unchecked Sendable {
    public static let shared = WebDAVConfigurationStore()

    private static let defaultsKey = "webdavRootConfigs"
    private static let legacyMigrationKey = "webdavRootConfigsLegacyMigrationCompleted"
    private static let legacyDomainNames = [
        ApplicationInfo.bundleIdentifier,
        ApplicationInfo.name
    ]
    private let lock = NSLock()
    private let userDefaults: UserDefaults
    private var configsByRootPath: [String: WebDAVRootConfig]

    public init(
        userDefaults: UserDefaults? = nil,
        legacyDomains: [[String: Any]]? = nil
    ) {
        let resolvedDefaults = userDefaults
            ?? UserDefaults(suiteName: ApplicationInfo.preferencesSuiteIdentifier)
            ?? .standard
        self.userDefaults = resolvedDefaults
        let resolvedLegacyDomains = legacyDomains ?? (
            userDefaults == nil
                ? Self.legacyDomainNames.map {
                    UserDefaults.standard.persistentDomain(forName: $0) ?? [:]
                }
                : []
        )
        self.configsByRootPath = Self.loadConfigs(
            from: resolvedDefaults,
            legacyDomains: resolvedLegacyDomains
        )
    }

    public func save(_ config: WebDAVRootConfig) {
        upsert(config)
    }

    public func upsert(_ config: WebDAVRootConfig) {
        let canonicalKey = URL.fromMediaPath(config.rootPath).mediaPath
        var normalized = config
        normalized.rootPath = canonicalKey
        normalized.davRootPath = URL.fromMediaPath(config.davRootPath).mediaPath
        normalized.address = WebDAVAddress.decodedDisplayAddress(config.address)
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

    public func config(for url: URL) -> WebDAVRootConfig? {
        config(forRootPath: url.mediaPath)
    }

    public func config(forRootPath rootPath: String) -> WebDAVRootConfig? {
        let canonicalKey = URL.fromMediaPath(rootPath).mediaPath
        lock.lock()
        defer { lock.unlock() }
        return configsByRootPath[canonicalKey]
    }

    public func httpHeaders(forMediaPath mediaPath: String) -> String? {
        matchingConfig(forMediaPath: mediaPath)?.ffmpegHTTPHeaders
    }

    public func matchingConfig(forMediaPath mediaPath: String) -> WebDAVRootConfig? {
        guard mediaPath.isWebDAVPath else { return nil }
        let canonical = URL.fromMediaPath(mediaPath).mediaPath
        lock.lock()
        let allConfigs = Array(configsByRootPath.values)
        lock.unlock()

        return allConfigs
            .filter { config in
                canonical == config.rootPath || canonical.hasPrefix(config.rootPath + "/")
            }
            .max(by: { $0.rootPath.count < $1.rootPath.count })
    }

    public func allConfigs() -> [WebDAVRootConfig] {
        lock.lock()
        defer { lock.unlock() }
        return Array(configsByRootPath.values)
    }

    public func rewriteFolderPathPrefix(from oldPath: String, to newPath: String) {
        guard oldPath.isWebDAVPath, newPath.isWebDAVPath else { return }
        let canonicalOld = URL.fromMediaPath(oldPath).mediaPath
        let canonicalNew = URL.fromMediaPath(newPath).mediaPath
        let newLeafName = LibraryRenamer.lastPathComponent(of: canonicalNew)

        lock.lock()
        var updatedConfigs: [String: WebDAVRootConfig] = [:]
        var changed = false
        for (_, var config) in configsByRootPath {
            if config.rootPath == canonicalOld {
                config.rootPath = canonicalNew
                config.davRootPath = LibraryRenamer.replacingLastPathComponent(
                    of: config.davRootPath,
                    with: newLeafName
                )
                config.address = WebDAVAddress.decodedDisplayAddress(canonicalNew)
                config.name = newLeafName
                updatedConfigs[canonicalNew] = config
                changed = true
            } else if config.rootPath.hasPrefix(canonicalOld + "/") {
                let suffix = String(config.rootPath.dropFirst(canonicalOld.count))
                let rewrittenRoot = canonicalNew + suffix
                if config.davRootPath.hasSuffix(suffix) {
                    let davOldPrefix = String(config.davRootPath.dropLast(suffix.count))
                    let rewrittenDAVPrefix = LibraryRenamer.replacingLastPathComponent(
                        of: davOldPrefix,
                        with: newLeafName
                    )
                    config.davRootPath = rewrittenDAVPrefix + suffix
                } else {
                    config.davRootPath = rewrittenRoot
                }
                config.rootPath = rewrittenRoot
                config.address = WebDAVAddress.decodedDisplayAddress(rewrittenRoot)
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

    private func persist(_ configs: [WebDAVRootConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        userDefaults.set(data, forKey: Self.defaultsKey)
    }

    private static func loadConfigs(
        from userDefaults: UserDefaults,
        legacyDomains: [[String: Any]] = []
    ) -> [String: WebDAVRootConfig] {
        var result = decodeConfigs(from: userDefaults.data(forKey: defaultsKey))

        if !legacyDomains.isEmpty && !userDefaults.bool(forKey: legacyMigrationKey) {
            var didMergeLegacy = false
            for domain in legacyDomains {
                guard let legacyData = domain[defaultsKey] as? Data else {
                    continue
                }
                let legacyConfigs = decodeConfigs(from: legacyData)
                for (key, config) in legacyConfigs where result[key] == nil {
                    result[key] = config
                    didMergeLegacy = true
                }
            }
            if didMergeLegacy,
               let encoded = try? JSONEncoder().encode(Array(result.values)) {
                userDefaults.set(encoded, forKey: defaultsKey)
            }
            userDefaults.set(true, forKey: legacyMigrationKey)
        }

        return result
    }

    private static func decodeConfigs(from data: Data?) -> [String: WebDAVRootConfig] {
        guard let data,
              let decoded = try? JSONDecoder().decode([WebDAVRootConfig].self, from: data) else {
            return [:]
        }
        var result: [String: WebDAVRootConfig] = [:]
        for var config in decoded {
            let key = URL.fromMediaPath(config.rootPath).mediaPath
            config.rootPath = key
            config.davRootPath = URL.fromMediaPath(config.davRootPath).mediaPath
            config.address = WebDAVAddress.decodedDisplayAddress(config.address)
            result[key] = config
        }
        return result
    }
}

public final class WebDAVSubtitleCache: @unchecked Sendable {
    public static let shared = WebDAVSubtitleCache()

    private let lock = NSLock()
    private let fileManager: FileManager
    private var cacheDirectoryURL: URL

    public init(
        cacheDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let cacheDirectoryURL {
            self.cacheDirectoryURL = cacheDirectoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.cacheDirectoryURL = appSupport
                .appendingPathComponent("CueSeeker", isDirectory: true)
                .appendingPathComponent("WebDAVSubtitleCache", isDirectory: true)
        }
    }

    public func setCacheDirectoryURLForTesting(_ directoryURL: URL) {
        lock.lock()
        cacheDirectoryURL = directoryURL
        lock.unlock()
    }

    public func cachedFileURL(for remoteURL: URL) -> URL {
        let canonical = remoteURL.mediaPath
        let digest = SHA256.hash(data: Data(canonical.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let ext = remoteURL.pathExtension.lowercased()
        let filename = ext.isEmpty ? hex : "\(hex).\(ext)"
        lock.lock()
        let dir = cacheDirectoryURL
        lock.unlock()
        return dir.appendingPathComponent(filename, isDirectory: false)
    }

    public func storeSubtitleData(_ data: Data, for remoteURL: URL) throws -> URL {
        let destination = cachedFileURL(for: remoteURL)
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    public func readSubtitleData(
        from url: URL,
        client: WebDAVClient = .shared,
        smbClient: SMBClient = .shared
    ) throws -> Data {
        guard url.isWebDAVURL || url.isSMBURL else {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        }

        let localFile = cachedFileURL(for: url)
        if fileManager.fileExists(atPath: localFile.path),
           let cached = try? Data(contentsOf: localFile, options: .mappedIfSafe) {
            return cached
        }

        let downloaded = url.isSMBURL
            ? try smbClient.downloadData(from: url)
            : try client.downloadData(from: url)
        _ = try? storeSubtitleData(downloaded, for: url)
        return downloaded
    }

    public func loadData(for url: URL) -> Data? {
        try? readSubtitleData(from: url)
    }

    public func moveCachedSubtitle(from oldRemoteURL: URL, to newRemoteURL: URL) {
        let source = cachedFileURL(for: oldRemoteURL)
        let destination = cachedFileURL(for: newRemoteURL)
        guard source != destination, fileManager.fileExists(atPath: source.path) else {
            return
        }
        try? fileManager.removeItem(at: destination)
        try? fileManager.moveItem(at: source, to: destination)
    }

    public func removeCachedSubtitle(for remoteURL: URL) {
        let localFile = cachedFileURL(for: remoteURL)
        try? fileManager.removeItem(at: localFile)
    }

    public func removeCachedSubtitles(forRootURL _: URL) {
        // Individual subtitle files are hashed by URL; keep directory clean when requested if needed.
    }
}

public final class WebDAVClient: @unchecked Sendable {
    public typealias HTTPHandler = @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    public static let defaultUserAgent = "pan.baidu.com"
    public static let shared = WebDAVClient()

    public static func ffmpegHTTPHeaders(includingAuthorizationFrom config: WebDAVRootConfig?) -> String {
        var lines: [String] = []
        if let auth = config?.basicAuthorizationValue {
            lines.append("Authorization: \(auth)")
        }
        lines.append("User-Agent: \(defaultUserAgent)")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private struct ResolvedCacheEntry {
        let input: WebDAVPlayableInput
        let expiresAt: Date
    }

    private let configurationStore: WebDAVConfigurationStore
    private let lock = NSLock()
    private var customHTTPHandler: HTTPHandler?
    private var resolvedPlayableCache: [String: ResolvedCacheEntry] = [:]
    private let resolvedCacheTTL: TimeInterval = 60

    public init(
        configurationStore: WebDAVConfigurationStore = .shared,
        customHTTPHandler: HTTPHandler? = nil
    ) {
        self.configurationStore = configurationStore
        self.customHTTPHandler = customHTTPHandler
    }

    public func setCustomHTTPHandlerForTesting(_ handler: HTTPHandler?) {
        lock.lock()
        customHTTPHandler = handler
        resolvedPlayableCache.removeAll()
        lock.unlock()
    }

    public func clearResolvedPlayableCache() {
        lock.lock()
        resolvedPlayableCache.removeAll()
        lock.unlock()
    }

    public func validateDirectory(
        name: String,
        address: String,
        username: String,
        password: String
    ) async throws -> WebDAVRootConfig {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            throw WebDAVError.invalidInput("Address is required.")
        }
        guard let rootURL = WebDAVAddress.parseURL(from: trimmedAddress) else {
            throw WebDAVError.invalidAddress
        }

        try Task.checkCancellation()

        let effectiveName = trimmedName.isEmpty
            ? WebDAVAddress.defaultDisplayName(for: rootURL)
            : trimmedName
        let rootMediaPath = rootURL.mediaPath
        let initialConfig = WebDAVRootConfig(
            rootPath: rootMediaPath,
            davRootPath: rootMediaPath,
            name: effectiveName,
            address: trimmedAddress,
            username: trimmedUsername,
            password: password
        )

        return try await Task.detached(priority: .userInitiated) { [self] in
            try Task.checkCancellation()
            do {
                try self.verifyPropfindCollection(at: rootURL, config: initialConfig)
                return initialConfig
            } catch let firstError as WebDAVError {
                try Task.checkCancellation()
                if case .authenticationFailed = firstError {
                    throw firstError
                }
                if let davFallbackURL = Self.alistDAVFallbackURL(for: rootURL) {
                    var fallbackConfig = initialConfig
                    fallbackConfig.davRootPath = davFallbackURL.mediaPath
                    if (try? self.verifyPropfindCollection(at: davFallbackURL, config: fallbackConfig)) != nil {
                        return fallbackConfig
                    }
                }
                throw firstError
            }
        }.value
    }

    public func connectAndBrowseDirectory(
        address: String,
        username: String,
        password: String
    ) async throws -> (config: WebDAVRootConfig, items: [WebDAVBrowserItem]) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else {
            throw WebDAVError.invalidInput("Address is required.")
        }
        guard let rootURL = WebDAVAddress.parseURL(from: trimmedAddress) else {
            throw WebDAVError.invalidAddress
        }

        try Task.checkCancellation()

        let effectiveName = WebDAVAddress.defaultDisplayName(for: rootURL)
        let rootMediaPath = rootURL.mediaPath
        let initialConfig = WebDAVRootConfig(
            rootPath: rootMediaPath,
            davRootPath: rootMediaPath,
            name: effectiveName,
            address: trimmedAddress,
            username: trimmedUsername,
            password: password
        )

        return try await Task.detached(priority: .userInitiated) { [self] in
            try Task.checkCancellation()
            do {
                let items = try self.listBrowserItems(at: rootURL, config: initialConfig)
                return (initialConfig, items)
            } catch let firstError as WebDAVError {
                try Task.checkCancellation()
                if case .authenticationFailed = firstError {
                    throw firstError
                }
                if let davFallbackURL = Self.alistDAVFallbackURL(for: rootURL) {
                    var fallbackConfig = initialConfig
                    fallbackConfig.davRootPath = davFallbackURL.mediaPath
                    if let items = try? self.listBrowserItems(at: rootURL, config: fallbackConfig) {
                        return (fallbackConfig, items)
                    }
                }
                throw firstError
            }
        }.value
    }

    public func browseDirectory(
        at folderURL: URL,
        baseConfig: WebDAVRootConfig
    ) async throws -> [WebDAVBrowserItem] {
        let normalizedURL = folderURL.standardizedMediaURL
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) { [self] in
            try Task.checkCancellation()
            return try self.listBrowserItems(at: normalizedURL, config: baseConfig)
        }.value
    }

    public func scanDirectoryTree(rootURL: URL) throws -> [WebDAVRemoteFile] {
        let rootMediaPath = rootURL.mediaPath
        let config = configurationStore.matchingConfig(forMediaPath: rootMediaPath)
            ?? WebDAVRootConfig(
                rootPath: rootMediaPath,
                davRootPath: rootMediaPath,
                name: rootURL.lastPathComponent,
                address: rootMediaPath,
                username: "",
                password: ""
            )

        let effectiveRootURL = effectiveDAVURL(for: rootURL, config: config)
        var results: [WebDAVRemoteFile] = []
        var visitedDirectories: Set<String> = []
        try scanDirectoryRecursive(
            davDirectoryURL: effectiveRootURL,
            effectiveRootMediaPath: effectiveRootURL.mediaPath,
            logicalRootMediaPath: rootMediaPath,
            config: config,
            visitedDirectories: &visitedDirectories,
            results: &results
        )
        return results.sorted { $0.url.mediaPath < $1.url.mediaPath }
    }

    public func downloadData(from url: URL) throws -> Data {
        guard url.isWebDAVURL else {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        }
        let config = configurationStore.matchingConfig(forMediaPath: url.mediaPath)
        let requestURL = config.map { effectiveDAVURL(for: url, config: $0) } ?? url
        let resolved = try resolvePlayableInput(for: url, requestURL: requestURL, config: config)
        guard let targetURL = URL(string: resolved.url) ?? WebDAVAddress.parseURL(from: resolved.url) else {
            throw WebDAVError.invalidAddress
        }

        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        if let headers = resolved.httpHeaders {
            for rawLine in headers.components(separatedBy: "\r\n") {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, let colon = line.firstIndex(of: ":") else { continue }
                let field = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if !field.isEmpty && !value.isEmpty {
                    request.setValue(value, forHTTPHeaderField: field)
                }
            }
        }

        let (data, response) = try performHTTPRequest(request, followRedirectsWithConfig: config)
        guard (200...299).contains(response.statusCode) else {
            throw mapHTTPError(statusCode: response.statusCode)
        }
        return data
    }

    public func resolvePlayableInput(for url: URL) -> WebDAVPlayableInput {
        if url.isSMBURL {
            return SMBClient.shared.resolvePlayableInput(for: url)
        }
        guard url.isWebDAVURL else {
            return WebDAVPlayableInput(url: url.path, httpHeaders: nil)
        }
        let config = configurationStore.matchingConfig(forMediaPath: url.mediaPath)
        let requestURL = config.map { effectiveDAVURL(for: url, config: $0) } ?? url
        if let resolved = try? resolvePlayableInput(for: url, requestURL: requestURL, config: config) {
            return resolved
        }
        return WebDAVPlayableInput(
            url: requestURL.absoluteString,
            httpHeaders: Self.ffmpegHTTPHeaders(includingAuthorizationFrom: config)
        )
    }

    public func directoryExists(
        at directoryPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) throws -> Bool {
        let endpoint = resolveDAVEndpoint(for: directoryPath, peerPathInSameDirectory: peerPath)
        do {
            let entries = try propfind(at: endpoint.davURL, depth: "0", config: endpoint.config)
            return entries.first?.isCollection == true
        } catch WebDAVError.directoryNotFound {
            return false
        }
    }

    public func fileExists(
        at filePath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) throws -> Bool {
        let endpoint = resolveDAVEndpoint(for: filePath, peerPathInSameDirectory: peerPath)
        do {
            let entries = try propfind(
                at: endpoint.davURL,
                depth: "0",
                config: endpoint.config,
                addsTrailingSlash: false
            )
            guard let first = entries.first else { return false }
            return !first.isCollection
        } catch WebDAVError.directoryNotFound {
            return false
        }
    }

    public func resourceExists(
        at targetPath: String,
        peerPathInSameDirectory peerPath: String? = nil,
        addsTrailingSlash: Bool = false
    ) throws -> Bool {
        let endpoint = resolveDAVEndpoint(for: targetPath, peerPathInSameDirectory: peerPath)
        do {
            let entries = try propfind(
                at: endpoint.davURL,
                depth: "0",
                config: endpoint.config,
                addsTrailingSlash: addsTrailingSlash
            )
            return !entries.isEmpty
        } catch WebDAVError.directoryNotFound {
            return false
        }
    }

    public func listDirectoryItems(at directoryPath: String) throws -> [String: Bool] {
        let endpoint = resolveDAVEndpoint(for: directoryPath)
        return try listDirectoryItems(atDAVURL: endpoint.davURL, config: endpoint.config)
    }

    public func listDirectoryItemsInParent(of childPath: String) throws -> [String: Bool]? {
        let childEndpoint = resolveDAVEndpoint(for: childPath)
        let childDAVMediaPath = childEndpoint.davURL.mediaPath
        let parentDAVMediaPath = LibraryRenamer.parentPath(of: childDAVMediaPath)
        guard parentDAVMediaPath != childDAVMediaPath else {
            return nil
        }
        return try listDirectoryItems(
            atDAVURL: URL.fromMediaPath(parentDAVMediaPath),
            config: childEndpoint.config
        )
    }

    public func moveItem(
        fromPath: String,
        toPath: String,
        isDirectory: Bool
    ) throws {
        let source = resolveDAVEndpoint(for: fromPath, peerPathInSameDirectory: toPath)
        let destination = resolveDAVEndpoint(for: toPath, peerPathInSameDirectory: fromPath)
        let config = source.config

        let requestURL = isDirectory
            ? ensureTrailingSlash(forDirectoryURL: source.davURL)
            : source.davURL
        let destinationURL = isDirectory
            ? ensureTrailingSlash(forDirectoryURL: destination.davURL)
            : destination.davURL

        var request = URLRequest(url: requestURL)
        request.httpMethod = "MOVE"
        request.timeoutInterval = 30
        request.setValue(destinationURL.absoluteString, forHTTPHeaderField: "Destination")
        let oldLeaf = LibraryRenamer.lastPathComponent(of: fromPath).precomposedStringWithCanonicalMapping
        let newLeaf = LibraryRenamer.lastPathComponent(of: toPath).precomposedStringWithCanonicalMapping
        let isCaseOrNormalizationRename = oldLeaf.caseInsensitiveCompare(newLeaf) == .orderedSame
        request.setValue(isCaseOrNormalizationRename ? "T" : "F", forHTTPHeaderField: "Overwrite")
        if let auth = config.basicAuthorizationValue {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try performHTTPRequest(request, followRedirectsWithConfig: config)
        let status = response.statusCode
        guard (200...299).contains(status), status != 207 else {
            throw mapHTTPError(statusCode: status)
        }
    }

    // MARK: - Internal Helpers

    private func resolveDAVEndpoint(
        for targetPath: String,
        peerPathInSameDirectory peerPath: String? = nil
    ) -> (davURL: URL, config: WebDAVRootConfig) {
        let targetURL = URL.fromMediaPath(targetPath)
        if let config = configurationStore.matchingConfig(forMediaPath: targetPath) {
            return (effectiveDAVURL(for: targetURL, config: config), config)
        }
        if let peerPath,
           let config = configurationStore.matchingConfig(forMediaPath: peerPath) {
            let peerDAVURL = effectiveDAVURL(for: URL.fromMediaPath(peerPath), config: config)
            let targetLeaf = LibraryRenamer.lastPathComponent(of: targetPath)
            let targetDAVMediaPath = LibraryRenamer.replacingLastPathComponent(
                of: peerDAVURL.mediaPath,
                with: targetLeaf
            )
            return (URL.fromMediaPath(targetDAVMediaPath), config)
        }
        let fallbackPath = targetURL.mediaPath
        let fallbackConfig = WebDAVRootConfig(
            rootPath: fallbackPath,
            davRootPath: fallbackPath,
            name: targetURL.lastPathComponent,
            address: fallbackPath,
            username: "",
            password: ""
        )
        return (targetURL, fallbackConfig)
    }

    private func listDirectoryItems(
        atDAVURL davDirectoryURL: URL,
        config: WebDAVRootConfig
    ) throws -> [String: Bool] {
        let entries = try propfind(at: davDirectoryURL, depth: "1", config: config)
        let baseComponents = URLComponents(url: davDirectoryURL, resolvingAgainstBaseURL: false)
        let expectedSelfPath = normalizeDAVPath(davDirectoryURL.path)
        var items: [String: Bool] = [:]
        for entry in entries {
            guard let resolvedDAVURL = resolveHref(
                entry.href,
                against: davDirectoryURL,
                baseComponents: baseComponents
            ) else {
                continue
            }
            let entryPath = normalizeDAVPath(resolvedDAVURL.path)
            if entryPath == expectedSelfPath {
                continue
            }
            let name = resolvedDAVURL.lastPathComponent.precomposedStringWithCanonicalMapping
            guard !name.isEmpty else {
                continue
            }
            items[name] = entry.isCollection
        }
        return items
    }

    private func resolvePlayableInput(
        for logicalURL: URL,
        requestURL: URL,
        config: WebDAVRootConfig?
    ) throws -> WebDAVPlayableInput {
        let startTime = CFAbsoluteTimeGetCurrent()
        let cacheKey = logicalURL.mediaPath
        let now = Date()
        lock.lock()
        if let cached = resolvedPlayableCache[cacheKey], cached.expiresAt > now {
            lock.unlock()
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            NSLog("[PlaybackPerf] S1_resolve302 cached=1 elapsed=%.1fms targetHost=%@", elapsedMs, URL(string: cached.input.url)?.host ?? "unknown")
            return cached.input
        }
        let hasCustomHandler = customHTTPHandler != nil
        lock.unlock()

        let defaultInput = WebDAVPlayableInput(
            url: requestURL.absoluteString,
            httpHeaders: Self.ffmpegHTTPHeaders(includingAuthorizationFrom: config)
        )

        var currentURL = requestURL
        var includeAuth = true
        let maxRedirects = 5

        for hop in 0..<maxRedirects {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 15
            request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            request.setValue(Self.defaultUserAgent, forHTTPHeaderField: "User-Agent")
            if includeAuth, let auth = config?.basicAuthorizationValue {
                request.setValue(auth, forHTTPHeaderField: "Authorization")
            }

            let response: HTTPURLResponse
            do {
                (_, response) = try performSingleHopRequest(request)
            } catch {
                let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                NSLog("[PlaybackPerf] S1_resolve302 cached=0 hop=%d error=%@ elapsed=%.1fms", hop, error.localizedDescription, elapsedMs)
                if hasCustomHandler {
                    throw error
                }
                return defaultInput
            }

            let status = response.statusCode
            if (300...399).contains(status),
               let location = response.value(forHTTPHeaderField: "Location"),
               let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL {
                let sameOrigin = Self.isSameOrigin(currentURL, nextURL)
                if !sameOrigin {
                    let resolved = WebDAVPlayableInput(
                        url: nextURL.absoluteString,
                        httpHeaders: Self.ffmpegHTTPHeaders(includingAuthorizationFrom: nil)
                    )
                    cacheResolvedInput(resolved, forKey: cacheKey)
                    let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    NSLog("[PlaybackPerf] S1_resolve302 cached=0 status=%d crossOrigin=1 elapsed=%.1fms targetHost=%@", status, elapsedMs, nextURL.host ?? "unknown")
                    return resolved
                }
                currentURL = nextURL
                includeAuth = sameOrigin
                continue
            }

            if status == 401 || status == 403 {
                throw WebDAVError.authenticationFailed
            }

            let resolved = WebDAVPlayableInput(
                url: currentURL.absoluteString,
                httpHeaders: Self.ffmpegHTTPHeaders(includingAuthorizationFrom: includeAuth ? config : nil)
            )
            cacheResolvedInput(resolved, forKey: cacheKey)
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            NSLog("[PlaybackPerf] S1_resolve302 cached=0 status=%d crossOrigin=0 elapsed=%.1fms targetHost=%@", status, elapsedMs, currentURL.host ?? "unknown")
            return resolved
        }

        return defaultInput
    }

    private func cacheResolvedInput(_ input: WebDAVPlayableInput, forKey key: String) {
        lock.lock()
        resolvedPlayableCache[key] = ResolvedCacheEntry(
            input: input,
            expiresAt: Date().addingTimeInterval(resolvedCacheTTL)
        )
        lock.unlock()
    }

    private func verifyPropfindCollection(at url: URL, config: WebDAVRootConfig) throws {
        let items = try propfind(at: url, depth: "0", config: config)
        guard let rootItem = items.first else {
            throw WebDAVError.invalidResponse
        }
        guard rootItem.isCollection else {
            throw WebDAVError.notADirectory
        }
    }

    private func listBrowserItems(
        at logicalDirectoryURL: URL,
        config: WebDAVRootConfig
    ) throws -> [WebDAVBrowserItem] {
        let davDirectoryURL = effectiveDAVURL(for: logicalDirectoryURL, config: config)
        let entries = try propfind(at: davDirectoryURL, depth: "1", config: config)
        let baseComponents = URLComponents(url: davDirectoryURL, resolvingAgainstBaseURL: false)
        let expectedSelfPath = normalizeDAVPath(davDirectoryURL.path)
        let fallbackSelfPath = Self.alistDAVFallbackURL(for: davDirectoryURL).map { normalizeDAVPath($0.path) }
        let effectiveRootMediaPath = URL.fromMediaPath(config.davRootPath).mediaPath
        let logicalRootMediaPath = URL.fromMediaPath(config.rootPath).mediaPath

        var sawSelfCollection = false
        var sawFallbackSelfCollection = false
        var foldersByPath: [String: WebDAVBrowserItem] = [:]
        var filesByPath: [String: WebDAVBrowserItem] = [:]

        for entry in entries {
            try Task.checkCancellation()
            guard let resolvedDAVURL = resolveHref(
                entry.href,
                against: davDirectoryURL,
                baseComponents: baseComponents
            ) else {
                continue
            }
            let entryPath = normalizeDAVPath(resolvedDAVURL.path)
            if entryPath == expectedSelfPath {
                guard entry.isCollection else {
                    throw WebDAVError.notADirectory
                }
                sawSelfCollection = true
                continue
            }
            if let fallbackSelfPath, entryPath == fallbackSelfPath {
                sawFallbackSelfCollection = true
            }

            let requiredPrefix = expectedSelfPath == "/" ? "/" : expectedSelfPath + "/"
            guard entryPath.hasPrefix(requiredPrefix) else {
                continue
            }
            let relativeRemainder = String(entryPath.dropFirst(requiredPrefix.count))
            guard !relativeRemainder.isEmpty, !relativeRemainder.contains("/") else {
                continue
            }

            let rawName = resolvedDAVURL.lastPathComponent
            let name = (rawName.removingPercentEncoding ?? rawName).precomposedStringWithCanonicalMapping
            if name.isEmpty || name.hasPrefix(".") {
                continue
            }

            let logicalURL = mapDAVURLToLogicalURL(
                resolvedDAVURL,
                effectiveRootMediaPath: effectiveRootMediaPath,
                logicalRootMediaPath: logicalRootMediaPath
            )

            if entry.isCollection {
                let item = WebDAVBrowserItem(url: logicalURL, name: name, kind: .folder)
                foldersByPath[item.id] = item
            } else {
                let ext = resolvedDAVURL.pathExtension.lowercased()
                if VideoMatcher.defaultVideoExtensions.contains(ext) {
                    let item = WebDAVBrowserItem(url: logicalURL, name: name, kind: .video)
                    filesByPath[item.id] = item
                } else if SubtitleFileScanner.supportedSubtitleExtensions.contains(ext) {
                    let item = WebDAVBrowserItem(url: logicalURL, name: name, kind: .subtitle)
                    filesByPath[item.id] = item
                }
            }
        }

        if !sawSelfCollection {
            if sawFallbackSelfCollection {
                throw WebDAVError.directoryNotFound
            }
            if entries.count == 1, entries[0].isCollection == false {
                throw WebDAVError.notADirectory
            }
        }

        let sortedFolders = foldersByPath.values.sorted {
            let cmp = $0.name.localizedStandardCompare($1.name)
            if cmp != .orderedSame {
                return cmp == .orderedAscending
            }
            return $0.id < $1.id
        }
        let sortedFiles = filesByPath.values.sorted {
            let cmp = $0.name.localizedStandardCompare($1.name)
            if cmp != .orderedSame {
                return cmp == .orderedAscending
            }
            return $0.id < $1.id
        }
        return sortedFolders + sortedFiles
    }

    private func scanDirectoryRecursive(
        davDirectoryURL: URL,
        effectiveRootMediaPath: String,
        logicalRootMediaPath: String,
        config: WebDAVRootConfig,
        visitedDirectories: inout Set<String>,
        results: inout [WebDAVRemoteFile]
    ) throws {
        try Task.checkCancellation()
        let dirMediaPath = davDirectoryURL.mediaPath
        guard visitedDirectories.insert(dirMediaPath).inserted else {
            return
        }

        let entries = try propfind(at: davDirectoryURL, depth: "1", config: config)
        let baseComponents = URLComponents(url: davDirectoryURL, resolvingAgainstBaseURL: false)
        let expectedSelfPath = normalizeDAVPath(davDirectoryURL.path)

        for entry in entries {
            try Task.checkCancellation()
            guard let resolvedDAVURL = resolveHref(entry.href, against: davDirectoryURL, baseComponents: baseComponents) else {
                continue
            }
            let entryPath = normalizeDAVPath(resolvedDAVURL.path)
            if entryPath == expectedSelfPath {
                continue
            }

            let name = resolvedDAVURL.lastPathComponent
            if name.isEmpty || name.hasPrefix(".") {
                continue
            }

            if entry.isCollection {
                try scanDirectoryRecursive(
                    davDirectoryURL: resolvedDAVURL,
                    effectiveRootMediaPath: effectiveRootMediaPath,
                    logicalRootMediaPath: logicalRootMediaPath,
                    config: config,
                    visitedDirectories: &visitedDirectories,
                    results: &results
                )
            } else {
                let logicalURL = mapDAVURLToLogicalURL(
                    resolvedDAVURL,
                    effectiveRootMediaPath: effectiveRootMediaPath,
                    logicalRootMediaPath: logicalRootMediaPath
                )
                results.append(
                    WebDAVRemoteFile(
                        url: logicalURL,
                        fileSize: entry.contentLength ?? 0,
                        modifiedAt: entry.lastModified ?? Date(timeIntervalSince1970: 0)
                    )
                )
            }
        }
    }

    private func propfind(
        at url: URL,
        depth: String,
        config: WebDAVRootConfig,
        addsTrailingSlash: Bool = true
    ) throws -> [WebDAVPropfindEntry] {
        let targetURL = addsTrailingSlash ? ensureTrailingSlash(forDirectoryURL: url) : url
        var request = URLRequest(url: targetURL)
        request.httpMethod = "PROPFIND"
        request.timeoutInterval = 15
        request.setValue(depth, forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let auth = config.basicAuthorizationValue {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        let body = """
        <?xml version="1.0" encoding="utf-8" ?>
        <D:propfind xmlns:D="DAV:">
          <D:prop>
            <D:resourcetype/>
            <D:getcontentlength/>
            <D:getlastmodified/>
          </D:prop>
        </D:propfind>
        """
        request.httpBody = Data(body.utf8)

        let (data, response) = try performHTTPRequest(request, followRedirectsWithConfig: config)
        let status = response.statusCode
        if status == 401 || status == 403 {
            throw WebDAVError.authenticationFailed
        }
        if status == 404 {
            throw WebDAVError.directoryNotFound
        }
        guard status == 207 || (200...299).contains(status) else {
            throw mapHTTPError(statusCode: status)
        }

        let entries = WebDAVPropfindXMLParser.parse(data: data)
        guard !entries.isEmpty else {
            throw WebDAVError.invalidResponse
        }
        return entries
    }

    private func effectiveDAVURL(for logicalURL: URL, config: WebDAVRootConfig) -> URL {
        let logicalMediaPath = logicalURL.mediaPath
        guard config.davRootPath != config.rootPath else {
            return logicalURL
        }
        if logicalMediaPath == config.rootPath {
            return URL.fromMediaPath(config.davRootPath)
        }
        if logicalMediaPath.hasPrefix(config.rootPath + "/") {
            let suffix = String(logicalMediaPath.dropFirst(config.rootPath.count))
            return URL.fromMediaPath(config.davRootPath + suffix)
        }
        return logicalURL
    }

    private func mapDAVURLToLogicalURL(
        _ davURL: URL,
        effectiveRootMediaPath: String,
        logicalRootMediaPath: String
    ) -> URL {
        let davMediaPath = davURL.mediaPath
        guard effectiveRootMediaPath != logicalRootMediaPath else {
            return davURL.standardizedMediaURL
        }
        if davMediaPath == effectiveRootMediaPath {
            return URL.fromMediaPath(logicalRootMediaPath)
        }
        if davMediaPath.hasPrefix(effectiveRootMediaPath + "/") {
            let suffix = String(davMediaPath.dropFirst(effectiveRootMediaPath.count))
            return URL.fromMediaPath(logicalRootMediaPath + suffix)
        }
        return davURL.standardizedMediaURL
    }

    private static func alistDAVFallbackURL(for url: URL) -> URL? {
        let path = url.path
        if path == "/dav" || path.hasPrefix("/dav/") {
            return nil
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let normalizedSuffix = path.hasPrefix("/") ? path : "/" + path
        components?.path = "/dav" + (normalizedSuffix == "/" ? "" : normalizedSuffix)
        return components?.url
    }

    private func ensureTrailingSlash(forDirectoryURL url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        if components.path.isEmpty {
            components.path = "/"
        } else if !components.path.hasSuffix("/") {
            components.path += "/"
        }
        return components.url ?? url
    }

    private func normalizeDAVPath(_ path: String) -> String {
        var decoded = (path.removingPercentEncoding ?? path).precomposedStringWithCanonicalMapping
        if decoded.isEmpty {
            decoded = "/"
        }
        while decoded.count > 1 && decoded.hasSuffix("/") {
            decoded.removeLast()
        }
        return decoded
    }

    private func resolveHref(
        _ href: String,
        against baseURL: URL,
        baseComponents: URLComponents?
    ) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.isWebDAVPath {
            return WebDAVAddress.parseURL(from: trimmed)
        }
        guard var components = baseComponents else {
            return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
        }
        let decodedPath = (trimmed.removingPercentEncoding ?? trimmed).precomposedStringWithCanonicalMapping
        components.path = decodedPath.hasPrefix("/") ? decodedPath : "/" + decodedPath
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func performHTTPRequest(
        _ initialRequest: URLRequest,
        followRedirectsWithConfig config: WebDAVRootConfig?
    ) throws -> (Data, HTTPURLResponse) {
        var currentRequest = initialRequest
        var includeAuth = true
        let maxRedirects = 5

        for _ in 0..<maxRedirects {
            let (data, response) = try performSingleHopRequest(currentRequest)
            let status = response.statusCode
            if (300...399).contains(status),
               let currentURL = currentRequest.url,
               let location = response.value(forHTTPHeaderField: "Location"),
               let nextURL = URL(string: location, relativeTo: currentURL)?.absoluteURL {
                let sameOrigin = Self.isSameOrigin(currentURL, nextURL)
                var nextRequest = currentRequest
                nextRequest.url = nextURL
                if status == 301 || status == 302 || status == 303 {
                    if currentRequest.httpMethod != "GET"
                        && currentRequest.httpMethod != "HEAD"
                        && currentRequest.httpMethod != "PROPFIND"
                        && currentRequest.httpMethod != "MOVE" {
                        nextRequest.httpMethod = "GET"
                        nextRequest.httpBody = nil
                    }
                }
                includeAuth = includeAuth && sameOrigin
                if includeAuth, let auth = config?.basicAuthorizationValue {
                    nextRequest.setValue(auth, forHTTPHeaderField: "Authorization")
                } else {
                    nextRequest.setValue(nil, forHTTPHeaderField: "Authorization")
                }
                currentRequest = nextRequest
                continue
            }
            return (data, response)
        }

        throw WebDAVError.invalidResponse
    }

    private func performSingleHopRequest(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        var preparedRequest = request
        if preparedRequest.value(forHTTPHeaderField: "User-Agent") == nil {
            preparedRequest.setValue(Self.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        }

        lock.lock()
        let handler = customHTTPHandler
        lock.unlock()

        if let handler {
            return try handler(preparedRequest)
        }

        let delegate = NoRedirectSessionDelegate()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = preparedRequest.timeoutInterval
        config.timeoutIntervalForResource = max(preparedRequest.timeoutInterval, 30)
        config.httpAdditionalHeaders = ["User-Agent": Self.defaultUserAgent]
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let box = SynchronousHTTPBox()
        let task = session.dataTask(with: preparedRequest) { data, response, error in
            box.complete(data: data, response: response, error: error)
        }
        task.resume()
        return try box.wait()
    }

    private func mapHTTPError(statusCode: Int) -> WebDAVError {
        switch statusCode {
        case 401, 403:
            return .authenticationFailed
        case 404:
            return .directoryNotFound
        default:
            return .httpError(statusCode: statusCode)
        }
    }

    private static func isSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && effectivePort(for: lhs) == effectivePort(for: rhs)
    }

    private static func effectivePort(for url: URL) -> Int {
        if let port = url.port { return port }
        return url.scheme?.lowercased() == "https" ? 443 : 80
    }
}

private final class NoRedirectSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private final class SynchronousHTTPBox: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private var data: Data?
    private var response: URLResponse?
    private var error: Error?

    func complete(data: Data?, response: URLResponse?, error: Error?) {
        self.data = data
        self.response = response
        self.error = error
        semaphore.signal()
    }

    func wait() throws -> (Data, HTTPURLResponse) {
        semaphore.wait()
        if let error {
            throw WebDAVError.networkError(error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        return (data ?? Data(), httpResponse)
    }
}

struct WebDAVPropfindEntry: Equatable {
    var href: String = ""
    var isCollection: Bool = false
    var contentLength: Int64?
    var lastModified: Date?
}

private final class WebDAVPropfindXMLParser: NSObject, XMLParserDelegate {
    private var entries: [WebDAVPropfindEntry] = []
    private var currentEntry: WebDAVPropfindEntry?
    private var currentPropstatIsCollection = false
    private var currentPropstatContentLength: Int64?
    private var currentPropstatLastModified: Date?
    private var currentPropstatStatus: String = ""
    private var elementStack: [String] = []
    private var textBuffer: String = ""

    static func parse(data: Data) -> [WebDAVPropfindEntry] {
        guard !data.isEmpty else { return [] }
        let delegate = WebDAVPropfindXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else { return [] }
        return delegate.entries
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let local = Self.localName(of: elementName)
        elementStack.append(local)
        textBuffer = ""

        switch local {
        case "response":
            currentEntry = WebDAVPropfindEntry()
        case "propstat":
            currentPropstatIsCollection = false
            currentPropstatContentLength = nil
            currentPropstatLastModified = nil
            currentPropstatStatus = ""
        case "collection":
            if elementStack.contains("resourcetype") {
                if elementStack.contains("propstat") {
                    currentPropstatIsCollection = true
                } else {
                    currentEntry?.isCollection = true
                }
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let local = Self.localName(of: elementName)
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch local {
        case "href":
            if currentEntry?.href.isEmpty == true {
                currentEntry?.href = trimmed
            }
        case "getcontentlength":
            if let length = Int64(trimmed) {
                if elementStack.contains("propstat") {
                    currentPropstatContentLength = length
                } else {
                    currentEntry?.contentLength = length
                }
            }
        case "getlastmodified":
            if let date = Self.parseHTTPDate(trimmed) {
                if elementStack.contains("propstat") {
                    currentPropstatLastModified = date
                } else {
                    currentEntry?.lastModified = date
                }
            }
        case "status":
            if elementStack.contains("propstat") {
                currentPropstatStatus = trimmed
            }
        case "propstat":
            let isSuccess = currentPropstatStatus.isEmpty || currentPropstatStatus.contains(" 200 ")
            if isSuccess {
                if currentPropstatIsCollection {
                    currentEntry?.isCollection = true
                }
                if let length = currentPropstatContentLength {
                    currentEntry?.contentLength = length
                }
                if let modified = currentPropstatLastModified {
                    currentEntry?.lastModified = modified
                }
            }
        case "response":
            if let entry = currentEntry, !entry.href.isEmpty {
                entries.append(entry)
            }
            currentEntry = nil
        default:
            break
        }

        textBuffer = ""
        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
    }

    private static func localName(of name: String) -> String {
        if let colon = name.lastIndex(of: ":") {
            return String(name[name.index(after: colon)...]).lowercased()
        }
        return name.lowercased()
    }

    private static let httpDateFormatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEEE, dd-MMM-yy HH:mm:ss zzz",
            "EEE MMM d HH:mm:ss yyyy"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()

    private static func parseHTTPDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        for formatter in httpDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: value)
    }
}
