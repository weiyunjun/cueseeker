import Foundation

public struct SubtitleIndexingResult: Equatable, Sendable {
    public var scannedSubtitleFiles: Int = 0
    public var indexedSubtitleFiles: Int = 0
    public var indexedSubtitleEntries: Int = 0
    public var skippedUnchangedSubtitleFiles: Int = 0
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
        let subtitleFiles = scanner.scanSubtitleFiles(in: folder)
        result.scannedSubtitleFiles = subtitleFiles.count

        let existingFiles = Dictionary(
            uniqueKeysWithValues: try database.subtitleFiles().map { ($0.subtitlePath, $0) }
        )
        var keptSubtitlePaths = Set<String>()

        for subtitleFile in subtitleFiles {
            guard let videoFile = matcher.matchingVideo(for: subtitleFile) else {
                result.skippedMissingVideo += 1
                continue
            }

            let attributes = try? FileManager.default.attributesOfItem(atPath: subtitleFile.path)
            let fileSize = (attributes?[.size] as? NSNumber)?.int64Value
            let modifiedAt = attributes?[.modificationDate] as? Date

            if let metadata = existingFiles[subtitleFile.path],
               isUnchanged(metadata: metadata, videoFile: videoFile, fileSize: fileSize, modifiedAt: modifiedAt)
            {
                keptSubtitlePaths.insert(subtitleFile.path)
                result.skippedUnchangedSubtitleFiles += 1
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

            guard let format = SubtitleFormat(fileExtension: subtitleFile.pathExtension) else {
                continue
            }

            let cueGroups: [SubtitleCueGroup]
            switch format {
            case .srt:
                cueGroups = SRTParser.parseCueGroups(contents)
            case .ass:
                cueGroups = ASSParser.parseCueGroups(contents)
            }

            try database.replaceCueGroups(
                subtitleFile: subtitleFile,
                videoFile: videoFile,
                format: format,
                cueGroups: cueGroups,
                fileSize: fileSize,
                modifiedAt: modifiedAt
            )

            keptSubtitlePaths.insert(subtitleFile.path)
            result.indexedSubtitleFiles += 1
            result.indexedSubtitleEntries += cueGroups.count
        }

        try database.removeStaleEntries(under: folder, keeping: keptSubtitlePaths)

        return result
    }

    private func isUnchanged(
        metadata: SubtitleFileMetadata,
        videoFile: URL,
        fileSize: Int64?,
        modifiedAt: Date?
    ) -> Bool {
        guard metadata.videoPath == videoFile.path,
              metadata.fileSize == fileSize,
              let existingModifiedAt = metadata.modifiedAt,
              let modifiedAt
        else {
            return false
        }

        return abs(existingModifiedAt.timeIntervalSince1970 - modifiedAt.timeIntervalSince1970) < 0.001
    }
}

private extension SubtitleFormat {
    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "srt":
            self = .srt
        case "ass":
            self = .ass
        default:
            return nil
        }
    }
}
