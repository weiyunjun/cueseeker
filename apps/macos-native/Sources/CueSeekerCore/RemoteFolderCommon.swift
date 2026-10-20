import CSMBClient
import CryptoKit
import Darwin
import Foundation

// MARK: - Shared Address Parsing & Validation

public enum RemoteAddressParser {
    public enum HostKind: Equatable, Sendable {
        case ipv4(String)
        case ipv6(String)
        case friendlyName(String)
    }

    public static func decodedDisplayAddress(_ rawAddress: String) -> String {
        WebDAVAddress.decodedDisplayAddress(rawAddress)
    }

    public static func decodedHost(for url: URL) -> String? {
        guard let rawHost = url.host, !rawHost.isEmpty else {
            return nil
        }
        return decodedDisplayAddress(rawHost)
    }

    public static func isIPv4Address(_ rawHost: String) -> Bool {
        let trimmed = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        for part in parts {
            guard !part.isEmpty, part.count <= 3, part.allSatisfy({ $0 >= "0" && $0 <= "9" }) else {
                return false
            }
            if part.count > 1 && part.first == "0" {
                return false
            }
            guard let octet = Int(part), (0...255).contains(octet) else {
                return false
            }
        }
        var addr = in_addr()
        return trimmed.withCString { inet_pton(AF_INET, $0, &addr) == 1 }
    }

    public static func isIPv6Address(_ rawHost: String) -> Bool {
        var candidate = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.hasPrefix("[") && candidate.hasSuffix("]") && candidate.count > 2 {
            candidate.removeFirst()
            candidate.removeLast()
        }
        guard !candidate.isEmpty, candidate.contains(":") else { return false }
        let addressOnly: String
        if let percentIndex = candidate.firstIndex(of: "%") {
            let zone = candidate[candidate.index(after: percentIndex)...]
            guard !zone.isEmpty, !zone.contains("%"), !zone.contains("/") else {
                return false
            }
            addressOnly = String(candidate[..<percentIndex])
        } else {
            addressOnly = candidate
        }
        guard !addressOnly.isEmpty else { return false }
        var addr6 = in6_addr()
        return addressOnly.withCString { inet_pton(AF_INET6, $0, &addr6) == 1 }
    }

    public static func classifyHost(_ rawHost: String) -> HostKind {
        let trimmed = decodedDisplayAddress(rawHost).trimmingCharacters(in: .whitespacesAndNewlines)
        if isIPv4Address(trimmed) {
            return .ipv4(trimmed)
        }
        if isIPv6Address(trimmed) {
            var bare = trimmed
            if bare.hasPrefix("[") && bare.hasSuffix("]") && bare.count > 2 {
                bare.removeFirst()
                bare.removeLast()
            }
            return .ipv6(bare)
        }
        return .friendlyName(trimmed)
    }

