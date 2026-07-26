import Foundation

public final class CueContentDatabase: @unchecked Sendable {
    private struct Candidate {
        let subtitleFileID: Int64
        let subtitlePath: String
        let subtitleFormat: SubtitleFormat
        let videoPath: String
        let videoName: String
        let displayTitle: String
        let timeRange: String
        let lineCount: Int
    }

    private struct LanguageDetections {
        let fileLanguages: Set<SubtitleLanguageCode>?
        let styleLanguagesByName: [String: Set<SubtitleLanguageCode>]

        var hasAnyDetection: Bool {
            fileLanguages != nil || !styleLanguagesByName.isEmpty
        }
    }

    private let database: SQLiteDatabase

    public init(path: URL) throws {
        database = try SQLiteDatabase(path: path, access: .readOnly)
    }

    public func cueContents(forCueIDs cueIDs: [Int64]) throws -> [CueContent] {
        var seenCueIDs = Set<Int64>()
        let orderedCueIDs = cueIDs.filter { $0 > 0 && seenCueIDs.insert($0).inserted }
        guard !orderedCueIDs.isEmpty else { return [] }

        let cueRecordsByID = try cueLineRecords(forCueIDs: orderedCueIDs)
        guard orderedCueIDs.allSatisfy({ cueRecordsByID[$0] != nil }) else { return [] }
        let cueGroupIDs = Array(Set(cueRecordsByID.values.map(\.cueGroupID))).sorted()
        let candidatesByGroupID = try candidates(forCueGroupIDs: cueGroupIDs)
        guard cueGroupIDs.allSatisfy({ candidatesByGroupID[$0] != nil }) else { return [] }

        let groupRecordsByID = try cueLineRecords(forCueGroupIDs: cueGroupIDs)
        let languagesByGroupID = try cueGroupLanguages(forCueGroupIDs: cueGroupIDs)
        var detectionsByFileID: [Int64: LanguageDetections] = [:]
        var contents: [CueContent] = []
        contents.reserveCapacity(orderedCueIDs.count)

        for cueID in orderedCueIDs {
            guard let cueRecord = cueRecordsByID[cueID],
                  let candidate = candidatesByGroupID[cueRecord.cueGroupID]
            else { return [] }
            let groupRecords = groupRecordsByID[cueRecord.cueGroupID] ?? [cueRecord]
            let detections: LanguageDetections
            if let cached = detectionsByFileID[candidate.subtitleFileID] {
                detections = cached
            } else {
                let loaded = try languageDetections(forSubtitleFileID: candidate.subtitleFileID)
                detectionsByFileID[candidate.subtitleFileID] = loaded
                detections = loaded
            }
            contents.append(CueContent(
                cueID: cueID,
                cueGroupID: cueRecord.cueGroupID,
                cueEventIndex: cueRecord.line.eventIndex,
                cueDisplayOrder: cueRecord.line.displayOrder,
                primaryGroupIndex: groupRecords.firstIndex { $0.id == cueID } ?? 0,
                subtitlePath: candidate.subtitlePath,
                subtitleFormat: candidate.subtitleFormat,
                videoPath: candidate.videoPath,
                videoName: candidate.videoName,
                displayTitle: candidate.displayTitle,
                timeRange: candidate.timeRange,
                startMilliseconds: cueRecord.line.startMilliseconds,
                endMilliseconds: cueRecord.line.endMilliseconds,
                content: cueRecord.line.content,
                cueLines: [cueRecord.line.content],
                cueGroupLines: groupRecords.map(\.line.content),
                languages: Self.displayLanguages(
                    for: cueRecord.line,
                    candidate: candidate,
                    detections: detections,
                    cueGroupLanguages: languagesByGroupID[cueRecord.cueGroupID] ?? [.unknown]
                )
            ))
        }
        return contents
    }

