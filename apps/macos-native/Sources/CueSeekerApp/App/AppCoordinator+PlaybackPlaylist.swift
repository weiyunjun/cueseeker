import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
    var activePlaybackSearchPlaylistContext: PlaybackSearchPromotion? {
        guard activePlaybackSource == .search,
              playback.playlistSource?.kind == .search,
              let ordinal = playback.playbackSearchPlaylistOrdinal
        else {
            return nil
        }
        return PlaybackSearchPromotion(
            query: search.searchQuery,
            scopePaths: indexing.selectedFolders.map {
                $0.standardizedFileURL.path
            },
            selectedOrdinal: ordinal
        )
    }

    func playbackPlaylistBoundaryDidChange(
        _ boundary: PlaybackPlaylistSourceBoundary?
    ) {
        guard let boundary,
              let context = activePlaybackSearchPlaylistContext,
              playback.playlistSource?.boundary.datasetID == boundary.datasetID,
              search.selectedSearchResult != nil
        else {
            return
        }
        let ordinal = context.selectedOrdinal
        setPlaybackChromeSnapshot(
            displayTitle: playback.chromeSnapshot.displayTitle,
            canGoPrevious: ordinal > 0 && ordinal < boundary.totalCount,
            canGoNext: ordinal + 1 < boundary.totalCount
        )
    }

    func makePlaybackRecentSessionStore() -> PlaybackRecentSessionStore {
        PlaybackRecentSessionStore(
            libraryStore: library,
            requestSource: { [weak self] in
                self?.hydrateTestRecentWatchingAsync()
            }
        )
    }

    func makePlaybackLibrarySessionStore() -> PlaybackLibrarySessionStore {
        PlaybackLibrarySessionStore(
            libraryStore: library,
            requestFolders: { [weak self] in
                self?.hydrateCompleteLibraryAsync()
            },
            requestFolderDetail: { [weak self] folderPath in
                self?.hydrateCompleteLibraryFolderDetailAsync(
                    folderPath: folderPath
                )
            }
        )
    }

    func openAdjacentPlaybackSearchPlaylistResult(
        _ direction: SearchResultNavigationDirection,
        context: PlaybackSearchPromotion
    ) {
        guard activePlaybackSource == .search,
              playback.playlistSource?.kind == .search,
              let selectedResult = search.selectedSearchResult,
              playback.playbackSearchPlaylistOrdinal == context.selectedOrdinal
        else {
            playback.playbackViewModel?.showSearchNavigationFeedback(
                direction: direction,
                hasResult: false
            )
            return
        }

        let anchorOrdinal = context.selectedOrdinal
        let targetOrdinal = anchorOrdinal + (direction == .previous ? -1 : 1)
        guard search.searchResults.indices.contains(anchorOrdinal),
              search.searchResults[anchorOrdinal].entryID == selectedResult.entryID,
              targetOrdinal >= 0,
              search.searchResults.indices.contains(targetOrdinal)
        else {
            playback.playbackViewModel?.showSearchNavigationFeedback(
                direction: direction,
                hasResult: false
            )
            return
        }

        playback.playbackViewModel?.showSearchNavigationFeedback(
            direction: direction,
            hasResult: true
        )
        openSearchResult(
            search.searchResults[targetOrdinal],
            playbackSearchPromotion: PlaybackSearchPromotion(
                query: context.query,
                scopePaths: context.scopePaths,
                selectedOrdinal: targetOrdinal
            )
        )
    }

    func installSearchPlaybackPlaylistSource(
        seed result: SubtitleSearchResult
    ) {
        let resultListGeneration = searchResultListGeneration
        let origin = PlaybackPlaylistSourceOrigin.search(
            resultListGeneration: resultListGeneration
        )
        let selectedOrdinal = search.searchResults.firstIndex {
            $0.entryID == result.entryID
        }
        if let source = playback.playlistSource,
           source.origin == origin {
            _ = source.updateBoundary(totalCount: search.searchResults.count)
            playback.setPlaylistSource(
                source,
                playbackSearchSelectedOrdinal: selectedOrdinal
            )
            return
        }

        let source = PlaybackPlaylistSource(
            origin: origin,
            totalCount: search.searchResults.count
        ) { @MainActor [weak self] ordinal in
            guard let self,
                  self.searchResultListGeneration == resultListGeneration,
                  self.search.searchResults.indices.contains(ordinal)
            else {
                return nil
            }
            return PlaybackPlaylistItem(
                searchResult: self.search.searchResults[ordinal],
                ordinal: ordinal
            )
        }
        playback.setPlaylistSource(
            source,
            playbackSearchSelectedOrdinal: selectedOrdinal
        )
    }

    func refreshSearchPlaybackPlaylistSource(
        resultListGeneration: UInt64
    ) {
        let origin = PlaybackPlaylistSourceOrigin.search(
            resultListGeneration: resultListGeneration
        )
        guard let source = playback.playlistSource,
              source.origin == origin
        else {
            return
        }

        _ = source.updateBoundary(totalCount: search.searchResults.count)
    }

    func installShioriPlaybackPlaylistSource(
        scope requestedScope: PlaybackPlaylistShioriScope? = nil
    ) {
        let scope: PlaybackPlaylistShioriScope
        if let requestedScope {
            scope = requestedScope
        } else if let scopeIDs = shioriPlaybackNavigationScopeIDs {
            scope = .explicitIDs(scopeIDs)
        } else {
            scope = .databaseOrder
        }
        let totalCount = shioriPlaybackPlaylistCount(scope: scope)
        let origin = PlaybackPlaylistSourceOrigin.shiori(scope: scope)
        if let source = playback.playlistSource,
           source.origin == origin {
            _ = source.updateBoundary(totalCount: totalCount)
            return
        }

        let source = PlaybackPlaylistSource(
            origin: origin,
            totalCount: totalCount
        ) { @MainActor [weak self] ordinal in
            self?.shioriPlaybackPlaylistItem(
                scope: scope,
                ordinal: ordinal
            )
        }
        playback.setPlaylistSource(source)
    }

    func refreshShioriPlaybackPlaylistSource() {
        guard let source = playback.playlistSource,
              case .shiori(let scope) = source.origin
        else {
            return
        }
        _ = source.updateBoundary(
            totalCount: shioriPlaybackPlaylistCount(scope: scope)
        )
    }

    private func shioriPlaybackPlaylistCount(
        scope: PlaybackPlaylistShioriScope
    ) -> Int {
        switch scope {
        case .explicitIDs(let shioriIDs):
            shioriIDs.count
        case .databaseOrder:
            shiori.shioris.count
        case .table(let context):
            min(
                context.totalCount,
                shiori.tableRowStore.snapshot.totalRowCount
            )
        }
    }

    private func shioriPlaybackPlaylistItem(
        scope: PlaybackPlaylistShioriScope,
        ordinal: Int
    ) -> PlaybackPlaylistItem? {
        switch scope {
        case .table:
            return shioriTablePlaybackItem(ordinal: ordinal)
        case .databaseOrder:
            guard shiori.shioris.indices.contains(ordinal) else {
                return nil
            }
            return PlaybackPlaylistItem(
                shiori: shiori.shioris[ordinal],
                cuePresentation: nil,
                ordinal: ordinal
            )
        case .explicitIDs(let shioriIDs):
            guard shioriIDs.indices.contains(ordinal) else {
                return nil
            }
            let shioriID = shioriIDs[ordinal]
            let snapshot = shiori.tableRowStore.snapshot
            if let rowOrdinal = snapshot.rows.firstIndex(where: {
                $0.id == Int(shioriID)
            }) {
                return shioriTablePlaybackItem(
                    ordinal: rowOrdinal,
                    itemOrdinal: ordinal
                )
            }
            guard let item = shiori.shioris.first(where: {
                $0.id == shioriID
            }) else {
                return nil
            }
            return PlaybackPlaylistItem(
                shiori: item,
                cuePresentation: nil,
                ordinal: ordinal
            )
        }
    }

    private func shioriTablePlaybackItem(
        ordinal: Int,
        itemOrdinal: Int? = nil
    ) -> PlaybackPlaylistItem? {
        let snapshot = shiori.tableRowStore.snapshot
        guard let row = snapshot.row(at: ordinal),
              let item = snapshot.shiori(entryID: row.id)
        else {
            return nil
        }
        return PlaybackPlaylistItem(
            shiori: item,
            cuePresentation: snapshot.shioriCuePresentation(entryID: row.id),
            ordinal: itemOrdinal ?? ordinal
        )
    }

}
