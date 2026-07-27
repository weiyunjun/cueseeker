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
    @Published var searchQuery = ""
    @Published var searchStatus: SearchStatus = .idle
    @Published var searchResultCueIDs: [Int64] = []
    @Published var searchResultTotalCount = 0
    @Published var searchFileSummaries: [SubtitleSearchFileSummary] = []
    @Published var searchCountState: SubtitleSearchCountState = .exact
    @Published var searchKnownResultCount = 0
    @Published var searchKnownFileCount = 0
    @Published var hasMoreSearchResults = false
    @Published var activeFilterSet = SubtitleSearchFilterSet()
    @Published var searchNavigationSnapshot: SearchNavigationSnapshot?
    @Published var selectedSearchResult: SubtitleSearchResult?
    @Published var cueContextSearchRequest: CueContextSearchRequest?
    @Published var tableSearchDraft = ""
    @Published var tableVisibleColumnIDs = SchemaWorkbenchSearchDefaults.initialVisibleColumnIDs
    @Published var tableActiveFilterSetID = SchemaWorkbenchSearchDefaults.defaultFilterSetID
    @Published var tableFilterRules = SchemaWorkbenchSearchDefaults.defaultFilterRules
    var tableViewportAnchor: TableViewportAnchor?
    var tableSelectionState = TableSandboxRowSelectionState()
    var tableSelectionEntryIDs: [Int] = []

    init(
        cueContentStore: CueContentStore = CueContentStore(),
        uiProbeScope: String? = nil
    ) {
        self.cueContentStore = cueContentStore
        self.uiProbeScope = uiProbeScope
        tableRowStore = TableSandboxRowModelStore()
        cueContentChangesCancellable = cueContentStore.changes.sink {
            [weak self] change in
            self?.receiveCueContentChange(change)
        }
    }

    var searchResults: [SubtitleSearchResult] {
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

    var resultFilterSet = SubtitleSearchFilterSet()
    var isPlaybackTemporaryFilterActive = false

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
