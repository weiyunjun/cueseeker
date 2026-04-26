import Foundation

public struct SubtitleIndexingResult: Equatable, Sendable {
    public var scannedSubtitleFiles: Int = 0
    public var indexedSubtitleFiles: Int = 0
    public var indexedSubtitleEntries: Int = 0
    public var skippedMissingVideo: Int = 0
    public var skippedUnreadableSubtitle: Int = 0
    public var failedFiles: [SubtitleIndexingFailure] = []
}

public struct SubtitleIndexingFailure: Equatable, Sendable {
    public let path: String
    public let reason: String
}

public struct SubtitleIndexer {
    private let scanner: SubtitleFileScanner
    private let matcher: VideoMatcher

    public init(
        scanner: SubtitleFileScanner = SubtitleFileScanner(),
        matcher: VideoMatcher = VideoMatcher()
    ) {
        self.scanner = scanner
        self.matcher = matcher
    }

    public func index(folder: URL, into database: SubtitleDatabase) throws -> SubtitleIndexingResult {
        try database.migrate()
        _ = try database.addSearchPath(folder)

        var result = SubtitleIndexingResult()
        let subtitleFiles = scanner.scanSRTFiles(in: folder)
        result.scannedSubtitleFiles = subtitleFiles.count

        var keptSubtitlePaths = Set<String>()

        for subtitleFile in subtitleFiles {
            guard let videoFile = matcher.matchingVideo(for: subtitleFile) else {
                result.skippedMissingVideo += 1
                continue
            }

            let contents: String
            do {
                contents = try String(contentsOf: subtitleFile)
            } catch {
                result.skippedUnreadableSubtitle += 1
                result.failedFiles.append(
                    SubtitleIndexingFailure(
                        path: subtitleFile.path,
                        reason: "Subtitle file could not be read."
                    )
                )
                continue
            }

            let entries = SRTParser.parse(contents)
            let attributes = try? FileManager.default.attributesOfItem(atPath: subtitleFile.path)
            let fileSize = (attributes?[.size] as? NSNumber)?.int64Value
            let modifiedAt = attributes?[.modificationDate] as? Date

            try database.replaceEntries(
                subtitleFile: subtitleFile,
                videoFile: videoFile,
                entries: entries,
                fileSize: fileSize,
                modifiedAt: modifiedAt
            )

            keptSubtitlePaths.insert(subtitleFile.path)
            result.indexedSubtitleFiles += 1
            result.indexedSubtitleEntries += entries.count
        }

        try database.removeStaleEntries(under: folder, keeping: keptSubtitlePaths)

        return result
    }
}
