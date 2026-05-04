import CryptoKit
import Foundation

struct RemoteByteRange: Codable, Equatable, Sendable {
    let start: Int64
    let end: Int64

    init?(start: Int64, end: Int64) {
        guard start >= 0, end >= start else {
            return nil
        }
        self.start = start
        self.end = end
    }

    var length: Int64 {
        end - start + 1
    }

    func contains(_ range: RemoteByteRange) -> Bool {
        start <= range.start && end >= range.end
    }

    func overlapsOrTouches(_ range: RemoteByteRange, maximumGap: Int64 = 0) -> Bool {
        range.start <= end + maximumGap + 1 && start <= range.end + maximumGap + 1
    }

    func merged(with range: RemoteByteRange) -> RemoteByteRange {
        RemoteByteRange(start: min(start, range.start), end: max(end, range.end))!
    }
}

struct RemoteRangeCacheWindow: Equatable, Sendable {
    let startMilliseconds: Int
    let endMilliseconds: Int
}

struct RemoteRangeCachedResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let data: Data
}

actor RemoteRangeCache {
    static let shared = RemoteRangeCache()

    private static let maximumEntries = 1_000
    private static let maximumTotalBytes: Int64 = 16 * 1024 * 1024 * 1024
    private static let maximumBytesPerVideo: Int64 = 64 * 1024 * 1024
    private static let headerPrefetchBytes: Int64 = 4 * 1024 * 1024
    private static let tailPrefetchBytes: Int64 = 4 * 1024 * 1024
    private static let targetWindowBytes: Int64 = 12 * 1024 * 1024
    private static let targetWindowPreBytes: Int64 = 4 * 1024 * 1024
    private static let maximumForwardCaptureBytes: Int64 = 16 * 1024 * 1024
    private static let assumedEpisodeDurationMilliseconds = 24 * 60 * 1_000

    private let rootURL: URL
    private let session: URLSession
    private var metadataCache: [String: CachedVideoMetadata] = [:]

    init(
        rootURL: URL? = nil,
        session: URLSession? = nil
    ) {
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.rootURL = rootURL
            ?? cacheRoot
                .appendingPathComponent("CueSeeker", isDirectory: true)
                .appendingPathComponent("RemoteRangeCache", isDirectory: true)

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpShouldSetCookies = false
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 20 * 60
            self.session = URLSession(configuration: configuration)
        }
    }

    func cachedResponse(
        cacheKey: String,
        range: RemoteByteRange
    ) async -> RemoteRangeCachedResponse? {
        do {
            var metadata = try loadMetadata(cacheKey: cacheKey)
            guard let entryIndex = metadata.ranges.firstIndex(where: { $0.range.contains(range) }) else {
                print("REMOTE_RANGE_CACHE state=miss media=\(Self.redacted(cacheKey)) range=\(range.start)-\(range.end)")
                return nil
            }

            var entry = metadata.ranges[entryIndex]
            let fileURL = directoryURL(cacheKey: cacheKey).appendingPathComponent(entry.fileName)
            let handle = try FileHandle(forReadingFrom: fileURL)
            try handle.seek(toOffset: UInt64(range.start - entry.range.start))
            let data = handle.readData(ofLength: Int(range.length))
            try handle.close()

            guard data.count == range.length else {
                print("REMOTE_RANGE_CACHE state=miss_partial media=\(Self.redacted(cacheKey)) range=\(range.start)-\(range.end)")
                return nil
            }

            entry.lastAccessedAt = Date()
            metadata.ranges[entryIndex] = entry
            metadata.lastAccessedAt = Date()
            try saveMetadata(metadata, cacheKey: cacheKey)

            let totalSize = metadata.totalSize ?? max(entry.range.end + 1, range.end + 1)
            print("REMOTE_RANGE_CACHE state=hit media=\(Self.redacted(cacheKey)) range=\(range.start)-\(range.end) bytes=\(data.count)")
            return RemoteRangeCachedResponse(
                statusCode: 206,
                headers: [
                    "Accept-Ranges": "bytes",
                    "Content-Length": "\(data.count)",
                    "Content-Range": "bytes \(range.start)-\(range.end)/\(totalSize)",
                    "Content-Type": metadata.contentType ?? "application/octet-stream"
                ],
                data: data
            )
        } catch {
            print("REMOTE_RANGE_CACHE state=miss_error media=\(Self.redacted(cacheKey)) reason=\(error)")
            return nil
        }
    }

    func storeForwardedRange(
        cacheKey: String,
        range: RemoteByteRange,
        totalSize: Int64?,
        contentType: String?,
        data: Data
    ) async {
        guard data.count == range.length,
              range.length <= Self.maximumForwardCaptureBytes
        else {
            return
        }
        do {
            try store(
                cacheKey: cacheKey,
                range: range,
                totalSize: totalSize,
                contentType: contentType,
                data: data
            )
            print("REMOTE_RANGE_CACHE state=store_forward media=\(Self.redacted(cacheKey)) range=\(range.start)-\(range.end) bytes=\(data.count)")
        } catch {
            print("REMOTE_RANGE_CACHE state=store_forward_failed media=\(Self.redacted(cacheKey)) reason=\(error)")
        }
    }

    func prefetch(
        cacheKey: String,
        remoteURL: URL,
        headers: [String: String],
        windows: [RemoteRangeCacheWindow]
    ) async {
        do {
            try ensureRootDirectory()
            let totalSize = try await discoverTotalSize(
                cacheKey: cacheKey,
                remoteURL: remoteURL,
                headers: headers
            )
            guard totalSize > 0 else {
                return
            }

            let plannedRanges = try plannedPrefetchRanges(
                cacheKey: cacheKey,
                totalSize: totalSize,
                windows: windows
            )
            print("REMOTE_RANGE_CACHE state=prefetch_start media=\(Self.redacted(cacheKey)) windows=\(windows.count) ranges=\(plannedRanges.count)")

            for range in plannedRanges {
                try Task.checkCancellation()
                if try isCached(cacheKey: cacheKey, range: range) {
                    print("REMOTE_RANGE_CACHE state=prefetch_skip_cached media=\(Self.redacted(cacheKey)) range=\(range.start)-\(range.end)")
                    continue
                }
                try await fetchAndStore(
                    cacheKey: cacheKey,
                    remoteURL: remoteURL,
                    headers: headers,
                    range: range
                )
            }

            try enforceGlobalLimits()
            print("REMOTE_RANGE_CACHE state=prefetch_done media=\(Self.redacted(cacheKey))")
        } catch is CancellationError {
            print("REMOTE_RANGE_CACHE state=prefetch_cancelled media=\(Self.redacted(cacheKey))")
        } catch {
            print("REMOTE_RANGE_CACHE state=prefetch_failed media=\(Self.redacted(cacheKey)) reason=\(error)")
        }
    }

    static func byteRange(from rangeHeader: String?) -> RemoteByteRange? {
        guard let rangeHeader,
              rangeHeader.lowercased().hasPrefix("bytes=")
        else {
            return nil
        }

        let value = rangeHeader.dropFirst("bytes=".count)
        guard let separator = value.firstIndex(of: "-") else {
            return nil
        }

        let startText = value[..<separator]
        let endText = value[value.index(after: separator)...]
        guard let start = Int64(startText), !endText.isEmpty, let end = Int64(endText) else {
            return nil
        }
        return RemoteByteRange(start: start, end: end)
    }

    static func responseRange(from contentRange: String?) -> (range: RemoteByteRange, totalSize: Int64?)? {
        guard let contentRange else {
            return nil
        }

        let prefix = "bytes "
        guard contentRange.lowercased().hasPrefix(prefix) else {
            return nil
        }

        let rest = contentRange.dropFirst(prefix.count)
        let parts = rest.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return nil
        }

        let rangeParts = parts[0].split(separator: "-", maxSplits: 1).map(String.init)
        guard rangeParts.count == 2,
              let start = Int64(rangeParts[0]),
              let end = Int64(rangeParts[1]),
              let range = RemoteByteRange(start: start, end: end)
        else {
            return nil
        }

        let totalSize = parts[1] == "*" ? nil : Int64(parts[1])
        return (range, totalSize)
    }

    private func discoverTotalSize(
        cacheKey: String,
        remoteURL: URL,
        headers: [String: String]
    ) async throws -> Int64 {
        let metadata = try loadMetadata(cacheKey: cacheKey)
        if let totalSize = metadata.totalSize, totalSize > 0 {
            return totalSize
        }

        let range = RemoteByteRange(start: 0, end: 0)!
        let response = try await fetchRange(remoteURL: remoteURL, headers: headers, range: range)
        let totalSize = response.totalSize ?? Int64(response.data.count)
        try store(
            cacheKey: cacheKey,
            range: response.range,
            totalSize: totalSize,
            contentType: response.contentType,
            data: response.data
        )
        return totalSize
    }

    private func plannedPrefetchRanges(
        cacheKey: String,
        totalSize: Int64,
        windows: [RemoteRangeCacheWindow]
    ) throws -> [RemoteByteRange] {
        var ranges: [RemoteByteRange] = []
        if let header = RemoteByteRange(start: 0, end: min(totalSize - 1, Self.headerPrefetchBytes - 1)) {
            ranges.append(header)
        }
        if totalSize > Self.tailPrefetchBytes,
           let tail = RemoteByteRange(start: max(0, totalSize - Self.tailPrefetchBytes), end: totalSize - 1) {
            ranges.append(tail)
        }

        let maxTimestamp = max(windows.map(\.endMilliseconds).max() ?? Self.assumedEpisodeDurationMilliseconds, Self.assumedEpisodeDurationMilliseconds)
        let estimatedDurationMilliseconds = max(maxTimestamp + 5 * 60 * 1_000, Self.assumedEpisodeDurationMilliseconds)
        for window in windows {
            let ratio = min(max(Double(window.startMilliseconds) / Double(estimatedDurationMilliseconds), 0), 0.98)
            let center = Int64((Double(totalSize) * ratio).rounded(.down))
            let start = max(0, center - Self.targetWindowPreBytes)
            let end = min(totalSize - 1, start + Self.targetWindowBytes - 1)
            if let range = RemoteByteRange(start: start, end: end) {
                ranges.append(range)
            }
        }

        let merged = Self.merged(ranges: ranges, maximumGap: 1024 * 1024)
        var selected: [RemoteByteRange] = []
        var selectedBytes: Int64 = 0
        for range in merged {
            let length = range.length
            guard selectedBytes + length <= Self.maximumBytesPerVideo || selected.isEmpty else {
                break
            }
            selected.append(range)
            selectedBytes += length
        }
        return selected
    }

    private func fetchAndStore(
        cacheKey: String,
        remoteURL: URL,
        headers: [String: String],
        range: RemoteByteRange
    ) async throws {
        let response = try await fetchRange(remoteURL: remoteURL, headers: headers, range: range)
        try store(
            cacheKey: cacheKey,
            range: response.range,
            totalSize: response.totalSize,
            contentType: response.contentType,
            data: response.data
        )
        print("REMOTE_RANGE_CACHE state=prefetch_store media=\(Self.redacted(cacheKey)) range=\(response.range.start)-\(response.range.end) bytes=\(response.data.count)")
    }

    private func fetchRange(
        remoteURL: URL,
        headers: [String: String],
        range: RemoteByteRange
    ) async throws -> RemoteFetchResponse {
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("bytes=\(range.start)-\(range.end)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteRangeCacheError.invalidResponse
        }
        guard httpResponse.statusCode == 206,
              let parsedRange = Self.responseRange(from: httpResponse.value(forHTTPHeaderField: "Content-Range"))
        else {
            throw RemoteRangeCacheError.unexpectedStatus(httpResponse.statusCode)
        }

        return RemoteFetchResponse(
            range: parsedRange.range,
            totalSize: parsedRange.totalSize,
            contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
            data: data
        )
    }

    private func store(
        cacheKey: String,
        range: RemoteByteRange,
        totalSize: Int64?,
        contentType: String?,
        data: Data
    ) throws {
        guard data.count == range.length else {
            throw RemoteRangeCacheError.invalidLength
        }

        try ensureRootDirectory()
        try ensureDirectory(cacheKey: cacheKey)
        var metadata = try loadMetadata(cacheKey: cacheKey)
        if metadata.ranges.contains(where: { $0.range.contains(range) }) {
            return
        }

        let fileName = "\(range.start)-\(range.end).bin"
        let directory = directoryURL(cacheKey: cacheKey)
        let tempURL = directory.appendingPathComponent(fileName + ".tmp")
        let fileURL = directory.appendingPathComponent(fileName)
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: fileURL)

        let now = Date()
        metadata.totalSize = totalSize ?? metadata.totalSize
        metadata.contentType = contentType ?? metadata.contentType
        metadata.updatedAt = now
        metadata.lastAccessedAt = now
        metadata.ranges.append(
            CachedRangeEntry(
                range: range,
                fileName: fileName,
                byteCount: Int64(data.count),
                createdAt: now,
                lastAccessedAt: now
            )
        )
        try enforcePerVideoLimit(metadata: &metadata, cacheKey: cacheKey)
        try saveMetadata(metadata, cacheKey: cacheKey)
    }

    private func isCached(cacheKey: String, range: RemoteByteRange) throws -> Bool {
        let metadata = try loadMetadata(cacheKey: cacheKey)
        return metadata.ranges.contains { $0.range.contains(range) }
    }

    private func enforcePerVideoLimit(
        metadata: inout CachedVideoMetadata,
        cacheKey: String
    ) throws {
        var totalBytes = metadata.ranges.reduce(Int64(0)) { $0 + $1.byteCount }
        while totalBytes > Self.maximumBytesPerVideo, !metadata.ranges.isEmpty {
            guard let index = metadata.ranges.indices.min(by: {
                metadata.ranges[$0].lastAccessedAt < metadata.ranges[$1].lastAccessedAt
            }) else {
                break
            }
            let entry = metadata.ranges.remove(at: index)
            totalBytes -= entry.byteCount
            try? FileManager.default.removeItem(
                at: directoryURL(cacheKey: cacheKey).appendingPathComponent(entry.fileName)
            )
        }
    }

    private func enforceGlobalLimits() throws {
        let allMetadata = try allCachedMetadata()
        var allEntries: [(cacheKey: String, entry: CachedRangeEntry)] = []
        for metadata in allMetadata {
            for entry in metadata.ranges {
                allEntries.append((metadata.cacheKey, entry))
            }
        }

        var totalBytes = allEntries.reduce(Int64(0)) { $0 + $1.entry.byteCount }
        var entryCount = allEntries.count
        let removalOrder = allEntries.sorted {
            $0.entry.lastAccessedAt < $1.entry.lastAccessedAt
        }
        for item in removalOrder where totalBytes > Self.maximumTotalBytes || entryCount > Self.maximumEntries {
            try remove(entry: item.entry, cacheKey: item.cacheKey)
            totalBytes -= item.entry.byteCount
            entryCount -= 1
        }
    }

    private func remove(entry: CachedRangeEntry, cacheKey: String) throws {
        var metadata = try loadMetadata(cacheKey: cacheKey)
        metadata.ranges.removeAll { $0.fileName == entry.fileName }
        try? FileManager.default.removeItem(
            at: directoryURL(cacheKey: cacheKey).appendingPathComponent(entry.fileName)
        )
        try saveMetadata(metadata, cacheKey: cacheKey)
    }

    private func allCachedMetadata() throws -> [CachedVideoMetadata] {
        try ensureRootDirectory()
        let directories = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var result: [CachedVideoMetadata] = []
        for directory in directories {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                continue
            }
            let cacheKeyHash = directory.lastPathComponent
            let metadataURL = directory.appendingPathComponent("metadata.json")
            guard FileManager.default.fileExists(atPath: metadataURL.path) else {
                continue
            }
            let data = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(CachedVideoMetadata.self, from: data)
            metadataCache[cacheKeyHash] = metadata
            result.append(metadata)
        }
        return result
    }

    private func loadMetadata(cacheKey: String) throws -> CachedVideoMetadata {
        let cacheKeyHash = Self.cacheKeyHash(cacheKey)
        if let metadata = metadataCache[cacheKeyHash] {
            return metadata
        }

        let metadataURL = directoryURL(cacheKey: cacheKey).appendingPathComponent("metadata.json")
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            let metadata = CachedVideoMetadata(
                cacheKey: cacheKey,
                totalSize: nil,
                contentType: nil,
                createdAt: Date(),
                updatedAt: Date(),
                lastAccessedAt: Date(),
                ranges: []
            )
            metadataCache[cacheKeyHash] = metadata
            return metadata
        }

        let data = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(CachedVideoMetadata.self, from: data)
        metadataCache[cacheKeyHash] = metadata
        return metadata
    }

    private func saveMetadata(_ metadata: CachedVideoMetadata, cacheKey: String) throws {
        try ensureDirectory(cacheKey: cacheKey)
        let cacheKeyHash = Self.cacheKeyHash(cacheKey)
        metadataCache[cacheKeyHash] = metadata
        let data = try JSONEncoder().encode(metadata)
        try data.write(
            to: directoryURL(cacheKey: cacheKey).appendingPathComponent("metadata.json"),
            options: .atomic
        )
    }

    private func ensureRootDirectory() throws {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
    }

    private func ensureDirectory(cacheKey: String) throws {
        try FileManager.default.createDirectory(
            at: directoryURL(cacheKey: cacheKey),
            withIntermediateDirectories: true
        )
    }

    private func directoryURL(cacheKey: String) -> URL {
        rootURL.appendingPathComponent(Self.cacheKeyHash(cacheKey), isDirectory: true)
    }

    private static func merged(
        ranges: [RemoteByteRange],
        maximumGap: Int64
    ) -> [RemoteByteRange] {
        let sorted = ranges.sorted {
            if $0.start == $1.start {
                return $0.end < $1.end
            }
            return $0.start < $1.start
        }
        var merged: [RemoteByteRange] = []
        for range in sorted {
            guard let last = merged.last else {
                merged.append(range)
                continue
            }
            if last.overlapsOrTouches(range, maximumGap: maximumGap) {
                merged[merged.count - 1] = last.merged(with: range)
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    private static func cacheKeyHash(_ cacheKey: String) -> String {
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func redacted(_ cacheKey: String) -> String {
        String(cacheKeyHash(cacheKey).prefix(12))
    }
}

private struct CachedVideoMetadata: Codable {
    let cacheKey: String
    var totalSize: Int64?
    var contentType: String?
    let createdAt: Date
    var updatedAt: Date
    var lastAccessedAt: Date
    var ranges: [CachedRangeEntry]
}

private struct CachedRangeEntry: Codable {
    let range: RemoteByteRange
    let fileName: String
    let byteCount: Int64
    let createdAt: Date
    var lastAccessedAt: Date
}

private struct RemoteFetchResponse {
    let range: RemoteByteRange
    let totalSize: Int64?
    let contentType: String?
    let data: Data
}

private enum RemoteRangeCacheError: Error, CustomStringConvertible {
    case invalidResponse
    case invalidLength
    case unexpectedStatus(Int)

    var description: String {
        switch self {
        case .invalidResponse:
            "Remote range cache received a non-HTTP response."
        case .invalidLength:
            "Remote range cache received data with an unexpected length."
        case .unexpectedStatus(let status):
            "Remote range cache received unexpected HTTP status \(status)."
        }
    }
}
