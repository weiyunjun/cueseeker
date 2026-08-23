import Foundation

public final class ShioriDatabase: @unchecked Sendable {
    public static let maximumListNameCharacters = 30
    public static let maximumListDescriptionCharacters = 100

    private static let resolvedShioriSelectSQL = """
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
        FROM shioris s
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
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        self.path = path
        database = try SQLiteDatabase(path: path, access: access)
    }

    public func upsertShiori(
        selection: SubtitleCueTextSelection,
        listID requestedListID: Int64? = nil,
        createdAt: Date = Date()
    ) throws -> Shiori {
        guard let cueID = selection.cueLineID else {
            throw SQLiteDatabaseError.stepFailed("Shiori requires a CueID")
        }
        guard let listID = try requestedListID ?? firstShioriListID() else {
            throw SQLiteDatabaseError.stepFailed("Shiori requires a destination list")
        }

        let statement = try database.prepare(
            """
            INSERT INTO shioris(list_id, cue_id, created_at)
            VALUES (?, ?, ?)
            ON CONFLICT(list_id, cue_id) DO NOTHING;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.bind(cueID, at: 2)
        try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 3)
        try statement.run()

        guard let savedShiori = try shiori(cueID: cueID, listID: listID) else {
            throw SQLiteDatabaseError.stepFailed("Inserted Shiori could not be loaded")
        }
        return savedShiori
    }

    public func shiori(
        cueID: Int64,
        listID requestedListID: Int64? = nil
    ) throws -> Shiori? {
        guard let listID = try requestedListID ?? firstShioriListID() else {
            return nil
        }
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.list_id = ? AND s.cue_id = ?;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.bind(cueID, at: 2)
        return try statement.step() ? shiori(from: statement) : nil
    }

    public func shiori(id: Int64) throws -> Shiori? {
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.id = ?;
            """
        )
        try statement.bind(id, at: 1)
        return try statement.step() ? shiori(from: statement) : nil
    }

    @discardableResult
    public func removeShiori(id: Int64) throws -> Bool {
        guard let relation = try shioriRelation(id: id) else {
            return false
        }
        return try database.withImmediateTransaction {
            let statement = try database.prepare("DELETE FROM shioris WHERE id = ?;")
            try statement.bind(id, at: 1)
            try statement.run()
            try deleteUnreferencedTombstone(cueID: relation.cueID)
            return true
        }
    }

    @discardableResult
    public func moveShiori(
        id: Int64,
        toListID destinationListID: Int64
    ) throws -> ShioriRelation {
        try transferShiori(
            id: id,
            toListID: destinationListID,
            removesSource: true
        )
    }

    @discardableResult
    public func duplicateShiori(
        id: Int64,
        toListID destinationListID: Int64
    ) throws -> ShioriRelation {
        try transferShiori(
            id: id,
            toListID: destinationListID,
            removesSource: false
        )
    }

    public func shioriLists() throws -> [ShioriList] {
        let statement = try database.prepare(
            """
            SELECT id, name, description, cover_path, created_at,
                   recent_cue_id, recent_sort_order, recent_played_at
            FROM shiori_lists
            ORDER BY created_at DESC, id DESC;
            """
        )
        var lists: [ShioriList] = []
        while try statement.step() {
            lists.append(shioriList(from: statement))
        }
        return lists
    }

    public func shioriList(id: Int64) throws -> ShioriList? {
        let statement = try database.prepare(
            """
            SELECT id, name, description, cover_path, created_at,
                   recent_cue_id, recent_sort_order, recent_played_at
            FROM shiori_lists
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)
        return try statement.step() ? shioriList(from: statement) : nil
    }

    public func firstShioriListID() throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT id
            FROM shiori_lists
            ORDER BY created_at DESC, id DESC
            LIMIT 1;
            """
        )
        return try statement.step() ? statement.int64Column(0) : nil
    }

    public func shioriListOverview() throws -> ShioriListOverview {
        let statement = try database.prepare(
            """
            SELECT l.id, l.name, l.description, l.cover_path, l.created_at,
                   l.recent_cue_id, l.recent_sort_order, l.recent_played_at,
                   COUNT(s.id)
            FROM shiori_lists l
            LEFT JOIN shioris s ON s.list_id = l.id
            GROUP BY l.id
            ORDER BY l.created_at DESC, l.id DESC;
            """
        )
        var lists: [ShioriListSummary] = []
        while try statement.step() {
            lists.append(ShioriListSummary(
                list: shioriList(from: statement),
                cueCount: statement.intColumn(8)
            ))
        }

        return ShioriListOverview(
            lists: lists,
            uniqueCueCount: try uniqueShioriCueCount()
        )
    }

    public func recordRecentShioriPlayback(
        shioriID: Int64,
        playedAt: Date = Date()
    ) throws {
        guard let relation = try shioriRelation(id: shioriID) else {
            return
        }
        let statement = try database.prepare(
            """
            UPDATE shiori_lists
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

    public func recentShioriListSummaries() throws -> [ShioriListSummary] {
        let statement = try database.prepare(
            """
            SELECT id, name, description, cover_path, created_at,
                   recent_cue_id, recent_sort_order, recent_played_at
            FROM shiori_lists
            WHERE recent_played_at IS NOT NULL
            ORDER BY recent_played_at DESC, id DESC;
            """
        )
        var recentLists: [ShioriList] = []
        while try statement.step() {
            recentLists.append(shioriList(from: statement))
        }

        var summaries: [ShioriListSummary] = []
        for list in recentLists {
            let relations = try shioriRelations(listID: list.id)
            let resolvedByID = Dictionary(
                uniqueKeysWithValues: try shioris(listID: list.id).map { ($0.id, $0) }
            )
            let playable = relations.compactMap { relation -> Shiori? in
                guard let shiori = resolvedByID[relation.id], shiori.isValid else {
                    return nil
                }
                return shiori
            }
            guard !playable.isEmpty else {
                try clearRecentShioriPlayback(listID: list.id)
                continue
            }

            let anchoredID = relations.first { relation in
                relation.cueID == list.recentCueID
                    && resolvedByID[relation.id]?.isValid == true
            }?.id
            let position = anchoredID.flatMap { id in
                playable.firstIndex { $0.id == id }
            } ?? 0
            summaries.append(ShioriListSummary(
                list: list,
                cueCount: playable.count,
                resumeShiori: playable[position],
                resumePosition: position + 1
            ))
        }
        return summaries
    }

    public func uniqueShioriCueCount() throws -> Int {
        let statement = try database.prepare(
            "SELECT COUNT(DISTINCT cue_id) FROM shioris;"
        )
        return try statement.step() ? statement.intColumn(0) : 0
    }

    public func validateShioriList(
        name rawName: String,
        description: String,
        excludingListID: Int64? = nil
    ) throws -> ShioriListValidation {
        let name = Self.trimmedListName(rawName)
        let nameError: ShioriListValidationError?
        if name.isEmpty {
            nameError = .emptyName
        } else if name.count > Self.maximumListNameCharacters {
            nameError = .nameTooLong(
                maximumCharacters: Self.maximumListNameCharacters,
                currentCharacters: name.count
            )
        } else if try shioriListNameExists(
            normalizedName: Self.normalizedListName(name),
            excludingListID: excludingListID
        ) {
            nameError = .duplicateName
        } else {
            nameError = nil
        }

        let descriptionError: ShioriListValidationError? =
            description.count > Self.maximumListDescriptionCharacters
                ? .descriptionTooLong(
                    maximumCharacters: Self.maximumListDescriptionCharacters,
                    currentCharacters: description.count
                )
                : nil
        return ShioriListValidation(
            nameError: nameError,
            descriptionError: descriptionError
        )
    }

    @discardableResult
    public func createShioriList(
        name rawName: String,
        description: String = "",
        coverPath: String? = nil,
        createdAt: Date = Date()
    ) throws -> ShioriList {
        try database.withImmediateTransaction {
            let validation = try validateShioriList(
                name: rawName,
                description: description
            )
            try Self.throwFirstValidationError(in: validation)

            let name = Self.trimmedListName(rawName)
            let statement = try database.prepare(
                """
                INSERT INTO shiori_lists(
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

            guard let list = try shioriList(id: database.lastInsertRowID()) else {
                throw SQLiteDatabaseError.stepFailed("Created Shiori list could not be loaded")
            }
            return list
        }
    }

    @discardableResult
    public func updateShioriList(
        id: Int64,
        name rawName: String,
        description: String,
        coverPath: String?
    ) throws -> ShioriList {
        try database.withImmediateTransaction {
            guard try shioriList(id: id) != nil else {
                throw ShioriListMutationError.listNotFound
            }
            let validation = try validateShioriList(
                name: rawName,
                description: description,
                excludingListID: id
            )
            try Self.throwFirstValidationError(in: validation)

            let name = Self.trimmedListName(rawName)
            let statement = try database.prepare(
                """
                UPDATE shiori_lists
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

            guard let list = try shioriList(id: id) else {
                throw SQLiteDatabaseError.stepFailed("Updated Shiori list could not be loaded")
            }
            return list
        }
    }

    @discardableResult
    public func deleteShioriList(id: Int64) throws -> ShioriList {
        try database.withImmediateTransaction {
            guard let list = try shioriList(id: id) else {
                throw ShioriListMutationError.listNotFound
            }
            let countStatement = try database.prepare("SELECT COUNT(*) FROM shiori_lists;")
            let listCount = try countStatement.step() ? countStatement.intColumn(0) : 0
            guard listCount > 1 else {
                throw ShioriListMutationError.cannotDeleteOnlyList
            }

            let cueStatement = try database.prepare(
                "SELECT DISTINCT cue_id FROM shioris WHERE list_id = ?;"
            )
            try cueStatement.bind(id, at: 1)
            var cueIDs: [Int64] = []
            while try cueStatement.step() {
                cueIDs.append(cueStatement.int64Column(0))
            }

            let statement = try database.prepare("DELETE FROM shiori_lists WHERE id = ?;")
            try statement.bind(id, at: 1)
            try statement.run()
            for cueID in cueIDs {
                try deleteUnreferencedTombstone(cueID: cueID)
            }
            return list
        }
    }

    public func shioriRelations(
        listID requestedListID: Int64? = nil
    ) throws -> [ShioriRelation] {
        guard let listID = try requestedListID ?? firstShioriListID() else {
            return []
        }
        let statement = try database.prepare(
            """
            SELECT id, list_id, cue_id, created_at
            FROM shioris
            WHERE list_id = ?
            ORDER BY created_at DESC, id DESC;
            """
        )
        try statement.bind(listID, at: 1)
        var relations: [ShioriRelation] = []
        while try statement.step() {
            relations.append(shioriRelation(from: statement))
        }
        return relations
    }

    public func shioriResidentSnapshot(
        listID: Int64? = nil
    ) throws -> ShioriResidentSnapshot {
        let relations = try shioriRelations(listID: listID)
        let resolvedShioris = try shioris(listID: listID)
        let availableShioriIDs = Set(
            resolvedShioris.lazy.filter(\.isValid).map(\.id)
        )
        let cueContents = try CueContentDatabase(path: path).cueContents(
            forCueIDs: relations.compactMap { relation in
                availableShioriIDs.contains(relation.id)
                    ? relation.cueID
                    : nil
            }
        )
        let watchStatesByShioriID = try relations.first.map {
            try shioriWatchStatesByID(listID: $0.listID)
        } ?? [:]
        return ShioriResidentSnapshot(
            relations: relations,
            resolvedShioris: resolvedShioris,
            cueContents: cueContents,
            facetSnapshot: shioriFacetSnapshot(
                relations: relations,
                resolvedShioris: resolvedShioris,
                cueContents: cueContents,
                watchStatesByShioriID: watchStatesByShioriID
            )
        )
    }

    private func shioriFacetSnapshot(
        relations: [ShioriRelation],
        resolvedShioris: [Shiori],
        cueContents: [CueContent],
        watchStatesByShioriID: [Int64: LibraryWatchState]
    ) -> CueFacetSnapshot {
        let resolvedShiorisByID = Dictionary(
            uniqueKeysWithValues: resolvedShioris.map { ($0.id, $0) }
        )
        let cueContentsByID = Dictionary(
            uniqueKeysWithValues: cueContents.map { ($0.cueID, $0) }
        )
        var cueIDs: [Int64] = []
        var durationFacets: [CueDurationFacet] = []
        var characterFacets: [CueCharacterFacet] = []
        var languageFacets: [Set<SubtitleLanguageCode>] = []
        var watchStateFacets: [LibraryWatchState] = []
        cueIDs.reserveCapacity(relations.count)
        durationFacets.reserveCapacity(relations.count)
        characterFacets.reserveCapacity(relations.count)
        languageFacets.reserveCapacity(relations.count)
        watchStateFacets.reserveCapacity(relations.count)

        for relation in relations {
            guard let shiori = resolvedShiorisByID[relation.id] else {
                continue
            }
            let content = cueContentsByID[relation.cueID]
            cueIDs.append(relation.cueID)
            durationFacets.append(CueDurationFacet(
                durationMilliseconds: max(
                    0,
                    (content?.endMilliseconds ?? shiori.endMilliseconds)
                        - (content?.startMilliseconds ?? shiori.startMilliseconds)
                )
            ))
            characterFacets.append(CueCharacterFacet(
                characterCount: (content?.content ?? shiori.content)
                    .unicodeScalars.count
            ))
            languageFacets.append(content?.languages ?? [.unknown])
            watchStateFacets.append(
                watchStatesByShioriID[relation.id] ?? .unwatched
            )
        }

        return CueFacetSnapshot(
            cueIDs: cueIDs,
            durationFacets: durationFacets,
            characterFacets: characterFacets,
            languageFacets: languageFacets,
            watchStateFacets: watchStateFacets
        )
    }

    private func shioriWatchStatesByID(
        listID: Int64
    ) throws -> [Int64: LibraryWatchState] {
        let statement = try database.prepare(
            """
            SELECT s.id, COALESCE(ws.state, '\(LibraryWatchState.unwatched.rawValue)')
            FROM shioris s
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

    public func shioriRelation(id: Int64) throws -> ShioriRelation? {
        let statement = try database.prepare(
            """
            SELECT id, list_id, cue_id, created_at
            FROM shioris
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)
        return try statement.step() ? shioriRelation(from: statement) : nil
    }

    public func cueID(forShioriID shioriID: Int64) throws -> Int64? {
        let statement = try database.prepare("SELECT cue_id FROM shioris WHERE id = ?;")
        try statement.bind(shioriID, at: 1)
        return try statement.step() ? statement.nullableInt64Column(0) : nil
    }

    public func shiori(
        subtitleFile: URL,
        startMilliseconds: Int,
        endMilliseconds: Int,
        listID requestedListID: Int64? = nil
    ) throws -> Shiori? {
        guard let listID = try requestedListID ?? firstShioriListID() else {
            return nil
        }
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
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
        return try statement.step() ? shiori(from: statement) : nil
    }

    public func adjacentShiori(
        to item: Shiori,
        direction: ShioriNavigationDirection
    ) throws -> Shiori? {
        guard let relation = try shioriRelation(id: item.id) else {
            return nil
        }
        let orderingPredicate: String
        let orderingClause: String
        switch direction {
        case .previous:
            orderingPredicate = "(s.created_at > ? OR (s.created_at = ? AND s.id > ?))"
            orderingClause = "ORDER BY s.created_at ASC, s.id ASC"
        case .next:
            orderingPredicate = "(s.created_at < ? OR (s.created_at = ? AND s.id < ?))"
            orderingClause = "ORDER BY s.created_at DESC, s.id DESC"
        }

        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
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
        return try statement.step() ? shiori(from: statement) : nil
    }

    public func shioris(listID requestedListID: Int64? = nil) throws -> [Shiori] {
        guard let listID = try requestedListID ?? firstShioriListID() else {
            return []
        }
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.list_id = ?
            ORDER BY sf.subtitle_path ASC, l.start_ms ASC, l.end_ms ASC, s.id ASC;
            """
        )
        try statement.bind(listID, at: 1)
        var shioris: [Shiori] = []
        while try statement.step() {
            shioris.append(shiori(from: statement))
        }
        return shioris
    }

    public func shioriCount(listID requestedListID: Int64? = nil) throws -> Int {
        guard let listID = try requestedListID ?? firstShioriListID() else {
            return 0
        }
        let statement = try database.prepare(
            "SELECT COUNT(*) FROM shioris WHERE list_id = ?;"
        )
        try statement.bind(listID, at: 1)
        return try statement.step() ? statement.intColumn(0) : 0
    }

    private func transferShiori(
        id: Int64,
        toListID destinationListID: Int64,
        removesSource: Bool
    ) throws -> ShioriRelation {
        try database.withImmediateTransaction {
            guard let source = try shioriRelation(id: id) else {
                throw ShioriTransferError.sourceUnavailable
            }
            guard try shiori(id: id)?.isValid == true else {
                throw ShioriTransferError.sourceUnavailable
            }
            guard try shioriList(id: destinationListID) != nil else {
                throw ShioriTransferError.destinationUnavailable
            }
            guard try !shioriRelationExists(
                cueID: source.cueID,
                listID: destinationListID
            ) else {
                throw ShioriTransferError.destinationAlreadyContainsCue(
                    listID: destinationListID
                )
            }

            let insert = try database.prepare(
                """
                INSERT INTO shioris(list_id, cue_id, created_at)
                VALUES (?, ?, ?);
                """
            )
            try insert.bind(destinationListID, at: 1)
            try insert.bind(source.cueID, at: 2)
            try insert.bind(source.createdAt, at: 3)
            try insert.run()
            let destinationShioriID = database.lastInsertRowID()

            if removesSource {
                let delete = try database.prepare("DELETE FROM shioris WHERE id = ?;")
                try delete.bind(source.id, at: 1)
                try delete.run()
            }

            guard let destination = try shioriRelation(id: destinationShioriID) else {
                throw SQLiteDatabaseError.stepFailed(
                    "Transferred Shiori relation could not be loaded"
                )
            }
            return destination
        }
    }

    private func shioriRelationExists(cueID: Int64, listID: Int64) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM shioris
            WHERE list_id = ? AND cue_id = ?
            LIMIT 1;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.bind(cueID, at: 2)
        return try statement.step()
    }

    private func shiori(from statement: SQLiteStatement) -> Shiori {
        let unavailableReason = statement.nullableStringColumn(11)
            .flatMap(ShioriUnavailableReason.init(rawValue:))
        let previousContent = statement.nullableStringColumn(13)
        let currentContent = statement.nullableStringColumn(14)
        let contentChange: ShioriCueContentChange? = if let previousContent, let currentContent {
            ShioriCueContentChange(
                previousContent: previousContent,
                currentContent: currentContent
            )
        } else {
            nil
        }
        return Shiori(
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
                SELECT 1 FROM shioris WHERE cue_id = ?
              );
            """
        )
        try statement.bind(cueID, at: 1)
        try statement.bind(cueID, at: 2)
        try statement.run()
    }

    private func shioriRelation(from statement: SQLiteStatement) -> ShioriRelation {
        ShioriRelation(
            id: statement.int64Column(0),
            listID: statement.int64Column(1),
            cueID: statement.int64Column(2),
            createdAt: statement.stringColumn(3)
        )
    }

    private func shioriList(from statement: SQLiteStatement) -> ShioriList {
        ShioriList(
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

    private func clearRecentShioriPlayback(listID: Int64) throws {
        let statement = try database.prepare(
            """
            UPDATE shiori_lists
            SET recent_cue_id = NULL,
                recent_sort_order = NULL,
                recent_played_at = NULL
            WHERE id = ?;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.run()
    }

    private func shioriListNameExists(
        normalizedName: String,
        excludingListID: Int64?
    ) throws -> Bool {
        let statement: SQLiteStatement
        if let excludingListID {
            statement = try database.prepare(
                """
                SELECT 1
                FROM shiori_lists
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
                FROM shiori_lists
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
        in validation: ShioriListValidation
    ) throws {
        if let nameError = validation.nameError {
            throw nameError
        }
        if let descriptionError = validation.descriptionError {
            throw descriptionError
        }
    }

}
