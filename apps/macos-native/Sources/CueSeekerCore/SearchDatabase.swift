import Foundation

public final class SearchDatabase: @unchecked Sendable {
    private static let exactSearchCandidateBatchMinimum = 5_000

    let path: URL
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readOnly,
        directIO: Bool = false
    ) throws {
        self.path = path
        database = try SQLiteDatabase(path: path, access: access, directIO: directIO)
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
        facetFilter: CueFacetFilter = CueFacetFilter(),
        sortOrder: SearchSortOrder = .default
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
            facetFilter: facetFilter,
            sortOrder: sortOrder
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
        sortOrder: SearchSortOrder = .default,
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
            sortOrder: sortOrder,
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
        sortOrder: SearchSortOrder = .default,
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
            sortOrder: sortOrder,
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
        try database.withReadTransaction {
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
                   l.start_ms, l.end_ms, l.duration_ms, l.character_width,
                   l.content, l.display_x, l.display_y,
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
                from: statement.nullableStringColumn(31)
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
        sortOrder: SearchSortOrder = .default,
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
            return try database.withReadTransaction {
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
            var acceptedCharacterWidths: [Int] = []
            var acceptedLanguageFacets: [Set<SubtitleLanguageCode>] = []
            var acceptedWatchStateFacets: [LibraryWatchState] = []
            var acceptedFolderFacets: [String] = []
            // Only while the selected folders are read first: each match's
            // file rank, and how many matches the first run holds.
            var acceptedFileRanks: [Int] = []
            var acceptedFirstRunCount = 0
            var resultCueIDs: [Int64] = []
            var resultCharacterWidths: [Int] = []
            var allExactResults: [OrderedSearchResult] = []
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
                        characterWidths: acceptedCharacterWidths,
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
                    characterWidths: order.map { acceptedCharacterWidths[$0] },
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
                excludedFolders: facetFilter.excludedFolders,
                watchStateValues: watchStateValues
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

            let hitCapacity = orderedHitRowIDs.count
            acceptedCueIDs.reserveCapacity(hitCapacity)
            acceptedDurationFacets.reserveCapacity(hitCapacity)
            acceptedCharacterFacets.reserveCapacity(hitCapacity)
            acceptedCharacterWidths.reserveCapacity(hitCapacity)
            acceptedLanguageFacets.reserveCapacity(hitCapacity)
            acceptedWatchStateFacets.reserveCapacity(hitCapacity)
            acceptedFolderFacets.reserveCapacity(hitCapacity)
            resultCueIDs.reserveCapacity(hitCapacity)
            if sortOrder != .default {
                resultCharacterWidths.reserveCapacity(hitCapacity)
                allExactResults.reserveCapacity(hitCapacity)
            }
            if firstFileIDs != nil {
                acceptedFileRanks.reserveCapacity(hitCapacity)
            }
            let requiredLanguageMask = languageFilterCodeSet.isEmpty
                ? 0
                : CueLineLanguages.mask(for: languageFilterCodeSet)

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

                let coveringResult = try searchCoveringCueLines(forFTSRowIDs: chunkRowIDs)
                let linesByFTSRowID = coveringResult.linesByFTSRowID
                let candidateCount = linesByFTSRowID.count
                emit(
                    "fts_batch",
                    since: queryStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("candidateOffset", candidateOffset),
                        .init("candidateBatchLimit", batchLimit),
                        .init("candidates", candidateCount)
                    ]
                )
                let isLastCandidateBatch = nextHitIndex >= orderedHitRowIDs.count

                guard candidateCount > 0 else {
                    if isLastCandidateBatch {
                        break
                    }
                    continue
                }

                totalCandidates += candidateCount
                totalMultiLineCandidates += coveringResult.multiLineGroupCount
                totalCueLineRows += coveringResult.totalLineCount
                emit(
                    "cue_lines",
                    since: queryStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("multiLineCandidates", coveringResult.multiLineGroupCount),
                        .init("lineCueGroups", candidateCount),
                        .init("cueLineRows", coveringResult.totalLineCount)
                    ]
                )

                let validationStart = Self.diagnosticNow()
                let acceptedBefore = acceptedSearchResultCount
                var matchedCandidateCount = 0
                for ftsRowID in chunkRowIDs {
                    try Task.checkCancellation()
                    let subtitleFileID = SearchFTSRows.subtitleFileID(ofRowID: ftsRowID)
                    guard let fileMetadata = fileOrder.files[subtitleFileID],
                          let records = linesByFTSRowID[ftsRowID],
                          !records.isEmpty
                    else {
                        continue
                    }
                    let orderedMatches = searchCoveringResults(
                        for: fileMetadata,
                        cueLineRecords: records,
                        matching: plan,
                        requiredLanguageMask: requiredLanguageMask,
                        filterSet: filterSet
                    )
                    if !orderedMatches.isEmpty {
                        matchedCandidateCount += 1
                    }
                    let isFirstFile = firstFileIDs?.contains(subtitleFileID) ?? false
                    let folderPath = fileMetadata.folderPath
                    for result in orderedMatches {
                        let durationFacet = CueDurationFacet(
                            durationMilliseconds: result.result.durationMilliseconds
                        )
                        let characterWidth = result.result.characterWidth
                        let characterFacet = CueCharacterFacet(
                            characterCount: characterWidth
                        )
                        acceptedCueIDs.append(result.result.entryID)
                        acceptedDurationFacets.append(durationFacet)
                        acceptedCharacterFacets.append(characterFacet)
                        acceptedCharacterWidths.append(characterWidth)
                        acceptedLanguageFacets.append(result.result.languages)
                        acceptedWatchStateFacets.append(fileMetadata.watchState)
                        acceptedFolderFacets.append(folderPath)
                        if firstFileIDs != nil {
                            acceptedFileRanks.append(fileRanks[subtitleFileID] ?? 0)
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
                            watchState: fileMetadata.watchState,
                            folder: folderPath
                        ) else {
                            continue
                        }
                        resultCueIDs.append(result.result.entryID)
                        if sortOrder == .default {
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
                        } else {
                            resultCharacterWidths.append(characterWidth)
                            allExactResults.append(result)
                            if mode == .exact {
                                progressFileSummaries.add(result)
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
                        .init("candidates", candidateCount),
                        .init("accepted", accepted),
                        .init("rejected", candidateCount - matchedCandidateCount),
                        .init("acceptedSoFar", acceptedSearchResultCount)
                    ]
                )

                if mode == .exact,
                   sortOrder == .default,
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

            if sortOrder != .default, !resultCueIDs.isEmpty {
                try Task.checkCancellation()
                var sortedIndices = Array(0..<resultCueIDs.count)
                sortedIndices.sort { lhs, rhs in
                    let lhsWidth = resultCharacterWidths[lhs]
                    let rhsWidth = resultCharacterWidths[rhs]
                    if lhsWidth != rhsWidth {
                        return sortOrder == .mostCharacters
                            ? lhsWidth > rhsWidth
                            : lhsWidth < rhsWidth
                    }
                    return lhs < rhs
                }
                resultCueIDs = sortedIndices.map { resultCueIDs[$0] }
                let sortedResults = sortedIndices.map { allExactResults[$0] }
                let safeLimit = max(0, limit)
                let sliceStart = min(max(0, offset), sortedResults.count)
                let sliceEnd = min(sliceStart + safeLimit, sortedResults.count)
                switch mode {
                case .exact:
                    if sliceStart < sliceEnd {
                        exactPageResults = Array(sortedResults[sliceStart..<sliceEnd])
                    }
                    if progress != nil {
                        pendingProgressResults = sortedResults
                    }
                case .visibleWindow:
                    let prefixEnd = min(max(0, offset) + safeLimit, sortedResults.count)
                    visiblePrefixResults = Array(sortedResults.prefix(prefixEnd))
                    let windowEnd = min(sliceStart + safeLimit + 1, sortedResults.count)
                    if sliceStart < windowEnd {
                        visibleWindowResults = Array(sortedResults[sliceStart..<windowEnd])
                    }
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
            }
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

    private struct SearchFileMetadata {
        let subtitleFileID: Int64
        let subtitlePath: String
        let subtitleFormat: SubtitleFormat
        let videoPath: String
        let videoName: String
        let order: SearchResultOrder
        let watchState: LibraryWatchState
        let folderPath: String
    }

    private struct SearchCoveringCueLineRecord {
        let id: Int64
        let cueGroupID: Int64
        let ftsRowID: Int64
        let eventIndex: Int
        let displayOrder: Int
        let startMilliseconds: Int
        let endMilliseconds: Int
        let durationMilliseconds: Int
        let characterWidth: Int
        let languageMask: Int
        let content: String
    }

    private struct SearchCoveringBatchResult {
        let linesByFTSRowID: [Int64: [SearchCoveringCueLineRecord]]
        let multiLineGroupCount: Int
        let totalLineCount: Int
    }

    /// The searchable subtitle files inside a scope, as the scan reads them.
    private struct SearchFileOrder {
        /// Display rank of every file, in the Search order: display title,
        /// then subtitle path.
        var ranks: [Int64: Int] = [:]
        /// Each file's folder, one string shared by every match of the file.
        var folderPaths: [Int64: String] = [:]
        /// Preloaded file metadata keyed by subtitleFileID.
        var files: [Int64: SearchFileMetadata] = [:]
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

    private func searchCoveringResults(
        for fileMetadata: SearchFileMetadata,
        cueLineRecords: [SearchCoveringCueLineRecord],
        matching plan: SearchQueryPlanner.Plan,
        requiredLanguageMask: Int,
        filterSet: SubtitleSearchFilterSet
    ) -> [OrderedSearchResult] {
        var results: [OrderedSearchResult] = []
        var lazyCueGroupLines: [String]?
        let hasFilterSet = !filterSet.isEffectivelyEmpty

        for (index, record) in cueLineRecords.enumerated() {
            let effectiveMask = record.languageMask == 0 ? 32 : record.languageMask
            if requiredLanguageMask != 0, (effectiveMask & requiredLanguageMask) == 0 {
                continue
            }
            guard SearchQueryPlanner.matches(record.content, rule: plan.lineMatchRule) else {
                continue
            }

            let displayLanguages = CueLineLanguages.languages(forMask: effectiveMask)
            if hasFilterSet,
               !filterSet.matches(
                   display: fileMetadata.order.displayTitle,
                   cues: record.content,
                   languages: Self.filterSetLanguageValues(displayLanguages)
               ) {
                continue
            }

            let singleLineArray = [record.content]
            let cueGroupLines: [String]
            if cueLineRecords.count == 1 {
                cueGroupLines = singleLineArray
            } else if let existing = lazyCueGroupLines {
                cueGroupLines = existing
            } else {
                let computed = cueLineRecords.map(\.content)
                lazyCueGroupLines = computed
                cueGroupLines = computed
            }

            results.append(
                OrderedSearchResult(
                    result: SubtitleSearchResult(
                        entryID: record.id,
                        cueGroupID: record.cueGroupID,
                        subtitleFileID: fileMetadata.subtitleFileID,
                        cueEventIndex: record.eventIndex,
                        cueDisplayOrder: record.displayOrder,
                        primaryGroupIndex: index,
                        subtitlePath: fileMetadata.subtitlePath,
                        subtitleFormat: fileMetadata.subtitleFormat,
                        videoPath: fileMetadata.videoPath,
                        videoName: fileMetadata.videoName,
                        displayTitle: fileMetadata.order.displayTitle,
                        startMilliseconds: record.startMilliseconds,
                        endMilliseconds: record.endMilliseconds,
                        durationMilliseconds: record.durationMilliseconds,
                        characterWidth: record.characterWidth,
                        content: record.content,
                        cueLines: singleLineArray,
                        cueGroupLines: cueGroupLines,
                        languages: displayLanguages
                    ),
                    order: fileMetadata.order
                )
            )
        }
        return results
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
                durationMilliseconds: cue.line.durationMilliseconds,
                characterWidth: cue.line.characterWidth,
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
            let normalizedVideoPath = URL.fromMediaPath(videoPath).mediaPath
            let normalizedSubtitlePath = URL.fromMediaPath(subtitlePath).mediaPath
            var timeMatchedIndex: Int?

            for (index, result) in results.enumerated() {
                let resultVideoPath = URL.fromMediaPath(result.videoPath).mediaPath
                let resultSubtitlePath = URL.fromMediaPath(result.subtitlePath).mediaPath
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
                   l.start_ms, l.end_ms, l.duration_ms, l.character_width,
                   l.content, l.display_x, l.display_y,
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
                   l.start_ms, l.end_ms, l.duration_ms, l.character_width,
                   l.content, l.display_x, l.display_y,
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

    /// Every searchable subtitle file inside the scope with its display rank,
    /// folder, and preloaded file metadata, and with a Folder selection the
    /// files the scan reads first.
    private func searchFileRanks(
        pathPrefixes: [String]?,
        subtitlePath: String?,
        excludedFolders: Set<String>?,
        watchStateValues: [String] = []
    ) throws -> SearchFileOrder {
        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "AND (\(conditions))"
        } ?? ""
        let subtitlePathCondition = subtitlePath.map { _ in "AND sf.subtitle_path = ?" } ?? ""
        let watchStateCondition: String
        if watchStateValues.isEmpty {
            watchStateCondition = ""
        } else {
            let placeholders = Array(repeating: "?", count: watchStateValues.count)
                .joined(separator: ", ")
            watchStateCondition = "AND ws.state IN (\(placeholders))"
        }
        let statement = try database.prepare(
            """
            SELECT sf.id,
                   sf.subtitle_path,
                   sf.format,
                   vf.path,
                   vf.video_name,
                   sor.subtitle_file_name,
                   sor.display_title,
                   sor.folder_order,
                   sor.file_order,
                   COALESCE(ws.state, '\(LibraryWatchState.unwatched.rawValue)'),
                   sor.folder_path
            FROM subtitle_search_order_rows sor
            JOIN subtitle_files sf ON sf.id = sor.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = vf.id
            WHERE 1 = 1
            \(scopeCondition)
            \(subtitlePathCondition)
            \(watchStateCondition)
            ORDER BY sor.display_title COLLATE NOCASE ASC,
                     sf.subtitle_path COLLATE NOCASE ASC;
            """
        )
        var bindIndex = try bindPathPrefixes(pathPrefixes, to: statement, startingAt: 1)
        if let subtitlePath {
            try statement.bind(subtitlePath, at: bindIndex)
            bindIndex += 1
        }
        for watchStateValue in watchStateValues {
            try statement.bind(watchStateValue, at: bindIndex)
            bindIndex += 1
        }

        var order = SearchFileOrder(firstFileIDs: excludedFolders == nil ? nil : [])
        while try statement.step() {
            let fileID = statement.int64Column(0)
            let subtitlePathValue = statement.stringColumn(1)
            let subtitleFormat = SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt
            let videoPath = statement.stringColumn(3)
            let videoName = statement.stringColumn(4)
            let resultOrder = SearchResultOrder(
                subtitleFileName: statement.stringColumn(5),
                displayTitle: statement.stringColumn(6),
                folderOrder: statement.intColumn(7),
                fileOrder: statement.intColumn(8)
            )
            let watchState = LibraryWatchState(rawValue: statement.stringColumn(9)) ?? .unwatched
            let folderPath = statement.stringColumn(10)
            if order.ranks[fileID] == nil {
                order.ranks[fileID] = order.ranks.count
            }
            order.folderPaths[fileID] = folderPath
            order.files[fileID] = SearchFileMetadata(
                subtitleFileID: fileID,
                subtitlePath: subtitlePathValue,
                subtitleFormat: subtitleFormat,
                videoPath: videoPath,
                videoName: videoName,
                order: resultOrder,
                watchState: watchState,
                folderPath: folderPath
            )
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

    /// Reads cue lines directly from `idx_subtitle_cue_lines_fts_covering`
    /// in ascending `fts_rowid` order without touching `subtitle_cue_groups`,
    /// `subtitle_cue_groups_fts` shadow tables, or `subtitle_cue_line_languages`.
    private func searchCoveringCueLines(
        forFTSRowIDs rowIDs: [Int64]
    ) throws -> SearchCoveringBatchResult {
        guard !rowIDs.isEmpty else {
            return SearchCoveringBatchResult(
                linesByFTSRowID: [:],
                multiLineGroupCount: 0,
                totalLineCount: 0
            )
        }
        let sortedRowIDs = rowIDs.sorted()
        let placeholders = sortedRowIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT fts_rowid, display_order, event_index, id, cue_group_id, start_ms, end_ms, duration_ms, character_width, language_mask, content
            FROM subtitle_cue_lines INDEXED BY idx_subtitle_cue_lines_fts_covering
            WHERE fts_rowid IN (\(placeholders))
            ORDER BY fts_rowid ASC, display_order ASC, event_index ASC, id ASC;
            """
        )
        for (offset, rowID) in sortedRowIDs.enumerated() {
            try statement.bind(rowID, at: Int32(offset + 1))
        }

        var linesByFTSRowID: [Int64: [SearchCoveringCueLineRecord]] = [:]
        linesByFTSRowID.reserveCapacity(sortedRowIDs.count)
        var currentFTSRowID: Int64 = -1
        var currentRecords: [SearchCoveringCueLineRecord] = []
        var multiLineGroupCount = 0
        var totalLineCount = 0

        while try statement.step() {
            totalLineCount += 1
            let ftsRowID = statement.int64Column(0)
            if ftsRowID != currentFTSRowID {
                if !currentRecords.isEmpty {
                    if currentRecords.count > 1 {
                        multiLineGroupCount += 1
                    }
                    linesByFTSRowID[currentFTSRowID] = currentRecords
                    currentRecords = []
                }
                currentFTSRowID = ftsRowID
            }
            currentRecords.append(
                SearchCoveringCueLineRecord(
                    id: statement.int64Column(3),
                    cueGroupID: statement.int64Column(4),
                    ftsRowID: ftsRowID,
                    eventIndex: statement.intColumn(2),
                    displayOrder: statement.intColumn(1),
                    startMilliseconds: statement.intColumn(5),
                    endMilliseconds: statement.intColumn(6),
                    durationMilliseconds: statement.intColumn(7),
                    characterWidth: statement.intColumn(8),
                    languageMask: statement.intColumn(9),
                    content: statement.stringColumn(10)
                )
            )
        }
        if !currentRecords.isEmpty {
            if currentRecords.count > 1 {
                multiLineGroupCount += 1
            }
            linesByFTSRowID[currentFTSRowID] = currentRecords
        }

        return SearchCoveringBatchResult(
            linesByFTSRowID: linesByFTSRowID,
            multiLineGroupCount: multiLineGroupCount,
            totalLineCount: totalLineCount
        )
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
                durationMilliseconds: statement.intColumn(columnOffset + 10),
                characterWidth: statement.intColumn(columnOffset + 11),
                content: statement.stringColumn(columnOffset + 12),
                displayX: statement.nullableDoubleColumn(columnOffset + 13),
                displayY: statement.nullableDoubleColumn(columnOffset + 14),
                displayOrder: statement.intColumn(columnOffset + 15)
            )
        )
    }

    private static func folderPathPrefixes(for folders: [URL]) -> [String] {
        Array(Set(folders.flatMap(folderPathPrefixes(for:)))).sorted()
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = normalizedFolderPath(folder.mediaPath)
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
