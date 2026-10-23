import Foundation

extension IndexingDatabase {
    @discardableResult
    public func addSearchPath(_ folder: URL, type: String = "local") throws -> Int64 {
        try database.withImmediateTransaction {
            try bindSearchPathInCurrentTransaction(folder, type: type)
        }
    }

    /// Binds a Library to its absolute path. The path is the only identity.
    func bindSearchPathInCurrentTransaction(
        _ folder: URL,
        type: String = "local",
        reuseCoveringLibrary: Bool = false
    ) throws -> Int64 {
        let effectiveType: String
        if folder.isWebDAVURL {
            effectiveType = "webdav"
        } else if folder.isSMBURL {
            effectiveType = "smb"
        } else if folder.isFTPURL {
            effectiveType = "ftp"
        } else if folder.isNFSURL {
            effectiveType = "nfs"
        } else {
            effectiveType = type
        }
        let standardizedFolder = folder.standardizedMediaURL
        let folderMediaPath = standardizedFolder.mediaPath
        let now = ISO8601DateFormatter().string(from: Date())
        try insertRootFolderMetadataIfNeeded(
            path: folderMediaPath,
            createdAt: now,
            updatedAt: now
        )

        if reuseCoveringLibrary,
           let covering = try libraryPathRecords()
               .filter({ LibraryRootGroups.holds($0.rootURL, standardizedFolder) })
               .min(by: { $0.rootURL.mediaPath.count < $1.rootURL.mediaPath.count }),
           covering.rootURL.mediaPath != folderMediaPath
        {
            if let matchingPath = try searchPathRecord(path: covering.rootURL.mediaPath) {
                try touchSearchPath(matchingPath, type: effectiveType, updatedAt: now)
            }
            try backfillMediaPathIdentities(libraryID: covering.id, rootURL: covering.rootURL)
            return covering.id
        }

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
    func separateNestedLibrary(_ root: URL) throws -> Set<String> {
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

    func upsertLibraryFolder(for folder: URL, libraryID: Int64) throws -> Int64? {
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

        let now = ISO8601DateFormatter().string(from: Date())
        if let matchingPath = try libraryFolderRecord(
            libraryID: libraryID,
            relativePath: relativePath
        ) {
            let backfillTimestamps = try database.prepare(
                """
                UPDATE library_folders
                SET created_at = CASE WHEN created_at = '' THEN ? ELSE created_at END,
                    updated_at = CASE WHEN updated_at = '' THEN ? ELSE updated_at END
                WHERE id = ? AND (created_at = '' OR updated_at = '');
                """
            )
            try backfillTimestamps.bind(now, at: 1)
            try backfillTimestamps.bind(now, at: 2)
            try backfillTimestamps.bind(matchingPath.id, at: 3)
            try backfillTimestamps.run()
            try adoptFolderOwnedPaths(folderID: matchingPath.id)
            try updateFolderOwnedPaths(
                folderID: matchingPath.id,
                path: folderMediaPath
            )
            return matchingPath.id
        }

        let statement = try database.prepare(
            """
            INSERT INTO library_folders(library_id, relative_path, created_at, updated_at)
            VALUES (?, ?, ?, ?)
            RETURNING id;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.bind(relativePath, at: 2)
        try statement.bind(now, at: 3)
        try statement.bind(now, at: 4)
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

    func mediaPathIdentity(
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

    static func relativeMediaPath(for file: URL, under root: URL) -> String? {
        guard file.isWebDAVURL == root.isWebDAVURL,
              file.isSMBURL == root.isSMBURL,
              file.isFTPURL == root.isFTPURL,
              file.isNFSURL == root.isNFSURL else {
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

    func searchPaths() throws -> [String] {
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

    public func recordCoveredRootFolderAddition(
        _ folder: URL,
        coveredBy coveringRoot: URL
    ) throws {
        try database.withImmediateTransaction {
            let folderPath = folder.standardizedMediaURL.mediaPath
            let coveringVariants = Self.folderPathVariants(for: coveringRoot.standardizedMediaURL)
            let now = ISO8601DateFormatter().string(from: Date())
            var coveringUpdatedAt: String?

            if !coveringVariants.isEmpty {
                let placeholders = coveringVariants.map { _ in "?" }.joined(separator: ", ")
                let rootSelect = try database.prepare(
                    """
                    SELECT updated_at
                    FROM library_root_folders
                    WHERE path IN (\(placeholders)) AND updated_at != ''
                    LIMIT 1;
                    """
                )
                for (offset, variant) in coveringVariants.enumerated() {
                    try rootSelect.bind(variant, at: Int32(offset + 1))
                }
                if try rootSelect.step() {
                    coveringUpdatedAt = rootSelect.stringColumn(0)
                }

                if coveringUpdatedAt == nil {
                    let spSelect = try database.prepare(
                        """
                        SELECT COALESCE(NULLIF(last_successful_index_at, ''), NULLIF(updated_at, ''), created_at)
                        FROM search_paths
                        WHERE path IN (\(placeholders))
                        LIMIT 1;
                        """
                    )
                    for (offset, variant) in coveringVariants.enumerated() {
                        try spSelect.bind(variant, at: Int32(offset + 1))
                    }
                    if try spSelect.step() {
                        let candidate = spSelect.stringColumn(0)
                        if !candidate.isEmpty {
                            coveringUpdatedAt = candidate
                        }
                    }
                }
            }

            let resolvedUpdatedAt = coveringUpdatedAt ?? now
            let upsert = try database.prepare(
                """
                INSERT INTO library_root_folders(path, created_at, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(path) DO UPDATE SET
                    created_at = excluded.created_at,
                    updated_at = excluded.updated_at;
                """
            )
            try upsert.bind(folderPath, at: 1)
            try upsert.bind(now, at: 2)
            try upsert.bind(resolvedUpdatedAt, at: 3)
            try upsert.run()
        }
    }

    public func removeRootFolderMetadata(_ folder: URL) throws {
        try database.withImmediateTransaction {
            try deleteRootFolderMetadataInCurrentTransaction(folder)
        }
    }

    func insertRootFolderMetadataIfNeeded(
        path: String,
        createdAt: String,
        updatedAt: String
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO library_root_folders(path, created_at, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(path) DO NOTHING;
            """
        )
        try statement.bind(path, at: 1)
        try statement.bind(createdAt, at: 2)
        try statement.bind(updatedAt, at: 3)
        try statement.run()
    }

    func deleteRootFolderMetadataInCurrentTransaction(_ folder: URL) throws {
        let delete = try database.prepare(
            "DELETE FROM library_root_folders WHERE path = ?;"
        )
        for variant in Self.folderPathVariants(for: folder.standardizedMediaURL) {
            try delete.bind(variant, at: 1)
            try delete.run()
            try delete.reset()
        }
    }

    /// Removing a Library deletes it. Re-adding the same path starts a new LibraryID.
    func deleteSearchPath(_ searchPath: String) throws {
        try deleteRootFolderMetadataInCurrentTransaction(URL.fromMediaPath(searchPath))
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
    func deleteEmptyLibraryFolders(libraryID: Int64) throws {
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

    static func path(_ path: String, isUnderAny folders: [URL]) -> Bool {
        let standardizedPath = URL.fromMediaPath(path).mediaPath
        return folders.contains { folder in
            folderPathPrefixes(for: folder).contains { prefix in
                standardizedPath.hasPrefix(prefix)
            }
        }
    }

    static func folderPath(_ path: String, matchesAny folders: [URL]) -> Bool {
        let standardizedPath = normalizedFolderPath(URL.fromMediaPath(path).mediaPath)
        return folders.contains { folder in
            folderPathVariants(for: folder).contains(standardizedPath)
        }
    }

    static func folderPathPrefixes(for folders: [URL]) -> [String] {
        MediaFolderPathMatching.folderPathPrefixes(for: folders)
    }

    static func folderPathPrefixes(for folder: URL) -> [String] {
        MediaFolderPathMatching.folderPathPrefixes(for: folder)
    }

    static func pathPrefixUpperBound(for prefix: String) -> String {
        MediaFolderPathMatching.pathPrefixUpperBound(for: prefix)
    }

    static func folderPath(forSubtitlePath subtitlePath: String) -> String {
        URL.fromMediaPath(subtitlePath)
            .deletingLastPathComponent()
            .mediaPath
    }

    static func subtitlePathPrefix(forFolderPath folderPath: String) -> String {
        folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
    }

    static func folderPathVariants(for folder: URL) -> [String] {
        MediaFolderPathMatching.folderPathVariants(for: folder)
    }

    static func normalizedFolderPath(_ path: String) -> String {
        MediaFolderPathMatching.normalizedFolderPath(path)
    }
}