    private func cueLineRecords(forCueIDs cueIDs: [Int64]) throws -> [Int64: SubtitleCueLineRecord] {
        let records = try cueLineRecords(whereColumn: "l.id", ids: cueIDs)
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    private func cueLineRecords(
        forCueGroupIDs cueGroupIDs: [Int64]
    ) throws -> [Int64: [SubtitleCueLineRecord]] {
        let records = try cueLineRecords(whereColumn: "l.cue_group_id", ids: cueGroupIDs)
        return Dictionary(grouping: records, by: \.cueGroupID)
    }

    private func cueLineRecords(
        whereColumn: String,
        ids: [Int64]
    ) throws -> [SubtitleCueLineRecord] {
        guard !ids.isEmpty else { return [] }
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order
            FROM subtitle_cue_lines l
            WHERE \(whereColumn) IN (\(placeholders))
            ORDER BY l.cue_group_id, l.display_order, l.event_index, l.id;
            """
        )
        for (offset, id) in ids.enumerated() {
            try statement.bind(id, at: Int32(offset + 1))
        }
        var records: [SubtitleCueLineRecord] = []
        while try statement.step() {
            records.append(SubtitleCueLineRecord(
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
            ))
        }
        return records
    }

    private func candidates(forCueGroupIDs ids: [Int64]) throws -> [Int64: Candidate] {
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT g.id, sf.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   sor.display_title, g.time_range, g.line_count
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            WHERE g.id IN (\(placeholders));
            """
        )
        for (offset, id) in ids.enumerated() {
            try statement.bind(id, at: Int32(offset + 1))
        }
        var result: [Int64: Candidate] = [:]
        while try statement.step() {
            result[statement.int64Column(0)] = Candidate(
                subtitleFileID: statement.int64Column(1),
                subtitlePath: statement.stringColumn(2),
                subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt,
                videoPath: statement.stringColumn(4),
                videoName: statement.stringColumn(5),
                displayTitle: statement.stringColumn(6),
                timeRange: statement.stringColumn(7),
                lineCount: statement.intColumn(8)
            )
        }
        return result
    }

    private func cueGroupLanguages(forCueGroupIDs ids: [Int64]) throws -> [Int64: Set<SubtitleLanguageCode>] {
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            "SELECT cue_group_id, language_code FROM subtitle_cue_group_languages WHERE cue_group_id IN (\(placeholders));"
        )
        for (offset, id) in ids.enumerated() { try statement.bind(id, at: Int32(offset + 1)) }
        var result: [Int64: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            if let language = SubtitleLanguageCode(rawValue: statement.stringColumn(1)) {
                result[statement.int64Column(0), default: []].insert(language)
            }
        }
        return result
    }

    private func languageDetections(forSubtitleFileID id: Int64) throws -> LanguageDetections {
        let statement = try database.prepare(
            """
            SELECT d.scope, d.scope_key, c.language_code
            FROM subtitle_language_detections d
            JOIN subtitle_language_detection_codes c ON c.detection_id = d.id
            WHERE d.subtitle_file_id = ?;
            """
        )
        try statement.bind(id, at: 1)
        var fileLanguages: Set<SubtitleLanguageCode>?
        var styles: [String: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(2)) else { continue }
            if SubtitleLanguageDetectionScope(rawValue: statement.stringColumn(0)) == .file {
                fileLanguages = (fileLanguages ?? []).union([language])
            } else {
                let style = statement.stringColumn(1)
                if !style.isEmpty { styles[style, default: []].insert(language) }
            }
        }
        return LanguageDetections(fileLanguages: fileLanguages, styleLanguagesByName: styles)
    }

    private static func displayLanguages(
        for line: SubtitleCueLine,
        candidate: Candidate,
        detections: LanguageDetections,
        cueGroupLanguages: Set<SubtitleLanguageCode>
    ) -> Set<SubtitleLanguageCode> {
        if detections.hasAnyDetection {
            switch line.sourceFormat {
            case .srt:
                return detections.fileLanguages ?? [.unknown]
            case .ass:
                guard let style = SubtitleLanguageAnalyzer.canonicalASSStyleName(line.sourceStyle) else {
                    return SubtitleLanguageAnalyzer.languageSegments(from: line.content).isEmpty ? [] : [.unknown]
                }
                return detections.styleLanguagesByName[style] ?? [.unknown]
            }
        }
        if candidate.subtitleFormat == .ass, candidate.lineCount > 1 {
            return SubtitleLanguageRecognizer(minimumEffectiveCharacterCount: 4)
                .detectLanguages(in: SubtitleLanguageAnalyzer.languageSegments(from: line.content))
                .languages
        }
        return cueGroupLanguages.isEmpty ? [.unknown] : cueGroupLanguages
    }
}
