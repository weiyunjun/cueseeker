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
    @Published var searchQuery = ""
    @Published var searchStatus: SearchStatus = .idle
    @Published var searchResults: [SubtitleSearchResult] = []
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

}
