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

public enum SubtitleIndexingError: Error, Equatable, Sendable {
    case incomplete(path: String, reason: String)
    case stalePublication(libraryID: Int64, token: Int64)
}

struct LibraryIndexLease: Equatable, Sendable {
    let libraryID: Int64
    let token: Int64
}

struct PreparedSubtitleIndexFile: Sendable {
    let subtitleFile: URL
    let videoFile: URL
    let format: SubtitleFormat
    let cueGroups: [SubtitleCueGroup]
    let assRenderSegments: [ASSRenderSegmentPayload]
    let assFontReferences: [ASSFontReferenceIntent]
    let fileSize: Int64?
    let modifiedAt: Date?
    let languageAnalysis: SubtitleLanguageAnalysis
}

struct UnchangedSubtitleIndexFile: Sendable {
    let subtitleFile: URL
    let videoFile: URL
}

struct PreparedLibraryIndex: Sendable {
    let folder: URL
    let lease: LibraryIndexLease
    let changedFiles: [PreparedSubtitleIndexFile]
    let unchangedFiles: [UnchangedSubtitleIndexFile]
    let keptSubtitlePaths: Set<String>
}

public struct SubtitleIndexer {
    private let scanner: SubtitleFileScanner
    private let matcher: VideoMatcher
    private let languageAnalyzer: SubtitleLanguageAnalyzer

    public init(
        scanner: SubtitleFileScanner = SubtitleFileScanner(),
        matcher: VideoMatcher = VideoMatcher(),
        languageAnalyzer: SubtitleLanguageAnalyzer = SubtitleLanguageAnalyzer()
    ) {
        self.scanner = scanner
        self.matcher = matcher
        self.languageAnalyzer = languageAnalyzer
    }

