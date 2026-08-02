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

struct SearchIndexedCueMutationToken: Equatable {
    let generation: UInt64
}

enum SearchTableProjectionSource: Equatable {
    case residentSearch(revision: UInt64)
    case facetSearch(generation: UInt64)
    case context(requestID: UUID)
}

private enum SearchContextLoadDirection {
    case previous
    case next
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
    private(set) var lastCountProgressUpdate: UInt64 = 0
    private(set) var nextGlobalCursor: SubtitleSearchCursor?
    private var isTableProjectionResponseActive = true
    private var pendingCueContentChange: CueContentStoreChange?
    private(set) var loadedSearchResultCueIDs: [Int64] = []
    private(set) var searchRankByCueID: [Int64: Int] = [:]
    private(set) var tableProjectionRevision: UInt64 = 0
    let tableRowStore: TableSandboxRowModelStore
    private(set) var tableProjectionSource: SearchTableProjectionSource?
    private var facetProjectionGeneration: UInt64 = 0
    private var facetProjectionTask: Task<Void, Never>?
    private(set) var filteredSearchResultCueIDs: [Int64] = []
    private var indexedCueMutationGeneration: UInt64 = 0
    private var activeIndexedCueMutationGeneration: UInt64?
    private var contextLoadGeneration: UInt64 = 0
    private var contextLoadTask: Task<Void, Never>?
    private var activeContextTableRequestID: UUID?
    private var isContextLoadInProgress = false
    private var contextInitialPageSize = TableSandboxHydrationPaging.pageSize
    private var contextContinuationPageSize = 1_000
    private(set) var contextLoadedSourceRange: Range<Int>?
    private(set) var contextTotalRowCount = 0
    private(set) var contextTargetSourceIndex: Int?
    private(set) var contextPrependedRowCount = 0
    private(set) var contextScrollTargetSourceIndex: Int?

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
    @Published private(set) var searchFacetSnapshot: CueFacetSnapshot?
    @Published private(set) var emptySearchFacetDistribution: CueFacetDistribution?
    private(set) var searchFacetFilter = CueFacetFilter()
    @Published private(set) var filteredSearchResultTotalCount: Int?
    @Published private(set) var filteredSearchFacetDistribution: CueFacetDistribution?
    @Published private(set) var searchNavigationSnapshot: SearchNavigationSnapshot?
    @Published private(set) var selectedSearchResult: SubtitleSearchResult?
    @Published private(set) var cueContextSearchRequest: CueContextSearchRequest?
    @Published private(set) var tableLoadRevision: UInt64 = 0
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

