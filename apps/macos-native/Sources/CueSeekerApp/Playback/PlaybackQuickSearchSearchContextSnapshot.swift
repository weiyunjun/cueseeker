import CueSeekerCore
import Foundation

@MainActor
struct PlaybackQuickSearchSearchContextSnapshot {
    let panelMode: WorkbenchPanelMode
    let searchQuery: String
    let searchStatus: SearchStatus
    let searchResults: [SubtitleSearchResult]
    let searchResultCueGroupIDs: [Int64]
    let searchResultTotalCount: Int
    let searchFileSummaries: [SubtitleSearchFileSummary]
    let searchCountState: SubtitleSearchCountState
    let searchKnownResultCount: Int
    let searchKnownFileCount: Int
    let hasMoreSearchResults: Bool
    let collapsedSearchResultGroupPaths: Set<String>
    let searchResultPresentationState: SearchResultPresentationState
    let searchResultGroups: [SearchResultFileGroup]
    let renderedSearchResultCount: Int
    let searchNavigationSnapshot: SearchNavigationSnapshot?
    let expandedSearchResultGroupRowsByPath: [String: [SubtitleSearchResult]]
    let selectedSearchResult: SubtitleSearchResult?
    let loadedGlobalSearchResultCount: Int
    let lastSearchCountProgressUpdate: UInt64
    let nextGlobalSearchCursor: SubtitleSearchCursor?
    let activeSearchPerformanceRun: SearchPerformanceRun?
    let pendingSearchVisibleEntryIDs: Set<Int64>

    init(appState: AppCoordinator) {
        panelMode = appState.workbenchLayout.panelMode
        searchQuery = appState.search.searchQuery
        searchStatus = appState.search.searchStatus
        searchResults = appState.search.searchResults
        searchResultCueGroupIDs = appState.search.searchResultCueGroupIDs
        searchResultTotalCount = appState.search.searchResultTotalCount
        searchFileSummaries = appState.search.searchFileSummaries
        searchCountState = appState.search.searchCountState
        searchKnownResultCount = appState.search.searchKnownResultCount
        searchKnownFileCount = appState.search.searchKnownFileCount
        hasMoreSearchResults = appState.search.hasMoreSearchResults
        collapsedSearchResultGroupPaths = appState.search.collapsedSearchResultGroupPaths
        searchResultPresentationState = appState.search.searchResultPresentationState
        searchResultGroups = appState.search.searchResultGroups
        renderedSearchResultCount = appState.search.renderedSearchResultCount
        searchNavigationSnapshot = appState.search.searchNavigationSnapshot
        expandedSearchResultGroupRowsByPath = appState.search.expandedSearchResultGroupRowsByPath
        selectedSearchResult = appState.search.selectedSearchResult
        loadedGlobalSearchResultCount = appState.loadedGlobalSearchResultCount
        lastSearchCountProgressUpdate = appState.lastSearchCountProgressUpdate
        nextGlobalSearchCursor = appState.nextGlobalSearchCursor
        activeSearchPerformanceRun = appState.activeSearchPerformanceRun
        pendingSearchVisibleEntryIDs = appState.pendingSearchVisibleEntryIDs
    }

    func restore(to appState: AppCoordinator) {
        appState.workbenchLayout.selectPanelMode(panelMode)
        appState.search.searchQuery = searchQuery
        appState.search.searchStatus = searchStatus
        appState.search.searchResults = searchResults
        appState.search.searchResultCueGroupIDs = searchResultCueGroupIDs
        appState.search.searchResultTotalCount = searchResultTotalCount
        appState.search.searchFileSummaries = searchFileSummaries
        appState.search.searchCountState = searchCountState
        appState.search.searchKnownResultCount = searchKnownResultCount
        appState.search.searchKnownFileCount = searchKnownFileCount
        appState.search.hasMoreSearchResults = hasMoreSearchResults
        appState.search.collapsedSearchResultGroupPaths = collapsedSearchResultGroupPaths
        appState.search.searchResultPresentationState = searchResultPresentationState
        appState.search.searchResultGroups = searchResultGroups
        appState.search.renderedSearchResultCount = renderedSearchResultCount
        appState.search.searchNavigationSnapshot = searchNavigationSnapshot
        appState.search.expandedSearchResultGroupRowsByPath = expandedSearchResultGroupRowsByPath
        appState.search.selectedSearchResult = selectedSearchResult
        appState.loadedGlobalSearchResultCount = loadedGlobalSearchResultCount
        appState.lastSearchCountProgressUpdate = lastSearchCountProgressUpdate
        appState.nextGlobalSearchCursor = nextGlobalSearchCursor
        appState.activeSearchPerformanceRun = activeSearchPerformanceRun
        appState.pendingSearchVisibleEntryIDs = pendingSearchVisibleEntryIDs
    }
}
