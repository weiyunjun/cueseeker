import Foundation

public struct IndexedContentRoot: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let path: String
    public let folders: [IndexedContentFolder]

    public init(id: Int64, path: String, folders: [IndexedContentFolder] = []) {
        self.id = id
        self.path = path
        self.folders = folders
    }

    public var displayPath: String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

public struct IndexedContentFolder: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let relativePath: String
    public let folderPath: String
    public let objects: [IndexedContentObject]

    public init(id: Int64, relativePath: String, folderPath: String, objects: [IndexedContentObject] = []) {
        self.id = id
        self.relativePath = relativePath
        self.folderPath = folderPath
        self.objects = objects
    }

    public var displayPath: String {
        String(relativePath.drop(while: { $0 == "/" }))
    }
}

public struct IndexedContentObject: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let displayTitle: String
    public let videoPath: String
    public let videoName: String
    public let fileSize: Int64
    public let subtitles: [IndexedContentSubtitle]

    public init(
        id: Int64,
        displayTitle: String,
        videoPath: String,
        videoName: String,
        fileSize: Int64 = 0,
        subtitles: [IndexedContentSubtitle] = []
    ) {
        self.id = id
        self.displayTitle = displayTitle
        self.videoPath = videoPath
        self.videoName = videoName
        self.fileSize = fileSize
        self.subtitles = subtitles
    }
}

public struct IndexedContentSubtitle: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let path: String
    public let name: String
    public let fileSize: Int64

    public init(
        id: Int64,
        path: String,
        name: String,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.fileSize = fileSize
    }
}
