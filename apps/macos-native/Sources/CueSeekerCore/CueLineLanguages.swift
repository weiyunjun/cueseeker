import Foundation

/// The language of every cue line is settled when its file is indexed and
/// stored in `subtitle_cue_line_languages`; Search, cue content and the facet
/// counts all read that table and nothing derives a language at query time.
/// A line whose language cannot be settled is stored as `unknown`.
enum CueLineLanguages {
    struct Detections {
        let fileLanguages: Set<SubtitleLanguageCode>?
        let styleLanguagesByName: [String: Set<SubtitleLanguageCode>]

        var hasAnyDetection: Bool {
            fileLanguages != nil || !styleLanguagesByName.isEmpty
        }

        static let none = Detections(fileLanguages: nil, styleLanguagesByName: [:])
    }

    /// The detections a file's language analysis publishes: only detections
    /// that name at least one language count, which is also what the stored
    /// detection codes preserve.
    static func detections(from analysis: SubtitleLanguageAnalysis?) -> Detections {
        guard let analysis else {
            return .none
        }
        let fileLanguages = analysis.fileDetection.map(\.languages)
            .flatMap { $0.isEmpty ? nil : $0 }
        var styleLanguagesByName: [String: Set<SubtitleLanguageCode>] = [:]
        for (styleName, detection) in analysis.styleDetections where !detection.languages.isEmpty {
            styleLanguagesByName[styleName] = detection.languages
        }
        return Detections(fileLanguages: fileLanguages, styleLanguagesByName: styleLanguagesByName)
    }

    /// The single language rule: a detected file or style language when the
    /// file has detections, otherwise a fresh recognition for a multi-line ASS
    /// group, otherwise the cue group's languages, otherwise `unknown`.
    static func resolve(
        sourceFormat: SubtitleFormat,
        sourceStyle: String?,
        content: String,
        fileFormat: SubtitleFormat,
        groupLineCount: Int,
        detections: Detections,
        cueGroupLanguages: Set<SubtitleLanguageCode>
    ) -> Set<SubtitleLanguageCode> {
        let languages = unresolved(
            sourceFormat: sourceFormat,
            sourceStyle: sourceStyle,
            content: content,
            fileFormat: fileFormat,
            groupLineCount: groupLineCount,
            detections: detections,
            cueGroupLanguages: cueGroupLanguages
        )
        return languages.isEmpty ? [.unknown] : languages
    }

    private static func unresolved(
        sourceFormat: SubtitleFormat,
        sourceStyle: String?,
        content: String,
        fileFormat: SubtitleFormat,
        groupLineCount: Int,
        detections: Detections,
        cueGroupLanguages: Set<SubtitleLanguageCode>
    ) -> Set<SubtitleLanguageCode> {
        if detections.hasAnyDetection {
            switch sourceFormat {
            case .srt:
                return detections.fileLanguages ?? [.unknown]
            case .ass:
                guard let styleName = SubtitleLanguageAnalyzer.canonicalASSStyleName(sourceStyle) else {
                    return SubtitleLanguageAnalyzer.languageSegments(from: content).isEmpty ? [] : [.unknown]
                }
                return detections.styleLanguagesByName[styleName] ?? [.unknown]
            }
        }
        if fileFormat == .ass, groupLineCount > 1 {
            return SubtitleLanguageRecognizer(minimumEffectiveCharacterCount: 4)
                .detectLanguages(in: SubtitleLanguageAnalyzer.languageSegments(from: content))
                .languages
        }
        return cueGroupLanguages
    }

