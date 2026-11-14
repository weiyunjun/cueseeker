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
    public let fileSize: Int64?
    public let videoWidth: Int?
    public let videoHeight: Int?
    public let videoCodec: String?
    public let duration: Double?
    public let subtitles: [IndexedContentSubtitle]

    public init(
        id: Int64,
        displayTitle: String,
        videoPath: String,
        videoName: String,
        fileSize: Int64? = nil,
        videoWidth: Int? = nil,
        videoHeight: Int? = nil,
        videoCodec: String? = nil,
        duration: Double? = nil,
        subtitles: [IndexedContentSubtitle] = []
    ) {
        self.id = id
        self.displayTitle = displayTitle
        self.videoPath = videoPath
        self.videoName = videoName
        self.fileSize = fileSize
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoCodec = videoCodec
        self.duration = duration
        self.subtitles = subtitles
    }

    func withSubtitles(_ subtitles: [IndexedContentSubtitle]) -> IndexedContentObject {
        IndexedContentObject(
            id: id,
            displayTitle: displayTitle,
            videoPath: videoPath,
            videoName: videoName,
            fileSize: fileSize,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            videoCodec: videoCodec,
            duration: duration,
            subtitles: subtitles
        )
    }
}

public struct IndexedContentSubtitle: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let path: String
    public let name: String
    public let fileSize: Int64?
    public let rawCueCount: Int?
    public let validCueCount: Int?

    public init(
        id: Int64,
        path: String,
        name: String,
        fileSize: Int64? = nil,
        rawCueCount: Int? = nil,
        validCueCount: Int? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.fileSize = fileSize
        self.rawCueCount = rawCueCount
        self.validCueCount = validCueCount
    }

    func withValidCueCount(_ validCueCount: Int?) -> IndexedContentSubtitle {
        IndexedContentSubtitle(
            id: id,
            path: path,
            name: name,
            fileSize: fileSize,
            rawCueCount: rawCueCount,
            validCueCount: validCueCount
        )
    }
}
