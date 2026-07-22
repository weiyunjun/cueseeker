import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

struct ShioriTagPopoverState: Equatable {
    let allTags: [ShioriTag]
    let currentTags: [ShioriTag]
}

struct ShioriTagDeletionOutcome: Equatable {
    let popoverState: ShioriTagPopoverState
    let deletionResult: ShioriTagDeletionResult
}

@MainActor
extension AppCoordinator {
    func loadShioriTableRowsIfNeeded() {
        guard !indexing.indexingStatus.isIndexing,
              !indexing.folderRemovalStatus.isRemoving
        else {
            return
        }
        guard shioriTableRowsTask == nil else {
            return
        }
        let snapshot = shiori.tableRowStore.snapshot
        guard !shiori.tableHasLoadedInitialPage
                || snapshot.totalRowCount != shiori.tableResultRowCount
        else {
            return
        }
        reloadShioriTableRows()
    }

    func reloadShioriTableRows() {
        guard !indexing.indexingStatus.isIndexing,
              !indexing.folderRemovalStatus.isRemoving
        else {
            return
        }
        shioriTableRowsTask?.cancel()
        shiori.clearTableRowsForReload()

        let resultSnapshotID = shiori.tableResultSnapshotID
        let searchText = shiori.tableSubmittedSearchText
        let filterSet = shiori.tableFilterRules.subtitleSearchFilterSet
        let dataRevision = shiori.tableDataRevision
        if shiori.residentDataRevision == dataRevision {
            applyResidentShioriTableProjection(
                resultSnapshotID: resultSnapshotID,
                searchText: searchText,
                filterSet: filterSet,
                dataRevision: dataRevision
            )
            return
        }

        shioriTableRowsTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.shiori.tableResultSnapshotID == resultSnapshotID {
                    self.shioriTableRowsTask = nil
                }
            }

