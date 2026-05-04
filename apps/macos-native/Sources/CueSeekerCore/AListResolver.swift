import Foundation

public enum AListResolverError: Error, Equatable, CustomStringConvertible {
    case invalidRootURL(String)
    case invalidAPIPath(String)
    case loginFailed(String)
    case resolveFailed(String)
    case emptyRawURL
    case invalidRawURL(String)

    public var description: String {
        switch self {
        case .invalidRootURL(let value):
            "Invalid AList root URL: \(value)"
        case .invalidAPIPath(let value):
            "Invalid AList API path: \(value)"
        case .loginFailed(let message):
            "AList login failed: \(message)"
        case .resolveFailed(let message):
            "AList media URL resolution failed: \(message)"
        case .emptyRawURL:
            "AList media URL resolution returned an empty raw_url."
        case .invalidRawURL(_):
            "AList media URL resolution returned an invalid raw_url."
        }
    }
}

public final class AListResolver: Sendable {
    private static let cache = AListResolverCache()
    private let session: URLSession

    public init(session: URLSession? = nil) {
        self.session = session ?? Self.defaultSession
    }

    public func validateRoot(source: RemoteMediaSourceConfiguration) async throws {
        let token = try await login(
            rootURL: source.rootURL,
            credentials: source.credentials
        )
        let apiPath = try Self.apiPath(
            webDAVRootPath: source.rootURL.path,
            sourceRelativePath: ""
        )
        let response: AListResponse<AListMetadataData> = try await postJSON(
            endpoint: try apiURL(rootURL: source.rootURL, path: "/api/fs/get"),
            headers: ["Authorization": token],
            body: AListGetRequest(
                path: apiPath,
                password: "",
                page: 1,
                perPage: 0,
                refresh: false
            )
        )

        guard response.code == 200, response.data != nil else {
            throw AListResolverError.resolveFailed(response.message)
        }
    }

    public func resolve(
        source: RemoteMediaSourceConfiguration,
        sourceRelativePath: String
    ) async throws -> ResolvedRemoteMedia {
        let linkCacheKey = Self.linkCacheKey(source: source, sourceRelativePath: sourceRelativePath)
        if let cachedLink = await Self.cache.resolvedLink(for: linkCacheKey) {
            return cachedLink
        }

        let token = try await login(
            rootURL: source.rootURL,
            credentials: source.credentials
        )
        let apiPath = try Self.apiPath(
            webDAVRootPath: source.rootURL.path,
            sourceRelativePath: sourceRelativePath
        )
        let response: AListResponse<AListFileData> = try await postJSON(
            endpoint: try apiURL(rootURL: source.rootURL, path: "/api/fs/get"),
            headers: ["Authorization": token],
            body: AListGetRequest(
                path: apiPath,
                password: "",
                page: 1,
                perPage: 0,
                refresh: false
            )
        )

        guard response.code == 200, let data = response.data else {
            throw AListResolverError.resolveFailed(response.message)
        }
        guard !data.rawURL.isEmpty else {
            throw AListResolverError.emptyRawURL
        }
        guard let url = URL(string: data.rawURL) else {
            throw AListResolverError.invalidRawURL(data.rawURL)
        }

        let resolved = ResolvedRemoteMedia(
            url: url,
            headers: data.parsedHeaders
        )
        await Self.cache.storeResolvedLink(
            resolved,
            for: linkCacheKey,
            expiresAt: Self.resolvedLinkExpiresAt(rawURL: url)
        )
        return resolved
    }

    public static func apiPath(
        webDAVRootPath: String,
        sourceRelativePath: String
    ) throws -> String {
        var mountPath = webDAVRootPath.removingPercentEncoding ?? webDAVRootPath
        while mountPath.count > 1 && mountPath.hasSuffix("/") {
            mountPath.removeLast()
        }
        if mountPath == "/dav" {
            mountPath = "/"
        } else if mountPath.hasPrefix("/dav/") {
            mountPath = String(mountPath.dropFirst("/dav".count))
        }
        if !mountPath.hasPrefix("/") {
            mountPath = "/" + mountPath
        }

        var relativePath = sourceRelativePath.removingPercentEncoding ?? sourceRelativePath
        if relativePath.isEmpty || relativePath == "/" {
            return mountPath
        }
        if !relativePath.hasPrefix("/") {
            relativePath = "/" + relativePath
        }

        let joined: String
        if mountPath == "/" {
            joined = relativePath
        } else {
            joined = mountPath + relativePath
        }

        guard joined.hasPrefix("/") else {
            throw AListResolverError.invalidAPIPath(joined)
        }
        return joined
    }

    private func login(
        rootURL: URL,
        credentials: RemoteMediaSourceCredentials
    ) async throws -> String {
        let cacheKey = Self.tokenCacheKey(rootURL: rootURL, credentials: credentials)
        if let cachedToken = await Self.cache.token(for: cacheKey) {
            return cachedToken
        }

        let response: AListResponse<AListLoginData> = try await postJSON(
            endpoint: try apiURL(rootURL: rootURL, path: "/api/auth/login"),
            headers: [:],
            body: AListLoginRequest(
                username: credentials.username,
                password: credentials.password
            )
        )

        guard response.code == 200, let token = response.data?.token, !token.isEmpty else {
            throw AListResolverError.loginFailed(response.message)
        }
        await Self.cache.storeToken(
            token,
            for: cacheKey,
            expiresAt: Date().addingTimeInterval(6 * 60 * 60)
        )
        return token
    }

