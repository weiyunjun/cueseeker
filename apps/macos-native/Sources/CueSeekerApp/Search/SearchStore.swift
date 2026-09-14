import Combine
import Foundation
import CueSeekerCore

struct SearchIndexedCueMutationToken: Equatable {
    let generation: UInt64
}

enum SearchTableProjectionSource: Equatable {
    case residentSearch(revision: UInt64)
}

@MainActor
final class SearchStore: ObservableObject {
    private let cueContentStore: CueContentStore
    private var cueContentChangesCancellable: AnyCancellable?
    private let uiProbeScope: String?
    let databaseURL: URL?
    let database: SearchDatabase?
    private(set) var searchTask: Task<Void, Never>?
    private(set) var exactCompletionTask: Task<Void, Never>?
    private(set) var navigationTask: Task<Void, Never>?
    private(set) var activePerformanceRun: SearchPerformanceRun?
    private(set) var resultListGeneration: UInt64 = 0
    private(set) var folderScopeGeneration: UInt64 = 0
    private var folderScopePaths: [String] = []
    private(set) var loadedGlobalResultCount = 0
    private(set) var nextGlobalCursor: SubtitleSearchCursor?
    private var isTableProjectionResponseActive = true
    private var pendingCueContentChange: CueContentStoreChange?
    private(set) var loadedSearchResultCueIDs: [Int64] = []
    private(set) var searchRankByCueID: [Int64: Int] = [:]
    private(set) var tableProjectionRevision: UInt64 = 0
    let tableRowStore: TableSandboxRowModelStore
    private(set) var tableProjectionSource: SearchTableProjectionSource?
    private var indexedCueMutationGeneration: UInt64 = 0
    private var activeIndexedCueMutationGeneration: UInt64?

    @Published private(set) var indexedCueDataRevision: UInt64 = 0
    @Published private(set) var searchQuery = ""
    private(set) var searchStatus: SearchStatus = .idle
    private(set) var searchResultCueIDs: [Int64] = []
    private(set) var searchResultTotalCount = 0
    private(set) var searchFileSummaries: [SubtitleSearchFileSummary] = []
    private(set) var searchCountState: SubtitleSearchCountState = .exact
    private(set) var searchKnownResultCount = 0
    private(set) var searchKnownFileCount = 0
    private(set) var hasMoreSearchResults = false
    @Published private(set) var resultRevision: UInt64 = 0
    @Published private(set) var activeFilterSet = SubtitleSearchFilterSet()
    /// Every line match of the current query and scope with its facet values,
    /// kept across filter changes so the option counts can be recomputed at once.
    @Published private(set) var searchFacetSnapshot: CueFacetSnapshot?
    @Published private(set) var emptySearchFacetDistribution: CueFacetDistribution?
    private(set) var searchFacetFilter = CueFacetFilter()
    /// The four option-count cards for the current filter: each card ignores its
    /// own selections and applies the other three.
    @Published private(set) var searchFacetDistribution: CueFacetDistribution?
    @Published private(set) var searchNavigationSnapshot: SearchNavigationSnapshot?
    @Published private(set) var selectedSearchResult: SubtitleSearchResult?
    @Published var tableSearchDraft = ""
    var tableViewportAnchor: TableViewportAnchor?
    var tableSelectionState = TableSandboxRowSelectionState()
    var tableSelectionEntryIDs: [Int] = []

    init(
        cueContentStore: CueContentStore = CueContentStore(),
        databaseURL: URL? = nil,
        database: SearchDatabase? = nil,
        uiProbeScope: String? = nil
    ) {
        self.cueContentStore = cueContentStore
        self.databaseURL = databaseURL
        self.database = database
        self.uiProbeScope = uiProbeScope
        emptySearchFacetDistribution = try? database?.cueFacetDistribution()
        tableRowStore = TableSandboxRowModelStore()
        cueContentChangesCancellable = cueContentStore.changes.sink {
            [weak self] change in
            self?.receiveCueContentChange(change)
        }
    }

    var searchResults: [SubtitleSearchResult] {
        loadedSearchResultCueIDs.compactMap { cueID in
            cueContentStore.content(for: cueID).map {
                SubtitleSearchResult(
                    cueContent: $0,
                    searchRank: searchRankByCueID[cueID] ?? 0
                )
            }
        }
    }

