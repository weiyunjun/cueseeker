import Foundation

public struct IndexedContentRoot: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let path: String
    public let folders: [IndexedContentFolder]

    public var displayPath: String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

public struct IndexedContentFolder: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let relativePath: String
    public let objects: [IndexedContentObject]

    public var displayPath: String {
        String(relativePath.drop(while: { $0 == "/" }))
    }
}

public struct IndexedContentObject: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let displayTitle: String
    public let videoPath: String
    public let videoName: String
    public let subtitles: [IndexedContentSubtitle]
}

public struct IndexedContentSubtitle: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let path: String
    public let name: String
}
