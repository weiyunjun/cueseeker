import Foundation

public struct RemoteSubtitleIndexer {
    private let videoExtensions: [String]

    public init(videoExtensions: [String] = VideoMatcher.defaultVideoExtensions) {
        self.videoExtensions = videoExtensions.map { $0.lowercased() }
    }

    public func index(
        source: RemoteMediaSourceConfiguration,
        into database: SubtitleDatabase
    ) async throws -> SubtitleIndexingResult {
        try database.migrate()

        let client = try WebDAVClient(
            rootURL: source.rootURL,
            credentials: source.credentials
        )

        var result = SubtitleIndexingResult()
        let files = try await client.listAllFiles()
        let subtitleFiles = files.filter { file in
            SubtitleFileScanner.supportedSubtitleExtensions.contains(
                URL(fileURLWithPath: file.name).pathExtension.lowercased()
            )
        }
        result.scannedSubtitleFiles = subtitleFiles.count

        let videoFilesByKey = videoFileLookup(files: files)
        let existingFiles = Dictionary(
            uniqueKeysWithValues: try database.subtitleFiles(sourceID: source.id).map { ($0.subtitlePath, $0) }
        )
        var keptSubtitlePaths = Set<String>()

        for subtitleFile in subtitleFiles {
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
                contents = try await client.downloadText(relativePath: subtitleFile.relativePath)
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
            switch format {
            case .srt:
                cueGroups = SRTParser.parseCueGroups(contents)
            case .ass:
                cueGroups = ASSParser.parseCueGroups(contents)
                if ASSRenderSegmenter.shouldSegment(format: format, fileSize: subtitleFile.size) {
                    assRenderSegments = ASSRenderSegmenter.renderSegments(from: contents)
                }
            }

            try database.replaceCueGroups(
                subtitlePath: subtitlePath,
                videoPath: videoPath,
                videoName: videoFile.name,
                format: format,
                cueGroups: cueGroups,
                assRenderSegments: assRenderSegments,
                sourceID: source.id,
                subtitleRelativePath: subtitleFile.relativePath,
                videoRelativePath: videoFile.relativePath,
                fileSize: subtitleFile.size,
                modifiedAt: subtitleFile.modifiedAt,
                videoFileSize: videoFile.size,
                videoModifiedAt: videoFile.modifiedAt
            )

            keptSubtitlePaths.insert(subtitlePath)
            result.indexedSubtitleFiles += 1
            result.indexedSubtitleEntries += cueGroups.count
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
