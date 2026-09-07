import Foundation

/// A file as the rename conflict check compares it with the disk.
struct RenameFileRecord: Equatable, Sendable {
    let id: Int64
    let path: String
    let fileSize: Int64?
    let modifiedAt: Double?
}

struct RenamePair: Equatable, Sendable {
    let subtitlePath: String
    let videoPath: String
}

/// The database side of an in-App rename: what the conflict check reads, and
/// the one transaction that moves every stored path to its new value.
///
/// Every path lookup accepts both forms a stored path can take, the way the
/// folder-scoped queries elsewhere in this class do.
extension IndexingDatabase {
    // MARK: - Reads for the conflict check

    func renameFileRecords(
        underFolderPath folderPath: String
    ) throws -> (subtitles: [RenameFileRecord], videos: [RenameFileRecord]) {
        (
            try renameFileRecords(
                sql: "SELECT id, subtitle_path, file_size, modified_at FROM subtitle_files",
                pathColumn: "subtitle_path",
                atOrUnderPath: folderPath,
                includingExact: false
            ),
            try renameFileRecords(
                sql: "SELECT id, path, file_size, modified_at FROM video_files",
                pathColumn: "path",
                atOrUnderPath: folderPath,
                includingExact: false
            )
        )
    }

    private func renameFileRecords(
        sql: String,
        pathColumn: String,
        atOrUnderPath path: String,
        includingExact: Bool
    ) throws -> [RenameFileRecord] {
        let scope = Self.renamePathScope(column: pathColumn, path: path, includingExact: includingExact)
        let statement = try database.prepare(
            "\(sql) WHERE \(scope.condition) ORDER BY id ASC;"
        )
        try scope.bind(to: statement)
        var records: [RenameFileRecord] = []
        while try statement.step() {
            records.append(Self.renameFileRecord(from: statement))
        }
        return records
    }

    /// The video at `videoPath` and the subtitles paired with it.
    func renameFileGroup(
        videoPath: String
    ) throws -> (video: RenameFileRecord, subtitles: [RenameFileRecord])? {
        let variants = Self.folderPathVariants(for: URL(fileURLWithPath: videoPath))
        let placeholders = variants.map { _ in "?" }.joined(separator: ", ")
        let videoStatement = try database.prepare(
            "SELECT id, path, file_size, modified_at FROM video_files WHERE path IN (\(placeholders)) LIMIT 1;"
        )
        for (offset, variant) in variants.enumerated() {
            try videoStatement.bind(variant, at: Int32(offset + 1))
        }
        guard try videoStatement.step() else {
            return nil
        }
        let video = Self.renameFileRecord(from: videoStatement)

        let subtitleStatement = try database.prepare(
            """
            SELECT sf.id, sf.subtitle_path, sf.file_size, sf.modified_at
            FROM subtitle_video_matches m
            JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
            WHERE m.video_file_id = ? AND m.is_active = 1
            ORDER BY sf.subtitle_path ASC;
            """
        )
        try subtitleStatement.bind(video.id, at: 1)
        var subtitles: [RenameFileRecord] = []
        while try subtitleStatement.step() {
            subtitles.append(Self.renameFileRecord(from: subtitleStatement))
        }
        return (video, subtitles)
    }

