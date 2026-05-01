import Foundation

public struct SubtitleEntry: Equatable, Sendable {
    public let sequenceNumber: Int?
    public let startTimecode: String
    public let endTimecode: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let text: String

    public init(
        sequenceNumber: Int?,
        startTimecode: String,
        endTimecode: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        text: String
    ) {
        self.sequenceNumber = sequenceNumber
        self.startTimecode = startTimecode
        self.endTimecode = endTimecode
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.text = text
    }
}

