import Foundation

public final class ExcerptDatabase: @unchecked Sendable {
    public static let maximumListNameCharacters = 30
    public static let maximumListDescriptionCharacters = 100

    private static let resolvedExcerptSelectSQL = """
        SELECT s.id,
               COALESCE(sf.subtitle_path, t.subtitle_path, ''),
               COALESCE(sf.format, t.source_format, 'srt'),
               COALESCE(vf.path, t.video_path, ''),
               COALESCE(vf.video_name, t.display_title, ''),
               COALESCE(l.start_ms, t.start_ms, 0),
               COALESCE(l.end_ms, t.end_ms, 0),
               l.event_index,
               l.display_order,
               COALESCE(l.content, t.content, ''),
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
                 t.cue_group_content,
                 l.content,
                 t.content,
                 ''
               ),
               CASE
                 WHEN l.id IS NULL THEN COALESCE(t.unavailable_reason, 'cue_missing')
                 WHEN sf.id IS NULL THEN 'subtitle_missing'
                 WHEN vf.id IS NULL THEN 'video_missing'
                 ELSE NULL
               END,
               s.created_at,
               n.previous_content,
               n.current_content,
               COALESCE(
                 (
                   SELECT sor.display_title
                   FROM subtitle_search_order_rows sor
                   WHERE sor.subtitle_file_id = sf.id
                   ORDER BY sor.updated_at DESC, sor.subtitle_path ASC
                   LIMIT 1
                 ),
                 t.display_title,
                 vf.video_name,
                 ''
               ),
               sf.id
        FROM excerpts s
        LEFT JOIN subtitle_cue_lines l ON l.id = s.cue_id
        LEFT JOIN cue_tombstones t ON t.cue_id = s.cue_id
        LEFT JOIN subtitle_files sf
          ON sf.id = COALESCE(l.subtitle_file_id, t.subtitle_file_id)
        LEFT JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
        LEFT JOIN subtitle_video_matches m
          ON m.subtitle_file_id = sf.id AND m.is_active = 1
        LEFT JOIN video_files vf ON vf.id = m.video_file_id
        LEFT JOIN cue_change_notices n ON n.cue_id = s.cue_id
        """

