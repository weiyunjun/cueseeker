import Foundation
import CueSeekerCore

struct URLSchemeDirectPlayIntent {
    let id: UUID
    let keyword: String
    let onPresentationReady: @MainActor () -> Void

    init(
        id: UUID,
        keyword: String,
        onPresentationReady: @escaping @MainActor () -> Void = {}
    ) {
        self.id = id
        self.keyword = keyword
        self.onPresentationReady = onPresentationReady
    }
}

struct URLSchemeCuePlaybackIntent {
    let id: UUID
    let cueID: Int64
    let onPresentationReady: @MainActor () -> Void

    init(
        id: UUID,
        cueID: Int64,
        onPresentationReady: @escaping @MainActor () -> Void = {}
    ) {
        self.id = id
        self.cueID = cueID
        self.onPresentationReady = onPresentationReady
    }
}

@MainActor
extension AppCoordinator {
    func handleURLSchemeCommand(
        _ command: URLSchemeCommand,
        onPresentationReady: @escaping @MainActor () -> Void = {}
    ) {
        pendingURLSchemeDirectPlayIntent = nil
        pendingURLSchemeCuePlaybackIntent = nil
        urlSchemeCueLookupTask?.cancel()
        urlSchemeCueLookupTask = nil
        search.cancelQueryTasks()

        switch command {
        case let .search(keyword):
            search.updateActiveFilterSet(SubtitleSearchFilterSet())
            search.updateContextRequest(nil)
            search.updateNavigationSnapshot(nil)
            guard settings.urlSchemePlayFirstSearchResultEnabled else {
                presentURLSchemeSearch(
                    keyword: keyword,
                    startsSearch: true,
                    onPresentationReady: onPresentationReady
                )
                return
            }

            if !hasPlaybackSelection {
                search.selectResult(nil)
            }

            let intent = URLSchemeDirectPlayIntent(
                id: UUID(),
                keyword: keyword,
                onPresentationReady: onPresentationReady
            )
            pendingURLSchemeDirectPlayIntent = intent
            search.updateQuery(keyword)
            startSearch(
                query: keyword,
                cursor: .start,
                appending: false,
                debounce: false,
                urlSchemeIntentID: intent.id
            )
        case let .cue(cueID):
            let intent = URLSchemeCuePlaybackIntent(
                id: UUID(),
                cueID: cueID,
                onPresentationReady: onPresentationReady
            )
            pendingURLSchemeCuePlaybackIntent = intent
            let lookupDatabaseURL = databaseURL
            urlSchemeCueLookupTask = Task { @MainActor [weak self] in
                let result: SubtitleSearchResult?
                do {
                    result = try await Self.runCancellableDetached(
                        priority: .userInitiated
                    ) {
                        let database = try SearchDatabase(
                            path: lookupDatabaseURL,
                            access: .readOnly
                        )
                        return try database.cuePlaybackResult(cueID: cueID)
                    }
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }
                    print("Failed to resolve URL Scheme CueID: \(error)")
                    result = nil
                }

                guard !Task.isCancelled else {
                    return
                }
                _ = self?.resolveURLSchemeCuePlaybackIntent(
                    id: intent.id,
                    result: result
                )
            }
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
        guard let firstPageResult else {
            presentURLSchemeSearch(
                keyword: intent.keyword,
                startsSearch: false,
                onPresentationReady: intent.onPresentationReady
            )
            return true
        }
        openSearchResult(firstPageResult, returnPanelMode: .search)
        intent.onPresentationReady()
        return true
    }

    @discardableResult
    func resolveURLSchemeCuePlaybackIntent(
        id: UUID,
        result: SubtitleSearchResult?
    ) -> Bool {
        guard let intent = pendingURLSchemeCuePlaybackIntent,
              intent.id == id,
              result?.entryID == intent.cueID || result == nil
        else {
            return false
        }

        pendingURLSchemeCuePlaybackIntent = nil
        urlSchemeCueLookupTask = nil
        guard let result else {
            intent.onPresentationReady()
            return true
        }

        let playlistSource = makeCueDeepLinkPlaybackPlaylistSource(
            result: result
        )
        openSearchResult(
            result,
            returnPanelMode: .search,
            playlistSourceOverride: playlistSource
        )
        playbackReturnContext = .search
        intent.onPresentationReady()
        return true
    }

    private func presentURLSchemeSearch(
        keyword: String,
        startsSearch: Bool,
        onPresentationReady: @escaping @MainActor () -> Void
    ) {
        search.updateQuery(keyword)
        search.updateNavigationSnapshot(nil)
        let hadActivePlayback = isPlaybackPageVisible

        if hadActivePlayback,
           presentPlaybackCommandPanelSearch(
               query: keyword,
               startsSearch: startsSearch
           ) {
            onPresentationReady()
            return
        }

        search.deactivatePlaybackTemporaryFilter()
        if !hadActivePlayback {
            search.selectResult(nil)
        }
        workbenchLayout.selectPanelMode(.search)
        if startsSearch {
            submitSearch(keyword)
        }
        onPresentationReady()
    }
}
