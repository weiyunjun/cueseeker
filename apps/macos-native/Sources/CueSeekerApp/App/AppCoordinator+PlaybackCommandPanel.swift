import AppKit
import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
    @discardableResult
    func presentPlaybackCommandPanel() -> Bool {
        guard isPlaybackPageVisible else {
            return false
        }
        guard preparePlaybackCommandPanelPresentation() else {
            return false
        }

        guard var presentation = playback.commandPanelPresentation else {
            return false
        }
        presentation.page = .root
        presentation.query = ""
        presentation.selectedOrdinal = 0
        presentation.selectedVideoPresentation = nil
        playback.presentCommandPanel(presentation)
        preparePlaybackKeyboardFocus()
        return true
    }

    @discardableResult
    func presentPlaybackCommandPanelSearch(
        query: String,
        startsSearch: Bool
    ) -> Bool {
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard isPlaybackPageVisible, !trimmedQuery.isEmpty else {
            return false
        }
        guard preparePlaybackCommandPanelPresentation() else {
            return false
        }

        search.searchQuery = trimmedQuery
        search.searchNavigationSnapshot = nil
        search.isPlaybackTemporaryFilterActive = true
        if startsSearch {
            startSearch(
                query: trimmedQuery,
                cursor: .start,
                appending: false,
                debounce: false,
                filterSetOverride: SubtitleSearchFilterSet()
            )
        }

        guard var presentation = playback.commandPanelPresentation else {
            return false
        }
        presentation.page = .searchResults
        presentation.query = trimmedQuery
        presentation.selectedOrdinal = nil
        presentation.selectedVideoPresentation = nil
        playback.presentCommandPanel(presentation)
        synchronizePlaybackCommandPanelSearchResults()
        preparePlaybackKeyboardFocus()
        return true
    }

    func updatePlaybackCommandPanelQuery(_ query: String) {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .root
        else {
            return
        }
        var updated = presentation
        updated.query = query
        updated.selectedOrdinal = 0
        playback.presentCommandPanel(updated)
    }

    @discardableResult
    func submitPlaybackCommandPanelSearch() -> Bool {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .root
        else {
            return false
        }
        let trimmedQuery = presentation.query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedQuery.isEmpty else {
            return openSelectedPlaybackCommandPanelItem()
        }
        return presentPlaybackCommandPanelSearch(
            query: trimmedQuery,
            startsSearch: true
        )
    }

    @discardableResult
    func presentPlaybackCommandPanelPage(
        _ page: PlaybackCommandPanelPage
    ) -> Bool {
        guard var presentation = playback.commandPanelPresentation,
              presentation.page == .root,
              page == .recentVideos || page == .recentShioris
        else {
            return false
        }

        switch page {
        case .recentVideos:
            hydrateTestRecentWatchingAsync()
        case .recentShioris:
            reloadShioriListOverview()
        case .root, .searchResults:
            return false
        }

        presentation.page = page
        presentation.selectedOrdinal =
            playbackCommandPanelItemCount(for: page) > 0 ? 0 : nil
        presentation.selectedVideoPresentation = nil
        playback.presentCommandPanel(presentation)
        preparePlaybackKeyboardFocus()
        return true
    }

    @discardableResult
    func movePlaybackCommandPanelSelection(_ offset: Int) -> Bool {
        guard var presentation = playback.commandPanelPresentation else {
            return false
        }
        let itemCount = playbackCommandPanelItemCount(for: presentation.page)
        guard itemCount > 0 else {
            presentation.selectedOrdinal = nil
            playback.presentCommandPanel(presentation)
            return true
        }

        let current = presentation.selectedOrdinal ?? 0
        let target = min(max(0, current + offset), itemCount - 1)
        presentation.selectedOrdinal = target
        if presentation.page == .searchResults {
            presentation.selectedVideoPresentation =
                playbackVideoPresentation(
                    videoPath: search.searchResults[target].videoPath
                )
        }
        playback.presentCommandPanel(presentation)
        return true
    }

    func synchronizePlaybackCommandPanelSelection() {
        guard var presentation = playback.commandPanelPresentation else {
            return
        }
        let itemCount = playbackCommandPanelItemCount(for: presentation.page)
        presentation.selectedOrdinal = itemCount > 0
            ? min(max(0, presentation.selectedOrdinal ?? 0), itemCount - 1)
            : nil
        if presentation.page == .searchResults {
            presentation.selectedVideoPresentation =
                presentation.selectedOrdinal.flatMap {
                    playbackVideoPresentation(
                        videoPath: search.searchResults[$0].videoPath
                    )
                }
        }
        playback.presentCommandPanel(presentation)
    }

    @discardableResult
    func openSelectedPlaybackCommandPanelItem() -> Bool {
        guard let presentation = playback.commandPanelPresentation,
              let selectedOrdinal = presentation.selectedOrdinal
        else {
            return false
        }

        switch presentation.page {
        case .root:
            let hasQuery = !presentation.query.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
            if hasQuery, selectedOrdinal == 0 {
                return presentPlaybackCommandPanelSearch(
                    query: presentation.query,
                    startsSearch: true
                )
            }
            let recentOrdinal = selectedOrdinal - (hasQuery ? 1 : 0)
            if recentOrdinal == 0 {
                return presentPlaybackCommandPanelPage(.recentVideos)
            }
            if recentOrdinal == 1 {
                return presentPlaybackCommandPanelPage(.recentShioris)
            }
            return false
        case .searchResults:
            return requestPlaybackCommandPanelSearchAction(
                .playFromThisCue,
                ordinal: selectedOrdinal
            )
        case .recentVideos:
            return openPlaybackCommandPanelRecentVideo(
                at: selectedOrdinal
            )
        case .recentShioris:
            return openPlaybackCommandPanelRecentShiori(
                at: selectedOrdinal
            )
        }
    }

    func synchronizePlaybackCommandPanelSearchResults() {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .searchResults
        else {
            return
        }

        let previewCount = min(
            search.searchResults.count,
            PlaybackCommandPanelPresentation.previewLimit
        )
        let selectedOrdinal: Int?
        if previewCount == 0 {
            selectedOrdinal = nil
        } else if let current = presentation.selectedOrdinal {
            selectedOrdinal = min(max(0, current), previewCount - 1)
        } else {
            selectedOrdinal = 0
        }
        let selectedResult = selectedOrdinal.flatMap {
            search.searchResults.indices.contains($0)
                ? search.searchResults[$0]
                : nil
        }

        var updated = presentation
        updated.selectedOrdinal = selectedOrdinal
        updated.selectedVideoPresentation = selectedResult.flatMap {
            playbackVideoPresentation(videoPath: $0.videoPath)
        }
        playback.presentCommandPanel(updated)
    }

    @discardableResult
    func requestPlaybackCommandPanelSearchAction(
        _ action: PlaybackSubtitleFocusAction,
        ordinal requestedOrdinal: Int? = nil
    ) -> Bool {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .searchResults,
              let ordinal = requestedOrdinal ?? presentation.selectedOrdinal,
              ordinal >= 0,
              ordinal < PlaybackCommandPanelPresentation.previewLimit,
              search.searchResults.indices.contains(ordinal)
        else {
            return false
        }

        let result = search.searchResults[ordinal]
        switch action {
        case .shiori:
            startPlaybackCommandPanelShioriSave(
                PlaybackPlaylistItem(
                    searchResult: result,
                    ordinal: ordinal
                )
            )
        case .copyCueText:
            let copied = PlaybackSubtitleFocusClipboard.copy(
                result.content,
                to: .general
            )
            playback.playbackViewModel?
                .showSubtitleCopyFeedback(copied: copied)
        case .copyCueMarkdownLink:
            let copied = PlaybackSubtitleFocusClipboard.copyMarkdownLink(
                cueText: result.content,
                cueID: result.entryID,
                to: .general
            )
            playback.playbackViewModel?
                .showSubtitleMarkdownLinkCopyFeedback(copied: copied)
        case .playFromThisCue:
            guard dismissPlaybackCommandPanelForAction(
                finishesPlaybackSearchHost: false
            ) else {
                return false
            }
            openSearchResult(
                result,
                playbackSearchPromotion: PlaybackSearchPromotion(
                    query: search.searchQuery,
                    scopePaths: indexing.selectedFolders.map {
                        $0.standardizedFileURL.path
                    },
                    selectedOrdinal: ordinal
                )
            )
        }
        return true
    }

    @discardableResult
    func openPlaybackCommandPanelRecentVideo(at ordinal: Int) -> Bool {
        guard playback.commandPanelPresentation?.page == .recentVideos,
              library.testRecentWatchingItems.indices.contains(ordinal)
        else {
            return false
        }
        let item = library.testRecentWatchingItems[ordinal]
        guard dismissPlaybackCommandPanelForAction() else {
            return false
        }
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await prepareRecentLibraryNavigation(for: item)
            openLibraryVideo(
                item.libraryVideo,
                displayTitle: item.displayTitle,
                playbackReturnContextOnSuccessfulPlay: .recent
            )
        }
        return true
    }

    @discardableResult
    func openPlaybackCommandPanelRecentShiori(at ordinal: Int) -> Bool {
        guard playback.commandPanelPresentation?.page == .recentShioris,
              shiori.recentListSummaries.indices.contains(ordinal)
        else {
            return false
        }
        let summary = shiori.recentListSummaries[ordinal]
        guard dismissPlaybackCommandPanelForAction() else {
            return false
        }
        openRecentShiori(summary)
        return true
    }

    @discardableResult
    func returnPlaybackCommandPanelToRoot() -> Bool {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page != .root
        else {
            return false
        }
        var updated = presentation
        updated.page = .root
        updated.selectedOrdinal = 0
        updated.selectedVideoPresentation = nil
        playback.presentCommandPanel(updated)
        preparePlaybackKeyboardFocus()
        return true
    }

    @discardableResult
    func dismissPlaybackCommandPanelFromUser() -> Bool {
        guard let presentation = playback.dismissCommandPanel() else {
            return false
        }
        finishPlaybackSearchHost(committingEmptyFilter: false)
        if presentation.resumesPlaybackOnDismiss,
           playback.subtitleFocusSession == nil {
            resumePlayback()
        }
        return true
    }

    private func dismissPlaybackCommandPanelForAction(
        finishesPlaybackSearchHost: Bool = true
    ) -> Bool {
        guard playback.dismissCommandPanel() != nil else {
            return false
        }
        if finishesPlaybackSearchHost {
            finishPlaybackSearchHost(committingEmptyFilter: false)
        }
        return true
    }

    private func playbackCommandPanelItemCount(
        for page: PlaybackCommandPanelPage
    ) -> Int {
        switch page {
        case .root:
            guard let query = playback.commandPanelPresentation?.query else {
                return 0
            }
            return query.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty ? 2 : 3
        case .searchResults:
            return min(
                search.searchResults.count,
                PlaybackCommandPanelPresentation.previewLimit
            )
        case .recentVideos:
            return library.testRecentWatchingItems.count
        case .recentShioris:
            return shiori.recentListSummaries.count
        }
    }

    private func startPlaybackCommandPanelShioriSave(
        _ item: PlaybackPlaylistItem
    ) {
        guard let actionContext = item.actionContext,
              !actionContext.cue.text.isEmpty
        else {
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            return
        }

        cancelPlaybackSubtitleFocusActionTask()
        let taskGeneration = playbackSubtitleFocusActionGeneration
        let databaseReader = playbackSubtitleFocusDatabaseReader
        playbackSubtitleFocusActionTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let result = try await databaseReader.saveShiori(
                    context: actionContext
                )
                guard playbackSubtitleFocusActionGeneration == taskGeneration
                else {
                    return
                }
                playbackSubtitleFocusActionTask = nil
                switch result {
                case .saved(let listID, let uniqueCueCount):
                    shiori.markTableRowsStale()
                    _ = shiori.adjustListCueCounts(
                        [listID: 1],
                        uniqueCueCount: uniqueCueCount
                    )
                    playback.playbackViewModel?.showShioriFeedback(.saved)
                case .alreadySaved:
                    playback.playbackViewModel?
                        .showShioriFeedback(.alreadySaved)
                }
            } catch is CancellationError {
                if playbackSubtitleFocusActionGeneration == taskGeneration {
                    playbackSubtitleFocusActionTask = nil
                }
            } catch {
                guard playbackSubtitleFocusActionGeneration == taskGeneration
                else {
                    return
                }
                playbackSubtitleFocusActionTask = nil
                print("Failed to save Playback Command Panel Shiori: \(error)")
                playback.playbackViewModel?
                    .showShioriFeedback(.unavailable)
            }
        }
    }

    private func preparePlaybackCommandPanelPresentation() -> Bool {
        if playback.commandPanelPresentation != nil {
            return true
        }
        let wasPlaying = playback.playbackViewModel?.isPlaying == true
        guard suspendPlaybackForModalPresentation(
            wasPlaying: wasPlaying
        ) else {
            return false
        }
        playback.presentCommandPanel(
            PlaybackCommandPanelPresentation(
                page: .root,
                query: "",
                selectedOrdinal: 0,
                selectedVideoPresentation: nil,
                resumesPlaybackOnDismiss:
                    playback.subtitleFocusSession == nil && wasPlaying
            )
        )
        return true
    }

    func playbackVideoPresentation(
        videoPath: String
    ) -> CompleteLibraryVideoPresentation? {
        let standardizedVideoPath = URL(fileURLWithPath: videoPath)
            .standardizedFileURL.path
        for detail in library.completeLibraryFolderDetailsByPath.values {
            if let video = detail.videos.first(
                where: { $0.videoPath == standardizedVideoPath }
            ) {
                return video
            }
        }
        return try? libraryDatabase?
            .completeLibraryFolderDetail(
                folderPath: URL(fileURLWithPath: standardizedVideoPath)
                    .deletingLastPathComponent()
                    .path
            )?
            .videos
            .first { $0.videoPath == standardizedVideoPath }
    }
}
