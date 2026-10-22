import Foundation

extension SearchDatabase {
    public func ftsVocabularyDiagnostics(
        for query: String,
        topTermLimit: Int = 12
    ) throws -> SubtitleFTSVocabularyDiagnostics {
        try database.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS temp.subtitle_cue_groups_fts_vocab
            USING fts5vocab(main, subtitle_cue_groups_fts, 'row');
            """
        )

        let totals = try database.prepare(
            """
            SELECT COUNT(*), COALESCE(SUM(doc), 0), COALESCE(SUM(cnt), 0)
            FROM temp.subtitle_cue_groups_fts_vocab;
            """
        )
        _ = try totals.step()
        let uniqueTermCount = totals.intColumn(0)
        let totalDocumentReferences = totals.intColumn(1)
        let totalOccurrences = totals.intColumn(2)

        let topTerms = try ftsVocabularyTerms(
            matching: nil,
            limit: max(0, topTermLimit)
        )
        let queryTerms = try SearchQueryPlanner.vocabularyTerms(in: query).map { term in
            try ftsVocabularyTerm(term)
        }

        return SubtitleFTSVocabularyDiagnostics(
            uniqueTermCount: uniqueTermCount,
            totalDocumentReferences: totalDocumentReferences,
            totalOccurrences: totalOccurrences,
            mostFrequentTerms: topTerms,
            queryTerms: queryTerms
        )
    }

    private func ftsVocabularyTerms(
        matching term: String?,
        limit: Int
    ) throws -> [SubtitleFTSVocabularyTermDiagnostic] {
        guard limit > 0 else {
            return []
        }

        let statement: SQLiteStatement
        if let term {
            statement = try database.prepare(
                """
                SELECT term, doc, cnt
                FROM temp.subtitle_cue_groups_fts_vocab
                WHERE term = ?
                LIMIT ?;
                """
            )
            try statement.bind(term, at: 1)
            try statement.bind(limit, at: 2)
        } else {
            statement = try database.prepare(
                """
                SELECT term, doc, cnt
                FROM temp.subtitle_cue_groups_fts_vocab
                ORDER BY cnt DESC, doc DESC, term ASC
                LIMIT ?;
                """
            )
            try statement.bind(limit, at: 1)
        }

        var terms: [SubtitleFTSVocabularyTermDiagnostic] = []
        while try statement.step() {
            terms.append(
                SubtitleFTSVocabularyTermDiagnostic(
                    term: statement.stringColumn(0),
                    documentCount: statement.intColumn(1),
                    occurrenceCount: statement.intColumn(2)
                )
            )
        }
        return terms
    }

    private func ftsVocabularyTerm(_ term: String) throws -> SubtitleFTSVocabularyTermDiagnostic {
        try ftsVocabularyTerms(matching: term, limit: 1).first
            ?? SubtitleFTSVocabularyTermDiagnostic(
                term: term,
                documentCount: 0,
                occurrenceCount: 0
            )
    }
}
