using CueSeeker.Windows.Core;
using Microsoft.Data.Sqlite;

namespace CueSeeker.Windows.Data;

internal sealed class SubtitleDatabase
{
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

    public void Migrate()
    {
        using SqliteConnection connection = OpenConnection();
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS search_paths (
                path TEXT PRIMARY KEY NOT NULL,
                added_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS subtitle_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_path TEXT NOT NULL UNIQUE,
                format TEXT NOT NULL,
                file_size INTEGER,
                modified_at TEXT,
                indexed_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS video_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                path TEXT NOT NULL UNIQUE,
                video_name TEXT NOT NULL,
                duration REAL
            );

            CREATE TABLE IF NOT EXISTS subtitle_video_matches (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_file_id INTEGER NOT NULL REFERENCES subtitle_files(id) ON DELETE CASCADE,
                video_file_id INTEGER NOT NULL REFERENCES video_files(id) ON DELETE CASCADE,
                match_method TEXT NOT NULL,
                confidence REAL NOT NULL,
                is_active INTEGER NOT NULL,
                UNIQUE(subtitle_file_id, video_file_id)
            );

            CREATE TABLE IF NOT EXISTS subtitle_cue_groups (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_file_id INTEGER NOT NULL REFERENCES subtitle_files(id) ON DELETE CASCADE,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                search_content TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS subtitle_cue_lines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cue_group_id INTEGER NOT NULL REFERENCES subtitle_cue_groups(id) ON DELETE CASCADE,
                display_order INTEGER NOT NULL,
                text TEXT NOT NULL
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

            CREATE INDEX IF NOT EXISTS idx_subtitle_files_subtitle_path ON subtitle_files(subtitle_path);
            CREATE INDEX IF NOT EXISTS idx_cue_groups_subtitle_file_id ON subtitle_cue_groups(subtitle_file_id);
            CREATE INDEX IF NOT EXISTS idx_cue_lines_group_order ON subtitle_cue_lines(cue_group_id, display_order);
            CREATE INDEX IF NOT EXISTS idx_library_video_rows_folder_order ON library_video_rows(folder_order, video_order);
            """;
        command.ExecuteNonQuery();
        RebuildLibraryPresentationSnapshot(connection);
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
        command.CommandText =
            """
            INSERT INTO search_paths(path, added_at)
            VALUES ($path, $added_at)
            ON CONFLICT(path) DO UPDATE SET added_at = excluded.added_at;
            """;
        command.Parameters.AddWithValue("$path", PathContract.NormalizePath(folder));
        command.Parameters.AddWithValue("$added_at", DateTimeOffset.UtcNow.ToString("O"));
        command.ExecuteNonQuery();
    }

    public void RemoveSearchPath(string folder)
    {
        string normalized = PathContract.NormalizePath(folder);
        using SqliteConnection connection = OpenConnection();
        DeleteIndexedSubtitlesWhere(connection, path => PathContract.PathIsUnderFolder(path, normalized));

        using SqliteCommand deletePath = connection.CreateCommand();
        deletePath.CommandText = "DELETE FROM search_paths WHERE path = $path;";
        deletePath.Parameters.AddWithValue("$path", normalized);
        deletePath.ExecuteNonQuery();

        DeleteOrphanedVideoFiles(connection);
        RebuildLibraryPresentationSnapshot(connection);
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
        if (!reader.Read()) {
            return null;
        }

        return new SubtitleFileMetadata(
            reader.GetString(0),
            SubtitleFormatExtensions.FromRawValue(reader.GetString(1)),
            reader.IsDBNull(2) ? null : reader.GetInt64(2),
            reader.IsDBNull(3) ? null : reader.GetString(3),
            reader.IsDBNull(4) ? null : reader.GetString(4));
    }

    public void ReplaceCueGroups(
        string subtitlePath,
        string videoPath,
        SubtitleFormat format,
        IReadOnlyList<SubtitleCueGroup> cueGroups,
        long? fileSize,
        DateTimeOffset? modifiedAt)
    {
        using SqliteConnection connection = OpenConnection();
        long subtitleFileId = UpsertSubtitleFile(connection, subtitlePath, format, fileSize, modifiedAt);
        long videoFileId = UpsertVideoFile(connection, videoPath);

        using (SqliteCommand deactivate = connection.CreateCommand()) {
            deactivate.CommandText = "UPDATE subtitle_video_matches SET is_active = 0 WHERE subtitle_file_id = $subtitle_file_id;";
            deactivate.Parameters.AddWithValue("$subtitle_file_id", subtitleFileId);
            deactivate.ExecuteNonQuery();
        }

        using (SqliteCommand match = connection.CreateCommand()) {
            match.CommandText =
                """
                INSERT INTO subtitle_video_matches(subtitle_file_id, video_file_id, match_method, confidence, is_active)
                VALUES ($subtitle_file_id, $video_file_id, 'same-directory-basename', 1.0, 1)
                ON CONFLICT(subtitle_file_id, video_file_id) DO UPDATE SET
                    match_method = excluded.match_method,
                    confidence = excluded.confidence,
                    is_active = excluded.is_active;
                """;
            match.Parameters.AddWithValue("$subtitle_file_id", subtitleFileId);
            match.Parameters.AddWithValue("$video_file_id", videoFileId);
            match.ExecuteNonQuery();
        }

        using (SqliteCommand deleteGroups = connection.CreateCommand()) {
            deleteGroups.CommandText = "DELETE FROM subtitle_cue_groups WHERE subtitle_file_id = $subtitle_file_id;";
            deleteGroups.Parameters.AddWithValue("$subtitle_file_id", subtitleFileId);
            deleteGroups.ExecuteNonQuery();
        }

        foreach (SubtitleCueGroup group in cueGroups) {
            long groupId;
            using (SqliteCommand insertGroup = connection.CreateCommand()) {
                insertGroup.CommandText =
                    """
                    INSERT INTO subtitle_cue_groups(subtitle_file_id, start_ms, end_ms, search_content)
                    VALUES ($subtitle_file_id, $start_ms, $end_ms, $search_content);
                    """;
                insertGroup.Parameters.AddWithValue("$subtitle_file_id", subtitleFileId);
                insertGroup.Parameters.AddWithValue("$start_ms", group.StartMilliseconds);
                insertGroup.Parameters.AddWithValue("$end_ms", group.EndMilliseconds);
                insertGroup.Parameters.AddWithValue("$search_content", group.SearchContent);
                insertGroup.ExecuteNonQuery();
            }

            using (SqliteCommand selectGroupId = connection.CreateCommand()) {
                selectGroupId.CommandText = "SELECT last_insert_rowid();";
                groupId = (long)(selectGroupId.ExecuteScalar() ?? 0L);
            }

            for (int index = 0; index < group.CueLines.Count; index++) {
                using SqliteCommand insertLine = connection.CreateCommand();
                insertLine.CommandText =
                    """
                    INSERT INTO subtitle_cue_lines(cue_group_id, display_order, text)
                    VALUES ($cue_group_id, $display_order, $text);
                    """;
                insertLine.Parameters.AddWithValue("$cue_group_id", groupId);
                insertLine.Parameters.AddWithValue("$display_order", index);
                insertLine.Parameters.AddWithValue("$text", group.CueLines[index]);
                insertLine.ExecuteNonQuery();
            }
        }

        RebuildLibraryPresentationSnapshot(connection);
    }

    public void RemoveStaleEntries(string folder, ISet<string> keptSubtitlePaths)
    {
        string normalizedFolder = PathContract.NormalizePath(folder);
        HashSet<string> kept = new(keptSubtitlePaths.Select(PathContract.NormalizePath), StringComparer.OrdinalIgnoreCase);
        using SqliteConnection connection = OpenConnection();
        DeleteIndexedSubtitlesWhere(connection, path => PathContract.PathIsUnderFolder(path, normalizedFolder) && !kept.Contains(path));
        DeleteOrphanedVideoFiles(connection);
        RebuildLibraryPresentationSnapshot(connection);
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
        SearchQueryPlan? plan = SearchQueryPlan.Create(query);
        if (plan is null) {
            return new SubtitleSearchPage([], 0, []);
        }

        HashSet<string> folders = SearchPaths().ToHashSet(StringComparer.OrdinalIgnoreCase);
        List<SearchCandidate> candidates = LoadSearchCandidates()
            .Where(candidate => folders.Count == 0 || folders.Any(folder => PathContract.PathIsUnderFolder(candidate.SubtitlePath, folder)))
            .Where(candidate => candidate.CueLines.Any(plan.LineMatches))
            .ToList();

        Dictionary<string, string> displayTitles = candidates
            .Select(candidate => candidate.SubtitlePath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToDictionary(path => path, SubtitleDisplayTitleResolver.DisplayTitle, StringComparer.OrdinalIgnoreCase);

        List<SubtitleSearchResult> sorted = candidates
            .OrderBy(candidate => displayTitles[candidate.SubtitlePath], NaturalSort.Comparer)
            .ThenBy(candidate => candidate.StartMilliseconds)
            .ThenBy(candidate => candidate.SubtitlePath, NaturalSort.Comparer)
            .Select(candidate => candidate.ToResult())
            .ToList();

        List<SubtitleSearchFileSummary> summaries = candidates
            .GroupBy(candidate => candidate.SubtitlePath, StringComparer.OrdinalIgnoreCase)
            .Select(group => new SubtitleSearchFileSummary(
                group.Key,
                Path.GetFileName(group.Key),
                displayTitles[group.Key],
                group.Count()))
            .OrderBy(summary => summary.SubtitleDisplayTitle, NaturalSort.Comparer)
            .ThenBy(summary => summary.SubtitlePath, NaturalSort.Comparer)
            .ToList();

        return new SubtitleSearchPage(sorted.Take(limit).ToList(), sorted.Count, summaries);
    }

    private SqliteConnection OpenConnection()
    {
        SqliteConnection connection = new($"Data Source={databasePath}");
        connection.Open();
        using SqliteCommand pragma = connection.CreateCommand();
        pragma.CommandText = "PRAGMA foreign_keys = ON;";
        pragma.ExecuteNonQuery();
        return connection;
    }

    private static long UpsertSubtitleFile(SqliteConnection connection, string subtitlePath, SubtitleFormat format, long? fileSize, DateTimeOffset? modifiedAt)
    {
        string normalized = PathContract.NormalizePath(subtitlePath);
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO subtitle_files(subtitle_path, format, file_size, modified_at, indexed_at)
            VALUES ($subtitle_path, $format, $file_size, $modified_at, $indexed_at)
            ON CONFLICT(subtitle_path) DO UPDATE SET
                format = excluded.format,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at,
                indexed_at = excluded.indexed_at;
            """;
        command.Parameters.AddWithValue("$subtitle_path", normalized);
        command.Parameters.AddWithValue("$format", format.RawValue());
        command.Parameters.AddWithValue("$file_size", fileSize.HasValue ? fileSize.Value : (object)DBNull.Value);
        command.Parameters.AddWithValue("$modified_at", modifiedAt?.ToString("O") ?? (object)DBNull.Value);
        command.Parameters.AddWithValue("$indexed_at", DateTimeOffset.UtcNow.ToString("O"));
        command.ExecuteNonQuery();

        using SqliteCommand select = connection.CreateCommand();
        select.CommandText = "SELECT id FROM subtitle_files WHERE subtitle_path = $subtitle_path;";
        select.Parameters.AddWithValue("$subtitle_path", normalized);
        return (long)(select.ExecuteScalar() ?? 0L);
    }

    private static long UpsertVideoFile(SqliteConnection connection, string videoPath)
    {
        string normalized = PathContract.NormalizePath(videoPath);
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            INSERT INTO video_files(path, video_name)
            VALUES ($path, $video_name)
            ON CONFLICT(path) DO UPDATE SET video_name = excluded.video_name;
            """;
        command.Parameters.AddWithValue("$path", normalized);
        command.Parameters.AddWithValue("$video_name", Path.GetFileName(normalized));
        command.ExecuteNonQuery();

        using SqliteCommand select = connection.CreateCommand();
        select.CommandText = "SELECT id FROM video_files WHERE path = $path;";
        select.Parameters.AddWithValue("$path", normalized);
        return (long)(select.ExecuteScalar() ?? 0L);
    }

    private void RebuildLibraryPresentationSnapshot(SqliteConnection connection)
    {
        IReadOnlyList<LibraryVideo> videos = IndexedLibraryVideos(connection);
        List<IGrouping<string, LibraryVideo>> grouped = videos
            .GroupBy(video => Path.GetDirectoryName(video.VideoPath) ?? string.Empty, StringComparer.OrdinalIgnoreCase)
            .OrderBy(group => Path.GetFileName(group.Key), NaturalSort.Comparer)
            .ThenBy(group => group.Key, NaturalSort.Comparer)
            .ToList();

        using SqliteCommand delete = connection.CreateCommand();
        delete.CommandText = "DELETE FROM library_video_rows;";
        delete.ExecuteNonQuery();

        string updatedAt = DateTimeOffset.UtcNow.ToString("O");
        for (int folderOrder = 0; folderOrder < grouped.Count; folderOrder++) {
            IGrouping<string, LibraryVideo> group = grouped[folderOrder];
            string folderPath = group.Key;
            string folderTitle = Path.GetFileName(folderPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            List<LibraryVideo> groupVideos = group.OrderBy(video => video.VideoName, NaturalSort.Comparer)
                .ThenBy(video => video.VideoPath, NaturalSort.Comparer)
                .ToList();
            int rankWidth = Math.Max(2, groupVideos.Count.ToString().Length);

            for (int videoOrder = 0; videoOrder < groupVideos.Count; videoOrder++) {
                LibraryVideo video = groupVideos[videoOrder];
                string sequence = (videoOrder + 1).ToString().PadLeft(rankWidth, '0');
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
                insert.Parameters.AddWithValue("$video_path", video.VideoPath);
                insert.Parameters.AddWithValue("$video_name", video.VideoName);
                insert.Parameters.AddWithValue("$duration", video.Duration.HasValue ? video.Duration.Value : (object)DBNull.Value);
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
            .OrderBy(video => Path.GetDirectoryName(video.VideoPath), NaturalSort.Comparer)
            .ThenBy(video => video.VideoName, NaturalSort.Comparer)
            .ThenBy(video => video.VideoPath, NaturalSort.Comparer)
            .ToList();
    }

    private List<SearchCandidate> LoadSearchCandidates()
    {
        using SqliteConnection connection = OpenConnection();
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT g.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.start_ms, g.end_ms, g.search_content,
                   l.display_order, l.text
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            LEFT JOIN subtitle_cue_lines l ON l.cue_group_id = g.id
            ORDER BY sf.subtitle_path ASC, g.start_ms ASC, g.end_ms ASC, l.display_order ASC;
            """;

        using SqliteDataReader reader = command.ExecuteReader();
        Dictionary<long, SearchCandidateBuilder> builders = [];
        while (reader.Read()) {
            long id = reader.GetInt64(0);
            if (!builders.TryGetValue(id, out SearchCandidateBuilder? builder)) {
                builder = new SearchCandidateBuilder(
                    id,
                    reader.GetString(1),
                    SubtitleFormatExtensions.FromRawValue(reader.GetString(2)),
                    reader.GetString(3),
                    reader.GetString(4),
                    checked((int)reader.GetInt64(5)),
                    checked((int)reader.GetInt64(6)),
                    reader.GetString(7));
                builders[id] = builder;
            }

            if (!reader.IsDBNull(9)) {
                builder.Lines.Add(reader.GetString(9));
            }
        }

        return builders.Values.Select(builder => builder.Build()).ToList();
    }

    private static void DeleteIndexedSubtitlesWhere(SqliteConnection connection, Func<string, bool> predicate)
    {
        List<string> paths = [];
        using (SqliteCommand select = connection.CreateCommand()) {
            select.CommandText = "SELECT subtitle_path FROM subtitle_files;";
            using SqliteDataReader reader = select.ExecuteReader();
            while (reader.Read()) {
                string path = reader.GetString(0);
                if (predicate(path)) {
                    paths.Add(path);
                }
            }
        }

        foreach (string path in paths) {
            using SqliteCommand delete = connection.CreateCommand();
            delete.CommandText = "DELETE FROM subtitle_files WHERE subtitle_path = $subtitle_path;";
            delete.Parameters.AddWithValue("$subtitle_path", path);
            delete.ExecuteNonQuery();
        }
    }

    private static void DeleteOrphanedVideoFiles(SqliteConnection connection)
    {
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText =
            """
            DELETE FROM video_files
            WHERE id NOT IN (
                SELECT DISTINCT video_file_id FROM subtitle_video_matches
            );
            """;
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
        string Content,
        IReadOnlyList<string> CueLines)
    {
        public SubtitleSearchResult ToResult()
        {
            return new SubtitleSearchResult(EntryId, SubtitlePath, SubtitleFormat, VideoPath, VideoName, StartMilliseconds, EndMilliseconds, Content, CueLines);
        }
    }

    private sealed class SearchCandidateBuilder
    {
        public SearchCandidateBuilder(long entryId, string subtitlePath, SubtitleFormat subtitleFormat, string videoPath, string videoName, int startMilliseconds, int endMilliseconds, string content)
        {
            EntryId = entryId;
            SubtitlePath = subtitlePath;
            SubtitleFormat = subtitleFormat;
            VideoPath = videoPath;
            VideoName = videoName;
            StartMilliseconds = startMilliseconds;
            EndMilliseconds = endMilliseconds;
            Content = content;
        }

        private long EntryId { get; }
        private string SubtitlePath { get; }
        private SubtitleFormat SubtitleFormat { get; }
        private string VideoPath { get; }
        private string VideoName { get; }
        private int StartMilliseconds { get; }
        private int EndMilliseconds { get; }
        private string Content { get; }
        public List<string> Lines { get; } = [];

        public SearchCandidate Build()
        {
            IReadOnlyList<string> lines = Lines.Count == 0 ? [Content] : Lines;
            return new SearchCandidate(EntryId, SubtitlePath, SubtitleFormat, VideoPath, VideoName, StartMilliseconds, EndMilliseconds, Content, lines);
        }
    }
}

internal sealed record SubtitleFileMetadata(
    string SubtitlePath,
    SubtitleFormat Format,
    long? FileSize,
    string? ModifiedAt,
    string? VideoPath);
