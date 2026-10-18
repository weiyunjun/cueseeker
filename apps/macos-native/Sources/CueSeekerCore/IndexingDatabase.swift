import Foundation

public final class IndexingDatabase: @unchecked Sendable {
    let path: URL
    let database: SQLiteDatabase

    struct LibraryPathRecord {
        let id: Int64
        let rootURL: URL
    }

    private struct MediaPathIdentity {
        let libraryID: Int64
        let relativePath: String
    }

    private struct BoundResourceRecord {
        let id: Int64
        let path: String
    }

    private struct UpsertedSubtitleFile {
        let id: Int64
        let previousPath: String?
    }

    private struct IndexedFileMutation {
        let subtitlePath: String
        let previousSubtitlePath: String?
        let videoPath: String
    }

    private struct ReconciledVideoMutation {
        var videoPaths = Set<String>()
        var folderPaths = Set<String>()
    }

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        self.path = path
        database = try SQLiteDatabase(path: path, access: access)
    }

    private static func cueTimeRange(startMilliseconds: Int, endMilliseconds: Int) -> String {
        SubtitleCueTimeRangeDisplay.text(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
    }

    @discardableResult
    public func addSearchPath(_ folder: URL, type: String = "local") throws -> Int64 {
        try database.withImmediateTransaction {
            try bindSearchPathInCurrentTransaction(folder, type: type)
        }
    }

    /// Binds a Library to its absolute path. The path is the only identity.
    private func bindSearchPathInCurrentTransaction(
        _ folder: URL,
        type: String = "local"
    ) throws -> Int64 {
        let effectiveType = folder.isWebDAVURL ? "webdav" : type
        let standardizedFolder = folder.standardizedMediaURL
        let folderMediaPath = standardizedFolder.mediaPath
        let now = ISO8601DateFormatter().string(from: Date())

        let libraryID: Int64
        if let matchingPath = try searchPathRecord(path: folderMediaPath) {
            try touchSearchPath(matchingPath, type: effectiveType, updatedAt: now)
            libraryID = matchingPath.id
        } else {
            libraryID = try insertSearchPath(
                path: folderMediaPath,
                type: effectiveType,
                createdAt: now
            )
        }

        try backfillMediaPathIdentities(libraryID: libraryID, rootURL: standardizedFolder)
        try adoptNestedLibraries(into: libraryID, rootURL: standardizedFolder)
        return libraryID
    }

    /// A root that holds other roots speaks for them, so the Libraries nested
    /// inside this one fold into it. Their files, folders and folder covers
    /// keep their rows and only change hands; nothing is parsed again. The way
    /// back is `separateNestedLibrary`.
    private func adoptNestedLibraries(into libraryID: Int64, rootURL: URL) throws {
        for nested in try libraryPathRecords() where nested.id != libraryID {
            guard let prefix = Self.relativeMediaPath(for: nested.rootURL, under: rootURL) else {
                continue
            }
            try moveLibraryContent(from: nested.id, to: libraryID) { relativePath in
                relativePath.isEmpty ? prefix : prefix + "/" + relativePath
            }
            if try libraryPresentationRetryPending(libraryID: nested.id) {
                try markLibraryPresentationRetryPending(libraryID: libraryID)
            }
            let statement = try database.prepare("DELETE FROM search_paths WHERE id = ?;")
            try statement.bind(nested.id, at: 1)
            try statement.run()
        }
    }

    /// Gives a root that another root held its own Library back, for when the
    /// root that held it goes and it stays. Its files and folders leave the
    /// holder with their rows and covers intact. Answers the subtitle files it
    /// now holds.
    private func separateNestedLibrary(_ root: URL) throws -> Set<String> {
        let libraryID = try bindSearchPathInCurrentTransaction(root)
        let rootURL = root.standardizedMediaURL
        for holder in try libraryPathRecords() where holder.id != libraryID {
            guard let prefix = Self.relativeMediaPath(for: rootURL, under: holder.rootURL) else {
                continue
            }
            try moveLibraryContent(from: holder.id, to: libraryID) { relativePath in
                if relativePath == prefix {
                    return ""
                }
                guard relativePath.hasPrefix(prefix + "/") else {
                    return nil
                }
                return String(relativePath.dropFirst(prefix.count + 1))
            }
        }

        let statement = try database.prepare(
            "SELECT subtitle_path FROM subtitle_files WHERE library_id = ?;"
        )
        try statement.bind(libraryID, at: 1)
        var subtitlePaths = Set<String>()
        while try statement.step() {
            subtitlePaths.insert(statement.stringColumn(0))
        }
        return subtitlePaths
    }

    /// Hands rows from one Library to another under the relative path
    /// `relativePath` gives each; a row it answers nil for stays.
    private func moveLibraryContent(
        from sourceID: Int64,
        to targetID: Int64,
        relativePath: (String) -> String?
    ) throws {
        for table in ["subtitle_files", "video_files", "library_folders"] {
            let select = try database.prepare(
                "SELECT id, relative_path FROM \(table) WHERE library_id = ?;"
            )
            try select.bind(sourceID, at: 1)
            var moves: [(id: Int64, relativePath: String)] = []
            while try select.step() {
                if let moved = relativePath(select.stringColumn(1)) {
                    moves.append((select.int64Column(0), moved))
                }
            }

            let update = try database.prepare(
                "UPDATE \(table) SET library_id = ?, relative_path = ? WHERE id = ?;"
            )
            for move in moves {
                try update.bind(targetID, at: 1)
                try update.bind(move.relativePath, at: 2)
                try update.bind(move.id, at: 3)
                try update.run()
                try update.reset()
            }
        }
    }

    func publishLibraryIndex(
        _ index: PreparedLibraryIndex
    ) throws -> PublishedLibraryIndexMutation {
        for file in index.changedFiles {
            try validateLanguageAnalysis(
                file.languageAnalysis,
                format: file.format,
                cueGroupCount: file.cueGroups.count
            )
        }

        return try database.withImmediateTransaction {
            let libraryID = try bindSearchPathInCurrentTransaction(
                index.folder
            )
            let hadPendingPresentationRefresh =
                try libraryPresentationRetryPending(
                    libraryID: libraryID
                )

            let clearedCueChangeNotices = try clearPriorCueChangeNotices(
                libraryID: libraryID
            )
            var changedSubtitlePaths = Set<String>()
            var affectedVideoPaths = Set<String>()
            var affectedFolderPaths = Set<String>()

            for file in index.changedFiles {
                let mutation = try replaceCueGroupsInCurrentTransaction(
                    subtitleFile: file.subtitleFile,
                    videoFile: file.videoFile,
                    format: file.format,
                    cueGroups: file.cueGroups,
                    assRenderSegments: file.assRenderSegments,
                    assFontReferences: file.assFontReferences,
                    fileSize: file.fileSize,
                    modifiedAt: file.modifiedAt,
                    videoFileSize: file.videoFileSize,
                    videoModifiedAt: file.videoModifiedAt,
                    languageAnalysis: file.languageAnalysis,
                    playbackFinishMetadata: Self.playbackFinishMetadata(
                        format: file.format,
                        cueGroups: file.cueGroups
                    ),
                    libraryID: libraryID,
                    rebuildSearchDerivedIndex: false
                )
                changedSubtitlePaths.insert(mutation.subtitlePath)
                if file.refreshVideoMetadata {
                    affectedVideoPaths.insert(mutation.videoPath)
                }
                affectedFolderPaths.insert(
                    Self.folderPath(forSubtitlePath: mutation.subtitlePath)
                )
                if let previousPath = mutation.previousSubtitlePath {
                    affectedFolderPaths.insert(
                        Self.folderPath(forSubtitlePath: previousPath)
                    )
                }
            }

            for file in index.bindingRefreshes {
                guard let subtitleFile = try subtitleFileRecord(path: file.subtitleFile.mediaPath) else {
                    throw SQLiteDatabaseError.stepFailed(
                        "Subtitle binding disappeared before index publication."
                    )
                }
                let videoFileID = try upsertVideoFile(
                    file.videoFile,
                    fileSize: file.videoFileSize,
                    modifiedAt: file.videoModifiedAt,
                    libraryID: libraryID
                )
                try upsertSubtitleVideoMatch(
                    subtitleFileID: subtitleFile.id,
                    videoFileID: videoFileID
                )
                affectedVideoPaths.insert(file.videoFile.mediaPath)
                affectedFolderPaths.insert(
                    file.subtitleFile.deletingLastPathComponent().mediaPath
                )
            }

            affectedFolderPaths.formUnion(
                try removeIndexedDataInCurrentTransaction(
                    under: index.folder,
                    keeping: index.keptSubtitlePaths,
                    missingVideoSubtitlePaths: Set(
                        index.missingVideoSubtitleFiles.map(\.mediaPath)
                    ),
                    removeSearchPath: false,
                    rebuildSearchDerivedIndex: false,
                    unavailableReason: .subtitleMissing
                )
            )
            try deleteOrphanedVideoFiles()
            try deleteEmptyLibraryFolders(libraryID: libraryID)
            if !affectedFolderPaths.isEmpty {
                try refreshSearchOrderRows(
                    affectedFolderPaths: affectedFolderPaths
                )
                try markLibraryPresentationRetryPending(
                    libraryID: libraryID
                )
            }
            try markVideoMetadataRetryPending(
                videoPaths: affectedVideoPaths
            )
            let pendingVideoMetadataPaths =
                try pendingVideoMetadataPaths(
                    libraryID: libraryID
                )
            let presentationRefreshRequest:
                LibraryPresentationRefreshRequest
            if hadPendingPresentationRefresh {
                presentationRefreshRequest = .fullLibrary
            } else if affectedFolderPaths.isEmpty {
                presentationRefreshRequest = .none
            } else {
                presentationRefreshRequest = .affectedFolders(
                    affectedFolderPaths.sorted()
                )
            }

            let publish = try database.prepare(
                """
                UPDATE search_paths
                SET last_successful_index_at = ?,
                    updated_at = ?
                WHERE id = ?;
                """
            )
            let publishedAt = ISO8601DateFormatter().string(from: Date())
            try publish.bind(publishedAt, at: 1)
            try publish.bind(publishedAt, at: 2)
            try publish.bind(libraryID, at: 3)
            try publish.run()
            if !affectedFolderPaths.isEmpty {
                try CueFacetCountCache.rebuildAll(on: database)
            }

            return PublishedLibraryIndexMutation(
                libraryID: libraryID,
                changedSubtitlePaths: changedSubtitlePaths,
                affectedVideoPaths: affectedVideoPaths,
                affectedFolderPaths: affectedFolderPaths,
                clearedCueChangeNotices: clearedCueChangeNotices,
                pendingVideoMetadataPaths:
                    pendingVideoMetadataPaths,
                presentationRefreshRequest:
                    presentationRefreshRequest
            )
        }
    }

    private func libraryPresentationRetryPending(
        libraryID: Int64
    ) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT presentation_retry_pending
            FROM search_paths
            WHERE id = ?;
            """
        )
        try statement.bind(libraryID, at: 1)
        return try statement.step() && statement.intColumn(0) != 0
    }

    private func markLibraryPresentationRetryPending(
        libraryID: Int64
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE search_paths
            SET presentation_retry_pending = 1
            WHERE id = ?;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.run()
    }

    private func markVideoMetadataRetryPending(
        videoPaths: Set<String>
    ) throws {
        guard !videoPaths.isEmpty else {
            return
        }
        let placeholders = videoPaths.map { _ in "?" }
            .joined(separator: ", ")
        let statement = try database.prepare(
            """
            UPDATE video_files
            SET duration_retry_pending = 1
            WHERE path IN (\(placeholders));
            """
        )
        for (offset, path) in videoPaths.sorted().enumerated() {
            try statement.bind(path, at: Int32(offset + 1))
        }
        try statement.run()
    }

    private func pendingVideoMetadataPaths(
        libraryID: Int64
    ) throws -> Set<String> {
        let statement = try database.prepare(
            """
            SELECT path
            FROM video_files
            WHERE library_id = ?
              AND (duration_retry_pending = 1 OR audio_tracks IS NULL)
            ORDER BY path ASC;
            """
        )
        try statement.bind(libraryID, at: 1)
        var paths = Set<String>()
        while try statement.step() {
            paths.insert(statement.stringColumn(0))
        }
        return paths
    }

    public func replaceEntries(
        subtitleFile: URL,
        videoFile: URL,
        entries: [SubtitleEntry],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: .srt,
            cueGroups: entries.enumerated().map { index, entry in
                entry.cueGroup(eventIndex: index)
            },
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            languageAnalysis: nil
        )
    }

    public func replaceEntries(
        subtitleFile: URL,
        videoFile: URL,
        entries: [SubtitleEntry],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil,
        languageAnalysis: SubtitleLanguageAnalysis
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: .srt,
            cueGroups: entries.enumerated().map { index, entry in
                entry.cueGroup(eventIndex: index)
            },
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            languageAnalysis: languageAnalysis
        )
    }

    public func replaceCueGroups(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload] = [],
        assFontReferences: [ASSFontReferenceIntent] = [],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: format,
            cueGroups: cueGroups,
            assRenderSegments: assRenderSegments,
            assFontReferences: assFontReferences,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            languageAnalysis: nil
        )
    }

    public func replaceCueGroups(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload] = [],
        assFontReferences: [ASSFontReferenceIntent] = [],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil,
        languageAnalysis: SubtitleLanguageAnalysis
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
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
    }

    func replaceCueGroupsForIndexingBatch(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload],
        assFontReferences: [ASSFontReferenceIntent],
        fileSize: Int64?,
        modifiedAt: Date?,
        languageAnalysis: SubtitleLanguageAnalysis
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: format,
            cueGroups: cueGroups,
            assRenderSegments: assRenderSegments,
            assFontReferences: assFontReferences,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            languageAnalysis: languageAnalysis,
            rebuildSearchDerivedIndex: false
        )
    }

    private func replaceCueGroupsPersistingLanguageAnalysis(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload] = [],
        assFontReferences: [ASSFontReferenceIntent] = [],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil,
        languageAnalysis: SubtitleLanguageAnalysis?,
        rebuildSearchDerivedIndex: Bool = true
    ) throws {
        try validateLanguageAnalysis(languageAnalysis, format: format, cueGroupCount: cueGroups.count)
        let playbackFinishMetadata = Self.playbackFinishMetadata(format: format, cueGroups: cueGroups)
        try database.withImmediateTransaction {
            _ = try replaceCueGroupsInCurrentTransaction(
                subtitleFile: subtitleFile,
                videoFile: videoFile,
                format: format,
                cueGroups: cueGroups,
                assRenderSegments: assRenderSegments,
                assFontReferences: assFontReferences,
                fileSize: fileSize,
                modifiedAt: modifiedAt,
                languageAnalysis: languageAnalysis,
                playbackFinishMetadata: playbackFinishMetadata,
                libraryID: nil,
                rebuildSearchDerivedIndex: rebuildSearchDerivedIndex
            )
            try deleteOrphanedVideoFiles()
            if rebuildSearchDerivedIndex {
                try CueFacetCountCache.rebuildAll(on: database)
            }
        }
    }

    private func replaceCueGroupsInCurrentTransaction(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload],
        assFontReferences: [ASSFontReferenceIntent],
        fileSize: Int64?,
        modifiedAt: Date?,
        videoFileSize: Int64? = nil,
        videoModifiedAt: Date? = nil,
        languageAnalysis: SubtitleLanguageAnalysis?,
        playbackFinishMetadata: SubtitlePlaybackFinishMetadata,
        libraryID: Int64?,
        rebuildSearchDerivedIndex: Bool
    ) throws -> IndexedFileMutation {
        let upsertedSubtitleFile = try upsertSubtitleFile(
            subtitleFile: subtitleFile,
            format: format,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            libraryID: libraryID
        )
        let subtitleFileID = upsertedSubtitleFile.id
        try clearPriorCueChangeNotices(
            subtitleFileID: subtitleFileID
        )
        let storedCueStates = try storedCueStates(subtitleFileID: subtitleFileID)
        let newCueLines = cueGroups.flatMap(\.cueLines)
        let identityAssignments = CueIdentityReconciler.reconcile(
            storedCues: storedCueStates.map(\.identity),
            newCues: newCueLines
        )
        try deleteIndexedSubtitlePath(
            subtitleFile.mediaPath,
            preserveFileIdentity: true,
            unavailableReason: .cueMissing
        )

        let videoFileID = try upsertVideoFile(
            videoFile,
            fileSize: videoFileSize,
            modifiedAt: videoModifiedAt,
            libraryID: libraryID
        )
        try upsertSubtitleVideoMatch(subtitleFileID: subtitleFileID, videoFileID: videoFileID)
        try insertPlaybackFinishMetadata(
            subtitleFileID: subtitleFileID,
            subtitleFile: subtitleFile,
            metadata: playbackFinishMetadata
        )

        if format == .ass {
            try insertASSFontReferenceManifest(
                subtitleFileID: subtitleFileID,
                referencedFontCount: assFontReferences.count
            )
            for reference in assFontReferences {
                try insertASSFontReference(subtitleFileID: subtitleFileID, reference: reference)
            }
        }

        for segment in assRenderSegments {
            try insertASSRenderSegment(subtitleFileID: subtitleFileID, segment: segment)
        }

        if let languageAnalysis {
            try insertSubtitleLanguageManifest(
                subtitleFileID: subtitleFileID,
                detectionCount: languageAnalysis.styleDetections.count + (languageAnalysis.fileDetection == nil ? 0 : 1),
                cueGroupCount: languageAnalysis.cueGroupLanguages.count
            )
            if let fileDetection = languageAnalysis.fileDetection {
                try insertSubtitleLanguageDetection(
                    subtitleFileID: subtitleFileID,
                    scope: .file,
                    scopeKey: nil,
                    detection: fileDetection
                )
            }
            for styleName in languageAnalysis.styleDetections.keys.sorted() {
                guard let detection = languageAnalysis.styleDetections[styleName] else {
                    continue
                }
                try insertSubtitleLanguageDetection(
                    subtitleFileID: subtitleFileID,
                    scope: .style,
                    scopeKey: styleName,
                    detection: detection
                )
            }
        }

        var newCueIndex = 0
        let ftsSequences = SearchFTSRows.sequences(for: cueGroups)
        let lineLanguageDetections = CueLineLanguages.detections(from: languageAnalysis)
        for (index, group) in cueGroups.enumerated() {
            let cueGroupID = try insertCueGroup(
                subtitleFileID: subtitleFileID,
                subtitleFile: subtitleFile,
                group: group
            )
            let ftsRowID = SearchFTSRows.rowID(
                subtitleFileID: subtitleFileID,
                sequence: ftsSequences[index]
            )
            for line in group.cueLines {
                let assignment = identityAssignments[newCueIndex]
                let resolvedLanguages = CueLineLanguages.resolve(
                    sourceFormat: line.sourceFormat,
                    sourceStyle: line.sourceStyle,
                    content: line.content,
                    fileFormat: format,
                    groupLineCount: group.cueLines.count,
                    detections: lineLanguageDetections,
                    cueGroupLanguages: languageAnalysis?.cueGroupLanguages[index] ?? []
                )
                let cueLineID = try insertCueLine(
                    subtitleFileID: subtitleFileID,
                    cueGroupID: cueGroupID,
                    ftsRowID: ftsRowID,
                    languageMask: CueLineLanguages.mask(for: resolvedLanguages),
                    line: line,
                    cueID: assignment?.cueID
                )
                try CueLineLanguages.insert(
                    on: database,
                    cueID: cueLineID,
                    languages: resolvedLanguages
                )
                try deleteCueTombstone(cueID: cueLineID)
                if let assignment,
                   assignment.previousContent != line.content
                {
                    try insertCueChangeNotice(
                        cueID: cueLineID,
                        previousContent: assignment.previousContent,
                        currentContent: line.content
                    )
                }
                newCueIndex += 1
            }
            try SearchFTSRows.insert(
                on: database,
                rowID: ftsRowID,
                cueGroupID: cueGroupID,
                content: group.searchContent
            )
            if let languages = languageAnalysis?.cueGroupLanguages[index] {
                try insertCueGroupLanguages(cueGroupID: cueGroupID, languages: languages)
            }
        }
        try recomputeTombstoneUnavailableReasons(
            subtitleFileID: subtitleFileID
        )
        try reconcileExcerptListRecentCues()

        if rebuildSearchDerivedIndex {
            try rebuildSearchDerivedIndexInCurrentTransaction()
        }
        return IndexedFileMutation(
            subtitlePath: subtitleFile.mediaPath,
            previousSubtitlePath: upsertedSubtitleFile.previousPath,
            videoPath: videoFile.mediaPath
        )
    }

    public func languageDetections(
        forSubtitleFile subtitleFile: URL
    ) throws -> [StoredSubtitleLanguageDetection] {
        let statement = try database.prepare(
            """
            SELECT d.id, sf.subtitle_path, d.scope, d.scope_key, d.algorithm_version,
                   d.confidence, d.confidence_band, d.segment_count,
                   d.effective_character_count, d.detected_at
            FROM subtitle_language_detections d
            JOIN subtitle_files sf ON sf.id = d.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY d.scope ASC, d.scope_key ASC, d.id ASC;
            """
        )
        try statement.bind(subtitleFile.mediaPath, at: 1)

        var records: [StoredSubtitleLanguageDetection] = []
        while try statement.step() {
            let detectionID = statement.int64Column(0)
            records.append(
                StoredSubtitleLanguageDetection(
                    subtitlePath: statement.stringColumn(1),
                    scope: SubtitleLanguageDetectionScope(rawValue: statement.stringColumn(2)) ?? .file,
                    scopeKey: statement.stringColumn(3).isEmpty ? nil : statement.stringColumn(3),
                    algorithmVersion: statement.intColumn(4),
                    confidence: statement.nullableDoubleColumn(5) ?? 0,
                    confidenceBand: SubtitleLanguageConfidenceBand(rawValue: statement.stringColumn(6)) ?? .none,
                    segmentCount: statement.intColumn(7),
                    effectiveCharacterCount: statement.intColumn(8),
                    languages: try subtitleLanguageDetectionCodes(detectionID: detectionID),
                    distribution: try subtitleLanguageDetectionDistribution(detectionID: detectionID),
                    detectedAt: statement.stringColumn(9)
                )
            )
        }

        return records
    }

    public func cueGroupLanguages(
        forSubtitleFile subtitleFile: URL
    ) throws -> [Int64: Set<SubtitleLanguageCode>] {
        let statement = try database.prepare(
            """
            SELECT g.id, cgl.language_code
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_cue_group_languages cgl ON cgl.cue_group_id = g.id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC, cgl.language_code ASC;
            """
        )
        try statement.bind(subtitleFile.mediaPath, at: 1)

        var languagesByCueGroupID: [Int64: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(1)) else {
                continue
            }
            languagesByCueGroupID[statement.int64Column(0), default: []].insert(language)
        }

        return languagesByCueGroupID
    }

    public func cueGroupLanguages(
        forSubtitlePath subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Set<SubtitleLanguageCode> {
        let statement = try database.prepare(
            """
            SELECT cgl.language_code
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_cue_group_languages cgl ON cgl.cue_group_id = g.id
            WHERE sf.subtitle_path = ?
              AND g.start_ms = ?
              AND g.end_ms = ?
            ORDER BY cgl.language_code ASC;
            """
        )
        try statement.bind(subtitlePath, at: 1)
        try statement.bind(startMilliseconds, at: 2)
        try statement.bind(endMilliseconds, at: 3)

        var languages = Set<SubtitleLanguageCode>()
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) else {
                continue
            }
            languages.insert(language)
        }

        return languages.isEmpty ? [.unknown] : languages
    }

    public func cueGroupID(
        forSubtitlePath subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT g.id
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.start_ms = ?
              AND g.end_ms = ?
            ORDER BY g.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitlePath, at: 1)
        try statement.bind(startMilliseconds, at: 2)
        try statement.bind(endMilliseconds, at: 3)

        guard try statement.step() else {
            return nil
        }

        return statement.int64Column(0)
    }

    public func firstCueGroupID(forSubtitleFile subtitleFile: URL) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT g.id
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitleFile.mediaPath, at: 1)

        guard try statement.step() else {
            return nil
        }

        return statement.int64Column(0)
    }

    public func hasCurrentSubtitleLanguageManifest(forSubtitleFile subtitleFile: URL) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT lm.algorithm_version
            FROM subtitle_language_manifests lm
            JOIN subtitle_files sf ON sf.id = lm.subtitle_file_id
            WHERE sf.subtitle_path = ?;
            """
        )
        try statement.bind(subtitleFile.mediaPath, at: 1)

        guard try statement.step() else {
            return false
        }

        return statement.intColumn(0) == SubtitleLanguageRecognizer.algorithmVersion
    }


    public func subtitleFiles() throws -> [SubtitleFileMetadata] {
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   vf.file_size, vf.modified_at, sf.file_size,
                   sf.modified_at, sf.indexed_at, sf.index_algorithm_version
            FROM subtitle_files sf
            LEFT JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf ON vf.id = m.video_file_id
            ORDER BY sf.subtitle_path ASC;
            """
        )

        var files: [SubtitleFileMetadata] = []
        while try statement.step() {
            files.append(
                SubtitleFileMetadata(
                    subtitlePath: statement.stringColumn(0),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(1)) ?? .srt,
                    videoPath: statement.nullableStringColumn(2),
                    videoName: statement.nullableStringColumn(3),
                    videoFileSize: statement.nullableInt64Column(4),
                    videoModifiedAt: statement.nullableDoubleColumn(5)
                        .map(Date.init(timeIntervalSince1970:)),
                    fileSize: statement.nullableInt64Column(6),
                    modifiedAt: statement.nullableDoubleColumn(7)
                        .map(Date.init(timeIntervalSince1970:)),
                    indexedAt: statement.stringColumn(8),
                    indexAlgorithmVersion: statement.intColumn(9)
                )
            )
        }

        return files
    }

    public func reconcileIndexedContent(activeFolders folders: [URL]) throws {
        let folders = folders.map(\.standardizedMediaURL)
        try database.withImmediateTransaction {
            var removedIndexedContent = false
            let inactiveSearchPaths = try searchPaths()
                .filter { !Self.folderPath($0, matchesAny: folders) }
            for searchPath in inactiveSearchPaths {
                let affectedFolderPaths = try removeIndexedDataInCurrentTransaction(
                    under: URL.fromMediaPath(searchPath),
                    keeping: [],
                    removeSearchPath: true,
                    rebuildSearchDerivedIndex: false,
                    unavailableReason: .libraryUnavailable
                )
                removedIndexedContent = removedIndexedContent || !affectedFolderPaths.isEmpty
            }

            try deleteOrphanedVideoFiles()
            if folders.isEmpty {
                try rebuildSearchDerivedIndexInCurrentTransaction()
            }
            if removedIndexedContent {
                try CueFacetCountCache.rebuildAll(on: database)
            }
        }
    }

    private func rebuildSearchOrderRows() throws {
        try LibraryDatabase(sharing: database).refreshVideoDisplayTitles(inFolderPaths: nil)
        try database.execute("DELETE FROM subtitle_search_order_rows;")
        try insertSearchOrderRows(for: try indexedSearchOrderFiles(inFolderPath: nil))
    }

    private func rebuildSearchDerivedIndexInCurrentTransaction() throws {
        try rebuildSearchOrderRows()
    }

    func refreshSearchOrderRows(
        affectedFolderPaths: Set<String>
    ) throws {
        guard !affectedFolderPaths.isEmpty else {
            return
        }
        // The rows carry their videos' Display Title, so the videos are named
        // first and Search never waits for the Library rows to be rebuilt.
        try LibraryDatabase(sharing: database).refreshVideoDisplayTitles(
            inFolderPaths: affectedFolderPaths
        )
        let folderPaths = Set(
            affectedFolderPaths.flatMap {
                Self.folderPathVariants(
                    for: URL.fromMediaPath($0)
                )
            }
        ).sorted()
        let placeholders = folderPaths.map { _ in "?" }.joined(separator: ", ")
        let delete = try database.prepare(
            """
            DELETE FROM subtitle_search_order_rows
            WHERE folder_path IN (\(placeholders));
            """
        )
        for (offset, folderPath) in folderPaths.enumerated() {
            try delete.bind(folderPath, at: Int32(offset + 1))
        }
        try delete.run()

        let pathRanges = folderPaths.map {
            (
                Self.subtitlePathPrefix(forFolderPath: $0),
                Self.pathPrefixUpperBound(
                    for: Self.subtitlePathPrefix(forFolderPath: $0)
                )
            )
        }
        let scopeCondition = pathRanges.map { _ in
            "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)"
        }.joined(separator: " OR ")
        let select = try database.prepare(
            """
            SELECT sf.id, sf.subtitle_path
            FROM subtitle_files sf
            WHERE (\(scopeCondition))
            ORDER BY sf.subtitle_path ASC;
            """
        )
        var bindIndex: Int32 = 1
        for range in pathRanges {
            try select.bind(range.0, at: bindIndex)
            bindIndex += 1
            try select.bind(range.1, at: bindIndex)
            bindIndex += 1
        }
        var files: [SearchOrderFile] = []
        while try select.step() {
            let subtitlePath = select.stringColumn(1)
            let folderPath = Self.folderPath(
                forSubtitlePath: subtitlePath
            )
            guard folderPaths.contains(folderPath) else {
                continue
            }
            files.append(
                SearchOrderFile(
                    subtitleFileID: select.int64Column(0),
                    subtitlePath: subtitlePath,
                    folderPath: folderPath,
                    folderTitle: URL.fromMediaPath(
                        folderPath
                    ).lastPathComponent,
                    subtitleFileName: URL.fromMediaPath(
                        subtitlePath
                    ).lastPathComponent
                )
            )
        }
        try insertSearchOrderRows(for: files)
    }

    private func indexedSearchOrderFiles(inFolderPath folderPath: String?) throws -> [SearchOrderFile] {
        let statement: SQLiteStatement
        if let folderPath {
            let prefix = Self.subtitlePathPrefix(forFolderPath: folderPath)
            statement = try database.prepare(
                """
                SELECT id, subtitle_path
                FROM subtitle_files
                WHERE subtitle_path >= ? AND subtitle_path < ?
                ORDER BY subtitle_path ASC;
                """
            )
            try statement.bind(prefix, at: 1)
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: 2)
        } else {
            statement = try database.prepare(
                """
                SELECT id, subtitle_path
                FROM subtitle_files
                ORDER BY subtitle_path ASC;
                """
            )
        }

        var files: [SearchOrderFile] = []
        while try statement.step() {
            let subtitleFileID = statement.int64Column(0)
            let subtitlePath = statement.stringColumn(1)
            let folderPath = Self.folderPath(forSubtitlePath: subtitlePath)
            files.append(
                SearchOrderFile(
                    subtitleFileID: subtitleFileID,
                    subtitlePath: subtitlePath,
                    folderPath: folderPath,
                    folderTitle: URL.fromMediaPath(folderPath).lastPathComponent,
                    subtitleFileName: URL.fromMediaPath(subtitlePath).lastPathComponent
                )
            )
        }
        return files
    }

    private func insertSearchOrderRows(for files: [SearchOrderFile]) throws {
        guard !files.isEmpty else {
            return
        }

        let updatedAt = ISO8601DateFormatter().string(from: Date())
        let filesByFolderPath = Dictionary(grouping: files, by: \.folderPath)
        let folderPaths = filesByFolderPath.keys.sorted { lhs, rhs in
            let lhsTitle = URL.fromMediaPath(lhs).lastPathComponent
            let rhsTitle = URL.fromMediaPath(rhs).lastPathComponent
            let titleComparison = lhsTitle.localizedStandardCompare(rhsTitle)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        let insert = try database.prepare(
            """
            INSERT INTO subtitle_search_order_rows(
                subtitle_path,
                subtitle_file_id,
                folder_path,
                folder_title,
                subtitle_file_name,
                display_title,
                folder_order,
                file_order,
                updated_at
            )
            VALUES (
                ?1, ?2, ?3, ?4, ?5,
                \(SubtitleDisplayTitleResolver.matchedVideoDisplayTitleSQL(subtitleFileID: "?2")),
                ?6, ?7, ?8
            );
            """
        )

        for (folderOrder, folderPath) in folderPaths.enumerated() {
            let files = (filesByFolderPath[folderPath] ?? []).sorted { lhs, rhs in
                let filenameComparison = lhs.subtitleFileName.localizedStandardCompare(rhs.subtitleFileName)
                if filenameComparison != .orderedSame {
                    return filenameComparison == .orderedAscending
                }

                return lhs.subtitlePath.localizedStandardCompare(rhs.subtitlePath) == .orderedAscending
            }

            for (fileOrder, file) in files.enumerated() {
                try insert.bind(file.subtitlePath, at: 1)
                try insert.bind(file.subtitleFileID, at: 2)
                try insert.bind(file.folderPath, at: 3)
                try insert.bind(file.folderTitle, at: 4)
                try insert.bind(file.subtitleFileName, at: 5)
                try insert.bind(folderOrder, at: 6)
                try insert.bind(fileOrder, at: 7)
                try insert.bind(updatedAt, at: 8)
                try insert.run()
                try insert.reset()
                try insert.clearBindings()
            }
        }
    }



    public func removeStaleEntries(under folder: URL, keeping subtitleFiles: Set<String>) throws {
        try removeIndexedData(
            under: folder,
            keeping: subtitleFiles,
            removeSearchPath: false,
            rebuildSearchDerivedIndex: true,
            unavailableReason: .subtitleMissing
        )
    }

    /// Removes a root and what it holds, except what lies inside the roots
    /// that stay: each of those becomes a Library of its own again, keeping
    /// its indexed content. One transaction, so either all of it happens or
    /// none of it.
    @discardableResult
    public func removeIndexedFolder(
        _ folder: URL,
        keepingNestedRoots nestedRoots: [URL] = []
    ) throws -> Bool {
        try database.withImmediateTransaction {
            var keptSubtitlePaths = Set<String>()
            for nestedRoot in nestedRoots {
                keptSubtitlePaths.formUnion(try separateNestedLibrary(nestedRoot))
            }
            let affectedFolderPaths = try removeIndexedDataInCurrentTransaction(
                under: folder,
                keeping: keptSubtitlePaths,
                removeSearchPath: true,
                rebuildSearchDerivedIndex: false,
                unavailableReason: .libraryUnavailable
            )
            if !affectedFolderPaths.isEmpty {
                try CueFacetCountCache.rebuildAll(on: database)
            }
            return !affectedFolderPaths.isEmpty
        }
    }

    private struct SearchOrderFile {
        let subtitleFileID: Int64
        let subtitlePath: String
        let folderPath: String
        let folderTitle: String
        let subtitleFileName: String
    }

    private struct PlaybackFinishCueGroup {
        let startMilliseconds: Int
        let endMilliseconds: Int
        let styles: Set<String>

        func overlapMilliseconds(with other: PlaybackFinishCueGroup) -> Int {
            min(endMilliseconds, other.endMilliseconds) - max(startMilliseconds, other.startMilliseconds)
        }
    }

    private struct PlaybackFinishCueGroupKey: Hashable {
        let startMilliseconds: Int
        let endMilliseconds: Int
    }

    private struct StoredCueState {
        let identity: StoredCueIdentity
    }


    private static func playbackFinishMetadata(
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup]
    ) -> SubtitlePlaybackFinishMetadata {
        var stylesByTimeRange: [PlaybackFinishCueGroupKey: Set<String>] = [:]
        for group in cueGroups {
            let key = PlaybackFinishCueGroupKey(
                startMilliseconds: group.startMilliseconds,
                endMilliseconds: group.endMilliseconds
            )
            stylesByTimeRange[key, default: []].formUnion(
                group.cueLines.compactMap { line in
                    let style = line.sourceStyle?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return style?.isEmpty == true ? nil : style
                }
            )
        }

        let groupedCues = stylesByTimeRange.map { key, styles in
            PlaybackFinishCueGroup(
                startMilliseconds: key.startMilliseconds,
                endMilliseconds: key.endMilliseconds,
                styles: styles
            )
        }

        let lastSubtitleEndMilliseconds = groupedCues.map(\.endMilliseconds).max()
        guard format == .ass else {
            return SubtitlePlaybackFinishMetadata(
                primaryStyles: [],
                primaryStyleLastEndMilliseconds: nil,
                lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
            )
        }

        var styleCounts: [String: Int] = [:]
        for (index, group) in groupedCues.enumerated() {
            let hasOverlap = groupedCues.indices.contains { otherIndex in
                guard otherIndex != index else {
                    return false
                }

                return group.overlapMilliseconds(with: groupedCues[otherIndex]) >= 1
            }

            guard !hasOverlap else {
                continue
            }

            for style in group.styles {
                styleCounts[style, default: 0] += 1
            }
        }

        guard let primaryStyleCount = styleCounts.values.max(),
              primaryStyleCount > 0
        else {
            return SubtitlePlaybackFinishMetadata(
                primaryStyles: [],
                primaryStyleLastEndMilliseconds: nil,
                lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
            )
        }

        let primaryStyles = styleCounts
            .filter { $0.value == primaryStyleCount }
            .map(\.key)
            .sorted()
        let primaryStyleSet = Set(primaryStyles)
        let primaryStyleLastEndMilliseconds = groupedCues
            .filter { !$0.styles.isDisjoint(with: primaryStyleSet) }
            .map(\.endMilliseconds)
            .max()

        return SubtitlePlaybackFinishMetadata(
            primaryStyles: primaryStyles,
            primaryStyleLastEndMilliseconds: primaryStyleLastEndMilliseconds,
            lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
        )
    }

    private static func encodePrimaryStyles(_ primaryStyles: [String]) throws -> String {
        let data = try JSONEncoder().encode(primaryStyles)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SQLiteDatabaseError.stepFailed("Primary style metadata could not be encoded.")
        }
        return json
    }

    private func removeIndexedData(
        under folder: URL,
        keeping subtitleFiles: Set<String>,
        removeSearchPath: Bool,
        rebuildSearchDerivedIndex: Bool,
        unavailableReason: ExcerptUnavailableReason
    ) throws {
        try database.withImmediateTransaction {
            let affectedFolderPaths = try removeIndexedDataInCurrentTransaction(
                under: folder,
                keeping: subtitleFiles,
                removeSearchPath: removeSearchPath,
                rebuildSearchDerivedIndex: rebuildSearchDerivedIndex,
                unavailableReason: unavailableReason
            )
            if !affectedFolderPaths.isEmpty {
                try CueFacetCountCache.rebuildAll(on: database)
            }
        }
    }

    private func removeIndexedDataInCurrentTransaction(
        under folder: URL,
        keeping subtitleFiles: Set<String>,
        missingVideoSubtitlePaths: Set<String> = [],
        removeSearchPath: Bool,
        rebuildSearchDerivedIndex: Bool,
        unavailableReason: ExcerptUnavailableReason
    ) throws -> Set<String> {
        let folderPathPrefixes = Self.folderPathPrefixes(for: folder)
        let missingVideoVariants = Set(
            missingVideoSubtitlePaths.flatMap {
                Self.folderPathVariants(for: URL.fromMediaPath($0))
            }
        )
        let prefixCondition = folderPathPrefixes
            .map { _ in "substr(sf.subtitle_path, 1, ?) = ?" }
            .joined(separator: " OR ")
        let keepCondition: String
        let keepPlaceholders: String

        if subtitleFiles.isEmpty {
            keepCondition = ""
            keepPlaceholders = ""
        } else {
            keepPlaceholders = subtitleFiles.map { _ in "?" }.joined(separator: ", ")
            keepCondition = "AND sf.subtitle_path NOT IN (\(keepPlaceholders))"
        }

        let staleSubtitleFiles = try staleSubtitleFileRecords(
            prefixCondition: prefixCondition,
            keepCondition: keepCondition,
            folderPathPrefixes: folderPathPrefixes,
            subtitleFiles: subtitleFiles
        )
        var affectedFolderPaths = Set(
            staleSubtitleFiles.map {
                Self.folderPath(forSubtitlePath: $0.path)
            }
        )
        affectedFolderPaths.formUnion(
            try reconcileDetachedTombstoneUnavailableReasons(
                folderPathPrefixes: folderPathPrefixes,
                missingVideoVariants: missingVideoVariants,
                defaultUnavailableReason: unavailableReason
            )
        )
        guard !staleSubtitleFiles.isEmpty else {
            if removeSearchPath {
                for searchPath in Self.folderPathVariants(for: folder) {
                    try deleteSearchPath(searchPath)
                }
            }
            return affectedFolderPaths
        }
        for subtitleFile in staleSubtitleFiles {
            let reason: ExcerptUnavailableReason =
                missingVideoVariants.contains(subtitleFile.path)
                ? .videoMissing
                : unavailableReason
            try snapshotReferencedCues(
                subtitleFileID: subtitleFile.id,
                unavailableReason: reason
            )
        }

        let candidateStaleVideos = try staleMatchedVideoFileRecords(
            prefixCondition: prefixCondition,
            keepCondition: keepCondition,
            folderPathPrefixes: folderPathPrefixes,
            subtitleFiles: subtitleFiles
        )

        let deleteLanguageDetections = try database.prepare(
            """
            DELETE FROM subtitle_language_detections
            WHERE subtitle_file_id IN (
                SELECT sf.id
                FROM subtitle_files sf
                WHERE (\(prefixCondition)) \(keepCondition)
            );
            """
        )
        try bindStaleEntryParameters(
            statement: deleteLanguageDetections,
            folderPathPrefixes: folderPathPrefixes,
            subtitleFiles: subtitleFiles
        )
        try deleteLanguageDetections.run()

        let deleteLanguageManifests = try database.prepare(
            """
            DELETE FROM subtitle_language_manifests
            WHERE subtitle_file_id IN (
                SELECT sf.id
                FROM subtitle_files sf
                WHERE (\(prefixCondition)) \(keepCondition)
            );
            """
        )
        try bindStaleEntryParameters(
            statement: deleteLanguageManifests,
            folderPathPrefixes: folderPathPrefixes,
            subtitleFiles: subtitleFiles
        )
        try deleteLanguageManifests.run()

        let deleteASSFontReferences = try database.prepare(
                """
                DELETE FROM ass_font_references
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteASSFontReferences,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteASSFontReferences.run()

            let deleteASSFontReferenceManifests = try database.prepare(
                """
                DELETE FROM ass_font_reference_manifests
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteASSFontReferenceManifests,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteASSFontReferenceManifests.run()

            let deleteASSRenderSegments = try database.prepare(
                """
                DELETE FROM ass_render_segments
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteASSRenderSegments,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteASSRenderSegments.run()

            let deleteASSFontResources = try database.prepare(
                """
                DELETE FROM ass_font_resources
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteASSFontResources,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteASSFontResources.run()

            let deletePlaybackFinishMetadata = try database.prepare(
                """
                DELETE FROM subtitle_playback_finish_metadata
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deletePlaybackFinishMetadata,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deletePlaybackFinishMetadata.run()

            let deleteFTS = try database.prepare(
                """
                DELETE FROM subtitle_cue_groups_fts
                WHERE cue_group_id IN (
                    SELECT g.id
                    FROM subtitle_cue_groups g
                    JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteFTS,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteFTS.run()

            let deleteLibraryRows = try database.prepare(
                """
                DELETE FROM library_video_rows
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteLibraryRows,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteLibraryRows.run()

            let deleteSearchOrderRows = try database.prepare(
                """
                DELETE FROM subtitle_search_order_rows
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteSearchOrderRows,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteSearchOrderRows.run()

            let deleteCueLines = try database.prepare(
                """
                DELETE FROM subtitle_cue_lines
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteCueLines,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteCueLines.run()

            let deleteCueGroups = try database.prepare(
                """
                DELETE FROM subtitle_cue_groups
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteCueGroups,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteCueGroups.run()

            for subtitleFile in staleSubtitleFiles {
                try deleteSubtitleFile(id: subtitleFile.id)
                try recomputeTombstoneUnavailableReasons(
                    subtitleFileID: subtitleFile.id
                )
            }

            for videoFile in candidateStaleVideos {
                if try !hasActiveSubtitleMatch(videoFileID: videoFile.id) {
                    try deleteVideoFile(id: videoFile.id)
                }
            }

            try deleteOrphanedVideoFiles()
            try reconcileExcerptListRecentCues()

            if removeSearchPath {
                for searchPath in Self.folderPathVariants(for: folder) {
                    try deleteSearchPath(searchPath)
                }
            }

        if rebuildSearchDerivedIndex {
            try refreshSearchOrderRows(
                affectedFolderPaths: affectedFolderPaths
            )
        }
        return affectedFolderPaths
    }

    private func upsertSubtitleFile(
        subtitleFile: URL,
        format: SubtitleFormat,
        fileSize: Int64?,
        modifiedAt: Date?,
        libraryID: Int64? = nil
    ) throws -> UpsertedSubtitleFile {
        let subtitleMediaPath = subtitleFile.mediaPath
        let pathIdentity = try mediaPathIdentity(for: subtitleFile, preferredLibraryID: libraryID)
        let folderID = try pathIdentity.flatMap {
            try upsertLibraryFolder(
                for: subtitleFile.deletingLastPathComponent(),
                libraryID: $0.libraryID
            )
        }
        let now = ISO8601DateFormatter().string(from: Date())

        if let record = try subtitleFileRecord(path: subtitleMediaPath) {
            let statement = try database.prepare(
                """
                UPDATE subtitle_files
                SET library_id = ?,
                    folder_id = ?,
                    relative_path = ?,
                    subtitle_path = ?,
                    format = ?,
                    file_size = ?,
                    modified_at = ?,
                    indexed_at = ?,
                    index_algorithm_version = ?
                WHERE id = ?;
                """
            )
            try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
            try statement.bind(subtitleMediaPath, at: 4)
            try statement.bind(format.rawValue, at: 5)
            try bindOptional(fileSize, to: statement, at: 6)
            try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 7)
            try statement.bind(now, at: 8)
            try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 9)
            try statement.bind(record.id, at: 10)
            try statement.run()
            try adoptTombstones(
                forSubtitleFile: subtitleFile,
                subtitleFileID: record.id
            )
            return UpsertedSubtitleFile(id: record.id, previousPath: nil)
        }

        let statement = try database.prepare(
            """
            INSERT INTO subtitle_files(
                library_id,
                folder_id,
                relative_path,
                subtitle_path,
                format,
                file_size,
                modified_at,
                indexed_at,
                index_algorithm_version
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            RETURNING id;
            """
        )

        try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
        try statement.bind(subtitleMediaPath, at: 4)
        try statement.bind(format.rawValue, at: 5)
        try bindOptional(fileSize, to: statement, at: 6)
        try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 7)
        try statement.bind(now, at: 8)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 9)

        let id = try statement.step()
            ? statement.int64Column(0)
            : database.lastInsertRowID()
        try adoptTombstones(
            forSubtitleFile: subtitleFile,
            subtitleFileID: id
        )
        return UpsertedSubtitleFile(id: id, previousPath: nil)
    }

    private func upsertVideoFile(
        _ videoFile: URL,
        fileSize explicitFileSize: Int64? = nil,
        modifiedAt explicitModifiedAt: Date? = nil,
        libraryID: Int64? = nil
    ) throws -> Int64 {
        let videoMediaPath = videoFile.mediaPath
        let fileSize: Int64?
        let modifiedAt: Date?
        if videoFile.isWebDAVURL {
            fileSize = explicitFileSize
            modifiedAt = explicitModifiedAt
        } else {
            let attributes = try? FileManager.default.attributesOfItem(atPath: videoFile.path)
            fileSize = explicitFileSize ?? (attributes?[.size] as? NSNumber)?.int64Value
            modifiedAt = explicitModifiedAt ?? (attributes?[.modificationDate] as? Date)
        }
        let pathIdentity = try mediaPathIdentity(for: videoFile, preferredLibraryID: libraryID)
        let folderID = try pathIdentity.flatMap {
            try upsertLibraryFolder(
                for: videoFile.deletingLastPathComponent(),
                libraryID: $0.libraryID
            )
        }

        if let record = try videoFileRecord(path: videoMediaPath) {
            let statement = try database.prepare(
                """
                UPDATE video_files
                SET library_id = ?,
                    folder_id = ?,
                    relative_path = ?,
                    path = ?,
                    video_name = ?,
                    file_size = ?,
                    modified_at = ?
                WHERE id = ?;
                """
            )
            try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
            try statement.bind(videoMediaPath, at: 4)
            try statement.bind(videoFile.lastPathComponent, at: 5)
            try bindOptional(fileSize, to: statement, at: 6)
            try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 7)
            try statement.bind(record.id, at: 8)
            try statement.run()
            try restoreVideoTombstoneIfNeeded(forVideoFile: videoFile, videoFileID: record.id)
            return record.id
        }

        let statement = try database.prepare(
            """
            INSERT INTO video_files(
                library_id,
                folder_id,
                relative_path,
                path,
                video_name,
                file_size,
                modified_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            RETURNING id;
            """
        )

        try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
        try statement.bind(videoMediaPath, at: 4)
        try statement.bind(videoFile.lastPathComponent, at: 5)
        try bindOptional(fileSize, to: statement, at: 6)
        try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 7)

        let id = try statement.step()
            ? statement.int64Column(0)
            : database.lastInsertRowID()
        try restoreVideoTombstoneIfNeeded(forVideoFile: videoFile, videoFileID: id)
        return id
    }

    private func subtitleFileRecord(path: String) throws -> BoundResourceRecord? {
        try boundResourceRecord(
            sql: """
                SELECT id, subtitle_path
                FROM subtitle_files
                WHERE subtitle_path = ?
                LIMIT 1;
                """,
            value: path
        )
    }

    private func videoFileRecord(path: String) throws -> BoundResourceRecord? {
        try boundResourceRecord(
            sql: """
                SELECT id, path
                FROM video_files
                WHERE path = ?
                LIMIT 1;
                """,
            value: path
        )
    }

    /// A resource that left the current scan result keeps nothing.
    private func deleteSubtitleFile(id: Int64) throws {
        let clearDefaultSubtitle = try database.prepare(
            "UPDATE video_files SET default_subtitle_file_id = NULL WHERE default_subtitle_file_id = ?;"
        )
        try clearDefaultSubtitle.bind(id, at: 1)
        try clearDefaultSubtitle.run()

        let statement = try database.prepare(
            "DELETE FROM subtitle_files WHERE id = ?;"
        )
        try statement.bind(id, at: 1)
        try statement.run()
    }

    /// Snapshots user-accumulated video state into `video_tombstones` (without Recent)
    /// and deletes the active video row and its transient rows.
    private func deleteVideoFile(id: Int64) throws {
        try snapshotVideoTombstoneIfNeeded(videoFileID: id)

        for table in ["library_playback_history", "library_watch_states"] {
            let statement = try database.prepare(
                "DELETE FROM \(table) WHERE video_file_id = ?;"
            )
            try statement.bind(id, at: 1)
            try statement.run()
        }

        let rows = try database.prepare(
            "DELETE FROM library_video_rows WHERE video_file_id = ?;"
        )
        try rows.bind(id, at: 1)
        try rows.run()

        let statement = try database.prepare(
            "DELETE FROM video_files WHERE id = ?;"
        )
        try statement.bind(id, at: 1)
        try statement.run()
    }

    private func snapshotVideoTombstoneIfNeeded(videoFileID: Int64) throws {
        let select = try database.prepare(
            """
            SELECT
                vf.path,
                vf.duration,
                COALESCE(vf.default_audio_track_index, 0),
                COALESCE(h.position_ms, 0),
                h.duration,
                COALESCE(
                    ws.state,
                    CASE
                        WHEN COALESCE(h.position_ms, 0) > 0 THEN 'watching'
                        ELSE 'unwatched'
                    END
                ),
                uvc.display_cover_path
            FROM video_files vf
            LEFT JOIN library_playback_history h ON h.video_file_id = vf.id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = vf.id
            LEFT JOIN user_video_covers uvc ON uvc.video_file_id = vf.id
            WHERE vf.id = ?
            LIMIT 1;
            """
        )
        try select.bind(videoFileID, at: 1)
        guard try select.step() else {
            return
        }

        let videoPath = select.stringColumn(0)
        let videoDuration = select.nullableDoubleColumn(1)
        let defaultAudioTrackIndex = select.intColumn(2)
        let positionMilliseconds = max(0, select.intColumn(3))
        let historyDuration = select.nullableDoubleColumn(4)
        let watchState = select.stringColumn(5)
        let userCoverPath = select.nullableStringColumn(6).flatMap { $0.isEmpty ? nil : $0 }

        let hasUserAccumulatedState =
            positionMilliseconds > 0
            || watchState != LibraryWatchState.unwatched.rawValue
            || userCoverPath != nil
            || defaultAudioTrackIndex > 0
        guard hasUserAccumulatedState else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let upsert = try database.prepare(
            """
            INSERT INTO video_tombstones(
                video_path,
                position_ms,
                duration,
                watch_state,
                user_cover_path,
                default_audio_track_index,
                tombstoned_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(video_path) DO UPDATE SET
                position_ms = excluded.position_ms,
                duration = excluded.duration,
                watch_state = excluded.watch_state,
                user_cover_path = excluded.user_cover_path,
                default_audio_track_index = excluded.default_audio_track_index,
                tombstoned_at = excluded.tombstoned_at,
                updated_at = excluded.updated_at;
            """
        )
        try upsert.bind(videoPath, at: 1)
        try upsert.bind(positionMilliseconds, at: 2)
        try bindOptional(videoDuration ?? historyDuration, to: upsert, at: 3)
        try upsert.bind(watchState, at: 4)
        try bindOptional(userCoverPath, to: upsert, at: 5)
        try upsert.bind(defaultAudioTrackIndex, at: 6)
        try upsert.bind(now, at: 7)
        try upsert.bind(now, at: 8)
        try upsert.run()
    }

    private func restoreVideoTombstoneIfNeeded(
        forVideoFile videoFile: URL,
        videoFileID: Int64
    ) throws {
        let pathVariants = Self.folderPathVariants(for: videoFile).sorted()
        guard !pathVariants.isEmpty else {
            return
        }
        let placeholders = pathVariants.map { _ in "?" }.joined(separator: ", ")
        let select = try database.prepare(
            """
            SELECT
                position_ms,
                duration,
                watch_state,
                user_cover_path,
                default_audio_track_index,
                updated_at
            FROM video_tombstones
            WHERE video_path IN (\(placeholders))
            ORDER BY CASE WHEN video_path = ? THEN 0 ELSE 1 END, updated_at DESC
            LIMIT 1;
            """
        )
        for (offset, variant) in pathVariants.enumerated() {
            try select.bind(variant, at: Int32(offset + 1))
        }
        try select.bind(videoFile.mediaPath, at: Int32(pathVariants.count + 1))
        guard try select.step() else {
            return
        }

        let positionMilliseconds = max(0, select.intColumn(0))
        let tombstoneDuration = select.nullableDoubleColumn(1)
        let watchState = select.stringColumn(2)
        let userCoverPath = select.nullableStringColumn(3).flatMap { $0.isEmpty ? nil : $0 }
        let defaultAudioTrackIndex = max(0, select.intColumn(4))
        let tombstoneUpdatedAt = select.stringColumn(5)

        if defaultAudioTrackIndex > 0 {
            let updateAudioTrack = try database.prepare(
                """
                UPDATE video_files
                SET default_audio_track_index = ?
                WHERE id = ?;
                """
            )
            try updateAudioTrack.bind(defaultAudioTrackIndex, at: 1)
            try updateAudioTrack.bind(videoFileID, at: 2)
            try updateAudioTrack.run()
        }

        if let userCoverPath {
            let upsertCover = try database.prepare(
                """
                INSERT INTO user_video_covers(video_file_id, display_cover_path, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(video_file_id) DO UPDATE SET
                    display_cover_path = excluded.display_cover_path,
                    updated_at = excluded.updated_at;
                """
            )
            try upsertCover.bind(videoFileID, at: 1)
            try upsertCover.bind(userCoverPath, at: 2)
            try upsertCover.bind(tombstoneUpdatedAt, at: 3)
            try upsertCover.run()
        }

        let durationStatement = try database.prepare(
            "SELECT duration FROM video_files WHERE id = ? LIMIT 1;"
        )
        try durationStatement.bind(videoFileID, at: 1)
        let currentVideoDuration: Double? = try durationStatement.step()
            ? durationStatement.nullableDoubleColumn(0)
            : nil

        let shouldResetForShorterDuration: Bool = {
            guard let currentVideoDuration, currentVideoDuration > 0 else {
                return false
            }
            let durationMilliseconds = Int((currentVideoDuration * 1_000).rounded(.down))
            return positionMilliseconds > durationMilliseconds
        }()

        if !shouldResetForShorterDuration {
            if watchState != LibraryWatchState.unwatched.rawValue {
                let upsertWatchState = try database.prepare(
                    """
                    INSERT INTO library_watch_states(video_file_id, state, updated_at)
                    VALUES (?, ?, ?)
                    ON CONFLICT(video_file_id) DO UPDATE SET
                        state = excluded.state,
                        updated_at = excluded.updated_at;
                    """
                )
                try upsertWatchState.bind(videoFileID, at: 1)
                try upsertWatchState.bind(watchState, at: 2)
                try upsertWatchState.bind(tombstoneUpdatedAt, at: 3)
                try upsertWatchState.run()
            }

            if positionMilliseconds > 0 {
                let startedAt: String? =
                    watchState == LibraryWatchState.unwatched.rawValue ? nil : tombstoneUpdatedAt
                let completedAt: String? =
                    watchState == LibraryWatchState.finished.rawValue ? tombstoneUpdatedAt : nil
                let upsertHistory = try database.prepare(
                    """
                    INSERT INTO library_playback_history(
                        video_file_id,
                        position_ms,
                        duration,
                        started_at,
                        completed_at,
                        updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, '')
                    ON CONFLICT(video_file_id) DO UPDATE SET
                        position_ms = excluded.position_ms,
                        duration = excluded.duration,
                        started_at = excluded.started_at,
                        completed_at = excluded.completed_at,
                        updated_at = excluded.updated_at;
                    """
                )
                try upsertHistory.bind(videoFileID, at: 1)
                try upsertHistory.bind(positionMilliseconds, at: 2)
                try bindOptional(currentVideoDuration ?? tombstoneDuration, to: upsertHistory, at: 3)
                try bindOptional(startedAt, to: upsertHistory, at: 4)
                try bindOptional(completedAt, to: upsertHistory, at: 5)
                try upsertHistory.run()
            }
        }

        let deleteTombstone = try database.prepare(
            "DELETE FROM video_tombstones WHERE video_path IN (\(placeholders));"
        )
        for (offset, variant) in pathVariants.enumerated() {
            try deleteTombstone.bind(variant, at: Int32(offset + 1))
        }
        try deleteTombstone.run()
    }

    private func reconcileExcerptListRecentCues() throws {
        let selectLists = try database.prepare(
            """
            SELECT el.id
            FROM excerpt_lists el
            WHERE el.recent_played_at IS NOT NULL
              AND (
                  el.recent_cue_id IS NULL
                  OR NOT EXISTS (
                      SELECT 1
                      FROM excerpts s
                      JOIN subtitle_cue_lines l ON l.id = s.cue_id
                      JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                      JOIN subtitle_video_matches m
                        ON m.subtitle_file_id = sf.id
                       AND m.is_active = 1
                      JOIN video_files vf ON vf.id = m.video_file_id
                      WHERE s.list_id = el.id
                        AND s.cue_id = el.recent_cue_id
                  )
              )
            ORDER BY el.id ASC;
            """
        )
        var listIDs: [Int64] = []
        while try selectLists.step() {
            listIDs.append(selectLists.int64Column(0))
        }
        guard !listIDs.isEmpty else {
            return
        }

        let selectFirstPlayableCue = try database.prepare(
            """
            SELECT s.cue_id
            FROM excerpts s
            JOIN subtitle_cue_lines l ON l.id = s.cue_id
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id
             AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE s.list_id = ?
            ORDER BY s.created_at ASC, s.id ASC
            LIMIT 1;
            """
        )
        let updateFallback = try database.prepare(
            "UPDATE excerpt_lists SET recent_cue_id = ? WHERE id = ?;"
        )
        let clearRecent = try database.prepare(
            """
            UPDATE excerpt_lists
            SET recent_cue_id = NULL,
                recent_sort_order = NULL,
                recent_played_at = NULL
            WHERE id = ?;
            """
        )

        for listID in listIDs {
            try selectFirstPlayableCue.bind(listID, at: 1)
            let fallbackCueID: Int64? = try selectFirstPlayableCue.step()
                ? selectFirstPlayableCue.int64Column(0)
                : nil
            try selectFirstPlayableCue.reset()

            if let fallbackCueID {
                try updateFallback.bind(fallbackCueID, at: 1)
                try updateFallback.bind(listID, at: 2)
                try updateFallback.run()
                try updateFallback.reset()
            } else {
                try clearRecent.bind(listID, at: 1)
                try clearRecent.run()
                try clearRecent.reset()
            }
        }
    }

    private func adoptTombstones(
        forSubtitleFile subtitleFile: URL,
        subtitleFileID: Int64
    ) throws {
        let pathVariants = Self.folderPathVariants(for: subtitleFile).sorted()
        guard !pathVariants.isEmpty else {
            return
        }
        let placeholders = pathVariants.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            UPDATE cue_tombstones
            SET subtitle_file_id = ?,
                subtitle_path = ?
            WHERE subtitle_path IN (\(placeholders));
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(subtitleFile.mediaPath, at: 2)
        for (offset, variant) in pathVariants.enumerated() {
            try statement.bind(variant, at: Int32(offset + 3))
        }
        try statement.run()
    }

    private func reconcileDetachedTombstoneUnavailableReasons(
        folderPathPrefixes: [String],
        missingVideoVariants: Set<String>,
        defaultUnavailableReason: ExcerptUnavailableReason
    ) throws -> Set<String> {
        guard !folderPathPrefixes.isEmpty else {
            return []
        }
        let prefixCondition = folderPathPrefixes
            .map { _ in "substr(t.subtitle_path, 1, ?) = ?" }
            .joined(separator: " OR ")
        let select = try database.prepare(
            """
            SELECT t.cue_id, t.subtitle_path, t.unavailable_reason
            FROM cue_tombstones t
            WHERE (\(prefixCondition))
              AND NOT EXISTS (
                  SELECT 1
                  FROM subtitle_files sf
                  WHERE sf.id = t.subtitle_file_id
              )
              AND t.unavailable_reason != 'cue_missing'
            ORDER BY t.cue_id ASC;
            """
        )
        var bindIndex: Int32 = 1
        for prefix in folderPathPrefixes {
            try select.bind(prefix.count, at: bindIndex)
            bindIndex += 1
            try select.bind(prefix, at: bindIndex)
            bindIndex += 1
        }
        var updates: [(cueID: Int64, subtitlePath: String, newReason: String)] = []
        while try select.step() {
            let cueID = select.int64Column(0)
            let subtitlePath = select.stringColumn(1)
            let currentReason = select.stringColumn(2)
            let targetReason: ExcerptUnavailableReason =
                missingVideoVariants.contains(subtitlePath)
                ? .videoMissing
                : defaultUnavailableReason
            if currentReason != targetReason.rawValue {
                updates.append((cueID, subtitlePath, targetReason.rawValue))
            }
        }
        guard !updates.isEmpty else {
            return []
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let updateStatement = try database.prepare(
            """
            UPDATE cue_tombstones
            SET unavailable_reason = ?,
                updated_at = ?
            WHERE cue_id = ?;
            """
        )
        var affectedFolders = Set<String>()
        for update in updates {
            try updateStatement.bind(update.newReason, at: 1)
            try updateStatement.bind(now, at: 2)
            try updateStatement.bind(update.cueID, at: 3)
            try updateStatement.run()
            try updateStatement.reset()
            affectedFolders.insert(
                Self.folderPath(forSubtitlePath: update.subtitlePath)
            )
        }
        return affectedFolders
    }

    private func hasActiveSubtitleMatch(videoFileID: Int64) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM subtitle_video_matches m
            JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
            WHERE m.video_file_id = ? AND m.is_active = 1
            LIMIT 1;
            """
        )
        try statement.bind(videoFileID, at: 1)
        return try statement.step()
    }

    private func bindMediaPathIdentity(
        _ pathIdentity: MediaPathIdentity?,
        folderID: Int64?,
        to statement: SQLiteStatement
    ) throws {
        if let pathIdentity {
            try statement.bind(pathIdentity.libraryID, at: 1)
            try bindOptional(folderID, to: statement, at: 2)
            try statement.bind(pathIdentity.relativePath, at: 3)
        } else {
            try statement.bindNull(at: 1)
            try statement.bindNull(at: 2)
            try statement.bindNull(at: 3)
        }
    }

    private func bindOptional(
        _ value: String?,
        to statement: SQLiteStatement,
        at index: Int32
    ) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

    private func bindOptional(
        _ value: Int64?,
        to statement: SQLiteStatement,
        at index: Int32
    ) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

    private func bindOptional(
        _ value: Double?,
        to statement: SQLiteStatement,
        at index: Int32
    ) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

    private func boundResourceRecord(
        sql: String,
        value: String
    ) throws -> BoundResourceRecord? {
        let statement = try database.prepare(sql)
        try statement.bind(value, at: 1)
        return try readBoundResourceRecord(statement)
    }

    private func readBoundResourceRecord(
        _ statement: SQLiteStatement
    ) throws -> BoundResourceRecord? {
        guard try statement.step() else {
            return nil
        }
        return BoundResourceRecord(
            id: statement.int64Column(0),
            path: statement.stringColumn(1)
        )
    }

    private func upsertSubtitleVideoMatch(subtitleFileID: Int64, videoFileID: Int64) throws {
        let clearPreviousMatches = try database.prepare(
            """
            DELETE FROM subtitle_video_matches
            WHERE subtitle_file_id = ?
              AND video_file_id != ?;
            """
        )
        try clearPreviousMatches.bind(subtitleFileID, at: 1)
        try clearPreviousMatches.bind(videoFileID, at: 2)
        try clearPreviousMatches.run()

        let statement = try database.prepare(
            """
            INSERT INTO subtitle_video_matches(
                subtitle_file_id,
                video_file_id,
                match_method,
                confidence,
                is_active
            )
            VALUES (?, ?, 'same-directory-basename', 1.0, 1)
            ON CONFLICT(subtitle_file_id, video_file_id) DO UPDATE SET
                match_method = excluded.match_method,
                confidence = excluded.confidence,
                is_active = excluded.is_active;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(videoFileID, at: 2)
        try statement.run()
    }

    private func storedCueStates(subtitleFileID: Int64) throws -> [StoredCueState] {
        let statement = try database.prepare(
            """
            SELECT l.id, l.source_format, l.source_style,
                   l.source_identity_remainder, l.start_ms, l.end_ms,
                   l.content
            FROM subtitle_cue_lines l
            WHERE l.subtitle_file_id = ?
            ORDER BY l.id ASC;
            """
        )
        try statement.bind(subtitleFileID, at: 1)

        var stateByCueID: [Int64: StoredCueState] = [:]
        while try statement.step() {
            let cueID = statement.int64Column(0)
            stateByCueID[cueID] = StoredCueState(
                identity: StoredCueIdentity(
                    cueID: cueID,
                    sourceFormat: SubtitleFormat(
                        rawValue: statement.stringColumn(1)
                    ) ?? .srt,
                    sourceStyle: statement.nullableStringColumn(2),
                    sourceIdentityRemainder: statement.stringColumn(3),
                    startMilliseconds: statement.intColumn(4),
                    endMilliseconds: statement.intColumn(5),
                    content: statement.stringColumn(6)
                )
            )
        }

        let tombstones = try database.prepare(
            """
            SELECT cue_id, source_format, source_style,
                   source_identity_remainder, start_ms, end_ms, content
            FROM cue_tombstones
            WHERE subtitle_file_id = ?
            ORDER BY cue_id ASC;
            """
        )
        try tombstones.bind(subtitleFileID, at: 1)
        while try tombstones.step() {
            let cueID = tombstones.int64Column(0)
            guard stateByCueID[cueID] == nil else {
                continue
            }
            stateByCueID[cueID] = StoredCueState(
                identity: StoredCueIdentity(
                    cueID: cueID,
                    sourceFormat: SubtitleFormat(
                        rawValue: tombstones.stringColumn(1)
                    ) ?? .srt,
                    sourceStyle: tombstones.nullableStringColumn(2),
                    sourceIdentityRemainder: tombstones.stringColumn(3),
                    startMilliseconds: tombstones.intColumn(4),
                    endMilliseconds: tombstones.intColumn(5),
                    content: tombstones.stringColumn(6)
                )
            )
        }

        return stateByCueID.values.sorted {
            $0.identity.cueID < $1.identity.cueID
        }
    }

    private func snapshotReferencedCues(
        subtitleFileID: Int64,
        unavailableReason: ExcerptUnavailableReason
    ) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let statement = try database.prepare(
            """
            INSERT INTO cue_tombstones(
                cue_id,
                subtitle_file_id,
                source_format,
                source_style,
                source_identity_remainder,
                start_time,
                end_time,
                start_ms,
                end_ms,
                content,
                cue_group_content,
                display_title,
                subtitle_path,
                video_path,
                unavailable_reason,
                tombstoned_at,
                updated_at
            )
            SELECT l.id,
                   l.subtitle_file_id,
                   l.source_format,
                   l.source_style,
                   l.source_identity_remainder,
                   l.start_time,
                   l.end_time,
                   l.start_ms,
                   l.end_ms,
                   l.content,
                   COALESCE(
                     (
                       SELECT GROUP_CONCAT(ordered.content, char(31))
                       FROM (
                         SELECT group_cue.content
                         FROM subtitle_cue_lines group_cue
                         WHERE group_cue.cue_group_id = l.cue_group_id
                         ORDER BY group_cue.display_order ASC,
                                  group_cue.event_index ASC,
                                  group_cue.id ASC
                       ) ordered
                     ),
                     l.content
                   ),
                   \(SubtitleDisplayTitleResolver.matchedVideoDisplayTitleSQL(subtitleFileID: "sf.id")),
                   sf.subtitle_path,
                   vf.path,
                   ?,
                   ?,
                   ?
            FROM subtitle_cue_lines l
            JOIN excerpts s ON s.cue_id = l.id
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            LEFT JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf ON vf.id = m.video_file_id
            WHERE l.subtitle_file_id = ?
            ON CONFLICT(cue_id) DO UPDATE SET
                subtitle_file_id = excluded.subtitle_file_id,
                source_format = excluded.source_format,
                source_style = excluded.source_style,
                source_identity_remainder = excluded.source_identity_remainder,
                start_time = excluded.start_time,
                end_time = excluded.end_time,
                start_ms = excluded.start_ms,
                end_ms = excluded.end_ms,
                content = excluded.content,
                cue_group_content = excluded.cue_group_content,
                display_title = excluded.display_title,
                subtitle_path = excluded.subtitle_path,
                video_path = excluded.video_path,
                unavailable_reason = excluded.unavailable_reason,
                updated_at = excluded.updated_at;
            """
        )
        try statement.bind(unavailableReason.rawValue, at: 1)
        try statement.bind(now, at: 2)
        try statement.bind(now, at: 3)
        try statement.bind(subtitleFileID, at: 4)
        try statement.run()
    }

    private func recomputeTombstoneUnavailableReasons(
        subtitleFileID: Int64
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE cue_tombstones
            SET unavailable_reason = CASE
                  WHEN EXISTS (
                    SELECT 1
                    FROM subtitle_files sf
                    WHERE sf.id = cue_tombstones.subtitle_file_id
                  )
                  THEN 'cue_missing'
                  ELSE unavailable_reason
                END,
                updated_at = ?
            WHERE subtitle_file_id = ?;
            """
        )
        try statement.bind(
            ISO8601DateFormatter().string(from: Date()),
            at: 1
        )
        try statement.bind(subtitleFileID, at: 2)
        try statement.run()
    }

    private func deleteCueTombstone(cueID: Int64) throws {
        let statement = try database.prepare(
            "DELETE FROM cue_tombstones WHERE cue_id = ?;"
        )
        try statement.bind(cueID, at: 1)
        try statement.run()
    }

    private func clearPriorCueChangeNotices(
        subtitleFileID: Int64
    ) throws {
        let statement = try database.prepare(
            """
            DELETE FROM cue_change_notices
            WHERE EXISTS (
                SELECT 1
                FROM subtitle_cue_lines l
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                WHERE l.id = cue_change_notices.cue_id
                  AND sf.id = ?
            )
               OR EXISTS (
                SELECT 1
                FROM cue_tombstones t
                JOIN subtitle_files sf ON sf.id = t.subtitle_file_id
                WHERE t.cue_id = cue_change_notices.cue_id
                  AND sf.id = ?
            );
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(subtitleFileID, at: 2)
        try statement.run()
    }

    private func clearPriorCueChangeNotices(
        libraryID: Int64
    ) throws -> Bool {
        let statement = try database.prepare(
            """
            DELETE FROM cue_change_notices
            WHERE EXISTS (
                SELECT 1
                FROM subtitle_cue_lines l
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                WHERE l.id = cue_change_notices.cue_id
                  AND sf.library_id = ?
            )
               OR EXISTS (
                SELECT 1
                FROM cue_tombstones t
                JOIN subtitle_files sf ON sf.id = t.subtitle_file_id
                WHERE t.cue_id = cue_change_notices.cue_id
                  AND sf.library_id = ?
            );
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(libraryID, at: 2)
        try statement.run()
        return database.changesCount() > 0
    }

    private func insertCueChangeNotice(
        cueID: Int64,
        previousContent: String,
        currentContent: String
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO cue_change_notices(
                cue_id,
                previous_content,
                current_content,
                changed_at
            )
            VALUES (?, ?, ?, ?)
            ON CONFLICT(cue_id) DO UPDATE SET
                previous_content = excluded.previous_content,
                current_content = excluded.current_content,
                changed_at = excluded.changed_at;
            """
        )
        try statement.bind(cueID, at: 1)
        try statement.bind(previousContent, at: 2)
        try statement.bind(currentContent, at: 3)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 4)
        try statement.run()
    }

    private func insertCueGroup(
        subtitleFileID: Int64,
        subtitleFile: URL,
        group: SubtitleCueGroup
    ) throws -> Int64 {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_groups(
                subtitle_file_id,
                subtitle_path,
                seq,
                start_time,
                end_time,
                start_ms,
                end_ms,
                time_range,
                search_content,
                line_count
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(subtitleFile.mediaPath, at: 2)
        if let sequenceNumber = group.sequenceNumber {
            try statement.bind(sequenceNumber, at: 3)
        } else {
            try statement.bindNull(at: 3)
        }
        try statement.bind(group.startTimecode, at: 4)
        try statement.bind(group.endTimecode, at: 5)
        try statement.bind(group.startMilliseconds, at: 6)
        try statement.bind(group.endMilliseconds, at: 7)
        try statement.bind(
            Self.cueTimeRange(
                startMilliseconds: group.startMilliseconds,
                endMilliseconds: group.endMilliseconds
            ),
            at: 8
        )
        try statement.bind(group.searchContent, at: 9)
        try statement.bind(max(1, group.cueLines.count), at: 10)
        try statement.run()

        return database.lastInsertRowID()
    }

    private func insertPlaybackFinishMetadata(
        subtitleFileID: Int64,
        subtitleFile: URL,
        metadata: SubtitlePlaybackFinishMetadata
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR REPLACE INTO subtitle_playback_finish_metadata(
                subtitle_file_id,
                subtitle_path,
                algorithm_version,
                primary_styles_json,
                primary_style_last_end_ms,
                last_subtitle_end_ms,
                indexed_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(subtitleFile.mediaPath, at: 2)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 3)
        try statement.bind(try Self.encodePrimaryStyles(metadata.primaryStyles), at: 4)
        if let primaryStyleLastEndMilliseconds = metadata.primaryStyleLastEndMilliseconds {
            try statement.bind(primaryStyleLastEndMilliseconds, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }
        if let lastSubtitleEndMilliseconds = metadata.lastSubtitleEndMilliseconds {
            try statement.bind(lastSubtitleEndMilliseconds, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 7)
        try statement.run()
    }

    private func insertCueLine(
        subtitleFileID: Int64,
        cueGroupID: Int64,
        ftsRowID: Int64,
        languageMask: Int,
        line: SubtitleCueLine,
        cueID: Int64? = nil
    ) throws -> Int64 {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_lines(
                id,
                subtitle_file_id,
                cue_group_id,
                fts_rowid,
                event_index,
                source_format,
                source_style,
                source_layer,
                source_identity_remainder,
                start_time,
                end_time,
                start_ms,
                end_ms,
                content,
                display_x,
                display_y,
                display_order,
                language_mask
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        if let cueID {
            try statement.bind(cueID, at: 1)
        } else {
            try statement.bindNull(at: 1)
        }
        try statement.bind(subtitleFileID, at: 2)
        try statement.bind(cueGroupID, at: 3)
        try statement.bind(ftsRowID, at: 4)
        try statement.bind(line.eventIndex, at: 5)
        try statement.bind(line.sourceFormat.rawValue, at: 6)
        if let sourceStyle = line.sourceStyle {
            try statement.bind(sourceStyle, at: 7)
        } else {
            try statement.bindNull(at: 7)
        }
        if let sourceLayer = line.sourceLayer {
            try statement.bind(sourceLayer, at: 8)
        } else {
            try statement.bindNull(at: 8)
        }
        try statement.bind(line.sourceIdentityRemainder, at: 9)
        try statement.bind(line.startTimecode, at: 10)
        try statement.bind(line.endTimecode, at: 11)
        try statement.bind(line.startMilliseconds, at: 12)
        try statement.bind(line.endMilliseconds, at: 13)
        try statement.bind(line.content, at: 14)
        if let displayX = line.displayX {
            try statement.bind(displayX, at: 15)
        } else {
            try statement.bindNull(at: 15)
        }
        if let displayY = line.displayY {
            try statement.bind(displayY, at: 16)
        } else {
            try statement.bindNull(at: 16)
        }
        try statement.bind(line.displayOrder, at: 17)
        try statement.bind(languageMask, at: 18)
        try statement.run()
        return cueID ?? database.lastInsertRowID()
    }

    private func validateLanguageAnalysis(
        _ languageAnalysis: SubtitleLanguageAnalysis?,
        format: SubtitleFormat,
        cueGroupCount: Int
    ) throws {
        guard let languageAnalysis else {
            return
        }

        guard languageAnalysis.format == format else {
            throw SQLiteDatabaseError.stepFailed(
                "Subtitle language analysis format does not match subtitle format."
            )
        }

        guard languageAnalysis.cueGroupLanguages.count == cueGroupCount else {
            throw SQLiteDatabaseError.stepFailed(
                "Subtitle language analysis cue group count does not match indexed cue group count."
            )
        }
    }

    private func insertSubtitleLanguageManifest(
        subtitleFileID: Int64,
        detectionCount: Int,
        cueGroupCount: Int
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_language_manifests(
                subtitle_file_id,
                algorithm_version,
                detection_count,
                cue_group_count,
                analyzed_at
            )
            VALUES (?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(SubtitleLanguageRecognizer.algorithmVersion, at: 2)
        try statement.bind(detectionCount, at: 3)
        try statement.bind(cueGroupCount, at: 4)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 5)
        try statement.run()
    }

    private func insertSubtitleLanguageDetection(
        subtitleFileID: Int64,
        scope: SubtitleLanguageDetectionScope,
        scopeKey: String?,
        detection: SubtitleLanguageDetectionResult
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_language_detections(
                subtitle_file_id,
                scope,
                scope_key,
                algorithm_version,
                confidence,
                confidence_band,
                segment_count,
                effective_character_count,
                detected_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(scope.rawValue, at: 2)
        try statement.bind(scopeKey ?? "", at: 3)
        try statement.bind(SubtitleLanguageRecognizer.algorithmVersion, at: 4)
        try statement.bind(detection.confidence, at: 5)
        try statement.bind(detection.confidenceBand.rawValue, at: 6)
        try statement.bind(detection.segmentCount, at: 7)
        try statement.bind(detection.effectiveCharacterCount, at: 8)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 9)
        try statement.run()

        let detectionID = database.lastInsertRowID()
        for language in detection.languages.sorted(by: { $0.rawValue < $1.rawValue }) {
            try insertSubtitleLanguageDetectionCode(detectionID: detectionID, language: language)
        }
        for (rank, item) in detection.distribution.enumerated() {
            try insertSubtitleLanguageDetectionDistribution(
                detectionID: detectionID,
                item: item,
                rank: rank
            )
        }
    }

    private func insertSubtitleLanguageDetectionCode(
        detectionID: Int64,
        language: SubtitleLanguageCode
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_language_detection_codes(detection_id, language_code)
            VALUES (?, ?);
            """
        )
        try statement.bind(detectionID, at: 1)
        try statement.bind(language.rawValue, at: 2)
        try statement.run()
    }

    private func insertSubtitleLanguageDetectionDistribution(
        detectionID: Int64,
        item: SubtitleLanguageDistribution,
        rank: Int
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_language_detection_distribution(
                detection_id,
                language_code,
                share,
                rank
            )
            VALUES (?, ?, ?, ?);
            """
        )
        try statement.bind(detectionID, at: 1)
        try statement.bind(item.language.rawValue, at: 2)
        try statement.bind(item.share, at: 3)
        try statement.bind(rank, at: 4)
        try statement.run()
    }

    private func insertCueGroupLanguages(
        cueGroupID: Int64,
        languages: Set<SubtitleLanguageCode>
    ) throws {
        let resolvedLanguages = languages.isEmpty ? Set([SubtitleLanguageCode.unknown]) : languages
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_group_languages(cue_group_id, language_code)
            VALUES (?, ?);
            """
        )
        for language in resolvedLanguages.sorted(by: { $0.rawValue < $1.rawValue }) {
            try statement.reset()
            try statement.clearBindings()
            try statement.bind(cueGroupID, at: 1)
            try statement.bind(language.rawValue, at: 2)
            try statement.run()
        }
    }

    private func subtitleLanguageDetectionCodes(
        detectionID: Int64
    ) throws -> Set<SubtitleLanguageCode> {
        let statement = try database.prepare(
            """
            SELECT language_code
            FROM subtitle_language_detection_codes
            WHERE detection_id = ?
            ORDER BY language_code ASC;
            """
        )
        try statement.bind(detectionID, at: 1)

        var languages = Set<SubtitleLanguageCode>()
        while try statement.step() {
            if let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) {
                languages.insert(language)
            }
        }

        return languages.isEmpty ? [.unknown] : languages
    }

    private func subtitleLanguageDetectionDistribution(
        detectionID: Int64
    ) throws -> [SubtitleLanguageDistribution] {
        let statement = try database.prepare(
            """
            SELECT language_code, share
            FROM subtitle_language_detection_distribution
            WHERE detection_id = ?
            ORDER BY rank ASC, language_code ASC;
            """
        )
        try statement.bind(detectionID, at: 1)

        var distribution: [SubtitleLanguageDistribution] = []
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) else {
                continue
            }
            distribution.append(
                SubtitleLanguageDistribution(
                    language: language,
                    share: statement.nullableDoubleColumn(1) ?? 0
                )
            )
        }

        return distribution
    }

    private func insertASSRenderSegment(
        subtitleFileID: Int64,
        segment: ASSRenderSegmentPayload
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO ass_render_segments(
                subtitle_file_id,
                segment_index,
                algorithm_version,
                start_ms,
                end_ms,
                event_count,
                byte_count,
                script_text
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(segment.segmentIndex, at: 2)
        try statement.bind(ASSRenderSegmenter.cacheAlgorithmVersion, at: 3)
        try statement.bind(segment.startMilliseconds, at: 4)
        try statement.bind(segment.endMilliseconds, at: 5)
        try statement.bind(segment.eventCount, at: 6)
        try statement.bind(segment.byteCount, at: 7)
        try statement.bind(segment.scriptText, at: 8)
        try statement.run()
    }

    private func insertASSFontReferenceManifest(
        subtitleFileID: Int64,
        referencedFontCount: Int
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO ass_font_reference_manifests(
                subtitle_file_id,
                algorithm_version,
                referenced_font_count,
                extracted_at
            )
            VALUES (?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(ASSFontIntentExtractor.cacheAlgorithmVersion, at: 2)
        try statement.bind(referencedFontCount, at: 3)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 4)
        try statement.run()
    }

    private func insertASSFontReference(
        subtitleFileID: Int64,
        reference: ASSFontReferenceIntent
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO ass_font_references(
                subtitle_file_id,
                font_name,
                source_location,
                occurrence_count,
                first_occurrence_order,
                algorithm_version
            )
            VALUES (?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(reference.fontName, at: 2)
        try statement.bind(reference.source.rawValue, at: 3)
        try statement.bind(reference.occurrenceCount, at: 4)
        try statement.bind(reference.firstOccurrenceOrder, at: 5)
        try statement.bind(ASSFontIntentExtractor.cacheAlgorithmVersion, at: 6)
        try statement.run()
    }

    private func cueLines(forCueGroupID cueGroupID: Int64) throws -> [SubtitleCueLine] {
        let statement = try database.prepare(
            """
            SELECT event_index, source_format, source_style, source_layer,
                   source_identity_remainder, start_time, end_time,
                   start_ms, end_ms, content,
                   display_x, display_y, display_order
            FROM subtitle_cue_lines
            WHERE cue_group_id = ?
            ORDER BY display_order ASC, event_index ASC, id ASC;
            """
        )

        try statement.bind(cueGroupID, at: 1)

        var lines: [SubtitleCueLine] = []
        while try statement.step() {
            lines.append(
                SubtitleCueLine(
                    eventIndex: statement.intColumn(0),
                    sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(1)) ?? .srt,
                    sourceStyle: statement.nullableStringColumn(2),
                    sourceLayer: statement.nullableIntColumn(3),
                    sourceIdentityRemainder: statement.stringColumn(4),
                    startTimecode: statement.stringColumn(5),
                    endTimecode: statement.stringColumn(6),
                    startMilliseconds: statement.intColumn(7),
                    endMilliseconds: statement.intColumn(8),
                    content: statement.stringColumn(9),
                    displayX: statement.nullableDoubleColumn(10),
                    displayY: statement.nullableDoubleColumn(11),
                    displayOrder: statement.intColumn(12)
                )
            )
        }

        return lines
    }


    private func cueLines(forCueGroupIDs cueGroupIDs: [Int64]) throws -> [Int64: [SubtitleCueLine]] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT cue_group_id, event_index, source_format, source_style, source_layer,
                   source_identity_remainder, start_time, end_time,
                   start_ms, end_ms, content,
                   display_x, display_y, display_order
            FROM subtitle_cue_lines
            WHERE cue_group_id IN (\(placeholders))
            ORDER BY cue_group_id ASC, display_order ASC, event_index ASC, id ASC;
            """
        )

        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var linesByCueGroupID: [Int64: [SubtitleCueLine]] = [:]
        linesByCueGroupID.reserveCapacity(cueGroupIDs.count)
        while try statement.step() {
            let cueGroupID = statement.int64Column(0)
            let line = SubtitleCueLine(
                eventIndex: statement.intColumn(1),
                sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
                sourceStyle: statement.nullableStringColumn(3),
                sourceLayer: statement.nullableIntColumn(4),
                sourceIdentityRemainder: statement.stringColumn(5),
                startTimecode: statement.stringColumn(6),
                endTimecode: statement.stringColumn(7),
                startMilliseconds: statement.intColumn(8),
                endMilliseconds: statement.intColumn(9),
                content: statement.stringColumn(10),
                displayX: statement.nullableDoubleColumn(11),
                displayY: statement.nullableDoubleColumn(12),
                displayOrder: statement.intColumn(13)
            )
            linesByCueGroupID[cueGroupID, default: []].append(line)
        }

        return linesByCueGroupID
    }


    private func deleteIndexedSubtitlePath(
        _ subtitlePath: String,
        preserveFileIdentity: Bool = false,
        unavailableReason: ExcerptUnavailableReason
    ) throws {
        if let subtitleFile = try subtitleFileRecord(path: subtitlePath) {
            try snapshotReferencedCues(
                subtitleFileID: subtitleFile.id,
                unavailableReason: unavailableReason
            )
        }
        let deleteLanguageDetectionDistribution = try database.prepare(
            """
            DELETE FROM subtitle_language_detection_distribution
            WHERE detection_id IN (
                SELECT d.id
                FROM subtitle_language_detections d
                JOIN subtitle_files sf ON sf.id = d.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try deleteLanguageDetectionDistribution.bind(subtitlePath, at: 1)
        try deleteLanguageDetectionDistribution.run()

        let deleteLanguageDetectionCodes = try database.prepare(
            """
            DELETE FROM subtitle_language_detection_codes
            WHERE detection_id IN (
                SELECT d.id
                FROM subtitle_language_detections d
                JOIN subtitle_files sf ON sf.id = d.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try deleteLanguageDetectionCodes.bind(subtitlePath, at: 1)
        try deleteLanguageDetectionCodes.run()

        let deleteLanguageDetections = try database.prepare(
            """
            DELETE FROM subtitle_language_detections
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteLanguageDetections.bind(subtitlePath, at: 1)
        try deleteLanguageDetections.run()

        let deleteLanguageManifests = try database.prepare(
            """
            DELETE FROM subtitle_language_manifests
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteLanguageManifests.bind(subtitlePath, at: 1)
        try deleteLanguageManifests.run()

        let deleteCueGroupLanguages = try database.prepare(
            """
            DELETE FROM subtitle_cue_group_languages
            WHERE cue_group_id IN (
                SELECT g.id
                FROM subtitle_cue_groups g
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try deleteCueGroupLanguages.bind(subtitlePath, at: 1)
        try deleteCueGroupLanguages.run()

        let deleteASSFontReferences = try database.prepare(
            """
            DELETE FROM ass_font_references
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteASSFontReferences.bind(subtitlePath, at: 1)
        try deleteASSFontReferences.run()

        let deleteASSFontReferenceManifests = try database.prepare(
            """
            DELETE FROM ass_font_reference_manifests
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteASSFontReferenceManifests.bind(subtitlePath, at: 1)
        try deleteASSFontReferenceManifests.run()

        let deleteASSRenderSegments = try database.prepare(
            """
            DELETE FROM ass_render_segments
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteASSRenderSegments.bind(subtitlePath, at: 1)
        try deleteASSRenderSegments.run()

        let deleteASSFontResources = try database.prepare(
            """
            DELETE FROM ass_font_resources
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteASSFontResources.bind(subtitlePath, at: 1)
        try deleteASSFontResources.run()

        let deletePlaybackFinishMetadata = try database.prepare(
            """
            DELETE FROM subtitle_playback_finish_metadata
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deletePlaybackFinishMetadata.bind(subtitlePath, at: 1)
        try deletePlaybackFinishMetadata.run()

        let deleteFTS = try database.prepare(
            """
            DELETE FROM subtitle_cue_groups_fts
            WHERE cue_group_id IN (
                SELECT g.id
                FROM subtitle_cue_groups g
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try deleteFTS.bind(subtitlePath, at: 1)
        try deleteFTS.run()

        let deleteLibraryRows = try database.prepare(
            "DELETE FROM library_video_rows WHERE subtitle_path = ?;"
        )
        try deleteLibraryRows.bind(subtitlePath, at: 1)
        try deleteLibraryRows.run()

        let deleteSearchOrderRows = try database.prepare(
            "DELETE FROM subtitle_search_order_rows WHERE subtitle_path = ?;"
        )
        try deleteSearchOrderRows.bind(subtitlePath, at: 1)
        try deleteSearchOrderRows.run()

        guard !preserveFileIdentity else {
            let deleteCueGroups = try database.prepare(
                """
                DELETE FROM subtitle_cue_groups
                WHERE subtitle_file_id IN (
                    SELECT id
                    FROM subtitle_files
                    WHERE subtitle_path = ?
                );
                """
            )
            try deleteCueGroups.bind(subtitlePath, at: 1)
            try deleteCueGroups.run()
            return
        }

        let deleteFile = try database.prepare(
            "DELETE FROM subtitle_files WHERE subtitle_path = ?;"
        )
        try deleteFile.bind(subtitlePath, at: 1)
        try deleteFile.run()
        try reconcileExcerptListRecentCues()
    }

    private func deleteOrphanedVideoFiles() throws {
        try database.execute(
            """
            DELETE FROM subtitle_video_matches
            WHERE is_active = 0
               OR subtitle_file_id NOT IN (SELECT id FROM subtitle_files);
            """
        )

        let statement = try database.prepare(
            """
            SELECT id
            FROM video_files
            WHERE id NOT IN (
                SELECT m.video_file_id
                FROM subtitle_video_matches m
                JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
                WHERE m.is_active = 1
            )
            ORDER BY id ASC;
            """
        )
        var orphanedVideoIDs: [Int64] = []
        while try statement.step() {
            orphanedVideoIDs.append(statement.int64Column(0))
        }
        for videoID in orphanedVideoIDs {
            try deleteVideoFile(id: videoID)
        }
    }

    private func bindStaleEntryParameters(
        statement: SQLiteStatement,
        folderPathPrefixes: [String],
        subtitleFiles: Set<String>
    ) throws {
        var bindIndex: Int32 = 1
        for prefix in folderPathPrefixes {
            try statement.bind(prefix.count, at: bindIndex)
            bindIndex += 1
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
        }

        for (offset, path) in subtitleFiles.sorted().enumerated() {
            try statement.bind(path, at: bindIndex + Int32(offset))
        }
    }

    private func staleSubtitleFileRecords(
        prefixCondition: String,
        keepCondition: String,
        folderPathPrefixes: [String],
        subtitleFiles: Set<String>
    ) throws -> [BoundResourceRecord] {
        let statement = try database.prepare(
            """
            SELECT sf.id, sf.subtitle_path
            FROM subtitle_files sf
            WHERE (\(prefixCondition)) \(keepCondition)
            ORDER BY sf.id ASC;
            """
        )
        try bindStaleEntryParameters(
            statement: statement,
            folderPathPrefixes: folderPathPrefixes,
            subtitleFiles: subtitleFiles
        )

        var records: [BoundResourceRecord] = []
        while try statement.step() {
            records.append(
                BoundResourceRecord(
                    id: statement.int64Column(0),
                    path: statement.stringColumn(1)
                )
            )
        }
        return records
    }

    private func staleMatchedVideoFileRecords(
        prefixCondition: String,
        keepCondition: String,
        folderPathPrefixes: [String],
        subtitleFiles: Set<String>
    ) throws -> [BoundResourceRecord] {
        let statement = try database.prepare(
            """
            SELECT DISTINCT vf.id, vf.path
            FROM subtitle_files sf
            JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE (\(prefixCondition)) \(keepCondition)
            ORDER BY vf.id ASC;
            """
        )
        try bindStaleEntryParameters(
            statement: statement,
            folderPathPrefixes: folderPathPrefixes,
            subtitleFiles: subtitleFiles
        )

        var records: [BoundResourceRecord] = []
        while try statement.step() {
            records.append(
                BoundResourceRecord(
                    id: statement.int64Column(0),
                    path: statement.stringColumn(1)
                )
            )
        }
        return records
    }

    private func indexedSubtitlePaths() throws -> [String] {
        let statement = try database.prepare(
            """
            SELECT subtitle_path
            FROM subtitle_files
            ORDER BY subtitle_path ASC;
            """
        )

        var paths: [String] = []
        while try statement.step() {
            paths.append(statement.stringColumn(0))
        }
        return paths
    }

    func libraryPathRecords() throws -> [LibraryPathRecord] {
        let statement = try database.prepare(
            """
            SELECT id, path
            FROM search_paths
            ORDER BY LENGTH(path) DESC, id ASC;
            """
        )

        var records: [LibraryPathRecord] = []
        while try statement.step() {
            records.append(
                LibraryPathRecord(
                    id: statement.int64Column(0),
                    rootURL: URL.fromMediaPath(statement.stringColumn(1))
                )
            )
        }
        return records
    }

    private func searchPathRecord(path: String) throws -> BoundResourceRecord? {
        try boundResourceRecord(
            sql: """
                SELECT id, path
                FROM search_paths
                WHERE path = ?
                LIMIT 1;
                """,
            value: path
        )
    }

    private func insertSearchPath(
        path: String,
        type: String,
        createdAt: String
    ) throws -> Int64 {
        let statement = try database.prepare(
            """
            INSERT INTO search_paths(type, path, created_at, updated_at)
            VALUES (?, ?, ?, ?)
            RETURNING id;
            """
        )
        try statement.bind(type, at: 1)
        try statement.bind(path, at: 2)
        try statement.bind(createdAt, at: 3)
        try statement.bind(createdAt, at: 4)
        guard try statement.step() else {
            return database.lastInsertRowID()
        }
        return statement.int64Column(0)
    }

    private func touchSearchPath(
        _ record: BoundResourceRecord,
        type: String,
        updatedAt: String
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE search_paths
            SET type = ?,
                updated_at = ?
            WHERE id = ?;
            """
        )
        try statement.bind(type, at: 1)
        try statement.bind(updatedAt, at: 2)
        try statement.bind(record.id, at: 3)
        try statement.run()
    }

    private func upsertLibraryFolder(for folder: URL, libraryID: Int64) throws -> Int64? {
        guard let library = try libraryPathRecords().first(where: { $0.id == libraryID })
        else {
            return nil
        }

        let standardizedFolder = folder.standardizedMediaURL
        let folderMediaPath = standardizedFolder.mediaPath
        let relativePath: String
        if folderMediaPath == library.rootURL.mediaPath {
            relativePath = ""
        } else if let relative = Self.relativeMediaPath(for: standardizedFolder, under: library.rootURL) {
            relativePath = relative
        } else {
            return nil
        }

        if let matchingPath = try libraryFolderRecord(
            libraryID: libraryID,
            relativePath: relativePath
        ) {
            try adoptFolderOwnedPaths(folderID: matchingPath.id)
            try updateFolderOwnedPaths(
                folderID: matchingPath.id,
                path: folderMediaPath
            )
            return matchingPath.id
        }

        let statement = try database.prepare(
            """
            INSERT INTO library_folders(library_id, relative_path)
            VALUES (?, ?)
            RETURNING id;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(relativePath, at: 2)
        let folderID: Int64
        if try statement.step() {
            folderID = statement.int64Column(0)
        } else {
            folderID = database.lastInsertRowID()
        }
        try adoptFolderOwnedPaths(folderID: folderID)
        return folderID
    }

    private func libraryFolderRecord(
        libraryID: Int64,
        relativePath: String
    ) throws -> BoundResourceRecord? {
        let statement = try database.prepare(
            """
            SELECT id, relative_path
            FROM library_folders
            WHERE library_id = ? AND relative_path = ?
            LIMIT 1;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(relativePath, at: 2)
        return try readBoundResourceRecord(statement)
    }

    func updateFolderOwnedPaths(folderID: Int64, path: String) throws {
        let generatedCover = try database.prepare(
            """
            UPDATE folder_covers
            SET folder_path = ?
            WHERE folder_id = ?;
            """
        )
        try generatedCover.bind(path, at: 1)
        try generatedCover.bind(folderID, at: 2)
        try generatedCover.run()

        let userCover = try database.prepare(
            """
            UPDATE user_folder_covers
            SET folder_path = ?
            WHERE folder_id = ?;
            """
        )
        try userCover.bind(path, at: 1)
        try userCover.bind(folderID, at: 2)
        try userCover.run()
    }

    private func adoptFolderOwnedPaths(folderID: Int64) throws {
        let generatedCover = try database.prepare(
            """
            UPDATE folder_covers
            SET folder_id = ?
            WHERE folder_id IS NULL
              AND folder_path = (
                  SELECT rtrim(sp.path || '/' || lf.relative_path, '/')
                  FROM library_folders lf
                  JOIN search_paths sp ON sp.id = lf.library_id
                  WHERE lf.id = ?
              );
            """
        )
        try generatedCover.bind(folderID, at: 1)
        try generatedCover.bind(folderID, at: 2)
        try generatedCover.run()

        let userCover = try database.prepare(
            """
            UPDATE user_folder_covers
            SET folder_id = ?
            WHERE folder_id IS NULL
              AND folder_path = (
                  SELECT rtrim(sp.path || '/' || lf.relative_path, '/')
                  FROM library_folders lf
                  JOIN search_paths sp ON sp.id = lf.library_id
                  WHERE lf.id = ?
              );
            """
        )
        try userCover.bind(folderID, at: 1)
        try userCover.bind(folderID, at: 2)
        try userCover.run()
    }

    private func mediaPathIdentity(
        for file: URL,
        preferredLibraryID: Int64? = nil
    ) throws -> MediaPathIdentity? {
        let libraries = try libraryPathRecords()
        if let preferredLibraryID,
           let library = libraries.first(where: { $0.id == preferredLibraryID }),
           let relativePath = Self.relativeMediaPath(for: file, under: library.rootURL) {
            return MediaPathIdentity(libraryID: library.id, relativePath: relativePath)
        }

        for library in libraries {
            if let relativePath = Self.relativeMediaPath(for: file, under: library.rootURL) {
                return MediaPathIdentity(libraryID: library.id, relativePath: relativePath)
            }
        }
        return nil
    }

    private func backfillMediaPathIdentities(libraryID: Int64, rootURL: URL) throws {
        let subtitleStatement = try database.prepare(
            """
            SELECT id, subtitle_path
            FROM subtitle_files
            WHERE library_id IS NULL;
            """
        )
        var subtitleUpdates: [(id: Int64, relativePath: String)] = []
        while try subtitleStatement.step() {
            let file = URL.fromMediaPath(subtitleStatement.stringColumn(1))
            if let relativePath = Self.relativeMediaPath(for: file, under: rootURL) {
                subtitleUpdates.append((subtitleStatement.int64Column(0), relativePath))
            }
        }

        let videoStatement = try database.prepare(
            """
            SELECT id, path
            FROM video_files
            WHERE library_id IS NULL;
            """
        )
        var videoUpdates: [(id: Int64, relativePath: String)] = []
        while try videoStatement.step() {
            let file = URL.fromMediaPath(videoStatement.stringColumn(1))
            if let relativePath = Self.relativeMediaPath(for: file, under: rootURL) {
                videoUpdates.append((videoStatement.int64Column(0), relativePath))
            }
        }

        let updateSubtitle = try database.prepare(
            "UPDATE subtitle_files SET library_id = ?, relative_path = ? WHERE id = ?;"
        )
        for update in subtitleUpdates {
            try updateSubtitle.bind(libraryID, at: 1)
            try updateSubtitle.bind(update.relativePath, at: 2)
            try updateSubtitle.bind(update.id, at: 3)
            try updateSubtitle.run()
            try updateSubtitle.reset()
        }

        let updateVideo = try database.prepare(
            "UPDATE video_files SET library_id = ?, relative_path = ? WHERE id = ?;"
        )
        for update in videoUpdates {
            try updateVideo.bind(libraryID, at: 1)
            try updateVideo.bind(update.relativePath, at: 2)
            try updateVideo.bind(update.id, at: 3)
            try updateVideo.run()
            try updateVideo.reset()
        }
    }

    private static func relativeMediaPath(for file: URL, under root: URL) -> String? {
        guard file.isWebDAVURL == root.isWebDAVURL else {
            return nil
        }
        let rootPath = normalizedFolderPath(root.mediaPath)
        let filePath = file.mediaPath
        let prefix = rootPath == "/" ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else {
            return nil
        }

        let relativePath = String(filePath.dropFirst(prefix.count))
            .precomposedStringWithCanonicalMapping
        return relativePath.isEmpty ? nil : relativePath
    }

    private func searchPaths() throws -> [String] {
        let statement = try database.prepare(
            """
            SELECT path
            FROM search_paths
            ORDER BY path ASC;
            """
        )

        var paths: [String] = []
        while try statement.step() {
            paths.append(statement.stringColumn(0))
        }
        return paths
    }

    /// Removing a Library deletes it. Re-adding the same path starts a new LibraryID.
    private func deleteSearchPath(_ searchPath: String) throws {
        guard let searchPathRecord = try searchPathRecord(path: searchPath) else {
            return
        }

        try deleteLibraryFolders(libraryID: searchPathRecord.id)

        let statement = try database.prepare(
            "DELETE FROM search_paths WHERE id = ?;"
        )
        try statement.bind(searchPathRecord.id, at: 1)
        try statement.run()
    }

    /// Auto-generated folder covers belong to the folder and go away with it,
    /// while manual folder covers remain detached by `folder_path` for same-path recovery.
    private func deleteLibraryFolders(libraryID: Int64) throws {
        let folderScope = """
            folder_id IN (
                SELECT id FROM library_folders WHERE library_id = ?
            )
            """
        for sql in [
            "DELETE FROM folder_covers WHERE \(folderScope);",
            "UPDATE user_folder_covers SET folder_id = NULL WHERE \(folderScope);",
            "UPDATE subtitle_files SET folder_id = NULL WHERE \(folderScope);",
            "UPDATE video_files SET folder_id = NULL WHERE \(folderScope);",
            "DELETE FROM library_folders WHERE library_id = ?;"
        ] {
            let statement = try database.prepare(sql)
            try statement.bind(libraryID, at: 1)
            try statement.run()
        }
    }

    /// A folder that no longer holds any indexed file has left the scan result,
    /// so it goes away together with its auto-generated covers while detaching manual covers.
    private func deleteEmptyLibraryFolders(libraryID: Int64) throws {
        let emptyFolders = """
            folder_id IN (
                SELECT lf.id
                FROM library_folders lf
                WHERE lf.library_id = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM subtitle_files sf WHERE sf.folder_id = lf.id
                  )
                  AND NOT EXISTS (
                      SELECT 1 FROM video_files vf WHERE vf.folder_id = lf.id
                  )
            )
            """
        for sql in [
            "DELETE FROM folder_covers WHERE \(emptyFolders);",
            "UPDATE user_folder_covers SET folder_id = NULL WHERE \(emptyFolders);",
            """
            DELETE FROM library_folders
            WHERE library_id = ?
              AND NOT EXISTS (
                  SELECT 1 FROM subtitle_files sf WHERE sf.folder_id = library_folders.id
              )
              AND NOT EXISTS (
                  SELECT 1 FROM video_files vf WHERE vf.folder_id = library_folders.id
              );
            """
        ] {
            let statement = try database.prepare(sql)
            try statement.bind(libraryID, at: 1)
            try statement.run()
        }
    }

    private static func path(_ path: String, isUnderAny folders: [URL]) -> Bool {
        let standardizedPath = URL.fromMediaPath(path).mediaPath
        return folders.contains { folder in
            folderPathPrefixes(for: folder).contains { prefix in
                standardizedPath.hasPrefix(prefix)
            }
        }
    }

    private static func folderPath(_ path: String, matchesAny folders: [URL]) -> Bool {
        let standardizedPath = normalizedFolderPath(URL.fromMediaPath(path).mediaPath)
        return folders.contains { folder in
            folderPathVariants(for: folder).contains(standardizedPath)
        }
    }

    private static func folderPathPrefixes(for folders: [URL]) -> [String] {
        Array(Set(folders.flatMap(folderPathPrefixes(for:)))).sorted()
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = normalizedFolderPath(folder.mediaPath)
        if !path.hasSuffix("/") {
            path.append("/")
        }

        var prefixes = Set([path])

        if path.hasPrefix("/var/") {
            prefixes.insert("/private" + path)
        } else if path.hasPrefix("/private/var/") {
            prefixes.insert(String(path.dropFirst("/private".count)))
        }

        return prefixes.sorted()
    }

    static func pathPrefixUpperBound(for prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }

    private static func folderPath(forSubtitlePath subtitlePath: String) -> String {
        URL.fromMediaPath(subtitlePath)
            .deletingLastPathComponent()
            .mediaPath
    }

    static func subtitlePathPrefix(forFolderPath folderPath: String) -> String {
        folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
    }

    static func folderPathVariants(for folder: URL) -> [String] {
        let path = normalizedFolderPath(folder.mediaPath)
        var paths = Set([path])

        if path.hasPrefix("/var/") {
            paths.insert("/private" + path)
        } else if path.hasPrefix("/private/var/") {
            paths.insert(String(path.dropFirst("/private".count)))
        }

        return paths.sorted()
    }

    private static func normalizedFolderPath(_ path: String) -> String {
        var path = path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}
