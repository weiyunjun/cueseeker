import Foundation

public struct SubtitleDatabaseEntry: Equatable, Sendable {
    public let id: Int64
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let videoPath: String
    public let videoName: String
    public let sequenceNumber: Int?
    public let startTimecode: String
    public let endTimecode: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let content: String
}

public struct SubtitleDatabaseEntryIndexItem: Equatable, Sendable {
    public let id: Int64
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(id: Int64, startMilliseconds: Int, endMilliseconds: Int) {
        self.id = id
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
    }
}