    var displayedSearchFacetDistribution: CueFacetDistribution {
        guard !searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return .zero
        }
        return searchFacetDistribution ?? .zero
    }

    var isDatabaseAvailable: Bool {
        database != nil
    }

    private func setLoadedSearchResults(
        _ results: [SubtitleSearchResult],
        orderedCueIDs: [Int64]? = nil
    ) {
        cueContentStore.install(results.map(\.cueContent))
        let nextCueIDs = results.map(\.entryID)
        let nextRanks = Dictionary(uniqueKeysWithValues: results.map {
            ($0.entryID, $0.searchRank)
        })
        let projectionChanged = loadedSearchResultCueIDs != nextCueIDs
            || searchRankByCueID != nextRanks
        loadedSearchResultCueIDs = nextCueIDs
        searchRankByCueID = nextRanks
        if projectionChanged {
            tableProjectionRevision &+= 1
        }

        if let orderedCueIDs {
            searchResultCueIDs = orderedCueIDs
        } else if results.isEmpty {
            searchResultCueIDs = []
        } else if searchResultCueIDs.isEmpty
                    || !Set(loadedSearchResultCueIDs).isSubset(
                        of: Set(searchResultCueIDs)
                    ) {
            searchResultCueIDs = loadedSearchResultCueIDs
        }

        if case .residentSearch = tableProjectionSource {
            activateResidentSearchTableProjection()
        }
    }

    /// Adds results whose first rank is `offset`. Rows already loaded at those
    /// ranks are kept when they are the same cues and only the rest is appended;
    /// otherwise the loaded rows from `offset` on are replaced. A snapshot that
    /// leaves a gap after the loaded rows is ignored apart from its counts.
    private func mergeLoadedSearchResults(
        _ results: [SubtitleSearchResult],
        cueIDs: [Int64],
        startingAt offset: Int
    ) {
        let loadedCount = loadedSearchResultCueIDs.count
        guard offset <= loadedCount else {
            return
        }
        let overlap = loadedCount - offset
        let overlapMatches = overlap <= results.count
            && results.prefix(overlap).map(\.entryID)
                .elementsEqual(loadedSearchResultCueIDs[offset...])
        if offset == 0 && !overlapMatches {
            setLoadedSearchResults(results, orderedCueIDs: cueIDs.isEmpty ? nil : cueIDs)
            return
        }
        let skip = overlapMatches ? overlap : 0
        if !overlapMatches {
            for cueID in loadedSearchResultCueIDs[offset...] {
                searchRankByCueID.removeValue(forKey: cueID)
            }
            loadedSearchResultCueIDs.removeSubrange(offset...)
        }
        let newResults = results.dropFirst(skip)
        guard !newResults.isEmpty else {
            return
        }
        cueContentStore.install(newResults.map(\.cueContent))
        loadedSearchResultCueIDs.append(contentsOf: newResults.map(\.entryID))
        for result in newResults {
            searchRankByCueID[result.entryID] = result.searchRank
        }
        if !cueIDs.isEmpty {
            if searchResultCueIDs.count == offset + skip {
                searchResultCueIDs.append(contentsOf: cueIDs.dropFirst(skip))
            } else {
                searchResultCueIDs = loadedSearchResultCueIDs
            }
        }
        tableProjectionRevision &+= 1
        if case .residentSearch = tableProjectionSource {
            activateResidentSearchTableProjection()
        }
    }

    func cacheHydratedResults(_ results: [SubtitleSearchResult]) {
        cueContentStore.install(results.map(\.cueContent))
    }

    func cachedCueContent(for cueID: Int64) -> CueContent? {
        cueContentStore.content(for: cueID)
    }

    var cachedCueContentRevision: UInt64 {
        cueContentStore.revision
    }

    func activateResidentSearchTableProjection() {
        setTableProjectionSource(.residentSearch(revision: tableProjectionRevision))
        guard isTableProjectionResponseActive else {
            return
        }
        synchronizeResidentSearchTableProjection()
    }

    /// Stores the filter the next search runs with. Returns whether it changed;
    /// the option counts follow at once when the facet snapshot is already known.
    @discardableResult
    func updateSearchFacetFilter(_ filter: CueFacetFilter) -> Bool {
        guard searchFacetFilter != filter else { return false }
        searchFacetFilter = filter
        refreshSearchFacetDistribution()
        return true
    }

    private func refreshSearchFacetDistribution() {
        guard let searchFacetSnapshot else {
            searchFacetDistribution = nil
            return
        }
        searchFacetDistribution = searchFacetSnapshot.filteredCueIDs(
            using: searchFacetFilter,
            limit: searchFacetSnapshot.cueIDs.count
        ).distribution
    }

    private func setSearchFacetSnapshot(_ snapshot: CueFacetSnapshot?) {
        searchFacetSnapshot = snapshot
        refreshSearchFacetDistribution()
    }

    func setTableProjectionResponseActive(_ isActive: Bool) {
        guard isTableProjectionResponseActive != isActive else {
            return
        }
        isTableProjectionResponseActive = isActive
        guard isActive else {
            return
        }
        if let pendingCueContentChange {
            self.pendingCueContentChange = nil
            refreshReferencedCueContent(pendingCueContentChange)
        }
        if case .residentSearch = tableProjectionSource {
            synchronizeResidentSearchTableProjection()
        }
    }

    private func synchronizeResidentSearchTableProjection() {
        tableRowStore.updateResidentSearchReferences(
            cueIDs: loadedSearchResultCueIDs,
            ranksByCueID: searchRankByCueID,
            cueContentProvider: { [cueContentStore] cueID in
                cueContentStore.content(for: cueID)
            },
            cueContentRevision: cueContentStore.revision,
            sourceRevision: tableProjectionRevision,
            tableName: "test-search",
            probeSurface: .search,
            probeScope: uiProbeScope
        )
    }

    private func receiveCueContentChange(_ change: CueContentStoreChange) {
        guard isTableProjectionResponseActive else {
            pendingCueContentChange = pendingCueContentChange?.merging(change)
                ?? change
            return
        }
        refreshReferencedCueContent(change)
    }

    private func refreshReferencedCueContent(_ change: CueContentStoreChange) {
        tableRowStore.refreshReferencedCueContent(
            change,
            tableName: "test-search",
            probeSurface: .search,
            probeScope: uiProbeScope
        )
    }

    func clearTableProjectionSource() {
        setTableProjectionSource(nil)
    }

    @discardableResult
    func beginIndexedCueDataMutation() -> SearchIndexedCueMutationToken {
        indexedCueMutationGeneration &+= 1
        let token = SearchIndexedCueMutationToken(
            generation: indexedCueMutationGeneration
        )
        activeIndexedCueMutationGeneration = token.generation
        setSearchFacetSnapshot(nil)
        if case .residentSearch = tableProjectionSource {
            return token
        }
        setTableProjectionSource(nil)
        tableRowStore.updateResidentSearchReferences(
            cueIDs: [],
            ranksByCueID: [:],
            cueContentProvider: { [cueContentStore] cueID in
                cueContentStore.content(for: cueID)
            },
            cueContentRevision: cueContentStore.revision,
            tableName: "test-search",
            probeSurface: .search,
            probeScope: uiProbeScope
        )
        return token
    }

    @discardableResult
    func completeIndexedCueDataMutation(
        _ token: SearchIndexedCueMutationToken
    ) -> Bool {
        guard token.generation == activeIndexedCueMutationGeneration else {
            return false
        }
        activeIndexedCueMutationGeneration = nil
        reloadEmptySearchFacetDistribution()
        indexedCueDataRevision &+= 1
        return true
    }

    func reloadEmptySearchFacetDistribution() {
        emptySearchFacetDistribution = try? database?.cueFacetDistribution()
    }

    private func setTableProjectionSource(_ source: SearchTableProjectionSource?) {
        guard tableProjectionSource != source else {
            return
        }
        tableProjectionSource = source
    }

    private(set) var resultFilterSet = SubtitleSearchFilterSet()
    /// The facet filter the current result list was searched with.
    private(set) var resultFacetFilter = CueFacetFilter()

    func updateQuery(_ query: String) {
        let normalizedQuery = SearchInputNormalizer.singleLine(query)
        guard normalizedQuery != searchQuery else { return }
        searchQuery = normalizedQuery
        setSearchFacetSnapshot(nil)
    }

    func markSearchIdle() {
        commitResultMutation {
            searchStatus = .idle
        }
    }

    func markSearchInProgress() {
        commitResultMutation {
            searchStatus = .searching
        }
    }

    func markSearchCompleted() {
        commitResultMutation {
            searchStatus = .completed
        }
    }

    func markSearchFailed(_ message: String, hasMore: Bool? = nil) {
        commitResultMutation {
            searchStatus = .failed(message)
            if let hasMore {
                hasMoreSearchResults = hasMore
            }
        }
    }

    func updateActiveFilterSet(_ filterSet: SubtitleSearchFilterSet) {
        activeFilterSet = filterSet
    }

    func updateNavigationSnapshot(_ snapshot: SearchNavigationSnapshot?) {
        searchNavigationSnapshot = snapshot
    }

    func selectResult(_ result: SubtitleSearchResult?) {
        selectedSearchResult = result
    }

    @discardableResult
    func prepareSearch(
        appending: Bool,
        filterSet: SubtitleSearchFilterSet
    ) -> UInt64 {
        if !appending {
            resultListGeneration &+= 1
            exactCompletionTask?.cancel()
            exactCompletionTask = nil
            resultFilterSet = filterSet
            resultFacetFilter = searchFacetFilter
        }
        searchTask?.cancel()
        return resultListGeneration
    }

    @discardableResult
    func advanceResultListGeneration() -> UInt64 {
        resultListGeneration &+= 1
        return resultListGeneration
    }

    func replaceSearchTask(_ task: Task<Void, Never>?) {
        searchTask = task
    }

    func replaceExactCompletionTask(_ task: Task<Void, Never>?) {
        exactCompletionTask = task
    }

    func replaceNavigationTask(_ task: Task<Void, Never>?) {
        navigationTask = task
    }

    func cancelQueryTasks() {
        searchTask?.cancel()
        searchTask = nil
        exactCompletionTask?.cancel()
        exactCompletionTask = nil
    }

    func cancelAllSearchTasks() {
        cancelQueryTasks()
        navigationTask?.cancel()
        navigationTask = nil
    }

    func cancelCompletionAndNavigationTasks() {
        exactCompletionTask?.cancel()
        exactCompletionTask = nil
        navigationTask?.cancel()
        navigationTask = nil
    }

    func cancelNavigationTask() {
        navigationTask?.cancel()
        navigationTask = nil
    }

    func updateFolderScope(_ folders: [URL]) -> Bool {
        let paths = Self.normalizedFolderPaths(folders)
        guard paths != folderScopePaths else {
            return false
        }
        let didInvalidateActiveSearch = isSearching
        folderScopePaths = paths
        folderScopeGeneration &+= 1
        resultListGeneration &+= 1
        setSearchFacetSnapshot(nil)
        cancelAllSearchTasks()
        return didInvalidateActiveSearch
    }

    func acceptsFolderScope(
        _ folders: [URL],
        generation: UInt64
    ) -> Bool {
        generation == folderScopeGeneration
            && Self.normalizedFolderPaths(folders) == folderScopePaths
    }

    private static func normalizedFolderPaths(_ folders: [URL]) -> [String] {
        folders.map { $0.standardizedFileURL.path }
    }

    func updateActivePerformanceRun(_ run: SearchPerformanceRun?) {
        activePerformanceRun = run
    }

    func replaceResultState(
        results: [SubtitleSearchResult],
        orderedCueIDs: [Int64]? = nil,
        status: SearchStatus,
        totalCount: Int,
        fileSummaries: [SubtitleSearchFileSummary],
        countState: SubtitleSearchCountState,
        knownResultCount: Int,
        knownFileCount: Int,
        hasMore: Bool,
        loadedResultCount: Int? = nil,
        nextCursor: SubtitleSearchCursor? = nil
    ) {
        commitResultMutation {
            setLoadedSearchResults(results, orderedCueIDs: orderedCueIDs)
            searchStatus = status
            searchResultTotalCount = totalCount
            searchFileSummaries = fileSummaries
            searchCountState = countState
            searchKnownResultCount = knownResultCount
            searchKnownFileCount = knownFileCount
            hasMoreSearchResults = hasMore
            loadedGlobalResultCount = loadedResultCount ?? results.count
            nextGlobalCursor = nextCursor
        }
    }

    @discardableResult
    func commitVisibleSearchPage(
        _ page: SubtitleSearchPage,
        appending: Bool,
        offset: Int
    ) -> Bool {
        var completesSearch = false
        commitResultMutation {
            let loadedResultCount: Int
            if appending {
                let existingIDs = Set(searchResults.map(\.entryID))
                let combined = searchResults + page.results.filter {
                    !existingIDs.contains($0.entryID)
                }
                setLoadedSearchResults(combined)
                loadedResultCount = max(
                    loadedGlobalResultCount,
                    offset + page.results.count
                )
            } else {
                setLoadedSearchResults(page.results)
                loadedResultCount = page.results.count
            }
            let preserveExactMetadata = appending
                && searchCountState == .exact
                && page.countState != .exact
            if preserveExactMetadata {
                searchKnownResultCount = max(
                    searchKnownResultCount,
                    page.knownResultCount
                )
                searchKnownFileCount = max(
                    searchKnownFileCount,
                    page.knownFileCount
                )
            } else {
                searchResultTotalCount = page.totalCount
                searchFileSummaries = page.fileSummaries
                searchCountState = page.countState
                searchKnownResultCount = page.knownResultCount
                searchKnownFileCount = page.knownFileCount
            }
            if let facetSnapshot = page.facetSnapshot {
                setSearchFacetSnapshot(facetSnapshot)
            }
            hasMoreSearchResults = page.hasMore
            loadedGlobalResultCount = loadedResultCount
            nextGlobalCursor = page.nextCursor
            completesSearch = page.countState == .exact || preserveExactMetadata
            searchStatus = completesSearch ? .completed : .searching
        }
        return completesSearch
    }

    @discardableResult
    func commitExactSearchPage(
        _ page: SubtitleSearchPage,
        generation: UInt64
    ) -> Bool {
        guard generation == resultListGeneration,
              let facetSnapshot = page.facetSnapshot
        else {
            return false
        }
        commitResultMutation {
            let loadedResultCount: Int
            if !page.renderableResults.isEmpty {
                mergeLoadedSearchResults(
                    page.renderableResults,
                    cueIDs: [],
                    startingAt: page.renderableResultsOffset
                )
                loadedResultCount = loadedSearchResultCueIDs.count
            } else {
                loadedResultCount = loadedGlobalResultCount
            }
            searchResultCueIDs = page.cueIDs
            let hasMore = loadedResultCount < page.totalCount
            searchResultTotalCount = page.totalCount
            searchFileSummaries = page.fileSummaries
            searchCountState = page.countState
            searchKnownResultCount = page.knownResultCount
            searchKnownFileCount = page.knownFileCount
            hasMoreSearchResults = hasMore
            loadedGlobalResultCount = loadedResultCount
            nextGlobalCursor = hasMore
                ? (nextGlobalCursor
                    ?? SubtitleSearchCursor(offset: loadedResultCount))
                : nil
            setSearchFacetSnapshot(facetSnapshot)
            searchStatus = .completed
        }
        return true
    }

    func commitSearchCountProgress(_ progress: SubtitleSearchProgressSnapshot) {
        commitResultMutation {
            let loadedResultCount: Int
            if !progress.results.isEmpty {
                mergeLoadedSearchResults(
                    progress.results,
                    cueIDs: progress.cueIDs,
                    startingAt: progress.resultOffset
                )
                loadedResultCount = loadedSearchResultCueIDs.count
            } else {
                loadedResultCount = loadedGlobalResultCount
            }
            let hasMore = loadedResultCount < progress.knownResultCount
            searchResultTotalCount = progress.knownResultCount
            searchFileSummaries = progress.fileSummaries
            searchCountState = progress.countState
            searchKnownResultCount = progress.knownResultCount
            searchKnownFileCount = progress.knownFileCount
            hasMoreSearchResults = hasMore
            loadedGlobalResultCount = loadedResultCount
            nextGlobalCursor = hasMore
                ? (nextGlobalCursor
                    ?? SubtitleSearchCursor(offset: loadedResultCount))
                : nil
        }
    }

    @discardableResult
    func clearResults() -> Int {
        let releasedRows = max(
            searchResults.count,
            searchResultCueIDs.count,
            searchResultTotalCount
        )
        commitResultMutation {
            setLoadedSearchResults([], orderedCueIDs: [])
            searchResultTotalCount = 0
            searchFileSummaries = []
            searchCountState = .exact
            searchKnownResultCount = 0
            searchKnownFileCount = 0
            hasMoreSearchResults = false
            loadedGlobalResultCount = 0
            nextGlobalCursor = nil
            searchNavigationSnapshot = nil
        }
        return releasedRows
    }

    private func commitResultMutation(_ mutation: () -> Void) {
        mutation()
        resultRevision &+= 1
    }

    var isSearching: Bool {
        if case .searching = searchStatus {
            return true
        }
        return false
    }

    var isFacetSnapshotCalculating: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && searchFacetSnapshot == nil
    }

    var activeFilterSetSignature: String {
        activeFilterSet.cacheSignature
    }

    var resultFilterSetSignature: String {
        resultFilterSet.cacheSignature
    }

}