    private let path: URL
    public let access: DatabaseConnectionAccess
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        self.path = path
        self.access = access
        database = try SQLiteDatabase(path: path, access: access)
    }

    public func upsertExcerpt(
        selection: SubtitleCueTextSelection,
        listID requestedListID: Int64? = nil,
        createdAt: Date = Date()
    ) throws -> Excerpt {
        guard let cueID = selection.cueLineID else {
            throw SQLiteDatabaseError.stepFailed("Excerpt requires a CueID")
        }
        return try upsertExcerpt(
            cueID: cueID,
            listID: requestedListID,
            createdAt: createdAt
        )
    }

    public func upsertExcerpt(
        cueID: Int64,
        listID requestedListID: Int64? = nil,
        createdAt: Date = Date()
    ) throws -> Excerpt {
        guard let listID = try requestedListID ?? firstExcerptListID() else {
            throw SQLiteDatabaseError.stepFailed("Excerpt requires a destination list")
        }

        let statement = try database.prepare(
            """
            INSERT INTO excerpts(list_id, cue_id, created_at)
            VALUES (?, ?, ?)
            ON CONFLICT(list_id, cue_id) DO NOTHING;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.bind(cueID, at: 2)
        try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 3)
        try statement.run()

        guard let savedExcerpt = try excerpt(cueID: cueID, listID: listID) else {
            throw SQLiteDatabaseError.stepFailed("Inserted Excerpt could not be loaded")
        }
        return savedExcerpt
    }

    public func excerpt(
        cueID: Int64,
        listID requestedListID: Int64? = nil
    ) throws -> Excerpt? {
        guard let listID = try requestedListID ?? firstExcerptListID() else {
            return nil
        }
        let statement = try database.prepare(
            """
            \(Self.resolvedExcerptSelectSQL)
            WHERE s.list_id = ? AND s.cue_id = ?;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.bind(cueID, at: 2)
        return try statement.step() ? excerpt(from: statement) : nil
    }

    public func excerpt(id: Int64) throws -> Excerpt? {
        let statement = try database.prepare(
            """
            \(Self.resolvedExcerptSelectSQL)
            WHERE s.id = ?;
            """
        )
        try statement.bind(id, at: 1)
        return try statement.step() ? excerpt(from: statement) : nil
    }

    @discardableResult
    public func removeExcerpt(id: Int64) throws -> Bool {
        guard let relation = try excerptRelation(id: id) else {
            return false
        }
        return try database.withImmediateTransaction {
            let statement = try database.prepare("DELETE FROM excerpts WHERE id = ?;")
            try statement.bind(id, at: 1)
            try statement.run()
            try deleteUnreferencedTombstone(cueID: relation.cueID)
            return true
        }
    }

    @discardableResult
    public func moveExcerpt(
        id: Int64,
        toListID destinationListID: Int64
    ) throws -> ExcerptRelation {
        try transferExcerpt(
            id: id,
            toListID: destinationListID,
            removesSource: true
        )
    }

    @discardableResult
    public func duplicateExcerpt(
        id: Int64,
        toListID destinationListID: Int64
    ) throws -> ExcerptRelation {
        try transferExcerpt(
            id: id,
            toListID: destinationListID,
            removesSource: false
        )
    }

    public func excerptLists() throws -> [ExcerptList] {
        let statement = try database.prepare(
            """
            SELECT id, name, description, cover_path, created_at,
                   recent_cue_id, recent_sort_order, recent_played_at
            FROM excerpt_lists
            ORDER BY created_at ASC, id ASC;
            """
        )
        var lists: [ExcerptList] = []
        while try statement.step() {
            lists.append(excerptList(from: statement))
        }
        return lists
    }

    public func excerptList(id: Int64) throws -> ExcerptList? {
        let statement = try database.prepare(
            """
            SELECT id, name, description, cover_path, created_at,
                   recent_cue_id, recent_sort_order, recent_played_at
            FROM excerpt_lists
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)
        return try statement.step() ? excerptList(from: statement) : nil
    }

    public func firstExcerptListID() throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT id
            FROM excerpt_lists
            ORDER BY created_at ASC, id ASC
            LIMIT 1;
            """
        )
        return try statement.step() ? statement.int64Column(0) : nil
    }

    public func excerptListOverview() throws -> ExcerptListOverview {
        let statement = try database.prepare(
            """
            SELECT l.id, l.name, l.description, l.cover_path, l.created_at,
                   l.recent_cue_id, l.recent_sort_order, l.recent_played_at,
                   COUNT(s.id)
            FROM excerpt_lists l
            LEFT JOIN excerpts s ON s.list_id = l.id
            GROUP BY l.id
            ORDER BY l.created_at ASC, l.id ASC;
            """
        )
        var lists: [ExcerptListSummary] = []
        while try statement.step() {
            lists.append(ExcerptListSummary(
                list: excerptList(from: statement),
                cueCount: statement.intColumn(8)
            ))
        }

        return ExcerptListOverview(
            lists: lists,
            uniqueCueCount: try uniqueExcerptCueCount()
        )
    }

    public func recordRecentExcerptPlayback(
        excerptID: Int64,
        playedAt: Date = Date()
    ) throws {
        guard let relation = try excerptRelation(id: excerptID) else {
            return
        }
        let statement = try database.prepare(
            """
            UPDATE excerpt_lists
            SET recent_cue_id = ?,
                recent_sort_order = 'created_at_desc',
                recent_played_at = ?
            WHERE id = ?;
            """
        )
        try statement.bind(relation.cueID, at: 1)
        try statement.bind(ISO8601DateFormatter().string(from: playedAt), at: 2)
        try statement.bind(relation.listID, at: 3)
        try statement.run()
    }

    public func recentExcerptListSummaries() throws -> [ExcerptListSummary] {
        let statement = try database.prepare(
            """
            SELECT id, name, description, cover_path, created_at,
                   recent_cue_id, recent_sort_order, recent_played_at
            FROM excerpt_lists
            WHERE recent_played_at IS NOT NULL
            ORDER BY recent_played_at DESC, id DESC;
            """
        )
        var recentLists: [ExcerptList] = []
        while try statement.step() {
            recentLists.append(excerptList(from: statement))
        }

        var summaries: [ExcerptListSummary] = []
        for list in recentLists {
            let relations = try excerptRelations(listID: list.id)
            let resolvedByID = Dictionary(
                uniqueKeysWithValues: try excerpts(listID: list.id).map { ($0.id, $0) }
            )
            let playable = relations.compactMap { relation -> Excerpt? in
                guard let excerpt = resolvedByID[relation.id], excerpt.isValid else {
                    return nil
                }
                return excerpt
            }
            guard !playable.isEmpty else {
                if access == .readWrite {
                    try? clearRecentExcerptPlayback(listID: list.id)
                }
                continue
            }

            let anchoredID = relations.first { relation in
                relation.cueID == list.recentCueID
                    && resolvedByID[relation.id]?.isValid == true
            }?.id
            let position = anchoredID.flatMap { id in
                playable.firstIndex { $0.id == id }
            } ?? 0
            summaries.append(ExcerptListSummary(
                list: list,
                cueCount: playable.count,
                resumeExcerpt: playable[position],
                resumePosition: position + 1
            ))
        }
        return summaries
    }

    public func uniqueExcerptCueCount() throws -> Int {
        let statement = try database.prepare(
            "SELECT COUNT(DISTINCT cue_id) FROM excerpts;"
        )
        return try statement.step() ? statement.intColumn(0) : 0
    }

    public func validateExcerptList(
        name rawName: String,
        description: String,
        excludingListID: Int64? = nil
    ) throws -> ExcerptListValidation {
        let name = Self.trimmedListName(rawName)
        let nameError: ExcerptListValidationError?
        if name.isEmpty {
            nameError = .emptyName
        } else if name.count > Self.maximumListNameCharacters {
            nameError = .nameTooLong(
                maximumCharacters: Self.maximumListNameCharacters,
                currentCharacters: name.count
            )
        } else if try excerptListNameExists(
            normalizedName: Self.normalizedListName(name),
            excludingListID: excludingListID
        ) {
            nameError = .duplicateName
        } else {
            nameError = nil
        }

        let descriptionError: ExcerptListValidationError? =
            description.count > Self.maximumListDescriptionCharacters
                ? .descriptionTooLong(
                    maximumCharacters: Self.maximumListDescriptionCharacters,
                    currentCharacters: description.count
                )
                : nil
        return ExcerptListValidation(
            nameError: nameError,
            descriptionError: descriptionError
        )
    }

    @discardableResult
    public func createExcerptList(
        name rawName: String,
        description: String = "",
        coverPath: String? = nil,
        createdAt: Date = Date()
    ) throws -> ExcerptList {
        try database.withImmediateTransaction {
            let validation = try validateExcerptList(
                name: rawName,
                description: description
            )
            try Self.throwFirstValidationError(in: validation)

            let name = Self.trimmedListName(rawName)
            let statement = try database.prepare(
                """
                INSERT INTO excerpt_lists(
                    name,
                    normalized_name,
                    description,
                    cover_path,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?);
                """
            )
            try statement.bind(name, at: 1)
            try statement.bind(Self.normalizedListName(name), at: 2)
            try statement.bind(description, at: 3)
            try bind(coverPath, to: statement, at: 4)
            try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 5)
            try statement.run()

            guard let list = try excerptList(id: database.lastInsertRowID()) else {
                throw SQLiteDatabaseError.stepFailed("Created Excerpt list could not be loaded")
            }
            return list
        }
    }

    @discardableResult
    public func updateExcerptList(
        id: Int64,
        name rawName: String,
        description: String,
        coverPath: String?
    ) throws -> ExcerptList {
        try database.withImmediateTransaction {
            guard try excerptList(id: id) != nil else {
                throw ExcerptListMutationError.listNotFound
            }
            let validation = try validateExcerptList(
                name: rawName,
                description: description,
                excludingListID: id
            )
            try Self.throwFirstValidationError(in: validation)

            let name = Self.trimmedListName(rawName)
            let statement = try database.prepare(
                """
                UPDATE excerpt_lists
                SET name = ?, normalized_name = ?, description = ?, cover_path = ?
                WHERE id = ?;
                """
            )
            try statement.bind(name, at: 1)
            try statement.bind(Self.normalizedListName(name), at: 2)
            try statement.bind(description, at: 3)
            try bind(coverPath, to: statement, at: 4)
            try statement.bind(id, at: 5)
            try statement.run()

            guard let list = try excerptList(id: id) else {
                throw SQLiteDatabaseError.stepFailed("Updated Excerpt list could not be loaded")
            }
            return list
        }
    }

    @discardableResult
    public func deleteExcerptList(id: Int64) throws -> ExcerptList {
        try database.withImmediateTransaction {
            guard let list = try excerptList(id: id) else {
                throw ExcerptListMutationError.listNotFound
            }
            let countStatement = try database.prepare("SELECT COUNT(*) FROM excerpt_lists;")
            let listCount = try countStatement.step() ? countStatement.intColumn(0) : 0
            guard listCount > 1 else {
                throw ExcerptListMutationError.cannotDeleteOnlyList
            }

            let cueStatement = try database.prepare(
                "SELECT DISTINCT cue_id FROM excerpts WHERE list_id = ?;"
            )
            try cueStatement.bind(id, at: 1)
            var cueIDs: [Int64] = []
            while try cueStatement.step() {
                cueIDs.append(cueStatement.int64Column(0))
            }

            let statement = try database.prepare("DELETE FROM excerpt_lists WHERE id = ?;")
            try statement.bind(id, at: 1)
            try statement.run()
            for cueID in cueIDs {
                try deleteUnreferencedTombstone(cueID: cueID)
            }
            return list
        }
    }

    public func excerptRelations(
        listID requestedListID: Int64? = nil
    ) throws -> [ExcerptRelation] {
        guard let listID = try requestedListID ?? firstExcerptListID() else {
            return []
        }
        let statement = try database.prepare(
            """
            SELECT id, list_id, cue_id, created_at
            FROM excerpts
            WHERE list_id = ?
            ORDER BY created_at ASC, id ASC;
            """
        )
        try statement.bind(listID, at: 1)
        var relations: [ExcerptRelation] = []
        while try statement.step() {
            relations.append(excerptRelation(from: statement))
        }
        return relations
    }

    public func excerptResidentSnapshot(
        listID: Int64? = nil
    ) throws -> ExcerptResidentSnapshot {
        let relations = try excerptRelations(listID: listID)
        let resolvedExcerpts = try excerpts(listID: listID)
        let availableExcerptIDs = Set(
            resolvedExcerpts.lazy.filter(\.isValid).map(\.id)
        )
        let cueContents = try CueContentDatabase(path: path).cueContents(
            forCueIDs: relations.compactMap { relation in
                availableExcerptIDs.contains(relation.id)
                    ? relation.cueID
                    : nil
            }
        )
        let watchStatesByExcerptID = try relations.first.map {
            try excerptWatchStatesByID(listID: $0.listID)
        } ?? [:]
        return ExcerptResidentSnapshot(
            relations: relations,
            resolvedExcerpts: resolvedExcerpts,
            cueContents: cueContents,
            facetSnapshot: excerptFacetSnapshot(
                relations: relations,
                resolvedExcerpts: resolvedExcerpts,
                cueContents: cueContents,
                watchStatesByExcerptID: watchStatesByExcerptID
            )
        )
    }

    private func excerptFacetSnapshot(
        relations: [ExcerptRelation],
        resolvedExcerpts: [Excerpt],
        cueContents: [CueContent],
        watchStatesByExcerptID: [Int64: LibraryWatchState]
    ) -> CueFacetSnapshot {
        let resolvedExcerptsByID = Dictionary(
            uniqueKeysWithValues: resolvedExcerpts.map { ($0.id, $0) }
        )
        let cueContentsByID = Dictionary(
            uniqueKeysWithValues: cueContents.map { ($0.cueID, $0) }
        )
        var cueIDs: [Int64] = []
        var durationFacets: [CueDurationFacet] = []
        var characterFacets: [CueCharacterFacet] = []
        var languageFacets: [Set<SubtitleLanguageCode>] = []
        var watchStateFacets: [LibraryWatchState] = []
        var folderFacets: [String] = []
        cueIDs.reserveCapacity(relations.count)
        durationFacets.reserveCapacity(relations.count)
        characterFacets.reserveCapacity(relations.count)
        languageFacets.reserveCapacity(relations.count)
        watchStateFacets.reserveCapacity(relations.count)
        folderFacets.reserveCapacity(relations.count)

        for relation in relations {
            guard let excerpt = resolvedExcerptsByID[relation.id] else {
                continue
            }
            let content = cueContentsByID[relation.cueID]
            cueIDs.append(relation.cueID)
            durationFacets.append(CueDurationFacet(
                durationMilliseconds: max(
                    0,
                    (content?.endMilliseconds ?? excerpt.endMilliseconds)
                        - (content?.startMilliseconds ?? excerpt.startMilliseconds)
                )
            ))
            characterFacets.append(CueCharacterFacet(
                characterCount: (content?.content ?? excerpt.content)
                    .unicodeScalars.count
            ))
            languageFacets.append(content?.languages ?? [.unknown])
            watchStateFacets.append(
                watchStatesByExcerptID[relation.id] ?? .unwatched
            )
            // The same folder the search order rows give the cue.
            folderFacets.append(
                URL(fileURLWithPath: content?.subtitlePath ?? excerpt.subtitlePath)
                    .deletingLastPathComponent()
                    .standardizedFileURL
                    .path
            )
        }

        return CueFacetSnapshot(
            cueIDs: cueIDs,
            durationFacets: durationFacets,
            characterFacets: characterFacets,
            languageFacets: languageFacets,
            watchStateFacets: watchStateFacets,
            folderFacets: folderFacets
        )
    }

    private func excerptWatchStatesByID(
        listID: Int64
    ) throws -> [Int64: LibraryWatchState] {
        let statement = try database.prepare(
            """
            SELECT s.id, COALESCE(ws.state, '\(LibraryWatchState.unwatched.rawValue)')
            FROM excerpts s
            LEFT JOIN subtitle_cue_lines l ON l.id = s.cue_id
            LEFT JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            LEFT JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf ON vf.id = m.video_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = vf.id
            WHERE s.list_id = ?;
            """
        )
        try statement.bind(listID, at: 1)
        var states: [Int64: LibraryWatchState] = [:]
        while try statement.step() {
            states[statement.int64Column(0)] = LibraryWatchState(
                rawValue: statement.stringColumn(1)
            ) ?? .unwatched
        }
        return states
    }

    public func excerptRelation(id: Int64) throws -> ExcerptRelation? {
        let statement = try database.prepare(
            """
            SELECT id, list_id, cue_id, created_at
            FROM excerpts
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)
        return try statement.step() ? excerptRelation(from: statement) : nil
    }

    public func cueID(forExcerptID excerptID: Int64) throws -> Int64? {
        let statement = try database.prepare("SELECT cue_id FROM excerpts WHERE id = ?;")
        try statement.bind(excerptID, at: 1)
        return try statement.step() ? statement.nullableInt64Column(0) : nil
    }

    /// The Excerpts among `excerptIDs` that are valid now: the same test the
    /// resolved Excerpt's `isValid` makes, a cue that is indexed and not in the
    /// tombstone, on a subtitle matched to a video.
    public func validExcerptIDs(among excerptIDs: [Int64]) throws -> Set<Int64> {
        let uniqueExcerptIDs = Array(Set(excerptIDs))
        var validExcerptIDs = Set<Int64>()
        for start in stride(from: 0, to: uniqueExcerptIDs.count, by: 500) {
            let batch = uniqueExcerptIDs[start..<min(start + 500, uniqueExcerptIDs.count)]
            let placeholders = batch.map { _ in "?" }.joined(separator: ", ")
            let statement = try database.prepare(
                """
                SELECT s.id
                FROM excerpts s
                JOIN subtitle_cue_lines l ON l.id = s.cue_id
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                JOIN video_files vf ON vf.id = m.video_file_id
                WHERE s.id IN (\(placeholders));
                """
            )
            for (offset, id) in batch.enumerated() {
                try statement.bind(id, at: Int32(offset + 1))
            }
            while try statement.step() {
                validExcerptIDs.insert(statement.int64Column(0))
            }
        }
        return validExcerptIDs
    }

    public func excerpt(
        subtitleFile: URL,
        startMilliseconds: Int,
        endMilliseconds: Int,
        listID requestedListID: Int64? = nil
    ) throws -> Excerpt? {
        guard let listID = try requestedListID ?? firstExcerptListID() else {
            return nil
        }
        let statement = try database.prepare(
            """
            \(Self.resolvedExcerptSelectSQL)
            WHERE s.list_id = ?
              AND sf.subtitle_path = ?
              AND l.start_ms = ?
              AND l.end_ms = ?
            ORDER BY l.display_order DESC, l.event_index DESC, s.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.bind(subtitleFile.path, at: 2)
        try statement.bind(max(0, startMilliseconds), at: 3)
        try statement.bind(max(startMilliseconds, endMilliseconds), at: 4)
        return try statement.step() ? excerpt(from: statement) : nil
    }

    public func adjacentExcerpt(
        to item: Excerpt,
        direction: ExcerptNavigationDirection
    ) throws -> Excerpt? {
        guard let relation = try excerptRelation(id: item.id) else {
            return nil
        }
        let orderingPredicate: String
        let orderingClause: String
        switch direction {
        case .previous:
            orderingPredicate = "(s.created_at < ? OR (s.created_at = ? AND s.id < ?))"
            orderingClause = "ORDER BY s.created_at DESC, s.id DESC"
        case .next:
            orderingPredicate = "(s.created_at > ? OR (s.created_at = ? AND s.id > ?))"
            orderingClause = "ORDER BY s.created_at ASC, s.id ASC"
        }

        let statement = try database.prepare(
            """
            \(Self.resolvedExcerptSelectSQL)
            WHERE s.list_id = ?
              AND \(orderingPredicate)
              AND l.id IS NOT NULL
            \(orderingClause)
            LIMIT 1;
            """
        )
        try statement.bind(relation.listID, at: 1)
        try statement.bind(item.createdAt, at: 2)
        try statement.bind(item.createdAt, at: 3)
        try statement.bind(item.id, at: 4)
        return try statement.step() ? excerpt(from: statement) : nil
    }

    public func excerpts(listID requestedListID: Int64? = nil) throws -> [Excerpt] {
        guard let listID = try requestedListID ?? firstExcerptListID() else {
            return []
        }
        let statement = try database.prepare(
            """
            \(Self.resolvedExcerptSelectSQL)
            WHERE s.list_id = ?
            ORDER BY sf.subtitle_path ASC, l.start_ms ASC, l.end_ms ASC, s.id ASC;
            """
        )
        try statement.bind(listID, at: 1)
        var excerpts: [Excerpt] = []
        while try statement.step() {
            excerpts.append(excerpt(from: statement))
        }
        return excerpts
    }

    public func excerptCount(listID requestedListID: Int64? = nil) throws -> Int {
        guard let listID = try requestedListID ?? firstExcerptListID() else {
            return 0
        }
        let statement = try database.prepare(
            "SELECT COUNT(*) FROM excerpts WHERE list_id = ?;"
        )
        try statement.bind(listID, at: 1)
        return try statement.step() ? statement.intColumn(0) : 0
    }

    private func transferExcerpt(
        id: Int64,
        toListID destinationListID: Int64,
        removesSource: Bool
    ) throws -> ExcerptRelation {
        try database.withImmediateTransaction {
            guard let source = try excerptRelation(id: id) else {
                throw ExcerptTransferError.sourceUnavailable
            }
            guard try excerpt(id: id)?.isValid == true else {
                throw ExcerptTransferError.sourceUnavailable
            }
            guard try excerptList(id: destinationListID) != nil else {
                throw ExcerptTransferError.destinationUnavailable
            }
            guard try !excerptRelationExists(
                cueID: source.cueID,
                listID: destinationListID
            ) else {
                throw ExcerptTransferError.destinationAlreadyContainsCue(
                    listID: destinationListID
                )
            }

            let insert = try database.prepare(
                """
                INSERT INTO excerpts(list_id, cue_id, created_at)
                VALUES (?, ?, ?);
                """
            )
            try insert.bind(destinationListID, at: 1)
            try insert.bind(source.cueID, at: 2)
            try insert.bind(source.createdAt, at: 3)
            try insert.run()
            let destinationExcerptID = database.lastInsertRowID()

            if removesSource {
                let delete = try database.prepare("DELETE FROM excerpts WHERE id = ?;")
                try delete.bind(source.id, at: 1)
                try delete.run()
            }

            guard let destination = try excerptRelation(id: destinationExcerptID) else {
                throw SQLiteDatabaseError.stepFailed(
                    "Transferred Excerpt relation could not be loaded"
                )
            }
            return destination
        }
    }

    public func excerptRelationExists(cueID: Int64, listID: Int64) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM excerpts
            WHERE list_id = ? AND cue_id = ?
            LIMIT 1;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.bind(cueID, at: 2)
        return try statement.step()
    }

    private func excerpt(from statement: SQLiteStatement) -> Excerpt {
        let unavailableReason = statement.nullableStringColumn(11)
            .flatMap(ExcerptUnavailableReason.init(rawValue:))
        let previousContent = statement.nullableStringColumn(13)
        let currentContent = statement.nullableStringColumn(14)
        let contentChange: ExcerptCueContentChange? = if let previousContent, let currentContent {
            ExcerptCueContentChange(
                previousContent: previousContent,
                currentContent: currentContent
            )
        } else {
            nil
        }
        return Excerpt(
            id: statement.int64Column(0),
            subtitleFileID: statement.nullableInt64Column(16),
            subtitlePath: statement.stringColumn(1),
            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
            videoPath: statement.stringColumn(3),
            videoName: statement.stringColumn(4),
            displayTitle: statement.stringColumn(15),
            timeRange: "",
            startMilliseconds: statement.intColumn(5),
            endMilliseconds: statement.intColumn(6),
            cueEventIndex: statement.nullableIntColumn(7),
            cueDisplayOrder: statement.nullableIntColumn(8),
            content: statement.stringColumn(9),
            cueGroupContent: statement.stringColumn(10),
            isValid: unavailableReason == nil,
            unavailableReason: unavailableReason,
            contentChange: contentChange,
            createdAt: statement.stringColumn(12)
        )
    }

    private func deleteUnreferencedTombstone(cueID: Int64) throws {
        let statement = try database.prepare(
            """
            DELETE FROM cue_tombstones
            WHERE cue_id = ?
              AND NOT EXISTS (
                SELECT 1 FROM excerpts WHERE cue_id = ?
              );
            """
        )
        try statement.bind(cueID, at: 1)
        try statement.bind(cueID, at: 2)
        try statement.run()
    }

    private func excerptRelation(from statement: SQLiteStatement) -> ExcerptRelation {
        ExcerptRelation(
            id: statement.int64Column(0),
            listID: statement.int64Column(1),
            cueID: statement.int64Column(2),
            createdAt: statement.stringColumn(3)
        )
    }

    private func excerptList(from statement: SQLiteStatement) -> ExcerptList {
        ExcerptList(
            id: statement.int64Column(0),
            name: statement.stringColumn(1),
            description: statement.stringColumn(2),
            coverPath: statement.nullableStringColumn(3),
            createdAt: statement.stringColumn(4),
            recentCueID: statement.nullableInt64Column(5),
            recentSortOrder: statement.nullableStringColumn(6),
            recentPlayedAt: statement.nullableStringColumn(7)
        )
    }

    private func clearRecentExcerptPlayback(listID: Int64) throws {
        let statement = try database.prepare(
            """
            UPDATE excerpt_lists
            SET recent_cue_id = NULL,
                recent_sort_order = NULL,
                recent_played_at = NULL
            WHERE id = ?;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.run()
    }

    private func excerptListNameExists(
        normalizedName: String,
        excludingListID: Int64?
    ) throws -> Bool {
        let statement: SQLiteStatement
        if let excludingListID {
            statement = try database.prepare(
                """
                SELECT 1
                FROM excerpt_lists
                WHERE normalized_name = ? AND id != ?
                LIMIT 1;
                """
            )
            try statement.bind(normalizedName, at: 1)
            try statement.bind(excludingListID, at: 2)
        } else {
            statement = try database.prepare(
                """
                SELECT 1
                FROM excerpt_lists
                WHERE normalized_name = ?
                LIMIT 1;
                """
            )
            try statement.bind(normalizedName, at: 1)
        }
        return try statement.step()
    }

    private func bind(
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

    private static func trimmedListName(_ rawName: String) -> String {
        rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedListName(_ name: String) -> String {
        name
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private static func throwFirstValidationError(
        in validation: ExcerptListValidation
    ) throws {
        if let nameError = validation.nameError {
            throw nameError
        }
        if let descriptionError = validation.descriptionError {
            throw descriptionError
        }
    }

}
