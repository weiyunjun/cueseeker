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

        try statement.bind(subtitleFile.mediaPath, at: 1)
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

        try statement.bind(subtitleFile.mediaPath, at: 1)
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
        try statement.bind(subtitleFile.mediaPath, at: 1)
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
        try statement.bind(videoFile.mediaPath, at: 1)
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

        try statement.bind(subtitleFile.mediaPath, at: 1)
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

        try statement.bind(subtitleFile.mediaPath, at: 1)
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

        try statement.bind(subtitleFile.mediaPath, at: 1)
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

        try statement.bind(subtitleFile.mediaPath, at: 1)
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

    private static func decodePrimaryStyles(from json: String) throws -> [String] {
        guard let data = json.data(using: .utf8) else {
            throw SQLiteDatabaseError.stepFailed("Primary style metadata could not be decoded.")
        }
        return try JSONDecoder().decode([String].self, from: data)
    }

}

extension PlaybackSubtitleDatabase {
    private enum SubtitleFileLookup {
        case id(Int64)
        case path(String)

        var predicate: String {
            switch self {
            case .id:
                "sf.id = ?"
            case .path:
                "sf.subtitle_path = ?"
            }
        }

        func bind(to statement: SQLiteStatement, at index: Int32) throws {
            switch self {
            case .id(let id):
                try statement.bind(id, at: index)
            case .path(let path):
                try statement.bind(path, at: index)
            }
        }
    }

    public func entries(forSubtitleFile subtitleFile: URL) throws -> [PlaybackSubtitleEntry] {
        try entries(forSubtitleFile: subtitleFile, limit: Int.max, offset: 0)
    }

    public func subtitleEntryIndex(
        forSubtitleFile subtitleFile: URL
    ) throws -> [PlaybackSubtitleEntryIndexItem] {
        let statement = try database.prepare(
            """
            SELECT g.id, g.start_ms, g.end_ms
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC;
            """
        )

        try statement.bind(subtitleFile.mediaPath, at: 1)

        var index: [PlaybackSubtitleEntryIndexItem] = []
        while try statement.step() {
            index.append(
                PlaybackSubtitleEntryIndexItem(
                    id: statement.int64Column(0),
                    startMilliseconds: statement.intColumn(1),
                    endMilliseconds: statement.intColumn(2)
                )
            )
        }

        return index
    }

    public func entries(
        forSubtitleFile subtitleFile: URL,
        limit: Int,
        offset: Int
    ) throws -> [PlaybackSubtitleEntry] {
        let requestedLimit = max(0, limit)
        guard requestedLimit > 0 else {
            return []
        }

        let statement = try database.prepare(
            """
            SELECT g.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.seq, g.start_time, g.end_time, g.start_ms, g.end_ms, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC
            LIMIT ? OFFSET ?;
            """
        )

        try statement.bind(subtitleFile.mediaPath, at: 1)
        try statement.bind(requestedLimit, at: 2)
        try statement.bind(max(0, offset), at: 3)

        var entries: [PlaybackSubtitleEntry] = []
        while try statement.step() {
            entries.append(entry(from: statement))
        }

        return entries
    }

