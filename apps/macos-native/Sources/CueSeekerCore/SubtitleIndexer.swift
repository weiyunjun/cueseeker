import Foundation

public struct SubtitleIndexingResult: Equatable, Sendable {
    public var scannedSubtitleFiles: Int = 0
    public var indexedSubtitleFiles: Int = 0
    public var indexedSubtitleEntries: Int = 0
    public var skippedUnchangedSubtitleFiles: Int = 0
    public var skippedMissingVideo: Int = 0
    public var skippedUnreadableSubtitle: Int = 0
    public var failedFiles: [SubtitleIndexingFailure] = []
    public var changedSubtitlePaths: [String] = []
    public var affectedVideoPaths: [String] = []
    public var affectedFolderPaths: [String] = []
    public var clearedCueChangeNotices = false

    public var hasIndexedContentChanges: Bool {
        !changedSubtitlePaths.isEmpty || !affectedVideoPaths.isEmpty
            || !affectedFolderPaths.isEmpty
    }

    public var requiresShioriRefresh: Bool {
        hasIndexedContentChanges || clearedCueChangeNotices
    }
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
    let refreshVideoMetadata: Bool
}

struct PreparedSubtitleBindingRefresh: Sendable {
    let subtitleFile: URL
    let videoFile: URL
}

struct PreparedLibraryIndex: Sendable {
    let folder: URL
    let lease: LibraryIndexLease
    let changedFiles: [PreparedSubtitleIndexFile]
    let bindingRefreshes: [PreparedSubtitleBindingRefresh]
    let missingVideoSubtitleFiles: [URL]
    let keptSubtitlePaths: Set<String>
}

struct PublishedLibraryIndexMutation: Equatable, Sendable {
    let changedSubtitlePaths: Set<String>
    let affectedVideoPaths: Set<String>
    let affectedFolderPaths: Set<String>
    let clearedCueChangeNotices: Bool
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
        let matchingVideos = matcher.matchingVideos(for: subtitleFiles)

        let existingFiles = Dictionary(
            uniqueKeysWithValues: try database.subtitleFiles().map { ($0.subtitlePath, $0) }
        )
        let existingVideoMetadataByPath: [String: SubtitleFileMetadata] = Dictionary(
            existingFiles.values.compactMap { metadata -> (String, SubtitleFileMetadata)? in
                guard metadata.videoBindingState == .available,
                      let videoPath = metadata.videoPath
                else {
                    return nil
                }
                return (videoPath, metadata)
            },
            uniquingKeysWith: { first, _ in first }
        )
        var keptSubtitlePaths = Set<String>()
        var changedFiles: [PreparedSubtitleIndexFile] = []
        var bindingRefreshes: [PreparedSubtitleBindingRefresh] = []
        var missingVideoSubtitleFiles: [URL] = []

        for subtitleFile in subtitleFiles {
            guard let videoFile = matchingVideos[subtitleFile] else {
                keptSubtitlePaths.insert(subtitleFile.path)
                missingVideoSubtitleFiles.append(subtitleFile)
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
               try isSubtitleContentUnchanged(
                    metadata: metadata,
                    subtitleFile: subtitleFile,
                    database: database,
                    playbackDatabase: playbackDatabase,
                    fileSize: fileSize,
                    modifiedAt: modifiedAt
               )
            {
                keptSubtitlePaths.insert(subtitleFile.path)
                if videoBindingNeedsRefresh(
                    metadata: metadata,
                    videoFile: videoFile
                ) {
                    bindingRefreshes.append(
                        PreparedSubtitleBindingRefresh(
                            subtitleFile: subtitleFile,
                            videoFile: videoFile
                        )
                    )
                }
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
                    languageAnalysis: languageAnalysis,
                    refreshVideoMetadata: existingVideoMetadataByPath[
                        videoFile.path
                    ].map {
                        videoBindingNeedsRefresh(
                            metadata: $0,
                            videoFile: videoFile
                        )
                    } ?? true
                )
            )

            keptSubtitlePaths.insert(subtitleFile.path)
            result.indexedSubtitleFiles += 1
            result.indexedSubtitleEntries += cueGroups.count
        }

        let mutation = try database.publishLibraryIndex(
            PreparedLibraryIndex(
                folder: folder,
                lease: lease,
                changedFiles: changedFiles,
                bindingRefreshes: bindingRefreshes,
                missingVideoSubtitleFiles: missingVideoSubtitleFiles,
                keptSubtitlePaths: keptSubtitlePaths
            )
        )
        result.changedSubtitlePaths = mutation.changedSubtitlePaths.sorted()
        result.affectedVideoPaths = mutation.affectedVideoPaths.sorted()
        result.affectedFolderPaths = mutation.affectedFolderPaths.sorted()
        result.clearedCueChangeNotices =
            mutation.clearedCueChangeNotices

        return result
    }

    private func isSubtitleContentUnchanged(
        metadata: SubtitleFileMetadata,
        subtitleFile: URL,
        database: IndexingDatabase,
        playbackDatabase: PlaybackSubtitleDatabase,
        fileSize: Int64?,
        modifiedAt: Date?
    ) throws -> Bool {
        guard metadata.fileSize == fileSize,
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

    private func videoBindingNeedsRefresh(
        metadata: SubtitleFileMetadata,
        videoFile: URL
    ) -> Bool {
        guard metadata.videoBindingState == .available,
              metadata.videoPath == videoFile.path
        else {
            return true
        }

        let attributes = try? FileManager.default.attributesOfItem(
            atPath: videoFile.path
        )
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value
        let modifiedAt = attributes?[.modificationDate] as? Date
        guard metadata.videoFileSize == fileSize,
              let storedModifiedAt = metadata.videoModifiedAt,
              let modifiedAt,
              abs(
                storedModifiedAt.timeIntervalSince1970
                    - modifiedAt.timeIntervalSince1970
              ) < 0.001
        else {
            return true
        }

        return metadata.videoResourceIdentity
            != FileResourceIdentityResolver.resourceIdentifier(for: videoFile)
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
