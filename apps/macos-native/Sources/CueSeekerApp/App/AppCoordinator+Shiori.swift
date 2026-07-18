import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

private func tableSandboxShioriRowSources(
    from page: ShioriPage,
    tagsByShioriID: [Int64: [ShioriTag]] = [:]
) -> [TableSandboxShioriRowSource] {
    page.shioris.map { shiori in
        TableSandboxShioriRowSource(
            shiori: shiori,
            displayTitle: page.displayTitlesByShioriID[shiori.id]
                ?? URL(fileURLWithPath: shiori.subtitlePath).lastPathComponent,
            dateAddedText: shioriDateAddedDisplayText(for: shiori.createdAt),
            languages: page.languagesByShioriID[shiori.id] ?? [.unknown],
            shioriTags: tagsByShioriID[shiori.id] ?? [],
            cuePresentation: page.cuePresentationsByShioriID[shiori.id]
        )
    }
}

private func shioriDateAddedDisplayText(for value: String) -> String {
    let isoFormatter = ISO8601DateFormatter()
    guard let date = isoFormatter.date(from: value) else {
        return value
    }

    let displayFormatter = DateFormatter()
    displayFormatter.locale = Locale(identifier: "en_US_POSIX")
    displayFormatter.dateFormat = "yy-MM-dd HH:mm"
    return displayFormatter.string(from: date)
}

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
        shioriTableRowsTask?.cancel()
        shiori.clearTableRowsForReload()

        let resultSnapshotID = shiori.tableResultSnapshotID
        let searchText = shiori.tableSubmittedSearchText
        let filterSet = shiori.tableFilterRules.subtitleSearchFilterSet
        let dataRevision = shiori.tableDataRevision
        shioriTableRowsTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.shiori.tableResultSnapshotID == resultSnapshotID {
                    self.shioriTableRowsTask = nil
                }
            }

            var resultShioriIDs: [Int64]?
            var nextOffset = 0
            var isFirstPage = true
            while !Task.isCancelled {
                let pageSize = isFirstPage
                    ? TableSandboxHydrationPaging.pageSize
                    : 1_000
                guard let page = await self.loadTableSandboxShioriRows(
                    range: nextOffset..<(nextOffset + pageSize),
                    searchText: searchText,
                    filterSet: filterSet,
                    resultShioriIDs: resultShioriIDs
                ) else {
                    if isFirstPage,
                       self.shioriTableRequestMatches(
                           resultSnapshotID: resultSnapshotID,
                           searchText: searchText,
                           filterSignature: filterSet.cacheSignature,
                           dataRevision: dataRevision
                       ) {
                        self.shiori.markTableRowsLoaded(totalSavedRowCount: 0)
                    }
                    return
                }
                guard self.shioriTableRequestMatches(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    filterSignature: filterSet.cacheSignature,
                    dataRevision: dataRevision
                ) else {
                    return
                }

                if isFirstPage {
                    resultShioriIDs = page.resultShioriIDs
                    self.shiori.installTableResultShioriIDs(page.resultShioriIDs)
                    self.shiori.markTableRowsLoaded(
                        totalSavedRowCount: page.totalSavedRowCount
                    )
                }
                self.shiori.tableRowStore.hydrateShioriRows(
                    page.rows,
                    startIndex: page.range.lowerBound,
                    totalRowCount: page.range.lowerBound + page.rows.count,
                    tableName: "shiori",
                    probeSurface: .shiori,
                    probeScope: self.uiProbeScope
                )
                self.refreshShioriPlaybackPlaylistSource()

                nextOffset = page.range.upperBound
                isFirstPage = false
                guard nextOffset < page.totalRowCount,
                      !page.rows.isEmpty
                else {
                    return
                }
            }
        }
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

    func loadTableSandboxShioriRows(
        range: Range<Int>,
        searchText: String,
        filterSet: SubtitleSearchFilterSet,
        resultShioriIDs: [Int64]? = nil
    ) async -> TableSandboxShioriHydrationPage? {
        guard subtitleDatabase != nil else {
            return nil
        }

        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerBound = max(0, range.lowerBound)
        let upperBound = max(lowerBound, range.upperBound)
        guard lowerBound < upperBound else { return nil }

        do {
            let pageDatabaseURL = databaseURL
            let page: TableSandboxShioriHydrationPage? = try await Self.runCancellableDetached(
                priority: .userInitiated
            ) {
                let pageDatabase = try SubtitleDatabase(path: pageDatabaseURL)
                let resolvedShioriIDs = try resultShioriIDs
                    ?? pageDatabase.shioriTableIDIndex(
                        searchText: trimmedSearchText,
                        filterSet: filterSet
                    ).shioriIDs
                try Task.checkCancellation()
                let pageLowerBound = min(lowerBound, resolvedShioriIDs.count)
                let pageUpperBound = min(upperBound, resolvedShioriIDs.count)
                let pageShioriIDs = Array(
                    resolvedShioriIDs[pageLowerBound..<pageUpperBound]
                )
                let rawPage = try pageDatabase.shioriPage(
                    shioriIDs: pageShioriIDs
                )
                guard rawPage.shioris.map(\.id) == pageShioriIDs else {
                    return nil
                }
                try Task.checkCancellation()
                let tagsByShioriID = try pageDatabase.shioriTagsByShioriID(
                    forShioriIDs: rawPage.shioris.map(\.id)
                )
                try Task.checkCancellation()
                let totalSavedRowCount = try pageDatabase.shioriCount()
                try Task.checkCancellation()
                let rows = tableSandboxShioriRowSources(
                    from: rawPage,
                    tagsByShioriID: tagsByShioriID
                )
                return TableSandboxShioriHydrationPage(
                    range: lowerBound..<(lowerBound + rows.count),
                    rows: rows,
                    totalRowCount: resolvedShioriIDs.count,
                    totalSavedRowCount: totalSavedRowCount,
                    resultShioriIDs: resolvedShioriIDs
                )
            }

            guard !Task.isCancelled, let page else {
                return nil
            }

            return page
        } catch is CancellationError {
            return nil
        } catch {
            print("Failed to load Shiori table rows: \(error)")
            return nil
        }
    }

    func shioriTagPopoverState(forShioriID shioriID: Int64) -> ShioriTagPopoverState? {
        guard let database = subtitleDatabase else { return nil }
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
        guard let database = subtitleDatabase else { return nil }
        do {
            _ = try database.assignShioriTag(tagID: tagID, toShioriID: shioriID)
            return try database.shioriTags(forShioriID: shioriID)
        } catch {
            print("Failed to assign Shiori tag: \(error)")
            return nil
        }
    }

    func createAndAssignShioriTag(named name: String, toShioriID shioriID: Int64) -> ShioriTagPopoverState? {
        guard let database = subtitleDatabase else { return nil }
        do {
            _ = try database.assignShioriTag(named: name, toShioriID: shioriID)
            return ShioriTagPopoverState(
                allTags: try database.shioriTags(),
                currentTags: try database.shioriTags(forShioriID: shioriID)
            )
        } catch {
            print("Failed to create Shiori tag: \(error)")
            return nil
        }
    }

    func removeShioriTagAssignment(tagID: Int64, fromShioriID shioriID: Int64) -> [ShioriTag]? {
        guard let database = subtitleDatabase else { return nil }
        do {
            _ = try database.removeShioriTagAssignment(tagID: tagID, fromShioriID: shioriID)
            return try database.shioriTags(forShioriID: shioriID)
        } catch {
            print("Failed to remove Shiori tag assignment: \(error)")
            return nil
        }
    }

    func deleteShioriTagGlobally(tagID: Int64, currentShioriID: Int64) -> ShioriTagDeletionOutcome? {
        guard let database = subtitleDatabase else { return nil }
        do {
            let deletion = try database.deleteShioriTag(tagID: tagID)
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

    func hydrateShiorisAsync(invalidatesTableRows: Bool = true) {
        guard let database = subtitleDatabase else {
            return
        }

        shiorisTask?.cancel()
        shiorisTask = Task { [weak self] in
            do {
                let loadedShioris = try await Task.detached(priority: .userInitiated) {
                    try database.shioris()
                }.value

                guard !Task.isCancelled else { return }

                self?.applyShioris(
                    loadedShioris,
                    invalidatesTableRows: invalidatesTableRows
                )
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load shioris asynchronously: \(error)")
            }
        }
    }

    func applyShioris(
        _ nextShioris: [Shiori],
        invalidatesTableRows: Bool = true
    ) {
        let sortedShioris = nextShioris.sorted(by: Self.shioriSort)
        if invalidatesTableRows,
           shiori.shioris != sortedShioris {
            shiori.invalidateTableRows()
        }
        shiori.shioris = sortedShioris
        rebuildShioriFileGroups()
    }

    func languages(for shiori: Shiori) -> Set<SubtitleLanguageCode> {
        guard let database = subtitleDatabase else {
            return [.unknown]
        }

        do {
            return try database.cueGroupLanguages(
                forSubtitlePath: shiori.subtitlePath,
                startMilliseconds: shiori.startMilliseconds,
                endMilliseconds: shiori.endMilliseconds
            )
        } catch {
            print("Failed to load Shiori languages: \(error)")
            return [.unknown]
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
            if reloadPresentation {
                try refreshShioriPresentationAfterMutation(database: database)
            } else {
                shiori.invalidateTableRows()
                shiori.shioris.removeAll { $0.id == item.id }
                if !shiori.shioriFileGroups.isEmpty {
                    rebuildShioriFileGroups()
                }
            }
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

    func rebuildShioriFileGroups() {
        shiori.shioriFileGroups = Self.makeShioriFileGroups(
            from: shiori.shioris,
            collapsedGroupPaths: shiori.collapsedShioriGroupPaths
        )
        UIInvalidationProbe.count(
            "UI.ShioriPresentation.rebuilt",
            scope: uiProbeScope,
            details: "groups=\(shiori.shioriFileGroups.count) rows=\(shiori.shioris.count)"
        )
    }

    func openShiori(
        _ shiori: Shiori,
        recordsNavigationHistory: Bool = true,
        navigationScopeIDs: [Int64]? = nil,
        playlistScope: PlaybackPlaylistShioriScope? = nil,
        playlistSelectedOrdinal: Int? = nil,
        displayTitle: String? = nil,
        playsContinuouslyFromStart: Bool = false,
        playbackReturnContextOnSuccessfulPlay: PlaybackReturnContext? = nil
    ) {
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
        if recordsNavigationHistory {
            recordPlaybackNavigationEntry(playbackNavigationPayload(for: shiori))
        }
        clearCueAutoStopPlayback()
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
            let didStartPlayback = play(
                shiori,
                playsContinuouslyFromStart: playsContinuouslyFromStart
            )
            if let playbackReturnContextOnSuccessfulPlay {
                commitPlaybackReturnContext(
                    playbackReturnContextOnSuccessfulPlay,
                    afterSuccessfulPlayback: didStartPlayback
                )
            }
        }
    }

    @discardableResult
    func play(
        _ shiori: Shiori,
        playsContinuouslyFromStart: Bool = false
    ) -> Bool {
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
                endMilliseconds: shiori.endMilliseconds,
                playsContinuouslyFromStart: playsContinuouslyFromStart
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

    func refreshShioriPresentationAfterMutation(database: SubtitleDatabase) throws {
        let hasLegacyPresentation = !shiori.shioris.isEmpty || !shiori.shioriFileGroups.isEmpty
        shiori.invalidateTableRows()
        guard hasLegacyPresentation else {
            return
        }
        applyShioris(try database.shioris())
    }


    func toggleShioriGroup(_ subtitlePath: String) {
        UIInvalidationProbe.mark(
            "ACTION UI.ShioriGroup.toggled",
            details: "collapsedBefore=\(shiori.collapsedShioriGroupPaths.contains(subtitlePath))"
        )
        if shiori.collapsedShioriGroupPaths.contains(subtitlePath) {
            shiori.collapsedShioriGroupPaths.remove(subtitlePath)
        } else {
            shiori.collapsedShioriGroupPaths.insert(subtitlePath)
        }
        rebuildShioriFileGroups()
    }

    func collapseAllShioriGroups() {
        let groupPaths = Set(shiori.shioriFileGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return
        }

        let collapsedPaths = shiori.collapsedShioriGroupPaths.union(groupPaths)
        guard collapsedPaths != shiori.collapsedShioriGroupPaths else {
            return
        }

        shiori.collapsedShioriGroupPaths = collapsedPaths
        rebuildShioriFileGroups()
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
            ?? shiori.shioris.firstIndex(where: { $0.id == selectedID })

        if let database = subtitleDatabase {
            do {
                shioriPlaybackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: try database.adjacentShiori(to: selectedShiori, direction: .previous)?.id,
                    nextID: try database.adjacentShiori(to: selectedShiori, direction: .next)?.id
                )
                return residentOrdinal
            } catch {
                print("Failed to load adjacent Shiori: \(error)")
            }
        }

        if let index = residentOrdinal {
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? shiori.shioris[index - 1].id : nil,
                nextID: index + 1 < shiori.shioris.count ? shiori.shioris[index + 1].id : nil
            )
            return index
        }

        shioriPlaybackNavigationSnapshot = (
            currentID: selectedID,
            previousID: nil,
            nextID: nil
        )
        return nil
    }

    private func shiori(withID id: Int64) -> Shiori? {
        if let cached = shiori.shioris.first(where: { $0.id == id }) {
            return cached
        }
        if let entryID = Int(exactly: id),
           let tableItem = shiori.tableRowStore.snapshot.shiori(entryID: entryID) {
            return tableItem
        }
        guard let database = subtitleDatabase else {
            return nil
        }

        do {
            return try database.shiori(id: id)
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
