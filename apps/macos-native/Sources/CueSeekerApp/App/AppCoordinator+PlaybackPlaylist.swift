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
            scopePaths: indexing.selectedFolders.map(\.mediaPath),
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
        // The item playing left the library and so the playlist; it plays on
        // with its Auto Pause and Auto Switch.
        guard playback.validatePlaylistPosition()
                || currentPlaybackItemLeftLibrary
        else {
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

    func currentExcerptPlaylistAdjacentOrdinal(
        for excerpt: Excerpt,
        direction: ExcerptNavigationDirection
    ) -> Int? {
        guard let source = playback.playlistSource,
              let position = playback.playlistPosition,
              position.datasetID == source.boundary.datasetID,
              position.itemIdentity == .excerpt(excerpt.id)
        else {
            return nil
        }
        return position.ordinal + (direction == .previous ? -1 : 1)
    }

    func makePlaybackLibrarySessionStore(
        folderPath: String,
        initialVideoPath: String
    ) -> PlaybackLibrarySessionStore {
        PlaybackLibrarySessionStore(
            libraryStore: library,
            folderPath: folderPath,
            initialVideoPath: initialVideoPath,
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

    func synchronizeSearchAndPlaylistOnPlayback(
        seed result: SubtitleSearchResult
    ) {
        search.activatePlaybackPruning()
        let candidateCueIDs = search.searchResultCueIDs.isEmpty
            ? search.searchResults.map(\.entryID)
            : search.searchResultCueIDs
        let liveCueIDs: Set<Int64>
        if search.hasMutatedSinceSearchSnapshot || !isCueInLibrary(result.entryID) {
            liveCueIDs = cueIDsInLibrary(among: candidateCueIDs)
        } else {
            liveCueIDs = Set(candidateCueIDs)
        }
        search.pruneInvalidSearchResults(liveCueIDs: liveCueIDs)
        installSearchPlaybackPlaylistSource(seed: result)
    }

    func installSearchPlaybackPlaylistSource(
        seed result: SubtitleSearchResult
    ) {
        let resultListGeneration = search.resultListGeneration
        let origin = PlaybackPlaylistSourceOrigin.search(
            resultListGeneration: resultListGeneration
        )
        let liveCueIDs: Set<Int64>
        if search.hasMutatedSinceSearchSnapshot || !isCueInLibrary(result.entryID) {
            liveCueIDs = cueIDsInLibrary(among: search.searchResults.map(\.entryID))
        } else {
            liveCueIDs = Set(search.searchResults.map(\.entryID))
        }
        let playlistResults = search.searchResults.filter { liveCueIDs.contains($0.entryID) }
        let selectedOrdinal = playlistResults.firstIndex {
            $0.entryID == result.entryID
        }
        if let source = playback.playlistSource,
           source.origin == origin,
           !source.isHeld {
            _ = source.replaceResidentItems(
                totalCount: playlistResults.count,
                itemProvider: Self.searchPlaylistItemProvider(
                    results: playlistResults
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
            totalCount: playlistResults.count,
            itemProvider: Self.searchPlaylistItemProvider(
                results: playlistResults
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
        guard let source = playback.playlistSource,
              case .search(let sourceGeneration) = source.origin,
              sourceGeneration == resultListGeneration
        else {
            return
        }

        let playlistResults: [SubtitleSearchResult]
        if search.hasMutatedSinceSearchSnapshot {
            let liveCueIDs = cueIDsInLibrary(among: search.searchResults.map(\.entryID))
            playlistResults = search.searchResults.filter { liveCueIDs.contains($0.entryID) }
        } else {
            playlistResults = search.searchResults
        }
        _ = source.replaceResidentItems(
            totalCount: playlistResults.count,
            itemProvider: Self.searchPlaylistItemProvider(
                results: playlistResults
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

    func installExcerptPlaybackPlaylistSource(
        scope requestedScope: PlaybackPlaylistExcerptScope? = nil
    ) {
        let scope: PlaybackPlaylistExcerptScope
        if let requestedScope {
            scope = requestedScope
        } else if let scopeIDs = excerptPlaybackNavigationScopeIDs {
            scope = .explicitIDs(scopeIDs)
        } else {
            scope = .databaseOrder
        }
        let totalCount = excerptPlaybackPlaylistCount(scope: scope)
        let origin = PlaybackPlaylistSourceOrigin.excerpt(scope: scope)
        if let source = playback.playlistSource,
           source.origin == origin {
            _ = source.updateBoundary(totalCount: totalCount)
            return
        }

        let source = PlaybackPlaylistSource(
            origin: origin,
            totalCount: totalCount
        ) { @MainActor [weak self] ordinal in
            self?.excerptPlaybackPlaylistItem(
                scope: scope,
                ordinal: ordinal
            )
        }
        playback.setPlaylistSource(source)
    }

    func refreshExcerptPlaybackPlaylistSource() {
        guard let source = playback.playlistSource,
              case .excerpt(let scope) = source.origin
        else {
            return
        }
        _ = source.updateBoundary(
            totalCount: excerptPlaybackPlaylistCount(scope: scope)
        )
    }

    private func excerptPlaybackPlaylistCount(
        scope: PlaybackPlaylistExcerptScope
    ) -> Int {
        switch scope {
        case .explicitIDs(let excerptIDs):
            excerptIDs.count
        case .databaseOrder:
            if excerpt.residentDataRevision != nil {
                excerpt.residentExcerptsByID.values.filter(\.isValid).count
            } else {
                (try? excerptDatabase?.excerpts().filter(\.isValid).count) ?? 0
            }
        case .table(let context):
            min(context.totalCount, excerpt.playbackTableResultExcerptIDs?.count ?? 0)
        }
    }

    private func excerptPlaybackPlaylistItem(
        scope: PlaybackPlaylistExcerptScope,
        ordinal: Int
    ) -> PlaybackPlaylistItem? {
        switch scope {
        case .table:
            guard let excerptIDs = excerpt.playbackTableResultExcerptIDs,
                  excerptIDs.indices.contains(ordinal)
            else {
                return nil
            }
            return excerptTablePlaybackItem(
                excerptID: excerptIDs[ordinal],
                itemOrdinal: ordinal
            )
        case .databaseOrder:
            let items: [Excerpt]
            if excerpt.residentDataRevision != nil {
                items = excerpt.residentRelations.compactMap {
                    excerpt.residentExcerptsByID[$0.id]
                }.filter(\.isValid)
            } else {
                items = (try? excerptDatabase?.excerpts())?.filter(\.isValid) ?? []
            }
            guard items.indices.contains(ordinal) else {
                return nil
            }
            let item = items[ordinal]
            return PlaybackPlaylistItem(
                excerpt: item,
                cuePresentation: excerptPlaybackCuePresentation(
                    excerptID: item.id
                ),
                ordinal: ordinal
            )
        case .explicitIDs(let excerptIDs):
            guard excerptIDs.indices.contains(ordinal) else {
                return nil
            }
            let excerptID = excerptIDs[ordinal]
            let snapshot = excerpt.tableRowStore.snapshot
            if snapshot.rowIndex(entryID: Int(excerptID)) != nil {
                return excerptTablePlaybackItem(
                    excerptID: excerptID,
                    itemOrdinal: ordinal
                )
            }
            guard let item = excerpt(withID: excerptID), item.isValid else {
                return nil
            }
            return PlaybackPlaylistItem(
                excerpt: item,
                cuePresentation: excerptPlaybackCuePresentation(
                    excerptID: excerptID
                ),
                ordinal: ordinal
            )
        }
    }

    /// The cue a saved Excerpt stands for, as the playlist item needs it.
    ///
    /// The cue content store is filled when a Excerpt list's table page loads,
    /// and this lookup used to read nothing else. Playback started from Recent
    /// never opens that page, so every item arrived carrying the line of text
    /// saved with it and no cue identity at all — and the cue is what
    /// `Save to Excerpt` and `Copy Deep Link` are addressed by, so both answered
    /// that there was no subtitle, while the rows showed one line where the cue
    /// has two.
    ///
    /// So the store is a cache here rather than the only source: what it does
    /// not hold is read from the database and kept, the way `excerpt(withID:)`
    /// already does for the Excerpt itself. A list whose page has been opened
    /// answers from memory as before and reads nothing.
    private func excerptPlaybackCuePresentation(
        excerptID: Int64
    ) -> ExcerptCuePresentation? {
        let cueID = excerpt.residentRelations.first {
            $0.id == excerptID
        }?.cueID ?? (try? excerptDatabase?.cueID(forExcerptID: excerptID)) ?? nil
        guard let cueID else {
            return nil
        }
        if let content = cueContent.content(for: cueID) {
            return ExcerptCuePresentation(cueContent: content)
        }
        guard let content = try? CueContentDatabase(path: databaseURL)
            .cueContents(forCueIDs: [cueID])
            .first
        else {
            return nil
        }
        cueContent.install([content])
        return ExcerptCuePresentation(cueContent: content)
    }

    private func excerptTablePlaybackItem(
        excerptID: Int64,
        itemOrdinal: Int? = nil
    ) -> PlaybackPlaylistItem? {
        let snapshot = excerpt.tableRowStore.snapshot
        guard let entryID = Int(exactly: excerptID),
              let rowOrdinal = snapshot.rowIndex(entryID: entryID),
              let row = snapshot.row(at: rowOrdinal),
              let item = snapshot.excerpt(entryID: row.id),
              item.isValid
        else {
            return nil
        }
        return PlaybackPlaylistItem(
            excerpt: item,
            cuePresentation: snapshot.excerptCuePresentation(entryID: row.id),
            ordinal: itemOrdinal ?? rowOrdinal
        )
    }

}
