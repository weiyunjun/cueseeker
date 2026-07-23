import Foundation

public final class ShioriDatabase: @unchecked Sendable {
    public static let maximumListNameCharacters = 30
    public static let maximumListDescriptionCharacters = 100

    private static let resolvedShioriSelectSQL = """
        SELECT s.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
               l.start_ms, l.end_ms, l.event_index, l.display_order,
               l.content, 1, s.created_at
        FROM shioris s
        JOIN subtitle_cue_lines l ON l.id = s.cue_id
        JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
        JOIN subtitle_video_matches m
          ON m.subtitle_file_id = sf.id AND m.is_active = 1
        JOIN video_files vf ON vf.id = m.video_file_id
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
        createdAt: Date = Date()
    ) throws -> Shiori {
        guard let cueID = selection.cueLineID else {
            throw SQLiteDatabaseError.stepFailed("Shiori requires a CueID")
        }

        let statement = try database.prepare(
            """
            INSERT INTO shioris(list_id, cue_id, created_at)
            VALUES (?, ?, ?)
            ON CONFLICT(list_id, cue_id) DO NOTHING;
            """
        )
        try statement.bind(ShioriListIdentity.defaultListID, at: 1)
        try statement.bind(cueID, at: 2)
        try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 3)
        try statement.run()

        guard let savedShiori = try shiori(cueID: cueID) else {
            throw SQLiteDatabaseError.stepFailed("Inserted Shiori could not be loaded")
        }
        return savedShiori
    }

    public func shiori(
        cueID: Int64,
        listID: Int64 = ShioriListIdentity.defaultListID
    ) throws -> Shiori? {
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
        guard try shiori(id: id) != nil else {
            return false
        }
        let statement = try database.prepare("DELETE FROM shioris WHERE id = ?;")
        try statement.bind(id, at: 1)
        try statement.run()
        return true
    }

    public func shioriLists() throws -> [ShioriList] {
        let statement = try database.prepare(
            """
            SELECT id, name, description, cover_path, created_at
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
            SELECT id, name, description, cover_path, created_at
            FROM shiori_lists
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)
        return try statement.step() ? shioriList(from: statement) : nil
    }

    public func shioriListOverview() throws -> ShioriListOverview {
        let statement = try database.prepare(
            """
            SELECT l.id, l.name, l.description, l.cover_path, l.created_at,
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
                cueCount: statement.intColumn(5)
            ))
        }

        let countStatement = try database.prepare(
            "SELECT COUNT(DISTINCT cue_id) FROM shioris;"
        )
        let uniqueCueCount = try countStatement.step() ? countStatement.intColumn(0) : 0
        return ShioriListOverview(lists: lists, uniqueCueCount: uniqueCueCount)
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

            let statement = try database.prepare("DELETE FROM shiori_lists WHERE id = ?;")
            try statement.bind(id, at: 1)
            try statement.run()
            return list
        }
    }

    public func shioriRelations(
        listID: Int64 = ShioriListIdentity.defaultListID
    ) throws -> [ShioriRelation] {
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
        listID: Int64 = ShioriListIdentity.defaultListID
    ) throws -> ShioriResidentSnapshot {
        let relations = try shioriRelations(listID: listID)
        let cueContents = try CueContentDatabase(path: path).cueContents(
            forCueIDs: relations.map(\.cueID)
        )
        guard cueContents.map(\.cueID) == relations.map(\.cueID) else {
            throw SQLiteDatabaseError.stepFailed(
                "Every Shiori relation must resolve its current Cue content"
            )
        }
        return ShioriResidentSnapshot(
            relations: relations,
            cueContents: cueContents,
            tagsByShioriID: try shioriTagsByShioriID(forShioriIDs: relations.map(\.id))
        )
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
        endMilliseconds: Int
    ) throws -> Shiori? {
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
        try statement.bind(ShioriListIdentity.defaultListID, at: 1)
        try statement.bind(subtitleFile.path, at: 2)
        try statement.bind(max(0, startMilliseconds), at: 3)
        try statement.bind(max(startMilliseconds, endMilliseconds), at: 4)
        return try statement.step() ? shiori(from: statement) : nil
    }

    public func adjacentShiori(
        to item: Shiori,
        direction: ShioriNavigationDirection
    ) throws -> Shiori? {
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
            WHERE s.list_id = ? AND \(orderingPredicate)
            \(orderingClause)
            LIMIT 1;
            """
        )
        try statement.bind(ShioriListIdentity.defaultListID, at: 1)
        try statement.bind(item.createdAt, at: 2)
        try statement.bind(item.createdAt, at: 3)
        try statement.bind(item.id, at: 4)
        return try statement.step() ? shiori(from: statement) : nil
    }

    public func shioris() throws -> [Shiori] {
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.list_id = ?
            ORDER BY sf.subtitle_path ASC, l.start_ms ASC, l.end_ms ASC, s.id ASC;
            """
        )
        try statement.bind(ShioriListIdentity.defaultListID, at: 1)
        var shioris: [Shiori] = []
        while try statement.step() {
            shioris.append(shiori(from: statement))
        }
        return shioris
    }

    public func shioriCount() throws -> Int {
        let statement = try database.prepare(
            "SELECT COUNT(*) FROM shioris WHERE list_id = ?;"
        )
        try statement.bind(ShioriListIdentity.defaultListID, at: 1)
        return try statement.step() ? statement.intColumn(0) : 0
    }

    public func shioriTags() throws -> [ShioriTag] {
        let statement = try database.prepare(
            """
            SELECT id, name, created_at
            FROM shiori_tags
            ORDER BY created_at ASC, id ASC;
            """
        )
        var tags: [ShioriTag] = []
        while try statement.step() {
            tags.append(shioriTag(from: statement))
        }
        return tags
    }

    public func shioriTag(id: Int64) throws -> ShioriTag? {
        let statement = try database.prepare(
            """
            SELECT id, name, created_at
            FROM shiori_tags
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)
        return try statement.step() ? shioriTag(from: statement) : nil
    }

    public func shioriTag(named rawName: String) throws -> ShioriTag? {
        try shioriTag(normalizedName: Self.validatedTagName(rawName))
    }

    @discardableResult
    public func createShioriTag(
        named rawName: String,
        createdAt: Date = Date()
    ) throws -> ShioriTag {
        let normalizedName = try Self.validatedTagName(rawName)
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO shiori_tags(name, normalized_name, created_at)
            VALUES (?, ?, ?);
            """
        )
        try statement.bind(normalizedName, at: 1)
        try statement.bind(normalizedName, at: 2)
        try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 3)
        try statement.run()

        guard let tag = try shioriTag(normalizedName: normalizedName) else {
            throw SQLiteDatabaseError.stepFailed("Shiori tag could not be saved")
        }
        return tag
    }

    public func shioriTags(forShioriID shioriID: Int64) throws -> [ShioriTag] {
        try shioriTagsByShioriID(forShioriIDs: [shioriID])[shioriID] ?? []
    }

    public func shioriTagsByShioriID(
        forShioriIDs shioriIDs: [Int64]
    ) throws -> [Int64: [ShioriTag]] {
        let uniqueIDs = Array(Set(shioriIDs)).sorted()
        guard !uniqueIDs.isEmpty else {
            return [:]
        }

        let placeholders = uniqueIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT a.shiori_id, t.id, t.name, t.created_at
            FROM shiori_tag_assignments a
            JOIN shiori_tags t ON t.id = a.tag_id
            WHERE a.shiori_id IN (\(placeholders))
            ORDER BY a.shiori_id ASC, a.created_at ASC, t.id ASC;
            """
        )
        for (offset, id) in uniqueIDs.enumerated() {
            try statement.bind(id, at: Int32(offset + 1))
        }

        var tagsByShioriID = Dictionary(uniqueKeysWithValues: uniqueIDs.map { ($0, [ShioriTag]()) })
        while try statement.step() {
            let shioriID = statement.int64Column(0)
            tagsByShioriID[shioriID, default: []].append(
                ShioriTag(
                    id: statement.int64Column(1),
                    name: statement.stringColumn(2),
                    createdAt: statement.stringColumn(3)
                )
            )
        }
        return tagsByShioriID
    }

    @discardableResult
    public func assignShioriTag(
        named rawName: String,
        toShioriID shioriID: Int64,
        createdAt: Date = Date()
    ) throws -> ShioriTag {
        guard try shioriExists(id: shioriID) else {
            throw SQLiteDatabaseError.stepFailed("Shiori tag assignment target does not exist")
        }
        let tag = try createShioriTag(named: rawName, createdAt: createdAt)
        try assignShioriTag(tagID: tag.id, toShioriID: shioriID, createdAt: createdAt)
        return tag
    }

    @discardableResult
    public func assignShioriTag(
        tagID: Int64,
        toShioriID shioriID: Int64,
        createdAt: Date = Date()
    ) throws -> Bool {
        guard try shioriExists(id: shioriID),
              try shioriTag(id: tagID) != nil,
              try !shioriTagAssignmentExists(tagID: tagID, shioriID: shioriID)
        else {
            return false
        }

        let statement = try database.prepare(
            """
            INSERT INTO shiori_tag_assignments(shiori_id, tag_id, created_at)
            VALUES (?, ?, ?);
            """
        )
        try statement.bind(shioriID, at: 1)
        try statement.bind(tagID, at: 2)
        try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 3)
        try statement.run()
        return true
    }

    @discardableResult
    public func removeShioriTagAssignment(
        tagID: Int64,
        fromShioriID shioriID: Int64
    ) throws -> Bool {
        guard try shioriTagAssignmentExists(tagID: tagID, shioriID: shioriID) else {
            return false
        }
        let statement = try database.prepare(
            """
            DELETE FROM shiori_tag_assignments
            WHERE shiori_id = ? AND tag_id = ?;
            """
        )
        try statement.bind(shioriID, at: 1)
        try statement.bind(tagID, at: 2)
        try statement.run()
        return true
    }

    public func deleteShioriTag(tagID: Int64) throws -> ShioriTagDeletionResult {
        guard try shioriTag(id: tagID) != nil else {
            return ShioriTagDeletionResult(
                tagID: tagID,
                didDelete: false,
                affectedShioriIDs: []
            )
        }
        let affectedIDs = try shioriIDsAssignedToTag(tagID: tagID)
        let statement = try database.prepare("DELETE FROM shiori_tags WHERE id = ?;")
        try statement.bind(tagID, at: 1)
        try statement.run()
        return ShioriTagDeletionResult(
            tagID: tagID,
            didDelete: true,
            affectedShioriIDs: affectedIDs
        )
    }

    private func shioriExists(id: Int64) throws -> Bool {
        let statement = try database.prepare("SELECT 1 FROM shioris WHERE id = ? LIMIT 1;")
        try statement.bind(id, at: 1)
        return try statement.step()
    }

    private func shioriTag(normalizedName: String) throws -> ShioriTag? {
        let statement = try database.prepare(
            """
            SELECT id, name, created_at
            FROM shiori_tags
            WHERE normalized_name = ?;
            """
        )
        try statement.bind(normalizedName, at: 1)
        return try statement.step() ? shioriTag(from: statement) : nil
    }

    private func shioriTagAssignmentExists(tagID: Int64, shioriID: Int64) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM shiori_tag_assignments
            WHERE shiori_id = ? AND tag_id = ?
            LIMIT 1;
            """
        )
        try statement.bind(shioriID, at: 1)
        try statement.bind(tagID, at: 2)
        return try statement.step()
    }

    private func shioriIDsAssignedToTag(tagID: Int64) throws -> [Int64] {
        let statement = try database.prepare(
            """
            SELECT shiori_id
            FROM shiori_tag_assignments
            WHERE tag_id = ?
            ORDER BY shiori_id ASC;
            """
        )
        try statement.bind(tagID, at: 1)
        var ids: [Int64] = []
        while try statement.step() {
            ids.append(statement.int64Column(0))
        }
        return ids
    }

    private func shioriTag(from statement: SQLiteStatement) -> ShioriTag {
        ShioriTag(
            id: statement.int64Column(0),
            name: statement.stringColumn(1),
            createdAt: statement.stringColumn(2)
        )
    }

    private func shiori(from statement: SQLiteStatement) -> Shiori {
        Shiori(
            id: statement.int64Column(0),
            subtitlePath: statement.stringColumn(1),
            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
            videoPath: statement.stringColumn(3),
            videoName: statement.stringColumn(4),
            timeRange: "",
            startMilliseconds: statement.intColumn(5),
            endMilliseconds: statement.intColumn(6),
            cueEventIndex: statement.nullableIntColumn(7),
            cueDisplayOrder: statement.nullableIntColumn(8),
            content: statement.stringColumn(9),
            isValid: statement.intColumn(10) != 0,
            createdAt: statement.stringColumn(11)
        )
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
            createdAt: statement.stringColumn(4)
        )
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

    private static func validatedTagName(_ rawName: String) throws -> String {
        guard !containsInvalidTagCharacter(rawName) else {
            throw ShioriTagValidationError.invalidCharacters
        }
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ShioriTagValidationError.emptyName
        }
        guard trimmedName.count <= 20 else {
            throw ShioriTagValidationError.nameTooLong(maximumCharacters: 20)
        }
        return trimmedName
    }

    private static func containsInvalidTagCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            switch scalar.properties.generalCategory {
            case .control, .format:
                true
            default:
                false
            }
        }
    }
}