    private func apiURL(rootURL: URL, path: String) throws -> URL {
        guard let scheme = rootURL.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              let host = rootURL.host
        else {
            throw AListResolverError.invalidRootURL(rootURL.absoluteString)
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = rootURL.port
        components.path = path
        guard let url = components.url else {
            throw AListResolverError.invalidRootURL(rootURL.absoluteString)
        }
        return url
    }

    private func postJSON<RequestBody: Encodable, ResponseBody: Decodable>(
        endpoint: URL,
        headers: [String: String],
        body: RequestBody
    ) async throws -> AListResponse<ResponseBody> {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONEncoder.alist.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AListResolverError.resolveFailed("No HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AListResolverError.resolveFailed("HTTP \(httpResponse.statusCode)")
        }
        return try JSONDecoder.alist.decode(AListResponse<ResponseBody>.self, from: data)
    }
}

private struct AListLoginRequest: Encodable {
    let username: String
    let password: String
}

private struct AListGetRequest: Encodable {
    let path: String
    let password: String
    let page: Int
    let perPage: Int
    let refresh: Bool

    enum CodingKeys: String, CodingKey {
        case path
        case password
        case page
        case perPage = "per_page"
        case refresh
    }
}

private struct AListResponse<DataBody: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: DataBody?
}

private struct AListLoginData: Decodable {
    let token: String
}

private struct AListMetadataData: Decodable {
    let name: String?
    let isDir: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case isDir = "is_dir"
    }
}

private struct AListFileData: Decodable {
    let rawURL: String
    let header: HeaderPayload?

    enum CodingKeys: String, CodingKey {
        case rawURL = "raw_url"
        case header
    }

    var parsedHeaders: [String: String] {
        header?.values ?? [:]
    }
}

private enum HeaderPayload: Decodable, Equatable {
    case string(String)
    case map([String: String])

    var values: [String: String] {
        switch self {
        case .map(let map):
            return map
        case .string(let string):
            guard !string.isEmpty,
                  let data = string.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data)
            else {
                return [:]
            }
            return decoded
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .map([:])
        } else if let map = try? container.decode([String: String].self) {
            self = .map(map)
        } else {
            self = .string(try container.decode(String.self))
        }
    }
}

private extension JSONEncoder {
    static var alist: JSONEncoder {
        JSONEncoder()
    }
}

private extension JSONDecoder {
    static var alist: JSONDecoder {
        JSONDecoder()
    }
}

private extension AListResolver {
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 45
        return URLSession(configuration: configuration)
    }()

    static func linkCacheKey(
        source: RemoteMediaSourceConfiguration,
        sourceRelativePath: String
    ) -> String {
        "\(source.id)|\(normalizedOriginAndPath(source.rootURL))|\(sourceRelativePath)"
    }

    static func tokenCacheKey(
        rootURL: URL,
        credentials: RemoteMediaSourceCredentials
    ) -> String {
        "\(normalizedOrigin(rootURL))|\(credentials.username)|\(credentials.password.hashValue)"
    }

    static func normalizedOriginAndPath(_ url: URL) -> String {
        var value = normalizedOrigin(url)
        var path = url.path.removingPercentEncoding ?? url.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        value += path.isEmpty ? "/" : path
        return value
    }

    static func normalizedOrigin(_ url: URL) -> String {
        guard let scheme = url.scheme, let host = url.host else {
            return url.absoluteString
        }
        var value = "\(scheme.lowercased())://\(host.lowercased())"
        if let port = url.port {
            value += ":\(port)"
        }
        return value
    }

    static func resolvedLinkExpiresAt(rawURL: URL) -> Date {
        let fallback = Date().addingTimeInterval(30 * 60)
        guard let components = URLComponents(url: rawURL, resolvingAgainstBaseURL: false),
              let expires = components.queryItems?.first(where: { $0.name == "expires" })?.value,
              let interval = expiryInterval(expires)
        else {
            return fallback
        }

        return Date().addingTimeInterval(min(interval * 0.8, 6 * 60 * 60))
    }

    static func expiryInterval(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasSuffix("h"), let hours = Double(trimmed.dropLast()) {
            return hours * 60 * 60
        }
        if trimmed.hasSuffix("m"), let minutes = Double(trimmed.dropLast()) {
            return minutes * 60
        }
        if trimmed.hasSuffix("s"), let seconds = Double(trimmed.dropLast()) {
            return seconds
        }
        if let seconds = Double(trimmed) {
            return seconds
        }
        return nil
    }
}

private actor AListResolverCache {
    private struct TokenEntry {
        let token: String
        let expiresAt: Date
    }

    private struct ResolvedLinkEntry {
        let resolved: ResolvedRemoteMedia
        let expiresAt: Date
    }

    private var tokens: [String: TokenEntry] = [:]
    private var resolvedLinks: [String: ResolvedLinkEntry] = [:]

    func token(for key: String) -> String? {
        guard let entry = tokens[key], entry.expiresAt > Date() else {
            tokens.removeValue(forKey: key)
            return nil
        }
        return entry.token
    }

    func storeToken(_ token: String, for key: String, expiresAt: Date) {
        tokens[key] = TokenEntry(token: token, expiresAt: expiresAt)
    }

    func resolvedLink(for key: String) -> ResolvedRemoteMedia? {
        guard let entry = resolvedLinks[key], entry.expiresAt > Date() else {
            resolvedLinks.removeValue(forKey: key)
            return nil
        }
        return entry.resolved
    }

    func storeResolvedLink(_ resolved: ResolvedRemoteMedia, for key: String, expiresAt: Date) {
        resolvedLinks[key] = ResolvedLinkEntry(resolved: resolved, expiresAt: expiresAt)
    }
}
