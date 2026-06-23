import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

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
        let hasLocalCriteria = !trimmedSearchText.isEmpty || !filterSet.isEffectivelyEmpty
        let lowerBound = max(0, range.lowerBound)
        let upperBound = max(lowerBound, range.upperBound)
        guard lowerBound < upperBound else { return nil }

        do {
            let pageDatabaseURL = databaseURL
            let rawPage = try await Task.detached(priority: .userInitiated) {
                let pageDatabase = try SubtitleDatabase(path: pageDatabaseURL)
                if hasLocalCriteria {
                    return try pageDatabase.shiorisWithLanguages()
                }
                return try pageDatabase.shioriPage(
                    limit: upperBound - lowerBound,
                    offset: lowerBound
                )
            }.value

            guard !Task.isCancelled else {
                return nil
            }

            if hasLocalCriteria {
                let filteredSources = shioriRowSources(
                    from: rawPage,
                    searchText: trimmedSearchText,
                    filterSet: filterSet
                )
                let pageUpperBound = min(upperBound, filteredSources.count)
                let pageRows = lowerBound < pageUpperBound
                    ? Array(filteredSources[lowerBound..<pageUpperBound])
                    : []
                return TableSandboxShioriHydrationPage(
                    range: lowerBound..<(lowerBound + pageRows.count),
                    rows: pageRows,
                    totalRowCount: filteredSources.count,
                    totalSavedRowCount: rawPage.totalCount
                )
            }

            let pageRows = shioriRowSources(
                from: rawPage,
                searchText: "",
                filterSet: SubtitleSearchFilterSet()
            )
            return TableSandboxShioriHydrationPage(
                range: lowerBound..<(lowerBound + pageRows.count),
                rows: pageRows,
                totalRowCount: rawPage.totalCount,
                totalSavedRowCount: rawPage.totalCount
            )
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

    static func shioriDateAddedDisplayText(for value: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        guard let date = isoFormatter.date(from: value) else {
            return value
        }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.dateFormat = "yy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
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

    private func shioriRowSources(
        from page: ShioriPage,
        searchText: String,
        filterSet: SubtitleSearchFilterSet
    ) -> [TableSandboxShioriRowSource] {
        page.shioris.compactMap { shiori in
            let displayTitle = SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: shiori.subtitlePath)
            let languages = page.languagesByShioriID[shiori.id] ?? [.unknown]
            let cues = tableSandboxDisplayText(content: shiori.content, cueLines: shiori.cueLines)
            guard shioriMatchesSearchText(searchText, displayTitle: displayTitle, cues: cues) else {
                return nil
            }
            guard shioriMatchesFilterSet(filterSet, displayTitle: displayTitle, cues: cues, languages: languages) else {
                return nil
            }
            return TableSandboxShioriRowSource(
                shiori: shiori,
                displayTitle: displayTitle,
                dateAddedText: AppCoordinator.shioriDateAddedDisplayText(for: shiori.createdAt),
                languages: languages
            )
        }
    }

    private func shioriMatchesSearchText(
        _ searchText: String,
        displayTitle: String,
        cues: String
    ) -> Bool {
        guard !searchText.isEmpty else {
            return true
        }
        return displayTitle.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || cues.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func shioriMatchesFilterSet(
        _ filterSet: SubtitleSearchFilterSet,
        displayTitle: String,
        cues: String,
        languages: Set<SubtitleLanguageCode>
    ) -> Bool {
        let tags = SubtitleLanguageWorkbenchTags.tags(for: languages)
        let languageCandidates = Array(Set(languages.map(\.rawValue) + tags.map(\.label)))
        return filterSet.matches(
            display: displayTitle,
            cues: cues,
            languages: languageCandidates
        )
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
                applyShioris(try database.shioris())
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
                applyShioris(try database.shioris())
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
            applyShioris(try database.shioris())
            playbackViewModel.showShioriFeedback(.saved)
            return true
        } catch {
            print("Failed to toggle Shiori: \(error)")
            playbackViewModel.showShioriFeedback(.unavailable)
            return false
        }
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
