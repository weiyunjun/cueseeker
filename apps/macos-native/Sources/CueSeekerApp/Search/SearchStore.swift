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
    @Published var activeFilterSet = SubtitleSearchFilterSet()
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
    @Published var activeSearchNavigationEntryID: Int64?
    @Published var activeSearchNavigationRank: Int?
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

    var activeFilterSetSignature: String {
        activeFilterSet.cacheSignature
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
        activeSearchNavigationEntryID = nil
        activeSearchNavigationRank = nil
        searchNavigationVisibleRowsVersion += 1
    }

    func applyActiveSearchNavigationResult(_ result: SubtitleSearchResult?) {
        activeSearchNavigationEntryID = result?.entryID
        activeSearchNavigationRank = result?.searchRank
    }

    func updateActiveSearchNavigationResult(
        videoPath: String?,
        subtitlePath: String?,
        currentMilliseconds: Int
    ) {
        let result = activeSearchNavigationResult(
            videoPath: videoPath,
            subtitlePath: subtitlePath,
            currentMilliseconds: currentMilliseconds
        )
        let nextEntryID = result?.entryID
        let nextRank = result?.searchRank
        guard activeSearchNavigationEntryID != nextEntryID
            || activeSearchNavigationRank != nextRank
        else {
            return
        }

        activeSearchNavigationEntryID = nextEntryID
        activeSearchNavigationRank = nextRank
    }

    func activeSearchNavigationResult(
        videoPath: String?,
        subtitlePath: String?,
        currentMilliseconds: Int
    ) -> SubtitleSearchResult? {
        guard let videoPath else {
            return searchNavigationSnapshot?.current ?? selectedSearchResult
        }

        let normalizedVideoPath = Self.normalizedPath(videoPath)
        let normalizedSubtitlePath = subtitlePath.map(Self.normalizedPath)
        let boundedMilliseconds = max(0, currentMilliseconds)
        let candidates = loadedSearchNavigationCandidates()

        return candidates
            .filter { result in
                Self.normalizedPath(result.videoPath) == normalizedVideoPath
                    && (
                        normalizedSubtitlePath == nil
                            || Self.normalizedPath(result.subtitlePath) == normalizedSubtitlePath
                    )
                    && result.startMilliseconds <= boundedMilliseconds
            }
            .max { lhs, rhs in
                if lhs.startMilliseconds != rhs.startMilliseconds {
                    return lhs.startMilliseconds < rhs.startMilliseconds
                }
                return lhs.searchRank < rhs.searchRank
            }
            ?? searchNavigationSnapshot?.current
            ?? selectedSearchResult
    }

    private func loadedSearchNavigationCandidates() -> [SubtitleSearchResult] {
        var resultsByEntryID: [Int64: SubtitleSearchResult] = [:]
        for result in searchNavigationSnapshot?.neighborhood ?? [] {
            resultsByEntryID[result.entryID] = result
        }
        for result in searchNavigationVisibleResults {
            resultsByEntryID[result.entryID] = result
        }
        if let current = searchNavigationSnapshot?.current {
            resultsByEntryID[current.entryID] = current
        }
        if let selectedSearchResult {
            resultsByEntryID[selectedSearchResult.entryID] = selectedSearchResult
        }
        return Array(resultsByEntryID.values)
    }

    private static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