    static func insert(
        on database: SQLiteDatabase,
        cueID: Int64,
        languages: Set<SubtitleLanguageCode>
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_line_languages(cue_id, language_code)
            VALUES (?, ?);
            """
        )
        for language in languages.sorted(by: { $0.rawValue < $1.rawValue }) {
            try statement.reset()
            try statement.clearBindings()
            try statement.bind(cueID, at: 1)
            try statement.bind(language.rawValue, at: 2)
            try statement.run()
        }
    }

    static func languages(
        forCueIDs cueIDs: [Int64],
        on database: SQLiteDatabase
    ) throws -> [Int64: Set<SubtitleLanguageCode>] {
        guard !cueIDs.isEmpty else {
            return [:]
        }
        let placeholders = cueIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT cue_id, language_code
            FROM subtitle_cue_line_languages
            WHERE cue_id IN (\(placeholders));
            """
        )
        for (offset, cueID) in cueIDs.enumerated() {
            try statement.bind(cueID, at: Int32(offset + 1))
        }
        var languagesByCueID: [Int64: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(1)) else {
                continue
            }
            languagesByCueID[statement.int64Column(0), default: []].insert(language)
        }
        return languagesByCueID
    }

    /// Fills the table for every stored line from the stored detections and
    /// cue group languages. Used once by the schema migration that adds it.
    static func rebuild(on database: SQLiteDatabase) throws {
        try database.execute("DELETE FROM subtitle_cue_line_languages;")
        let files = try database.prepare("SELECT id, format FROM subtitle_files ORDER BY id ASC;")
        while try files.step() {
            let subtitleFileID = files.int64Column(0)
            let fileFormat = SubtitleFormat(rawValue: files.stringColumn(1)) ?? .srt
            let detections = try storedDetections(forSubtitleFileID: subtitleFileID, on: database)
            let cueGroupLanguages = try storedCueGroupLanguages(forSubtitleFileID: subtitleFileID, on: database)
            let lines = try database.prepare(
                """
                SELECT l.id, l.cue_group_id, l.source_format, l.source_style, l.content, g.line_count
                FROM subtitle_cue_lines l
                JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
                WHERE l.subtitle_file_id = ?;
                """
            )
            try lines.bind(subtitleFileID, at: 1)
            while try lines.step() {
                let languages = resolve(
                    sourceFormat: SubtitleFormat(rawValue: lines.stringColumn(2)) ?? fileFormat,
                    sourceStyle: lines.nullableStringColumn(3),
                    content: lines.stringColumn(4),
                    fileFormat: fileFormat,
                    groupLineCount: lines.intColumn(5),
                    detections: detections,
                    cueGroupLanguages: cueGroupLanguages[lines.int64Column(1)] ?? []
                )
                try insert(on: database, cueID: lines.int64Column(0), languages: languages)
            }
        }
    }

    private static func storedDetections(
        forSubtitleFileID subtitleFileID: Int64,
        on database: SQLiteDatabase
    ) throws -> Detections {
        let statement = try database.prepare(
            """
            SELECT d.scope, d.scope_key, c.language_code
            FROM subtitle_language_detections d
            JOIN subtitle_language_detection_codes c ON c.detection_id = d.id
            WHERE d.subtitle_file_id = ?;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        var fileLanguages: Set<SubtitleLanguageCode>?
        var styleLanguagesByName: [String: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(2)) else {
                continue
            }
            switch SubtitleLanguageDetectionScope(rawValue: statement.stringColumn(0)) {
            case .file:
                fileLanguages = (fileLanguages ?? []).union([language])
            case .style:
                let styleName = statement.stringColumn(1)
                if !styleName.isEmpty {
                    styleLanguagesByName[styleName, default: []].insert(language)
                }
            case nil:
                continue
            }
        }
        return Detections(fileLanguages: fileLanguages, styleLanguagesByName: styleLanguagesByName)
    }

    private static func storedCueGroupLanguages(
        forSubtitleFileID subtitleFileID: Int64,
        on database: SQLiteDatabase
    ) throws -> [Int64: Set<SubtitleLanguageCode>] {
        let statement = try database.prepare(
            """
            SELECT cgl.cue_group_id, cgl.language_code
            FROM subtitle_cue_group_languages cgl
            JOIN subtitle_cue_groups g ON g.id = cgl.cue_group_id
            WHERE g.subtitle_file_id = ?;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        var languagesByCueGroupID: [Int64: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(1)) else {
                continue
            }
            languagesByCueGroupID[statement.int64Column(0), default: []].insert(language)
        }
        return languagesByCueGroupID
    }
}
