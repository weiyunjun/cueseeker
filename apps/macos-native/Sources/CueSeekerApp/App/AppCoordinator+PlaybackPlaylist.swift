import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
    var isCueDeepLinkPlaybackSource: Bool {
        guard let source = playback.playlistSource,
              case .cue = source.origin
        else {
            return false
        }
        return true
    }

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
        guard let boundary else {
            clearCueAutoStopPlayback()
            return
        }
        guard playback.validatePlaylistPosition() else {
            clearCueAutoStopPlayback()
            return
        }
        guard let context = activePlaybackSearchPlaylistContext,
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

    func currentShioriPlaylistAdjacentOrdinal(
        for shiori: Shiori,
        direction: ShioriNavigationDirection
    ) -> Int? {
        guard let source = playback.playlistSource,
              let position = playback.playlistPosition,
              position.datasetID == source.boundary.datasetID,
              position.itemIdentity == .shiori(shiori.id)
        else {
            return nil
        }
        return position.ordinal + (direction == .previous ? -1 : 1)
    }

    func makePlaybackRecentSessionStore() -> PlaybackRecentSessionStore {
        PlaybackRecentSessionStore(
            libraryStore: library,
            requestSource: { [weak self] in
                self?.hydrateTestRecentWatchingAsync()
            }
        )
    }

    func makePlaybackLibrarySessionStore(
        folderPath: String
    ) -> PlaybackLibrarySessionStore {
        PlaybackLibrarySessionStore(
            libraryStore: library,
            folderPath: folderPath,
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
              let source = playback.playlistSource,
              source.kind == .search,
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
        guard let anchorItem = source.item(at: anchorOrdinal),
              case .search(let anchorResult) = anchorItem.target,
              anchorResult.entryID == selectedResult.entryID,
              targetOrdinal >= 0,
              let targetItem = source.item(at: targetOrdinal),
              case .search(let targetResult) = targetItem.target
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
            targetResult,
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
        let residentResults = search.searchResults
        let selectedOrdinal = residentResults.firstIndex {
            $0.entryID == result.entryID
        }
        if let source = playback.playlistSource,
           source.origin == origin {
            _ = source.replaceResidentItems(
                totalCount: residentResults.count,
                itemProvider: Self.searchPlaylistItemProvider(
                    results: residentResults
                )
            )
            playback.setPlaylistSource(
                source,
                playbackSearchSelectedOrdinal: selectedOrdinal
            )
            return
        }

        let source = PlaybackPlaylistSource(
            origin: origin,
            totalCount: residentResults.count,
            itemProvider: Self.searchPlaylistItemProvider(
                results: residentResults
            )
        )
        playback.setPlaylistSource(
            source,
            playbackSearchSelectedOrdinal: selectedOrdinal
        )
    }

    func makeCueDeepLinkPlaybackPlaylistSource(
        result: SubtitleSearchResult
    ) -> PlaybackPlaylistSource {
        PlaybackPlaylistSource(
            origin: .cue(cueID: result.entryID),
            totalCount: 1
        ) { ordinal in
            guard ordinal == 0 else {
                return nil
            }
            return PlaybackPlaylistItem(searchResult: result, ordinal: 0)
        }
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

        let residentResults = search.searchResults
        _ = source.replaceResidentItems(
            totalCount: residentResults.count,
            itemProvider: Self.searchPlaylistItemProvider(
                results: residentResults
            )
        )
    }

    private static func searchPlaylistItemProvider(
        results: [SubtitleSearchResult]
    ) -> PlaybackPlaylistSharedItemProvider {
        { ordinal in
            guard results.indices.contains(ordinal) else {
                return nil
            }
            return PlaybackPlaylistItem(
                searchResult: results[ordinal],
                ordinal: ordinal
            )
        }
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
            if shiori.residentDataRevision != nil {
                shiori.residentShiorisByID.values.filter(\.isValid).count
            } else {
                (try? shioriDatabase?.shioris().filter(\.isValid).count) ?? 0
            }
        case .table(let context):
            min(context.totalCount, shiori.playbackTableResultShioriIDs?.count ?? 0)
        }
    }

    private func shioriPlaybackPlaylistItem(
        scope: PlaybackPlaylistShioriScope,
        ordinal: Int
    ) -> PlaybackPlaylistItem? {
        switch scope {
        case .table:
            guard let shioriIDs = shiori.playbackTableResultShioriIDs,
                  shioriIDs.indices.contains(ordinal)
            else {
                return nil
            }
            return shioriTablePlaybackItem(
                shioriID: shioriIDs[ordinal],
                itemOrdinal: ordinal
            )
        case .databaseOrder:
            let items: [Shiori]
            if shiori.residentDataRevision != nil {
                items = shiori.residentRelations.compactMap {
                    shiori.residentShiorisByID[$0.id]
                }.filter(\.isValid)
            } else {
                items = (try? shioriDatabase?.shioris())?.filter(\.isValid) ?? []
            }
            guard items.indices.contains(ordinal) else {
                return nil
            }
            let item = items[ordinal]
            let cueID = shiori.residentRelations.first {
                $0.id == item.id
            }?.cueID ?? (try? shioriDatabase?.cueID(forShioriID: item.id)) ?? nil
            return PlaybackPlaylistItem(
                shiori: item,
                cuePresentation: cueID.flatMap(cueContent.content(for:))
                    .map(ShioriCuePresentation.init(cueContent:)),
                ordinal: ordinal
            )
        case .explicitIDs(let shioriIDs):
            guard shioriIDs.indices.contains(ordinal) else {
                return nil
            }
            let shioriID = shioriIDs[ordinal]
            let snapshot = shiori.tableRowStore.snapshot
            if snapshot.rowIndex(entryID: Int(shioriID)) != nil {
                return shioriTablePlaybackItem(
                    shioriID: shioriID,
                    itemOrdinal: ordinal
                )
            }
            guard let item = shiori(withID: shioriID), item.isValid else {
                return nil
            }
            return PlaybackPlaylistItem(
                shiori: item,
                cuePresentation: shiori.residentRelations
                    .first { $0.id == shioriID }
                    .flatMap { cueContent.content(for: $0.cueID) }
                    .map(ShioriCuePresentation.init(cueContent:)),
                ordinal: ordinal
            )
        }
    }

    private func shioriTablePlaybackItem(
        shioriID: Int64,
        itemOrdinal: Int? = nil
    ) -> PlaybackPlaylistItem? {
        let snapshot = shiori.tableRowStore.snapshot
        guard let entryID = Int(exactly: shioriID),
              let rowOrdinal = snapshot.rowIndex(entryID: entryID),
              let row = snapshot.row(at: rowOrdinal),
              let item = snapshot.shiori(entryID: row.id),
              item.isValid
        else {
            return nil
        }
        return PlaybackPlaylistItem(
            shiori: item,
            cuePresentation: snapshot.shioriCuePresentation(entryID: row.id),
            ordinal: itemOrdinal ?? rowOrdinal
        )
    }

}