    var projectedSearchResults: [SubtitleSearchResult] {
        guard let searchFacetSnapshot else {
            return searchResults
        }
        let cueIDs: [Int64]
        if filteredSearchResultTotalCount != nil {
            cueIDs = filteredSearchResultCueIDs
        } else {
            cueIDs = searchFacetSnapshot.filteredCueIDs(
                using: searchFacetFilter,
                limit: searchFacetSnapshot.cueIDs.count
            ).cueIDs
        }
        return cueIDs.compactMap { cueID in
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
        return filteredSearchFacetDistribution
            ?? searchFacetSnapshot?.distribution
            ?? .zero
    }

    var isDatabaseAvailable: Bool {
        database != nil
    }

    func firstCueID(forSubtitleFile subtitleFile: URL) throws -> Int64? {
        try database?.firstCueID(forSubtitleFile: subtitleFile)
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

    func activateCurrentSearchTableProjection() {
        guard searchFacetSnapshot != nil else {
            activateResidentSearchTableProjection()
            return
        }
        activateFacetSearchTableProjection()
    }

    func updateSearchFacetFilter(_ filter: CueFacetFilter) {
        guard searchFacetFilter != filter else { return }
        searchFacetFilter = filter
        rebuildFacetSearchProjection()
    }

    private func rebuildFacetSearchProjection() {
        facetProjectionTask?.cancel()
        facetProjectionGeneration &+= 1
        let generation = facetProjectionGeneration
        guard let snapshot = searchFacetSnapshot else {
            filteredSearchResultCueIDs = []
            filteredSearchResultTotalCount = nil
            filteredSearchFacetDistribution = nil
            if case .facetSearch = tableProjectionSource {
                activateResidentSearchTableProjection()
            }
            return
        }

        let firstPage = snapshot.filteredCueIDs(
            using: searchFacetFilter,
            limit: TableSandboxHydrationPaging.pageSize
        )
        filteredSearchResultCueIDs = firstPage.cueIDs
        filteredSearchResultTotalCount = firstPage.isComplete
            ? firstPage.distribution.totalCount
            : nil
        if firstPage.isComplete {
            filteredSearchFacetDistribution = firstPage.distribution
        }
        activateFacetSearchTableProjection()

        guard !firstPage.isComplete else { return }
        let filter = searchFacetFilter
        facetProjectionTask = Task { [weak self] in
            var cueIDs = firstPage.cueIDs
            var distribution = firstPage.distribution
            var sourceIndex = firstPage.nextSourceIndex
            var isComplete = false
            while !isComplete {
                await Task.yield()
                guard !Task.isCancelled,
                      let self,
                      self.facetProjectionGeneration == generation,
                      self.searchFacetSnapshot == snapshot,
                      self.searchFacetFilter == filter
                else {
                    return
                }
                let page = snapshot.filteredCueIDs(
                    using: filter,
                    startingAt: sourceIndex,
                    limit: 1_000
                )
                cueIDs.append(contentsOf: page.cueIDs)
                distribution = distribution.adding(page.distribution)
                sourceIndex = page.nextSourceIndex
                isComplete = page.isComplete
                self.filteredSearchResultCueIDs = cueIDs
                if isComplete {
                    self.filteredSearchResultTotalCount = distribution.totalCount
                    self.filteredSearchFacetDistribution = distribution
                }
                self.synchronizeFacetSearchTableProjection()
            }
        }
    }

    private func activateFacetSearchTableProjection() {
        setTableProjectionSource(.facetSearch(generation: facetProjectionGeneration))
        guard isTableProjectionResponseActive else { return }
        synchronizeFacetSearchTableProjection()
    }

    private func synchronizeFacetSearchTableProjection() {
        guard isTableProjectionResponseActive else { return }
        tableRowStore.updateResidentSearchReferences(
            cueIDs: filteredSearchResultCueIDs,
            ranksByCueID: searchRankByCueID,
            cueContentProvider: { [cueContentStore] cueID in
                cueContentStore.content(for: cueID)
            },
            cueContentRevision: cueContentStore.revision,
            tableName: "test-search",
            probeSurface: .search,
            probeScope: uiProbeScope
        )
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
            return
        }
        if case .facetSearch = tableProjectionSource {
            synchronizeFacetSearchTableProjection()
            return
        }
        restoreFolderScopedTableProjection(
            tableProjectionSource,
            folders: folderScopePaths.map { URL(fileURLWithPath: $0) }
        )
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
    func beginContextTableLoad(
        request: CueContextSearchRequest,
        folders: [URL],
        initialPageSize: Int,
        continuationPageSize: Int
    ) -> Bool {
        if activeContextTableRequestID == request.id,
           isContextLoadInProgress || contextLoadedSourceRange != nil {
            return false
        }
        contextInitialPageSize = initialPageSize
        contextContinuationPageSize = continuationPageSize
        activeContextTableRequestID = request.id
        contextLoadGeneration &+= 1
        let generation = contextLoadGeneration
        contextLoadTask?.cancel()
        isContextLoadInProgress = true
        contextLoadedSourceRange = nil
        contextTotalRowCount = 0
        contextTargetSourceIndex = nil
        contextPrependedRowCount = 0
        contextScrollTargetSourceIndex = nil
        activateContextTableProjection(requestID: request.id)

        contextLoadTask = Task { [weak self] in
            guard let self else { return }
            UIInvalidationProbe.count(
                SubtitleTableProbeSurface.context.counterName(
                    "row_hydration_requested"
                ),
                scope: self.uiProbeScope
            )
            guard let page = await self.loadContextRows(
                request: request,
                range: 0..<initialPageSize,
                folders: folders,
                anchorsInitialPage: true
            ),
                  generation == self.contextLoadGeneration,
                  self.cueContextSearchRequest?.id == request.id
            else {
                guard generation == self.contextLoadGeneration else { return }
                self.activeContextTableRequestID = nil
                self.isContextLoadInProgress = false
                self.tableRowStore.updateResidentSearchResults(
                    [],
                    cueContentProvider: { [weak self] cueID in
                        self?.cachedCueContent(for: cueID)
                    },
                    cueContentRevision: self.cachedCueContentRevision,
                    tableName: "test-search",
                    probeSurface: .context,
                    probeScope: self.uiProbeScope
                )
                self.tableLoadRevision &+= 1
                return
            }

            self.applyAllCueSearchContext(page)
            self.tableRowStore.updateResidentSearchResults(
                page.results,
                cueContentProvider: { [weak self] cueID in
                    self?.cachedCueContent(for: cueID)
                },
                cueContentRevision: self.cachedCueContentRevision,
                tableName: "test-search",
                probeSurface: .context,
                probeScope: self.uiProbeScope,
                isHydration: true
            )
            self.contextLoadedSourceRange = page.range
            self.contextTotalRowCount = page.totalRowCount
            self.contextTargetSourceIndex =
                page.results.first { $0.entryID == request.targetCueID }?
                    .searchRank
                ?? page.range.lowerBound
            self.contextScrollTargetSourceIndex = self.contextTargetSourceIndex
            self.isContextLoadInProgress = false
            self.tableLoadRevision &+= 1
            self.loadAdjacentContextRows(
                visibleRows: nil,
                folders: folders,
                pageSize: continuationPageSize,
                prefersPrevious: true
            )
        }
        return true
    }

    func loadAdjacentContextRows(
        visibleRows: Range<Int>?,
        folders: [URL],
        pageSize: Int,
        prefersPrevious: Bool = false
    ) {
        guard let request = cueContextSearchRequest,
              let sourceRange = contextLoadedSourceRange,
              contextTotalRowCount > 0,
              !isContextLoadInProgress
        else {
            return
        }

        let direction: SearchContextLoadDirection
        let scrollSourceIndex: Int?
        if sourceRange.lowerBound > 0,
           prefersPrevious
            || (visibleRows?.lowerBound ?? 0)
                <= TableSandboxHydrationPaging.pageSize {
            direction = .previous
            scrollSourceIndex = prefersPrevious
                ? contextTargetSourceIndex
                : sourceRange.lowerBound + max(0, visibleRows?.lowerBound ?? 0)
        } else if sourceRange.upperBound < contextTotalRowCount,
                  (visibleRows?.upperBound
                    ?? tableRowStore.snapshot.totalRowCount)
                    >= tableRowStore.snapshot.totalRowCount
                        - TableSandboxHydrationPaging.pageSize {
            direction = .next
            scrollSourceIndex = nil
        } else {
            return
        }

        let range: Range<Int>
        switch direction {
        case .previous:
            let lowerBound = max(0, sourceRange.lowerBound - pageSize)
            range = lowerBound..<sourceRange.lowerBound
        case .next:
            let upperBound = min(
                contextTotalRowCount,
                sourceRange.upperBound + pageSize
            )
            range = sourceRange.upperBound..<upperBound
        }
        guard !range.isEmpty else { return }

        let generation = contextLoadGeneration
        isContextLoadInProgress = true
        contextLoadTask = Task { [weak self] in
            guard let self else { return }
            UIInvalidationProbe.count(
                SubtitleTableProbeSurface.context.counterName(
                    "row_hydration_requested"
                ),
                scope: self.uiProbeScope
            )
            guard let page = await self.loadContextRows(
                request: request,
                range: range,
                folders: folders,
                anchorsInitialPage: false
            ),
                  generation == self.contextLoadGeneration,
                  self.cueContextSearchRequest?.id == request.id
            else {
                if generation == self.contextLoadGeneration {
                    self.isContextLoadInProgress = false
                }
                return
            }

            switch direction {
            case .previous:
                guard page.range.upperBound == sourceRange.lowerBound else {
                    self.isContextLoadInProgress = false
                    return
                }
                let prepended = self.tableRowStore.prependResidentSearchResults(
                    page.results,
                    cueContentProvider: { [weak self] cueID in
                        self?.cachedCueContent(for: cueID)
                    },
                    cueContentRevision: self.cachedCueContentRevision,
                    tableName: "test-search",
                    probeSurface: .context,
                    probeScope: self.uiProbeScope
                )
                if prepended > 0 {
                    self.contextLoadedSourceRange =
                        page.range.lowerBound..<sourceRange.upperBound
                    self.contextPrependedRowCount = prepended
                    self.contextScrollTargetSourceIndex = scrollSourceIndex
                }
            case .next:
                guard page.range.lowerBound == sourceRange.upperBound else {
                    self.isContextLoadInProgress = false
                    return
                }
                let appended = self.tableRowStore.appendResidentSearchResults(
                    page.results,
                    cueContentProvider: { [weak self] cueID in
                        self?.cachedCueContent(for: cueID)
                    },
                    cueContentRevision: self.cachedCueContentRevision,
                    tableName: "test-search",
                    probeSurface: .context,
                    probeScope: self.uiProbeScope
                )
                if appended > 0 {
                    self.contextLoadedSourceRange =
                        sourceRange.lowerBound..<page.range.upperBound
                }
            }
            self.isContextLoadInProgress = false
            self.tableLoadRevision &+= 1
        }
    }

    func consumeContextTablePresentation() {
        contextPrependedRowCount = 0
        contextScrollTargetSourceIndex = nil
    }

    func cancelContextTableLoad() {
        contextLoadGeneration &+= 1
        contextLoadTask?.cancel()
        contextLoadTask = nil
        activeContextTableRequestID = nil
        isContextLoadInProgress = false
        contextLoadedSourceRange = nil
        contextTotalRowCount = 0
        contextTargetSourceIndex = nil
        contextPrependedRowCount = 0
        contextScrollTargetSourceIndex = nil
    }

    @discardableResult
    func beginIndexedCueDataMutation() -> SearchIndexedCueMutationToken {
        indexedCueMutationGeneration &+= 1
        let token = SearchIndexedCueMutationToken(
            generation: indexedCueMutationGeneration
        )
        activeIndexedCueMutationGeneration = token.generation
        cueContextSearchRequest = nil
        searchFacetSnapshot = nil
        filteredSearchFacetDistribution = nil
        if case .residentSearch = tableProjectionSource {
            return token
        }
        if case .facetSearch = tableProjectionSource {
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

    func updateQuery(_ query: String) {
        let normalizedQuery = SearchInputNormalizer.singleLine(query)
        guard normalizedQuery != searchQuery else { return }
        searchQuery = normalizedQuery
        searchFacetSnapshot = nil
        filteredSearchFacetDistribution = nil
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

    func updateContextRequest(_ request: CueContextSearchRequest?) {
        cueContextSearchRequest = request
        if request == nil {
            cancelContextTableLoad()
        }
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
            searchFacetSnapshot = nil
            filteredSearchFacetDistribution = nil
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
        let tableProjectionToRestore = tableProjectionSource
        folderScopePaths = paths
        folderScopeGeneration &+= 1
        resultListGeneration &+= 1
        searchFacetSnapshot = nil
        filteredSearchFacetDistribution = nil
        cancelAllSearchTasks()
        cancelContextTableLoad()
        restoreFolderScopedTableProjection(
            tableProjectionToRestore,
            folders: folders
        )
        return didInvalidateActiveSearch
    }

    private func restoreFolderScopedTableProjection(
        _ source: SearchTableProjectionSource?,
        folders: [URL]
    ) {
        guard isTableProjectionResponseActive else {
            return
        }
        switch source {
        case .context(let requestID):
            guard let request = cueContextSearchRequest,
                  request.id == requestID
            else {
                return
            }
            beginContextTableLoad(
                request: request,
                folders: folders,
                initialPageSize: contextInitialPageSize,
                continuationPageSize: contextContinuationPageSize
            )
        case .residentSearch, .facetSearch, nil:
            return
        }
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
                searchFacetSnapshot = facetSnapshot
            }
            hasMoreSearchResults = page.hasMore
            loadedGlobalResultCount = loadedResultCount
            nextGlobalCursor = page.nextCursor
            completesSearch = page.countState == .exact || preserveExactMetadata
            searchStatus = completesSearch ? .completed : .searching
        }
        if page.facetSnapshot != nil {
            rebuildFacetSearchProjection()
        }
        return completesSearch
    }

    @discardableResult
    func commitExactSearchPage(
        _ page: SubtitleSearchPage,
        generation: UInt64
    ) -> Bool {
        guard generation == resultListGeneration,
              let facetSnapshot = page.facetSnapshot,
              facetSnapshot.cueIDs == page.cueIDs,
              facetSnapshot.distribution.totalCount == page.totalCount
        else {
            return false
        }
        commitResultMutation {
            let loadedResultCount: Int
            if !page.renderableResults.isEmpty {
                setLoadedSearchResults(
                    page.renderableResults,
                    orderedCueIDs: page.cueIDs
                )
                loadedResultCount = page.renderableResults.count
            } else {
                searchResultCueIDs = page.cueIDs
                loadedResultCount = loadedGlobalResultCount
            }
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
            searchFacetSnapshot = facetSnapshot
            searchStatus = .completed
        }
        rebuildFacetSearchProjection()
        return true
    }

    func commitSearchCountProgress(_ progress: SubtitleSearchProgressSnapshot) {
        commitResultMutation {
            let loadedResultCount: Int
            if !progress.results.isEmpty {
                setLoadedSearchResults(
                    progress.results,
                    orderedCueIDs: progress.cueIDs
                )
                loadedResultCount = progress.results.count
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

    func acceptsCountProgress(
        at update: UInt64,
        minimumInterval: UInt64
    ) -> Bool {
        if lastCountProgressUpdate != 0,
           update - lastCountProgressUpdate < minimumInterval {
            return false
        }
        lastCountProgressUpdate = update
        return true
    }

    @discardableResult
    func clearResults() -> Int {
        let wasShowingFacetProjection: Bool
        if case .facetSearch = tableProjectionSource {
            wasShowingFacetProjection = true
        } else {
            wasShowingFacetProjection = false
        }
        facetProjectionTask?.cancel()
        facetProjectionGeneration &+= 1
        filteredSearchResultCueIDs = []
        filteredSearchResultTotalCount = nil
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
            lastCountProgressUpdate = 0
            nextGlobalCursor = nil
            searchFacetSnapshot = nil
            filteredSearchFacetDistribution = nil
            searchNavigationSnapshot = nil
        }
        if wasShowingFacetProjection {
            activateResidentSearchTableProjection()
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