    public func index(folder: URL, into database: IndexingDatabase) throws -> SubtitleIndexingResult {
        try scanner.validateReadableDirectory(folder)
        let lease = try database.beginLibraryIndex(folder)
        let playbackDatabase = try PlaybackSubtitleDatabase(path: database.path)

        var result = SubtitleIndexingResult()
        let subtitleFiles: [URL]
        do {
            subtitleFiles = try scanner.scanSubtitleFilesSafely(in: folder)
        } catch {
            throw SubtitleIndexingError.incomplete(
                path: folder.path,
                reason: "Library scan did not complete: \(error)"
            )
        }
        result.scannedSubtitleFiles = subtitleFiles.count

        let existingFiles = Dictionary(
            uniqueKeysWithValues: try database.subtitleFiles().map { ($0.subtitlePath, $0) }
        )
        var keptSubtitlePaths = Set<String>()
        var changedFiles: [PreparedSubtitleIndexFile] = []
        var unchangedFiles: [UnchangedSubtitleIndexFile] = []

        for subtitleFile in subtitleFiles {
            guard let videoFile = matcher.matchingVideo(for: subtitleFile) else {
                keptSubtitlePaths.insert(subtitleFile.path)
                result.skippedMissingVideo += 1
                continue
            }

            let attributes: [FileAttributeKey: Any]
            do {
                attributes = try FileManager.default.attributesOfItem(atPath: subtitleFile.path)
            } catch {
                throw SubtitleIndexingError.incomplete(
                    path: subtitleFile.path,
                    reason: "Subtitle metadata could not be read."
                )
            }
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value
            let modifiedAt = attributes[.modificationDate] as? Date

            if let metadata = existingFiles[subtitleFile.path],
               try isUnchanged(
                    metadata: metadata,
                    videoFile: videoFile,
                    subtitleFile: subtitleFile,
                    database: database,
                    playbackDatabase: playbackDatabase,
                    fileSize: fileSize,
                    modifiedAt: modifiedAt
               )
            {
                keptSubtitlePaths.insert(subtitleFile.path)
                unchangedFiles.append(
                    UnchangedSubtitleIndexFile(
                        subtitleFile: subtitleFile,
                        videoFile: videoFile
                    )
                )
                result.skippedUnchangedSubtitleFiles += 1
                continue
            }

            let contents: String
            do {
                contents = try String(contentsOf: subtitleFile)
            } catch {
                throw SubtitleIndexingError.incomplete(
                    path: subtitleFile.path,
                    reason: "Subtitle file could not be read."
                )
            }

            guard let format = SubtitleFormat(fileExtension: subtitleFile.pathExtension) else {
                continue
            }

            let cueGroups: [SubtitleCueGroup]
            var assRenderSegments: [ASSRenderSegmentPayload] = []
            var assFontReferences: [ASSFontReferenceIntent] = []
            do {
                switch format {
                case .srt:
                    cueGroups = try SRTParser.parseCueGroupsForIndexing(contents)
                case .ass:
                    cueGroups = try ASSParser.parseCueGroupsForIndexing(contents)
                    assFontReferences = ASSFontIntentExtractor.references(from: contents)
                    if ASSRenderSegmenter.shouldSegment(format: format, fileSize: fileSize) {
                        assRenderSegments = ASSRenderSegmenter.renderSegments(from: contents)
                    }
                }
            } catch {
                throw SubtitleIndexingError.incomplete(
                    path: subtitleFile.path,
                    reason: "Subtitle parsing did not complete: \(error)"
                )
            }

            let languageAnalysis = languageAnalyzer.analyze(format: format, cueGroups: cueGroups)
            changedFiles.append(
                PreparedSubtitleIndexFile(
                    subtitleFile: subtitleFile,
                    videoFile: videoFile,
                    format: format,
                    cueGroups: cueGroups,
                    assRenderSegments: assRenderSegments,
                    assFontReferences: assFontReferences,
                    fileSize: fileSize,
                    modifiedAt: modifiedAt,
                    languageAnalysis: languageAnalysis
                )
            )

            keptSubtitlePaths.insert(subtitleFile.path)
            result.indexedSubtitleFiles += 1
            result.indexedSubtitleEntries += cueGroups.count
        }

        try database.publishLibraryIndex(
            PreparedLibraryIndex(
                folder: folder,
                lease: lease,
                changedFiles: changedFiles,
                unchangedFiles: unchangedFiles,
                keptSubtitlePaths: keptSubtitlePaths
            )
        )

        return result
    }

    private func isUnchanged(
        metadata: SubtitleFileMetadata,
        videoFile: URL,
        subtitleFile: URL,
        database: IndexingDatabase,
        playbackDatabase: PlaybackSubtitleDatabase,
        fileSize: Int64?,
        modifiedAt: Date?
    ) throws -> Bool {
        guard metadata.videoPath == videoFile.path,
              metadata.fileSize == fileSize,
              metadata.indexAlgorithmVersion == SubtitleCueIndexingRules.algorithmVersion,
              let existingModifiedAt = metadata.modifiedAt,
              let modifiedAt
        else {
            return false
        }

        guard abs(existingModifiedAt.timeIntervalSince1970 - modifiedAt.timeIntervalSince1970) < 0.001 else {
            return false
        }

        guard try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: subtitleFile) else {
            return false
        }

        guard try playbackDatabase.hasCurrentPlaybackFinishMetadata(forSubtitleFile: subtitleFile) else {
            return false
        }

        if metadata.subtitleFormat == .ass,
           try !playbackDatabase.hasCurrentASSFontReferenceManifest(forSubtitleFile: subtitleFile) {
            return false
        }

        if ASSRenderSegmenter.shouldSegment(format: metadata.subtitleFormat, fileSize: fileSize) {
            return try playbackDatabase.hasASSRenderSegments(forSubtitleFile: subtitleFile)
        }

        return true
    }
}

extension SubtitleIndexingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .incomplete(path, reason):
            return "\(reason) Index publication was cancelled for \(path)."
        case let .stalePublication(libraryID, token):
            return "Index token \(token) no longer has publication rights for Library \(libraryID)."
        }
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
