import Foundation
import CueSeekerCore
import CueSeekerPlayback

struct LibraryPlaybackHistorySnapshot: Sendable {
    let videoPath: String
    let positionMilliseconds: Int
    let duration: Double?
}

final class LibraryPlaybackHistoryWriter: @unchecked Sendable {
    let database: SubtitleDatabase?
    let queue = DispatchQueue(
        label: "app.cueseeker.library-playback-history",
        qos: .utility
    )

    init(database: SubtitleDatabase?) {
        self.database = database
    }

    func save(_ snapshot: LibraryPlaybackHistorySnapshot) {
        queue.async { [weak self] in
            self?.write(snapshot)
        }
    }

    func saveAndWait(_ snapshot: LibraryPlaybackHistorySnapshot) {
        queue.sync {
            write(snapshot)
        }
    }

    func write(_ snapshot: LibraryPlaybackHistorySnapshot) {
        guard let database else {
            return
        }

        do {
            try database.upsertLibraryPlaybackHistory(
                videoFile: URL(fileURLWithPath: snapshot.videoPath),
                positionMilliseconds: snapshot.positionMilliseconds,
                duration: snapshot.duration
            )
        } catch {
            print("Failed to save Library playback history: \(error)")
        }
    }
}

@MainActor
extension AppCoordinator {
    func openPreviousLibraryVideo() {
        let hasResult = canOpenPreviousLibraryVideo
        playback.playbackViewModel?.showLibraryNavigationFeedback(direction: .previous, hasResult: hasResult)
        if hasResult {
            openAdjacentLibraryVideo(offset: -1)
        }
    }

    func openNextLibraryVideo() {
        let hasResult = canOpenNextLibraryVideo
        playback.playbackViewModel?.showLibraryNavigationFeedback(direction: .next, hasResult: hasResult)
        if hasResult {
            openAdjacentLibraryVideo(offset: 1)
        }
    }

    func refreshLibrary() {
        libraryTask?.cancel()

        let folders = indexing.selectedFolders
        guard !folders.isEmpty else {
            applyLibraryPresentation([])
            library.libraryStatus = .idle
            return
        }

        library.libraryStatus = .loading
        guard let database = subtitleDatabase else {
            applyLibraryPresentation([])
            library.libraryStatus = .failed("Database is not initialized")
            return
        }
        libraryTask = Task {
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    return try database.libraryPresentation(under: folders)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                applyLibraryPresentation(snapshot)
                library.libraryStatus = .completed
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                applyLibraryPresentation([])
                library.libraryStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }




    func hydrateLibraryAsync() {
        guard let database = subtitleDatabase, library.libraryStatus != .loading else {
            return
        }
        let folders = indexing.selectedFolders
        guard !folders.isEmpty else {
            applyLibraryPresentation([])
            library.libraryStatus = .idle
            return
        }

        library.libraryStatus = .loading
        libraryTask?.cancel()
        libraryTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.libraryPresentation(under: folders)
                }.value

                guard !Task.isCancelled else { return }

                self?.applyLibraryPresentation(snapshot)
                self?.library.libraryStatus = .completed
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to hydrate library asynchronously: \(error)")
                self?.library.libraryStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func hydrateRecentWatchingAsync() {
        if case .loading = library.recentWatchingStatus, recentWatchingTask != nil {
            return
        }
        refreshRecentWatching()
    }

    func refreshRecentWatching() {
        recentWatchingTask?.cancel()

        let folders = indexing.selectedFolders
        guard !folders.isEmpty else {
            applyRecentWatching([])
            library.recentWatchingStatus = .idle
            return
        }

        guard let database = subtitleDatabase else {
            applyRecentWatching([])
            library.recentWatchingStatus = .failed("Database is not initialized")
            return
        }

        library.recentWatchingStatus = .loading
        recentWatchingTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.recentLibraryWatching(under: folders)
                }.value

                guard !Task.isCancelled else { return }

                self?.applyRecentWatching(snapshot)
                self?.library.recentWatchingStatus = .completed
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to hydrate recent Library watching asynchronously: \(error)")
                self?.applyRecentWatching([])
                self?.library.recentWatchingStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func applyLibraryPresentation(_ snapshot: [LibraryFolderPresentation]) {
        let groups = Self.makeLibraryFolderGroups(from: snapshot)
        library.libraryFolderGroups = groups
        library.libraryVideos = groups.flatMap { group in
            group.videos.map(\.video)
        }
        library.libraryPresentationRevision += 1
        UIInvalidationProbe.count(
            "UI.LibraryPresentationSnapshot.rebuilt",
            details: "groups=\(groups.count) rows=\(library.libraryVideos.count)"
        )
    }

    func applyRecentWatching(_ snapshot: [RecentLibraryWatchingPresentation]) {
        library.recentWatchingItems = snapshot
        library.recentWatchingRevision += 1
        UIInvalidationProbe.count(
            "UI.RecentWatchingSnapshot.rebuilt",
            details: "rows=\(snapshot.count)"
        )
    }

    func removeLibraryPresentation(under folder: URL) {
        let groups = library.libraryFolderGroups.filter { group in
            !group.videos.contains { Self.path($0.video.videoPath, isUnder: folder) }
        }
        library.libraryFolderGroups = groups
        library.libraryVideos = groups.flatMap { group in
            group.videos.map(\.video)
        }
        library.libraryPresentationRevision += 1
        UIInvalidationProbe.count(
            "UI.LibraryPresentationSnapshot.rebuilt",
            details: "groups=\(groups.count) rows=\(library.libraryVideos.count) reason=remove"
        )
    }

    func openLibraryVideo(_ video: LibraryVideo, recordsNavigationHistory: Bool = true) {
        UIInvalidationProbe.mark(
            "ACTION UI.LibraryVideo.opened",
            details: "duration=\(video.duration.map { String(format: "%.2f", $0) } ?? "unknown")"
        )
        rememberPlaybackOriginatingPanelModeIfEntering()
        if case .library = activePlaybackSource {
            saveCurrentLibraryPlaybackHistory()
        }
        if recordsNavigationHistory {
            recordPlaybackNavigationEntry(playbackNavigationPayload(for: video))
        }
        recordRecentLibraryWatching(for: video)
        library.selectedLibraryVideo = video
        search.selectedSearchResult = nil
        shiori.selectedShiori = nil
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            play(video)
        }
    }

