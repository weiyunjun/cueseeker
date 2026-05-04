import Foundation

public enum RemoteIndexingProgress: Equatable, Sendable {
    case listingStarted(rootURL: String)
    case listingDirectory(path: String, visitedDirectories: Int, queuedDirectories: Int)
    case listedDirectory(path: String, entries: Int, files: Int, directories: Int, elapsedMilliseconds: Int)
    case listingCompleted(fileCount: Int, subtitleCount: Int, elapsedMilliseconds: Int)
    case subtitleStarted(index: Int, total: Int, path: String, size: Int64?)
    case subtitleDownloaded(path: String, bytes: Int, elapsedMilliseconds: Int)
    case subtitleParsed(path: String, cueGroups: Int, elapsedMilliseconds: Int)
    case assSegmented(path: String, segments: Int, elapsedMilliseconds: Int)
    case databaseWritten(path: String, elapsedMilliseconds: Int)
    case subtitleFinished(index: Int, total: Int, path: String, elapsedMilliseconds: Int)

    public var userMessage: String {
        switch self {
        case .listingStarted:
            return "Listing remote directories..."
        case .listingDirectory(let path, let visitedDirectories, let queuedDirectories):
            return "Listing \(path) (\(visitedDirectories) visited, \(queuedDirectories) queued)..."
        case .listedDirectory(let path, _, let files, let directories, let elapsedMilliseconds):
            return "Listed \(path): \(files) files, \(directories) folders in \(elapsedMilliseconds) ms"
        case .listingCompleted(let fileCount, let subtitleCount, let elapsedMilliseconds):
            return "Listed \(fileCount) files, \(subtitleCount) subtitles in \(elapsedMilliseconds) ms"
        case .subtitleStarted(let index, let total, let path, _):
            return "Indexing subtitle \(index) of \(total): \(path)"
        case .subtitleDownloaded(_, let bytes, let elapsedMilliseconds):
            return "Downloaded subtitle: \(bytes) bytes in \(elapsedMilliseconds) ms"
        case .subtitleParsed(_, let cueGroups, let elapsedMilliseconds):
            return "Parsed subtitle: \(cueGroups) cue groups in \(elapsedMilliseconds) ms"
        case .assSegmented(_, let segments, let elapsedMilliseconds):
            return "Split ASS render cache: \(segments) segments in \(elapsedMilliseconds) ms"
        case .databaseWritten(_, let elapsedMilliseconds):
            return "Wrote subtitle index in \(elapsedMilliseconds) ms"
        case .subtitleFinished(let index, let total, let path, let elapsedMilliseconds):
            return "Finished subtitle \(index) of \(total): \(path) in \(elapsedMilliseconds) ms"
        }
    }

    public var logMessage: String {
        switch self {
        case .listingStarted(let rootURL):
            return "stage=listing_start root=\"\(rootURL)\""
        case .listingDirectory(let path, let visitedDirectories, let queuedDirectories):
            return "stage=listing_directory path=\"\(path)\" visited=\(visitedDirectories) queued=\(queuedDirectories)"
        case .listedDirectory(let path, let entries, let files, let directories, let elapsedMilliseconds):
            return "stage=listed_directory path=\"\(path)\" entries=\(entries) files=\(files) directories=\(directories) elapsed_ms=\(elapsedMilliseconds)"
        case .listingCompleted(let fileCount, let subtitleCount, let elapsedMilliseconds):
            return "stage=listing_complete files=\(fileCount) subtitles=\(subtitleCount) elapsed_ms=\(elapsedMilliseconds)"
        case .subtitleStarted(let index, let total, let path, let size):
            return "stage=subtitle_start index=\(index) total=\(total) path=\"\(path)\" size=\(size.map(String.init) ?? "unknown")"
        case .subtitleDownloaded(let path, let bytes, let elapsedMilliseconds):
            return "stage=subtitle_downloaded path=\"\(path)\" bytes=\(bytes) elapsed_ms=\(elapsedMilliseconds)"
        case .subtitleParsed(let path, let cueGroups, let elapsedMilliseconds):
            return "stage=subtitle_parsed path=\"\(path)\" cue_groups=\(cueGroups) elapsed_ms=\(elapsedMilliseconds)"
        case .assSegmented(let path, let segments, let elapsedMilliseconds):
            return "stage=ass_segmented path=\"\(path)\" segments=\(segments) elapsed_ms=\(elapsedMilliseconds)"
        case .databaseWritten(let path, let elapsedMilliseconds):
            return "stage=database_written path=\"\(path)\" elapsed_ms=\(elapsedMilliseconds)"
        case .subtitleFinished(let index, let total, let path, let elapsedMilliseconds):
            return "stage=subtitle_finished index=\(index) total=\(total) path=\"\(path)\" elapsed_ms=\(elapsedMilliseconds)"
        }
    }
}

