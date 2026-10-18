import Foundation

public enum LibraryPresentationRefreshRequest: Equatable, Sendable {
    case none
    case affectedFolders([String])
    case fullLibrary
}

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
    public var libraryID: Int64?
    public var pendingVideoMetadataPaths: [String] = []
    public var presentationRefreshRequest:
        LibraryPresentationRefreshRequest = .none

    public init() {}

    public var hasIndexedContentChanges: Bool {
        !changedSubtitlePaths.isEmpty || !affectedVideoPaths.isEmpty
            || !affectedFolderPaths.isEmpty
    }

    public var requiresExcerptRefresh: Bool {
        hasIndexedContentChanges || clearedCueChangeNotices
    }
}

public struct SubtitleIndexingFailure: Equatable, Sendable {
    public let path: String
    public let reason: String
}

public enum SubtitleIndexingError: Error, Equatable, Sendable {
    case incomplete(path: String, reason: String)
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
    let videoFileSize: Int64?
    let videoModifiedAt: Date?
    let languageAnalysis: SubtitleLanguageAnalysis
    let refreshVideoMetadata: Bool
}

struct SubtitleFileObservation: Equatable, Sendable {
    let fileSize: Int64?
    let modifiedAt: Date?

    static func capture(_ file: URL) throws -> SubtitleFileObservation {
        let attributes = try FileManager.default.attributesOfItem(
            atPath: file.path
        )
        return SubtitleFileObservation(
            fileSize: (attributes[.size] as? NSNumber)?.int64Value,
            modifiedAt: attributes[.modificationDate] as? Date
        )
    }
}

struct PreparedSubtitleBindingRefresh: Sendable {
    let subtitleFile: URL
    let videoFile: URL
    let videoFileSize: Int64?
    let videoModifiedAt: Date?
}

struct PreparedLibraryIndex: Sendable {
    let folder: URL
    let changedFiles: [PreparedSubtitleIndexFile]
    let bindingRefreshes: [PreparedSubtitleBindingRefresh]
    let missingVideoSubtitleFiles: [URL]
    let keptSubtitlePaths: Set<String>
}

struct PublishedLibraryIndexMutation: Equatable, Sendable {
    let libraryID: Int64
    let changedSubtitlePaths: Set<String>
    let affectedVideoPaths: Set<String>
    let affectedFolderPaths: Set<String>
    let clearedCueChangeNotices: Bool
    let pendingVideoMetadataPaths: Set<String>
    let presentationRefreshRequest: LibraryPresentationRefreshRequest
}

public struct SubtitleIndexer {
    private let scanner: SubtitleFileScanner
    private let matcher: VideoMatcher
    private let languageAnalyzer: SubtitleLanguageAnalyzer
    private let loadSubtitleData: (URL) throws -> Data

    public init(
        scanner: SubtitleFileScanner = SubtitleFileScanner(),
        matcher: VideoMatcher = VideoMatcher(),
        languageAnalyzer: SubtitleLanguageAnalyzer = SubtitleLanguageAnalyzer()
    ) {
        self.init(
            scanner: scanner,
            matcher: matcher,
            languageAnalyzer: languageAnalyzer,
            loadSubtitleData: { url in
                if url.isWebDAVURL {
                    let data = try WebDAVClient.shared.downloadData(from: url)
                    _ = try? WebDAVSubtitleCache.shared.storeSubtitleData(data, for: url)
                    return data
                }
                return try Data(contentsOf: url)
            }
        )
    }

    init(
        scanner: SubtitleFileScanner = SubtitleFileScanner(),
        matcher: VideoMatcher = VideoMatcher(),
        languageAnalyzer: SubtitleLanguageAnalyzer = SubtitleLanguageAnalyzer(),
        loadSubtitleData: @escaping (URL) throws -> Data
    ) {
        self.scanner = scanner
        self.matcher = matcher
        self.languageAnalyzer = languageAnalyzer
        self.loadSubtitleData = loadSubtitleData
    }

