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
            shioriTags: tagsByShioriID[shiori.id] ?? []
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
    func loadTableSandboxShioriRows(
        range: Range<Int>,
        searchText: String,
        filterSet: SubtitleSearchFilterSet
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
            let page = try await Task.detached(priority: .userInitiated) {
                let pageDatabase = try SubtitleDatabase(path: pageDatabaseURL)
                let rawPage = try pageDatabase.shioriTablePage(
                    limit: upperBound - lowerBound,
                    offset: lowerBound,
                    searchText: trimmedSearchText,
                    filterSet: filterSet
                )
                let tagsByShioriID = try pageDatabase.shioriTagsByShioriID(
                    forShioriIDs: rawPage.shioris.map(\.id)
                )
                let totalSavedRowCount = try pageDatabase.shioriCount()
                let rows = tableSandboxShioriRowSources(
                    from: rawPage,
                    tagsByShioriID: tagsByShioriID
                )
                return TableSandboxShioriHydrationPage(
                    range: lowerBound..<(lowerBound + rows.count),
                    rows: rows,
                    totalRowCount: rawPage.totalCount,
                    totalSavedRowCount: totalSavedRowCount
                )
            }.value

            guard !Task.isCancelled else {
                return nil
            }

            return page
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

    func hydrateShiorisAsync() {
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

                self?.applyShioris(loadedShioris)
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load shioris asynchronously: \(error)")
            }
        }
    }

    func applyShioris(_ nextShioris: [Shiori]) {
        let sortedShioris = nextShioris.sorted(by: Self.shioriSort)
        if shiori.shioris != sortedShioris {
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
            try database.removeShiori(
                subtitleFile: URL(fileURLWithPath: item.subtitlePath),
                startMilliseconds: item.startMilliseconds,
                endMilliseconds: item.endMilliseconds
            )
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
                    refreshShioriPlaybackNavigationSnapshot(for: selectedShiori)
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
            details: "groups=\(shiori.shioriFileGroups.count) rows=\(shiori.shioris.count)"
        )
    }

    func openShiori(
        _ shiori: Shiori,
        recordsNavigationHistory: Bool = true,
        navigationScopeIDs: [Int64]? = nil,
        displayTitle: String? = nil
    ) {
        UIInvalidationProbe.mark(
            "ACTION UI.Shiori.opened",
            details: "time=\(String(format: "%.2f", Double(shiori.startMilliseconds) / 1000.0))"
        )
        preparePlaybackKeyboardFocus()
        shioriPlaybackNavigationScopeIDs = normalizedShioriPlaybackNavigationScopeIDs(navigationScopeIDs)
        refreshShioriPlaybackNavigationSnapshot(for: shiori)
        rememberPlaybackOriginatingPanelModeIfEntering()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        if recordsNavigationHistory {
            recordPlaybackNavigationEntry(playbackNavigationPayload(for: shiori))
        }
        cancelAutoPlayCueSequenceTask()
        currentCueSegmentFinished = false
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
            play(shiori)
        }
    }

    func play(_ shiori: Shiori) {
        ensurePlayerInitialized()
        beginCueSegmentPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        playback.playbackStatus = .opening
        playbackSubtitleCuesTask?.cancel()
        let subtitleCues = initialPlaybackSubtitleCues(for: shiori)
        playback.playbackViewModel?.setSubtitleCues(
            subtitleCues,
            currentTimeMilliseconds: shiori.startMilliseconds
        )

        do {
            let segment = autoSwitchCuePlaybackSegment(
                startMilliseconds: shiori.startMilliseconds,
                endMilliseconds: shiori.endMilliseconds
            )
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: shiori.videoPath),
                startMilliseconds: shiori.startMilliseconds,
                segmentEndMilliseconds: segment?.endMilliseconds,
                subtitleSource: playbackSubtitleSource(for: shiori)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
                player.loadSubtitleSource(request.subtitleSource)
                if let segment {
                    try player.seek(to: segment)
                } else {
                    try player.seek(toMilliseconds: shiori.startMilliseconds)
                }
            } else {
                try player.open(request)
            }

            try player.setPaused(false)
            playback.playbackStatus = .playing
            startPlaybackSubtitleCuesLoad(
                forSubtitleFile: URL(fileURLWithPath: shiori.subtitlePath),
                format: shiori.subtitleFormat,
                videoPath: shiori.videoPath
            )
        } catch {
            playbackSubtitleCuesTask?.cancel()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func toggleCurrentShiori() -> Bool {
        guard let currentPlaybackSubtitlePath,
              let currentPlaybackSubtitleFormat,
              let currentPlaybackVideoPath,
              let playbackViewModel = playback.playbackViewModel
        else {
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            return false
        }

        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        let videoFile = URL(fileURLWithPath: currentPlaybackVideoPath)
        let videoName = library.selectedLibraryVideo?.videoName
            ?? search.selectedSearchResult?.videoName
            ?? shiori.selectedShiori?.videoName
            ?? videoFile.lastPathComponent
        let milliseconds = max(0, Int((playbackViewModel.currentTime * 1_000).rounded(.down)))

        guard let database = subtitleDatabase else {
            playbackViewModel.showShioriFeedback(.unavailable)
            return false
        }

        do {
            guard let selection = try database.cueTextSelection(
                forSubtitleFile: subtitleFile,
                atMilliseconds: milliseconds
            ), !selection.text.isEmpty else {
                playbackViewModel.showShioriFeedback(.unavailable)
                return false
            }

            if try database.shiori(
                subtitleFile: subtitleFile,
                startMilliseconds: selection.startMilliseconds,
                endMilliseconds: selection.endMilliseconds
            ) != nil {
                playbackViewModel.showShioriFeedback(.alreadySaved)
                return true
            }

            _ = try database.upsertShiori(
                subtitleFile: subtitleFile,
                subtitleFormat: currentPlaybackSubtitleFormat,
                videoFile: videoFile,
                videoName: videoName,
                selection: selection
            )
            try refreshShioriPresentationAfterMutation(database: database)
            playbackViewModel.showShioriFeedback(.saved)
            return true
        } catch {
            print("Failed to toggle Shiori: \(error)")
            playbackViewModel.showShioriFeedback(.unavailable)
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
            openShiori(target, navigationScopeIDs: shioriPlaybackNavigationScopeIDs)
        }
    }

    func openNextShiori() {
        let target = shioriPlaybackNavigationTarget(direction: .next)
        let hasResult = target != nil
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .next, hasResult: hasResult)
        if let target {
            openShiori(target, navigationScopeIDs: shioriPlaybackNavigationScopeIDs)
        }
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

    private func refreshShioriPlaybackNavigationSnapshot(for selectedShiori: Shiori) {
        let selectedID = selectedShiori.id

        if let scopeIDs = shioriPlaybackNavigationScopeIDs,
           let index = scopeIDs.firstIndex(of: selectedID) {
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count ? scopeIDs[index + 1] : nil
            )
            return
        }

        if let database = subtitleDatabase {
            do {
                shioriPlaybackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: try database.adjacentShiori(to: selectedShiori, direction: .previous)?.id,
                    nextID: try database.adjacentShiori(to: selectedShiori, direction: .next)?.id
                )
                return
            } catch {
                print("Failed to load adjacent Shiori: \(error)")
            }
        }

        if let index = shiori.shioris.firstIndex(where: { $0.id == selectedID }) {
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? shiori.shioris[index - 1].id : nil,
                nextID: index + 1 < shiori.shioris.count ? shiori.shioris[index + 1].id : nil
            )
            return
        }

        shioriPlaybackNavigationSnapshot = (
            currentID: selectedID,
            previousID: nil,
            nextID: nil
        )
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
