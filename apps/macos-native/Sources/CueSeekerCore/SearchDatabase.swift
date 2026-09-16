import Foundation

public final class SearchDatabase: @unchecked Sendable {
    private static let exactSearchCandidateBatchMinimum = 5_000

    let path: URL
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readOnly
    ) throws {
        self.path = path
        database = try SQLiteDatabase(path: path, access: access)
    }

    public func cueFacetDistribution() throws -> CueFacetDistribution {
        try CueFacetCountCache.load(from: database)
    }

    public func cueOccurrenceCount(
        for query: String,
        under folders: [URL]? = nil
    ) throws -> Int {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return 0
        }

        return try searchPage(
            trimmedQuery,
            limit: 1,
            cursor: .start,
            under: folders,
            mode: .exact
        ).totalCount
    }

    public func cueGroupOccurrenceCount(
        for query: String,
        under folders: [URL]? = nil
    ) throws -> Int {
        try cueOccurrenceCount(for: query, under: folders)
    }

    private static func cueTimeRange(startMilliseconds: Int, endMilliseconds: Int) -> String {
        SubtitleCueTimeRangeDisplay.text(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
    }

    private func bindPathPrefixes(
        _ pathPrefixes: [String]?,
        to statement: SQLiteStatement,
        startingAt startIndex: Int32
    ) throws -> Int32 {
        var bindIndex = startIndex
        if let pathPrefixes {
            for prefix in pathPrefixes {
                try statement.bind(prefix, at: bindIndex)
                bindIndex += 1
                try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                bindIndex += 1
            }
        }
        return bindIndex
    }

    public func search(
        _ query: String,
        limit: Int = 50,
        offset: Int = 0,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        watchStateFilter: SubtitleSearchWatchStateFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        facetFilter: CueFacetFilter = CueFacetFilter()
    ) throws -> [SubtitleSearchResult] {
        try searchPage(
            query,
            limit: limit,
            offset: offset,
            under: folders,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter,
            watchStateFilter: watchStateFilter,
            filterSet: filterSet,
            facetFilter: facetFilter
        ).results
    }

    public func searchPage(
        _ query: String,
        limit: Int = 50,
        offset: Int = 0,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        watchStateFilter: SubtitleSearchWatchStateFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        facetFilter: CueFacetFilter = CueFacetFilter(),
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil,
        mode: SubtitleSearchPageMode = .exact
    ) throws -> SubtitleSearchPage {
        try searchPage(
            query,
            limit: limit,
            cursor: SubtitleSearchCursor(offset: offset),
            under: folders,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter,
            watchStateFilter: watchStateFilter,
            filterSet: filterSet,
            facetFilter: facetFilter,
            diagnostics: diagnostics,
            progress: progress,
            mode: mode
        )
    }

    public func searchVisiblePage(
        _ query: String,
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        watchStateFilter: SubtitleSearchWatchStateFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        facetFilter: CueFacetFilter = CueFacetFilter(),
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil
    ) throws -> SubtitleSearchPage {
        try searchPage(
            query,
            limit: limit,
            cursor: cursor,
            under: folders,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter,
            watchStateFilter: watchStateFilter,
            filterSet: filterSet,
            facetFilter: facetFilter,
            diagnostics: diagnostics,
            progress: progress,
            mode: .visibleWindow
        )
    }

    public func allCuesVisiblePage(
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet()
    ) throws -> SubtitleSearchPage {
        try Task.checkCancellation()
        let appliedCursor = cursor ?? .start
        let requestedLimit = max(0, limit)
        let offset = appliedCursor.offset

        let pathPrefixes: [String]?
        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                return SubtitleSearchPage(
                    results: [],
                    totalCount: 0,
                    fileSummaries: [],
                    countSnapshot: .exact(totalCount: 0, fileSummaryCount: 0),
                    appliedCursor: appliedCursor,
                    pageMode: .visibleWindow
                )
            }
            pathPrefixes = prefixes
        } else {
            pathPrefixes = nil
        }

        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "WHERE (\(conditions))"
        } ?? ""

        try requireCompleteSearchOrderRows(
            pathPrefixes: pathPrefixes,
            subtitlePath: nil
        )

        let statement = try database.prepare(
            """
            SELECT g.id, sf.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.start_ms, g.end_ms, g.time_range, g.search_content, g.line_count,
                   sor.subtitle_file_name, sor.display_title, sor.folder_order, sor.file_order,
                   l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order,
                   (
                       SELECT GROUP_CONCAT(cll.language_code)
                       FROM subtitle_cue_line_languages cll
                       WHERE cll.cue_id = l.id
                   ) AS language_values
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            JOIN subtitle_cue_lines l ON l.cue_group_id = g.id
            \(scopeCondition)
            ORDER BY sor.display_title COLLATE NOCASE ASC,
                     sf.subtitle_path COLLATE NOCASE ASC,
                     g.start_ms ASC, g.end_ms ASC, g.id ASC,
                     l.display_order ASC, l.event_index ASC, l.id ASC
            """
        )
        _ = try bindPathPrefixes(pathPrefixes, to: statement, startingAt: 1)

        var accepted: [AllCuePageCandidate] = []
        var fileSummaryAccumulator = SearchFileSummaryAccumulator()
        var acceptedCount = 0
        while try statement.step() {
            try Task.checkCancellation()
            let candidate = searchCandidate(from: statement)
            let cueLineRecord = cueLineRecord(from: statement, startingAt: 15)
            let displayLanguages = Self.languageValues(
                from: statement.nullableStringColumn(29)
            )
            guard filterSet.isEffectivelyEmpty || filterSet.matches(
                display: candidate.order.displayTitle,
                cues: cueLineRecord.line.content,
                languages: Self.filterSetLanguageValues(displayLanguages)
            ) else {
                continue
            }

            fileSummaryAccumulator.add(candidate: candidate)
            if acceptedCount >= offset && accepted.count < requestedLimit {
                accepted.append(
                    AllCuePageCandidate(
                        candidate: candidate,
                        cueLineRecord: cueLineRecord,
                        displayLanguages: displayLanguages
                    )
                )
            }
            acceptedCount += 1
        }

        let totalCount = acceptedCount
        let fileSummaries = fileSummaryAccumulator.fileSummaries()
        let acceptedCueGroupIDs = Array(Set(accepted.map { $0.candidate.cueGroupID })).sorted()
        let groupRecordsByID = try cueLineRecords(forCueGroupIDs: acceptedCueGroupIDs)
        var results: [SubtitleSearchResult] = []
        results.reserveCapacity(accepted.count)
        for (index, item) in accepted.enumerated() {
            try Task.checkCancellation()
            let groupRecords = groupRecordsByID[item.candidate.cueGroupID] ?? [item.cueLineRecord]
            var result = orderedSearchResult(
                for: item.candidate,
                match: SearchResultMatch(
                    cueLineRecord: item.cueLineRecord,
                    primaryGroupIndex: groupRecords.firstIndex {
                        $0.id == item.cueLineRecord.id
                    } ?? 0,
                    cueGroupLines: groupRecords.map(\.line.content),
                    displayLanguages: item.displayLanguages
                )
            ).result
            result.searchRank = offset + index
            results.append(result)
        }
        let upperBound = min(totalCount, offset + results.count)

        return SubtitleSearchPage(
            results: results,
            totalCount: totalCount,
            fileSummaries: fileSummaries,
            countSnapshot: .exact(totalCount: totalCount, fileSummaryCount: fileSummaries.count),
            appliedCursor: appliedCursor,
            nextCursor: upperBound < totalCount ? SubtitleSearchCursor(offset: upperBound) : nil,
            pageMode: .visibleWindow,
            orderSource: "defaultCueOrder",
            materializedOrderRows: results.count
        )
    }

    /// Reads a `searchCandidateColumnsSQL` row, whose column 15 is the watch state.
    private func searchCandidateWithWatchState(from statement: SQLiteStatement) -> SearchCandidate {
        var candidate = searchCandidate(from: statement)
        candidate.watchState = LibraryWatchState(rawValue: statement.stringColumn(15)) ?? .unwatched
        return candidate
    }

    private func searchCandidate(from statement: SQLiteStatement) -> SearchCandidate {
        SearchCandidate(
            cueGroupID: statement.int64Column(0),
            subtitleFileID: statement.int64Column(1),
            subtitlePath: statement.stringColumn(2),
            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt,
            videoPath: statement.stringColumn(4),
            videoName: statement.stringColumn(5),
            startMilliseconds: statement.intColumn(6),
            endMilliseconds: statement.intColumn(7),
            timeRange: statement.stringColumn(8),
            searchContent: statement.stringColumn(9),
            lineCount: statement.intColumn(10),
            order: SearchResultOrder(
                subtitleFileName: statement.stringColumn(11),
                displayTitle: statement.stringColumn(12),
                folderOrder: statement.intColumn(13),
                fileOrder: statement.intColumn(14)
            )
        )
    }


    public func searchIndexedVisiblePage(
        from indexWindow: SubtitleSearchResultIDIndexWindow
    ) throws -> SubtitleSearchPage? {
        guard !indexWindow.cueIDs.isEmpty else {
            return SubtitleSearchPage(
                results: [],
                totalCount: indexWindow.totalCount,
                fileSummaries: indexWindow.fileSummaries,
                countSnapshot: indexWindow.countSnapshot,
                appliedCursor: indexWindow.appliedCursor,
                nextCursor: indexWindow.nextCursor,
                pageMode: .visibleWindow,
                orderSource: "resultIDIndex",
                materializedOrderRows: 0
            )
        }

        try Task.checkCancellation()
        let cueRecordsByID = try cueLineRecords(forCueIDs: indexWindow.cueIDs)
        try Task.checkCancellation()
        guard indexWindow.cueIDs.allSatisfy({ cueRecordsByID[$0] != nil }) else {
            return nil
        }

        var cueGroupIDs: [Int64] = []
        var seenCueGroupIDs = Set<Int64>()
        for cueID in indexWindow.cueIDs {
            guard let cueGroupID = cueRecordsByID[cueID]?.cueGroupID,
                  seenCueGroupIDs.insert(cueGroupID).inserted
            else {
                continue
            }
            cueGroupIDs.append(cueGroupID)
        }
        let candidatesByCueGroupID = try searchCandidates(forCueGroupIDs: cueGroupIDs)
        guard cueGroupIDs.allSatisfy({ candidatesByCueGroupID[$0] != nil }) else {
            return nil
        }
        let cueRecordsByCueGroupID = try cueLineRecords(forCueGroupIDs: cueGroupIDs)
        let languagesByCueID = try CueLineLanguages.languages(forCueIDs: indexWindow.cueIDs, on: database)
        try Task.checkCancellation()

        var results: [SubtitleSearchResult] = []
        results.reserveCapacity(indexWindow.cueIDs.count)
        for (index, cueID) in indexWindow.cueIDs.enumerated() {
            try Task.checkCancellation()
            guard let cueRecord = cueRecordsByID[cueID],
                  let candidate = candidatesByCueGroupID[cueRecord.cueGroupID]
            else {
                return nil
            }
            let groupRecords = cueRecordsByCueGroupID[cueRecord.cueGroupID] ?? [cueRecord]
            let languages = languagesByCueID[cueID] ?? [.unknown]
            var result = orderedSearchResult(
                for: candidate,
                match: SearchResultMatch(
                    cueLineRecord: cueRecord,
                    primaryGroupIndex: groupRecords.firstIndex { $0.id == cueID } ?? 0,
                    cueGroupLines: groupRecords.map(\.line.content),
                    displayLanguages: languages
                )
            ).result
            result.searchRank = indexWindow.offset + index
            results.append(result)
        }

        return SubtitleSearchPage(
            results: results,
            totalCount: indexWindow.totalCount,
            fileSummaries: indexWindow.fileSummaries,
            countSnapshot: indexWindow.countSnapshot,
            appliedCursor: indexWindow.appliedCursor,
            nextCursor: indexWindow.nextCursor,
            pageMode: .visibleWindow,
            orderSource: "resultIDIndex",
            materializedOrderRows: results.count
        )
    }


    public func cuePlaybackResult(cueID: Int64) throws -> SubtitleSearchResult? {
        guard cueID > 0 else {
            return nil
        }
        return try CueContentDatabase(path: path).cueContents(forCueIDs: [cueID]).first.map {
            SubtitleSearchResult(cueContent: $0)
        }
    }

    public func searchPage(
        _ query: String,
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        watchStateFilter: SubtitleSearchWatchStateFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        facetFilter: CueFacetFilter = CueFacetFilter(),
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil,
        mode: SubtitleSearchPageMode = .exact
    ) throws -> SubtitleSearchPage {
        try Task.checkCancellation()
        let searchPageStart = Self.diagnosticNow()
        let appliedCursor = cursor ?? .start

        func emit(
            _ name: String,
            since start: UInt64,
            fields: [SubtitleSearchDiagnosticField] = []
        ) {
            diagnostics?(
                SubtitleSearchDiagnosticEvent(
                    name: name,
                    phaseMilliseconds: Self.diagnosticMilliseconds(between: start, and: Self.diagnosticNow()),
                    fields: fields
                )
            )
        }

        let planStart = Self.diagnosticNow()
        guard let plan = SearchQueryPlanner.plan(for: query) else {
            emit("query_plan_empty", since: planStart)
            return SubtitleSearchPage(
                results: [],
                totalCount: 0,
                fileSummaries: [],
                appliedCursor: appliedCursor,
                pageMode: mode,
                facetSnapshot: .empty
            )
        }
        emit(
            "query_plan",
            since: planStart,
            fields: [
                .init("ftsQueryLength", plan.ftsQuery.count),
                .init("lineRule", SearchQueryPlanner.matchRuleName(plan.lineMatchRule))
            ]
        )

        let scopeStart = Self.diagnosticNow()
        let offset = appliedCursor.offset
        let subtitlePathFilter = subtitlePath
        if let subtitlePathFilter, subtitlePathFilter.isEmpty {
            emit("scope_empty_subtitle_path", since: scopeStart)
            return SubtitleSearchPage(
                results: [],
                totalCount: 0,
                fileSummaries: [],
                appliedCursor: appliedCursor,
                pageMode: mode,
                facetSnapshot: .empty
            )
        }

        let pathPrefixes: [String]?
        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                emit("scope_empty_folders", since: scopeStart)
                return SubtitleSearchPage(
                    results: [],
                    totalCount: 0,
                    fileSummaries: [],
                    appliedCursor: appliedCursor,
                    pageMode: mode,
                    facetSnapshot: .empty
                )
            }
            pathPrefixes = prefixes
        } else {
            pathPrefixes = nil
        }
        emit(
            "scope_resolved",
            since: scopeStart,
            fields: [
                .init("cursorOffset", appliedCursor.offset),
                .init("pathPrefixes", pathPrefixes?.count ?? 0),
                .init("hasSubtitlePathFilter", subtitlePathFilter == nil ? "false" : "true"),
                .init("languageFilter", languageFilter.rawValue),
                .init("watchStateFilter", watchStateFilter.rawValue),
                .init("hasFilterSet", filterSet.isEffectivelyEmpty ? "false" : "true")
            ]
        )

        do {
            let setupStart = Self.diagnosticNow()
            let candidateBatchLimit = Self.searchCandidateBatchLimit(for: limit, mode: mode)
            // The first batch is no larger than a visible window's, so an exact
            // scan reaches its first page as early as a visible window does.
            let firstCandidateBatchLimit = Self.searchCandidateBatchLimit(for: limit, mode: .visibleWindow)
            // The checked filter does not narrow the row reads: every match of the
            // query goes into the page's facet snapshot, so it counts every option,
            // and only the matches inside the selection become results.
            var acceptedCueIDs: [Int64] = []
            var acceptedDurationFacets: [CueDurationFacet] = []
            var acceptedCharacterFacets: [CueCharacterFacet] = []
            var acceptedLanguageFacets: [Set<SubtitleLanguageCode>] = []
            var acceptedWatchStateFacets: [LibraryWatchState] = []
            var acceptedFolderFacets: [String] = []
            // Only while the selected folders are read first: each match's
            // file rank, and how many matches the first run holds.
            var acceptedFileRanks: [Int] = []
            var acceptedFirstRunCount = 0
            var resultCueIDs: [Int64] = []
            var exactPageResults: [OrderedSearchResult] = []
            var pendingProgressResults: [OrderedSearchResult] = []
            var publishedProgressResultCount = 0
            var visiblePrefixResults: [OrderedSearchResult] = []
            var visibleWindowResults: [OrderedSearchResult] = []
            var progressFileSummaries = SearchFileSummaryAccumulator()
            var acceptedSearchResultCount = 0
            var reachedVisibleLookahead = false
            var batchIndex = 0
            var totalCandidates = 0
            var totalMultiLineCandidates = 0
            var totalCueLineRows = 0
            func rankedResults(
                from orderedResults: [OrderedSearchResult],
                startingAt startIndex: Int = 0
            ) -> [SubtitleSearchResult] {
                var results = orderedResults.map(\.result)
                for index in results.indices {
                    results[index].searchRank = startIndex + index
                }
                return results
            }
            func facetSnapshot() -> CueFacetSnapshot {
                guard !acceptedFileRanks.isEmpty else {
                    return CueFacetSnapshot(
                        cueIDs: acceptedCueIDs,
                        durationFacets: acceptedDurationFacets,
                        characterFacets: acceptedCharacterFacets,
                        languageFacets: acceptedLanguageFacets,
                        watchStateFacets: acceptedWatchStateFacets,
                        folderFacets: acceptedFolderFacets
                    )
                }
                let order = Self.displayOrder(
                    fileRanks: acceptedFileRanks,
                    firstRunCount: acceptedFirstRunCount
                )
                return CueFacetSnapshot(
                    cueIDs: order.map { acceptedCueIDs[$0] },
                    durationFacets: order.map { acceptedDurationFacets[$0] },
                    characterFacets: order.map { acceptedCharacterFacets[$0] },
                    languageFacets: order.map { acceptedLanguageFacets[$0] },
                    watchStateFacets: order.map { acceptedWatchStateFacets[$0] },
                    folderFacets: order.map { acceptedFolderFacets[$0] }
                )
            }
            let languageFilterCodes = Self.languageCodesForSearchFilter(languageFilter)
            let languageFilterCodeSet = Set(languageFilterCodes)
            let watchStateValues = watchStateFilter.states.map(\.rawValue)
            emit(
                "setup",
                since: setupStart,
                fields: [
                    .init("candidateBatchLimit", candidateBatchLimit),
                    .init("scopeCondition", pathPrefixes == nil ? "none" : "path"),
                    .init("subtitlePathFilter", subtitlePathFilter == nil ? "false" : "true"),
                    .init("languageFilter", languageFilter.rawValue),
                    .init("watchStateFilter", watchStateFilter.rawValue),
                    .init("hasFilterSet", filterSet.isEffectivelyEmpty ? "false" : "true"),
                    .init("metadataMode", mode.rawValue)
                ]
            )

            let searchOrderRowsStart = Self.diagnosticNow()
            try Task.checkCancellation()
            try requireCompleteSearchOrderRows(
                pathPrefixes: pathPrefixes,
                subtitlePath: subtitlePathFilter
            )
            emit("search_order_rows_validated", since: searchOrderRowsStart)

            let fileRanksStart = Self.diagnosticNow()
            // With a Folder selection the selected folders' files are read
            // first, so the first page does not wait behind folders that give
            // no result; the snapshot goes back to display order at the end.
            let fileOrder = try searchFileRanks(
                pathPrefixes: pathPrefixes,
                subtitlePath: subtitlePathFilter,
                excludedFolders: facetFilter.excludedFolders
            )
            let fileRanks = fileOrder.ranks
            let firstFileIDs = fileOrder.firstFileIDs
            emit("file_ranks", since: fileRanksStart, fields: [.init("files", fileRanks.count)])

            let hitsStart = Self.diagnosticNow()
            let orderedHitRowIDs = try orderedFTSHitRowIDs(
                matching: plan.ftsQuery,
                fileRanks: fileRanks,
                firstFileIDs: firstFileIDs
            )
            emit("fts_hits", since: hitsStart, fields: [.init("hits", orderedHitRowIDs.count)])

            var nextHitIndex = 0
            while nextHitIndex < orderedHitRowIDs.count {
                try Task.checkCancellation()
                batchIndex += 1
                let queryStart = Self.diagnosticNow()
                let batchLimit = batchIndex == 1 ? firstCandidateBatchLimit : candidateBatchLimit
                let chunkEnd = min(nextHitIndex + batchLimit, orderedHitRowIDs.count)
                let chunkRowIDs = Array(orderedHitRowIDs[nextHitIndex..<chunkEnd])
                let candidateOffset = nextHitIndex
                nextHitIndex = chunkEnd
                let candidates = try searchCandidates(
                    forFTSRowIDs: chunkRowIDs,
                    watchStateValues: watchStateValues
                )
                emit(
                    "fts_batch",
                    since: queryStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("candidateOffset", candidateOffset),
                        .init("candidateBatchLimit", batchLimit),
                        .init("candidates", candidates.count)
                    ]
                )
                let isLastCandidateBatch = nextHitIndex >= orderedHitRowIDs.count

                guard !candidates.isEmpty else {
                    if isLastCandidateBatch {
                        break
                    }
                    continue
                }

                totalCandidates += candidates.count

                let candidateCueGroupIDs = candidates.map(\.cueGroupID)
                let multiLineCueGroupIDs = candidates
                    .filter { $0.lineCount > 1 }
                    .map(\.cueGroupID)
                totalMultiLineCandidates += multiLineCueGroupIDs.count
                let cueLinesStart = Self.diagnosticNow()
                let languageLineIDsByCueGroupID = languageFilterCodeSet.isEmpty
                    ? nil
                    : try languageMatchingLineIDs(
                        forCueGroupIDs: candidateCueGroupIDs,
                        requiredLanguages: languageFilterCodeSet
                    )
                let lineCueGroupIDs = languageLineIDsByCueGroupID.map { Array($0.keys) }
                    ?? candidateCueGroupIDs
                let cueLineRecordsByCueGroupID = try cueLineRecords(
                    forCueGroupIDs: lineCueGroupIDs
                )
                let cueLineRows = cueLineRecordsByCueGroupID.values.reduce(0) { $0 + $1.count }
                totalCueLineRows += cueLineRows
                let languagesByCueID = try CueLineLanguages.languages(
                    forCueIDs: cueLineRecordsByCueGroupID.values.flatMap { $0.map(\.id) },
                    on: database
                )
                emit(
                    "cue_lines",
                    since: cueLinesStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("multiLineCandidates", multiLineCueGroupIDs.count),
                        .init("lineCueGroups", lineCueGroupIDs.count),
                        .init("cueLineRows", cueLineRows)
                    ]
                )

                let validationStart = Self.diagnosticNow()
                let acceptedBefore = acceptedSearchResultCount
                var matchedCandidateCount = 0
                for candidate in candidates {
                    try Task.checkCancellation()
                    let orderedMatches = searchResults(
                        for: candidate,
                        cueLineRecords: cueLineRecordsByCueGroupID[candidate.cueGroupID] ?? [],
                        matching: plan,
                        languageFilterCodes: languageFilterCodeSet,
                        languagesByCueID: languagesByCueID,
                        filterSet: filterSet,
                        allowedLineIDs: languageLineIDsByCueGroupID?[candidate.cueGroupID]
                    )
                    if !orderedMatches.isEmpty {
                        matchedCandidateCount += 1
                    }
                    let isFirstFile = firstFileIDs?.contains(candidate.subtitleFileID) ?? false
                    let folderPath = fileOrder.folderPaths[candidate.subtitleFileID] ?? ""
                    for result in orderedMatches {
                        let durationFacet = CueDurationFacet(
                            durationMilliseconds:
                                result.result.endMilliseconds
                                - result.result.startMilliseconds
                        )
                        let characterFacet = CueCharacterFacet(
                            characterCount: result.result.content.unicodeScalars.count
                        )
                        acceptedCueIDs.append(result.result.entryID)
                        acceptedDurationFacets.append(durationFacet)
                        acceptedCharacterFacets.append(characterFacet)
                        acceptedLanguageFacets.append(result.result.languages)
                        acceptedWatchStateFacets.append(candidate.watchState)
                        acceptedFolderFacets.append(folderPath)
                        if firstFileIDs != nil {
                            acceptedFileRanks.append(fileRanks[candidate.subtitleFileID] ?? 0)
                            if isFirstFile {
                                acceptedFirstRunCount += 1
                            }
                        }
                        guard facetFilter.matches(
                            duration: durationFacet,
                            characters: characterFacet,
                            languages: result.result.languages.isEmpty
                                ? [.unknown]
                                : result.result.languages,
                            watchState: candidate.watchState,
                            folder: folderPath
                        ) else {
                            continue
                        }
                        resultCueIDs.append(result.result.entryID)
                        switch mode {
                        case .exact:
                            progressFileSummaries.add(result)
                            if progress != nil {
                                pendingProgressResults.append(result)
                            }
                            if acceptedSearchResultCount >= offset && exactPageResults.count < limit {
                                exactPageResults.append(result)
                            }
                        case .visibleWindow:
                            if acceptedSearchResultCount < offset + limit {
                                visiblePrefixResults.append(result)
                            }
                            if acceptedSearchResultCount >= offset && visibleWindowResults.count < limit + 1 {
                                visibleWindowResults.append(result)
                                reachedVisibleLookahead = visibleWindowResults.count > limit
                            }
                        }
                        acceptedSearchResultCount += 1
                    }
                }
                let accepted = acceptedSearchResultCount - acceptedBefore
                emit(
                    "line_validation",
                    since: validationStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("candidates", candidates.count),
                        .init("accepted", accepted),
                        .init("rejected", candidates.count - matchedCandidateCount),
                        .init("acceptedSoFar", acceptedSearchResultCount)
                    ]
                )

                if mode == .exact,
                   !isLastCandidateBatch,
                   acceptedSearchResultCount > 0 {
                    let progressSummaries = progressFileSummaries.fileSummaries()
                    let countSnapshot = SubtitleSearchCountSnapshot.exactProgress(
                        knownResultCount: acceptedSearchResultCount,
                        knownFileCount: progressSummaries.count
                    )
                    progress?(
                        SubtitleSearchProgressSnapshot(
                            countSnapshot: countSnapshot,
                            fileSummaries: progressSummaries,
                            results: rankedResults(
                                from: pendingProgressResults,
                                startingAt: publishedProgressResultCount
                            ),
                            cueIDs: Array(resultCueIDs[publishedProgressResultCount...]),
                            resultOffset: publishedProgressResultCount
                        )
                    )
                    publishedProgressResultCount = resultCueIDs.count
                    pendingProgressResults.removeAll(keepingCapacity: true)
                    emit(
                        "count_progress",
                        since: searchPageStart,
                        fields: [
                            .init("countState", countSnapshot.state.rawValue),
                            .init("knownResultCount", countSnapshot.knownResultCount),
                            .init("knownFileCount", countSnapshot.knownFileCount),
                            .init("summaries", progressSummaries.count)
                        ]
                    )
                }

                if reachedVisibleLookahead {
                    break
                }

                if isLastCandidateBatch {
                    break
                }
            }

            if mode == .visibleWindow {
                try Task.checkCancellation()
                let pageStart = Self.diagnosticNow()
                let hasMore = visibleWindowResults.count > limit
                let pageOrderedResults = Array(visibleWindowResults.prefix(limit))
                var pageResults = pageOrderedResults.map(\.result)
                for i in 0..<pageResults.count {
                    pageResults[i].searchRank = offset + i
                }
                let nextCursor = hasMore
                    ? SubtitleSearchCursor(offset: offset + pageResults.count)
                    : nil
                let orderSource = Self.searchOrderSource(for: pageOrderedResults)
                let materializedOrderRows = visiblePrefixResults.count
                emit(
                    "page_slice",
                    since: pageStart,
                    fields: [
                        .init("offset", offset),
                        .init("cursorOffset", appliedCursor.offset),
                        .init("nextCursorOffset", nextCursor?.offset ?? -1),
                        .init("limit", limit),
                        .init("pageResults", pageResults.count),
                        .init("hasMore", hasMore ? "true" : "false"),
                        .init("metadataMode", mode.rawValue)
                    ]
                )

                let summariesStart = Self.diagnosticNow()
                let fileSummaries = Self.fileSummaries(for: visiblePrefixResults)
                let countSnapshot: SubtitleSearchCountSnapshot = hasMore
                    ? .exactProgress(
                        knownResultCount: visiblePrefixResults.count,
                        knownFileCount: fileSummaries.count
                    )
                    : .exact(
                        totalCount: visiblePrefixResults.count,
                        fileSummaryCount: fileSummaries.count
                    )
                emit(
                    "file_summaries",
                    since: summariesStart,
                    fields: [
                        .init("summaries", fileSummaries.count),
                        .init("results", visiblePrefixResults.count),
                        .init("countState", countSnapshot.state.rawValue),
                        .init("knownResultCount", countSnapshot.knownResultCount),
                        .init("knownFileCount", countSnapshot.knownFileCount),
                        .init("metadataMode", mode.rawValue)
                    ]
                )

                emit(
                    "search_page_complete",
                    since: searchPageStart,
                    fields: [
                        .init("batches", batchIndex),
                        .init("cursorOffset", appliedCursor.offset),
                        .init("nextCursorOffset", nextCursor?.offset ?? -1),
                        .init("totalCandidates", totalCandidates),
                        .init("multiLineCandidates", totalMultiLineCandidates),
                        .init("cueLineRows", totalCueLineRows),
                        .init("accepted", visiblePrefixResults.count),
                        .init("pageResults", pageResults.count),
                        .init("summaries", fileSummaries.count),
                        .init("orderSource", orderSource),
                        .init("materializedOrderRows", materializedOrderRows),
                        .init("countState", countSnapshot.state.rawValue),
                        .init("knownResultCount", countSnapshot.knownResultCount),
                        .init("knownFileCount", countSnapshot.knownFileCount),
                        .init("metadataMode", mode.rawValue)
                    ]
                )
                let page = SubtitleSearchPage(
                    results: pageResults,
                    totalCount: countSnapshot.knownResultCount,
                    fileSummaries: fileSummaries,
                    countSnapshot: countSnapshot,
                    appliedCursor: appliedCursor,
                    nextCursor: nextCursor,
                    pageMode: mode,
                    orderSource: orderSource,
                    materializedOrderRows: materializedOrderRows,
                    facetSnapshot: countSnapshot.state == .exact ? facetSnapshot() : nil
                )
                return page
            }

            let sortStart = Self.diagnosticNow()
            try Task.checkCancellation()
            let totalExactResultCount = resultCueIDs.count
            let orderSource = totalExactResultCount > 0 ? "ftsRowid" : "none"
            let materializedOrderRows = exactPageResults.count
            emit(
                "sort_results",
                since: sortStart,
                fields: [
                    .init("results", totalExactResultCount),
                    .init("materializedResults", exactPageResults.count),
                    .init("resultIDs", resultCueIDs.count),
                    .init("orderSource", orderSource),
                    .init("materializedOrderRows", materializedOrderRows)
                ]
            )

            let pageStart = Self.diagnosticNow()
            let pageResults = rankedResults(from: exactPageResults, startingAt: offset)
            let renderableResults = progress == nil
                ? pageResults
                : rankedResults(
                    from: pendingProgressResults,
                    startingAt: publishedProgressResultCount
                )
            let renderableResultsOffset = progress == nil ? offset : publishedProgressResultCount
            let nextCursor = limit > 0 && offset + pageResults.count < totalExactResultCount
                ? SubtitleSearchCursor(offset: offset + pageResults.count)
                : nil
            emit(
                "page_slice",
                since: pageStart,
                fields: [
                    .init("offset", offset),
                    .init("cursorOffset", appliedCursor.offset),
                    .init("nextCursorOffset", nextCursor?.offset ?? -1),
                    .init("limit", limit),
                    .init("pageResults", pageResults.count)
                ]
            )

            let summariesStart = Self.diagnosticNow()
            let fileSummaries = progressFileSummaries.fileSummaries()
            let countSnapshot = SubtitleSearchCountSnapshot.exact(
                totalCount: totalExactResultCount,
                fileSummaryCount: fileSummaries.count
            )
            emit(
                "file_summaries",
                since: summariesStart,
                fields: [
                    .init("summaries", fileSummaries.count),
                    .init("results", totalExactResultCount),
                    .init("countState", countSnapshot.state.rawValue),
                    .init("knownResultCount", countSnapshot.knownResultCount),
                    .init("knownFileCount", countSnapshot.knownFileCount)
                ]
            )

            emit(
                "search_page_complete",
                since: searchPageStart,
                fields: [
                    .init("batches", batchIndex),
                    .init("cursorOffset", appliedCursor.offset),
                    .init("nextCursorOffset", nextCursor?.offset ?? -1),
                    .init("totalCandidates", totalCandidates),
                    .init("multiLineCandidates", totalMultiLineCandidates),
                    .init("cueLineRows", totalCueLineRows),
                    .init("accepted", totalExactResultCount),
                    .init("pageResults", pageResults.count),
                    .init("summaries", fileSummaries.count),
                    .init("orderSource", orderSource),
                    .init("materializedOrderRows", materializedOrderRows),
                    .init("countState", countSnapshot.state.rawValue),
                    .init("knownResultCount", countSnapshot.knownResultCount),
                    .init("knownFileCount", countSnapshot.knownFileCount)
                ]
            )
            let page = SubtitleSearchPage(
                results: pageResults,
                renderableResults: renderableResults,
                renderableResultsOffset: renderableResultsOffset,
                cueIDs: resultCueIDs,
                totalCount: totalExactResultCount,
                fileSummaries: fileSummaries,
                countSnapshot: countSnapshot,
                appliedCursor: appliedCursor,
                nextCursor: nextCursor,
                pageMode: mode,
                orderSource: orderSource,
                materializedOrderRows: materializedOrderRows,
                facetSnapshot: facetSnapshot()
            )
            return page
        } catch {
            emit(
                "failed",
                since: searchPageStart,
                fields: [.init("error", error.localizedDescription)]
            )
            if Self.isFTSSyntaxError(error) {
                return SubtitleSearchPage(
                    results: [],
                    totalCount: 0,
                    fileSummaries: [],
                    appliedCursor: appliedCursor,
                    pageMode: mode,
                    facetSnapshot: .empty
                )
            }
            throw error
        }
    }

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

    public func searchNavigationSnapshot(
        _ query: String,
        under folders: [URL]? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        anchor: SearchNavigationAnchor,
        radius: Int = 1
    ) throws -> SearchNavigationSnapshot {
        let countPage = try searchPage(
            query,
            limit: 1,
            offset: 0,
            under: folders,
            languageFilter: languageFilter
        )
        let page = if countPage.totalCount <= countPage.results.count {
            countPage
        } else {
            try searchPage(
                query,
                limit: countPage.totalCount,
                offset: 0,
                under: folders,
                languageFilter: languageFilter
            )
        }
        let results = page.results
        let currentIndex = Self.searchNavigationIndex(
            in: results,
            anchor: anchor
        )
        let boundedRadius = max(1, radius)
        let neighborhood: [SubtitleSearchResult]
        if let currentIndex {
            let lowerBound = max(0, currentIndex - boundedRadius)
            let upperBound = min(results.count, currentIndex + boundedRadius + 1)
            neighborhood = Array(results[lowerBound..<upperBound])
        } else {
            neighborhood = Array(results.prefix((boundedRadius * 2) + 1))
        }

        let previous = currentIndex.flatMap { index in
            index > 0 ? results[index - 1] : nil
        }
        let current = currentIndex.map { results[$0] }
        let next = currentIndex.flatMap { index in
            index + 1 < results.count ? results[index + 1] : nil
        }

        return SearchNavigationSnapshot(
            totalCount: page.totalCount,
            currentIndex: currentIndex,
            neighborhood: neighborhood,
            previous: previous,
            current: current,
            next: next
        )
    }




    private func requireCompleteSearchOrderRows(
        pathPrefixes: [String]?,
        subtitlePath: String?
    ) throws {
        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "AND (\(conditions))"
        } ?? ""
        let subtitlePathCondition = subtitlePath.map { _ in "AND sf.subtitle_path = ?" } ?? ""
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path
            FROM subtitle_files sf
            LEFT JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            WHERE sor.subtitle_file_id IS NULL
            \(scopeCondition)
            \(subtitlePathCondition)
            LIMIT 1;
            """
        )

        var bindIndex: Int32 = 1
        if let pathPrefixes {
            for prefix in pathPrefixes {
                try statement.bind(prefix, at: bindIndex)
                bindIndex += 1
                try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                bindIndex += 1
            }
        }
        if let subtitlePath {
            try statement.bind(subtitlePath, at: bindIndex)
        }

        guard try !statement.step() else {
            throw SQLiteDatabaseError.stepFailed(
                "Search order rows are missing for \(statement.stringColumn(0)). Rebuild derived Search order rows before searching."
            )
        }
    }

    private struct SearchCandidate {
        let cueGroupID: Int64
        let subtitleFileID: Int64
        let subtitlePath: String
        let subtitleFormat: SubtitleFormat
        let videoPath: String
        let videoName: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let timeRange: String
        let searchContent: String
        let lineCount: Int
        let order: SearchResultOrder
        var watchState: LibraryWatchState = .unwatched
        var ftsRowID: Int64 = 0
    }

    /// The searchable subtitle files inside a scope, as the scan reads them.
    private struct SearchFileOrder {
        /// Display rank of every file, in the Search order: display title,
        /// then subtitle path.
        var ranks: [Int64: Int] = [:]
        /// Each file's folder, one string shared by every match of the file.
        var folderPaths: [Int64: String] = [:]
        /// With a Folder selection, the files of the selected folders, which
        /// the scan reads first.
        var firstFileIDs: Set<Int64>?
    }

    private struct SearchResultOrder {
        let subtitleFileName: String
        let displayTitle: String
        let folderOrder: Int
        let fileOrder: Int
    }

    private struct OrderedSearchResult {
        let result: SubtitleSearchResult
        let order: SearchResultOrder
    }

    private struct SearchResultMatch {
        let cueLineRecord: SubtitleCueLineRecord
        let primaryGroupIndex: Int
        let cueGroupLines: [String]
        let displayLanguages: Set<SubtitleLanguageCode>
    }

    private struct AllCuePageCandidate {
        let candidate: SearchCandidate
        let cueLineRecord: SubtitleCueLineRecord
        let displayLanguages: Set<SubtitleLanguageCode>
    }

    private struct SearchFileSummaryAccumulator {
        private var countsByPath: [String: Int] = [:]
        private var pathsInOrder: [String] = []
        private var fileNamesByPath: [String: String] = [:]
        private var displayTitlesByPath: [String: String] = [:]

        mutating func add(_ orderedResult: OrderedSearchResult) {
            let result = orderedResult.result
            add(
                subtitlePath: result.subtitlePath,
                order: orderedResult.order
            )
        }

        mutating func add(candidate: SearchCandidate) {
            add(
                subtitlePath: candidate.subtitlePath,
                order: candidate.order
            )
        }

        private mutating func add(
            subtitlePath: String,
            order: SearchResultOrder
        ) {
            if countsByPath[subtitlePath] == nil {
                pathsInOrder.append(subtitlePath)
            }
            countsByPath[subtitlePath, default: 0] += 1
            fileNamesByPath[subtitlePath] = order.subtitleFileName
            displayTitlesByPath[subtitlePath] = order.displayTitle
        }

        func fileSummaries() -> [SubtitleSearchFileSummary] {
            pathsInOrder.map { path in
                SubtitleSearchFileSummary(
                    subtitlePath: path,
                    subtitleFileName: fileNamesByPath[path]!,
                    subtitleDisplayTitle: displayTitlesByPath[path]!,
                    matchCount: countsByPath[path]!
                )
            }
        }
    }


    private static func languageCodesForSearchFilter(
        _ languageFilter: SubtitleSearchLanguageFilter
    ) -> [SubtitleLanguageCode] {
        guard languageFilter != .all else {
            return []
        }

        var codes = languageFilter.matchingLanguageCodes
        codes.insert(.unknown)
        return codes.sorted { $0.rawValue < $1.rawValue }
    }

    private static func diagnosticNow() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private static func diagnosticMilliseconds(between start: UInt64, and end: UInt64) -> Double {
        Double(end - start) / 1_000_000
    }

    private func searchResults(
        for candidate: SearchCandidate,
        cueLineRecords: [SubtitleCueLineRecord],
        matching plan: SearchQueryPlanner.Plan,
        languageFilterCodes: Set<SubtitleLanguageCode>,
        languagesByCueID: [Int64: Set<SubtitleLanguageCode>],
        filterSet: SubtitleSearchFilterSet,
        allowedLineIDs: Set<Int64>? = nil
    ) -> [OrderedSearchResult] {
        searchMatches(
            for: candidate,
            cueLineRecords: cueLineRecords,
            matching: plan,
            languageFilterCodes: languageFilterCodes,
            languagesByCueID: languagesByCueID,
            filterSet: filterSet,
            allowedLineIDs: allowedLineIDs
        ).map { orderedSearchResult(for: candidate, match: $0) }
    }

    private func searchMatches(
        for candidate: SearchCandidate,
        cueLineRecords: [SubtitleCueLineRecord],
        matching plan: SearchQueryPlanner.Plan,
        languageFilterCodes: Set<SubtitleLanguageCode>,
        languagesByCueID: [Int64: Set<SubtitleLanguageCode>],
        filterSet: SubtitleSearchFilterSet,
        allowedLineIDs: Set<Int64>? = nil
    ) -> [SearchResultMatch] {
        let lines = cueLineRecords.map(\.line)
        let cueGroupLines = lines.map(\.content)
        var matches: [SearchResultMatch] = []
        matches.reserveCapacity(cueLineRecords.count)

        for (index, record) in cueLineRecords.enumerated() {
            if let allowedLineIDs, !allowedLineIDs.contains(record.id) {
                continue
            }
            guard SearchQueryPlanner.matches(record.line.content, rule: plan.lineMatchRule) else {
                continue
            }

            let displayLanguages = languagesByCueID[record.id] ?? [.unknown]
            guard languageFilterCodes.isEmpty
                    || !displayLanguages.isDisjoint(with: languageFilterCodes)
            else {
                continue
            }

            if !filterSet.isEffectivelyEmpty,
               !filterSet.matches(
                   display: candidate.order.displayTitle,
                   cues: record.line.content,
                   languages: Self.filterSetLanguageValues(displayLanguages)
               ) {
                continue
            }

            matches.append(
                SearchResultMatch(
                    cueLineRecord: record,
                    primaryGroupIndex: index,
                    cueGroupLines: cueGroupLines,
                    displayLanguages: displayLanguages
                )
            )
        }
        return matches
    }

    private func orderedSearchResult(
        for candidate: SearchCandidate,
        match: SearchResultMatch
    ) -> OrderedSearchResult {
        let cue = match.cueLineRecord
        return OrderedSearchResult(
            result: SubtitleSearchResult(
                entryID: cue.id,
                cueGroupID: candidate.cueGroupID,
                subtitleFileID: candidate.subtitleFileID,
                cueEventIndex: cue.line.eventIndex,
                cueDisplayOrder: cue.line.displayOrder,
                primaryGroupIndex: match.primaryGroupIndex,
                subtitlePath: candidate.subtitlePath,
                subtitleFormat: candidate.subtitleFormat,
                videoPath: candidate.videoPath,
                videoName: candidate.videoName,
                displayTitle: candidate.order.displayTitle,
                startMilliseconds: cue.line.startMilliseconds,
                endMilliseconds: cue.line.endMilliseconds,
                content: cue.line.content,
                cueLines: [cue.line.content],
                cueGroupLines: match.cueGroupLines,
                languages: match.displayLanguages
            ),
            order: candidate.order
        )
    }

    private static func filterSetLanguageValues(_ languages: Set<SubtitleLanguageCode>) -> [String] {
        let resolvedLanguages = languages.isEmpty ? Set([SubtitleLanguageCode.unknown]) : languages
        return resolvedLanguages
            .map(\.rawValue)
            .sorted()
    }

    private static func languageValues(from rawValue: String?) -> Set<SubtitleLanguageCode> {
        guard let rawValue, !rawValue.isEmpty else {
            return [.unknown]
        }

        let values = rawValue
            .split(separator: ",")
            .compactMap { SubtitleLanguageCode(rawValue: String($0)) }
        return values.isEmpty ? [.unknown] : Set(values)
    }

    private static func searchOrderSource(for results: [OrderedSearchResult]) -> String {
        guard !results.isEmpty else {
            return "none"
        }

        return "ftsRowid"
    }

    private static func searchNavigationIndex(
        in results: [SubtitleSearchResult],
        anchor: SearchNavigationAnchor
    ) -> Int? {
        if let videoPath = anchor.videoPath,
           let subtitlePath = anchor.subtitlePath {
            let normalizedVideoPath = URL(fileURLWithPath: videoPath).standardizedFileURL.path
            let normalizedSubtitlePath = URL(fileURLWithPath: subtitlePath).standardizedFileURL.path
            var timeMatchedIndex: Int?

            for (index, result) in results.enumerated() {
                let resultVideoPath = URL(fileURLWithPath: result.videoPath).standardizedFileURL.path
                let resultSubtitlePath = URL(fileURLWithPath: result.subtitlePath).standardizedFileURL.path
                guard resultVideoPath == normalizedVideoPath,
                      resultSubtitlePath == normalizedSubtitlePath,
                      result.startMilliseconds <= anchor.currentMilliseconds
                else {
                    continue
                }

                timeMatchedIndex = index
            }

            if let timeMatchedIndex {
                return timeMatchedIndex
            }
        }

        if let selectedEntryID = anchor.selectedEntryID,
           let selectedIndex = results.firstIndex(where: { $0.entryID == selectedEntryID }) {
            return selectedIndex
        }

        return nil
    }

    private static func searchNavigationIndex(
        in cueIDs: [Int64],
        anchor: SearchNavigationAnchor
    ) -> Int? {
        if let selectedEntryID = anchor.selectedEntryID,
           let selectedSearchRank = anchor.selectedSearchRank,
           cueIDs.indices.contains(selectedSearchRank),
           cueIDs[selectedSearchRank] == selectedEntryID {
            return selectedSearchRank
        }

        if anchor.selectedEntryID == nil,
           let selectedSearchRank = anchor.selectedSearchRank,
           cueIDs.indices.contains(selectedSearchRank) {
            return selectedSearchRank
        }

        if let selectedEntryID = anchor.selectedEntryID,
           let selectedIndex = cueIDs.firstIndex(of: selectedEntryID) {
            return selectedIndex
        }

        return nil
    }

    private static func searchNavigationIndex(
        of cueID: Int64,
        in cueIDs: [Int64],
        preferredSearchRank: Int?
    ) -> Int? {
        if let preferredSearchRank,
           cueIDs.indices.contains(preferredSearchRank),
           cueIDs[preferredSearchRank] == cueID {
            return preferredSearchRank
        }

        if let preferredSearchRank,
           cueIDs.indices.contains(preferredSearchRank) {
            var lowerIndex = preferredSearchRank - 1
            var upperIndex = preferredSearchRank + 1
            while lowerIndex >= 0 || upperIndex < cueIDs.count {
                if upperIndex < cueIDs.count {
                    if cueIDs[upperIndex] == cueID {
                        return upperIndex
                    }
                    upperIndex += 1
                }

                if lowerIndex >= 0 {
                    if cueIDs[lowerIndex] == cueID {
                        return lowerIndex
                    }
                    lowerIndex -= 1
                }
            }
        }

        return cueIDs.firstIndex(of: cueID)
    }

    private static func fileSummaries(for results: [OrderedSearchResult]) -> [SubtitleSearchFileSummary] {
        var countsByPath: [String: Int] = [:]
        var pathsInOrder: [String] = []
        var fileNamesByPath: [String: String] = [:]
        var displayTitlesByPath: [String: String] = [:]
        for orderedResult in results {
            let result = orderedResult.result
            if countsByPath[result.subtitlePath] == nil {
                pathsInOrder.append(result.subtitlePath)
            }
            countsByPath[result.subtitlePath, default: 0] += 1
            fileNamesByPath[result.subtitlePath] = orderedResult.order.subtitleFileName
            displayTitlesByPath[result.subtitlePath] = orderedResult.order.displayTitle
        }

        return pathsInOrder
        .map { path in
            SubtitleSearchFileSummary(
                subtitlePath: path,
                subtitleFileName: fileNamesByPath[path]!,
                subtitleDisplayTitle: displayTitlesByPath[path]!,
                matchCount: countsByPath[path]!
            )
        }
    }

    private static func isFTSSyntaxError(_ error: Error) -> Bool {
        String(describing: error).contains("fts5: syntax error")
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

    private static func expandedSQLLimit(for limit: Int) -> Int {
        let (expanded, overflow) = limit.multipliedReportingOverflow(by: 2)
        if overflow {
            return Int(Int32.max)
        }

        return min(expanded, Int(Int32.max))
    }

    private static func searchCandidateBatchLimit(
        for limit: Int,
        mode: SubtitleSearchPageMode
    ) -> Int {
        switch mode {
        case .exact:
            max(expandedSQLLimit(for: limit), exactSearchCandidateBatchMinimum)
        case .visibleWindow:
            max(expandedSQLLimit(for: limit), 100)
        }
    }


    /// Line ids inside the given cue groups that have one of the required
    /// languages, keyed by cue group. Groups without such a line are absent, so
    /// their rows need not be read at all.
    private func languageMatchingLineIDs(
        forCueGroupIDs cueGroupIDs: [Int64],
        requiredLanguages: Set<SubtitleLanguageCode>
    ) throws -> [Int64: Set<Int64>] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }
        let requiredLanguageCodes = requiredLanguages.map(\.rawValue).sorted()
        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let languagePlaceholders = Array(repeating: "?", count: requiredLanguageCodes.count)
            .joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id
            FROM subtitle_cue_lines l
            WHERE l.cue_group_id IN (\(placeholders))
              AND EXISTS (
                SELECT 1
                FROM subtitle_cue_line_languages cll
                WHERE cll.cue_id = l.id
                  AND cll.language_code IN (\(languagePlaceholders))
              );
            """
        )
        var bindIndex: Int32 = 1
        for cueGroupID in cueGroupIDs {
            try statement.bind(cueGroupID, at: bindIndex)
            bindIndex += 1
        }
        for code in requiredLanguageCodes {
            try statement.bind(code, at: bindIndex)
            bindIndex += 1
        }

        var lineIDsByCueGroupID: [Int64: Set<Int64>] = [:]
        while try statement.step() {
            lineIDsByCueGroupID[statement.int64Column(1), default: []].insert(statement.int64Column(0))
        }
        return lineIDsByCueGroupID
    }

    private func cueLineRecords(
        forCueGroupIDs cueGroupIDs: [Int64]
    ) throws -> [Int64: [SubtitleCueLineRecord]] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order
            FROM subtitle_cue_lines l
            WHERE l.cue_group_id IN (\(placeholders))
            ORDER BY l.cue_group_id ASC, l.display_order ASC, l.event_index ASC, l.id ASC;
            """
        )
        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var recordsByCueGroupID: [Int64: [SubtitleCueLineRecord]] = [:]
        recordsByCueGroupID.reserveCapacity(cueGroupIDs.count)
        while try statement.step() {
            let record = cueLineRecord(from: statement)
            recordsByCueGroupID[record.cueGroupID, default: []].append(record)
        }
        return recordsByCueGroupID
    }

    private func cueLineRecords(
        forCueIDs cueIDs: [Int64]
    ) throws -> [Int64: SubtitleCueLineRecord] {
        guard !cueIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order
            FROM subtitle_cue_lines l
            WHERE l.id IN (\(placeholders));
            """
        )
        for (offset, cueID) in cueIDs.enumerated() {
            try statement.bind(cueID, at: Int32(offset + 1))
        }

        var recordsByCueID: [Int64: SubtitleCueLineRecord] = [:]
        recordsByCueID.reserveCapacity(cueIDs.count)
        while try statement.step() {
            let record = cueLineRecord(from: statement)
            recordsByCueID[record.id] = record
        }
        return recordsByCueID
    }

    private static let searchCandidateColumnsSQL = """
        SELECT g.id, sf.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
               g.start_ms, g.end_ms, g.time_range, g.search_content, g.line_count,
               sor.subtitle_file_name, sor.display_title, sor.folder_order, sor.file_order,
               COALESCE(ws.state, '\(LibraryWatchState.unwatched.rawValue)')
        """

    private static let searchCandidateJoinsSQL = """
        JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
        JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
        JOIN video_files vf ON vf.id = m.video_file_id
        LEFT JOIN library_watch_states ws ON ws.video_file_id = vf.id
        JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
        """

    /// Every searchable subtitle file inside the scope with its display rank
    /// and folder, and with a Folder selection the files the scan reads first.
    private func searchFileRanks(
        pathPrefixes: [String]?,
        subtitlePath: String?,
        excludedFolders: Set<String>?
    ) throws -> SearchFileOrder {
        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "AND (\(conditions))"
        } ?? ""
        let subtitlePathCondition = subtitlePath.map { _ in "AND sf.subtitle_path = ?" } ?? ""
        let statement = try database.prepare(
            """
            SELECT sf.id, sor.folder_path
            FROM subtitle_search_order_rows sor
            JOIN subtitle_files sf ON sf.id = sor.subtitle_file_id
            WHERE EXISTS (
                SELECT 1
                FROM subtitle_video_matches m
                WHERE m.subtitle_file_id = sf.id AND m.is_active = 1
            )
            \(scopeCondition)
            \(subtitlePathCondition)
            ORDER BY sor.display_title COLLATE NOCASE ASC,
                     sf.subtitle_path COLLATE NOCASE ASC;
            """
        )
        var bindIndex = try bindPathPrefixes(pathPrefixes, to: statement, startingAt: 1)
        if let subtitlePath {
            try statement.bind(subtitlePath, at: bindIndex)
            bindIndex += 1
        }

        var order = SearchFileOrder(firstFileIDs: excludedFolders == nil ? nil : [])
        while try statement.step() {
            let fileID = statement.int64Column(0)
            let folderPath = statement.stringColumn(1)
            order.ranks[fileID] = order.ranks.count
            order.folderPaths[fileID] = folderPath
            if let excludedFolders, !excludedFolders.contains(folderPath) {
                order.firstFileIDs?.insert(fileID)
            }
        }
        return order
    }

    /// FTS hit rowids inside the scope, ordered by file display rank and then
    /// by time inside the file; the files read first, when there are any,
    /// come before the rest. Reads only the FTS index, never a content row.
    private func orderedFTSHitRowIDs(
        matching ftsQuery: String,
        fileRanks: [Int64: Int],
        firstFileIDs: Set<Int64>?
    ) throws -> [Int64] {
        guard !fileRanks.isEmpty else {
            return []
        }
        let singleFileRange = fileRanks.count == 1
            ? fileRanks.keys.first.map(SearchFTSRows.rowIDRange(forSubtitleFileID:))
            : nil
        let rangeCondition = singleFileRange == nil ? "" : "AND rowid >= ? AND rowid <= ?"
        let statement = try database.prepare(
            """
            SELECT rowid
            FROM subtitle_cue_groups_fts
            WHERE subtitle_cue_groups_fts MATCH ?
            \(rangeCondition);
            """
        )
        try statement.bind(ftsQuery, at: 1)
        if let singleFileRange {
            try statement.bind(singleFileRange.lowerBound, at: 2)
            try statement.bind(singleFileRange.upperBound, at: 3)
        }

        var hits: [(later: Bool, rank: Int, rowID: Int64)] = []
        var stepped = 0
        while try statement.step() {
            stepped += 1
            if stepped % 4096 == 0 {
                try Task.checkCancellation()
            }
            let rowID = statement.int64Column(0)
            let fileID = SearchFTSRows.subtitleFileID(ofRowID: rowID)
            guard let rank = fileRanks[fileID] else {
                continue
            }
            hits.append((firstFileIDs.map { !$0.contains(fileID) } ?? false, rank, rowID))
        }
        hits.sort { lhs, rhs in
            if lhs.later != rhs.later {
                return !lhs.later
            }
            return lhs.rank != rhs.rank ? lhs.rank < rhs.rank : lhs.rowID < rhs.rowID
        }
        return hits.map(\.rowID)
    }

    /// The order that puts a scan which read the selected folders first back
    /// in display order: the rows of that first run and then the rest, each
    /// run already in display order, merged by file rank.
    private static func displayOrder(fileRanks: [Int], firstRunCount: Int) -> [Int] {
        var order: [Int] = []
        order.reserveCapacity(fileRanks.count)
        var first = 0
        var rest = firstRunCount
        while first < firstRunCount, rest < fileRanks.count {
            if fileRanks[first] <= fileRanks[rest] {
                order.append(first)
                first += 1
            } else {
                order.append(rest)
                rest += 1
            }
        }
        order.append(contentsOf: first..<firstRunCount)
        order.append(contentsOf: rest..<fileRanks.count)
        return order
    }

    /// Candidates for the given FTS rowids, returned in the rowids' order and
    /// without the rows the language or watch-state filter rejects.
    private func searchCandidates(
        forFTSRowIDs rowIDs: [Int64],
        watchStateValues: [String],
        facetWatchStates: Set<LibraryWatchState> = [],
        negatesFacetWatchStates: Bool = false
    ) throws -> [SearchCandidate] {
        guard !rowIDs.isEmpty else {
            return []
        }
        let facetWatchStateValues = facetWatchStates.map(\.rawValue).sorted()
        let facetWatchStateCondition: String
        if facetWatchStateValues.isEmpty {
            facetWatchStateCondition = ""
        } else {
            let placeholders = Array(repeating: "?", count: facetWatchStateValues.count)
                .joined(separator: ", ")
            facetWatchStateCondition =
                "AND COALESCE(ws.state, '\(LibraryWatchState.unwatched.rawValue)') "
                + (negatesFacetWatchStates ? "NOT IN" : "IN")
                + " (\(placeholders))"
        }

        let watchStateCondition: String
        if watchStateValues.isEmpty {
            watchStateCondition = ""
        } else {
            let placeholders = Array(repeating: "?", count: watchStateValues.count)
                .joined(separator: ", ")
            watchStateCondition = "AND ws.state IN (\(placeholders))"
        }
        let rowIDPlaceholders = rowIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            \(Self.searchCandidateColumnsSQL), f.rowid
            FROM subtitle_cue_groups_fts f
            JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
            \(Self.searchCandidateJoinsSQL)
            WHERE f.rowid IN (\(rowIDPlaceholders))
            \(watchStateCondition)
            \(facetWatchStateCondition);
            """
        )
        var bindIndex: Int32 = 1
        for rowID in rowIDs {
            try statement.bind(rowID, at: bindIndex)
            bindIndex += 1
        }
        for watchStateValue in watchStateValues {
            try statement.bind(watchStateValue, at: bindIndex)
            bindIndex += 1
        }
        for facetWatchStateValue in facetWatchStateValues {
            try statement.bind(facetWatchStateValue, at: bindIndex)
            bindIndex += 1
        }

        var candidatesByRowID: [Int64: SearchCandidate] = [:]
        candidatesByRowID.reserveCapacity(rowIDs.count)
        while try statement.step() {
            var candidate = searchCandidateWithWatchState(from: statement)
            candidate.ftsRowID = statement.int64Column(16)
            candidatesByRowID[candidate.ftsRowID] = candidate
        }
        return rowIDs.compactMap { candidatesByRowID[$0] }
    }

    private func searchCandidates(forCueGroupIDs cueGroupIDs: [Int64]) throws -> [Int64: SearchCandidate] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            \(Self.searchCandidateColumnsSQL)
            FROM subtitle_cue_groups g
            \(Self.searchCandidateJoinsSQL)
            WHERE g.id IN (\(placeholders));
            """
        )

        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var candidates: [Int64: SearchCandidate] = [:]
        candidates.reserveCapacity(cueGroupIDs.count)
        while try statement.step() {
            let candidate = searchCandidateWithWatchState(from: statement)
            candidates[candidate.cueGroupID] = candidate
        }

        return candidates
    }

    private func cueLineRecord(
        from statement: SQLiteStatement,
        startingAt columnOffset: Int32 = 0
    ) -> SubtitleCueLineRecord {
        SubtitleCueLineRecord(
            id: statement.int64Column(columnOffset),
            cueGroupID: statement.int64Column(columnOffset + 1),
            line: SubtitleCueLine(
                eventIndex: statement.intColumn(columnOffset + 2),
                sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(columnOffset + 3)) ?? .srt,
                sourceStyle: statement.nullableStringColumn(columnOffset + 4),
                sourceLayer: statement.nullableIntColumn(columnOffset + 5),
                startTimecode: statement.stringColumn(columnOffset + 6),
                endTimecode: statement.stringColumn(columnOffset + 7),
                startMilliseconds: statement.intColumn(columnOffset + 8),
                endMilliseconds: statement.intColumn(columnOffset + 9),
                content: statement.stringColumn(columnOffset + 10),
                displayX: statement.nullableDoubleColumn(columnOffset + 11),
                displayY: statement.nullableDoubleColumn(columnOffset + 12),
                displayOrder: statement.intColumn(columnOffset + 13)
            )
        )
    }

    private static func folderPathPrefixes(for folders: [URL]) -> [String] {
        Array(Set(folders.flatMap(folderPathPrefixes(for:)))).sorted()
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = normalizedFolderPath(folder.standardizedFileURL.path)
        if !path.hasSuffix("/") {
            path.append("/")
        }

        var prefixes = Set([path])

        if path.hasPrefix("/var/") {
            prefixes.insert("/private" + path)
        } else if path.hasPrefix("/private/var/") {
            prefixes.insert(String(path.dropFirst("/private".count)))
        }

        return prefixes.sorted()
    }

    private static func pathPrefixUpperBound(for prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }

    private static func normalizedFolderPath(_ path: String) -> String {
        var path = path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}
