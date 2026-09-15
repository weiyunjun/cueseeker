import Foundation

/// FTS rows carry a rowid that encodes the subtitle file and the cue group's
/// time position inside that file: `subtitleFileID << 24 | sequence`. Rows of
/// one file therefore form one contiguous rowid range in time order no matter
/// when the file was indexed, so Search can read hit rowids alone and order
/// them by file display rank without touching any other table.
enum SearchFTSRows {
    static let sequenceBits: Int64 = 24

    static func rowID(subtitleFileID: Int64, sequence: Int) -> Int64 {
        (subtitleFileID << sequenceBits) | Int64(sequence)
    }

    static func subtitleFileID(ofRowID rowID: Int64) -> Int64 {
        rowID >> sequenceBits
    }

    static func rowIDRange(forSubtitleFileID subtitleFileID: Int64) -> ClosedRange<Int64> {
        let lowerBound = rowID(subtitleFileID: subtitleFileID, sequence: 0)
        let upperBound = rowID(subtitleFileID: subtitleFileID, sequence: Int((1 << sequenceBits) - 1))
        return lowerBound...upperBound
    }

    /// One-based sequence for every cue group of a file, following the Search
    /// order inside a file: start time, end time, then original position.
    static func sequences(for cueGroups: [SubtitleCueGroup]) -> [Int] {
        let orderedIndices = cueGroups.indices.sorted { lhs, rhs in
            let left = cueGroups[lhs]
            let right = cueGroups[rhs]
            if left.startMilliseconds != right.startMilliseconds {
                return left.startMilliseconds < right.startMilliseconds
            }
            if left.endMilliseconds != right.endMilliseconds {
                return left.endMilliseconds < right.endMilliseconds
            }
            return lhs < rhs
        }
        var sequences = [Int](repeating: 0, count: cueGroups.count)
        for (sequence, index) in orderedIndices.enumerated() {
            sequences[index] = sequence + 1
        }
        return sequences
    }

    static func insert(
        on database: SQLiteDatabase,
        rowID: Int64,
        cueGroupID: Int64,
        content: String
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_groups_fts(rowid, content, cue_group_id)
            VALUES (?, ?, ?);
            """
        )
        try statement.bind(rowID, at: 1)
        try statement.bind(SearchQueryPlanner.segmentForFTS(content), at: 2)
        try statement.bind(cueGroupID, at: 3)
        try statement.run()
    }

    /// Rewrites every FTS row with the encoded rowid. Used once by the schema
    /// migration that introduces the encoding.
    static func rebuild(on database: SQLiteDatabase) throws {
        try database.execute("DELETE FROM subtitle_cue_groups_fts;")
        let statement = try database.prepare(
            """
            SELECT g.id, g.subtitle_file_id, g.search_content
            FROM subtitle_cue_groups g
            ORDER BY g.subtitle_file_id ASC, g.start_ms ASC, g.end_ms ASC, g.id ASC;
            """
        )
        var currentSubtitleFileID: Int64 = -1
        var sequence = 0
        while try statement.step() {
            let subtitleFileID = statement.int64Column(1)
            if subtitleFileID != currentSubtitleFileID {
                currentSubtitleFileID = subtitleFileID
                sequence = 0
            }
            sequence += 1
            try insert(
                on: database,
                rowID: rowID(subtitleFileID: subtitleFileID, sequence: sequence),
                cueGroupID: statement.int64Column(0),
                content: statement.stringColumn(2)
            )
        }
    }
}
