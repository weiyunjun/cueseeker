import Foundation

public enum MediaSourceType: String, Sendable, Equatable {
    case local
    case webdav
}

public enum MediaSourceProvider: String, CaseIterable, Identifiable, Sendable, Equatable {
    case local
    case genericWebDAV
    case alist

    public var id: String {
        rawValue
    }
}

public struct StoredMediaSource: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let type: MediaSourceType
    public let provider: MediaSourceProvider
    public let path: String
    public let displayName: String
    public let credentialRef: String?
}

public struct RemoteMediaSourceCredentials: Equatable, Sendable, Codable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct RemoteMediaSourceConfiguration: Equatable, Sendable {
    public let id: Int64
    public let provider: MediaSourceProvider
    public let displayName: String
    public let rootURL: URL
    public let credentialRef: String?
    public let credentials: RemoteMediaSourceCredentials

    public init(
        id: Int64,
        provider: MediaSourceProvider,
        displayName: String,
        rootURL: URL,
        credentialRef: String?,
        credentials: RemoteMediaSourceCredentials
    ) {
        self.id = id
        self.provider = provider
        self.displayName = displayName
        self.rootURL = rootURL
        self.credentialRef = credentialRef
        self.credentials = credentials
    }
}

public struct ResolvedRemoteMedia: Equatable, Sendable {
    public let url: URL
    public let headers: [String: String]

    public init(url: URL, headers: [String: String] = [:]) {
        self.url = url
        self.headers = headers
    }
}