            do {
                let databaseURL = self.databaseURL
                let residentSnapshot = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    try SubtitleDatabase(
                        path: databaseURL,
                        access: .readOnly
                    ).shioriResidentSnapshot()
                }
                guard self.shioriTableRequestMatches(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    filterSignature: filterSet.cacheSignature,
                    dataRevision: dataRevision
                ) else {
                    return
                }
                self.cueContent.install(residentSnapshot.cueContents)
                self.shiori.installResidentSnapshot(
                    residentSnapshot,
                    dataRevision: dataRevision
                )
                self.applyResidentShioriTableProjection(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    filterSet: filterSet,
                    dataRevision: dataRevision
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load resident Shiori data: \(error)")
                if self.shioriTableRequestMatches(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    filterSignature: filterSet.cacheSignature,
                    dataRevision: dataRevision
                ) {
                    self.shiori.markTableRowsLoaded(totalSavedRowCount: 0)
                }
            }
        }
    }

    func prepareShioriForIndexedContentMutation(under folders: [URL]) {
        shioriNeedsReloadAfterIndexedContentMutation =
            shioriNeedsReloadAfterIndexedContentMutation
            || shiori.residentDataRevision != nil
            || shiori.tableHasLoadedInitialPage
            || shioriTableRowsTask != nil
        shioriTableRowsTask?.cancel()
        shioriTableRowsTask = nil
        cueContent.remove { content in
            folders.contains { folder in
                Self.path(content.subtitlePath, isUnder: folder)
            }
        }
        shiori.invalidateTableRows()
        shioriPlaybackNavigationScopeIDs = nil
        shioriPlaybackNavigationSnapshot = nil
    }

    func reloadShioriAfterIndexedContentMutation() {
        shioriTableRowsTask?.cancel()
        shioriTableRowsTask = nil
        guard shioriNeedsReloadAfterIndexedContentMutation else {
            return
        }
        shioriNeedsReloadAfterIndexedContentMutation = false
        reloadShioriTableRows()
    }

    private func applyResidentShioriTableProjection(
        resultSnapshotID: UUID,
        searchText: String,
        filterSet: SubtitleSearchFilterSet,
        dataRevision: Int
    ) {
        guard shioriTableRequestMatches(
            resultSnapshotID: resultSnapshotID,
            searchText: searchText,
            filterSignature: filterSet.cacheSignature,
            dataRevision: dataRevision
        ) else {
            return
        }

        let trimmedSearchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let relations = shiori.residentRelations.filter { relation in
            guard let content = cueContent.content(for: relation.cueID) else {
                return false
            }
            let matchesSearch = trimmedSearchText.isEmpty
                || content.displayTitle.range(
                    of: trimmedSearchText,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
                || content.content.range(
                    of: trimmedSearchText,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            return matchesSearch && filterSet.matches(
                display: content.displayTitle,
                cues: content.content,
                languages: content.languages.map(\.rawValue).sorted(),
                speakers: content.speakers.sorted()
            )
        }
        shiori.installTableResultShioriIDs(relations.map(\.id))
        shiori.markTableRowsLoaded(
            totalSavedRowCount: shiori.residentRelations.count
        )
        shiori.tableRowStore.updateResidentShioriRelations(
            relations,
            tagsByShioriID: shiori.residentTagsByShioriID,
            cueContentProvider: { [cueContent] cueID in
                cueContent.content(for: cueID)
            },
            cueContentRevision: cueContent.revision,
            tableName: "shiori",
            probeSurface: .shiori,
            probeScope: uiProbeScope
        )
        refreshShioriPlaybackPlaylistSource()
    }

    private func shioriTableRequestMatches(
        resultSnapshotID: UUID,
        searchText: String,
        filterSignature: String,
        dataRevision: Int
    ) -> Bool {
        !Task.isCancelled
            && shiori.tableResultSnapshotID == resultSnapshotID
            && shiori.tableSubmittedSearchText == searchText
            && shiori.tableFilterRules.subtitleSearchFilterSet.cacheSignature
                == filterSignature
            && shiori.tableDataRevision == dataRevision
    }

    func shioriTagPopoverState(forShioriID shioriID: Int64) -> ShioriTagPopoverState? {
        guard let database = shioriDatabase else { return nil }
        do {
            return ShioriTagPopoverState(
                allTags: try database.shioriTags(),
                currentTags: try database.shioriTags(forShioriID: shioriID)
            )
        } catch {
            print("Failed to load Shiori tags: \(error)")
            return nil
        }
    }

    func assignShioriTag(tagID: Int64, toShioriID shioriID: Int64) -> [ShioriTag]? {
        guard let database = shioriDatabase else { return nil }
        do {
            _ = try database.assignShioriTag(tagID: tagID, toShioriID: shioriID)
            let tags = try database.shioriTags(forShioriID: shioriID)
            shiori.updateResidentTags(tags, forShioriID: shioriID)
            return tags
        } catch {
            print("Failed to assign Shiori tag: \(error)")
            return nil
        }
    }

    func createAndAssignShioriTag(named name: String, toShioriID shioriID: Int64) -> ShioriTagPopoverState? {
        guard let database = shioriDatabase else { return nil }
        do {
            _ = try database.assignShioriTag(named: name, toShioriID: shioriID)
            let state = ShioriTagPopoverState(
                allTags: try database.shioriTags(),
                currentTags: try database.shioriTags(forShioriID: shioriID)
            )
            shiori.updateResidentTags(state.currentTags, forShioriID: shioriID)
            return state
        } catch {
            print("Failed to create Shiori tag: \(error)")
            return nil
        }
    }

    func removeShioriTagAssignment(tagID: Int64, fromShioriID shioriID: Int64) -> [ShioriTag]? {
        guard let database = shioriDatabase else { return nil }
        do {
            _ = try database.removeShioriTagAssignment(tagID: tagID, fromShioriID: shioriID)
            let tags = try database.shioriTags(forShioriID: shioriID)
            shiori.updateResidentTags(tags, forShioriID: shioriID)
            return tags
        } catch {
            print("Failed to remove Shiori tag assignment: \(error)")
            return nil
        }
    }

    func deleteShioriTagGlobally(tagID: Int64, currentShioriID: Int64) -> ShioriTagDeletionOutcome? {
        guard let database = shioriDatabase else { return nil }
        do {
            let deletion = try database.deleteShioriTag(tagID: tagID)
            shiori.removeResidentTag(
                tagID: tagID,
                fromShioriIDs: deletion.affectedShioriIDs
            )
            let state = ShioriTagPopoverState(
                allTags: try database.shioriTags(),
                currentTags: try database.shioriTags(forShioriID: currentShioriID)
            )
            return ShioriTagDeletionOutcome(
                popoverState: state,
                deletionResult: deletion
            )
        } catch {
            print("Failed to delete Shiori tag: \(error)")
            return nil
        }
    }

    @discardableResult
    func removeShiori(_ item: Shiori, reloadPresentation: Bool = true) -> Bool {
        guard let database = subtitleDatabase else {
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            return false
        }

        do {
            try database.removeShiori(id: item.id)
            _ = reloadPresentation
            shiori.invalidateTableRows()
            removeShioriFromPlaybackNavigationScope(item.id)
            if shiori.selectedShiori?.id == item.id {
                shiori.selectedShiori = nil
                shioriPlaybackNavigationSnapshot = nil
                clearPlaybackChromeSnapshot()
            } else {
                if let selectedShiori = shiori.selectedShiori {
                    _ = refreshShioriPlaybackNavigationSnapshot(for: selectedShiori)
                    refreshPlaybackChromeSnapshot(
                        displayTitle: playback.chromeSnapshot.displayTitle
                    )
                }
            }
            playback.playbackViewModel?.showShioriFeedback(.removed)
            return true
        } catch {
            print("Failed to remove Shiori: \(error)")
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            return false
        }
    }

    func openShiori(
        _ shiori: Shiori,
        navigationScopeIDs: [Int64]? = nil,
        playlistScope: PlaybackPlaylistShioriScope? = nil,
        playlistSelectedOrdinal: Int? = nil,
        displayTitle: String? = nil,
        playbackReturnContextOnSuccessfulPlay: PlaybackReturnContext? = nil
    ) {
        clearCueAutoStopPlayback()
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        playback.playbackStatus = .opening
        UIInvalidationProbe.mark(
            "ACTION UI.Shiori.opened",
            details: "time=\(String(format: "%.2f", Double(shiori.startMilliseconds) / 1000.0))"
        )
        preparePlaybackKeyboardFocus()
        let keepsExistingPlaylistSnapshot = playlistScope.map { scope in
            playback.playlistSource?.origin == .shiori(scope: scope)
                && shioriPlaybackNavigationScopeIDs != nil
        } ?? false
        if !keepsExistingPlaylistSnapshot {
            if case .table(let context)? = playlistScope,
               let navigationScopeIDs,
               navigationScopeIDs.count == context.totalCount {
                // Core table snapshots are already ordered and unique by the
                // Shiori primary key. Keep their copy-on-write ID buffer.
                shioriPlaybackNavigationScopeIDs = navigationScopeIDs
            } else {
                shioriPlaybackNavigationScopeIDs = normalizedShioriPlaybackNavigationScopeIDs(
                    navigationScopeIDs
                )
            }
        }
        installShioriPlaybackPlaylistSource(scope: playlistScope)
        let resolvedPlaylistOrdinal = refreshShioriPlaybackNavigationSnapshot(
            for: shiori,
            preferredOrdinal: playlistSelectedOrdinal
        )
        if let resolvedPlaylistOrdinal {
            _ = playback.setPlaylistPosition(
                itemIdentity: .shiori(shiori.id),
                ordinal: resolvedPlaylistOrdinal
            )
        } else {
            playback.clearPlaylistPosition()
        }
        initializePlaybackReturnContextIfEntering()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        self.shiori.selectedShiori = shiori
        search.selectedSearchResult = nil
        library.selectedLibraryVideo = nil
        refreshPlaybackChromeSnapshot(
            displayTitle: playbackDisplayTitle(
                for: shiori,
                providedDisplayTitle: displayTitle
            )
        )
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            let didStartPlayback = play(shiori)
            if let playbackReturnContextOnSuccessfulPlay {
                commitPlaybackReturnContext(
                    playbackReturnContextOnSuccessfulPlay,
                    afterSuccessfulPlayback: didStartPlayback
                )
            }
        }
    }

    @discardableResult
    func play(_ shiori: Shiori) -> Bool {
        ensurePlayerInitialized()
        beginCueAutoStopPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        playback.playbackStatus = .opening
        playbackSubtitleCuesTask?.cancel()
        let subtitleCues = initialPlaybackSubtitleCues(for: shiori)
        playback.playbackViewModel?.preparePresentationTransition(
            to: Double(shiori.startMilliseconds) / 1_000,
            subtitleCues: subtitleCues
        )

        do {
            let autoStopBoundary = configureCueAutoStopBoundary(
                startMilliseconds: shiori.startMilliseconds,
                endMilliseconds: shiori.endMilliseconds
            )
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: shiori.videoPath),
                startMilliseconds: shiori.startMilliseconds,
                autoStopAtMilliseconds: autoStopBoundary?.endMilliseconds,
                subtitleSource: playbackSubtitleSource(for: shiori)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            let generation: UInt
            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
                if let autoStopBoundary {
                    generation = try player.seek(
                        to: autoStopBoundary,
                        subtitleSource: request.subtitleSource
                    )
                } else {
                    generation = try player.seek(
                        toMilliseconds: shiori.startMilliseconds,
                        subtitleSource: request.subtitleSource
                    )
                }
            } else {
                generation = try player.open(request)
            }

            playback.playbackViewModel?.bindPendingPresentation(to: generation)
            startPlaybackSubtitleCuesLoad(
                forSubtitleFile: URL(fileURLWithPath: shiori.subtitlePath),
                format: shiori.subtitleFormat,
                videoPath: shiori.videoPath
            )
            return true
        } catch {
            playback.playbackViewModel?.cancelPendingPresentation()
            clearCueAutoStopPlayback()
            playbackSubtitleCuesTask?.cancel()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
            return false
        }
    }

    var canOpenPreviousShiori: Bool {
        guard activePlaybackSource == .shiori,
              let selectedShiori = shiori.selectedShiori,
              shioriPlaybackNavigationSnapshot?.currentID == selectedShiori.id
        else {
            return false
        }
        return shioriPlaybackNavigationSnapshot?.previousID != nil
    }

    var canOpenNextShiori: Bool {
        guard activePlaybackSource == .shiori,
              let selectedShiori = shiori.selectedShiori,
              shioriPlaybackNavigationSnapshot?.currentID == selectedShiori.id
        else {
            return false
        }
        return shioriPlaybackNavigationSnapshot?.nextID != nil
    }

    func openPreviousShiori() {
        let target = shioriPlaybackNavigationTarget(direction: .previous)
        let hasResult = target != nil
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .previous, hasResult: hasResult)
        if let target {
            let targetOrdinal = shiori.selectedShiori.flatMap {
                currentShioriPlaylistAdjacentOrdinal(
                    for: $0,
                    direction: .previous
                )
            }
            openShiori(
                target,
                navigationScopeIDs: shioriPlaybackNavigationScopeIDs,
                playlistScope: activeShioriPlaybackPlaylistScope,
                playlistSelectedOrdinal: targetOrdinal
            )
        }
    }

    func openNextShiori() {
        let target = shioriPlaybackNavigationTarget(direction: .next)
        let hasResult = target != nil
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .next, hasResult: hasResult)
        if let target {
            let targetOrdinal = shiori.selectedShiori.flatMap {
                currentShioriPlaylistAdjacentOrdinal(
                    for: $0,
                    direction: .next
                )
            }
            openShiori(
                target,
                navigationScopeIDs: shioriPlaybackNavigationScopeIDs,
                playlistScope: activeShioriPlaybackPlaylistScope,
                playlistSelectedOrdinal: targetOrdinal
            )
        }
    }

    private var activeShioriPlaybackPlaylistScope: PlaybackPlaylistShioriScope? {
        guard let source = playback.playlistSource,
              case .shiori(let scope) = source.origin
        else {
            return nil
        }
        return scope
    }

    private func shioriPlaybackNavigationTarget(direction: ShioriNavigationDirection) -> Shiori? {
        guard activePlaybackSource == .shiori,
              let selectedShiori = shiori.selectedShiori,
              let snapshot = shioriPlaybackNavigationSnapshot,
              snapshot.currentID == selectedShiori.id
        else {
            return nil
        }

        let targetID: Int64?
        switch direction {
        case .previous:
            targetID = snapshot.previousID
        case .next:
            targetID = snapshot.nextID
        }
        return targetID.flatMap(shiori(withID:))
    }

    private func refreshShioriPlaybackNavigationSnapshot(
        for selectedShiori: Shiori,
        preferredOrdinal: Int? = nil
    ) -> Int? {
        let selectedID = selectedShiori.id
        let validatedPreferredOrdinal: Int?
        if let preferredOrdinal,
           playback.playlistSource?.itemIdentity(at: preferredOrdinal)
            == .shiori(selectedID) {
            validatedPreferredOrdinal = preferredOrdinal
        } else {
            validatedPreferredOrdinal = nil
        }

        if let source = playback.playlistSource,
           case .shiori(.table) = source.origin {
            let scopeIDs = shioriPlaybackNavigationScopeIDs
                ?? shiori.tableResultShioriIDs
            guard let scopeIDs,
                  let index = validatedPreferredOrdinal
                    ?? scopeIDs.firstIndex(of: selectedID)
            else {
                shioriPlaybackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: nil,
                    nextID: nil
                )
                return nil
            }
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count
                    ? scopeIDs[index + 1]
                    : nil
            )
            return index
        }

        if let scopeIDs = shioriPlaybackNavigationScopeIDs,
           let index = validatedPreferredOrdinal
                ?? scopeIDs.firstIndex(of: selectedID) {
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count ? scopeIDs[index + 1] : nil
            )
            return index
        }

        let residentOrdinal = validatedPreferredOrdinal
            ?? shiori.residentRelations.firstIndex(where: { $0.id == selectedID })

        if let index = residentOrdinal {
            let residentRelations = shiori.residentRelations
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? residentRelations[index - 1].id : nil,
                nextID: index + 1 < residentRelations.count
                    ? residentRelations[index + 1].id
                    : nil
            )
            return index
        }

        if let database = subtitleDatabase {
            do {
                shioriPlaybackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: try database.adjacentShiori(to: selectedShiori, direction: .previous)?.id,
                    nextID: try database.adjacentShiori(to: selectedShiori, direction: .next)?.id
                )
                return nil
            } catch {
                print("Failed to load adjacent Shiori: \(error)")
            }
        }

        shioriPlaybackNavigationSnapshot = (
            currentID: selectedID,
            previousID: nil,
            nextID: nil
        )
        return nil
    }

    func shiori(withID id: Int64) -> Shiori? {
        if let entryID = Int(exactly: id),
           let tableItem = shiori.tableRowStore.snapshot.shiori(entryID: entryID) {
            return tableItem
        }
        if let relation = shiori.residentRelations.first(where: { $0.id == id }),
           let content = cueContent.content(for: relation.cueID) {
            return Shiori(relation: relation, cueContent: content)
        }
        guard let database = subtitleDatabase else {
            return nil
        }

        do {
            guard let relation = try database.shioriRelation(id: id),
                  let content = try database.cueContents(
                    forCueIDs: [relation.cueID]
                  ).first
            else {
                return nil
            }
            cueContent.install([content])
            return Shiori(relation: relation, cueContent: content)
        } catch {
            print("Failed to load scoped Shiori: \(error)")
            return nil
        }
    }

    private func normalizedShioriPlaybackNavigationScopeIDs(_ ids: [Int64]?) -> [Int64]? {
        guard let ids else {
            return nil
        }

        var seenIDs: Set<Int64> = []
        let normalizedIDs = ids.filter { seenIDs.insert($0).inserted }
        return normalizedIDs.isEmpty ? nil : normalizedIDs
    }

    private func removeShioriFromPlaybackNavigationScope(_ id: Int64) {
        guard var scopeIDs = shioriPlaybackNavigationScopeIDs else {
            return
        }

        scopeIDs.removeAll { $0 == id }
        shioriPlaybackNavigationScopeIDs = scopeIDs.isEmpty ? nil : scopeIDs
    }
}
