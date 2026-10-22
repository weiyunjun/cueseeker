import Foundation
@testable import CueSeekerCore

extension IndexingDatabase {
    public func languageDetections(
        forSubtitleFile subtitleFile: URL
    ) throws -> [StoredSubtitleLanguageDetection] {
        let statement = try database.prepare(
            """
            SELECT d.id, sf.subtitle_path, d.scope, d.scope_key, d.algorithm_version,
                   d.confidence, d.confidence_band, d.segment_count,
                   d.effective_character_count, d.detected_at
            FROM subtitle_language_detections d
            JOIN subtitle_files sf ON sf.id = d.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY d.scope ASC, d.scope_key ASC, d.id ASC;
            """
        )
        try statement.bind(subtitleFile.mediaPath, at: 1)

        var records: [StoredSubtitleLanguageDetection] = []
        while try statement.step() {
            let detectionID = statement.int64Column(0)
            records.append(
                StoredSubtitleLanguageDetection(
                    subtitlePath: statement.stringColumn(1),
                    scope: SubtitleLanguageDetectionScope(rawValue: statement.stringColumn(2)) ?? .file,
                    scopeKey: statement.stringColumn(3).isEmpty ? nil : statement.stringColumn(3),
                    algorithmVersion: statement.intColumn(4),
                    confidence: statement.nullableDoubleColumn(5) ?? 0,
                    confidenceBand: SubtitleLanguageConfidenceBand(rawValue: statement.stringColumn(6)) ?? .none,
                    segmentCount: statement.intColumn(7),
                    effectiveCharacterCount: statement.intColumn(8),
                    languages: try subtitleLanguageDetectionCodes(detectionID: detectionID),
                    distribution: try subtitleLanguageDetectionDistribution(detectionID: detectionID),
                    detectedAt: statement.stringColumn(9)
                )
            )
        }

        return records
    }

    public func cueGroupLanguages(
        forSubtitleFile subtitleFile: URL
    ) throws -> [Int64: Set<SubtitleLanguageCode>] {
        let statement = try database.prepare(
            """
            SELECT g.id, cgl.language_code
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_cue_group_languages cgl ON cgl.cue_group_id = g.id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC, cgl.language_code ASC;
            """
        )
        try statement.bind(subtitleFile.mediaPath, at: 1)

        var languagesByCueGroupID: [Int64: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(1)) else {
                continue
            }
            languagesByCueGroupID[statement.int64Column(0), default: []].insert(language)
        }

