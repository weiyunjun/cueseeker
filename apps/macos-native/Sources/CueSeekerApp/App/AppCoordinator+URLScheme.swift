import CueSeekerCore

@MainActor
extension AppCoordinator {
    func handleURLSchemeCommand(_ command: URLSchemeCommand) {
        switch command {
        case let .search(keyword):
            if hasPlaybackSelection {
                stopPlayback()
            }
            search.activeFilterSet = SubtitleSearchFilterSet()
            search.cueContextSearchRequest = nil
            search.selectedSearchResult = nil
            search.searchNavigationSnapshot = nil
            submitSearch(keyword)
        }
    }
}