public struct RemoteSubtitleIndexer {
    private let videoExtensions: [String]

    public init(videoExtensions: [String] = VideoMatcher.defaultVideoExtensions) {
        self.videoExtensions = videoExtensions.map { $0.lowercased() }
    }

    public func index(
        source: RemoteMediaSourceConfiguration,
        into database: SubtitleDatabase,
        progress: (@Sendable (RemoteIndexingProgress) -> Void)? = nil
    ) async throws -> SubtitleIndexingResult {
        try database.migrate()

        let client = try WebDAVClient(
            rootURL: source.rootURL,
            credentials: source.credentials
        )

        var result = SubtitleIndexingResult()
        let listingStartedAt = Date()
        progress?(.listingStarted(rootURL: source.rootURL.absoluteString))
        let files = try await client.listAllFiles { listingProgress in
            switch listingProgress {
            case .willListDirectory(let path, let visitedDirectories, let queuedDirectories):
                progress?(
                    .listingDirectory(
                        path: path,
                        visitedDirectories: visitedDirectories,
                        queuedDirectories: queuedDirectories
                    )
                )
            case .didListDirectory(let path, let entries, let files, let directories, let elapsedMilliseconds):
                progress?(
                    .listedDirectory(
                        path: path,
                        entries: entries,
                        files: files,
                        directories: directories,
                        elapsedMilliseconds: elapsedMilliseconds
                    )
                )
            }
        }
        let subtitleFiles = files.filter { file in
            SubtitleFileScanner.supportedSubtitleExtensions.contains(
                URL(fileURLWithPath: file.name).pathExtension.lowercased()
            )
        }
        result.scannedSubtitleFiles = subtitleFiles.count
        progress?(
            .listingCompleted(
                fileCount: files.count,
                subtitleCount: subtitleFiles.count,
                elapsedMilliseconds: Self.elapsedMilliseconds(since: listingStartedAt)
            )
        )

        let videoFilesByKey = videoFileLookup(files: files)
        let existingFiles = Dictionary(
            uniqueKeysWithValues: try database.subtitleFiles(sourceID: source.id).map { ($0.subtitlePath, $0) }
        )
        var keptSubtitlePaths = Set<String>()

        for (index, subtitleFile) in subtitleFiles.enumerated() {
            let subtitleStartedAt = Date()
            progress?(
                .subtitleStarted(
                    index: index + 1,
                    total: subtitleFiles.count,
                    path: subtitleFile.relativePath,
                    size: subtitleFile.size
                )
            )

            guard let videoFile = matchingVideo(for: subtitleFile, in: videoFilesByKey) else {
                result.skippedMissingVideo += 1
                continue
            }

            let subtitleURL = try client.url(for: subtitleFile)
            let videoURL = try client.url(for: videoFile)
            let subtitlePath = subtitleURL.absoluteString
            let videoPath = videoURL.absoluteString

            if let metadata = existingFiles[subtitlePath],
               try isUnchanged(
                    metadata: metadata,
                    videoPath: videoPath,
                    subtitleFile: subtitleFile,
                    database: database
               )
            {
                keptSubtitlePaths.insert(subtitlePath)
                result.skippedUnchangedSubtitleFiles += 1
                continue
            }

            let contents: String
            do {
                let downloadStartedAt = Date()
                contents = try await client.downloadText(relativePath: subtitleFile.relativePath)
                progress?(
                    .subtitleDownloaded(
                        path: subtitleFile.relativePath,
                        bytes: contents.utf8.count,
                        elapsedMilliseconds: Self.elapsedMilliseconds(since: downloadStartedAt)
                    )
                )
            } catch {
                result.skippedUnreadableSubtitle += 1
                result.failedFiles.append(
                    SubtitleIndexingFailure(
                        path: subtitlePath,
                        reason: "Remote subtitle file could not be read."
                    )
                )
                continue
            }

            guard let format = subtitleFormat(fileExtension: subtitleFile.name.pathExtension) else {
                continue
            }

            let cueGroups: [SubtitleCueGroup]
            var assRenderSegments: [ASSRenderSegmentPayload] = []
            var assSourceScript: String?
            let parseStartedAt = Date()
            switch format {
            case .srt:
                cueGroups = SRTParser.parseCueGroups(contents)
            case .ass:
                cueGroups = ASSParser.parseCueGroups(contents)
            }
            progress?(
                .subtitleParsed(
                    path: subtitleFile.relativePath,
                    cueGroups: cueGroups.count,
                    elapsedMilliseconds: Self.elapsedMilliseconds(since: parseStartedAt)
                )
            )

            switch format {
            case .srt:
                break
            case .ass:
                if ASSRenderSegmenter.shouldSegment(format: format, fileSize: subtitleFile.size) {
                    let segmentStartedAt = Date()
                    assRenderSegments = ASSRenderSegmenter.renderSegments(from: contents)
                    progress?(
                        .assSegmented(
                            path: subtitleFile.relativePath,
                            segments: assRenderSegments.count,
                            elapsedMilliseconds: Self.elapsedMilliseconds(since: segmentStartedAt)
                        )
                    )
                } else {
                    assSourceScript = contents
                }
            }

            let databaseStartedAt = Date()
            try database.replaceCueGroups(
                subtitlePath: subtitlePath,
                videoPath: videoPath,
                videoName: videoFile.name,
                format: format,
                cueGroups: cueGroups,
                assRenderSegments: assRenderSegments,
                assSourceScript: assSourceScript,
                sourceID: source.id,
                subtitleRelativePath: subtitleFile.relativePath,
                videoRelativePath: videoFile.relativePath,
                fileSize: subtitleFile.size,
                modifiedAt: subtitleFile.modifiedAt,
                videoFileSize: videoFile.size,
                videoModifiedAt: videoFile.modifiedAt
            )
            progress?(
                .databaseWritten(
                    path: subtitleFile.relativePath,
                    elapsedMilliseconds: Self.elapsedMilliseconds(since: databaseStartedAt)
                )
            )

            keptSubtitlePaths.insert(subtitlePath)
            result.indexedSubtitleFiles += 1
            result.indexedSubtitleEntries += cueGroups.count
            progress?(
                .subtitleFinished(
                    index: index + 1,
                    total: subtitleFiles.count,
                    path: subtitleFile.relativePath,
                    elapsedMilliseconds: Self.elapsedMilliseconds(since: subtitleStartedAt)
                )
            )
        }

        try database.removeStaleEntries(sourceID: source.id, keeping: keptSubtitlePaths)
        return result
    }

