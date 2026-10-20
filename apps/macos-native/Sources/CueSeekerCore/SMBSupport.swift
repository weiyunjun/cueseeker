import CSMBClient
import Darwin
import Foundation
import dnssd

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

public struct SMBRootConfig: RemoteRootConfigurable, Codable, Equatable, Sendable {
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

    public typealias HostKind = RemoteAddressParser.HostKind

    public static func decodedDisplayAddress(_ rawAddress: String) -> String {
        RemoteAddressParser.decodedDisplayAddress(rawAddress)
    }

    public static func decodedHost(for url: URL) -> String? {
        RemoteAddressParser.decodedHost(for: url)
    }

    public static func isIPv4Address(_ rawHost: String) -> Bool {
        RemoteAddressParser.isIPv4Address(rawHost)
    }

    public static func isIPv6Address(_ rawHost: String) -> Bool {
        RemoteAddressParser.isIPv6Address(rawHost)
    }

    public static func classifyHost(_ rawHost: String) -> HostKind {
        RemoteAddressParser.classifyHost(rawHost)
    }

    public static func parsePort(_ rawPort: String) -> Int? {
        RemoteAddressParser.parsePort(rawPort)
    }

    public static func parseURL(from rawAddress: String, portOverride: Int? = nil) -> URL? {
        RemoteAddressParser.parseURL(
            from: rawAddress,
            scheme: "smb",
            defaultPort: defaultPort,
            portOverride: portOverride
        )
    }

    public static func effectivePort(for url: URL, fallbackConfig: SMBRootConfig? = nil) -> Int {
        RemoteAddressParser.effectivePort(
            for: url,
            defaultPort: defaultPort,
            fallbackPort: fallbackConfig?.port
        )
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
        RemoteAddressParser.defaultDisplayName(for: url)
    }
}

public final class SMBHostResolver: @unchecked Sendable {
    public static let shared = SMBHostResolver()

    private struct CacheEntry {
        let ipAddress: String
        let resolvedAt: Date
    }

    private let lock = NSLock()
    private var cacheByHost: [String: CacheEntry] = [:]
    private var customResolver: (@Sendable (String) -> String?)?
    private let cacheTTL: TimeInterval = 300

    public init() {}

    public func setCustomResolverForTesting(_ resolver: (@Sendable (String) -> String?)?) {
        lock.lock()
        customResolver = resolver
        cacheByHost.removeAll()
        lock.unlock()
    }

    public func invalidateCachedHost(_ host: String) {
        let key = Self.cacheKey(for: host)
        lock.lock()
        cacheByHost.removeValue(forKey: key)
        lock.unlock()
    }

    public func resolveConnectionHost(_ rawHost: String, allowCache: Bool = true) throws -> String {
        switch SMBAddress.classifyHost(rawHost) {
        case .ipv4(let ipv4):
            return ipv4
        case .ipv6(let ipv6):
            return ipv6
        case .friendlyName(let friendlyName):
            guard !friendlyName.isEmpty else {
                throw SMBError.invalidAddress
            }
            let key = Self.cacheKey(for: friendlyName)
            let overrideResolver: (@Sendable (String) -> String?)?
            lock.lock()
            overrideResolver = customResolver
            if allowCache,
               let cached = cacheByHost[key],
               Date().timeIntervalSince(cached.resolvedAt) < cacheTTL {
                let ip = cached.ipAddress
                lock.unlock()
                return ip
            }
            lock.unlock()

            let resolvedIP: String?
            if let overrideResolver {
                resolvedIP = overrideResolver(friendlyName)
            } else {
                resolvedIP = Self.resolveFriendlyNameToIPAddress(friendlyName)
            }

            guard let ip = resolvedIP, !ip.isEmpty else {
                throw SMBError.networkError("Could not resolve SMB host \"\(friendlyName)\".")
            }

            lock.lock()
            cacheByHost[key] = CacheEntry(ipAddress: ip, resolvedAt: Date())
            lock.unlock()
            return ip
        }
    }

    private static func cacheKey(for host: String) -> String {
        host.precomposedStringWithCanonicalMapping.lowercased()
    }

