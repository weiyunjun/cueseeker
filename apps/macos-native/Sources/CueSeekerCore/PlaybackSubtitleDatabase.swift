import Foundation

public final class PlaybackSubtitleDatabase: @unchecked Sendable {
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readOnly
    ) throws {
        database = try SQLiteDatabase(path: path, access: access)
    }

    public func hasCurrentPlaybackFinishMetadata(forSubtitleFile subtitleFile: URL) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM subtitle_playback_finish_metadata
            WHERE subtitle_path = ?
              AND algorithm_version = ?
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 2)
        return try statement.step()
    }

    public func cueTimings(
        forSubtitleFile subtitleFile: URL,
        startingAtMilliseconds startMilliseconds: Int,
        limit: Int
    ) throws -> [SubtitleCueTiming] {
        let limit = min(max(0, limit), 100)
        guard limit > 0 else {
            return []
        }

        let statement = try database.prepare(
            """
            SELECT g.start_ms, g.end_ms
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.start_ms >= ?
            ORDER BY g.start_ms ASC, g.id ASC
            LIMIT ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(max(0, startMilliseconds), at: 2)
        try statement.bind(limit, at: 3)

        var timings: [SubtitleCueTiming] = []
        while try statement.step() {
            timings.append(
                SubtitleCueTiming(
                    startMilliseconds: statement.intColumn(0),
                    endMilliseconds: statement.intColumn(1)
                )
            )
        }

        return timings
    }

    public func playbackFinishMetadata(
        forSubtitleFile subtitleFile: URL
    ) throws -> SubtitlePlaybackFinishMetadata? {
        let statement = try database.prepare(
            """
            SELECT primary_styles_json, primary_style_last_end_ms, last_subtitle_end_ms
            FROM subtitle_playback_finish_metadata
            WHERE subtitle_path = ?
              AND algorithm_version = ?;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 2)

        guard try statement.step() else {
            return nil
        }

        return SubtitlePlaybackFinishMetadata(
            primaryStyles: try Self.decodePrimaryStyles(from: statement.stringColumn(0)),
            primaryStyleLastEndMilliseconds: statement.nullableIntColumn(1),
            lastSubtitleEndMilliseconds: statement.nullableIntColumn(2)
        )
    }

    public func playbackFinishMetadata(
        forVideoFile videoFile: URL
    ) throws -> SubtitlePlaybackFinishMetadata? {
        let statement = try database.prepare(
            """
            SELECT pfm.primary_styles_json, pfm.primary_style_last_end_ms,
                   pfm.last_subtitle_end_ms
            FROM video_files vf
            JOIN subtitle_video_matches m ON m.video_file_id = vf.id AND m.is_active = 1
            JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
            JOIN subtitle_playback_finish_metadata pfm ON pfm.subtitle_file_id = sf.id
            WHERE vf.path = ?
              AND pfm.algorithm_version = ?
            ORDER BY sf.subtitle_path ASC
            LIMIT 1;
            """
        )
        try statement.bind(videoFile.path, at: 1)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 2)

        guard try statement.step() else {
            return nil
        }

        return SubtitlePlaybackFinishMetadata(
            primaryStyles: try Self.decodePrimaryStyles(from: statement.stringColumn(0)),
            primaryStyleLastEndMilliseconds: statement.nullableIntColumn(1),
            lastSubtitleEndMilliseconds: statement.nullableIntColumn(2)
        )
    }


    public func hasASSRenderSegments(forSubtitleFile subtitleFile: URL) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM ass_render_segments s
            JOIN subtitle_files sf ON sf.id = s.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND s.algorithm_version = ?
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(ASSRenderSegmenter.cacheAlgorithmVersion, at: 2)
        return try statement.step()
    }

    public func hasCurrentASSFontReferenceManifest(forSubtitleFile subtitleFile: URL) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM ass_font_reference_manifests m
            JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND m.algorithm_version = ?
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(ASSFontIntentExtractor.cacheAlgorithmVersion, at: 2)
        return try statement.step()
    }

    public func assFontReferences(forSubtitleFile subtitleFile: URL) throws -> [ASSFontReference] {
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, r.font_name, r.source_location,
                   r.occurrence_count, r.first_occurrence_order
            FROM ass_font_references r
            JOIN subtitle_files sf ON sf.id = r.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND r.algorithm_version = ?
            ORDER BY r.first_occurrence_order ASC, r.id ASC;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(ASSFontIntentExtractor.cacheAlgorithmVersion, at: 2)

        var references: [ASSFontReference] = []
        while try statement.step() {
            references.append(
                ASSFontReference(
                    subtitlePath: statement.stringColumn(0),
                    fontName: statement.stringColumn(1),
                    source: ASSFontReferenceSource(rawValue: statement.stringColumn(2)) ?? .style,
                    occurrenceCount: statement.intColumn(3),
                    firstOccurrenceOrder: statement.intColumn(4)
                )
            )
        }

        return references
    }

    public func assRenderSegment(
        forSubtitleFile subtitleFile: URL,
        atMilliseconds milliseconds: Int
    ) throws -> ASSRenderSegment? {
        let timestamp = max(0, milliseconds)
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, s.start_ms, s.end_ms, s.script_text,
                   s.event_count, s.byte_count
            FROM ass_render_segments s
            JOIN subtitle_files sf ON sf.id = s.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND s.algorithm_version = ?
              AND s.start_ms <= ?
              AND s.end_ms > ?
            ORDER BY s.start_ms DESC, s.segment_index DESC
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(ASSRenderSegmenter.cacheAlgorithmVersion, at: 2)
        try statement.bind(timestamp, at: 3)
        try statement.bind(timestamp, at: 4)

        guard try statement.step() else {
            return nil
        }

        return ASSRenderSegment(
            subtitlePath: statement.stringColumn(0),
            startMilliseconds: statement.intColumn(1),
            endMilliseconds: statement.intColumn(2),
            scriptText: statement.stringColumn(3),
            eventCount: statement.intColumn(4),
            byteCount: statement.intColumn(5)
        )
    }

    public func assFontResourceManifest(
        forSubtitleFile subtitleFile: URL,
        videoFile: URL
    ) throws -> ASSFontResourceManifest? {
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, vf.path, r.status, r.fonts_directory,
                   r.resource_signature, r.error_message, r.prepared_at
            FROM ass_font_resources r
            JOIN subtitle_files sf ON sf.id = r.subtitle_file_id
            JOIN video_files vf ON vf.id = r.video_file_id
            WHERE sf.subtitle_path = ? AND vf.path = ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(videoFile.path, at: 2)

        guard try statement.step() else {
            return nil
        }

        let status = ASSFontResourceStatus(rawValue: statement.stringColumn(2)) ?? .failed
        return ASSFontResourceManifest(
            subtitlePath: statement.stringColumn(0),
            videoPath: statement.stringColumn(1),
            status: status,
            fontsDirectoryPath: statement.nullableStringColumn(3),
            resourceSignature: statement.stringColumn(4),
            errorMessage: statement.nullableStringColumn(5),
            preparedAt: statement.stringColumn(6)
        )
    }


    private static func decodePrimaryStyles(from json: String) throws -> [String] {
        guard let data = json.data(using: .utf8) else {
            throw SQLiteDatabaseError.stepFailed("Primary style metadata could not be decoded.")
        }
        return try JSONDecoder().decode([String].self, from: data)
    }

}