    private func isUnchanged(
        metadata: SubtitleFileMetadata,
        videoPath: String,
        subtitleFile: WebDAVFile,
        database: SubtitleDatabase
    ) throws -> Bool {
        guard metadata.videoPath == videoPath,
              metadata.fileSize == subtitleFile.size,
              let existingModifiedAt = metadata.modifiedAt,
              let modifiedAt = subtitleFile.modifiedAt
        else {
            return false
        }

        guard abs(existingModifiedAt.timeIntervalSince1970 - modifiedAt.timeIntervalSince1970) < 0.001 else {
            return false
        }

        if ASSRenderSegmenter.shouldSegment(format: metadata.subtitleFormat, fileSize: subtitleFile.size) {
            return try database.hasASSRenderSegments(forSubtitlePath: metadata.subtitlePath)
        }

        if metadata.subtitleFormat == .ass {
            return try database.hasASSSourceScriptCache(forSubtitlePath: metadata.subtitlePath)
        }

        return true
    }

    private func videoFileLookup(files: [WebDAVFile]) -> [String: WebDAVFile] {
        var lookup: [String: WebDAVFile] = [:]
        for file in files {
            let fileExtension = URL(fileURLWithPath: file.name).pathExtension.lowercased()
            guard videoExtensions.contains(fileExtension) else {
                continue
            }

            let key = matchKey(for: file.relativePath.deletingPathExtension)
            lookup[key] = file
        }
        return lookup
    }

    private func matchingVideo(
        for subtitleFile: WebDAVFile,
        in videoFilesByKey: [String: WebDAVFile]
    ) -> WebDAVFile? {
        let subtitleBase = subtitleFile.relativePath.deletingPathExtension
        for candidate in candidateBasePaths(for: subtitleBase) {
            if let videoFile = videoFilesByKey[matchKey(for: candidate)] {
                return videoFile
            }
        }
        return nil
    }

    private func candidateBasePaths(for subtitleBasePath: String) -> [String] {
        var candidates = [subtitleBasePath]
        guard let lastSlash = subtitleBasePath.lastIndex(of: "/") else {
            return VideoMatcher().candidateBaseNames(for: subtitleBasePath)
        }

        let directory = String(subtitleBasePath[..<lastSlash])
        let fileName = String(subtitleBasePath[subtitleBasePath.index(after: lastSlash)...])
        for baseName in VideoMatcher().candidateBaseNames(for: fileName).dropFirst() {
            candidates.append(directory + "/" + baseName)
        }
        return candidates
    }

    private func matchKey(for path: String) -> String {
        path.lowercased()
    }

    private func subtitleFormat(fileExtension: String) -> SubtitleFormat? {
        switch fileExtension.lowercased() {
        case "srt":
            return .srt
        case "ass":
            return .ass
        default:
            return nil
        }
    }

    private static func elapsedMilliseconds(since startDate: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startDate) * 1_000))
    }
}

private extension String {
    var pathExtension: String {
        URL(fileURLWithPath: self).pathExtension
    }

    var deletingPathExtension: String {
        let url = URL(fileURLWithPath: self)
        return url.deletingPathExtension().path
    }
}
