import CueSeekerCore
import Foundation

/// What playback does when an Add Folder, Index or Remove Folder changes the
/// database under it: the item playing plays on, whether or not the library
/// still holds it, and the playlist keeps what the library still holds. See
/// `docs/human/requirements/20260925-Feature-Playback Continues When Content
/// Leaves The Database.md`.
@MainActor
extension AppCoordinator {
    /// Before the pages are brought up to the change: the playlist holds the
    /// items it has now, so the stores reloading underneath no longer reach
    /// it and an open Playback Overlay keeps showing them.
    func holdPlaybackBeforeIndexedContentChange() {
        playback.subtitleFocusSession?.libraryStore?.holdDetail()
        switch playback.commandPanelPresentation?.page {
        case .recentVideos:
            playback.holdCommandPanelPage(
                .recentVideos(library.testRecentWatchingItems)
            )
        case .recentExcerpts:
            playback.holdCommandPanelPage(
                .recentExcerpts(excerpt.recentListSummaries)
            )
        case .searchResults:
            playback.holdCommandPanelPage(
                .searchResults(
                    totalCount: max(
                        search.searchResultTotalCount,
                        search.searchResults.count
                    ),
                    hasMoreResults: search.hasMoreSearchResults
                )
            )
        case .root, nil:
            break
        }
        guard let source = playback.playlistSource, !source.isHeld else {
            return
        }
        playback.holdPlaylistItems(
            source.currentItems(),
            current: currentPlaybackPlaylistIdentity
        )
        realignCueAutoStopPosition()
    }

    /// Once the change is in. Whether the item playing is still in the library
    /// is settled at once, so nothing is written for a video the database no
    /// longer holds; the playlist drops what left the library once the
    /// Playback Overlay and the Command Panel are both closed, since until
    /// then they keep showing what they had.
    func reconcilePlaybackAfterIndexedContentChange() {
        guard hasPlaybackSelection else {
            return
        }
        currentPlaybackItemLeftLibrary = !isCurrentPlaybackItemInLibrary()
        if currentPlaybackItemLeftLibrary {
            stopLibraryPlaybackHistoryTracking()
        }
        playbackAwaitsLibraryReconcile = true
        reconcilePlaybackPlaylistIfAwaiting()
    }

    func reconcilePlaybackPlaylistIfAwaiting() {
        guard playbackAwaitsLibraryReconcile,
              playback.subtitleFocusSession == nil,
              playback.commandPanelPresentation == nil
        else {
            return
        }
        playbackAwaitsLibraryReconcile = false
        guard hasPlaybackSelection else {
            return
        }
        if let source = playback.playlistSource {
            let keptItems = playlistItemsInLibrary(source.currentItems())
            playback.holdPlaylistItems(
                keptItems,
                current: currentPlaybackPlaylistIdentity
            )
            realignCueAutoStopPosition()
            if source.kind == .excerpt {
                excerptPlaybackNavigationScopeIDs = keptItems.compactMap {
                    guard case .excerpt(let item) = $0.target else {
                        return nil
                    }
                    return item.id
                }
                if !currentPlaybackItemLeftLibrary,
                   let selectedExcerpt = excerpt.selectedExcerpt {
                    _ = refreshExcerptPlaybackNavigationSnapshot(
                        for: selectedExcerpt,
                        preferredOrdinal: playback.playlistPosition?.ordinal
                    )
                }
            }
        }
        refreshPlaybackChromeSnapshot(
            displayTitle: playback.chromeSnapshot.displayTitle
        )
    }

    /// Previous, next, Auto Switch and the end of a Library video, from an
    /// item the library no longer holds: the first item of the playlist it
    /// still holds, or a word that there is none.
    func openFirstAvailablePlaybackItem(
        direction: SearchResultNavigationDirection
    ) {
        if let video = library.selectedLibraryVideo {
            guard let detail = libraryFolderDetailInLibrary(for: video),
                  let first = detail.videos.first
            else {
                playback.playbackViewModel?.showNoAvailableNavigationFeedback(
                    direction: direction,
                    text: L("playback.hud.no_available_videos")
                )
                return
            }
            playback.playbackViewModel?.showLibraryNavigationFeedback(
                direction: direction,
                hasResult: true
            )
            prepareLibraryNavigationVideos(detail.videos)
            openLibraryVideo(first.libraryVideo, displayTitle: first.displayTitle)
            return
        }

        guard let source = playback.playlistSource,
              let item = firstPlaylistItemInLibrary(in: source)
        else {
            playback.playbackViewModel?.showNoAvailableNavigationFeedback(
                direction: direction,
                text: excerpt.selectedExcerpt == nil
                    ? L("playback.hud.no_available_results")
                    : L("playback.hud.no_available_excerpts")
            )
            return
        }
        switch item.target {
        case .search(let result):
            playback.playbackViewModel?.showSearchNavigationFeedback(
                direction: direction,
                hasResult: true
            )
            let promotion: PlaybackSearchPromotion?
            if case .search = source.origin {
                promotion = PlaybackSearchPromotion(
                    query: search.searchQuery,
                    scopePaths: indexing.selectedFolders.map {
                        $0.standardizedFileURL.path
                    },
                    selectedOrdinal: item.ordinal
                )
            } else {
                promotion = nil
            }
            openSearchResult(
                result,
                playbackSearchPromotion: promotion,
                playlistSourceOverride: source
            )
        case .excerpt(let target):
            playback.playbackViewModel?.showExcerptNavigationFeedback(
                direction: direction,
                hasResult: true
            )
            guard case .excerpt(let scope) = source.origin else {
                return
            }
            openExcerpt(
                target,
                navigationScopeIDs: excerptPlaybackNavigationScopeIDs,
                playlistScope: scope,
                playlistSelectedOrdinal: item.ordinal
            )
        }
    }

