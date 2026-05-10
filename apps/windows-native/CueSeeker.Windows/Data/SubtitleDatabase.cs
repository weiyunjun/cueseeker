using CueSeeker.Windows.Core;
using Microsoft.Data.Sqlite;

namespace CueSeeker.Windows.Data;

internal sealed class SubtitleDatabase
{
    public const int CurrentSchemaVersion = 2;
    public const int ConfiguredBusyTimeoutMilliseconds = 5_000;

    private readonly string databasePath;

    public SubtitleDatabase(string databasePath)
    {
        this.databasePath = databasePath;
        Directory.CreateDirectory(Path.GetDirectoryName(databasePath)!);
    }

    public static string DefaultPath {
        get {
            string root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "CueSeeker",
                "Windows");
            return Path.Combine(root, "CueSeeker.sqlite3");
        }
    }

    public static double UnixSeconds(DateTimeOffset value)
    {
        return (value.ToUniversalTime() - DateTimeOffset.UnixEpoch).TotalSeconds;
    }

    public void Migrate()
    {
        using SqliteConnection connection = OpenConnection();
        int previousVersion = SchemaVersion(connection);
        EnsureSearchPathsTable(connection);
        if (previousVersion < CurrentSchemaVersion) {
            DropDerivedSubtitleIndexTables(connection);
        }

        Execute(connection,
            """
            CREATE TABLE IF NOT EXISTS subtitle_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_path TEXT NOT NULL UNIQUE,
                format TEXT NOT NULL,
                file_size INTEGER,
                modified_at REAL,
                indexed_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS video_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                path TEXT NOT NULL UNIQUE,
                video_name TEXT NOT NULL,
                file_size INTEGER,
                modified_at REAL,
                duration REAL,
                video_codec TEXT,
                audio_codec TEXT,
                native_video_candidate INTEGER,
                native_audio_candidate INTEGER,
                native_compatibility_reason TEXT,
                native_failure_reason TEXT,
                compatibility_evaluated_at TEXT
            );

            CREATE TABLE IF NOT EXISTS subtitle_video_matches (
                subtitle_file_id INTEGER NOT NULL,
                video_file_id INTEGER NOT NULL,
                match_method TEXT NOT NULL,
                confidence REAL NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                PRIMARY KEY(subtitle_file_id, video_file_id),
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_cue_groups (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_file_id INTEGER NOT NULL,
                subtitle_path TEXT NOT NULL,
                seq INTEGER,
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                search_content TEXT NOT NULL,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_cue_lines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cue_group_id INTEGER NOT NULL,
                event_index INTEGER NOT NULL,
                source_format TEXT NOT NULL,
                source_style TEXT,
                source_layer INTEGER,
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                content TEXT NOT NULL,
                display_x REAL,
                display_y REAL,
                display_order INTEGER NOT NULL,
                FOREIGN KEY(cue_group_id) REFERENCES subtitle_cue_groups(id) ON DELETE CASCADE
            );

            CREATE VIRTUAL TABLE IF NOT EXISTS subtitle_cue_groups_fts USING fts5(
                content,
                cue_group_id UNINDEXED
            );

            CREATE TABLE IF NOT EXISTS library_video_rows (
                video_path TEXT PRIMARY KEY NOT NULL,
                video_name TEXT NOT NULL,
                duration REAL,
                subtitle_path TEXT NOT NULL,
                subtitle_format TEXT NOT NULL,
                folder_path TEXT NOT NULL,
                folder_title TEXT NOT NULL,
                display_title TEXT NOT NULL,
                file_extension TEXT NOT NULL,
                folder_order INTEGER NOT NULL,
                video_order INTEGER NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS shioris (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_path TEXT NOT NULL,
                subtitle_format TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                video_path TEXT NOT NULL,
                video_name TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(subtitle_path, start_ms, end_ms)
            );

            CREATE INDEX IF NOT EXISTS idx_subtitle_files_subtitle_path
                ON subtitle_files(subtitle_path);
            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_groups_subtitle_path
                ON subtitle_cue_groups(subtitle_path);
            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_groups_start_ms
                ON subtitle_cue_groups(start_ms);
            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_lines_group_order
                ON subtitle_cue_lines(cue_group_id, display_order, event_index);
            CREATE INDEX IF NOT EXISTS idx_library_video_rows_folder_order
                ON library_video_rows(folder_order, video_order);
            """);

        if (previousVersion < CurrentSchemaVersion) {
            RebuildLibraryPresentationSnapshot(connection);
        }

        Execute(connection, $"PRAGMA user_version = {CurrentSchemaVersion};");
    }

    public IReadOnlyList<string> SearchPaths()
    {
        using SqliteConnection connection = OpenConnection();
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText = "SELECT path FROM search_paths ORDER BY path COLLATE NOCASE ASC;";
        using SqliteDataReader reader = command.ExecuteReader();
        List<string> paths = [];
        while (reader.Read()) {
            paths.Add(reader.GetString(0));
        }
        return paths;
    }

    public void AddSearchPath(string folder)
    {
        using SqliteConnection connection = OpenConnection();
        using SqliteCommand command = connection.CreateCommand();
        string now = DateTimeOffset.UtcNow.ToString("O");
        command.CommandText =
            """
            INSERT INTO search_paths(type, path, created_at, updated_at)
            VALUES ('local', $path, $created_at, $updated_at)
            ON CONFLICT(path) DO UPDATE SET
                type = excluded.type,
                updated_at = excluded.updated_at;
            """;
        command.Parameters.AddWithValue("$path", PathContract.NormalizePath(folder));
        command.Parameters.AddWithValue("$created_at", now);
        command.Parameters.AddWithValue("$updated_at", now);
        command.ExecuteNonQuery();
    }

    public void RemoveSearchPath(string folder)
    {
        RemoveIndexedData(folder, new HashSet<string>(StringComparer.OrdinalIgnoreCase), removeSearchPath: true);
        RebuildLibraryPresentationSnapshot();
    }

    public IReadOnlyList<SubtitleFileMetadata> SubtitleFiles()
    {
        using SqliteConnection connection = OpenConnection();
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT sf.subtitle_path, sf.format, sf.file_size, sf.modified_at, vf.path
            FROM subtitle_files sf
            LEFT JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf ON vf.id = m.video_file_id;
            """;

        using SqliteDataReader reader = command.ExecuteReader();
        List<SubtitleFileMetadata> files = [];
        while (reader.Read()) {
            files.Add(ReadSubtitleFileMetadata(reader));
        }

        return files;
    }

    public SubtitleFileMetadata? SubtitleFile(string subtitlePath)
    {
        using SqliteConnection connection = OpenConnection();
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT sf.subtitle_path, sf.format, sf.file_size, sf.modified_at, vf.path
            FROM subtitle_files sf
            LEFT JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf ON vf.id = m.video_file_id
            WHERE sf.subtitle_path = $subtitle_path;
            """;
        command.Parameters.AddWithValue("$subtitle_path", PathContract.NormalizePath(subtitlePath));
        using SqliteDataReader reader = command.ExecuteReader();
        return reader.Read() ? ReadSubtitleFileMetadata(reader) : null;
    }

    public void ReplaceCueGroups(
        string subtitlePath,
        string videoPath,
        SubtitleFormat format,
        IReadOnlyList<SubtitleCueGroup> cueGroups,
        long? fileSize,
        DateTimeOffset? modifiedAt)
    {
        string normalizedSubtitlePath = PathContract.NormalizePath(subtitlePath);
        string normalizedVideoPath = PathContract.NormalizePath(videoPath);
        using SqliteConnection connection = OpenConnection();
        BeginImmediateTransaction(connection);
        try {
            DeleteIndexedSubtitlePath(connection, normalizedSubtitlePath);

            long subtitleFileId = UpsertSubtitleFile(connection, normalizedSubtitlePath, format, fileSize, modifiedAt);
            long videoFileId = UpsertVideoFile(connection, normalizedVideoPath);
            UpsertSubtitleVideoMatch(connection, subtitleFileId, videoFileId);

            foreach (SubtitleCueGroup group in cueGroups) {
                long groupId = InsertCueGroup(connection, subtitleFileId, normalizedSubtitlePath, group);
                foreach (SubtitleCueLine line in group.CueLines) {
                    InsertCueLine(connection, groupId, line);
                }
                InsertFtsRow(connection, groupId, group.SearchContent);
            }

            DeleteOrphanedVideoFiles(connection);
            Execute(connection, "COMMIT;");
        } catch {
            TryRollback(connection);
            throw;
        }
    }

    public void RemoveStaleEntries(string folder, ISet<string> keptSubtitlePaths)
    {
        RemoveIndexedData(folder, keptSubtitlePaths, removeSearchPath: false);
    }

    public IReadOnlyList<LibraryFolderPresentation> LibraryPresentation()
    {
        HashSet<string> folders = SearchPaths().ToHashSet(StringComparer.OrdinalIgnoreCase);
        using SqliteConnection connection = OpenConnection();
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT folder_path, folder_title, video_path, video_name, duration,
                   subtitle_path, subtitle_format, display_title, file_extension
            FROM library_video_rows
            ORDER BY folder_order ASC, video_order ASC, video_path ASC;
            """;
        using SqliteDataReader reader = command.ExecuteReader();
        List<LibraryFolderPresentation> groups = [];
        string? currentFolderPath = null;
        string currentFolderTitle = string.Empty;
        List<LibraryVideoPresentation> currentVideos = [];

        void AppendCurrent()
        {
            if (currentFolderPath is not null && currentVideos.Count > 0) {
                groups.Add(new LibraryFolderPresentation(currentFolderPath, currentFolderTitle, currentVideos.ToArray()));
            }
        }

        while (reader.Read()) {
            string folderPath = reader.GetString(0);
            string subtitlePath = reader.GetString(5);
            if (folders.Count > 0 && !folders.Any(folder => PathContract.PathIsUnderFolder(subtitlePath, folder))) {
                continue;
            }

            if (!folderPath.Equals(currentFolderPath, StringComparison.OrdinalIgnoreCase)) {
                AppendCurrent();
                currentFolderPath = folderPath;
                currentFolderTitle = reader.GetString(1);
                currentVideos = [];
            }

            currentVideos.Add(new LibraryVideoPresentation(
                reader.GetString(2),
                reader.GetString(3),
                reader.IsDBNull(4) ? null : reader.GetDouble(4),
                subtitlePath,
                SubtitleFormatExtensions.FromRawValue(reader.GetString(6)),
                reader.GetString(7),
                reader.GetString(8)));
        }
        AppendCurrent();
        return groups;
    }

    public SubtitleSearchPage SearchPage(string query, int limit)
    {
        SearchQueryPlan? plan = SearchQueryPlan.Create(query, limit);
        if (plan is null) {
            return new SubtitleSearchPage([], 0, []);
        }

        try {
            using SqliteConnection connection = OpenConnection();
            IReadOnlyList<string> pathPrefixes = SearchPaths()
                .Select(path => PathContract.NormalizePath(path) + Path.DirectorySeparatorChar)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
            int candidateBatchLimit = SearchQueryPlan.SearchCandidateBatchLimit(limit);
            int candidateOffset = 0;
            List<SubtitleSearchResult> results = [];

            while (true) {
                List<SearchCandidate> candidates = LoadSearchCandidates(connection, plan, pathPrefixes, candidateBatchLimit, candidateOffset);
                if (candidates.Count == 0) {
                    break;
                }

                candidateOffset += candidates.Count;
                foreach (SearchCandidate candidate in candidates) {
                    if (SearchResult(connection, candidate, plan) is { } result) {
                        results.Add(result);
                    }
                }

                if (candidates.Count < candidateBatchLimit) {
                    break;
                }
            }

            List<SubtitleSearchResult> sorted = SortedSearchResults(results);
            List<SubtitleSearchResult> pageResults = sorted.Take(limit).ToList();
            return new SubtitleSearchPage(pageResults, sorted.Count, FileSummaries(sorted));
        } catch (SqliteException) {
            return new SubtitleSearchPage([], 0, []);
        }
    }

    public void RebuildLibraryPresentationSnapshot()
    {
        using SqliteConnection connection = OpenConnection();
        RebuildLibraryPresentationSnapshot(connection);
    }

    private SqliteConnection OpenConnection()
    {
        SqliteConnection connection = new($"Data Source={databasePath}");
        connection.Open();
        Execute(connection, "PRAGMA foreign_keys = ON;");
        Execute(connection, $"PRAGMA busy_timeout = {ConfiguredBusyTimeoutMilliseconds};");
        return connection;
    }

    private static int SchemaVersion(SqliteConnection connection)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText = "PRAGMA user_version;";
        return Convert.ToInt32(command.ExecuteScalar() ?? 0);
    }

    private static void EnsureSearchPathsTable(SqliteConnection connection)
    {
        if (!TableExists(connection, "search_paths")) {
            CreateSearchPathsTable(connection);
            return;
        }

        HashSet<string> columns = ColumnNames(connection, "search_paths");
        if (columns.IsSupersetOf(["id", "type", "path", "created_at", "updated_at"])) {
            return;
        }

        string legacyName = $"search_paths_legacy_{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        Execute(connection, $"ALTER TABLE search_paths RENAME TO {legacyName};");
        CreateSearchPathsTable(connection);

        string now = DateTimeOffset.UtcNow.ToString("O");
        string createdAtExpression = columns.Contains("added_at") ? "COALESCE(added_at, $now)" : "$now";
        using (SqliteCommand migrate = connection.CreateCommand()) {
            migrate.CommandText =
                $"""
                INSERT OR IGNORE INTO search_paths(type, path, created_at, updated_at)
                SELECT 'local', path, {createdAtExpression}, {createdAtExpression}
                FROM {legacyName}
                WHERE path IS NOT NULL;
                """;
            migrate.Parameters.AddWithValue("$now", now);
            migrate.ExecuteNonQuery();
        }

        Execute(connection, $"DROP TABLE {legacyName};");
    }

    private static void CreateSearchPathsTable(SqliteConnection connection)
    {
        Execute(connection,
            """
            CREATE TABLE IF NOT EXISTS search_paths (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL DEFAULT 'local',
                path TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """);
    }

    private static bool TableExists(SqliteConnection connection, string table)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText = "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = $name;";
        command.Parameters.AddWithValue("$name", table);
        return command.ExecuteScalar() is not null;
    }

    private static HashSet<string> ColumnNames(SqliteConnection connection, string table)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText = $"PRAGMA table_info({table});";
        using SqliteDataReader reader = command.ExecuteReader();
        HashSet<string> columns = new(StringComparer.OrdinalIgnoreCase);
        while (reader.Read()) {
            columns.Add(reader.GetString(1));
        }

        return columns;
    }

    private static void DropDerivedSubtitleIndexTables(SqliteConnection connection)
    {
        Execute(connection,
            """
            DROP TABLE IF EXISTS subtitle_cue_groups_fts;
            DROP TABLE IF EXISTS subtitle_cue_lines;
            DROP TABLE IF EXISTS subtitle_cue_groups;
            DROP TABLE IF EXISTS subtitle_video_matches;
            DROP TABLE IF EXISTS library_video_rows;
            DROP TABLE IF EXISTS video_files;
            DROP TABLE IF EXISTS subtitle_files;
            """);
    }

    private static SubtitleFileMetadata ReadSubtitleFileMetadata(SqliteDataReader reader)
    {
        return new SubtitleFileMetadata(
            reader.GetString(0),
            SubtitleFormatExtensions.FromRawValue(reader.GetString(1)),
            reader.IsDBNull(2) ? null : reader.GetInt64(2),
            reader.IsDBNull(3) ? null : reader.GetDouble(3),
            reader.IsDBNull(4) ? null : reader.GetString(4));
    }

    private static long UpsertSubtitleFile(SqliteConnection connection, string subtitlePath, SubtitleFormat format, long? fileSize, DateTimeOffset? modifiedAt)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO subtitle_files(subtitle_path, format, file_size, modified_at, indexed_at)
            VALUES ($subtitle_path, $format, $file_size, $modified_at, $indexed_at)
            ON CONFLICT(subtitle_path) DO UPDATE SET
                format = excluded.format,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at,
                indexed_at = excluded.indexed_at
            RETURNING id;
            """;
        command.Parameters.AddWithValue("$subtitle_path", subtitlePath);
        command.Parameters.AddWithValue("$format", format.RawValue());
        command.Parameters.AddWithValue("$file_size", fileSize.HasValue ? fileSize.Value : DBNull.Value);
        command.Parameters.AddWithValue("$modified_at", modifiedAt.HasValue ? UnixSeconds(modifiedAt.Value) : DBNull.Value);
        command.Parameters.AddWithValue("$indexed_at", DateTimeOffset.UtcNow.ToString("O"));
        return Convert.ToInt64(command.ExecuteScalar() ?? 0L);
    }

    private static long UpsertVideoFile(SqliteConnection connection, string videoPath)
    {
        FileInfo fileInfo = new(videoPath);
        long? fileSize = fileInfo.Exists ? fileInfo.Length : null;
        DateTimeOffset? modifiedAt = fileInfo.Exists ? new DateTimeOffset(fileInfo.LastWriteTimeUtc) : null;
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO video_files(path, video_name, file_size, modified_at)
            VALUES ($path, $video_name, $file_size, $modified_at)
            ON CONFLICT(path) DO UPDATE SET
                video_name = excluded.video_name,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at
            RETURNING id;
            """;
        command.Parameters.AddWithValue("$path", videoPath);
        command.Parameters.AddWithValue("$video_name", Path.GetFileName(videoPath));
        command.Parameters.AddWithValue("$file_size", fileSize.HasValue ? fileSize.Value : DBNull.Value);
        command.Parameters.AddWithValue("$modified_at", modifiedAt.HasValue ? UnixSeconds(modifiedAt.Value) : DBNull.Value);
        return Convert.ToInt64(command.ExecuteScalar() ?? 0L);
    }

    private static void UpsertSubtitleVideoMatch(SqliteConnection connection, long subtitleFileId, long videoFileId)
    {
        using (SqliteCommand clearActive = connection.CreateCommand()) {
            clearActive.CommandText = "UPDATE subtitle_video_matches SET is_active = 0 WHERE subtitle_file_id = $subtitle_file_id;";
            clearActive.Parameters.AddWithValue("$subtitle_file_id", subtitleFileId);
            clearActive.ExecuteNonQuery();
        }

        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO subtitle_video_matches(subtitle_file_id, video_file_id, match_method, confidence, is_active)
            VALUES ($subtitle_file_id, $video_file_id, 'same-directory-basename', 1.0, 1)
            ON CONFLICT(subtitle_file_id, video_file_id) DO UPDATE SET
                match_method = excluded.match_method,
                confidence = excluded.confidence,
                is_active = excluded.is_active;
            """;
        command.Parameters.AddWithValue("$subtitle_file_id", subtitleFileId);
        command.Parameters.AddWithValue("$video_file_id", videoFileId);
        command.ExecuteNonQuery();
    }

    private static long InsertCueGroup(SqliteConnection connection, long subtitleFileId, string subtitlePath, SubtitleCueGroup group)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO subtitle_cue_groups(subtitle_file_id, subtitle_path, seq, start_time, end_time, start_ms, end_ms, search_content)
            VALUES ($subtitle_file_id, $subtitle_path, $seq, $start_time, $end_time, $start_ms, $end_ms, $search_content);
            SELECT last_insert_rowid();
            """;
        command.Parameters.AddWithValue("$subtitle_file_id", subtitleFileId);
        command.Parameters.AddWithValue("$subtitle_path", subtitlePath);
        command.Parameters.AddWithValue("$seq", group.SequenceNumber.HasValue ? group.SequenceNumber.Value : DBNull.Value);
        command.Parameters.AddWithValue("$start_time", group.StartTimecode);
        command.Parameters.AddWithValue("$end_time", group.EndTimecode);
        command.Parameters.AddWithValue("$start_ms", group.StartMilliseconds);
        command.Parameters.AddWithValue("$end_ms", group.EndMilliseconds);
        command.Parameters.AddWithValue("$search_content", group.SearchContent);
        return Convert.ToInt64(command.ExecuteScalar() ?? 0L);
    }

    private static void InsertCueLine(SqliteConnection connection, long cueGroupId, SubtitleCueLine line)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO subtitle_cue_lines(
                cue_group_id, event_index, source_format, source_style, source_layer,
                start_time, end_time, start_ms, end_ms, content,
                display_x, display_y, display_order)
            VALUES (
                $cue_group_id, $event_index, $source_format, $source_style, $source_layer,
                $start_time, $end_time, $start_ms, $end_ms, $content,
                $display_x, $display_y, $display_order);
            """;
        command.Parameters.AddWithValue("$cue_group_id", cueGroupId);
        command.Parameters.AddWithValue("$event_index", line.EventIndex);
        command.Parameters.AddWithValue("$source_format", line.SourceFormat.RawValue());
        command.Parameters.AddWithValue("$source_style", line.SourceStyle is null ? DBNull.Value : line.SourceStyle);
        command.Parameters.AddWithValue("$source_layer", line.SourceLayer.HasValue ? line.SourceLayer.Value : DBNull.Value);
        command.Parameters.AddWithValue("$start_time", line.StartTimecode);
        command.Parameters.AddWithValue("$end_time", line.EndTimecode);
        command.Parameters.AddWithValue("$start_ms", line.StartMilliseconds);
        command.Parameters.AddWithValue("$end_ms", line.EndMilliseconds);
        command.Parameters.AddWithValue("$content", line.Content);
        command.Parameters.AddWithValue("$display_x", line.DisplayX.HasValue ? line.DisplayX.Value : DBNull.Value);
        command.Parameters.AddWithValue("$display_y", line.DisplayY.HasValue ? line.DisplayY.Value : DBNull.Value);
        command.Parameters.AddWithValue("$display_order", line.DisplayOrder);
        command.ExecuteNonQuery();
    }

    private static void InsertFtsRow(SqliteConnection connection, long cueGroupId, string content)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO subtitle_cue_groups_fts(content, cue_group_id)
            VALUES ($content, $cue_group_id);
            """;
        command.Parameters.AddWithValue("$content", SearchQueryPlan.SegmentCjkForFts(content));
        command.Parameters.AddWithValue("$cue_group_id", cueGroupId);
        command.ExecuteNonQuery();
    }

    private static void RebuildLibraryPresentationSnapshot(SqliteConnection connection)
    {
        IReadOnlyList<LibraryVideo> videos = IndexedLibraryVideos(connection);
        List<IGrouping<string, LibraryVideo>> grouped = videos
            .GroupBy(video => Path.GetDirectoryName(video.VideoPath) ?? string.Empty, StringComparer.OrdinalIgnoreCase)
            .OrderBy(group => Path.GetFileName(group.Key), NaturalSort.Comparer)
            .ThenBy(group => group.Key, NaturalSort.Comparer)
            .ToList();

        BeginImmediateTransaction(connection);
        try {
            Execute(connection, "DELETE FROM library_video_rows;");
            string updatedAt = DateTimeOffset.UtcNow.ToString("O");
            foreach ((IGrouping<string, LibraryVideo> group, int folderOrder) in grouped.Select((group, index) => (group, index))) {
                string folderPath = group.Key;
                string folderTitle = Path.GetFileName(folderPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
                List<LibraryVideo> groupVideos = group.OrderBy(video => video.VideoName, NaturalSort.Comparer)
                    .ThenBy(video => video.VideoPath, NaturalSort.Comparer)
                    .ToList();
                int rankWidth = Math.Max(2, groupVideos.Count.ToString().Length);

                foreach ((LibraryVideo video, int videoOrder) in groupVideos.Select((video, index) => (video, index))) {
                    using SqliteCommand insert = connection.CreateCommand();
                    insert.CommandText =
                        """
                        INSERT INTO library_video_rows(
                            video_path, video_name, duration, subtitle_path, subtitle_format,
                            folder_path, folder_title, display_title, file_extension,
                            folder_order, video_order, updated_at)
                        VALUES (
                            $video_path, $video_name, $duration, $subtitle_path, $subtitle_format,
                            $folder_path, $folder_title, $display_title, $file_extension,
                            $folder_order, $video_order, $updated_at);
                        """;
                    string sequence = (videoOrder + 1).ToString().PadLeft(rankWidth, '0');
                    insert.Parameters.AddWithValue("$video_path", video.VideoPath);
                    insert.Parameters.AddWithValue("$video_name", video.VideoName);
                    insert.Parameters.AddWithValue("$duration", video.Duration.HasValue ? video.Duration.Value : DBNull.Value);
                    insert.Parameters.AddWithValue("$subtitle_path", video.SubtitlePath);
                    insert.Parameters.AddWithValue("$subtitle_format", video.SubtitleFormat.RawValue());
                    insert.Parameters.AddWithValue("$folder_path", folderPath);
                    insert.Parameters.AddWithValue("$folder_title", folderTitle);
                    insert.Parameters.AddWithValue("$display_title", $"{folderTitle} - {sequence}");
                    insert.Parameters.AddWithValue("$file_extension", Path.GetExtension(video.VideoPath).TrimStart('.').ToLowerInvariant());
                    insert.Parameters.AddWithValue("$folder_order", folderOrder);
                    insert.Parameters.AddWithValue("$video_order", videoOrder);
                    insert.Parameters.AddWithValue("$updated_at", updatedAt);
                    insert.ExecuteNonQuery();
                }
            }

            Execute(connection, "COMMIT;");
        } catch {
            TryRollback(connection);
            throw;
        }
    }

    private static IReadOnlyList<LibraryVideo> IndexedLibraryVideos(SqliteConnection connection)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT vf.path, vf.video_name, vf.duration, sf.subtitle_path, sf.format
            FROM subtitle_files sf
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """;
        using SqliteDataReader reader = command.ExecuteReader();
        Dictionary<string, LibraryVideo> videosByPath = new(StringComparer.OrdinalIgnoreCase);
        while (reader.Read()) {
            LibraryVideo video = new(
                reader.GetString(0),
                reader.GetString(1),
                reader.IsDBNull(2) ? null : reader.GetDouble(2),
                reader.GetString(3),
                SubtitleFormatExtensions.FromRawValue(reader.GetString(4)));

            if (!videosByPath.TryGetValue(video.VideoPath, out LibraryVideo? existing)
                || NaturalSort.Compare(video.SubtitlePath, existing.SubtitlePath) < 0) {
                videosByPath[video.VideoPath] = video;
            }
        }

        return videosByPath.Values
            .OrderBy(video => Path.GetDirectoryName(video.VideoPath) ?? string.Empty, NaturalSort.Comparer)
            .ThenBy(video => video.VideoName, NaturalSort.Comparer)
            .ThenBy(video => video.VideoPath, NaturalSort.Comparer)
            .ToList();
    }

    private static List<SearchCandidate> LoadSearchCandidates(SqliteConnection connection, SearchQueryPlan plan, IReadOnlyList<string> pathPrefixes, int limit, int offset)
    {
        string scopeCondition = pathPrefixes.Count == 0
            ? string.Empty
            : "AND (" + string.Join(" OR ", pathPrefixes.Select((_, index) => $"substr(sf.subtitle_path, 1, $prefix_len_{index}) = $prefix_{index}")) + ")";
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            $"""
            SELECT g.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.start_ms, g.end_ms, g.search_content
            FROM subtitle_cue_groups_fts f
            JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE subtitle_cue_groups_fts MATCH $fts_query
            {scopeCondition}
            ORDER BY vf.video_name ASC, g.start_ms ASC, g.id ASC
            LIMIT $limit OFFSET $offset;
            """;
        command.Parameters.AddWithValue("$fts_query", plan.FtsQuery);
        for (int index = 0; index < pathPrefixes.Count; index++) {
            command.Parameters.AddWithValue($"$prefix_len_{index}", pathPrefixes[index].Length);
            command.Parameters.AddWithValue($"$prefix_{index}", pathPrefixes[index]);
        }
        command.Parameters.AddWithValue("$limit", limit);
        command.Parameters.AddWithValue("$offset", offset);

        using SqliteDataReader reader = command.ExecuteReader();
        List<SearchCandidate> candidates = [];
        while (reader.Read()) {
            candidates.Add(new SearchCandidate(
                reader.GetInt64(0),
                reader.GetString(1),
                SubtitleFormatExtensions.FromRawValue(reader.GetString(2)),
                reader.GetString(3),
                reader.GetString(4),
                checked((int)reader.GetInt64(5)),
                checked((int)reader.GetInt64(6)),
                reader.GetString(7)));
        }

        return candidates;
    }

    private static SubtitleSearchResult? SearchResult(SqliteConnection connection, SearchCandidate candidate, SearchQueryPlan plan)
    {
        IReadOnlyList<string> cueLines = CueLines(connection, candidate.EntryId);
        IReadOnlyList<string> searchableLines = cueLines.Count == 0 ? [candidate.Content] : cueLines;
        if (!searchableLines.Any(plan.LineMatches)) {
            return null;
        }

        return new SubtitleSearchResult(
            candidate.EntryId,
            candidate.SubtitlePath,
            candidate.SubtitleFormat,
            candidate.VideoPath,
            candidate.VideoName,
            candidate.StartMilliseconds,
            candidate.EndMilliseconds,
            candidate.Content,
            cueLines);
    }

    private static IReadOnlyList<string> CueLines(SqliteConnection connection, long cueGroupId)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT content
            FROM subtitle_cue_lines
            WHERE cue_group_id = $cue_group_id
            ORDER BY display_order ASC, event_index ASC, id ASC;
            """;
        command.Parameters.AddWithValue("$cue_group_id", cueGroupId);
        using SqliteDataReader reader = command.ExecuteReader();
        List<string> lines = [];
        while (reader.Read()) {
            lines.Add(reader.GetString(0));
        }

        return lines;
    }

    private static List<SubtitleSearchResult> SortedSearchResults(IReadOnlyList<SubtitleSearchResult> results)
    {
        Dictionary<string, string> displayTitles = DisplayTitlesByPath(results.Select(result => result.SubtitlePath));
        return results
            .OrderBy(result => displayTitles[result.SubtitlePath], Comparer<string>.Create(SubtitleDisplayTitleResolver.CompareDisplayTitles))
            .ThenBy(result => result.SubtitlePath, NaturalSort.Comparer)
            .ThenBy(result => result.StartMilliseconds)
            .ThenBy(result => result.EndMilliseconds)
            .ThenBy(result => result.EntryId)
            .ToList();
    }

    private static IReadOnlyList<SubtitleSearchFileSummary> FileSummaries(IReadOnlyList<SubtitleSearchResult> results)
    {
        Dictionary<string, string> displayTitles = DisplayTitlesByPath(results.Select(result => result.SubtitlePath));
        return results
            .GroupBy(result => result.SubtitlePath, StringComparer.OrdinalIgnoreCase)
            .Select(group => new SubtitleSearchFileSummary(
                group.Key,
                Path.GetFileName(group.Key),
                displayTitles[group.Key],
                group.Count()))
            .OrderBy(summary => summary.SubtitleDisplayTitle, Comparer<string>.Create(SubtitleDisplayTitleResolver.CompareDisplayTitles))
            .ThenBy(summary => summary.SubtitlePath, NaturalSort.Comparer)
            .ToList();
    }

    private static Dictionary<string, string> DisplayTitlesByPath(IEnumerable<string> subtitlePaths)
    {
        return subtitlePaths
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToDictionary(path => path, SubtitleDisplayTitleResolver.DisplayTitle, StringComparer.OrdinalIgnoreCase);
    }

    private void RemoveIndexedData(string folder, ISet<string> subtitleFiles, bool removeSearchPath)
    {
        string normalizedFolder = PathContract.NormalizePath(folder);
        List<string> prefixes = FolderPathPrefixes(normalizedFolder);
        List<string> keepPaths = subtitleFiles
            .Select(PathContract.NormalizePath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        string keepCondition = keepPaths.Count == 0
            ? string.Empty
            : "AND sf.subtitle_path NOT IN (" + string.Join(", ", keepPaths.Select((_, index) => $"$keep_{index}")) + ")";
        string libraryKeepCondition = keepPaths.Count == 0
            ? string.Empty
            : "AND subtitle_path NOT IN (" + string.Join(", ", keepPaths.Select((_, index) => $"$keep_{index}")) + ")";

        using SqliteConnection connection = OpenConnection();
        BeginImmediateTransaction(connection);
        try {
            using (SqliteCommand deleteFts = connection.CreateCommand()) {
                deleteFts.CommandText =
                    $"""
                    DELETE FROM subtitle_cue_groups_fts
                    WHERE cue_group_id IN (
                        SELECT g.id
                        FROM subtitle_cue_groups g
                        JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                        WHERE ({PrefixCondition("sf.subtitle_path", prefixes)}) {keepCondition}
                    );
                    """;
                BindFolderParameters(deleteFts, normalizedFolder, prefixes, keepPaths);
                deleteFts.ExecuteNonQuery();
            }

            using (SqliteCommand deleteLibraryRows = connection.CreateCommand()) {
                deleteLibraryRows.CommandText =
                    $"""
                    DELETE FROM library_video_rows
                    WHERE ({PrefixCondition("subtitle_path", prefixes)}) {libraryKeepCondition};
                    """;
                BindFolderParameters(deleteLibraryRows, normalizedFolder, prefixes, keepPaths);
                deleteLibraryRows.ExecuteNonQuery();
            }

            using (SqliteCommand deleteFiles = connection.CreateCommand()) {
                deleteFiles.CommandText =
                    $"""
                    DELETE FROM subtitle_files
                    WHERE id IN (
                        SELECT sf.id
                        FROM subtitle_files sf
                        WHERE ({PrefixCondition("sf.subtitle_path", prefixes)}) {keepCondition}
                    );
                    """;
                BindFolderParameters(deleteFiles, normalizedFolder, prefixes, keepPaths);
                deleteFiles.ExecuteNonQuery();
            }

            if (removeSearchPath) {
                using SqliteCommand deleteSearchPath = connection.CreateCommand();
                deleteSearchPath.CommandText = "DELETE FROM search_paths WHERE path = $path;";
                deleteSearchPath.Parameters.AddWithValue("$path", normalizedFolder);
                deleteSearchPath.ExecuteNonQuery();
            }

            DeleteOrphanedVideoFiles(connection);
            Execute(connection, "COMMIT;");
        } catch {
            TryRollback(connection);
            throw;
        }
    }

    private static void DeleteIndexedSubtitlePath(SqliteConnection connection, string subtitlePath)
    {
        using (SqliteCommand deleteFts = connection.CreateCommand()) {
            deleteFts.CommandText =
                """
                DELETE FROM subtitle_cue_groups_fts
                WHERE cue_group_id IN (
                    SELECT g.id
                    FROM subtitle_cue_groups g
                    JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                    WHERE sf.subtitle_path = $subtitle_path
                );
                """;
            deleteFts.Parameters.AddWithValue("$subtitle_path", subtitlePath);
            deleteFts.ExecuteNonQuery();
        }

        using SqliteCommand deleteFile = connection.CreateCommand();
        deleteFile.CommandText = "DELETE FROM subtitle_files WHERE subtitle_path = $subtitle_path;";
        deleteFile.Parameters.AddWithValue("$subtitle_path", subtitlePath);
        deleteFile.ExecuteNonQuery();
    }

    private static void DeleteOrphanedVideoFiles(SqliteConnection connection)
    {
        Execute(connection,
            """
            DELETE FROM video_files
            WHERE id NOT IN (
                SELECT DISTINCT video_file_id FROM subtitle_video_matches
            );
            """);
    }

    private static List<string> FolderPathPrefixes(string normalizedFolder)
    {
        return new[] {
                normalizedFolder + Path.DirectorySeparatorChar,
                normalizedFolder + Path.AltDirectorySeparatorChar,
            }
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static string PrefixCondition(string columnExpression, IReadOnlyList<string> prefixes)
    {
        List<string> conditions = [$"{columnExpression} = $folder"];
        conditions.AddRange(prefixes.Select((_, index) => $"substr({columnExpression}, 1, $prefix_len_{index}) = $prefix_{index}"));
        return string.Join(" OR ", conditions);
    }

    private static void BindFolderParameters(SqliteCommand command, string normalizedFolder, IReadOnlyList<string> prefixes, IReadOnlyList<string> keepPaths)
    {
        command.Parameters.AddWithValue("$folder", normalizedFolder);
        for (int index = 0; index < prefixes.Count; index++) {
            command.Parameters.AddWithValue($"$prefix_len_{index}", prefixes[index].Length);
            command.Parameters.AddWithValue($"$prefix_{index}", prefixes[index]);
        }

        for (int index = 0; index < keepPaths.Count; index++) {
            command.Parameters.AddWithValue($"$keep_{index}", keepPaths[index]);
        }
    }

    private static void BeginImmediateTransaction(SqliteConnection connection)
    {
        Execute(connection, "BEGIN IMMEDIATE TRANSACTION;");
    }

    private static void TryRollback(SqliteConnection connection)
    {
        try {
            Execute(connection, "ROLLBACK;");
        } catch (SqliteException) {
        }
    }

    private static void Execute(SqliteConnection connection, string sql)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    private sealed record SearchCandidate(
        long EntryId,
        string SubtitlePath,
        SubtitleFormat SubtitleFormat,
        string VideoPath,
        string VideoName,
        int StartMilliseconds,
        int EndMilliseconds,
        string Content);
}

internal sealed record SubtitleFileMetadata(
    string SubtitlePath,
    SubtitleFormat Format,
    long? FileSize,
    double? ModifiedAtSeconds,
    string? VideoPath);
