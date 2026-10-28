import Foundation

public final class IndexingDatabase: @unchecked Sendable {
    let path: URL
    let database: SQLiteDatabase

    struct LibraryPathRecord {
        let id: Int64
        let rootURL: URL
    }

    struct MediaPathIdentity {
        let libraryID: Int64
        let relativePath: String
    }

    struct BoundResourceRecord {
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
                index.folder,
                reuseCoveringLibrary: true
            )
            let hadPendingPresentationRefresh =
                try libraryPresentationRetryPending(
                    libraryID: libraryID
                )

            let clearedCueChangeNotices = try clearPriorCueChangeNotices(
                libraryID: libraryID,
                under: index.folder
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
                    assFontReferences: file.assFontReferences,
                    fileSize: file.fileSize,
                    modifiedAt: file.modifiedAt,
                    rawCueCount: file.rawCueCount,
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

            for refresh in index.rawCueCountRefreshes {
                let statement = try database.prepare(
                    """
                    UPDATE subtitle_files
                    SET raw_cue_count = ?
                    WHERE subtitle_path = ?;
                    """
                )
                try statement.bind(refresh.rawCueCount, at: 1)
                try statement.bind(refresh.subtitleFile.mediaPath, at: 2)
                try statement.run()
            }

            let removal = try removeIndexedDataInCurrentTransaction(
                under: index.folder,
                keeping: index.keptSubtitlePaths,
                missingVideoSubtitlePaths: Set(
                    index.missingVideoSubtitleFiles.map(\.mediaPath)
                ),
                removeSearchPath: false,
                rebuildSearchDerivedIndex: false,
                unavailableReason: .subtitleMissing
            )
            changedSubtitlePaths.formUnion(removal.removedSubtitlePaths)
            affectedFolderPaths.formUnion(removal.affectedFolderPaths)
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
                    libraryID: libraryID,
                    under: index.folder
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
            try refreshPublishedFolderTimestamps(
                for: index.folder,
                libraryID: libraryID,
                publishedAt: publishedAt
            )
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

    private func refreshPublishedFolderTimestamps(
        for folder: URL,
        libraryID: Int64,
        publishedAt: String
    ) throws {
        let standardizedFolder = folder.standardizedMediaURL
        let folderMediaPath = standardizedFolder.mediaPath
        let upsertRoot = try database.prepare(
            """
            INSERT INTO library_root_folders(path, created_at, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                created_at = CASE
                    WHEN library_root_folders.created_at = '' THEN excluded.created_at
                    ELSE library_root_folders.created_at
                END,
                updated_at = excluded.updated_at;
            """
        )
        try upsertRoot.bind(folderMediaPath, at: 1)
        try upsertRoot.bind(publishedAt, at: 2)
        try upsertRoot.bind(publishedAt, at: 3)
        try upsertRoot.run()

        let selectRoots = try database.prepare(
            "SELECT path FROM library_root_folders ORDER BY path ASC;"
        )
        var coveredRootPaths: [String] = []
        while try selectRoots.step() {
            let rowPath = selectRoots.stringColumn(0)
            let rowURL = URL.fromMediaPath(rowPath).standardizedMediaURL
            if LibraryRootGroups.holds(standardizedFolder, rowURL) {
                coveredRootPaths.append(rowPath)
            }
        }
        if !coveredRootPaths.isEmpty {
            let updateCoveredRoot = try database.prepare(
                """
                UPDATE library_root_folders
                SET created_at = CASE WHEN created_at = '' THEN ? ELSE created_at END,
                    updated_at = ?
                WHERE path = ?;
                """
            )
            for rowPath in coveredRootPaths {
                try updateCoveredRoot.bind(publishedAt, at: 1)
                try updateCoveredRoot.bind(publishedAt, at: 2)
                try updateCoveredRoot.bind(rowPath, at: 3)
                try updateCoveredRoot.run()
                try updateCoveredRoot.reset()
            }
        }

        guard let library = try libraryPathRecords().first(where: { $0.id == libraryID }) else {
            return
        }
        if folderMediaPath == library.rootURL.mediaPath {
            let updateFolders = try database.prepare(
                """
                UPDATE library_folders
                SET created_at = CASE WHEN created_at = '' THEN ? ELSE created_at END,
                    updated_at = ?
                WHERE library_id = ?;
                """
            )
            try updateFolders.bind(publishedAt, at: 1)
            try updateFolders.bind(publishedAt, at: 2)
            try updateFolders.bind(libraryID, at: 3)
            try updateFolders.run()
        } else if let prefix = Self.relativeMediaPath(for: standardizedFolder, under: library.rootURL) {
            let slashPrefix = prefix + "/"
            let upperBound = Self.pathPrefixUpperBound(for: slashPrefix)
            let updateFolders = try database.prepare(
                """
                UPDATE library_folders
                SET created_at = CASE WHEN created_at = '' THEN ? ELSE created_at END,
                    updated_at = ?
                WHERE library_id = ?
                  AND (relative_path = ? OR (relative_path >= ? AND relative_path < ?));
                """
            )
            try updateFolders.bind(publishedAt, at: 1)
            try updateFolders.bind(publishedAt, at: 2)
            try updateFolders.bind(libraryID, at: 3)
            try updateFolders.bind(prefix, at: 4)
            try updateFolders.bind(slashPrefix, at: 5)
            try updateFolders.bind(upperBound, at: 6)
            try updateFolders.run()
        }
    }

    func libraryPresentationRetryPending(
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

    func markLibraryPresentationRetryPending(
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
        libraryID: Int64,
        under folder: URL
    ) throws -> Set<String> {
        let prefixes = Self.folderPathPrefixes(for: folder)
        let statement = try database.prepare(
            """
            SELECT path
            FROM video_files
            WHERE library_id = ?
              AND (duration_retry_pending = 1 OR audio_tracks IS NULL OR container_format IS NULL)
            ORDER BY path ASC;
            """
        )
        try statement.bind(libraryID, at: 1)
        var paths = Set<String>()
        while try statement.step() {
            let path = statement.stringColumn(0)
            if prefixes.contains(where: { path.hasPrefix($0) }) {
                paths.insert(path)
            }
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
        assFontReferences: [ASSFontReferenceIntent] = [],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: format,
            cueGroups: cueGroups,
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
        assFontReferences: [ASSFontReferenceIntent],
        fileSize: Int64?,
        modifiedAt: Date?,
        rawCueCount: Int? = nil,
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
            rawCueCount: rawCueCount,
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

        if format.usesASSSemantics {
            try insertASSFontReferenceManifest(
                subtitleFileID: subtitleFileID,
                referencedFontCount: assFontReferences.count
            )
            for reference in assFontReferences {
                try insertASSFontReference(subtitleFileID: subtitleFileID, reference: reference)
            }
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
                   sf.modified_at, sf.raw_cue_count, sf.indexed_at, sf.index_algorithm_version
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
                    rawCueCount: statement.nullableIntColumn(8),
                    indexedAt: statement.stringColumn(9),
                    indexAlgorithmVersion: statement.intColumn(10)
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
                let removal = try removeIndexedDataInCurrentTransaction(
                    under: URL.fromMediaPath(searchPath),
                    keeping: [],
                    removeSearchPath: true,
                    rebuildSearchDerivedIndex: false,
                    unavailableReason: .libraryUnavailable
                )
                removedIndexedContent = removedIndexedContent || !removal.affectedFolderPaths.isEmpty
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
    public func compactStorage() throws {
        try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        try database.execute("VACUUM;")
        try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    }

    /// its indexed content. One transaction, so either all of it happens or
    /// none of it.
    @discardableResult
    public func removeIndexedFolder(
        _ folder: URL,
        keepingNestedRoots nestedRoots: [URL] = [],
        compactAfterRemovingSubtitles: Bool = true
    ) throws -> Bool {
        let removal = try database.withImmediateTransaction {
            var keptSubtitlePaths = Set<String>()
            for nestedRoot in nestedRoots {
                keptSubtitlePaths.formUnion(try separateNestedLibrary(nestedRoot))
            }
            let removal = try removeIndexedDataInCurrentTransaction(
                under: folder,
                keeping: keptSubtitlePaths,
                removeSearchPath: true,
                rebuildSearchDerivedIndex: false,
                unavailableReason: .libraryUnavailable
            )
            if !removal.affectedFolderPaths.isEmpty {
                try CueFacetCountCache.rebuildAll(on: database)
            }
            return removal
        }
        if compactAfterRemovingSubtitles, !removal.removedSubtitlePaths.isEmpty {
            try compactStorage()
        }
        return !removal.affectedFolderPaths.isEmpty
    }

    private struct SearchOrderFile {
        let subtitleFileID: Int64
        let subtitlePath: String
        let folderPath: String
        let folderTitle: String
        let subtitleFileName: String
    }

    private func removeIndexedData(
        under folder: URL,
        keeping subtitleFiles: Set<String>,
        removeSearchPath: Bool,
        rebuildSearchDerivedIndex: Bool,
        unavailableReason: ExcerptUnavailableReason
    ) throws {
        try database.withImmediateTransaction {
            let removal = try removeIndexedDataInCurrentTransaction(
                under: folder,
                keeping: subtitleFiles,
                removeSearchPath: removeSearchPath,
                rebuildSearchDerivedIndex: rebuildSearchDerivedIndex,
                unavailableReason: unavailableReason
            )
            if !removal.affectedFolderPaths.isEmpty {
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
    ) throws -> (affectedFolderPaths: Set<String>, removedSubtitlePaths: Set<String>) {
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
        let removedSubtitlePaths = Set(staleSubtitleFiles.map(\.path))
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
            return (affectedFolderPaths, removedSubtitlePaths)
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
        return (affectedFolderPaths, removedSubtitlePaths)
    }

    private func upsertSubtitleFile(
        subtitleFile: URL,
        format: SubtitleFormat,
        fileSize: Int64?,
        modifiedAt: Date?,
        rawCueCount: Int? = nil,
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
                    raw_cue_count = ?,
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
            try bindOptional(rawCueCount, to: statement, at: 8)
            try statement.bind(now, at: 9)
            try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 10)
            try statement.bind(record.id, at: 11)
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
                raw_cue_count,
                indexed_at,
                index_algorithm_version
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            RETURNING id;
            """
        )

        try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
        try statement.bind(subtitleMediaPath, at: 4)
        try statement.bind(format.rawValue, at: 5)
        try bindOptional(fileSize, to: statement, at: 6)
        try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 7)
        try bindOptional(rawCueCount, to: statement, at: 8)
        try statement.bind(now, at: 9)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 10)

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
        if videoFile.isRemoteMediaURL {
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

    func bindOptional(
        _ value: Int?,
        to statement: SQLiteStatement,
        at index: Int32
    ) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

    func bindOptional(
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

    func bindOptional(
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

    func boundResourceRecord(
        sql: String,
        value: String
    ) throws -> BoundResourceRecord? {
        let statement = try database.prepare(sql)
        try statement.bind(value, at: 1)
        return try readBoundResourceRecord(statement)
    }

    func readBoundResourceRecord(
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
                duration_ms,
                character_width,
                content,
                display_x,
                display_y,
                display_order,
                language_mask
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
        try statement.bind(line.durationMilliseconds, at: 14)
        try statement.bind(line.characterWidth, at: 15)
        try statement.bind(line.content, at: 16)
        if let displayX = line.displayX {
            try statement.bind(displayX, at: 17)
        } else {
            try statement.bindNull(at: 17)
        }
        if let displayY = line.displayY {
            try statement.bind(displayY, at: 18)
        } else {
            try statement.bindNull(at: 18)
        }
        try statement.bind(line.displayOrder, at: 19)
        try statement.bind(languageMask, at: 20)
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
            try statement.bind(prefix.unicodeScalars.count, at: bindIndex)
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
}
