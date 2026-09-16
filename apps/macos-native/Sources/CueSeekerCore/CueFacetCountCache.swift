enum CueFacetCountCache {
    static let durationFacet = "duration"
    static let characterFacet = "character"
    static let languageFacet = "language"
    static let watchStatusFacet = "watchStatus"
    static let folderFacet = "folder"

    static func load(from database: SQLiteDatabase) throws -> CueFacetDistribution {
        let statement = try database.prepare(
            """
            SELECT facet, value, cue_count
            FROM cue_facet_counts
            ORDER BY facet ASC, value ASC;
            """
        )
        var durationCounts: [CueDurationFacet: Int] = [:]
        var characterCounts: [CueCharacterFacet: Int] = [:]
        var languageCounts: [SubtitleLanguageCode: Int] = [:]
        var watchStateCounts: [LibraryWatchState: Int] = [:]
        var folderCounts: [String: Int] = [:]

        while try statement.step() {
            let facet = statement.stringColumn(0)
            let value = statement.stringColumn(1)
            let count = statement.intColumn(2)
            switch facet {
            case durationFacet:
                if let value = CueDurationFacet(rawValue: value) {
                    durationCounts[value] = count
                }
            case characterFacet:
                if let value = CueCharacterFacet(rawValue: value) {
                    characterCounts[value] = count
                }
            case languageFacet:
                if let value = SubtitleLanguageCode(rawValue: value) {
                    languageCounts[value] = count
                }
            case watchStatusFacet:
                if let value = LibraryWatchState(rawValue: value) {
                    watchStateCounts[value] = count
                }
            case folderFacet:
                folderCounts[value] = count
            default:
                continue
            }
        }

        return CueFacetDistribution(
            totalCount: durationCounts.values.reduce(0, +),
            durationCounts: durationCounts,
            characterCounts: characterCounts,
            languageCounts: languageCounts,
            watchStateCounts: watchStateCounts,
            folderCounts: folderCounts
        )
    }

    static func rebuildAll(on database: SQLiteDatabase) throws {
        try database.execute("DELETE FROM cue_facet_counts;")
        try rebuildDuration(on: database)
        try rebuildCharacter(on: database)
        try rebuildLanguage(on: database)
        try rebuildWatchStates(on: database)
        try rebuildFolders(on: database)
    }

    /// The folder of every searchable cue, read from the search order rows
    /// the scan itself orders by; they are refreshed before the counts.
    /// Migrations from schemas whose order rows have no folder yet skip the
    /// group; schema 50 counts it once they do.
    private static func rebuildFolders(on database: SQLiteDatabase) throws {
        let columns = try database.prepare("PRAGMA table_info(subtitle_search_order_rows);")
        var hasFolderPath = false
        while try columns.step() {
            hasFolderPath = hasFolderPath || columns.stringColumn(1) == "folder_path"
        }
        guard hasFolderPath else {
            return
        }
        try database.execute(
            """
            INSERT INTO cue_facet_counts(facet, value, cue_count)
            SELECT '\(folderFacet)', sor.folder_path, COUNT(*)
            FROM subtitle_cue_lines l
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            WHERE EXISTS (
                  SELECT 1
                  FROM subtitle_video_matches m
                  JOIN video_files vf ON vf.id = m.video_file_id
                  WHERE m.subtitle_file_id = sf.id
                    AND m.is_active = 1
              )
            GROUP BY sor.folder_path;
            """
        )
    }

    static func rebuildWatchStates(on database: SQLiteDatabase) throws {
        try database.execute(
            "DELETE FROM cue_facet_counts WHERE facet = '\(watchStatusFacet)';"
        )
        try database.execute(
            """
            INSERT INTO cue_facet_counts(facet, value, cue_count)
            SELECT '\(watchStatusFacet)',
                   COALESCE(ws.state, '\(LibraryWatchState.unwatched.rawValue)'),
                   COUNT(DISTINCT l.id)
            FROM subtitle_cue_lines l
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            LEFT JOIN library_watch_states ws
              ON ws.video_file_id = vf.id
            GROUP BY COALESCE(ws.state, '\(LibraryWatchState.unwatched.rawValue)');
            """
        )
    }

    private static func rebuildDuration(on database: SQLiteDatabase) throws {
        try database.execute(
            """
            INSERT INTO cue_facet_counts(facet, value, cue_count)
            SELECT '\(durationFacet)',
                   CASE
                       WHEN l.end_ms - l.start_ms < 1000
                           THEN '\(CueDurationFacet.underOneSecond.rawValue)'
                       WHEN l.end_ms - l.start_ms < 3000
                           THEN '\(CueDurationFacet.oneToUnderThreeSeconds.rawValue)'
                       WHEN l.end_ms - l.start_ms < 5000
                           THEN '\(CueDurationFacet.threeToUnderFiveSeconds.rawValue)'
                       ELSE '\(CueDurationFacet.fiveSecondsOrMore.rawValue)'
                   END,
                   COUNT(*)
            FROM subtitle_cue_lines l
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            WHERE EXISTS (
                  SELECT 1
                  FROM subtitle_video_matches m
                  JOIN video_files vf ON vf.id = m.video_file_id
                  WHERE m.subtitle_file_id = sf.id
                    AND m.is_active = 1
              )
            GROUP BY 2;
            """
        )
    }

    private static func rebuildCharacter(on database: SQLiteDatabase) throws {
        try database.execute(
            """
            INSERT INTO cue_facet_counts(facet, value, cue_count)
            SELECT '\(characterFacet)',
                   CASE
                       WHEN LENGTH(l.content) <= 10
                           THEN '\(CueCharacterFacet.oneToTen.rawValue)'
                       WHEN LENGTH(l.content) <= 20
                           THEN '\(CueCharacterFacet.elevenToTwenty.rawValue)'
                       WHEN LENGTH(l.content) <= 30
                           THEN '\(CueCharacterFacet.twentyOneToThirty.rawValue)'
                       ELSE '\(CueCharacterFacet.thirtyOneOrMore.rawValue)'
                   END,
                   COUNT(*)
            FROM subtitle_cue_lines l
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            WHERE EXISTS (
                  SELECT 1
                  FROM subtitle_video_matches m
                  JOIN video_files vf ON vf.id = m.video_file_id
                  WHERE m.subtitle_file_id = sf.id
                    AND m.is_active = 1
              )
            GROUP BY 2;
            """
        )
    }

    private static func rebuildLanguage(on database: SQLiteDatabase) throws {
        try database.execute(
            """
            INSERT INTO cue_facet_counts(facet, value, cue_count)
            SELECT '\(languageFacet)', cll.language_code, COUNT(DISTINCT cll.cue_id)
            FROM subtitle_cue_line_languages cll
            JOIN subtitle_cue_lines l ON l.id = cll.cue_id
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            WHERE EXISTS (
                  SELECT 1
                  FROM subtitle_video_matches m
                  JOIN video_files vf ON vf.id = m.video_file_id
                  WHERE m.subtitle_file_id = sf.id
                    AND m.is_active = 1
              )
            GROUP BY cll.language_code;
            """
        )
    }
}
