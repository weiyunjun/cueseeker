import Combine
import Foundation
import CueSeekerCore

struct CueContextSearchRequest: Equatable, Identifiable {
    let id: UUID
    let displayTitle: String
    let subtitlePath: String
    let targetCueID: Int64

    init(
        id: UUID = UUID(),
        displayTitle: String,
        subtitlePath: String,
        targetCueID: Int64
    ) {
        self.id = id
        self.displayTitle = displayTitle
        self.subtitlePath = subtitlePath
        self.targetCueID = targetCueID
    }
}

struct SearchFilterOnlyProjectionKey: Equatable {
    let filterSignature: String
    let folderPaths: [String]
    let indexedCueDataRevision: UInt64

    init(
        filterSignature: String,
        folderPaths: [String],
        indexedCueDataRevision: UInt64 = 0
    ) {
        self.filterSignature = filterSignature
        self.folderPaths = folderPaths
        self.indexedCueDataRevision = indexedCueDataRevision
    }
}

struct SearchIndexedCueMutationToken: Equatable {
    let generation: UInt64
}

struct SearchFilterOnlyLoadToken: Equatable {
    let key: SearchFilterOnlyProjectionKey
    let generation: UInt64
    let startIndex: Int
}

enum SearchTableProjectionSource: Equatable {
    case residentSearch(revision: UInt64)
    case filterOnly(SearchFilterOnlyProjectionKey)
    case context(requestID: UUID)
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
    private(set) var loadedGlobalResultCount = 0
    private(set) var lastCountProgressUpdate: UInt64 = 0
    private(set) var nextGlobalCursor: SubtitleSearchCursor?
    private var isTableProjectionResponseActive = true
    private var pendingCueContentChange: CueContentStoreChange?
    private(set) var loadedSearchResultCueIDs: [Int64] = []
    private(set) var searchRankByCueID: [Int64: Int] = [:]
    private(set) var tableProjectionRevision: UInt64 = 0
    let tableRowStore: TableSandboxRowModelStore
    private(set) var tableProjectionSource: SearchTableProjectionSource?
    private var filterOnlyLoadGeneration: UInt64 = 0
    private var isFilterOnlyLoadInProgress = false
    private var hasLoadedFilterOnlyInitialPage = false
    private var filterOnlyTotalRowCount = 0
    private var indexedCueMutationGeneration: UInt64 = 0
    private var activeIndexedCueMutationGeneration: UInt64?