    private static func resolveFriendlyNameToIPAddress(_ friendlyName: String) -> String? {
        let normalized = friendlyName.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let isLocalhost = normalized.caseInsensitiveCompare("localhost") == .orderedSame

        // 1. Direct DNS / system resolver lookup (handles FQDNs, localhost, and explicit .local names)
        if !normalized.contains(" "),
           let directIP = lookupAddrInfo(hostname: normalized, preferLoopback: isLocalhost) {
            return directIP
        }

        // 2. Bonjour multicast DNS (.local) lookup
        let lower = normalized.lowercased()
        if !lower.hasSuffix(".local") {
            if !normalized.contains(" "),
               let localIP = lookupAddrInfo(hostname: "\(normalized).local", preferLoopback: false) {
                return localIP
            }
            let sanitized = sanitizeBonjourHostLabel(normalized)
            if !sanitized.isEmpty,
               sanitized.caseInsensitiveCompare(normalized) != .orderedSame,
               let sanitizedIP = lookupAddrInfo(hostname: "\(sanitized).local", preferLoopback: false) {
                return sanitizedIP
            }
        }

        // 3. Bonjour _smb._tcp. service discovery in "local."
        let serviceQueryName = lower.hasSuffix(".local")
            ? String(normalized.dropLast(".local".count))
            : normalized
        if let bonjourIP = resolveViaBonjourSMBService(serviceName: serviceQueryName) {
            return bonjourIP
        }

        // 4. NetBIOS lookup fallback via /usr/bin/smbutil lookup
        if let netbiosIP = resolveViaSMBUtilLookup(name: serviceQueryName) {
            return netbiosIP
        }

        return nil
    }

