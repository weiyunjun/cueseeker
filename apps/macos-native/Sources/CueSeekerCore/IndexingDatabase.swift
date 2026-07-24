import Foundation

public final class IndexingDatabase: @unchecked Sendable {
    let path: URL
    private let database: SQLiteDatabase

    private struct LibraryPathRecord {
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
        let resourceIdentity: String?
        let contentFingerprint: String?
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
        let standardizedFolder = folder.standardizedFileURL
        let now = ISO8601DateFormatter().string(from: Date())
        let resourceIdentity = FileResourceIdentityResolver.resourceIdentifier(
            for: standardizedFolder
        )

        return try database.withImmediateTransaction {
            let matchingResource = try resourceIdentity.flatMap {
                try searchPathRecord(resourceIdentity: $0)
            }
            let matchingPath = try searchPathRecord(path: standardizedFolder.path)

            let libraryID: Int64
            if let matchingResource {
                if let matchingPath, matchingPath.id != matchingResource.id {
                    try retireSearchPath(matchingPath, state: .replaced, updatedAt: now)
                }
                try activateSearchPath(
                    matchingResource,
                    path: standardizedFolder.path,
                    type: type,
                    resourceIdentity: resourceIdentity,
                    updatedAt: now
                )
                libraryID = matchingResource.id
            } else if let matchingPath,
                      matchingPath.resourceIdentity == nil || resourceIdentity == nil
            {
                try activateSearchPath(
                    matchingPath,
                    path: standardizedFolder.path,
                    type: type,
                    resourceIdentity: resourceIdentity,
                    updatedAt: now
                )
                libraryID = matchingPath.id
            } else {
                if let matchingPath {
                    try retireSearchPath(matchingPath, state: .replaced, updatedAt: now)
                }
                libraryID = try insertSearchPath(
                    path: standardizedFolder.path,
                    type: type,
                    resourceIdentity: resourceIdentity,
                    createdAt: now
                )
            }

            try backfillMediaPathIdentities(libraryID: libraryID, rootURL: standardizedFolder)
            return libraryID
        }
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

    @discardableResult
    public func confirmSubtitleBindingConflict(
        conflictID: Int64,
        existingSubtitleID: Int64
    ) throws -> Int64 {
        try database.withImmediateTransaction {
            let conflict = try database.prepare(
                """
                SELECT library_id, candidate_path
                FROM resource_binding_conflicts
                WHERE id = ?
                  AND resource_kind = 'subtitle'
                  AND existing_resource_id = ?
                  AND resolved_at IS NULL;
                """
            )
            try conflict.bind(conflictID, at: 1)
            try conflict.bind(existingSubtitleID, at: 2)
            guard try conflict.step() else {
                throw SQLiteDatabaseError.stepFailed(
                    "Subtitle binding conflict is missing, resolved, or does not match the selected SubtitleID."
                )
            }
            let libraryID = conflict.int64Column(0)
            let candidatePath = conflict.stringColumn(1)
            guard let candidate = try subtitleFileRecord(path: candidatePath),
                  candidate.id != existingSubtitleID
            else {
                throw SQLiteDatabaseError.stepFailed(
                    "Subtitle binding candidate is no longer available."
                )
            }

            try retireSubtitleFile(candidate, state: .replaced)
            let releaseCandidateIdentity = try database.prepare(
                """
                UPDATE subtitle_files
                SET resource_identity = NULL,
                    content_fingerprint = NULL
                WHERE id = ?;
                """
            )
            try releaseCandidateIdentity.bind(candidate.id, at: 1)
            try releaseCandidateIdentity.run()
            let rebind = try database.prepare(
                """
                UPDATE subtitle_files
                SET library_id = (
                        SELECT library_id FROM subtitle_files WHERE id = ?
                    ),
                    folder_id = (
                        SELECT folder_id FROM subtitle_files WHERE id = ?
                    ),
                    relative_path = (
                        SELECT relative_path FROM subtitle_files WHERE id = ?
                    ),
                    subtitle_path = (
                        SELECT last_known_path FROM subtitle_files WHERE id = ?
                    ),
                    last_known_path = (
                        SELECT last_known_path FROM subtitle_files WHERE id = ?
                    ),
                    resource_identity = (
                        SELECT resource_identity FROM subtitle_files WHERE id = ?
                    ),
                    content_fingerprint = (
                        SELECT content_fingerprint FROM subtitle_files WHERE id = ?
                    ),
                    binding_state = 'available',
                    last_seen_at = (
                        SELECT last_seen_at FROM subtitle_files WHERE id = ?
                    ),
                    format = (
                        SELECT format FROM subtitle_files WHERE id = ?
                    ),
                    file_size = (
                        SELECT file_size FROM subtitle_files WHERE id = ?
                    ),
                    modified_at = (
                        SELECT modified_at FROM subtitle_files WHERE id = ?
                    ),
                    indexed_at = (
                        SELECT indexed_at FROM subtitle_files WHERE id = ?
                    ),
                    index_algorithm_version = (
                        SELECT index_algorithm_version FROM subtitle_files WHERE id = ?
                    )
                WHERE id = ?
                  AND library_id = ?;
                """
            )
            for index in 1...13 {
                try rebind.bind(candidate.id, at: Int32(index))
            }
            try rebind.bind(existingSubtitleID, at: 14)
            try rebind.bind(libraryID, at: 15)
            try rebind.run()
            guard database.changesCount() == 1 else {
                throw SQLiteDatabaseError.stepFailed(
                    "Selected SubtitleID does not belong to the binding conflict Library."
                )
            }

            let resolve = try database.prepare(
                """
                UPDATE resource_binding_conflicts
                SET resolved_at = ?
                WHERE library_id = ?
                  AND resource_kind = 'subtitle'
                  AND candidate_path = ?
                  AND resolved_at IS NULL;
                """
            )
            try resolve.bind(ISO8601DateFormatter().string(from: Date()), at: 1)
            try resolve.bind(libraryID, at: 2)
            try resolve.bind(candidatePath, at: 3)
            try resolve.run()
            return existingSubtitleID
        }
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
            let preservedCueLineSpeakers = try cueLineSpeakersByStableKey(forSubtitlePath: subtitleFile.path)
            var preservedShioris = try shioriRelationsByCueSourceIdentity(
                forSubtitlePath: subtitleFile.path
            )
            try deleteIndexedSubtitlePath(
                subtitleFile.path,
                preserveFileIdentity: true
            )

            let subtitleFileID = try upsertSubtitleFile(
                subtitleFile: subtitleFile,
                format: format,
                fileSize: fileSize,
                modifiedAt: modifiedAt
            )
            let videoFileID = try upsertVideoFile(videoFile)
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

            for (index, group) in cueGroups.enumerated() {
                let cueGroupID = try insertCueGroup(
                    subtitleFileID: subtitleFileID,
                    subtitleFile: subtitleFile,
                    group: group
                )
                for line in group.cueLines {
                    let cueLineID = try insertCueLine(
                        subtitleFileID: subtitleFileID,
                        cueGroupID: cueGroupID,
                        line: line
                    )
                    let speakerKey = CueLineStableKey(line: line)
                    if let speakers = preservedCueLineSpeakers[speakerKey] {
                        try insertCueLineSpeakers(
                            cueLineID: cueLineID,
                            cueGroupID: cueGroupID,
                            speakers: speakers
                        )
                    }
                    let cueIdentity = CueLineSourceIdentity(line: line)
                    if let relations = preservedShioris.removeValue(
                        forKey: cueIdentity
                    ) {
                        try restoreShioriRelations(relations, cueID: cueLineID)
                    }
                }
                try insertFTSRow(cueGroupID: cueGroupID, content: group.searchContent)
                if let languages = languageAnalysis?.cueGroupLanguages[index] {
                    try insertCueGroupLanguages(cueGroupID: cueGroupID, languages: languages)
                }
            }

            if rebuildSearchDerivedIndex {
                try rebuildSearchDerivedIndexInCurrentTransaction()
            }
            try deleteOrphanedVideoFiles()
        }
    }

