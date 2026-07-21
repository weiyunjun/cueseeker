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

@MainActor
final class SearchStore: ObservableObject {
    private let cueContentStore: CueContentStore
    private var cueContentChangesCancellable: AnyCancellable?
    private let uiProbeScope: String?
    private(set) var loadedSearchResultCueIDs: [Int64] = []
    private(set) var searchRankByCueID: [Int64: Int] = [:]
    private(set) var tableProjectionRevision: UInt64 = 0
    let tableRowStore: TableSandboxRowModelStore

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
    @Published var collapsedSearchResultGroupPaths: Set<String> = []
    @Published var searchResultPresentationState: SearchResultPresentationState = .initial
    @Published var searchResultGroups: [SearchResultFileGroup] = []
    @Published var renderedSearchResultCount = 0
    @Published var searchNavigationSnapshot: SearchNavigationSnapshot?
    @Published var expandedSearchResultGroupRowsByPath: [String: [SubtitleSearchResult]] = [:]
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
            [weak tableRowStore] change in
            tableRowStore?.refreshReferencedCueContent(
                change,
                tableName: "test-search",
                probeSurface: .search,
                probeScope: uiProbeScope
            )
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
    }

    var resultFilterSet = SubtitleSearchFilterSet()
    var isPlaybackTemporaryFilterActive = false

    var isSearching: Bool {
        if case .searching = searchStatus {
            return true
        }
        return false
    }

    var hasSearchResultGroups: Bool {
        !searchResultGroups.isEmpty
    }

    var searchResultFileCount: Int {
        searchFileSummaries.count
    }

    var canCollapseAllSearchResultGroups: Bool {
        hasSearchResultGroups
            && !isSearching
            && searchStatus == .completed
            && searchCountState == .exact
            && searchResultPresentationState != .collapsed
            && !searchFileSummaries.isEmpty
    }

    var shouldShowSearchGlobalLoadMoreTrigger: Bool {
        searchResultPresentationState != .collapsed && hasMoreSearchResults
    }

    var activeFilterSetSignature: String {
        activeFilterSet.cacheSignature
    }

    var resultFilterSetSignature: String {
        resultFilterSet.cacheSignature
    }

}