    private static func sanitizeBonjourHostLabel(_ raw: String) -> String {
        var result = raw
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: " ", with: "-")
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    }

    private static func lookupAddrInfo(hostname: String, preferLoopback: Bool) -> String? {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM

        var res: UnsafeMutablePointer<addrinfo>?
        let rc = getaddrinfo(hostname, nil, &hints, &res)
        guard rc == 0, let first = res else {
            return nil
        }
        defer { freeaddrinfo(first) }

        var nonLoopbackIPv4: [String] = []
        var loopbackIPv4: [String] = []
        var nonLoopbackIPv6: [String] = []
        var loopbackIPv6: [String] = []

        var current: UnsafeMutablePointer<addrinfo>? = first
        while let info = current {
            if info.pointee.ai_family == AF_INET, let addr = info.pointee.ai_addr {
                var sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                if inet_ntop(AF_INET, &sin.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil {
                    let ip = String(cString: buf)
                    if ip.hasPrefix("127.") {
                        if !loopbackIPv4.contains(ip) { loopbackIPv4.append(ip) }
                    } else {
                        if !nonLoopbackIPv4.contains(ip) { nonLoopbackIPv4.append(ip) }
                    }
                }
            } else if info.pointee.ai_family == AF_INET6, let addr = info.pointee.ai_addr {
                var sin6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                if inet_ntop(AF_INET6, &sin6.sin6_addr, &buf, socklen_t(INET6_ADDRSTRLEN)) != nil {
                    let ip = String(cString: buf)
                    if ip == "::1" {
                        if !loopbackIPv6.contains(ip) { loopbackIPv6.append(ip) }
                    } else if !ip.lowercased().hasPrefix("fe80:") {
                        if !nonLoopbackIPv6.contains(ip) { nonLoopbackIPv6.append(ip) }
                    }
                }
            }
            current = info.pointee.ai_next
        }

        if preferLoopback {
            return loopbackIPv4.first
                ?? nonLoopbackIPv4.first
                ?? loopbackIPv6.first
                ?? nonLoopbackIPv6.first
        }
        return nonLoopbackIPv4.first
            ?? loopbackIPv4.first
            ?? nonLoopbackIPv6.first
            ?? loopbackIPv6.first
    }

    private final class BonjourResolveBox {
        var targetHosts: [String] = []
    }

    private final class BonjourBrowseBox {
        var services: [(name: String, regtype: String, domain: String, interfaceIndex: UInt32)] = []
    }

    private static func resolveViaBonjourSMBService(serviceName: String) -> String? {
        let directTargets = resolveBonjourServiceTargetHosts(
            name: serviceName,
            regtype: "_smb._tcp.",
            domain: "local.",
            interfaceIndex: 0,
            timeoutSeconds: 0.45
        )
        for target in directTargets {
            if let ip = lookupAddrInfo(hostname: target, preferLoopback: false) {
                return ip
            }
        }

        let discovered = browseBonjourSMBServices(timeoutSeconds: 0.45)
        let normalizedTarget = serviceName.precomposedStringWithCanonicalMapping.lowercased()
        let sanitizedTarget = sanitizeBonjourHostLabel(serviceName).lowercased()

        for service in discovered {
            let candidate = service.name.precomposedStringWithCanonicalMapping.lowercased()
            let sanitizedCandidate = sanitizeBonjourHostLabel(service.name).lowercased()
            if candidate == normalizedTarget
                || (!sanitizedTarget.isEmpty && sanitizedCandidate == sanitizedTarget) {
                let targets = resolveBonjourServiceTargetHosts(
                    name: service.name,
                    regtype: service.regtype,
                    domain: service.domain,
                    interfaceIndex: service.interfaceIndex,
                    timeoutSeconds: 0.45
                )
                for target in targets {
                    if let ip = lookupAddrInfo(hostname: target, preferLoopback: false) {
                        return ip
                    }
                }
            }
        }

        return nil
    }

    private static func resolveBonjourServiceTargetHosts(
        name: String,
        regtype: String,
        domain: String,
        interfaceIndex: UInt32,
        timeoutSeconds: TimeInterval
    ) -> [String] {
        let box = BonjourResolveBox()
        var sdRef: DNSServiceRef?
        let callback: DNSServiceResolveReply = { _, _, _, errorCode, _, hosttarget, _, _, _, context in
            guard errorCode == kDNSServiceErr_NoError,
                  let context,
                  let hosttarget else {
                return
            }
            let state = Unmanaged<BonjourResolveBox>.fromOpaque(context).takeUnretainedValue()
            var target = String(cString: hosttarget)
            while target.hasSuffix(".") {
                target.removeLast()
            }
            if !target.isEmpty && !state.targetHosts.contains(target) {
                state.targetHosts.append(target)
            }
        }

        let err = DNSServiceResolve(
            &sdRef,
            0,
            interfaceIndex,
            name,
            regtype,
            domain,
            callback,
            Unmanaged.passUnretained(box).toOpaque()
        )
        guard err == kDNSServiceErr_NoError, let activeRef = sdRef else {
            return []
        }
        defer { DNSServiceRefDeallocate(activeRef) }

        let fd = DNSServiceRefSockFD(activeRef)
        guard fd >= 0 else { return [] }
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline && box.targetHosts.isEmpty {
            let remainingMs = Int32(max(1, deadline.timeIntervalSinceNow * 1000))
            let rc = Darwin.poll(&pfd, 1, remainingMs)
            if rc > 0 && (pfd.revents & Int16(POLLIN)) != 0 {
                if DNSServiceProcessResult(activeRef) != kDNSServiceErr_NoError {
                    break
                }
            } else {
                break
            }
        }
        return box.targetHosts
    }

    private static func browseBonjourSMBServices(
        timeoutSeconds: TimeInterval
    ) -> [(name: String, regtype: String, domain: String, interfaceIndex: UInt32)] {
        let box = BonjourBrowseBox()
        var sdRef: DNSServiceRef?
        let callback: DNSServiceBrowseReply = { _, flags, interfaceIndex, errorCode, serviceName, regtype, replyDomain, context in
            guard errorCode == kDNSServiceErr_NoError,
                  let context,
                  let serviceName,
                  let regtype,
                  let replyDomain else {
                return
            }
            if (flags & UInt32(kDNSServiceFlagsAdd)) != 0 {
                let state = Unmanaged<BonjourBrowseBox>.fromOpaque(context).takeUnretainedValue()
                state.services.append((
                    name: String(cString: serviceName),
                    regtype: String(cString: regtype),
                    domain: String(cString: replyDomain),
                    interfaceIndex: interfaceIndex
                ))
            }
        }

        let err = DNSServiceBrowse(
            &sdRef,
            0,
            0,
            "_smb._tcp.",
            "local.",
            callback,
            Unmanaged.passUnretained(box).toOpaque()
        )
        guard err == kDNSServiceErr_NoError, let activeRef = sdRef else {
            return []
        }
        defer { DNSServiceRefDeallocate(activeRef) }

        let fd = DNSServiceRefSockFD(activeRef)
        guard fd >= 0 else { return [] }
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let remainingMs = Int32(max(1, deadline.timeIntervalSinceNow * 1000))
            let rc = Darwin.poll(&pfd, 1, remainingMs)
            if rc > 0 && (pfd.revents & Int16(POLLIN)) != 0 {
                if DNSServiceProcessResult(activeRef) != kDNSServiceErr_NoError {
                    break
                }
            } else {
                break
            }
        }
        return box.services
    }

    private static func resolveViaSMBUtilLookup(name: String) -> String? {
        let smbutilPath = "/usr/bin/smbutil"
        guard FileManager.default.isExecutableFile(atPath: smbutilPath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: smbutilPath)
        process.arguments = ["lookup", name]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            finished.signal()
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        if finished.wait(timeout: .now() + 1.5) == .timedOut {
            process.terminate()
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        for line in output.split(whereSeparator: \.isNewline) {
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == ":" })
            for token in tokens.reversed() {
                let candidate = String(token).trimmingCharacters(in: .whitespacesAndNewlines)
                if SMBAddress.isIPv4Address(candidate) {
                    return candidate
                }
            }
        }
        return nil
    }
}

