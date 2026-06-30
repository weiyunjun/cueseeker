import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

private func tableSandboxShioriRowSources(from page: ShioriPage) -> [TableSandboxShioriRowSource] {
    page.shioris.map { shiori in
        TableSandboxShioriRowSource(
            shiori: shiori,
            displayTitle: page.displayTitlesByShioriID[shiori.id]
                ?? URL(fileURLWithPath: shiori.subtitlePath).lastPathComponent,
            dateAddedText: shioriDateAddedDisplayText(for: shiori.createdAt),
            languages: page.languagesByShioriID[shiori.id] ?? [.unknown]
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
                let totalSavedRowCount = try pageDatabase.shioriCount()
                let rows = tableSandboxShioriRowSources(from: rawPage)
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
            if shiori.selectedShiori?.id == item.id {
                shiori.selectedShiori = nil
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

    func openShiori(_ shiori: Shiori, recordsNavigationHistory: Bool = true) {
        UIInvalidationProbe.mark(
            "ACTION UI.Shiori.opened",
            details: "time=\(String(format: "%.2f", Double(shiori.startMilliseconds) / 1000.0))"
        )
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
                try database.removeShiori(
                    subtitleFile: subtitleFile,
                    startMilliseconds: selection.startMilliseconds,
                    endMilliseconds: selection.endMilliseconds
                )
                try refreshShioriPresentationAfterMutation(database: database)
                playbackViewModel.showShioriFeedback(.removed)
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
        guard activePlaybackSource == .shiori, let selectedShiori = shiori.selectedShiori else {
            return false
        }
        return adjacentShiori(to: selectedShiori, direction: .previous) != nil
    }

    var canOpenNextShiori: Bool {
        guard activePlaybackSource == .shiori, let selectedShiori = shiori.selectedShiori else {
            return false
        }
        return adjacentShiori(to: selectedShiori, direction: .next) != nil
    }

    func openPreviousShiori() {
        let target = shiori.selectedShiori.flatMap {
            adjacentShiori(to: $0, direction: .previous)
        }
        let hasResult = target != nil
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .previous, hasResult: hasResult)
        if let target {
            openShiori(target)
        }
    }

    func openNextShiori() {
        let target = shiori.selectedShiori.flatMap {
            adjacentShiori(to: $0, direction: .next)
        }
        let hasResult = target != nil
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .next, hasResult: hasResult)
        if let target {
            openShiori(target)
        }
    }

    private func adjacentShiori(
        to selectedShiori: Shiori,
        direction: ShioriNavigationDirection
    ) -> Shiori? {
        if let database = subtitleDatabase {
            do {
                return try database.adjacentShiori(to: selectedShiori, direction: direction)
            } catch {
                print("Failed to load adjacent Shiori: \(error)")
                return nil
            }
        }

        guard let index = shiori.shioris.firstIndex(where: { $0.id == selectedShiori.id }) else {
            return nil
        }
        switch direction {
        case .previous:
            return index > 0 ? shiori.shioris[index - 1] : nil
        case .next:
            return index < shiori.shioris.count - 1 ? shiori.shioris[index + 1] : nil
        }
    }
}