    public func cueLineRecords(forSubtitleFile subtitleFile: URL) throws -> [SubtitleCueLineRecord] {
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC, l.display_order ASC, l.event_index ASC, l.id ASC;
            """
        )

        try statement.bind(subtitleFile.mediaPath, at: 1)

        var records: [SubtitleCueLineRecord] = []
        while try statement.step() {
            records.append(cueLineRecord(from: statement))
        }
        return records
    }

    private func entry(from statement: SQLiteStatement) -> PlaybackSubtitleEntry {
        PlaybackSubtitleEntry(
            id: statement.int64Column(0),
            subtitlePath: statement.stringColumn(1),
            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
            videoPath: statement.stringColumn(3),
            videoName: statement.stringColumn(4),
            sequenceNumber: statement.nullableIntColumn(5),
            startTimecode: statement.stringColumn(6),
            endTimecode: statement.stringColumn(7),
            startMilliseconds: statement.intColumn(8),
            endMilliseconds: statement.intColumn(9),
            content: statement.stringColumn(10)
        )
    }

    private func cueLineRecord(from statement: SQLiteStatement) -> SubtitleCueLineRecord {
        SubtitleCueLineRecord(
            id: statement.int64Column(0),
            cueGroupID: statement.int64Column(1),
            line: SubtitleCueLine(
                eventIndex: statement.intColumn(2),
                sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt,
                sourceStyle: statement.nullableStringColumn(4),
                sourceLayer: statement.nullableIntColumn(5),
                startTimecode: statement.stringColumn(6),
                endTimecode: statement.stringColumn(7),
                startMilliseconds: statement.intColumn(8),
                endMilliseconds: statement.intColumn(9),
                content: statement.stringColumn(10),
                displayX: statement.nullableDoubleColumn(11),
                displayY: statement.nullableDoubleColumn(12),
                displayOrder: statement.intColumn(13)
            )
        )
    }
}

extension PlaybackSubtitleDatabase {
    private struct CueGroupSelection {
        let cueGroupID: Int64
        let startMilliseconds: Int
        let endMilliseconds: Int
        let searchContent: String
    }

    public func cueTextSelection(
        forSubtitleFile subtitleFile: URL,
        atMilliseconds milliseconds: Int
    ) throws -> SubtitleCueTextSelection? {
        let timestamp = max(0, milliseconds)
        guard let group = try activeCueGroupSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: timestamp
        ) ?? previousCueGroupSelection(
            forSubtitleFile: subtitleFile,
            beforeOrAtMilliseconds: timestamp
        ) else {
            return nil
        }

        if let selection = try bottommostCueTextSelection(forCueGroupID: group.cueGroupID) {
            return selection
        }
        return SubtitleCueTextSelection(
            cueGroupID: group.cueGroupID,
            startMilliseconds: group.startMilliseconds,
            endMilliseconds: group.endMilliseconds,
            cueEventIndex: nil,
            cueDisplayOrder: nil,
            content: group.searchContent
        )
    }

    public func subtitleFocusInitialSnapshot(
        forSubtitleFileID subtitleFileID: Int64,
        atMilliseconds milliseconds: Int,
        policy: SubtitleFocusWindowPolicy = .standard
    ) throws -> SubtitleFocusSnapshot? {
        let timestamp = max(0, milliseconds)
        let activeGroup = try activeCueGroupSelection(
            for: .id(subtitleFileID),
            atMilliseconds: timestamp
        )
        let activeCueID = try activeGroup.flatMap { group in
            try bottommostCueTextSelection(forCueGroupID: group.cueGroupID)?.cueLineID
        }
        guard let selectedCueID = try activeCueID
            ?? subtitleFocusPreviousCueLineID(
                forSubtitleFileID: subtitleFileID,
                beforeOrAtMilliseconds: timestamp
            )
            ?? subtitleFocusFirstCueLineID(forSubtitleFileID: subtitleFileID),
        let metadata = try subtitleFocusOrdinalMetadata(
            forSubtitleFileID: subtitleFileID,
            cueLineID: selectedCueID
        ) else {
            return nil
        }

        let range = policy.windowRange(
            totalCount: metadata.totalCount,
            selectedOrdinal: metadata.ordinal
        )
        let batch = try subtitleFocusCueBatch(
            forSubtitleFileID: subtitleFileID,
            totalCount: metadata.totalCount,
            startingAtOrdinal: range.lowerBound,
            limit: range.count,
            didReadCue: nil
        )
        guard batch.cues.count == range.count,
              batch.cues.contains(where: {
                  $0.id == selectedCueID && $0.ordinal == metadata.ordinal
              }) else {
            return nil
        }
        return SubtitleFocusSnapshot(
            totalCount: metadata.totalCount,
            selectedOrdinal: metadata.ordinal,
            cues: batch.cues
        )
    }

    public func subtitleFocusCueBatch(
        forSubtitleFileID subtitleFileID: Int64,
        totalCount requestedTotalCount: Int,
        startingAtOrdinal requestedOrdinal: Int,
        limit requestedLimit: Int
    ) throws -> SubtitleFocusCueBatch {
        try subtitleFocusCueBatch(
            forSubtitleFileID: subtitleFileID,
            totalCount: requestedTotalCount,
            startingAtOrdinal: requestedOrdinal,
            limit: requestedLimit,
            didReadCue: nil
        )
    }

    func subtitleFocusCueBatch(
        forSubtitleFileID subtitleFileID: Int64,
        totalCount requestedTotalCount: Int,
        startingAtOrdinal requestedOrdinal: Int,
        limit requestedLimit: Int,
        didReadCue: ((Int) -> Void)?
    ) throws -> SubtitleFocusCueBatch {
        try Task.checkCancellation()
        let totalCount = max(0, requestedTotalCount)
        let startOrdinal = min(max(0, requestedOrdinal), totalCount)
        let limit = min(max(0, requestedLimit), max(0, totalCount - startOrdinal))
        guard limit > 0 else {
            return SubtitleFocusCueBatch(totalCount: totalCount, cues: [])
        }

        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.display_order,
                   l.start_ms, l.end_ms, l.content
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.id = ?
              AND g.end_ms > g.start_ms
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                     l.display_order ASC, l.event_index ASC, l.id ASC
            LIMIT ? OFFSET ?;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(limit, at: 2)
        try statement.bind(startOrdinal, at: 3)

        var cues: [SubtitleFocusCue] = []
        cues.reserveCapacity(limit)
        var offset = 0
        while true {
            try Task.checkCancellation()
            guard try statement.step() else {
                break
            }
            cues.append(
                SubtitleFocusCue(
                    id: statement.int64Column(0),
                    cueGroupID: statement.int64Column(1),
                    ordinal: startOrdinal + offset,
                    eventIndex: statement.intColumn(2),
                    displayOrder: statement.intColumn(3),
                    startMilliseconds: statement.intColumn(4),
                    endMilliseconds: statement.intColumn(5),
                    content: statement.stringColumn(6)
                )
            )
            offset += 1
            didReadCue?(offset)
        }
        return SubtitleFocusCueBatch(totalCount: totalCount, cues: cues)
    }

    private func bottommostCueTextSelection(
        forCueGroupID cueGroupID: Int64
    ) throws -> SubtitleCueTextSelection? {
        let statement = try database.prepare(
            """
            SELECT id, event_index, display_order, start_ms, end_ms, content
            FROM subtitle_cue_lines
            WHERE cue_group_id = ?
            ORDER BY display_order DESC, event_index DESC, id DESC
            LIMIT 1;
            """
        )
        try statement.bind(cueGroupID, at: 1)
        guard try statement.step() else {
            return nil
        }
        return SubtitleCueTextSelection(
            cueGroupID: cueGroupID,
            cueLineID: statement.int64Column(0),
            startMilliseconds: statement.intColumn(3),
            endMilliseconds: statement.intColumn(4),
            cueEventIndex: statement.intColumn(1),
            cueDisplayOrder: statement.intColumn(2),
            content: statement.stringColumn(5)
        )
    }

    private func activeCueGroupSelection(
        forSubtitleFile subtitleFile: URL,
        atMilliseconds milliseconds: Int
    ) throws -> CueGroupSelection? {
        try activeCueGroupSelection(
            for: .path(subtitleFile.mediaPath),
            atMilliseconds: milliseconds
        )
    }

    private func activeCueGroupSelection(
        for lookup: SubtitleFileLookup,
        atMilliseconds milliseconds: Int
    ) throws -> CueGroupSelection? {
        let statement = try database.prepare(
            """
            SELECT g.id, g.start_ms, g.end_ms, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE \(lookup.predicate)
              AND g.start_ms <= ?
              AND g.end_ms > ?
              AND g.end_ms > g.start_ms
            ORDER BY (g.end_ms - g.start_ms) ASC,
                     g.end_ms DESC, g.start_ms DESC, g.id ASC
            LIMIT 1;
            """
        )
        try lookup.bind(to: statement, at: 1)
        try statement.bind(milliseconds, at: 2)
        try statement.bind(milliseconds, at: 3)
        return try statement.step() ? cueGroupSelection(from: statement) : nil
    }

    private func previousCueGroupSelection(
        forSubtitleFile subtitleFile: URL,
        beforeOrAtMilliseconds milliseconds: Int
    ) throws -> CueGroupSelection? {
        let statement = try database.prepare(
            """
            SELECT g.id, g.start_ms, g.end_ms, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.end_ms <= ?
              AND g.end_ms > g.start_ms
            ORDER BY g.end_ms DESC, (g.end_ms - g.start_ms) ASC,
                     g.start_ms DESC, g.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitleFile.mediaPath, at: 1)
        try statement.bind(milliseconds, at: 2)
        return try statement.step() ? cueGroupSelection(from: statement) : nil
    }

    private func subtitleFocusPreviousCueLineID(
        forSubtitleFileID subtitleFileID: Int64,
        beforeOrAtMilliseconds milliseconds: Int
    ) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT l.id
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.id = ?
              AND g.start_ms <= ?
              AND g.end_ms > g.start_ms
            ORDER BY g.start_ms DESC, g.end_ms DESC, g.id DESC,
                     l.display_order DESC, l.event_index DESC, l.id DESC
            LIMIT 1;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(milliseconds, at: 2)
        return try statement.step() ? statement.int64Column(0) : nil
    }

    private func subtitleFocusFirstCueLineID(
        forSubtitleFileID subtitleFileID: Int64
    ) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT l.id
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.id = ?
              AND g.end_ms > g.start_ms
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                     l.display_order ASC, l.event_index ASC, l.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        return try statement.step() ? statement.int64Column(0) : nil
    }

    private func subtitleFocusOrdinalMetadata(
        forSubtitleFileID subtitleFileID: Int64,
        cueLineID: Int64
    ) throws -> (ordinal: Int, totalCount: Int)? {
        let statement = try database.prepare(
            """
            SELECT ordinal, total_count
            FROM (
                SELECT l.id AS cue_line_id,
                       ROW_NUMBER() OVER (
                           ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                                    l.display_order ASC, l.event_index ASC, l.id ASC
                       ) - 1 AS ordinal,
                       COUNT(*) OVER () AS total_count
                FROM subtitle_cue_lines l
                JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                WHERE sf.id = ?
                  AND g.end_ms > g.start_ms
            ) ordered
            WHERE cue_line_id = ?;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(cueLineID, at: 2)
        guard try statement.step() else {
            return nil
        }
        return (statement.intColumn(0), statement.intColumn(1))
    }

    private func cueGroupSelection(from statement: SQLiteStatement) -> CueGroupSelection {
        CueGroupSelection(
            cueGroupID: statement.int64Column(0),
            startMilliseconds: statement.intColumn(1),
            endMilliseconds: statement.intColumn(2),
            searchContent: statement.stringColumn(3)
        )
    }
}
