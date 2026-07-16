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
        PlaybackRecentSessionStore(loader: .live(
            databaseURL: databaseURL,
            folders: indexing.selectedFolders
        ), sourceRevision: { [weak self] in
            self?.library.recentWatchingRevision ?? 0
        })
    }

    func makePlaybackLibrarySessionStore() -> PlaybackLibrarySessionStore {
        PlaybackLibrarySessionStore(
            loader: .live(
                databaseURL: databaseURL,
                folders: indexing.selectedFolders
            ),
            sourceRevision: { [weak self] in
                PlaybackLibrarySourceRevision(
                    folders: self?.library.completeLibraryRevision ?? 0,
                    playbackHistory:
                        self?.library.libraryPlaybackHistoryRevision ?? 0
                )
            }
        )
    }

    func makePlaybackShioriOverlaySource() -> PlaybackCueResultSource {
        let totalCount = subtitleDatabase.flatMap {
            try? $0.shioriCount()
        } ?? 0
        let databaseReader = playbackSubtitleFocusDatabaseReader

        return PlaybackCueResultSource(
            kind: .shiori,
            totalCount: totalCount,
            knownItemIDsByOrdinal: [:]
        ) { request in
            do {
                let page = try await databaseReader.shioriPage(
                    limit: request.ordinalRange.count,
                    offset: request.ordinalRange.lowerBound
                )
                guard !Task.isCancelled,
                      page.shioris.count == request.ordinalRange.count
                else {
                    return nil
                }
                let items = zip(request.ordinalRange, page.shioris).map {
                    PlaybackCueResultItem(
                        shiori: $1,
                        cuePresentation: page.cuePresentationsByShioriID[$1.id],
                        ordinal: $0
                    )
                }
                return PlaybackCueResultSourceWindowResponse(
                    request: request,
                    items: items
                )
            } catch is CancellationError {
                return nil
            } catch {
                print("Failed to load Playback Shiori window: \(error)")
                return nil
            }
        }
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
            _ = source.updateBoundary(
                totalCount: search.searchResults.count,
                knownItemIDsByOrdinal: [:]
            )
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

        _ = source.updateBoundary(
            totalCount: search.searchResults.count,
            knownItemIDsByOrdinal: [:]
        )
    }

    func installShioriPlaybackPlaylistSource(
        scope requestedScope: PlaybackPlaylistShioriScope? = nil
    ) {
        let scope: PlaybackPlaylistShioriScope
        let totalCount: Int
        let knownItemIDsByOrdinal: [Int: PlaybackPlaylistItemIdentity]
        let stableItemIdentities: [PlaybackPlaylistItemIdentity]?
        if let requestedScope {
            scope = requestedScope
        } else if let scopeIDs = shioriPlaybackNavigationScopeIDs {
            scope = .explicitIDs(scopeIDs)
        } else {
            scope = .databaseOrder
        }
        switch scope {
        case .explicitIDs(let scopeIDs):
            totalCount = scopeIDs.count
            let explicitIdentities = scopeIDs.map(
                PlaybackPlaylistItemIdentity.shiori
            )
            stableItemIdentities = explicitIdentities
            knownItemIDsByOrdinal = Dictionary(uniqueKeysWithValues:
                explicitIdentities.enumerated().map {
                    ($0.offset, $0.element)
                }
            )
        case .databaseOrder:
            totalCount = subtitleDatabase.flatMap {
                try? $0.shioriCount()
            } ?? 0
            knownItemIDsByOrdinal = [:]
            stableItemIdentities = nil
        case .table(let context):
            totalCount = context.totalCount
            let tableIDs = shioriPlaybackNavigationScopeIDs ?? []
            let tableIdentities = tableIDs.map(
                PlaybackPlaylistItemIdentity.shiori
            )
            stableItemIdentities = tableIdentities.count == totalCount
                ? tableIdentities
                : nil
            knownItemIDsByOrdinal = Dictionary(uniqueKeysWithValues:
                tableIdentities.prefix(totalCount).enumerated().map {
                    ($0.offset, $0.element)
                }
            )
        }
        let origin = PlaybackPlaylistSourceOrigin.shiori(scope: scope)
        if let source = playback.playlistSource,
           source.origin == origin {
            if case .table = scope {
                return
            }
            _ = source.updateBoundary(
                totalCount: totalCount,
                knownItemIDsByOrdinal: knownItemIDsByOrdinal
            )
            return
        }

        let databaseReader = playbackSubtitleFocusDatabaseReader
        let source = PlaybackPlaylistSource(
            origin: origin,
            totalCount: totalCount,
            knownItemIDsByOrdinal: knownItemIDsByOrdinal,
            stableItemIdentities: stableItemIdentities
        ) { @MainActor [weak self] request in
            guard let self,
                  self.playback.playlistSource?.origin == origin
            else {
                return nil
            }

            do {
                let page: ShioriPage
                let expectedShioriIDs: [Int64]?
                switch scope {
                case .explicitIDs(let scopeIDs):
                    let requestedIDs = Array(scopeIDs[request.ordinalRange])
                    expectedShioriIDs = requestedIDs
                    page = try await databaseReader.shioriPage(
                        shioriIDs: requestedIDs
                    )
                case .databaseOrder:
                    expectedShioriIDs = nil
                    page = try await databaseReader.shioriPage(
                        limit: request.ordinalRange.count,
                        offset: request.ordinalRange.lowerBound
                    )
                case .table:
                    guard let stableItemIdentities else {
                        return nil
                    }
                    let requestedIDs = stableItemIdentities[request.ordinalRange]
                        .compactMap { identity -> Int64? in
                            guard case .shiori(let shioriID) = identity else {
                                return nil
                            }
                            return shioriID
                        }
                    guard requestedIDs.count == request.ordinalRange.count else {
                        return nil
                    }
                    expectedShioriIDs = requestedIDs
                    page = try await databaseReader.shioriPage(
                        shioriIDs: requestedIDs
                    )
                }
                guard !Task.isCancelled,
                      self.playback.playlistSource?.origin == origin,
                      page.shioris.count == request.ordinalRange.count,
                      expectedShioriIDs.map({
                          page.shioris.map(\.id) == $0
                      }) ?? true
                else {
                    return nil
                }
                let items = zip(request.ordinalRange, page.shioris).map {
                    PlaybackPlaylistItem(
                        shiori: $1,
                        cuePresentation: page.cuePresentationsByShioriID[$1.id],
                        ordinal: $0
                    )
                }
                return PlaybackPlaylistSourceWindowResponse(
                    request: request,
                    items: items
                )
            } catch is CancellationError {
                return nil
            } catch {
                print("Failed to load Shiori playback Playlist window: \(error)")
                return nil
            }
        }
        playback.setPlaylistSource(source)
    }

}
