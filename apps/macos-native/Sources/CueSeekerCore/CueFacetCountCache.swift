enum CueFacetCountCache {
    static let durationFacet = "duration"
    static let characterFacet = "character"
    static let languageFacet = "language"
    static let watchStatusFacet = "watchStatus"

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
            default:
                continue
            }
        }

        return CueFacetDistribution(
            totalCount: durationCounts.values.reduce(0, +),
            durationCounts: durationCounts,
            characterCounts: characterCounts,
            languageCounts: languageCounts,
            watchStateCounts: watchStateCounts
        )
    }

    static func rebuildAll(on database: SQLiteDatabase) throws {
        try database.execute("DELETE FROM cue_facet_counts;")
        try rebuildDuration(on: database)
        try rebuildCharacter(on: database)
        try rebuildLanguage(on: database)
        try rebuildWatchStates(on: database)
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
            WITH searchable_cues AS (
                SELECT l.id AS cue_id,
                       l.subtitle_file_id,
                       l.cue_group_id,
                       l.source_format,
                       CASE
                           WHEN SUBSTR(TRIM(COALESCE(l.source_style, '')), 1, 1) = '*'
                               THEN SUBSTR(TRIM(COALESCE(l.source_style, '')), 2)
                           ELSE TRIM(COALESCE(l.source_style, ''))
                       END AS style_key
                FROM subtitle_cue_lines l
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                WHERE EXISTS (
                      SELECT 1
                      FROM subtitle_video_matches m
                      JOIN video_files vf ON vf.id = m.video_file_id
                      WHERE m.subtitle_file_id = sf.id
                        AND m.is_active = 1
                  )
            ),
            files_with_detections AS (
                SELECT DISTINCT d.subtitle_file_id
                FROM subtitle_language_detections d
                JOIN subtitle_language_detection_codes c ON c.detection_id = d.id
            ),
            detected_cue_languages AS (
                SELECT sc.cue_id, c.language_code
                FROM searchable_cues sc
                JOIN subtitle_language_detections d
                  ON d.subtitle_file_id = sc.subtitle_file_id
                JOIN subtitle_language_detection_codes c ON c.detection_id = d.id
                WHERE (sc.source_format = 'srt' AND d.scope = 'file')
                   OR (sc.source_format = 'ass' AND d.scope = 'style' AND d.scope_key = sc.style_key)
            ),
            resolved_languages AS (
                SELECT sc.cue_id,
                       COALESCE(dcl.language_code, '\(SubtitleLanguageCode.unknown.rawValue)') AS language_code
                FROM searchable_cues sc
                JOIN files_with_detections f ON f.subtitle_file_id = sc.subtitle_file_id
                LEFT JOIN detected_cue_languages dcl ON dcl.cue_id = sc.cue_id

                UNION ALL

                SELECT sc.cue_id,
                       COALESCE(cgl.language_code, '\(SubtitleLanguageCode.unknown.rawValue)') AS language_code
                FROM searchable_cues sc
                LEFT JOIN subtitle_cue_group_languages cgl ON cgl.cue_group_id = sc.cue_group_id
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM files_with_detections f
                    WHERE f.subtitle_file_id = sc.subtitle_file_id
                )
            )
            INSERT INTO cue_facet_counts(facet, value, cue_count)
            SELECT '\(languageFacet)', language_code, COUNT(DISTINCT cue_id)
            FROM resolved_languages
            GROUP BY language_code;
            """
        )
    }
}