public final class SMBConfigurationStore: @unchecked Sendable {
    public static let shared = SMBConfigurationStore()

    private let store: RemoteRootConfigStore<SMBRootConfig>

    public init(userDefaults: UserDefaults? = nil) {
        self.store = RemoteRootConfigStore(
            defaultsKey: "smbRootConfigs",
            defaultPort: SMBAddress.defaultPort,
            isSchemePath: { $0.isSMBPath },
            userDefaults: userDefaults
        )
    }

    public func save(_ config: SMBRootConfig) { store.save(config) }
    public func upsert(_ config: SMBRootConfig) { store.upsert(config) }
    public func remove(url: URL) { store.remove(url: url) }
    public func remove(forRootPath rootPath: String) { store.remove(forRootPath: rootPath) }
    public func config(for url: URL) -> SMBRootConfig? { store.config(for: url) }
    public func config(forRootPath rootPath: String) -> SMBRootConfig? { store.config(forRootPath: rootPath) }
    public func matchingConfig(forMediaPath mediaPath: String) -> SMBRootConfig? { store.matchingConfig(forMediaPath: mediaPath) }
    public func allConfigs() -> [SMBRootConfig] { store.allConfigs() }
    public func rewriteFolderPathPrefix(from oldPath: String, to newPath: String) {
        store.rewriteFolderPathPrefix(from: oldPath, to: newPath)
    }
}