    /// Every active pairing whose subtitle sits anywhere under `folderPath`.
    func activeRenamePairs(underFolderPath folderPath: String) throws -> [RenamePair] {
        let scope = Self.renamePathScope(
            column: "sf.subtitle_path",
            path: folderPath,
            includingExact: false
        )
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, vf.path
            FROM subtitle_files sf
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE \(scope.condition)
            ORDER BY sf.subtitle_path ASC;
            """
        )
        try scope.bind(to: statement)
        var pairs: [RenamePair] = []
        while try statement.step() {
            pairs.append(
                RenamePair(
                    subtitlePath: statement.stringColumn(0),
                    videoPath: statement.stringColumn(1)
                )
            )
        }
        return pairs
    }

    /// Every active pairing whose subtitle sits directly in `directoryPath`.
    func activeRenamePairs(inDirectory directoryPath: String) throws -> [RenamePair] {
        let directory = LibraryRenamer.canonicalPath(directoryPath)
        return try activeRenamePairs(underFolderPath: directoryPath).filter {
            LibraryRenamer.canonicalPath(($0.subtitlePath as NSString).deletingLastPathComponent) == directory
        }
    }

    /// Whether any library, folder, video or subtitle is stored at `path` or
    /// under it. A rename must not land where the database already has rows,
    /// or the paths that are unique keys would collide.
    func hasRenameRows(atOrUnderPath path: String) throws -> Bool {
        for (table, column) in [
            ("search_paths", "path"),
            ("subtitle_files", "subtitle_path"),
            ("video_files", "path"),
        ] {
            let scope = Self.renamePathScope(column: column, path: path, includingExact: true)
            let statement = try database.prepare(
                "SELECT 1 FROM \(table) WHERE \(scope.condition) LIMIT 1;"
            )
            try scope.bind(to: statement)
            if try statement.step() {
                return true
            }
        }
        let folderScope = Self.renamePathScope(
            column: "rtrim(sp.path || '/' || lf.relative_path, '/')",
            path: path,
            includingExact: true
        )
        let folders = try database.prepare(
            """
            SELECT 1
            FROM library_folders lf
            JOIN search_paths sp ON sp.id = lf.library_id
            WHERE \(folderScope.condition)
            LIMIT 1;
            """
        )
        try folderScope.bind(to: folders)
        return try folders.step()
    }

    /// A WHERE clause matching `column` at `path` (optionally) or under it, in
    /// either form the path can take.
    private struct RenamePathScope {
        let condition: String
        let values: [String]

        func bind(to statement: SQLiteStatement) throws {
            for (offset, value) in values.enumerated() {
                try statement.bind(value, at: Int32(offset + 1))
            }
        }
    }

    private static func renamePathScope(
        column: String,
        path: String,
        includingExact: Bool
    ) -> RenamePathScope {
        var conditions: [String] = []
        var values: [String] = []
        for variant in folderPathVariants(for: URL(fileURLWithPath: path)) {
            let prefix = subtitlePathPrefix(forFolderPath: variant)
            if includingExact {
                conditions.append("\(column) = ?")
                values.append(variant)
            }
            conditions.append("(\(column) >= ? AND \(column) < ?)")
            values.append(prefix)
            values.append(pathPrefixUpperBound(for: prefix))
        }
        return RenamePathScope(
            condition: "(" + conditions.joined(separator: " OR ") + ")",
            values: values
        )
    }

    private static func renameFileRecord(from statement: SQLiteStatement) -> RenameFileRecord {
        RenameFileRecord(
            id: statement.int64Column(0),
            path: statement.stringColumn(1),
            fileSize: statement.nullableInt64Column(2),
            modifiedAt: statement.nullableDoubleColumn(3)
        )
    }

    // MARK: - The update

    /// Moves every stored path the plan touches, then rebuilds the derived
    /// Search order and Library rows of the affected folders — inside one
    /// transaction, so a failure leaves the database as it was.
    func applyRename(_ plan: LibraryRenamePlan) throws {
        try database.withImmediateTransaction {
            let rewrite = { (path: String) -> String? in
                for step in plan.steps {
                    if let moved = LibraryRenamer.rewrite(path, from: step.oldPath, to: step.newPath) {
                        return moved
                    }
                }
                return nil
            }

            // Roots as they were, so folders can be placed before anything moves.
            let libraries = try libraryPathRecords()
            var rootPaths: [Int64: String] = [:]
            for library in libraries {
                rootPaths[library.id] = library.rootURL.path
            }

            var folderUpdates: [(id: Int64, libraryID: Int64, newPath: String)] = []
            let folders = try database.prepare(
                "SELECT id, library_id, relative_path FROM library_folders ORDER BY id ASC;"
            )
            while try folders.step() {
                let libraryID = folders.int64Column(1)
                guard let rootPath = rootPaths[libraryID] else {
                    continue
                }
                let relativePath = folders.stringColumn(2)
                let oldPath = relativePath.isEmpty ? rootPath : rootPath + "/" + relativePath
                if let newPath = rewrite(oldPath) {
                    folderUpdates.append((folders.int64Column(0), libraryID, newPath))
                }
            }

            let updateLibrary = try database.prepare(
                "UPDATE search_paths SET path = ? WHERE id = ?;"
            )
            for library in libraries {
                guard let newPath = rewrite(library.rootURL.path) else {
                    continue
                }
                try updateLibrary.bind(newPath, at: 1)
                try updateLibrary.bind(library.id, at: 2)
                try updateLibrary.run()
                try updateLibrary.reset()
                rootPaths[library.id] = newPath
            }

            let updateFolder = try database.prepare(
                "UPDATE library_folders SET relative_path = ? WHERE id = ?;"
            )
            for update in folderUpdates {
                let relativePath = rootPaths[update.libraryID].flatMap {
                    Self.renameRelativePath(of: update.newPath, under: $0)
                } ?? ""
                try updateFolder.bind(relativePath, at: 1)
                try updateFolder.bind(update.id, at: 2)
                try updateFolder.run()
                try updateFolder.reset()
                try updateFolderOwnedPaths(folderID: update.id, path: update.newPath)
            }

            try rewriteFiles(
                select: "SELECT id, library_id, subtitle_path FROM subtitle_files",
                pathColumn: "subtitle_path",
                steps: plan.steps,
                rewrite: rewrite,
                rootPaths: rootPaths
            ) { id, newPath, relativePath in
                let file = try database.prepare(
                    "UPDATE subtitle_files SET subtitle_path = ?, relative_path = ? WHERE id = ?;"
                )
                try file.bind(newPath, at: 1)
                try bindOptional(relativePath, to: file, at: 2)
                try file.bind(id, at: 3)
                try file.run()
                for table in ["subtitle_cue_groups", "subtitle_playback_finish_metadata"] {
                    let derived = try database.prepare(
                        "UPDATE \(table) SET subtitle_path = ? WHERE subtitle_file_id = ?;"
                    )
                    try derived.bind(newPath, at: 1)
                    try derived.bind(id, at: 2)
                    try derived.run()
                }
            }

            try rewriteFiles(
                select: "SELECT id, library_id, path FROM video_files",
                pathColumn: "path",
                steps: plan.steps,
                rewrite: rewrite,
                rootPaths: rootPaths
            ) { id, newPath, relativePath in
                let file = try database.prepare(
                    "UPDATE video_files SET path = ?, relative_path = ?, video_name = ? WHERE id = ?;"
                )
                try file.bind(newPath, at: 1)
                try bindOptional(relativePath, to: file, at: 2)
                try file.bind((newPath as NSString).lastPathComponent, at: 3)
                try file.bind(id, at: 4)
                try file.run()
            }

            let affectedFolderPaths = Set(plan.affectedFolderPaths)
            try refreshSearchOrderRows(affectedFolderPaths: affectedFolderPaths)
            try LibraryDatabase(sharing: database)
                .rebuildPresentationRowsInCurrentTransaction(folderPaths: affectedFolderPaths)
        }
    }

    /// The path relative to its root, in the form `relative_path` stores;
    /// nil when the path is not under the root.
    private static func renameRelativePath(of path: String, under rootPath: String) -> String? {
        let canonicalRoot = LibraryRenamer.canonicalPath(rootPath)
        let canonicalPath = LibraryRenamer.canonicalPath(path)
        let prefix = canonicalRoot == "/" ? "/" : canonicalRoot + "/"
        guard canonicalPath.hasPrefix(prefix) else {
            return nil
        }
        let relativePath = String(canonicalPath.dropFirst(prefix.count))
            .precomposedStringWithCanonicalMapping
        return relativePath.isEmpty ? nil : relativePath
    }

    private func rewriteFiles(
        select: String,
        pathColumn: String,
        steps: [LibraryRenameStep],
        rewrite: (String) -> String?,
        rootPaths: [Int64: String],
        update: (_ id: Int64, _ newPath: String, _ relativePath: String?) throws -> Void
    ) throws {
        var updates: [(id: Int64, libraryID: Int64?, newPath: String)] = []
        var seen = Set<Int64>()
        for step in steps {
            let scope = Self.renamePathScope(column: pathColumn, path: step.oldPath, includingExact: true)
            let statement = try database.prepare(
                "\(select) WHERE \(scope.condition) ORDER BY id ASC;"
            )
            try scope.bind(to: statement)
            while try statement.step() {
                let id = statement.int64Column(0)
                guard seen.insert(id).inserted,
                      let newPath = rewrite(statement.stringColumn(2))
                else {
                    continue
                }
                updates.append((id, statement.nullableInt64Column(1), newPath))
            }
        }
        for entry in updates {
            let relativePath = entry.libraryID.flatMap { rootPaths[$0] }.flatMap {
                Self.renameRelativePath(of: entry.newPath, under: $0)
            }
            try update(entry.id, entry.newPath, relativePath)
        }
    }

    private func bindOptional(_ value: String?, to statement: SQLiteStatement, at index: Int32) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }
}