    /// `onProgress` reports how many subtitle files have been gone through and
    /// how many there are. The first report comes once the folder has been
    /// scanned and its videos matched, which is what tells a caller drawing a
    /// progress bar that the scan is over.
    ///
    /// A cancelled task stops between files, and nothing is published until
    /// every file has been gone through, so a stopped Index leaves this folder
    /// as it was.
    public func index(
        folder: URL,
        into database: IndexingDatabase,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) throws -> SubtitleIndexingResult {
        let isWebDAV = folder.isWebDAVURL
        if !isWebDAV {
            try scanner.validateReadableDirectory(folder)
        }
        let playbackDatabase = try PlaybackSubtitleDatabase(path: database.path)

        var result = SubtitleIndexingResult()
        let subtitleFiles: [URL]
        let matchingVideos: [URL: URL]
        var remoteObservationsByMediaPath: [String: SubtitleFileObservation] = [:]

        if isWebDAV {
            let remoteFiles: [WebDAVRemoteFile]
            do {
                remoteFiles = try WebDAVClient.shared.scanDirectoryTree(rootURL: folder)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw SubtitleIndexingError.incomplete(
                    path: folder.mediaPath,
                    reason: "Library scan did not complete: \(error)"
                )
            }
            for remoteFile in remoteFiles {
                remoteObservationsByMediaPath[remoteFile.url.mediaPath] = SubtitleFileObservation(
                    fileSize: remoteFile.fileSize,
                    modifiedAt: remoteFile.modifiedAt
                )
            }
            let allRemoteURLs = remoteFiles.map(\.url)
            subtitleFiles = allRemoteURLs
                .filter {
                    SubtitleFileScanner.supportedSubtitleExtensions.contains(
                        $0.pathExtension.lowercased()
                    )
                }
                .sorted { $0.mediaPath < $1.mediaPath }
            result.scannedSubtitleFiles = subtitleFiles.count
            matchingVideos = matcher.matchingVideos(
                for: subtitleFiles,
                among: allRemoteURLs
            )
        } else {
            do {
                subtitleFiles = try scanner.scanSubtitleFilesSafely(in: folder)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw SubtitleIndexingError.incomplete(
                    path: folder.mediaPath,
                    reason: "Library scan did not complete: \(error)"
                )
            }
            result.scannedSubtitleFiles = subtitleFiles.count
            do {
                matchingVideos = try matcher.matchingVideos(for: subtitleFiles)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw SubtitleIndexingError.incomplete(
                    path: folder.mediaPath,
                    reason: "Video matching scan did not complete: \(error)"
                )
            }
        }

        onProgress?(0, subtitleFiles.count)

        let existingFiles = Dictionary(
            uniqueKeysWithValues: try database.subtitleFiles().map { ($0.subtitlePath, $0) }
        )
        let existingVideoMetadataByPath: [String: SubtitleFileMetadata] = Dictionary(
            existingFiles.values.compactMap { metadata -> (String, SubtitleFileMetadata)? in
                guard let videoPath = metadata.videoPath else {
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

        for (offset, subtitleFile) in subtitleFiles.enumerated() {
            try Task.checkCancellation()
            defer { onProgress?(offset + 1, subtitleFiles.count) }
            let subtitleMediaPath = subtitleFile.mediaPath

            guard let videoFile = matchingVideos[subtitleFile] else {
                keptSubtitlePaths.insert(subtitleMediaPath)
                missingVideoSubtitleFiles.append(subtitleFile)
                result.skippedMissingVideo += 1
                continue
            }

            let observation: SubtitleFileObservation
            if isWebDAV {
                if let remoteObservation = remoteObservationsByMediaPath[subtitleMediaPath] {
                    observation = remoteObservation
                } else {
                    recordFileFailure(
                        subtitleFile,
                        reason: "Subtitle metadata could not be read.",
                        result: &result,
                        keptSubtitlePaths: &keptSubtitlePaths
                    )
                    continue
                }
            } else {
                do {
                    observation = try SubtitleFileObservation.capture(subtitleFile)
                } catch {
                    recordFileFailure(
                        subtitleFile,
                        reason: "Subtitle metadata could not be read.",
                        result: &result,
                        keptSubtitlePaths: &keptSubtitlePaths
                    )
                    continue
                }
            }

            let videoObservation: SubtitleFileObservation?
            if isWebDAV {
                videoObservation = remoteObservationsByMediaPath[videoFile.mediaPath]
            } else {
                videoObservation = try? SubtitleFileObservation.capture(videoFile)
            }

            if let metadata = existingFiles[subtitleMediaPath],
               try isSubtitleContentUnchanged(
                    metadata: metadata,
                    subtitleFile: subtitleFile,
                    database: database,
                    playbackDatabase: playbackDatabase,
                    fileSize: observation.fileSize,
                    modifiedAt: observation.modifiedAt
               )
            {
                keptSubtitlePaths.insert(subtitleMediaPath)
                if isWebDAV {
                    let cachedURL = WebDAVSubtitleCache.shared.cachedFileURL(for: subtitleFile)
                    if !FileManager.default.fileExists(atPath: cachedURL.path),
                       let data = try? loadSubtitleData(subtitleFile) {
                        _ = try? WebDAVSubtitleCache.shared.storeSubtitleData(data, for: subtitleFile)
                    }
                }
                if videoBindingNeedsRefresh(
                    metadata: metadata,
                    videoFile: videoFile,
                    videoObservation: videoObservation
                ) {
                    bindingRefreshes.append(
                        PreparedSubtitleBindingRefresh(
                            subtitleFile: subtitleFile,
                            videoFile: videoFile,
                            videoFileSize: videoObservation?.fileSize,
                            videoModifiedAt: videoObservation?.modifiedAt
                        )
                    )
                }
                result.skippedUnchangedSubtitleFiles += 1
                continue
            }

            guard let format = SubtitleFormat(fileExtension: subtitleFile.pathExtension) else {
                continue
            }

            let data: Data
            do {
                data = try loadSubtitleData(subtitleFile)
            } catch {
                recordFileFailure(
                    subtitleFile,
                    reason: "Subtitle file could not be read: \(error.localizedDescription)",
                    result: &result,
                    keptSubtitlePaths: &keptSubtitlePaths
                )
                continue
            }

            let contents: String
            do {
                contents = try SubtitleTextDecoder.decode(data, format: format)
            } catch {
                recordFileFailure(
                    subtitleFile,
                    reason: "Subtitle file could not be decoded: \(error.localizedDescription)",
                    result: &result,
                    keptSubtitlePaths: &keptSubtitlePaths
                )
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
                    if ASSRenderSegmenter.shouldSegment(
                        format: format,
                        fileSize: observation.fileSize
                    ) {
                        assRenderSegments = ASSRenderSegmenter.renderSegments(from: contents)
                    }
                }
            } catch {
                recordFileFailure(
                    subtitleFile,
                    reason: "Subtitle parsing did not complete: \(error)",
                    result: &result,
                    keptSubtitlePaths: &keptSubtitlePaths
                )
                continue
            }

            let finalObservation: SubtitleFileObservation
            if isWebDAV {
                finalObservation = observation
            } else {
                do {
                    finalObservation = try SubtitleFileObservation.capture(
                        subtitleFile
                    )
                } catch {
                    recordFileFailure(
                        subtitleFile,
                        reason: "Subtitle metadata could not be revalidated.",
                        result: &result,
                        keptSubtitlePaths: &keptSubtitlePaths
                    )
                    continue
                }
            }
            guard finalObservation == observation else {
                recordFileFailure(
                    subtitleFile,
                    reason: "Subtitle file changed while it was being indexed.",
                    result: &result,
                    keptSubtitlePaths: &keptSubtitlePaths
                )
                continue
            }

            guard !cueGroups.isEmpty else {
                continue
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
                    fileSize: observation.fileSize,
                    modifiedAt: observation.modifiedAt,
                    videoFileSize: videoObservation?.fileSize,
                    videoModifiedAt: videoObservation?.modifiedAt,
                    languageAnalysis: languageAnalysis,
                    refreshVideoMetadata: existingVideoMetadataByPath[
                        videoFile.mediaPath
                    ].map {
                        videoBindingNeedsRefresh(
                            metadata: $0,
                            videoFile: videoFile,
                            videoObservation: videoObservation
                        )
                    } ?? true
                )
            )

            keptSubtitlePaths.insert(subtitleMediaPath)
            result.indexedSubtitleFiles += 1
            result.indexedSubtitleEntries += cueGroups.count
        }

        let mutation = try database.publishLibraryIndex(
            PreparedLibraryIndex(
                folder: folder,
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
        result.libraryID = mutation.libraryID
        result.pendingVideoMetadataPaths =
            mutation.pendingVideoMetadataPaths.sorted()
        result.presentationRefreshRequest =
            mutation.presentationRefreshRequest

        return result
    }

    private func recordFileFailure(
        _ subtitleFile: URL,
        reason: String,
        result: inout SubtitleIndexingResult,
        keptSubtitlePaths: inout Set<String>
    ) {
        let subtitleMediaPath = subtitleFile.mediaPath
        keptSubtitlePaths.insert(subtitleMediaPath)
        result.skippedUnreadableSubtitle += 1
        result.failedFiles.append(
            SubtitleIndexingFailure(
                path: subtitleMediaPath,
                reason: reason
            )
        )
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

        guard try database.firstCueGroupID(forSubtitleFile: subtitleFile) != nil else {
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
        videoFile: URL,
        videoObservation: SubtitleFileObservation?
    ) -> Bool {
        guard metadata.videoPath == videoFile.mediaPath else {
            return true
        }

        let fileSize = videoObservation?.fileSize
        let modifiedAt = videoObservation?.modifiedAt
        return !(
            metadata.videoFileSize == fileSize
                && metadata.videoModifiedAt.map { storedModifiedAt in
                    modifiedAt.map {
                        abs(
                            storedModifiedAt.timeIntervalSince1970
                                - $0.timeIntervalSince1970
                        ) < 0.001
                    } ?? false
                } ?? false
        )
    }
}

extension SubtitleIndexingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .incomplete(path, reason):
            return "\(reason) Index publication was cancelled for \(path)."
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