    func recordRecentLibraryWatching(for video: LibraryVideo) {
        let existingHistory = libraryPlaybackHistory(for: video)
        let snapshot = LibraryPlaybackHistorySnapshot(
            videoPath: video.videoPath,
            positionMilliseconds: existingHistory?.positionMilliseconds ?? 0,
            duration: existingHistory?.duration ?? video.duration
        )
        libraryPlaybackHistoryWriter.saveAndWait(snapshot)
        refreshRecentWatching()
    }

    func play(_ video: LibraryVideo) {
        ensurePlayerInitialized()
        clearCueSegmentPlayback()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .none
        playback.playbackStatus = .opening
        playbackSubtitleCuesTask?.cancel()
        let startMilliseconds = libraryResumePositionMilliseconds(for: video)
        let subtitleCues = initialPlaybackSubtitleCues(
            forSubtitleFile: URL(fileURLWithPath: video.subtitlePath),
            format: video.subtitleFormat,
            fallbackStartMilliseconds: startMilliseconds,
            fallbackEndMilliseconds: startMilliseconds,
            fallbackContent: "",
            fallbackCueGroupID: nil
        )
        playback.playbackViewModel?.setSubtitleCues(
            subtitleCues,
            currentTimeMilliseconds: startMilliseconds
        )

        do {
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: video.videoPath),
                startMilliseconds: startMilliseconds,
                subtitleSource: playbackSubtitleSource(
                    for: video,
                    startingAtMilliseconds: startMilliseconds
                )
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
                player.loadSubtitleSource(request.subtitleSource)
                try player.seek(toMilliseconds: request.startMilliseconds)
            } else {
                try player.open(request)
            }

            try player.setPaused(false)
            playback.playbackStatus = .playing
            startPlaybackSubtitleCuesLoad(
                forSubtitleFile: URL(fileURLWithPath: video.subtitlePath),
                format: video.subtitleFormat,
                videoPath: video.videoPath
            )
            startLibraryPlaybackHistoryTracking(videoPath: video.videoPath)
        } catch {
            playbackSubtitleCuesTask?.cancel()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func saveCurrentLibraryPlaybackHistory() {
        saveCurrentLibraryPlaybackHistory(waitUntilFinished: false)
    }

    func saveCurrentLibraryPlaybackHistorySynchronously() {
        saveCurrentLibraryPlaybackHistory(waitUntilFinished: true)
    }

    func saveCurrentLibraryPlaybackHistory(waitUntilFinished: Bool) {
        guard case .library(let videoPath) = activePlaybackSource,
              let playbackViewModel = playback.playbackViewModel
        else {
            return
        }

        let positionMilliseconds = max(
            0,
            Int((playbackViewModel.currentTime * 1_000).rounded(.down))
        )
        let duration = playbackViewModel.duration.isFinite && playbackViewModel.duration > 0
            ? playbackViewModel.duration
            : nil
        let snapshot = LibraryPlaybackHistorySnapshot(
            videoPath: videoPath,
            positionMilliseconds: positionMilliseconds,
            duration: duration
        )

        if waitUntilFinished {
            libraryPlaybackHistoryWriter.saveAndWait(snapshot)
        } else {
            libraryPlaybackHistoryWriter.save(snapshot)
        }
    }

    func libraryResumePositionMilliseconds(for video: LibraryVideo) -> Int {
        libraryPlaybackHistory(for: video)?.positionMilliseconds ?? 0
    }

    func libraryPlaybackHistory(for video: LibraryVideo) -> LibraryPlaybackHistory? {
        guard let database = subtitleDatabase else {
            return nil
        }
        do {
            return try database.libraryPlaybackHistory(
                forVideoFile: URL(fileURLWithPath: video.videoPath)
            )
        } catch {
            print("Failed to load Library playback history: \(error)")
            return nil
        }
    }

    func openAdjacentLibraryVideo(offset: Int) {
        guard let target = libraryAdjacentVideo(offset: offset) else {
            return
        }

        openLibraryVideo(target)
    }

    func libraryAdjacentVideo(offset: Int) -> LibraryVideo? {
        guard isLibraryPlaybackActive,
              let selectedLibraryVideo = library.selectedLibraryVideo,
              let currentIndex = library.libraryVideos.firstIndex(where: { $0.videoPath == selectedLibraryVideo.videoPath })
        else {
            return nil
        }

        let targetIndex = currentIndex + offset
        guard library.libraryVideos.indices.contains(targetIndex) else {
            return nil
        }

        return library.libraryVideos[targetIndex]
    }

    func startLibraryPlaybackHistoryTracking(videoPath: String) {
        activePlaybackSource = .library(videoPath: videoPath)
        libraryPlaybackHistoryTask?.cancel()
        libraryPlaybackHistoryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else {
                    return
                }

                self?.saveCurrentLibraryPlaybackHistory()
            }
        }
    }

    func stopLibraryPlaybackHistoryTracking() {
        libraryPlaybackHistoryTask?.cancel()
        libraryPlaybackHistoryTask = nil
    }
}