    public func replaceCueLineSpeakers(
        forSubtitleFile subtitleFile: URL,
        assignments: [SubtitleCueLineSpeakerAssignment]
    ) throws {
        let cueGroupIDsByLineID = try cueGroupIDsByCueLineID(forSubtitleFile: subtitleFile)
        let assignedLineIDs = Set(assignments.map(\.cueLineID))
        guard assignedLineIDs.isSubset(of: Set(cueGroupIDsByLineID.keys)) else {
            throw SQLiteDatabaseError.stepFailed(
                "Speaker assignments contain cue lines outside subtitle file: \(subtitleFile.path)"
            )
        }

        try database.withImmediateTransaction {
            try clearCueLineSpeakersInCurrentTransaction(forSubtitleFile: subtitleFile)
            for assignment in assignments {
                guard let cueGroupID = cueGroupIDsByLineID[assignment.cueLineID] else {
                    continue
                }
                try insertCueLineSpeakers(
                    cueLineID: assignment.cueLineID,
                    cueGroupID: cueGroupID,
                    speakers: assignment.speakers
                )
            }
        }
    }

    public func clearCueLineSpeakers(forSubtitleFile subtitleFile: URL) throws {
        try database.withImmediateTransaction {
            try clearCueLineSpeakersInCurrentTransaction(forSubtitleFile: subtitleFile)
        }
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
        try statement.bind(subtitleFile.path, at: 1)

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
        try statement.bind(subtitleFile.path, at: 1)

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
        try statement.bind(subtitleFile.path, at: 1)

        guard try statement.step() else {
            return nil
        }

        return statement.int64Column(0)
    }

