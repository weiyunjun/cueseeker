import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
    var activePlaybackSearchPlaylistContext: PlaybackSearchPromotion? {
        guard activePlaybackSource == .search,
              let source = playback.playlistSource,
              let ordinal = playback.playbackSearchPlaylistOrdinal
        else {
            return nil
        }
        return PlaybackSearchPromotion(
            source: source,
            selectedOrdinal: ordinal
        )
    }

    func playbackPlaylistBoundaryDidChange(
        _ boundary: PlaybackPlaylistSourceBoundary?
    ) {
        guard let boundary,
              let context = activePlaybackSearchPlaylistContext,
              context.source.boundary.datasetID == boundary.datasetID,
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

    func makePlaybackSearchSessionStore() -> PlaybackSearchSessionStore {
        PlaybackSearchSessionStore(configuration: PlaybackSearchConfiguration(
            databaseURL: databaseURL,
            folders: indexing.selectedFolders,
            languageFilter: settings.primarySearchLanguage.searchLanguageFilter,
            watchStateFilter: settings.searchScope.searchWatchStateFilter,
            filterSet: search.activeFilterSet,
            pageSize: Self.searchPageSize
        ))
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
        playbackSearchPlaylistNavigationTask?.cancel()

        guard activePlaybackSearchPlaylistContext?.source === context.source,
              let selectedResult = search.selectedSearchResult
        else {
            playback.playbackViewModel?.showSearchNavigationFeedback(
                direction: direction,
                hasResult: false
            )
            return
        }

        let anchorEntryID = selectedResult.entryID
        let anchorOrdinal = context.selectedOrdinal
        let targetOrdinal = anchorOrdinal + (direction == .previous ? -1 : 1)
        let source = context.source
        guard anchorOrdinal < source.boundary.totalCount,
              targetOrdinal >= 0,
              targetOrdinal < source.boundary.totalCount
        else {
            playback.playbackViewModel?.showSearchNavigationFeedback(
                direction: direction,
                hasResult: false
            )
            return
        }

        playbackSearchPlaylistNavigationTask = Task { @MainActor [weak self, weak source] in
            guard let self, let source else {
                return
            }

            var targetResult: SubtitleSearchResult?
            while !Task.isCancelled {
                guard !Task.isCancelled,
                      self.activePlaybackSearchPlaylistContext?.source === source,
                      self.search.selectedSearchResult?.entryID == anchorEntryID,
                      self.playback.playbackSearchPlaylistOrdinal == anchorOrdinal
                else {
                    return
                }

                let boundary = source.boundary
                guard targetOrdinal < boundary.totalCount else {
                    break
                }
                let range = PlaybackVirtualReelWindowPolicy.standard.windowRange(
                    totalCount: boundary.totalCount,
                    targetOrdinal: targetOrdinal
                )
                let request = PlaybackPlaylistSourceWindowRequest(
                    datasetID: boundary.datasetID,
                    generation: boundary.generation,
                    sourceRevision: boundary.revision,
                    totalCount: boundary.totalCount,
                    ordinalRange: range
                )
                if let response = await source.loadWindow(request),
                   let item = response.items.first(where: {
                       $0.ordinal == targetOrdinal
                   }),
                   case .search(let result) = item.target,
                   source.boundary.datasetID == response.datasetID,
                   source.boundary.generation == response.generation,
                   source.boundary.revision == response.sourceRevision,
                   source.boundary.totalCount == response.totalCount {
                    targetResult = result
                    break
                }
                guard source.boundary != boundary else {
                    break
                }
                await Task.yield()
            }

            guard !Task.isCancelled,
                  self.activePlaybackSearchPlaylistContext?.source === source,
                  self.search.selectedSearchResult?.entryID == anchorEntryID,
                  self.playback.playbackSearchPlaylistOrdinal == anchorOrdinal,
                  let targetResult,
                  let currentContext = PlaybackSearchPromotion(
                      source: source,
                      selectedOrdinal: targetOrdinal
                  )
            else {
                if !Task.isCancelled {
                    self.playback.playbackViewModel?.showSearchNavigationFeedback(
                        direction: direction,
                        hasResult: false
                    )
                }
                return
            }

            self.playback.playbackViewModel?.showSearchNavigationFeedback(
                direction: direction,
                hasResult: true
            )
            self.openSearchResult(
                targetResult,
                playbackSearchPromotion: currentContext
            )
        }
    }

    func installSearchPlaybackPlaylistSource(
        seed result: SubtitleSearchResult
    ) {
        let resultListGeneration = searchResultListGeneration
        let origin = PlaybackPlaylistSourceOrigin.search(
            resultListGeneration: resultListGeneration
        )
        let boundary = searchPlaybackPlaylistBoundary(seed: result)
        if let source = playback.playlistSource,
           source.origin == origin {
            _ = source.updateBoundary(
                totalCount: boundary.totalCount,
                knownItemIDsByOrdinal: boundary.knownItemIDsByOrdinal
            )
            return
        }

        let source = PlaybackPlaylistSource(
            origin: origin,
            totalCount: boundary.totalCount,
            knownItemIDsByOrdinal: boundary.knownItemIDsByOrdinal
        ) { @MainActor [weak self] request in
            guard let self,
                  self.searchResultListGeneration == resultListGeneration,
                  self.playback.playlistSource?.origin == origin
            else {
                return nil
            }

            if let items = self.loadedSearchPlaybackPlaylistItems(
                in: request.ordinalRange
            ) {
                return PlaybackPlaylistSourceWindowResponse(
                    request: request,
                    items: items
                )
            }

            let page: TableSandboxSearchHydrationPage?
            if self.search.searchQuery.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                page = await self.loadTableSandboxAllCueRows(
                    range: request.ordinalRange
                )
            } else {
                page = await self.loadTableSandboxSearchRows(
                    range: request.ordinalRange
                )
            }
            guard !Task.isCancelled,
                  self.searchResultListGeneration == resultListGeneration,
                  self.playback.playlistSource?.origin == origin,
                  let page,
                  page.range == request.ordinalRange,
                  page.results.count == request.ordinalRange.count
            else {
                return nil
            }
            let items = zip(request.ordinalRange, page.results).map {
                PlaybackPlaylistItem(searchResult: $1, ordinal: $0)
            }
            return PlaybackPlaylistSourceWindowResponse(
                request: request,
                items: items
            )
        }
        playback.setPlaylistSource(source)
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

        let boundary = searchPlaybackPlaylistBoundary(
            seed: search.selectedSearchResult
        )
        _ = source.updateBoundary(
            totalCount: boundary.totalCount,
            knownItemIDsByOrdinal: boundary.knownItemIDsByOrdinal
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

    private func searchPlaybackPlaylistBoundary(
        seed: SubtitleSearchResult?
    ) -> (
        totalCount: Int,
        knownItemIDsByOrdinal: [Int: PlaybackPlaylistItemIdentity]
    ) {
        var knownIDs: [Int: PlaybackPlaylistItemIdentity] = [:]
        var maximumOrdinal = -1
        for result in search.searchResults {
            let ordinal = max(0, result.searchRank)
            knownIDs[ordinal] = .search(result.entryID)
            maximumOrdinal = max(maximumOrdinal, ordinal)
        }
        if let seed {
            let ordinal = max(0, seed.searchRank)
            knownIDs[ordinal] = .search(seed.entryID)
            maximumOrdinal = max(maximumOrdinal, ordinal)
        }
        return (
            totalCount: max(
                search.searchResultTotalCount,
                maximumOrdinal + 1
            ),
            knownItemIDsByOrdinal: knownIDs
        )
    }

    private func loadedSearchPlaybackPlaylistItems(
        in range: Range<Int>
    ) -> [PlaybackPlaylistItem]? {
        var items: [PlaybackPlaylistItem] = []
        items.reserveCapacity(range.count)
        for ordinal in range {
            let indexedResult = search.searchResults.indices.contains(ordinal)
                ? search.searchResults[ordinal]
                : nil
            let result: SubtitleSearchResult?
            if let indexedResult,
               max(0, indexedResult.searchRank) == ordinal {
                result = indexedResult
            } else if let selectedResult = search.selectedSearchResult,
                      max(0, selectedResult.searchRank) == ordinal {
                result = selectedResult
            } else {
                result = nil
            }
            guard let result else {
                return nil
            }
            items.append(PlaybackPlaylistItem(
                searchResult: result,
                ordinal: ordinal
            ))
        }
        return items
    }
}