        return languagesByCueGroupID
    }

    public func cueGroupLanguages(
        forSubtitlePath subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Set<SubtitleLanguageCode> {
        let statement = try database.prepare(
            """
            SELECT cgl.language_code
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_cue_group_languages cgl ON cgl.cue_group_id = g.id
            WHERE sf.subtitle_path = ?
              AND g.start_ms = ?
              AND g.end_ms = ?
            ORDER BY cgl.language_code ASC;
            """
        )
        try statement.bind(subtitlePath, at: 1)
        try statement.bind(startMilliseconds, at: 2)
        try statement.bind(endMilliseconds, at: 3)

        var languages = Set<SubtitleLanguageCode>()
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) else {
                continue
            }
            languages.insert(language)
        }

        return languages.isEmpty ? [.unknown] : languages
    }

    public func cueGroupID(
        forSubtitlePath subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT g.id
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.start_ms = ?
              AND g.end_ms = ?
            ORDER BY g.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitlePath, at: 1)
        try statement.bind(startMilliseconds, at: 2)
        try statement.bind(endMilliseconds, at: 3)

        guard try statement.step() else {
            return nil
        }

        return statement.int64Column(0)
    }

    private func subtitleLanguageDetectionCodes(
        detectionID: Int64
    ) throws -> Set<SubtitleLanguageCode> {
        let statement = try database.prepare(
            """
            SELECT language_code
            FROM subtitle_language_detection_codes
            WHERE detection_id = ?
            ORDER BY language_code ASC;
            """
        )
        try statement.bind(detectionID, at: 1)

        var languages = Set<SubtitleLanguageCode>()
        while try statement.step() {
            if let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) {
                languages.insert(language)
            }
        }

        return languages.isEmpty ? [.unknown] : languages
    }

    private func subtitleLanguageDetectionDistribution(
        detectionID: Int64
    ) throws -> [SubtitleLanguageDistribution] {
        let statement = try database.prepare(
            """
            SELECT language_code, share
            FROM subtitle_language_detection_distribution
            WHERE detection_id = ?
            ORDER BY rank ASC, language_code ASC;
            """
        )
        try statement.bind(detectionID, at: 1)

        var distribution: [SubtitleLanguageDistribution] = []
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) else {
                continue
            }
            distribution.append(
                SubtitleLanguageDistribution(
                    language: language,
                    share: statement.nullableDoubleColumn(1) ?? 0
                )
            )
        }

        return distribution
    }

    func cueLines(forCueGroupID cueGroupID: Int64) throws -> [SubtitleCueLine] {
        let statement = try database.prepare(
            """
            SELECT event_index, source_format, source_style, source_layer,
                   source_identity_remainder, start_time, end_time,
                   start_ms, end_ms, duration_ms, character_width, content,
                   display_x, display_y, display_order
            FROM subtitle_cue_lines
            WHERE cue_group_id = ?
            ORDER BY display_order ASC, event_index ASC, id ASC;
            """
        )

        try statement.bind(cueGroupID, at: 1)

        var lines: [SubtitleCueLine] = []
        while try statement.step() {
            lines.append(
                SubtitleCueLine(
                    eventIndex: statement.intColumn(0),
                    sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(1)) ?? .srt,
                    sourceStyle: statement.nullableStringColumn(2),
                    sourceLayer: statement.nullableIntColumn(3),
                    sourceIdentityRemainder: statement.stringColumn(4),
                    startTimecode: statement.stringColumn(5),
                    endTimecode: statement.stringColumn(6),
                    startMilliseconds: statement.intColumn(7),
                    endMilliseconds: statement.intColumn(8),
                    durationMilliseconds: statement.intColumn(9),
                    characterWidth: statement.intColumn(10),
                    content: statement.stringColumn(11),
                    displayX: statement.nullableDoubleColumn(12),
                    displayY: statement.nullableDoubleColumn(13),
                    displayOrder: statement.intColumn(14)
                )
            )
        }

        return lines
    }


    func cueLines(forCueGroupIDs cueGroupIDs: [Int64]) throws -> [Int64: [SubtitleCueLine]] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT cue_group_id, event_index, source_format, source_style, source_layer,
                   source_identity_remainder, start_time, end_time,
                   start_ms, end_ms, duration_ms, character_width, content,
                   display_x, display_y, display_order
            FROM subtitle_cue_lines
            WHERE cue_group_id IN (\(placeholders))
            ORDER BY cue_group_id ASC, display_order ASC, event_index ASC, id ASC;
            """
        )

        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var linesByCueGroupID: [Int64: [SubtitleCueLine]] = [:]
        linesByCueGroupID.reserveCapacity(cueGroupIDs.count)
        while try statement.step() {
            let cueGroupID = statement.int64Column(0)
            let line = SubtitleCueLine(
                eventIndex: statement.intColumn(1),
                sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
                sourceStyle: statement.nullableStringColumn(3),
                sourceLayer: statement.nullableIntColumn(4),
                sourceIdentityRemainder: statement.stringColumn(5),
                startTimecode: statement.stringColumn(6),
                endTimecode: statement.stringColumn(7),
                startMilliseconds: statement.intColumn(8),
                endMilliseconds: statement.intColumn(9),
                durationMilliseconds: statement.intColumn(10),
                characterWidth: statement.intColumn(11),
                content: statement.stringColumn(12),
                displayX: statement.nullableDoubleColumn(13),
                displayY: statement.nullableDoubleColumn(14),
                displayOrder: statement.intColumn(15)
            )
            linesByCueGroupID[cueGroupID, default: []].append(line)
        }

        return linesByCueGroupID
    }

    func indexedSubtitlePaths() throws -> [String] {
        let statement = try database.prepare(
            """
            SELECT subtitle_path
            FROM subtitle_files
            ORDER BY subtitle_path ASC;
            """
        )

        var paths: [String] = []
        while try statement.step() {
            paths.append(statement.stringColumn(0))
        }
        return paths
    }
}
