import Foundation

public struct DatabaseStorageStats: Equatable, Sendable {
    public let databaseFileBytes: Int64
    public let walFileBytes: Int64
    public let shmFileBytes: Int64
    public let pageSize: Int
    public let pageCount: Int
    public let freelistCount: Int
    public let autoVacuumMode: Int

    public var allocatedBytes: Int64 {
        Int64(pageSize) * Int64(pageCount)
    }

    public var freelistBytes: Int64 {
        Int64(pageSize) * Int64(freelistCount)
    }

    public var usedBytesEstimate: Int64 {
        Int64(pageSize) * Int64(max(0, pageCount - freelistCount))
    }

    public var freelistRatio: Double {
        guard pageCount > 0 else {
            return 0
        }

        return Double(freelistCount) / Double(pageCount)
    }
}