public typealias SMBDirectoryEntry = RemoteDirectoryEntry

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

    func streamRange(
        host: String,
        port: Int,
        share: String,
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
        let isFriendlyHost: Bool
        if case .friendlyName = SMBAddress.classifyHost(host) {
            isFriendlyHost = true
        } else {
            isFriendlyHost = false
        }

        let resolvedHost = try SMBHostResolver.shared.resolveConnectionHost(host, allowCache: true)
        do {
            return try performListShares(
                resolvedHost: resolvedHost,
                port: port,
                username: username,
                password: password
            )
        } catch SMBError.networkError where isFriendlyHost {
            SMBHostResolver.shared.invalidateCachedHost(host)
            let refreshedHost = try SMBHostResolver.shared.resolveConnectionHost(host, allowCache: false)
            if refreshedHost != resolvedHost {
                return try performListShares(
                    resolvedHost: refreshedHost,
                    port: port,
                    username: username,
                    password: password
                )
            }
            throw SMBError.networkError("SMB connection failed.")
        }
    }

    private func performListShares(
        resolvedHost: String,
        port: Int,
        username: String,
        password: String
    ) throws -> [String] {
        var shareList = csmb_share_list_t(names: nil, count: 0)
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = resolvedHost.withCString { hostC in
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

    public func streamRange(
        host: String,
        port: Int,
        share: String,
        relativePath: String,
        offset: UInt64,
        maxLength: UInt64,
        username: String,
        password: String,
        writeChunk: (UnsafeRawPointer, Int) -> Bool
    ) throws {
        guard maxLength > 0 else { return }
        let session = try connectSession(
            host: host,
            port: port,
            share: share,
            username: username,
            password: password
        )
        defer { csmb_session_disconnect(session) }

        var fileHandle: OpaquePointer?
        var maxReadSize: UInt32 = 262144
        var errPtr: UnsafeMutablePointer<CChar>?
        let openCode = relativePath.withCString { relC in
            csmb_file_open(session, relC, &fileHandle, nil, &maxReadSize, &errPtr)
        }
        defer {
            if let errPtr { csmb_free_buffer(errPtr) }
        }
        guard openCode == CSMB_OK, let fileHandle else {
            throw Self.mapError(openCode, errPtr: errPtr)
        }
        defer { csmb_file_close(fileHandle) }

        let chunkCap = max(65536, min(Int(maxReadSize), 524288))
        var buffer = [UInt8](repeating: 0, count: chunkCap)
        var currentOffset = offset
        var remaining = maxLength

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
            if readCode != CSMB_OK {
                throw Self.mapError(readCode, errPtr: nil)
            }
            if bytesRead <= 0 {
                break
            }
            let wrote = buffer.withUnsafeBytes { rawBuf in
                writeChunk(rawBuf.baseAddress!, bytesRead)
            }
            if !wrote {
                break
            }
            currentOffset += UInt64(bytesRead)
            remaining -= UInt64(bytesRead)
        }
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
        let isFriendlyHost: Bool
        if case .friendlyName = SMBAddress.classifyHost(host) {
            isFriendlyHost = true
        } else {
            isFriendlyHost = false
        }

        let resolvedHost = try SMBHostResolver.shared.resolveConnectionHost(host, allowCache: true)
        do {
            return try performConnectSession(
                resolvedHost: resolvedHost,
                port: port,
                share: share,
                username: username,
                password: password
            )
        } catch let error as SMBError {
            if case .networkError = error, isFriendlyHost {
                SMBHostResolver.shared.invalidateCachedHost(host)
                let refreshedHost = try SMBHostResolver.shared.resolveConnectionHost(host, allowCache: false)
                if refreshedHost != resolvedHost {
                    return try performConnectSession(
                        resolvedHost: refreshedHost,
                        port: port,
                        share: share,
                        username: username,
                        password: password
                    )
                }
            }
            throw error
        }
    }

    private func performConnectSession(
        resolvedHost: String,
        port: Int,
        share: String,
        username: String,
        password: String
    ) throws -> OpaquePointer {
        var sessionPtr: OpaquePointer?
        var errPtr: UnsafeMutablePointer<CChar>?
        let code = resolvedHost.withCString { hostC in
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
        let port = endpoint.port

        if let nativeBackend = backend as? NativeCSMBBackend {
            let session = try nativeBackend.connectSession(
                host: endpoint.host,
                port: endpoint.port,
                share: share,
                username: endpoint.config.username,
                password: endpoint.config.password
            )
            defer { csmb_session_disconnect(session) }
            try RemoteDirectoryListingHelper.scanDirectoryRecursive(
                directoryURL: endpoint.url,
                relativePath: endpoint.relativePath,
                appendChild: { dirURL, name in
                    Self.appendingChildComponent(name, to: dirURL, port: port)
                },
                listEntries: { relPath in
                    try NativeCSMBBackend.listDirectory(on: session, relativePath: relPath)
                },
                cacheFileSize: { [weak self] size, path in
                    self?.cacheFileSize(size, forMediaPath: path)
                },
                visitedDirectories: &visitedDirectories,
                results: &results
            )
        } else {
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
                        share: share,
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

    public func streamRange(
        from url: URL,
        offset: UInt64,
        maxLength: UInt64,
        writeChunk: (UnsafeRawPointer, Int) -> Bool
    ) throws {
        let endpoint = resolveEndpoint(for: url.mediaPath)
        guard !endpoint.host.isEmpty,
              let share = endpoint.share,
              !share.isEmpty,
              !endpoint.relativePath.isEmpty else {
            throw SMBError.directoryNotFound
        }
        try activeBackend.streamRange(
            host: endpoint.host,
            port: endpoint.port,
            share: share,
            relativePath: endpoint.relativePath,
            offset: offset,
            maxLength: maxLength,
            username: endpoint.config.username,
            password: endpoint.config.password,
            writeChunk: writeChunk
        )
    }

    public func resolvePlayableInput(for url: URL) -> WebDAVPlayableInput {
        guard url.isSMBURL else {
            return WebDAVPlayableInput(url: url.path, httpHeaders: nil)
        }
        if let streamURL = RemoteMediaStreamServer.shared.registerAndResolveHTTPURL(
            for: url,
            routePrefix: "smb",
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
        let host = SMBAddress.decodedHost(for: targetURL) ?? ""
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
        guard let host = SMBAddress.decodedHost(for: directoryURL), !host.isEmpty else {
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
            return RemoteDirectoryListingHelper.sortBrowserItems(folders: Array(foldersByPath.values), files: [])
        }

        let entries = try backend.listDirectory(
            host: host,
            port: port,
            share: share!,
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
        return SMBAddress.parseURL(from: combined, portOverride: port) ?? directoryURL.appendingPathComponent(name)
    }
}
