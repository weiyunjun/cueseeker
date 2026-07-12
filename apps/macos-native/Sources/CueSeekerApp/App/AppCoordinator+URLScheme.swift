import Foundation
import CueSeekerCore

struct URLSchemeDirectPlayIntent: Equatable, Sendable {
    let id: UUID
    let keyword: String
}

@MainActor
extension AppCoordinator {
    func handleURLSchemeCommand(_ command: URLSchemeCommand) {
        pendingURLSchemeDirectPlayIntent = nil
        searchTask?.cancel()
        searchExactCompletionTask?.cancel()
        searchExactCompletionTask = nil
        if hasPlaybackSelection {
            stopPlayback()
        }

        switch command {
        case let .search(keyword):
            search.activeFilterSet = SubtitleSearchFilterSet()
            search.cueContextSearchRequest = nil
            search.selectedSearchResult = nil
            search.searchNavigationSnapshot = nil
            guard settings.urlSchemePlayFirstSearchResultEnabled else {
                submitSearch(keyword)
                return
            }

            let intent = URLSchemeDirectPlayIntent(id: UUID(), keyword: keyword)
            pendingURLSchemeDirectPlayIntent = intent
            search.searchQuery = keyword
            startSearch(
                query: keyword,
                cursor: .start,
                appending: false,
                debounce: false,
                urlSchemeIntentID: intent.id
            )
        }
    }

    @discardableResult
    func resolveURLSchemeDirectPlayIntent(
        id: UUID?,
        firstPageResult: SubtitleSearchResult?
    ) -> Bool {
        guard let id,
              let intent = pendingURLSchemeDirectPlayIntent,
              intent.id == id,
              search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == intent.keyword
        else {
            return false
        }

        pendingURLSchemeDirectPlayIntent = nil
        workbenchLayout.selectPanelMode(.search)
        guard let firstPageResult else {
            return true
        }
        openSearchResult(firstPageResult)
        return true
    }
}