    public static func parsePort(_ rawPort: String) -> Int? {
        let trimmed = rawPort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), (1...65535).contains(value) else {
            return nil
        }
        return value
    }

    public static func parseURL(
        from rawAddress: String,
        scheme: String,
        defaultPort: Int,
        portOverride: Int? = nil,
        allowCustomPort: Bool = true
    ) -> URL? {
        let decodedInput = decodedDisplayAddress(rawAddress)
        let trimmed = decodedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let prefix = "\(scheme)://"
        let withScheme: String
        if trimmed.hasPrefix(prefix) {
            withScheme = trimmed
        } else {
            withScheme = prefix + trimmed
        }

        let afterScheme = withScheme.dropFirst(prefix.count)
        guard !afterScheme.isEmpty,
              !afterScheme.hasPrefix("/"),
              !afterScheme.contains("://") else {
            return nil
        }

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

        var hostWithoutUser: Substring
        if let atIndex = authority.lastIndex(of: "@") {
            let userPart = authority[..<atIndex]
            guard !userPart.isEmpty else { return nil }
            hostWithoutUser = authority[authority.index(after: atIndex)...]
        } else {
            hostWithoutUser = authority
        }
        guard !hostWithoutUser.isEmpty else { return nil }

        if !allowCustomPort && hostWithoutUser.hasSuffix(":") && !isIPv6Address(String(hostWithoutUser)) {
            hostWithoutUser = hostWithoutUser.dropLast()
            guard !hostWithoutUser.isEmpty else { return nil }
        }

        let hostPart: String
        var isIPv6Host = false
        var portInAddress: Int?
        if hostWithoutUser.hasPrefix("[") {
            guard let closeBracket = hostWithoutUser.firstIndex(of: "]") else { return nil }
            let nextIndex = hostWithoutUser.index(after: closeBracket)
            let insideBrackets = String(
                hostWithoutUser[hostWithoutUser.index(after: hostWithoutUser.startIndex)..<closeBracket]
            )
            guard isIPv6Address(insideBrackets) else { return nil }
            hostPart = insideBrackets
            isIPv6Host = true
            if nextIndex < hostWithoutUser.endIndex {
                let remainder = hostWithoutUser[nextIndex...]
                guard remainder.hasPrefix(":"),
                      let parsedPort = Int(remainder.dropFirst()),
                      (1...65535).contains(parsedPort) else {
                    return nil
                }
                portInAddress = parsedPort
            }
        } else if isIPv6Address(String(hostWithoutUser)) {
            hostPart = String(hostWithoutUser)
            isIPv6Host = true
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
        guard !trimmedHost.isEmpty, trimmedHost == hostPart else { return nil }

        if !isIPv6Host {
            guard isValidNonIPv6Host(trimmedHost) else { return nil }
        }

        let effectivePort: Int
        if allowCustomPort {
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
        } else {
            effectivePort = defaultPort
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

        let hostComponent: String
        if isIPv6Host {
            let escapedZone = trimmedHost.replacingOccurrences(of: "%", with: "%25")
            hostComponent = "[\(escapedZone)]"
        } else {
            var allowed = CharacterSet.urlHostAllowed
            allowed.remove(charactersIn: ":[]/?#@")
            guard let encoded = trimmedHost.addingPercentEncoding(withAllowedCharacters: allowed) else {
                return nil
            }
            hostComponent = encoded
        }

        let portComponent = (!allowCustomPort || effectivePort == defaultPort) ? "" : ":\(effectivePort)"
        let pathComponent: String
        if normalizedPath.isEmpty || normalizedPath == "/" {
            pathComponent = ""
        } else {
            var allowedPathSegment = CharacterSet.urlPathAllowed
            allowedPathSegment.remove(charactersIn: "/?#")
            let encodedSegments = normalizedPath
                .split(separator: "/", omittingEmptySubsequences: true)
                .compactMap { segment in
                    String(segment).addingPercentEncoding(withAllowedCharacters: allowedPathSegment)
                }
            pathComponent = "/" + encodedSegments.joined(separator: "/")
        }

        return URL(string: "\(scheme)://\(hostComponent)\(portComponent)\(pathComponent)")
    }

    public static func effectivePort(for url: URL, defaultPort: Int, fallbackPort: Int?) -> Int {
        if let urlPort = url.port, (1...65535).contains(urlPort) {
            return urlPort
        }
        if let fallbackPort, (1...65535).contains(fallbackPort) {
            return fallbackPort
        }
        return defaultPort
    }

    public static func relativePath(for url: URL) -> String {
        let decodedPath = decodedDisplayAddress(url.path)
        return decodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .joined(separator: "/")
    }

    public static func defaultDisplayName(for url: URL) -> String {
        WebDAVAddress.defaultDisplayName(for: url)
    }

    public static func isValidNonIPv6Host(_ host: String) -> Bool {
        guard !host.isEmpty else { return false }
        let forbiddenCharacters = CharacterSet(charactersIn: ":/\\?#[]@").union(.controlCharacters).union(.newlines)
        if host.rangeOfCharacter(from: forbiddenCharacters) != nil {
            return false
        }
        if host.hasPrefix(".") || host.hasSuffix(".") || host.contains("..") {
            return false
        }
        let looksLikeNumericDottedAddress = host.contains(".")
            && host.allSatisfy { ($0 >= "0" && $0 <= "9") || $0 == "." }
        if looksLikeNumericDottedAddress {
            return isIPv4Address(host)
        }
        return true
    }
}

// MARK: - Shared Root Configuration Store

public protocol RemoteRootConfigurable: Codable, Equatable, Sendable {
    var rootPath: String { get set }
    var name: String { get set }
    var address: String { get set }
    var port: Int { get set }
}

public final class RemoteRootConfigStore<Config: RemoteRootConfigurable>: @unchecked Sendable {
    private let defaultsKey: String
    private let defaultPort: Int
    private let isSchemePath: @Sendable (String) -> Bool
    private let lock = NSLock()
    private let userDefaults: UserDefaults
    private var configsByRootPath: [String: Config]

    public init(
        defaultsKey: String,
        defaultPort: Int,
        isSchemePath: @escaping @Sendable (String) -> Bool,
        userDefaults: UserDefaults? = nil
    ) {
        self.defaultsKey = defaultsKey
        self.defaultPort = defaultPort
        self.isSchemePath = isSchemePath
        let resolvedDefaults = userDefaults
            ?? UserDefaults(suiteName: ApplicationInfo.preferencesSuiteIdentifier)
            ?? .standard
        self.userDefaults = resolvedDefaults
        self.configsByRootPath = Self.decodeConfigs(from: resolvedDefaults.data(forKey: defaultsKey))
    }

    public func save(_ config: Config) {
        upsert(config)
    }

    public func upsert(_ config: Config) {
        let canonicalKey = URL.fromMediaPath(config.rootPath).mediaPath
        var normalized = config
        normalized.rootPath = canonicalKey
        normalized.address = RemoteAddressParser.decodedDisplayAddress(config.address)
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

    public func config(for url: URL) -> Config? {
        config(forRootPath: url.mediaPath)
    }

    public func config(forRootPath rootPath: String) -> Config? {
        let canonicalKey = URL.fromMediaPath(rootPath).mediaPath
        lock.lock()
        defer { lock.unlock() }
        return configsByRootPath[canonicalKey]
    }

    public func matchingConfig(forMediaPath mediaPath: String) -> Config? {
        guard isSchemePath(mediaPath) else { return nil }
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

        guard let targetHost = RemoteAddressParser.decodedHost(for: targetURL)?.lowercased() else { return nil }
        let targetPort = targetURL.port ?? defaultPort
        return allConfigs.first { config in
            let configURL = URL.fromMediaPath(config.rootPath)
            return RemoteAddressParser.decodedHost(for: configURL)?.lowercased() == targetHost && config.port == targetPort
        }
    }

    public func allConfigs() -> [Config] {
        lock.lock()
        defer { lock.unlock() }
        return Array(configsByRootPath.values)
    }

    public func rewriteFolderPathPrefix(from oldPath: String, to newPath: String) {
        guard isSchemePath(oldPath), isSchemePath(newPath) else { return }
        let canonicalOld = URL.fromMediaPath(oldPath).mediaPath
        let canonicalNew = URL.fromMediaPath(newPath).mediaPath
        let newLeafName = LibraryRenamer.lastPathComponent(of: canonicalNew)

        lock.lock()
        var updatedConfigs: [String: Config] = [:]
        var changed = false
        for (_, var config) in configsByRootPath {
            if config.rootPath == canonicalOld {
                config.rootPath = canonicalNew
                config.address = RemoteAddressParser.decodedDisplayAddress(canonicalNew)
                config.name = newLeafName
                updatedConfigs[canonicalNew] = config
                changed = true
            } else if config.rootPath.hasPrefix(canonicalOld + "/") {
                let suffix = String(config.rootPath.dropFirst(canonicalOld.count))
                let rewrittenRoot = canonicalNew + suffix
                config.rootPath = rewrittenRoot
                config.address = RemoteAddressParser.decodedDisplayAddress(rewrittenRoot)
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

    private func persist(_ configs: [Config]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        userDefaults.set(data, forKey: defaultsKey)
    }

    private static func decodeConfigs(from data: Data?) -> [String: Config] {
        guard let data,
              let decoded = try? JSONDecoder().decode([Config].self, from: data) else {
            return [:]
        }
        var result: [String: Config] = [:]
        for var config in decoded {
            let key = URL.fromMediaPath(config.rootPath).mediaPath
            config.rootPath = key
            config.address = RemoteAddressParser.decodedDisplayAddress(config.address)
            result[key] = config
        }
        return result
    }
}

// MARK: - Shared Directory Scanning & Browser Item Building

public struct RemoteDirectoryEntry: Equatable, Sendable {
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

public enum RemoteDirectoryListingHelper {
    public static func sortBrowserItems(
        folders: [WebDAVBrowserItem],
        files: [WebDAVBrowserItem]
    ) -> [WebDAVBrowserItem] {
        let sortedFolders = folders.sorted {
            let cmp = $0.name.localizedStandardCompare($1.name)
            return cmp != .orderedSame ? (cmp == .orderedAscending) : ($0.id < $1.id)
        }
        let sortedFiles = files.sorted {
            let cmp = $0.name.localizedStandardCompare($1.name)
            return cmp != .orderedSame ? (cmp == .orderedAscending) : ($0.id < $1.id)
        }
        return sortedFolders + sortedFiles
    }

    public static func buildBrowserItems(
        entries: [RemoteDirectoryEntry],
        directoryURL: URL,
        appendChild: (URL, String) -> URL,
        cacheFileSize: (UInt64, String) -> Void
    ) throws -> [WebDAVBrowserItem] {
        var foldersByPath: [String: WebDAVBrowserItem] = [:]
        var filesByPath: [String: WebDAVBrowserItem] = [:]

        for entry in entries {
            try Task.checkCancellation()
            let name = entry.name.precomposedStringWithCanonicalMapping
            if name.isEmpty || name.hasPrefix(".") {
                continue
            }
            let childURL = appendChild(directoryURL, name)
            if entry.isDirectory {
                let item = WebDAVBrowserItem(url: childURL, name: name, kind: .folder)
                foldersByPath[item.id] = item
            } else {
                let ext = (name as NSString).pathExtension.lowercased()
                if VideoMatcher.defaultVideoExtensions.contains(ext) {
                    let item = WebDAVBrowserItem(url: childURL, name: name, kind: .video)
                    filesByPath[item.id] = item
                    if entry.fileSize > 0 {
                        cacheFileSize(UInt64(entry.fileSize), childURL.mediaPath)
                    }
                } else if SubtitleFileScanner.supportedSubtitleExtensions.contains(ext) {
                    let item = WebDAVBrowserItem(url: childURL, name: name, kind: .subtitle)
                    filesByPath[item.id] = item
                    if entry.fileSize > 0 {
                        cacheFileSize(UInt64(entry.fileSize), childURL.mediaPath)
                    }
                }
            }
        }

        return sortBrowserItems(
            folders: Array(foldersByPath.values),
            files: Array(filesByPath.values)
        )
    }

    public static func scanDirectoryRecursive(
        directoryURL: URL,
        relativePath: String,
        appendChild: (URL, String) -> URL,
        listEntries: (String) throws -> [RemoteDirectoryEntry],
        cacheFileSize: (UInt64, String) -> Void,
        visitedDirectories: inout Set<String>,
        results: inout [WebDAVRemoteFile]
    ) throws {
        try Task.checkCancellation()
        let dirMediaPath = directoryURL.mediaPath
        guard visitedDirectories.insert(dirMediaPath).inserted else {
            return
        }

        let entries = try listEntries(relativePath)
        for entry in entries {
            try Task.checkCancellation()
            let name = entry.name.precomposedStringWithCanonicalMapping
            if name.isEmpty || name.hasPrefix(".") {
                continue
            }
            let childURL = appendChild(directoryURL, name)
            let childRelPath = relativePath.isEmpty ? name : "\(relativePath)/\(name)"

            if entry.isDirectory {
                try scanDirectoryRecursive(
                    directoryURL: childURL,
                    relativePath: childRelPath,
                    appendChild: appendChild,
                    listEntries: listEntries,
                    cacheFileSize: cacheFileSize,
                    visitedDirectories: &visitedDirectories,
                    results: &results
                )
            } else {
                if entry.fileSize > 0 {
                    cacheFileSize(UInt64(entry.fileSize), childURL.mediaPath)
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
}

// MARK: - Shared Local HTTP Byte-Range Stream Proxy

final class RemoteMediaStreamServer: @unchecked Sendable {
    static let shared = RemoteMediaStreamServer()

    struct ResolvedByteRange {
        let start: UInt64
        let end: UInt64
        let length: UInt64
        let isPartial: Bool
    }

    struct StreamRegistration {
        let statFileSize: @Sendable () throws -> UInt64
        let streamRange: @Sendable (_ fd: Int32, _ rangeHeader: String?) -> Void
    }

    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var boundPort: UInt16 = 0
    private var registrationsByToken: [String: StreamRegistration] = [:]
    private let acceptQueue = DispatchQueue(label: "com.cueseeker.remote.stream.accept", qos: .userInitiated)
    private let connectionQueue = DispatchQueue(
        label: "com.cueseeker.remote.stream.connection",
        qos: .userInitiated,
        attributes: .concurrent
    )

    func registerAndResolveHTTPURL(
        for remoteURL: URL,
        routePrefix: String,
        registration: StreamRegistration
    ) -> String? {
        let canonical = remoteURL.mediaPath
        let digest = SHA256.hash(data: Data(canonical.utf8))
        let token = digest.prefix(16).map { String(format: "%02x", $0) }.joined()

        lock.lock()
        if listenFD < 0 {
            startListenerLocked()
        }
        let port = boundPort
        if port > 0 {
            registrationsByToken["\(routePrefix):\(token)"] = registration
        }
        lock.unlock()

        guard port > 0 else { return nil }
        let leaf = remoteURL.lastPathComponent.isEmpty ? "stream.bin" : remoteURL.lastPathComponent
        let encodedLeaf = leaf.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "stream.bin"
        return "http://127.0.0.1:\(port)/\(routePrefix)/\(token)/\(encodedLeaf)"
    }

    static func streamContinuousRange(
        fd: Int32,
        rangeHeader: String?,
        statFileSize: () throws -> UInt64,
        streamBody: (_ offset: UInt64, _ maxLength: UInt64, _ writeChunk: (UnsafeRawPointer, Int) -> Bool) throws -> Void
    ) {
        guard let totalSize = try? statFileSize() else {
            writeAll(to: fd, string: "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
            return
        }
        guard let range = resolveByteRange(rangeHeader: rangeHeader, totalSize: totalSize) else {
            writeRangeNotSatisfiable(to: fd, totalSize: totalSize)
            return
        }
        guard writeRangeSuccessHeader(to: fd, range: range, totalSize: totalSize), range.length > 0 else {
            return
        }
        try? streamBody(range.start, range.length) { baseAddress, count in
            guard count > 0 else { return true }
            return writeAll(to: fd, baseAddress: baseAddress, count: count)
        }
    }

    static func resolveByteRange(rangeHeader: String?, totalSize: UInt64) -> ResolvedByteRange? {
        guard let rangeHeader, rangeHeader.lowercased().hasPrefix("bytes=") else {
            let end = totalSize > 0 ? totalSize - 1 : 0
            return ResolvedByteRange(start: 0, end: end, length: totalSize, isPartial: false)
        }
        guard totalSize > 0 else { return nil }
        let spec = rangeHeader.dropFirst("bytes=".count).split(separator: ",").first ?? ""
        let parts = spec.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let startStr = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let endStr = String(parts[1]).trimmingCharacters(in: .whitespaces)

        if startStr.isEmpty {
            guard let suffixLen = UInt64(endStr), suffixLen > 0 else { return nil }
            let start = suffixLen >= totalSize ? 0 : (totalSize - suffixLen)
            let end = totalSize - 1
            return ResolvedByteRange(start: start, end: end, length: end - start + 1, isPartial: true)
        }

        guard let start = UInt64(startStr), start < totalSize else { return nil }
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

    @discardableResult
    static func writeRangeSuccessHeader(to fd: Int32, range: ResolvedByteRange, totalSize: UInt64) -> Bool {
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
        return writeAll(to: fd, string: headerLines.joined(separator: "\r\n"))
    }

    static func writeRangeNotSatisfiable(to fd: Int32, totalSize: UInt64) {
        let notSatisfiable = [
            "HTTP/1.1 416 Range Not Satisfiable",
            "Content-Range: bytes */\(totalSize)",
            "Connection: close",
            "\r\n"
        ].joined(separator: "\r\n")
        writeAll(to: fd, string: notSatisfiable)
    }

    @discardableResult
    static func writeAll(to fd: Int32, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return true }
            return writeAll(to: fd, baseAddress: base, count: rawBuf.count)
        }
    }

    static func writeAll(to fd: Int32, baseAddress: UnsafeRawPointer, count: Int) -> Bool {
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
        guard pathSegments.count >= 2 else {
            Self.writeAll(to: fd, string: "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
            return
        }
        let routePrefix = String(pathSegments[0])
        let token = String(pathSegments[1])

        lock.lock()
        let registration = registrationsByToken["\(routePrefix):\(token)"]
        lock.unlock()

        guard let registration else {
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
            guard let totalSize = try? registration.statFileSize() else {
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

        registration.streamRange(fd, rangeHeader)
    }

    private static func readHTTPHeader(from fd: Int32) -> String? {
        var accumulated = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        let delimiter = Data([13, 10, 13, 10])
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
}
