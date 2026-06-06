import Foundation
import CueSeekerCore

@MainActor
final class SearchStore: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchStatus: SearchStatus = .idle
    @Published var searchResults: [SubtitleSearchResult] = []
    @Published var searchResultTotalCount = 0
    @Published var searchFileSummaries: [SubtitleSearchFileSummary] = []
    @Published var searchCountState: SubtitleSearchCountState = .exact
    @Published var searchKnownResultCount = 0
    @Published var searchKnownFileCount = 0
    @Published var hasMoreSearchResults = false
    @Published var collapsedSearchResultGroupPaths: Set<String> = []
    @Published var searchResultPresentationState: SearchResultPresentationState = .initial
    @Published var searchResultGroups: [SearchResultFileGroup] = []
    @Published var renderedSearchResultCount = 0
    @Published var searchNavigationSnapshot: SearchNavigationSnapshot?
    @Published var searchNavigationResultGroups: [SearchResultFileGroup] = []
    @Published var searchNavigationVisibleResults: [SubtitleSearchResult] = []
    @Published var searchNavigationVisibleWindowStartIndex = 0
    @Published var searchNavigationVisibleTotalCount = 0
    @Published var searchNavigationVisibleRowsVersion = 0
    @Published var expandedSearchResultGroupRowsByPath: [String: [SubtitleSearchResult]] = [:]
    @Published var selectedSearchResult: SubtitleSearchResult?

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

    var searchNavigationVisibleWindowRange: Range<Int> {
        return searchNavigationVisibleWindowStartIndex..<(searchNavigationVisibleWindowStartIndex + searchNavigationVisibleResults.count)
    }

    func searchNavigationVisibleResult(at row: Int) -> SubtitleSearchResult? {
        let localIndex = row - searchNavigationVisibleWindowStartIndex
        guard localIndex >= 0, localIndex < searchNavigationVisibleResults.count else {
            return nil
        }
        return searchNavigationVisibleResults[localIndex]
    }

    func applySearchNavigationVisibleWindow(
        _ results: [SubtitleSearchResult],
        startIndex: Int,
        totalCount: Int
    ) {
        searchNavigationVisibleResults = results
        searchNavigationVisibleWindowStartIndex = max(0, startIndex)
        searchNavigationVisibleTotalCount = max(totalCount, results.count)
        searchNavigationVisibleRowsVersion += 1
    }

    func resetSearchNavigationVisibleWindow() {
        searchNavigationVisibleResults = []
        searchNavigationVisibleWindowStartIndex = 0
        searchNavigationVisibleTotalCount = 0
        searchNavigationVisibleRowsVersion += 1
    }
}