    @Published private(set) var indexedCueDataRevision: UInt64 = 0
    @Published private(set) var searchQuery = ""
    @Published private(set) var searchStatus: SearchStatus = .idle
    @Published private(set) var searchResultCueIDs: [Int64] = []
    @Published private(set) var searchResultTotalCount = 0
    @Published private(set) var searchFileSummaries: [SubtitleSearchFileSummary] = []
    @Published private(set) var searchCountState: SubtitleSearchCountState = .exact
    @Published private(set) var searchKnownResultCount = 0
    @Published private(set) var searchKnownFileCount = 0
    @Published private(set) var hasMoreSearchResults = false
    @Published private(set) var activeFilterSet = SubtitleSearchFilterSet()
    @Published private(set) var searchNavigationSnapshot: SearchNavigationSnapshot?
    @Published private(set) var selectedSearchResult: SubtitleSearchResult?
    @Published private(set) var cueContextSearchRequest: CueContextSearchRequest?
    @Published var tableSearchDraft = ""
    @Published var tableVisibleColumnIDs = SchemaWorkbenchSearchDefaults.initialVisibleColumnIDs
    @Published var tableActiveFilterSetID = SchemaWorkbenchSearchDefaults.defaultFilterSetID
    @Published var tableFilterRules = SchemaWorkbenchSearchDefaults.defaultFilterRules
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
        tableRowStore = TableSandboxRowModelStore()
        cueContentChangesCancellable = cueContentStore.changes.sink {
            [weak self] change in
            self?.receiveCueContentChange(change)
        }
    }

    private(set) var searchResults: [SubtitleSearchResult] {
        get {
            loadedSearchResultCueIDs.compactMap { cueID in
                cueContentStore.content(for: cueID).map {
                    SubtitleSearchResult(
                        cueContent: $0,
                        searchRank: searchRankByCueID[cueID] ?? 0
                    )
                }
            }
        }
        set {
            replaceLoadedSearchResults(newValue)
        }
    }

    func replaceLoadedSearchResults(
        _ results: [SubtitleSearchResult],
        orderedCueIDs: [Int64]? = nil
    ) {
        objectWillChange.send()
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

    func activateResidentSearchTableProjection() {
        setTableProjectionSource(.residentSearch(revision: tableProjectionRevision))
        guard isTableProjectionResponseActive else {
            return
        }
        synchronizeResidentSearchTableProjection()
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

    func activateContextTableProjection(requestID: UUID) {
        setTableProjectionSource(.context(requestID: requestID))
    }

    func clearTableProjectionSource() {
        setTableProjectionSource(nil)
    }

    @discardableResult
    func prepareFilterOnlyTableProjection(
        key: SearchFilterOnlyProjectionKey
    ) -> Bool {
        let source = SearchTableProjectionSource.filterOnly(key)
        guard tableProjectionSource != source else {
            return false
        }
        setTableProjectionSource(source)
        return true
    }

    func beginFilterOnlyPageLoad(
        key: SearchFilterOnlyProjectionKey,
        loadedRowCount: Int
    ) -> SearchFilterOnlyLoadToken? {
        guard tableProjectionSource == .filterOnly(key),
              !isFilterOnlyLoadInProgress
        else {
            return nil
        }
        if hasLoadedFilterOnlyInitialPage,
           loadedRowCount >= filterOnlyTotalRowCount {
            return nil
        }
        isFilterOnlyLoadInProgress = true
        return SearchFilterOnlyLoadToken(
            key: key,
            generation: filterOnlyLoadGeneration,
            startIndex: hasLoadedFilterOnlyInitialPage ? loadedRowCount : 0
        )
    }

    func acceptsFilterOnlyPageLoad(_ token: SearchFilterOnlyLoadToken) -> Bool {
        tableProjectionSource == .filterOnly(token.key)
            && filterOnlyLoadGeneration == token.generation
            && isFilterOnlyLoadInProgress
    }

    @discardableResult
    func completeFilterOnlyPageLoad(
        _ token: SearchFilterOnlyLoadToken,
        totalRowCount: Int,
        loadedRowCount: Int
    ) -> Bool {
        guard acceptsFilterOnlyPageLoad(token) else {
            return false
        }
        isFilterOnlyLoadInProgress = false
        hasLoadedFilterOnlyInitialPage = true
        filterOnlyTotalRowCount = max(0, totalRowCount)
        return loadedRowCount < filterOnlyTotalRowCount
    }

    func failFilterOnlyPageLoad(_ token: SearchFilterOnlyLoadToken) {
        guard acceptsFilterOnlyPageLoad(token) else {
            return
        }
        isFilterOnlyLoadInProgress = false
    }

    func suspendFilterOnlyPageLoad() {
        guard isFilterOnlyLoadInProgress else {
            return
        }
        filterOnlyLoadGeneration &+= 1
        isFilterOnlyLoadInProgress = false
    }

    @discardableResult
    func beginIndexedCueDataMutation() -> SearchIndexedCueMutationToken {
        indexedCueMutationGeneration &+= 1
        let token = SearchIndexedCueMutationToken(
            generation: indexedCueMutationGeneration
        )
        activeIndexedCueMutationGeneration = token.generation
        cueContextSearchRequest = nil
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
        indexedCueDataRevision &+= 1
        return true
    }

    private func setTableProjectionSource(_ source: SearchTableProjectionSource?) {
        guard tableProjectionSource != source else {
            return
        }
        tableProjectionSource = source
        filterOnlyLoadGeneration &+= 1
        isFilterOnlyLoadInProgress = false
        hasLoadedFilterOnlyInitialPage = false
        filterOnlyTotalRowCount = 0
    }

    private(set) var resultFilterSet = SubtitleSearchFilterSet()
    private(set) var isPlaybackTemporaryFilterActive = false

    func updateQuery(_ query: String) {
        searchQuery = query
    }

    func updateStatus(_ status: SearchStatus) {
        searchStatus = status
    }

    func updateActiveFilterSet(_ filterSet: SubtitleSearchFilterSet) {
        activeFilterSet = filterSet
    }

    func activatePlaybackTemporaryFilter() {
        isPlaybackTemporaryFilterActive = true
    }

    func deactivatePlaybackTemporaryFilter() {
        isPlaybackTemporaryFilterActive = false
    }

    func finishPlaybackTemporaryFilter(
        committingEmptyFilter: Bool
    ) -> SubtitleSearchFilterSet? {
        guard isPlaybackTemporaryFilterActive else {
            return nil
        }
        isPlaybackTemporaryFilterActive = false
        if committingEmptyFilter {
            let emptyFilterSet = SubtitleSearchFilterSet()
            activeFilterSet = emptyFilterSet
            resultFilterSet = emptyFilterSet
            return nil
        }
        return resultFilterSetSignature == activeFilterSetSignature
            ? nil
            : activeFilterSet
    }

    func updateNavigationSnapshot(_ snapshot: SearchNavigationSnapshot?) {
        searchNavigationSnapshot = snapshot
    }

    func selectResult(_ result: SubtitleSearchResult?) {
        selectedSearchResult = result
    }

    func updateContextRequest(_ request: CueContextSearchRequest?) {
        cueContextSearchRequest = request
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

    func updateActivePerformanceRun(_ run: SearchPerformanceRun?) {
        activePerformanceRun = run
    }

    func updateResultCueIDs(_ cueIDs: [Int64]) {
        searchResultCueIDs = cueIDs
    }

    func publishResultMetadata(
        totalCount: Int,
        fileSummaries: [SubtitleSearchFileSummary],
        countState: SubtitleSearchCountState,
        knownResultCount: Int,
        knownFileCount: Int,
        hasMore: Bool
    ) {
        searchResultTotalCount = totalCount
        searchFileSummaries = fileSummaries
        searchCountState = countState
        searchKnownResultCount = knownResultCount
        searchKnownFileCount = knownFileCount
        hasMoreSearchResults = hasMore
    }

    func publishKnownCounts(resultCount: Int, fileCount: Int) {
        searchKnownResultCount = resultCount
        searchKnownFileCount = fileCount
    }

    func updateHasMoreResults(_ hasMore: Bool) {
        hasMoreSearchResults = hasMore
    }

    func updatePagination(
        loadedResultCount: Int,
        nextCursor: SubtitleSearchCursor?
    ) {
        loadedGlobalResultCount = loadedResultCount
        nextGlobalCursor = nextCursor
    }

    func updateNextGlobalCursor(_ cursor: SubtitleSearchCursor?) {
        nextGlobalCursor = cursor
    }

    func updateLastCountProgress(_ update: UInt64) {
        lastCountProgressUpdate = update
    }

    @discardableResult
    func clearResults() -> Int {
        let releasedRows = max(
            searchResults.count,
            searchResultCueIDs.count,
            searchResultTotalCount
        )
        searchResults = []
        searchResultCueIDs = []
        publishResultMetadata(
            totalCount: 0,
            fileSummaries: [],
            countState: .exact,
            knownResultCount: 0,
            knownFileCount: 0,
            hasMore: false
        )
        loadedGlobalResultCount = 0
        lastCountProgressUpdate = 0
        nextGlobalCursor = nil
        searchNavigationSnapshot = nil
        return releasedRows
    }

    func appendLoadedResults(_ results: [SubtitleSearchResult]) {
        let existingEntryIDs = Set(searchResults.map(\.entryID))
        searchResults = searchResults
            + results.filter { !existingEntryIDs.contains($0.entryID) }
    }

    func revealInitialGlobalPage(limit: Int) {
        searchResults = Array(searchResults.prefix(limit))
        let loadedResultCount = searchResults.count
        publishKnownCounts(
            resultCount: searchResultTotalCount,
            fileCount: searchFileSummaries.count
        )
        let hasMore = loadedResultCount < searchResultTotalCount
        hasMoreSearchResults = hasMore
        updatePagination(
            loadedResultCount: loadedResultCount,
            nextCursor: hasMore
                ? SubtitleSearchCursor(offset: loadedResultCount)
                : nil
        )
    }

    var isSearching: Bool {
        if case .searching = searchStatus {
            return true
        }
        return false
    }

    var activeFilterSetSignature: String {
        activeFilterSet.cacheSignature
    }

    var resultFilterSetSignature: String {
        resultFilterSet.cacheSignature
    }

}