    /// Whether previous and next have somewhere to go from an item the
    /// library no longer holds.
    var hasAvailablePlaybackItem: Bool {
        if let video = library.selectedLibraryVideo {
            return libraryFolderDetailInLibrary(for: video)?.videos.isEmpty == false
        }
        guard let source = playback.playlistSource else {
            return false
        }
        return firstPlaylistItemInLibrary(in: source) != nil
    }

    /// Playing an item the library no longer holds is refused on the
    /// banner's own line.
    func showPlaybackItemNotInLibrary() {
        playback.showError(L("playback.error.not_in_library"), on: .notInLibrary)
    }

    func isCueInLibrary(_ cueID: Int64) -> Bool {
        cueIDsInLibrary(among: [cueID]).contains(cueID)
    }

    /// Whether a Current or Playlist item of the Playback Overlay is one the
    /// library no longer holds. The playback page shows no other module.
    func overlayTargetLeftLibrary(
        _ target: PlaybackSubtitleFocusActionTarget
    ) -> Bool {
        switch target {
        case .current(let context):
            !isCueInLibrary(context.cue.id)
        case .playlist(let item):
            playlistItemsInLibrary([item]).isEmpty
        case .search, .excerpt:
            false
        }
    }

    /// Whether the subtitle the Playback Overlay opens on is still matched to
    /// the video playing.
    func isPlaybackSubtitleInLibrary(_ source: SubtitleFocusSourceIdentity) -> Bool {
        guard let subtitleFileID = source.subtitleFileID,
              let subtitles = try? libraryDatabase?.videoSubtitles(
                  forVideoFile: URL(fileURLWithPath: source.videoPath)
              )
        else {
            return false
        }
        return subtitles.subtitles.contains { $0.subtitleFileID == subtitleFileID }
    }

    func isCurrentPlaybackItemInLibrary() -> Bool {
        if let video = library.selectedLibraryVideo {
            return !libraryHasLost(videoPath: video.videoPath)
        }
        if let result = search.selectedSearchResult {
            return cueIDsInLibrary(among: [result.entryID])
                .contains(result.entryID)
        }
        if let selectedExcerpt = excerpt.selectedExcerpt {
            return excerptIDsInLibrary(among: [selectedExcerpt.id])
                .contains(selectedExcerpt.id)
        }
        return true
    }

    /// The items among `items` the library still holds, in their order.
    func playlistItemsInLibrary(
        _ items: [PlaybackPlaylistItem]
    ) -> [PlaybackPlaylistItem] {
        var cueIDs: [Int64] = []
        var excerptIDs: [Int64] = []
        for item in items {
            switch item.target {
            case .search(let result):
                cueIDs.append(result.entryID)
            case .excerpt(let target):
                excerptIDs.append(target.id)
            }
        }
        let liveCueIDs = cueIDsInLibrary(among: cueIDs)
        let validExcerptIDs = excerptIDsInLibrary(among: excerptIDs)
        return items.filter { item in
            switch item.target {
            case .search(let result):
                liveCueIDs.contains(result.entryID)
            case .excerpt(let target):
                validExcerptIDs.contains(target.id)
            }
        }
    }

    func cueIDsInLibrary(among cueIDs: [Int64]) -> Set<Int64> {
        guard !cueIDs.isEmpty else {
            return []
        }
        return (try? CueContentDatabase(path: databaseURL)
            .liveCueIDs(among: cueIDs)) ?? []
    }

    func excerptIDsInLibrary(among excerptIDs: [Int64]) -> Set<Int64> {
        guard !excerptIDs.isEmpty else {
            return []
        }
        return (try? excerptDatabase?.validExcerptIDs(among: excerptIDs)) ?? []
    }

    /// The Library Playlist a video belongs to, its folder, as the database
    /// holds it now.
    private func libraryFolderDetailInLibrary(
        for video: LibraryVideo
    ) -> CompleteLibraryFolderDetailPresentation? {
        try? libraryDatabase?.completeLibraryFolderDetail(
            folderPath: URL(fileURLWithPath: video.videoPath)
                .deletingLastPathComponent()
                .standardizedFileURL.path
        )
    }

    /// Looks through the playlist a hundred items at a time, so a playlist
    /// that already dropped what left the library answers from its first read.
    private func firstPlaylistItemInLibrary(
        in source: PlaybackPlaylistSource
    ) -> PlaybackPlaylistItem? {
        let totalCount = source.boundary.totalCount
        for start in stride(from: 0, to: totalCount, by: 100) {
            let items = (start..<min(start + 100, totalCount)).compactMap {
                source.item(at: $0)
            }
            if let item = playlistItemsInLibrary(items).first {
                return item
            }
        }
        return nil
    }

    private var currentPlaybackPlaylistIdentity: PlaybackPlaylistItemIdentity? {
        if let result = search.selectedSearchResult {
            return .search(result.entryID)
        }
        if let selectedExcerpt = excerpt.selectedExcerpt {
            return .excerpt(selectedExcerpt.id)
        }
        return nil
    }

    /// The cue playing keeps its Auto Pause and Auto Switch when the playlist
    /// moves it to another place, or drops it.
    private func realignCueAutoStopPosition() {
        guard activePlaylistCueSettings != nil else {
            return
        }
        activePlaylistCuePosition = playback.playlistPosition
    }
}