    private func cueGroupSpeakers(
        forCueGroupIDs cueGroupIDs: [Int64]
    ) throws -> [Int64: Set<String>] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT cue_group_id, speaker
            FROM subtitle_cue_line_speakers
            WHERE cue_group_id IN (\(placeholders))
            GROUP BY cue_group_id, speaker_key, speaker
            ORDER BY cue_group_id ASC, speaker_key ASC;
            """
        )

        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var speakersByCueGroupID: [Int64: Set<String>] = [:]
        while try statement.step() {
            speakersByCueGroupID[statement.int64Column(0), default: []].insert(statement.stringColumn(1))
        }

        return speakersByCueGroupID
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
        try statement.bind(subtitleFile.path, at: 1)

        guard try statement.step() else {
            return false
        }

        return statement.intColumn(0) == SubtitleLanguageRecognizer.algorithmVersion
    }


    public func subtitleFiles() throws -> [SubtitleFileMetadata] {
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   sf.file_size, sf.modified_at, sf.indexed_at, sf.index_algorithm_version
            FROM subtitle_files sf
            LEFT JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf ON vf.id = m.video_file_id
            WHERE sf.binding_state = 'available'
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
                    fileSize: statement.nullableInt64Column(4),
                    modifiedAt: statement.nullableDoubleColumn(5).map(Date.init(timeIntervalSince1970:)),
                    indexedAt: statement.stringColumn(6),
                    indexAlgorithmVersion: statement.intColumn(7)
                )
            )
        }

        return files
    }

    public func reconcileIndexedContent(activeFolders folders: [URL]) throws {
        let folders = folders.map(\.standardizedFileURL)
        guard !folders.isEmpty else {
            try clearIndexedContent()
            return
        }

        try database.withImmediateTransaction {
            let inactiveSubtitlePaths = try indexedSubtitlePaths()
                .filter { !Self.path($0, isUnderAny: folders) }
            for subtitlePath in inactiveSubtitlePaths {
                try deleteIndexedSubtitlePath(subtitlePath)
            }

            let inactiveSearchPaths = try searchPaths()
                .filter { !Self.folderPath($0, matchesAny: folders) }
            for searchPath in inactiveSearchPaths {
                try deleteSearchPath(searchPath)
            }

            try deleteOrphanedVideoFiles()
            try rebuildSearchDerivedIndexInCurrentTransaction()
        }
    }

    private func clearIndexedContent() throws {
        try database.withImmediateTransaction {
            try database.execute("DELETE FROM library_video_rows;")
            try database.execute("DELETE FROM subtitle_search_order_rows;")
            try database.execute("DELETE FROM subtitle_cue_groups_fts;")
            try database.execute("DELETE FROM ass_font_references;")
            try database.execute("DELETE FROM ass_font_reference_manifests;")
            try database.execute("DELETE FROM ass_render_segments;")
            try database.execute("DELETE FROM subtitle_files;")
            try database.execute("DELETE FROM video_files;")
            try database.execute("DELETE FROM library_folders;")
            try database.execute("DELETE FROM search_paths;")
        }
    }

    private func rebuildSearchOrderRows() throws {
        try database.execute("DELETE FROM subtitle_search_order_rows;")
        try insertSearchOrderRows(for: try indexedSearchOrderFiles(inFolderPath: nil))
    }

    private func rebuildSearchDerivedIndexInCurrentTransaction() throws {
        try rebuildSearchOrderRows()
        try rebuildFTSRowsInProductOrder()
    }

    private func requireCompleteSearchOrderRows(
        pathPrefixes: [String]?,
        subtitlePath: String?
    ) throws {
        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "AND (\(conditions))"
        } ?? ""
        let subtitlePathCondition = subtitlePath.map { _ in "AND sf.subtitle_path = ?" } ?? ""
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path
            FROM subtitle_files sf
            LEFT JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            WHERE sor.subtitle_file_id IS NULL
            \(scopeCondition)
            \(subtitlePathCondition)
            LIMIT 1;
            """
        )

        var bindIndex: Int32 = 1
        if let pathPrefixes {
            for prefix in pathPrefixes {
                try statement.bind(prefix, at: bindIndex)
                bindIndex += 1
                try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                bindIndex += 1
            }
        }
        if let subtitlePath {
            try statement.bind(subtitlePath, at: bindIndex)
        }

        guard try !statement.step() else {
            throw SQLiteDatabaseError.stepFailed(
                "Search order rows are missing for \(statement.stringColumn(0)). Rebuild derived Search order rows before searching."
            )
        }
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
                    folderTitle: URL(fileURLWithPath: folderPath).lastPathComponent,
                    subtitleFileName: URL(fileURLWithPath: subtitlePath).lastPathComponent
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
            let lhsTitle = URL(fileURLWithPath: lhs).lastPathComponent
            let rhsTitle = URL(fileURLWithPath: rhs).lastPathComponent
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
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
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
                try insert.bind(SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: file.subtitlePath), at: 6)
                try insert.bind(folderOrder, at: 7)
                try insert.bind(fileOrder, at: 8)
                try insert.bind(updatedAt, at: 9)
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
            rebuildSearchDerivedIndex: true
        )
    }

    public func removeIndexedFolder(_ folder: URL) throws {
        try removeIndexedData(
            under: folder,
            keeping: [],
            removeSearchPath: true,
            rebuildSearchDerivedIndex: false
        )
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

    private struct CueLineStableKey: Hashable {
        let sourceFormat: SubtitleFormat
        let sourceStyle: String?
        let sourceLayer: Int?
        let startTimecode: String
        let endTimecode: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let content: String
        let displayX: Double?
        let displayY: Double?

        init(line: SubtitleCueLine) {
            sourceFormat = line.sourceFormat
            sourceStyle = line.sourceStyle
            sourceLayer = line.sourceLayer
            startTimecode = line.startTimecode
            endTimecode = line.endTimecode
            startMilliseconds = line.startMilliseconds
            endMilliseconds = line.endMilliseconds
            content = line.content
            displayX = line.displayX
            displayY = line.displayY
        }

        init(statement: SQLiteStatement) {
            sourceFormat = SubtitleFormat(rawValue: statement.stringColumn(0)) ?? .srt
            sourceStyle = statement.nullableStringColumn(1)
            sourceLayer = statement.nullableIntColumn(2)
            startTimecode = statement.stringColumn(3)
            endTimecode = statement.stringColumn(4)
            startMilliseconds = statement.intColumn(5)
            endMilliseconds = statement.intColumn(6)
            content = statement.stringColumn(7)
            displayX = statement.nullableDoubleColumn(8)
            displayY = statement.nullableDoubleColumn(9)
        }
    }

    private struct CueLineSourceIdentity: Hashable {
        let sourceFormat: SubtitleFormat
        let eventIndex: Int
        let displayOrder: Int

        init(line: SubtitleCueLine) {
            sourceFormat = line.sourceFormat
            eventIndex = line.eventIndex
            displayOrder = line.displayOrder
        }

        init(statement: SQLiteStatement, columnOffset: Int32 = 0) {
            sourceFormat = SubtitleFormat(
                rawValue: statement.stringColumn(columnOffset)
            ) ?? .srt
            eventIndex = statement.intColumn(columnOffset + 1)
            displayOrder = statement.intColumn(columnOffset + 2)
        }
    }

    private struct PreservedShioriTagAssignment {
        let tagID: Int64
        let createdAt: String
    }

    private struct PreservedShioriRelation {
        let id: Int64
        let listID: Int64
        let createdAt: String
        let cueIdentity: CueLineSourceIdentity
        var tagAssignments: [PreservedShioriTagAssignment]
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
        rebuildSearchDerivedIndex: Bool
    ) throws {
        let folderPathPrefixes = Self.folderPathPrefixes(for: folder)
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

        try database.withImmediateTransaction {
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

            let deleteFiles = try database.prepare(
                """
                DELETE FROM subtitle_files
                WHERE id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteFiles,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteFiles.run()

            try deleteOrphanedVideoFiles()

            if removeSearchPath {
                for searchPath in Self.folderPathVariants(for: folder) {
                    try deleteSearchPath(searchPath)
                }
            }

            if rebuildSearchDerivedIndex {
                try rebuildSearchDerivedIndexInCurrentTransaction()
            }
        }
    }

    private func upsertSubtitleFile(
        subtitleFile: URL,
        format: SubtitleFormat,
        fileSize: Int64?,
        modifiedAt: Date?,
        libraryID: Int64? = nil
    ) throws -> Int64 {
        let pathIdentity = try mediaPathIdentity(for: subtitleFile, preferredLibraryID: libraryID)
        let fileIdentity = FileResourceIdentityResolver.resolve(
            subtitleFile,
            includesContentFingerprint: true
        )
        let folderID = try pathIdentity.flatMap {
            try upsertLibraryFolder(
                for: subtitleFile.deletingLastPathComponent(),
                libraryID: $0.libraryID
            )
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let matchingResource = try pathIdentity.flatMap { pathIdentity in
            try fileIdentity.resourceIdentifier.flatMap {
                try subtitleFileRecord(
                    libraryID: pathIdentity.libraryID,
                    resourceIdentity: $0
                )
            }
        }
        let matchingPath = try subtitleFileRecord(path: subtitleFile.path)

        let record: BoundResourceRecord?
        if let matchingResource {
            if let matchingPath, matchingPath.id != matchingResource.id {
                try retireSubtitleFile(matchingPath, state: .replaced)
            }
            if matchingResource.path != subtitleFile.path {
                try deleteIndexedSubtitlePath(
                    matchingResource.path,
                    preserveFileIdentity: true
                )
            }
            record = matchingResource
        } else if let matchingPath,
                  matchingPath.resourceIdentity == nil
                    || fileIdentity.resourceIdentifier == nil
                    || matchingPath.resourceIdentity == fileIdentity.resourceIdentifier
        {
            record = matchingPath
        } else if let pathIdentity,
                  let fingerprint = fileIdentity.contentFingerprint
        {
            let candidates = try subtitleFileRecords(
                libraryID: pathIdentity.libraryID,
                contentFingerprint: fingerprint
            ).filter {
                $0.path != subtitleFile.path
                    && !FileManager.default.fileExists(atPath: $0.path)
            }

            if candidates.count == 1, let candidate = candidates.first {
                if let matchingPath {
                    try retireSubtitleFile(matchingPath, state: .replaced)
                }
                try deleteIndexedSubtitlePath(candidate.path, preserveFileIdentity: true)
                record = candidate
            } else {
                if let matchingPath {
                    try retireSubtitleFile(matchingPath, state: .replaced)
                }
                for candidate in candidates {
                    try markSubtitleFileConflict(candidate)
                    try insertBindingConflict(
                        libraryID: pathIdentity.libraryID,
                        resourceKind: "subtitle",
                        existingResourceID: candidate.id,
                        candidatePath: subtitleFile.path,
                        reason: "Multiple missing subtitles have the same complete content fingerprint."
                    )
                }
                record = nil
            }
        } else {
            if let matchingPath {
                try retireSubtitleFile(matchingPath, state: .replaced)
            }
            record = nil
        }

        if let record {
            let statement = try database.prepare(
                """
                UPDATE subtitle_files
                SET library_id = ?,
                    folder_id = ?,
                    relative_path = ?,
                    subtitle_path = ?,
                    last_known_path = ?,
                    resource_identity = ?,
                    content_fingerprint = ?,
                    binding_state = 'available',
                    last_seen_at = ?,
                    format = ?,
                    file_size = ?,
                    modified_at = ?,
                    indexed_at = ?,
                    index_algorithm_version = ?
                WHERE id = ?;
                """
            )
            try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
            try statement.bind(subtitleFile.path, at: 4)
            try statement.bind(subtitleFile.path, at: 5)
            try bindOptional(fileIdentity.resourceIdentifier, to: statement, at: 6)
            try bindOptional(fileIdentity.contentFingerprint, to: statement, at: 7)
            try statement.bind(now, at: 8)
            try statement.bind(format.rawValue, at: 9)
            try bindOptional(fileSize, to: statement, at: 10)
            try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 11)
            try statement.bind(now, at: 12)
            try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 13)
            try statement.bind(record.id, at: 14)
            try statement.run()
            return record.id
        }

        let statement = try database.prepare(
            """
            INSERT INTO subtitle_files(
                library_id,
                folder_id,
                relative_path,
                subtitle_path,
                last_known_path,
                resource_identity,
                content_fingerprint,
                binding_state,
                last_seen_at,
                format,
                file_size,
                modified_at,
                indexed_at,
                index_algorithm_version
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 'available', ?, ?, ?, ?, ?, ?)
            RETURNING id;
            """
        )

        try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
        try statement.bind(subtitleFile.path, at: 4)
        try statement.bind(subtitleFile.path, at: 5)
        try bindOptional(fileIdentity.resourceIdentifier, to: statement, at: 6)
        try bindOptional(fileIdentity.contentFingerprint, to: statement, at: 7)
        try statement.bind(now, at: 8)
        try statement.bind(format.rawValue, at: 9)
        try bindOptional(fileSize, to: statement, at: 10)
        try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 11)
        try statement.bind(now, at: 12)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 13)

        guard try statement.step() else {
            return database.lastInsertRowID()
        }

        return statement.int64Column(0)
    }

    private func upsertVideoFile(_ videoFile: URL, libraryID: Int64? = nil) throws -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: videoFile.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value
        let modifiedAt = attributes?[.modificationDate] as? Date
        let pathIdentity = try mediaPathIdentity(for: videoFile, preferredLibraryID: libraryID)
        let fileIdentity = FileResourceIdentityResolver.resolve(
            videoFile,
            includesContentFingerprint: false
        )
        let folderID = try pathIdentity.flatMap {
            try upsertLibraryFolder(
                for: videoFile.deletingLastPathComponent(),
                libraryID: $0.libraryID
            )
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let matchingResource = try pathIdentity.flatMap { pathIdentity in
            try fileIdentity.resourceIdentifier.flatMap {
                try videoFileRecord(
                    libraryID: pathIdentity.libraryID,
                    resourceIdentity: $0
                )
            }
        }
        let matchingPath = try videoFileRecord(path: videoFile.path)
        let record: BoundResourceRecord?
        if let matchingResource {
            if let matchingPath, matchingPath.id != matchingResource.id {
                try retireVideoFile(matchingPath, state: .replaced)
            }
            record = matchingResource
        } else if let matchingPath,
                  matchingPath.resourceIdentity == nil
                    || fileIdentity.resourceIdentifier == nil
                    || matchingPath.resourceIdentity == fileIdentity.resourceIdentifier
        {
            record = matchingPath
        } else {
            if let matchingPath {
                try retireVideoFile(matchingPath, state: .replaced)
            }
            record = nil
        }

        if let record {
            try updateDurableVideoPaths(videoFileID: record.id, path: videoFile.path)
            let statement = try database.prepare(
                """
                UPDATE video_files
                SET library_id = ?,
                    folder_id = ?,
                    relative_path = ?,
                    path = ?,
                    last_known_path = ?,
                    resource_identity = ?,
                    binding_state = 'available',
                    last_seen_at = ?,
                    video_name = ?,
                    file_size = ?,
                    modified_at = ?
                WHERE id = ?;
                """
            )
            try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
            try statement.bind(videoFile.path, at: 4)
            try statement.bind(videoFile.path, at: 5)
            try bindOptional(fileIdentity.resourceIdentifier, to: statement, at: 6)
            try statement.bind(now, at: 7)
            try statement.bind(videoFile.lastPathComponent, at: 8)
            try bindOptional(fileSize, to: statement, at: 9)
            try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 10)
            try statement.bind(record.id, at: 11)
            try statement.run()
            return record.id
        }

        let statement = try database.prepare(
            """
            INSERT INTO video_files(
                library_id,
                folder_id,
                relative_path,
                path,
                last_known_path,
                resource_identity,
                binding_state,
                last_seen_at,
                video_name,
                file_size,
                modified_at
            )
            VALUES (?, ?, ?, ?, ?, ?, 'available', ?, ?, ?, ?)
            RETURNING id;
            """
        )

        try bindMediaPathIdentity(pathIdentity, folderID: folderID, to: statement)
        try statement.bind(videoFile.path, at: 4)
        try statement.bind(videoFile.path, at: 5)
        try bindOptional(fileIdentity.resourceIdentifier, to: statement, at: 6)
        try statement.bind(now, at: 7)
        try statement.bind(videoFile.lastPathComponent, at: 8)
        try bindOptional(fileSize, to: statement, at: 9)
        try bindOptional(modifiedAt?.timeIntervalSince1970, to: statement, at: 10)

        guard try statement.step() else {
            return database.lastInsertRowID()
        }

        return statement.int64Column(0)
    }

    private func subtitleFileRecord(path: String) throws -> BoundResourceRecord? {
        try boundResourceRecord(
            sql: """
                SELECT id, subtitle_path, resource_identity, content_fingerprint
                FROM subtitle_files
                WHERE subtitle_path = ?
                LIMIT 1;
                """,
            value: path,
            includesFingerprint: true
        )
    }

    private func subtitleFileRecord(
        libraryID: Int64,
        resourceIdentity: String
    ) throws -> BoundResourceRecord? {
        let statement = try database.prepare(
            """
            SELECT id, subtitle_path, resource_identity, content_fingerprint
            FROM subtitle_files
            WHERE library_id = ? AND resource_identity = ?
            LIMIT 1;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(resourceIdentity, at: 2)
        return try readBoundResourceRecord(statement, includesFingerprint: true)
    }

    private func subtitleFileRecords(
        libraryID: Int64,
        contentFingerprint: String
    ) throws -> [BoundResourceRecord] {
        let statement = try database.prepare(
            """
            SELECT id, subtitle_path, resource_identity, content_fingerprint
            FROM subtitle_files
            WHERE library_id = ? AND content_fingerprint = ?
            ORDER BY id ASC;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(contentFingerprint, at: 2)

        var records: [BoundResourceRecord] = []
        while let record = try readBoundResourceRecord(
            statement,
            includesFingerprint: true
        ) {
            records.append(record)
        }
        return records
    }

    private func videoFileRecord(path: String) throws -> BoundResourceRecord? {
        try boundResourceRecord(
            sql: """
                SELECT id, path, resource_identity
                FROM video_files
                WHERE path = ?
                LIMIT 1;
                """,
            value: path
        )
    }

    private func videoFileRecord(
        libraryID: Int64,
        resourceIdentity: String
    ) throws -> BoundResourceRecord? {
        let statement = try database.prepare(
            """
            SELECT id, path, resource_identity
            FROM video_files
            WHERE library_id = ? AND resource_identity = ?
            LIMIT 1;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(resourceIdentity, at: 2)
        return try readBoundResourceRecord(statement)
    }

    private func retireSubtitleFile(
        _ record: BoundResourceRecord,
        state: ResourceBindingState
    ) throws {
        try deleteIndexedSubtitlePath(record.path, preserveFileIdentity: true)
        let statement = try database.prepare(
            """
            UPDATE subtitle_files
            SET subtitle_path = ?,
                last_known_path = ?,
                binding_state = ?
            WHERE id = ?;
            """
        )
        try statement.bind(Self.unboundPath(kind: "subtitle", id: record.id), at: 1)
        try statement.bind(record.path, at: 2)
        try statement.bind(state.rawValue, at: 3)
        try statement.bind(record.id, at: 4)
        try statement.run()
    }

    private func markSubtitleFileConflict(_ record: BoundResourceRecord) throws {
        let statement = try database.prepare(
            """
            UPDATE subtitle_files
            SET last_known_path = ?,
                binding_state = 'conflict'
            WHERE id = ?;
            """
        )
        try statement.bind(record.path, at: 1)
        try statement.bind(record.id, at: 2)
        try statement.run()
    }

    private func retireVideoFile(
        _ record: BoundResourceRecord,
        state: ResourceBindingState
    ) throws {
        let unboundPath = Self.unboundPath(kind: "video", id: record.id)
        try updateDurableVideoPaths(videoFileID: record.id, path: unboundPath)
        let statement = try database.prepare(
            """
            UPDATE video_files
            SET path = ?,
                last_known_path = ?,
                binding_state = ?
            WHERE id = ?;
            """
        )
        try statement.bind(unboundPath, at: 1)
        try statement.bind(record.path, at: 2)
        try statement.bind(state.rawValue, at: 3)
        try statement.bind(record.id, at: 4)
        try statement.run()
    }

    private func updateDurableVideoPaths(videoFileID: Int64, path: String) throws {
        let history = try database.prepare(
            """
            UPDATE library_playback_history
            SET video_path = ?
            WHERE video_file_id = ?;
            """
        )
        try history.bind(path, at: 1)
        try history.bind(videoFileID, at: 2)
        try history.run()

        let watchState = try database.prepare(
            """
            UPDATE library_watch_states
            SET video_path = ?
            WHERE video_file_id = ?;
            """
        )
        try watchState.bind(path, at: 1)
        try watchState.bind(videoFileID, at: 2)
        try watchState.run()
    }

    private func insertBindingConflict(
        libraryID: Int64,
        resourceKind: String,
        existingResourceID: Int64?,
        candidatePath: String,
        reason: String
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO resource_binding_conflicts(
                library_id,
                resource_kind,
                existing_resource_id,
                candidate_path,
                reason,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?);
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(resourceKind, at: 2)
        try bindOptional(existingResourceID, to: statement, at: 3)
        try statement.bind(candidatePath, at: 4)
        try statement.bind(reason, at: 5)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 6)
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
        value: String,
        includesFingerprint: Bool = false
    ) throws -> BoundResourceRecord? {
        let statement = try database.prepare(sql)
        try statement.bind(value, at: 1)
        return try readBoundResourceRecord(
            statement,
            includesFingerprint: includesFingerprint
        )
    }

    private func readBoundResourceRecord(
        _ statement: SQLiteStatement,
        includesFingerprint: Bool = false
    ) throws -> BoundResourceRecord? {
        guard try statement.step() else {
            return nil
        }
        return BoundResourceRecord(
            id: statement.int64Column(0),
            path: statement.stringColumn(1),
            resourceIdentity: statement.nullableStringColumn(2),
            contentFingerprint: includesFingerprint
                ? statement.nullableStringColumn(3)
                : nil
        )
    }

    private static func unboundPath(kind: String, id: Int64) -> String {
        "cueseeker-unbound://\(kind)/\(id)"
    }

    private func upsertSubtitleVideoMatch(subtitleFileID: Int64, videoFileID: Int64) throws {
        let clearActive = try database.prepare(
            """
            UPDATE subtitle_video_matches
            SET is_active = 0
            WHERE subtitle_file_id = ?;
            """
        )
        try clearActive.bind(subtitleFileID, at: 1)
        try clearActive.run()

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

    private func cueLineSpeakersByStableKey(forSubtitlePath subtitlePath: String) throws -> [CueLineStableKey: Set<String>] {
        let statement = try database.prepare(
            """
            SELECT l.source_format, l.source_style, l.source_layer,
                   l.start_time, l.end_time, l.start_ms, l.end_ms,
                   l.content, l.display_x, l.display_y, s.speaker
            FROM subtitle_cue_line_speakers s
            JOIN subtitle_cue_lines l ON l.id = s.cue_line_id
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY l.id ASC, s.speaker_key ASC;
            """
        )
        try statement.bind(subtitlePath, at: 1)

        var speakersByKey: [CueLineStableKey: Set<String>] = [:]
        while try statement.step() {
            let key = CueLineStableKey(statement: statement)
            speakersByKey[key, default: []].insert(statement.stringColumn(10))
        }
        return speakersByKey
    }

    private func shioriRelationsByCueSourceIdentity(
        forSubtitlePath subtitlePath: String
    ) throws -> [CueLineSourceIdentity: [PreservedShioriRelation]] {
        let relationStatement = try database.prepare(
            """
            SELECT s.id, s.list_id, s.created_at,
                   l.source_format, l.event_index, l.display_order
            FROM shioris s
            JOIN subtitle_cue_lines l ON l.id = s.cue_id
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY s.id ASC;
            """
        )
        try relationStatement.bind(subtitlePath, at: 1)

        var relationsByID: [Int64: PreservedShioriRelation] = [:]
        while try relationStatement.step() {
            let shioriID = relationStatement.int64Column(0)
            relationsByID[shioriID] = PreservedShioriRelation(
                id: shioriID,
                listID: relationStatement.int64Column(1),
                createdAt: relationStatement.stringColumn(2),
                cueIdentity: CueLineSourceIdentity(
                    statement: relationStatement,
                    columnOffset: 3
                ),
                tagAssignments: []
            )
        }

        guard !relationsByID.isEmpty else { return [:] }

        let tagStatement = try database.prepare(
            """
            SELECT a.shiori_id, a.tag_id, a.created_at
            FROM shiori_tag_assignments a
            JOIN shioris s ON s.id = a.shiori_id
            JOIN subtitle_cue_lines l ON l.id = s.cue_id
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY a.shiori_id ASC, a.tag_id ASC;
            """
        )
        try tagStatement.bind(subtitlePath, at: 1)
        while try tagStatement.step() {
            let shioriID = tagStatement.int64Column(0)
            guard var relation = relationsByID[shioriID] else { continue }
            relation.tagAssignments.append(PreservedShioriTagAssignment(
                tagID: tagStatement.int64Column(1),
                createdAt: tagStatement.stringColumn(2)
            ))
            relationsByID[shioriID] = relation
        }

        return Dictionary(grouping: relationsByID.values, by: \.cueIdentity)
    }

    private func restoreShioriRelations(
        _ relations: [PreservedShioriRelation],
        cueID: Int64
    ) throws {
        let relationStatement = try database.prepare(
            """
            INSERT INTO shioris(id, list_id, cue_id, created_at)
            VALUES (?, ?, ?, ?);
            """
        )
        let tagStatement = try database.prepare(
            """
            INSERT INTO shiori_tag_assignments(shiori_id, tag_id, created_at)
            VALUES (?, ?, ?);
            """
        )

        for relation in relations.sorted(by: { $0.id < $1.id }) {
            try relationStatement.bind(relation.id, at: 1)
            try relationStatement.bind(relation.listID, at: 2)
            try relationStatement.bind(cueID, at: 3)
            try relationStatement.bind(relation.createdAt, at: 4)
            try relationStatement.run()
            try relationStatement.reset()

            for assignment in relation.tagAssignments {
                try tagStatement.bind(relation.id, at: 1)
                try tagStatement.bind(assignment.tagID, at: 2)
                try tagStatement.bind(assignment.createdAt, at: 3)
                try tagStatement.run()
                try tagStatement.reset()
            }
        }
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
        try statement.bind(subtitleFile.path, at: 2)
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
        try statement.bind(subtitleFile.path, at: 2)
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
        line: SubtitleCueLine
    ) throws -> Int64 {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_lines(
                subtitle_file_id,
                cue_group_id,
                event_index,
                source_format,
                source_style,
                source_layer,
                start_time,
                end_time,
                start_ms,
                end_ms,
                content,
                display_x,
                display_y,
                display_order
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(cueGroupID, at: 2)
        try statement.bind(line.eventIndex, at: 3)
        try statement.bind(line.sourceFormat.rawValue, at: 4)
        if let sourceStyle = line.sourceStyle {
            try statement.bind(sourceStyle, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }
        if let sourceLayer = line.sourceLayer {
            try statement.bind(sourceLayer, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        try statement.bind(line.startTimecode, at: 7)
        try statement.bind(line.endTimecode, at: 8)
        try statement.bind(line.startMilliseconds, at: 9)
        try statement.bind(line.endMilliseconds, at: 10)
        try statement.bind(line.content, at: 11)
        if let displayX = line.displayX {
            try statement.bind(displayX, at: 12)
        } else {
            try statement.bindNull(at: 12)
        }
        if let displayY = line.displayY {
            try statement.bind(displayY, at: 13)
        } else {
            try statement.bindNull(at: 13)
        }
        try statement.bind(line.displayOrder, at: 14)
        try statement.run()
        return database.lastInsertRowID()
    }

    private func cueGroupIDsByCueLineID(forSubtitleFile subtitleFile: URL) throws -> [Int64: Int64] {
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)

        var cueGroupIDsByLineID: [Int64: Int64] = [:]
        while try statement.step() {
            cueGroupIDsByLineID[statement.int64Column(0)] = statement.int64Column(1)
        }
        return cueGroupIDsByLineID
    }

    private func clearCueLineSpeakersInCurrentTransaction(forSubtitleFile subtitleFile: URL) throws {
        let statement = try database.prepare(
            """
            DELETE FROM subtitle_cue_line_speakers
            WHERE cue_line_id IN (
                SELECT l.id
                FROM subtitle_cue_lines l
                JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try statement.bind(subtitleFile.path, at: 1)
        try statement.run()
    }

    private func insertCueLineSpeakers(
        cueLineID: Int64,
        cueGroupID: Int64,
        speakers: Set<String>
    ) throws {
        let normalizedSpeakers = Self.normalizedSpeakerValues(speakers)
        guard !normalizedSpeakers.isEmpty else {
            return
        }

        let statement = try database.prepare(
            """
            INSERT OR REPLACE INTO subtitle_cue_line_speakers(
                cue_line_id,
                cue_group_id,
                speaker,
                speaker_key
            )
            VALUES (?, ?, ?, ?);
            """
        )

        for speaker in normalizedSpeakers {
            try statement.reset()
            try statement.clearBindings()
            try statement.bind(cueLineID, at: 1)
            try statement.bind(cueGroupID, at: 2)
            try statement.bind(speaker, at: 3)
            try statement.bind(Self.speakerKey(for: speaker), at: 4)
            try statement.run()
        }
    }

    private static func normalizedSpeakerValues(_ speakers: Set<String>) -> [String] {
        speakers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    private static func speakerKey(for speaker: String) -> String {
        speaker.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func insertFTSRow(
        rowID: Int64? = nil,
        cueGroupID: Int64,
        content: String
    ) throws {
        let statement: SQLiteStatement
        if let rowID {
            statement = try database.prepare(
                """
                INSERT INTO subtitle_cue_groups_fts(rowid, content, cue_group_id)
                VALUES (?, ?, ?);
                """
            )
            try statement.bind(rowID, at: 1)
            try statement.bind(SearchQueryPlanner.segmentForFTS(content), at: 2)
            try statement.bind(cueGroupID, at: 3)
        } else {
            statement = try database.prepare(
                """
                INSERT INTO subtitle_cue_groups_fts(content, cue_group_id)
                VALUES (?, ?);
                """
            )
            try statement.bind(SearchQueryPlanner.segmentForFTS(content), at: 1)
            try statement.bind(cueGroupID, at: 2)
        }
        try statement.run()
    }


    private func rebuildFTSRowsInProductOrder() throws {
        try requireCompleteSearchOrderRows(pathPrefixes: nil, subtitlePath: nil)
        try database.execute("DELETE FROM subtitle_cue_groups_fts;")

        var rows: [(cueGroupID: Int64, content: String)] = []
        let statement = try database.prepare(
            """
            SELECT g.id, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            ORDER BY sor.display_title COLLATE NOCASE ASC,
                     sf.subtitle_path COLLATE NOCASE ASC,
                     g.start_ms ASC,
                     g.end_ms ASC,
                     g.id ASC;
            """
        )

        while try statement.step() {
            rows.append((statement.int64Column(0), statement.stringColumn(1)))
        }

        for (index, row) in rows.enumerated() {
            try insertFTSRow(
                rowID: Int64(index + 1),
                cueGroupID: row.cueGroupID,
                content: row.content
            )
        }
    }

    private func cueLines(forCueGroupID cueGroupID: Int64) throws -> [SubtitleCueLine] {
        let statement = try database.prepare(
            """
            SELECT event_index, source_format, source_style, source_layer,
                   start_time, end_time, start_ms, end_ms, content,
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
                    startTimecode: statement.stringColumn(4),
                    endTimecode: statement.stringColumn(5),
                    startMilliseconds: statement.intColumn(6),
                    endMilliseconds: statement.intColumn(7),
                    content: statement.stringColumn(8),
                    displayX: statement.nullableDoubleColumn(9),
                    displayY: statement.nullableDoubleColumn(10),
                    displayOrder: statement.intColumn(11)
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
                   start_time, end_time, start_ms, end_ms, content,
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
                startTimecode: statement.stringColumn(5),
                endTimecode: statement.stringColumn(6),
                startMilliseconds: statement.intColumn(7),
                endMilliseconds: statement.intColumn(8),
                content: statement.stringColumn(9),
                displayX: statement.nullableDoubleColumn(10),
                displayY: statement.nullableDoubleColumn(11),
                displayOrder: statement.intColumn(12)
            )
            linesByCueGroupID[cueGroupID, default: []].append(line)
        }

        return linesByCueGroupID
    }


    private func deleteIndexedSubtitlePath(
        _ subtitlePath: String,
        preserveFileIdentity: Bool = false
    ) throws {
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
            let deleteMatches = try database.prepare(
                """
                DELETE FROM subtitle_video_matches
                WHERE subtitle_file_id IN (
                    SELECT id
                    FROM subtitle_files
                    WHERE subtitle_path = ?
                );
                """
            )
            try deleteMatches.bind(subtitlePath, at: 1)
            try deleteMatches.run()

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
    }

    private func deleteOrphanedVideoFiles() throws {
        try database.execute(
            """
            DELETE FROM video_files
            WHERE library_id IS NULL
              AND resource_identity IS NULL
              AND id NOT IN (
                SELECT DISTINCT video_file_id FROM subtitle_video_matches
            )
              AND id NOT IN (
                  SELECT video_file_id
                  FROM library_playback_history
                  WHERE video_file_id IS NOT NULL
              )
              AND id NOT IN (
                  SELECT video_file_id
                  FROM library_watch_states
                  WHERE video_file_id IS NOT NULL
              );
            """
        )
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

    private func libraryPathRecords() throws -> [LibraryPathRecord] {
        let statement = try database.prepare(
            """
            SELECT id, path
            FROM search_paths
            WHERE is_configured = 1
              AND binding_state = 'available'
            ORDER BY LENGTH(path) DESC, id ASC;
            """
        )

        var records: [LibraryPathRecord] = []
        while try statement.step() {
            records.append(
                LibraryPathRecord(
                    id: statement.int64Column(0),
                    rootURL: URL(fileURLWithPath: statement.stringColumn(1)).standardizedFileURL
                )
            )
        }
        return records
    }

    private func searchPathRecord(path: String) throws -> BoundResourceRecord? {
        try boundResourceRecord(
            sql: """
                SELECT id, path, resource_identity
                FROM search_paths
                WHERE path = ?
                LIMIT 1;
                """,
            value: path
        )
    }

    private func searchPathRecord(resourceIdentity: String) throws -> BoundResourceRecord? {
        try boundResourceRecord(
            sql: """
                SELECT id, path, resource_identity
                FROM search_paths
                WHERE resource_identity = ?
                LIMIT 1;
                """,
            value: resourceIdentity
        )
    }

    private func insertSearchPath(
        path: String,
        type: String,
        resourceIdentity: String?,
        createdAt: String
    ) throws -> Int64 {
        let statement = try database.prepare(
            """
            INSERT INTO search_paths(
                type,
                path,
                last_known_path,
                resource_identity,
                binding_state,
                is_configured,
                last_seen_at,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, 'available', 1, ?, ?, ?)
            RETURNING id;
            """
        )
        try statement.bind(type, at: 1)
        try statement.bind(path, at: 2)
        try statement.bind(path, at: 3)
        try bindOptional(resourceIdentity, to: statement, at: 4)
        try statement.bind(createdAt, at: 5)
        try statement.bind(createdAt, at: 6)
        try statement.bind(createdAt, at: 7)
        guard try statement.step() else {
            return database.lastInsertRowID()
        }
        return statement.int64Column(0)
    }

    private func activateSearchPath(
        _ record: BoundResourceRecord,
        path: String,
        type: String,
        resourceIdentity: String?,
        updatedAt: String
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE search_paths
            SET type = ?,
                path = ?,
                last_known_path = ?,
                resource_identity = ?,
                binding_state = 'available',
                is_configured = 1,
                last_seen_at = ?,
                updated_at = ?
            WHERE id = ?;
            """
        )
        try statement.bind(type, at: 1)
        try statement.bind(path, at: 2)
        try statement.bind(path, at: 3)
        try bindOptional(resourceIdentity ?? record.resourceIdentity, to: statement, at: 4)
        try statement.bind(updatedAt, at: 5)
        try statement.bind(updatedAt, at: 6)
        try statement.bind(record.id, at: 7)
        try statement.run()
    }

    private func retireSearchPath(
        _ record: BoundResourceRecord,
        state: ResourceBindingState,
        updatedAt: String
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE search_paths
            SET path = ?,
                last_known_path = ?,
                binding_state = ?,
                is_configured = 0,
                updated_at = ?
            WHERE id = ?;
            """
        )
        try statement.bind(Self.unboundPath(kind: "library", id: record.id), at: 1)
        try statement.bind(record.path, at: 2)
        try statement.bind(state.rawValue, at: 3)
        try statement.bind(updatedAt, at: 4)
        try statement.bind(record.id, at: 5)
        try statement.run()
    }

    private func upsertLibraryFolder(for folder: URL, libraryID: Int64) throws -> Int64? {
        guard let library = try libraryPathRecords().first(where: { $0.id == libraryID })
        else {
            return nil
        }

        let standardizedFolder = folder.standardizedFileURL
        let relativePath: String
        if standardizedFolder.path == library.rootURL.path {
            relativePath = ""
        } else if let relative = Self.relativeMediaPath(for: standardizedFolder, under: library.rootURL) {
            relativePath = relative
        } else {
            return nil
        }

        let resourceIdentity = FileResourceIdentityResolver.resourceIdentifier(
            for: standardizedFolder
        )
        let matchingResource = try resourceIdentity.flatMap {
            try libraryFolderRecord(libraryID: libraryID, resourceIdentity: $0)
        }
        let matchingPath = try libraryFolderRecord(
            libraryID: libraryID,
            relativePath: relativePath
        )
        let now = ISO8601DateFormatter().string(from: Date())

        if let matchingResource {
            if let matchingPath, matchingPath.id != matchingResource.id {
                try retireLibraryFolder(matchingPath)
            }
            try updateLibraryFolder(
                matchingResource.id,
                relativePath: relativePath,
                lastKnownPath: standardizedFolder.path,
                resourceIdentity: resourceIdentity ?? matchingResource.resourceIdentity,
                lastSeenAt: now
            )
            return matchingResource.id
        }

        if let matchingPath,
           matchingPath.resourceIdentity == nil || resourceIdentity == nil
        {
            try updateLibraryFolder(
                matchingPath.id,
                relativePath: relativePath,
                lastKnownPath: standardizedFolder.path,
                resourceIdentity: resourceIdentity,
                lastSeenAt: now
            )
            return matchingPath.id
        }

        if let matchingPath {
            try retireLibraryFolder(matchingPath)
        }
        let statement = try database.prepare(
            """
            INSERT INTO library_folders(
                library_id,
                relative_path,
                last_known_path,
                resource_identity,
                binding_state,
                last_seen_at
            )
            VALUES (?, ?, ?, ?, 'available', ?)
            RETURNING id;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(relativePath, at: 2)
        try statement.bind(standardizedFolder.path, at: 3)
        try bindOptional(resourceIdentity, to: statement, at: 4)
        try statement.bind(now, at: 5)
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
            SELECT id, relative_path, resource_identity
            FROM library_folders
            WHERE library_id = ? AND relative_path = ?
            LIMIT 1;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(relativePath, at: 2)
        return try readBoundResourceRecord(statement)
    }

    private func libraryFolderRecord(
        libraryID: Int64,
        resourceIdentity: String
    ) throws -> BoundResourceRecord? {
        let statement = try database.prepare(
            """
            SELECT id, relative_path, resource_identity
            FROM library_folders
            WHERE library_id = ? AND resource_identity = ?
            LIMIT 1;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(resourceIdentity, at: 2)
        return try readBoundResourceRecord(statement)
    }

    private func updateLibraryFolder(
        _ id: Int64,
        relativePath: String,
        lastKnownPath: String,
        resourceIdentity: String?,
        lastSeenAt: String
    ) throws {
        try adoptFolderOwnedPaths(folderID: id)
        try updateFolderOwnedPaths(folderID: id, path: lastKnownPath)
        let statement = try database.prepare(
            """
            UPDATE library_folders
            SET relative_path = ?,
                last_known_path = ?,
                resource_identity = ?,
                binding_state = 'available',
                last_seen_at = ?
            WHERE id = ?;
            """
        )
        try statement.bind(relativePath, at: 1)
        try statement.bind(lastKnownPath, at: 2)
        try bindOptional(resourceIdentity, to: statement, at: 3)
        try statement.bind(lastSeenAt, at: 4)
        try statement.bind(id, at: 5)
        try statement.run()
    }

    private func retireLibraryFolder(_ record: BoundResourceRecord) throws {
        let unboundPath = Self.unboundPath(kind: "folder", id: record.id)
        try updateFolderOwnedPaths(folderID: record.id, path: unboundPath)
        let statement = try database.prepare(
            """
            UPDATE library_folders
            SET relative_path = ?,
                binding_state = 'replaced'
            WHERE id = ?;
            """
        )
        try statement.bind("__cueseeker_unbound__/folder/\(record.id)", at: 1)
        try statement.bind(record.id, at: 2)
        try statement.run()
    }

    private func updateFolderOwnedPaths(folderID: Int64, path: String) throws {
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
                  SELECT last_known_path
                  FROM library_folders
                  WHERE id = ?
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
                  SELECT last_known_path
                  FROM library_folders
                  WHERE id = ?
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
            let file = URL(fileURLWithPath: subtitleStatement.stringColumn(1))
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
            let file = URL(fileURLWithPath: videoStatement.stringColumn(1))
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
        let rootPath = normalizedFolderPath(root.standardizedFileURL.path)
        let filePath = file.standardizedFileURL.path
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

    private func deleteSearchPath(_ searchPath: String) throws {
        let detachSubtitleFiles = try database.prepare(
            """
            UPDATE subtitle_files
            SET library_id = NULL, folder_id = NULL, relative_path = NULL
            WHERE library_id IN (
                SELECT id FROM search_paths WHERE path = ?
            );
            """
        )
        try detachSubtitleFiles.bind(searchPath, at: 1)
        try detachSubtitleFiles.run()

        let detachVideoFiles = try database.prepare(
            """
            UPDATE video_files
            SET library_id = NULL, folder_id = NULL, relative_path = NULL
            WHERE library_id IN (
                SELECT id FROM search_paths WHERE path = ?
            );
            """
        )
        try detachVideoFiles.bind(searchPath, at: 1)
        try detachVideoFiles.run()

        let deleteFolders = try database.prepare(
            """
            DELETE FROM library_folders
            WHERE library_id IN (
                SELECT id FROM search_paths WHERE path = ?
            );
            """
        )
        try deleteFolders.bind(searchPath, at: 1)
        try deleteFolders.run()

        let statement = try database.prepare(
            "DELETE FROM search_paths WHERE path = ?;"
        )
        try statement.bind(searchPath, at: 1)
        try statement.run()
    }

    private static func path(_ path: String, isUnderAny folders: [URL]) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return folders.contains { folder in
            folderPathPrefixes(for: folder).contains { prefix in
                standardizedPath.hasPrefix(prefix)
            }
        }
    }

    private static func folderPath(_ path: String, matchesAny folders: [URL]) -> Bool {
        let standardizedPath = normalizedFolderPath(URL(fileURLWithPath: path).standardizedFileURL.path)
        return folders.contains { folder in
            folderPathVariants(for: folder).contains(standardizedPath)
        }
    }

    private static func folderPathPrefixes(for folders: [URL]) -> [String] {
        Array(Set(folders.flatMap(folderPathPrefixes(for:)))).sorted()
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = normalizedFolderPath(folder.standardizedFileURL.path)
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

    private static func pathPrefixUpperBound(for prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }

    private static func folderPath(forSubtitlePath subtitlePath: String) -> String {
        URL(fileURLWithPath: subtitlePath)
            .deletingLastPathComponent()
            .standardizedFileURL
            .path
    }

    private static func subtitlePathPrefix(forFolderPath folderPath: String) -> String {
        folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
    }

    private static func folderPathVariants(for folder: URL) -> [String] {
        let path = normalizedFolderPath(folder.standardizedFileURL.path)
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
