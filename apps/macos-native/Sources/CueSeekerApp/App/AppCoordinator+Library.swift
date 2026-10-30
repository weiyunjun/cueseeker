import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

@MainActor
extension AppCoordinator {
    var libraryCoverDirectory: URL {
        get { library.libraryCoverDirectory }
        set { library.libraryCoverDirectory = newValue }
    }

    var libraryDatabase: LibraryDatabase? {
        get { library.libraryDatabase }
        set { library.libraryDatabase = newValue }
    }

    var indexedContentDatabase: IndexedContentDatabase? {
        get { library.indexedContentDatabase }
        set { library.indexedContentDatabase = newValue }
    }

    var libraryCoverDatabase: LibraryCoverDatabase? {
        get { library.libraryCoverDatabase }
        set { library.libraryCoverDatabase = newValue }
    }

    var libraryUserCoverService: LibraryUserCoverService? {
        get { library.libraryUserCoverService }
        set { library.libraryUserCoverService = newValue }
    }

    var libraryPlaybackHistoryWriter: LibraryPlaybackHistoryWriter {
        get { library.libraryPlaybackHistoryWriter }
        set { library.libraryPlaybackHistoryWriter = newValue }
    }

    var recentNeedsReloadAfterIndexedMutation: Bool {
        get { library.recentNeedsReloadAfterIndexedMutation }
        set { library.recentNeedsReloadAfterIndexedMutation = newValue }
    }

    var libraryNeedsReloadAfterIndexedMutation: Bool {
        get { library.libraryNeedsReloadAfterIndexedMutation }
        set { library.libraryNeedsReloadAfterIndexedMutation = newValue }
    }

    var fileNeedsReloadAfterIndexedMutation: Bool {
        get { library.fileNeedsReloadAfterIndexedMutation }
        set { library.fileNeedsReloadAfterIndexedMutation = newValue }
    }

    var libraryTask: Task<Void, Never>? {
        get { library.libraryTask }
        set { library.libraryTask = newValue }
    }

    var recentWatchingTask: Task<Void, Never>? {
        get { library.recentWatchingTask }
        set { library.recentWatchingTask = newValue }
    }

    var testRecentWatchingTask: Task<Void, Never>? {
        get { library.testRecentWatchingTask }
        set { library.testRecentWatchingTask = newValue }
    }

    var completeLibraryTask: Task<Void, Never>? {
        get { library.completeLibraryTask }
        set { library.completeLibraryTask = newValue }
    }

    var completeLibraryFolderDetailTasks: [String: Task<Void, Never>] {
        get { library.completeLibraryFolderDetailTasks }
        set { library.completeLibraryFolderDetailTasks = newValue }
    }

    var completeLibraryFolderDetailRequestIDs: [String: UUID] {
        get { library.completeLibraryFolderDetailRequestIDs }
        set { library.completeLibraryFolderDetailRequestIDs = newValue }
    }

    var completeLibraryFolderDetailGeneration: UInt64 {
        get { library.completeLibraryFolderDetailGeneration }
        set { library.completeLibraryFolderDetailGeneration = newValue }
    }

    var libraryDisplayRenditionCommitGate: LibraryCoverDisplayRenditionCommitGate {
        library.libraryDisplayRenditionCommitGate
    }

    var libraryDisplayRenditionTask: Task<Void, Never>? {
        get { library.libraryDisplayRenditionTask }
        set { library.libraryDisplayRenditionTask = newValue }
    }

    var libraryDisplayRenditionAttemptedScopeKey: String? {
        get { library.libraryDisplayRenditionAttemptedScopeKey }
        set { library.libraryDisplayRenditionAttemptedScopeKey = newValue }
    }

    var libraryDisplayRenditionGeneration: Int {
        get { library.libraryDisplayRenditionGeneration }
        set { library.libraryDisplayRenditionGeneration = newValue }
    }

    var libraryCoverImportTask: Task<Void, Never>? {
        get { library.libraryCoverImportTask }
        set { library.libraryCoverImportTask = newValue }
    }

    var libraryCoverSaveTask: Task<Void, Never>? {
        get { library.libraryCoverSaveTask }
        set { library.libraryCoverSaveTask = newValue }
    }

    var libraryPlaybackHistoryTask: Task<Void, Never>? {
        get { library.libraryPlaybackHistoryTask }
        set { library.libraryPlaybackHistoryTask = newValue }
    }

    func beginChangingLibraryCover(
        target: LibraryUserCoverTarget,
        currentCoverPath: String?,
        currentCoverRevision: String?
    ) {
        library.beginChangingLibraryCover(
            target: target,
            currentCoverPath: currentCoverPath,
            currentCoverRevision: currentCoverRevision
        )
    }

    func beginChoosingLibraryCover(_ session: LibraryCoverEditingSession) {
        library.beginChoosingLibraryCover(session)
    }

    func cancelLibraryCoverEditing() {
        library.cancelLibraryCoverEditing()
    }

    func saveLibraryCoverEditing(_ session: LibraryCoverEditingSession) {
        library.saveLibraryCoverEditing(session)
    }

    func openPreviousLibraryVideo() {
        guard !currentPlaybackItemLeftLibrary else {
            openFirstAvailablePlaybackItem(direction: .previous)
            return
        }
        let hasResult = canOpenPreviousLibraryVideo
        playback.playbackViewModel?.showLibraryNavigationFeedback(direction: .previous, hasResult: hasResult)
        if hasResult {
            openAdjacentLibraryVideo(offset: -1)
        }
    }

    func openNextLibraryVideo() {
        guard !currentPlaybackItemLeftLibrary else {
            openFirstAvailablePlaybackItem(direction: .next)
            return
        }
        let hasResult = canOpenNextLibraryVideo
        playback.playbackViewModel?.showLibraryNavigationFeedback(direction: .next, hasResult: hasResult)
        if hasResult {
            openAdjacentLibraryVideo(offset: 1)
        }
    }

    func refreshLibrary(force: Bool = false) {
        library.refreshLibrary(force: force)
    }

    func hydrateLibraryAsync() {
        library.hydrateLibraryAsync()
    }

    func hydrateRecentWatchingAsync() {
        library.hydrateRecentWatchingAsync()
    }

    func hydrateTestRecentWatchingAsync() {
        library.hydrateTestRecentWatchingAsync()
    }

    func hydrateCompleteLibraryAsync() {
        library.hydrateCompleteLibraryAsync()
    }

    func ensureLibraryDisplayRenditionsAsync() {
        library.ensureLibraryDisplayRenditionsAsync()
    }

    func cancelLibraryDisplayRenditionTask() {
        library.cancelLibraryDisplayRenditionTask()
    }

    func refreshRecentWatching(force: Bool = false) {
        library.refreshRecentWatching(force: force)
    }

    func refreshTestRecentWatching() {
        library.refreshTestRecentWatching()
    }

    func refreshLoadedTestRecentWatching(force: Bool = false) {
        library.refreshLoadedTestRecentWatching(force: force)
    }

    func refreshRecentOnReappearanceIfNeeded() {
        guard recentNeedsReloadAfterIndexedMutation else {
            return
        }
        recentNeedsReloadAfterIndexedMutation = false
        refreshTestRecentWatching()
        refreshRecentWatching(force: true)
        reloadExcerptListOverview()
    }

    func refreshCompleteLibrary(force: Bool = false) {
        library.refreshCompleteLibrary(force: force)
    }

    func refreshLibraryOnReappearanceIfNeeded() {
        library.refreshLibraryOnReappearanceIfNeeded()
    }

    func completeLibraryFolderDetailFromStore(
        folderPath: String
    ) async -> CompleteLibraryFolderDetailPresentation? {
        await library.completeLibraryFolderDetailFromStore(folderPath: folderPath)
    }

    func hydrateCompleteLibraryFolderDetailAsync(folderPath: String) {
        library.hydrateCompleteLibraryFolderDetailAsync(folderPath: folderPath)
    }

    func invalidateCompleteLibraryFolderDetails() {
        library.invalidateCompleteLibraryFolderDetails()
    }

    func prepareLibraryNavigationVideos(_ videos: [CompleteLibraryVideoPresentation]) {
        library.prepareLibraryNavigationVideos(videos)
    }

    func prepareRecentLibraryNavigation(for item: RecentLibraryWatchingPresentation) async {
        await library.prepareRecentLibraryNavigation(for: item)
    }

    func openRecentLibraryWatching(_ item: RecentLibraryWatchingPresentation) async {
        await prepareRecentLibraryNavigation(for: item)
        openLibraryVideo(item.libraryVideo, displayTitle: item.displayTitle)
    }

    func openFolder(atPath path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
    }

    func openLibraryFolderInFile(folderPath: String) {
        guard let rootURL = indexing.selectedFolders
            .filter({ Self.path(folderPath, isUnder: $0) })
            .max(by: { $0.mediaPath.count < $1.mediaPath.count }),
            (try? libraryDatabase?.completeLibraryFolderDetail(folderPath: folderPath)) != nil
        else {
            toast.show(LibraryToastRequest.folderNotInLibrary)
            return
        }

        refreshFileOnReappearanceIfNeeded()
        let rootPath = rootURL.mediaPath
        let standardizedFolder = Self.normalizedFolderPath(URL.fromMediaPath(folderPath).mediaPath)
        let standardizedRoot = Self.normalizedFolderPath(URL.fromMediaPath(rootPath).mediaPath)
        if standardizedFolder == standardizedRoot {
            loadFileSubfolders(rootPath: rootPath)
            navigateWorkbench(to: .fileFolder(rootPath: rootPath))
        } else {
            loadFileObjects(folderPath: folderPath)
            navigateWorkbench(to: .fileFiles(rootPath: rootPath, folderPath: folderPath))
        }
    }

    func markLibraryVideo(_ video: LibraryVideo, as state: LibraryWatchState) {
        library.markLibraryVideo(video, as: state)
    }

    func markCompleteLibraryFolder(folderPath: String, as state: LibraryWatchState) {
        library.markCompleteLibraryFolder(folderPath: folderPath, as: state)
    }

    func refreshLibraryPlaybackHistoryPresentations(
        affectedVideoPaths: Set<String>
    ) {
        library.refreshLibraryPlaybackHistoryPresentations(
            affectedVideoPaths: affectedVideoPaths
        )
    }

    func applyLibraryPresentation(_ snapshot: [LibraryFolderPresentation]) {
        library.applyLibraryPresentation(snapshot)
    }

    func applyRecentWatching(_ snapshot: [RecentLibraryWatchingPresentation]) {
        library.applyRecentWatching(snapshot)
    }

    func applyTestRecentWatching(_ snapshot: [RecentLibraryWatchingPresentation]) {
        library.applyTestRecentWatching(snapshot)
    }

    func applyCompleteLibrary(_ snapshot: [CompleteLibraryFolderSummaryPresentation]) {
        library.applyCompleteLibrary(snapshot)
    }

    func removeLibraryPresentation(under folder: URL) {
        library.removeLibraryPresentation(under: folder)
    }

    func removeCompleteLibraryPresentation(under folder: URL) {
        library.removeCompleteLibraryPresentation(under: folder)
    }

    func openLibraryVideo(
        _ video: LibraryVideo,
        displayTitle: String? = nil,
        savesCurrentPlaybackHistory: Bool = true
    ) {
        ensurePlayerInitialized()
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        playback.clearPlaylistSource()
        playback.playbackStatus = .opening
        UIInvalidationProbe.mark(
            "ACTION UI.LibraryVideo.opened",
            details: "duration=\(video.duration.map { String(format: "%.2f", $0) } ?? "unknown")"
        )
        preparePlaybackKeyboardFocus()
        if savesCurrentPlaybackHistory, case .library = activePlaybackSource {
            saveCurrentLibraryPlaybackHistory()
        }
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .library(videoPath: video.videoPath)
        let itemInLibrary = !libraryHasLost(videoPath: video.videoPath)
        currentPlaybackItemLeftLibrary = !itemInLibrary
        library.selectedLibraryVideo = video
        search.selectResult(nil)
        excerpt.selectedExcerpt = nil
        let navigationAvailability = libraryNavigationAvailability(for: video)
        setPlaybackChromeSnapshot(
            displayTitle: playbackDisplayTitle(
                for: video,
                providedDisplayTitle: displayTitle
            ),
            canGoPrevious: navigationAvailability.previous,
            canGoNext: navigationAvailability.next
        )
        playback.isPlaybackSurfaceExpanded = true
        if !itemInLibrary {
            cancelPendingPlaybackOpenTask()
            playback.clearPlaylistPosition()
            playback.playbackStatus = .loadFailed
            try? player?.stop()
            playback.playbackViewModel?.resetPresentationForStoppedPlayback()
            showPlaybackItemNotInLibrary()
        } else {
            playback.clearError(on: .notInLibrary)
            let startMilliseconds = libraryResumePositionMilliseconds(for: video)
            let targetSubtitle = defaultPlaybackSubtitle(forVideoPath: video.videoPath)
            preparePlaybackTransition(
                forVideoPath: video.videoPath,
                startMilliseconds: startMilliseconds,
                subtitleCues: [],
                resetsLoadingTimer: true
            )
            schedulePlaybackOpen(
                videoPath: video.videoPath,
                subtitlePath: targetSubtitle?.subtitlePath ?? video.subtitlePath
            ) { [weak self] in
                guard let self else { return }
                let didStartPlayback = self.play(video)
                if didStartPlayback {
                    self.recordRecentLibraryWatching(for: video)
                }
            }
        }
    }

    func recordRecentLibraryWatching(
        for video: LibraryVideo,
        refreshPresentation: Bool = true
    ) {
        guard !currentPlaybackItemLeftLibrary else {
            return
        }
        let existingHistory = libraryPlaybackHistory(for: video)
        let snapshot = LibraryPlaybackHistorySnapshot(
            videoPath: video.videoPath,
            positionMilliseconds: existingHistory?.positionMilliseconds ?? 0,
            duration: existingHistory?.duration ?? video.duration
        )
        libraryPlaybackHistoryWriter.save(snapshot)
        pendingLibraryPlaybackHistoryPresentationVideoPaths.insert(video.videoPath)
        guard refreshPresentation else {
            UIInvalidationProbe.mark(
                "ACTION UI.LibraryPlaybackHistory.recorded",
                details: "presentationRefresh=false"
            )
            return
        }
        flushPendingLibraryPlaybackHistoryPresentations()
    }

    @discardableResult
    func play(_ video: LibraryVideo) -> Bool {
        ensurePlayerInitialized()
        let targetDecodeMode = prepareDecodeModeForPlayback(videoPath: video.videoPath)
        let codec = libraryDatabase?.videoCodec(forVideoPath: video.videoPath) ?? "unknown"
        let videoName = URL.fromMediaPath(video.videoPath).lastPathComponent
        AppLogger.shared.info(
            .playback,
            "Playback requested",
            details: "source=library video=\"\(videoName)\" codec=\(codec) setting_mode=\(settings.playbackDecodeMode.rawValue) target_mode=\(targetDecodeMode.rawValue)"
        )
        clearCueAutoStopPlayback()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .library(videoPath: video.videoPath)
        playbackSubtitle = defaultPlaybackSubtitle(forVideoPath: video.videoPath)
        playback.playbackStatus = .opening
        playback.clearError(on: .video)
        playback.clearError(on: .notInLibrary)
        let startMilliseconds = libraryResumePositionMilliseconds(for: video)
        preparePlaybackTransition(
            forVideoPath: video.videoPath,
            startMilliseconds: startMilliseconds,
            subtitleCues: [],
            resetsLoadingTimer: false
        )

        do {
            let request = try PlaybackRequest(
                videoURL: URL.fromMediaPath(video.videoPath),
                startMilliseconds: startMilliseconds,
                subtitleSource: loadablePlaybackSubtitleSource(
                    playbackSubtitleSource(
                        forSubtitleFile: URL.fromMediaPath(playbackSubtitle?.subtitlePath ?? video.subtitlePath),
                        format: playbackSubtitle?.format ?? video.subtitleFormat,
                        videoPath: video.videoPath,
                        startingAtMilliseconds: startMilliseconds,
                        fallbackEndMilliseconds: startMilliseconds
                    )
                ),
                audioTrackIndex: defaultAudioTrackIndex(forVideoPath: video.videoPath)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            let generation: UInt
            if canSeekInOpenVideo(for: request) {
                generation = try player.seek(
                    toMilliseconds: request.startMilliseconds,
                    subtitleSource: request.subtitleSource
                )
            } else {
                generation = try player.open(request)
            }

            playback.playbackViewModel?.bindPendingPresentation(to: generation)
            startLibraryPlaybackHistoryTracking(videoPath: video.videoPath)
            return true
        } catch {
            handlePlaybackOpenFailure(error, videoPath: video.videoPath)
            // Still the Library's video, so its neighbours and the Library
            // Playlist stay reachable.
            activePlaybackSource = .library(videoPath: video.videoPath)
            return false
        }
    }

    func saveCurrentLibraryPlaybackHistory() {
        saveCurrentLibraryPlaybackHistory(waitUntilFinished: false)
    }

    func saveCurrentLibraryPlaybackHistorySynchronously() {
        if !saveCurrentLibraryPlaybackHistory(waitUntilFinished: true) {
            libraryPlaybackHistoryWriter.flush()
        }
    }

    func markCurrentLibraryPlaybackCompletedIfNeeded(
        currentTime: Double,
        duration: Double
    ) {
        guard case .library(let videoPath) = activePlaybackSource,
              !currentPlaybackItemLeftLibrary,
              libraryPlaybackCompletedMilestoneVideoPath != videoPath,
              duration.isFinite,
              duration > 0
        else {
            return
        }

        let positionMilliseconds = max(
            0,
            Int((currentTime * 1_000).rounded(.down))
        )
        let snapshot = libraryPlaybackHistorySnapshot(
            videoPath: videoPath,
            positionMilliseconds: positionMilliseconds,
            duration: duration
        )
        guard snapshot.markCompleted else {
            return
        }

        pendingLibraryPlaybackHistoryPresentationVideoPaths.insert(videoPath)
        libraryPlaybackHistoryWriter.save(snapshot)
    }

    func saveCurrentLibraryPlaybackHistoryForPlaybackClose() {
        if case .library = activePlaybackSource {
            _ = saveCurrentLibraryPlaybackHistory(waitUntilFinished: true)
        }
        flushPendingLibraryPlaybackHistoryPresentations()
    }

    func flushPendingLibraryPlaybackHistoryPresentations() {
        libraryPlaybackHistoryWriter.flush()
        let affectedVideoPaths = pendingLibraryPlaybackHistoryPresentationVideoPaths
        guard !affectedVideoPaths.isEmpty else {
            return
        }
        pendingLibraryPlaybackHistoryPresentationVideoPaths = []
        refreshLibraryPlaybackHistoryPresentations(
            affectedVideoPaths: affectedVideoPaths
        )
    }

    @discardableResult
    func saveCurrentLibraryPlaybackHistory(waitUntilFinished: Bool) -> Bool {
        // A video that failed to load was never played, so its history keeps
        // what it had, also while the next video is opening. One the library
        // no longer holds has no history to keep.
        guard case .library(let videoPath) = activePlaybackSource,
              !currentPlaybackItemLeftLibrary,
              let playbackViewModel = playback.playbackViewModel,
              !playbackViewModel.isPlayerEmpty,
              !playbackViewModel.isOpeningNewVideo
        else {
            return false
        }

        let positionMilliseconds = max(
            0,
            Int((playbackViewModel.currentTime * 1_000).rounded(.down))
        )
        let duration = playbackViewModel.duration.isFinite && playbackViewModel.duration > 0
            ? playbackViewModel.duration
            : nil
        let snapshot = libraryPlaybackHistorySnapshot(
            videoPath: videoPath,
            positionMilliseconds: positionMilliseconds,
            duration: duration
        )
        pendingLibraryPlaybackHistoryPresentationVideoPaths.insert(videoPath)

        if waitUntilFinished {
            libraryPlaybackHistoryWriter.saveAndWait(snapshot)
        } else {
            libraryPlaybackHistoryWriter.save(snapshot)
        }
        return true
    }

    private func libraryPlaybackHistorySnapshot(
        videoPath: String,
        positionMilliseconds: Int,
        duration: Double?
    ) -> LibraryPlaybackHistorySnapshot {
        let markCompleted = shouldMarkLibraryPlaybackCompleted(
            videoPath: videoPath,
            positionMilliseconds: positionMilliseconds,
            duration: duration
        )
        if markCompleted {
            libraryPlaybackCompletedMilestoneVideoPath = videoPath
        }

        return LibraryPlaybackHistorySnapshot(
            videoPath: videoPath,
            positionMilliseconds: positionMilliseconds,
            duration: duration,
            markCompleted: markCompleted
        )
    }

    private func shouldMarkLibraryPlaybackCompleted(
        videoPath: String,
        positionMilliseconds: Int,
        duration: Double?
    ) -> Bool {
        guard libraryPlaybackCompletedMilestoneVideoPath != videoPath,
              let duration,
              duration.isFinite,
              duration > 0,
              let finishPointMilliseconds = SubtitlePlaybackFinishMetadata.finishPointMilliseconds(
                metadata: libraryPlaybackFinishMetadata,
                videoDuration: duration
              )
        else {
            return false
        }

        return positionMilliseconds >= finishPointMilliseconds
    }

    func libraryResumePositionMilliseconds(for video: LibraryVideo) -> Int {
        LibraryPlaybackIntentResolver.startPositionMilliseconds(
            history: libraryPlaybackHistory(for: video)
        )
    }

    func shouldRestartLibraryPlaybackFromBeginningOnPlay() -> Bool {
        guard case .library(let videoPath) = activePlaybackSource,
              let selectedLibraryVideo = library.selectedLibraryVideo,
              selectedLibraryVideo.videoPath == videoPath,
              let playbackViewModel = playback.playbackViewModel
        else {
            return false
        }

        let resolvedDuration = [
            playbackViewModel.duration,
            selectedLibraryVideo.duration
        ]
        .compactMap { $0 }
        .first { $0.isFinite && $0 > 0 }

        return LibraryPlaybackIntentResolver.shouldRestartFromBeginningOnPlay(
            hasNextVideo: libraryAdjacentVideo(offset: 1) != nil,
            currentTime: playbackViewModel.currentTime,
            duration: resolvedDuration
        )
    }

    func handlePlaybackFinishedNaturally() {
        guard case .library(let videoPath) = activePlaybackSource,
              library.selectedLibraryVideo?.videoPath == videoPath
        else {
            return
        }

        playback.playbackStatus = .paused
        guard !currentPlaybackItemLeftLibrary else {
            openFirstAvailablePlaybackItem(direction: .next)
            return
        }
        persistNaturallyCompletedLibraryPlayback(videoPath: videoPath)

        let nextVideo = libraryAdjacentVideo(offset: 1)
        let action = LibraryPlaybackIntentResolver.completionAction(
            hasNextVideo: nextVideo != nil
        )
        guard action == .playNextVideo, let nextVideo else {
            return
        }

        openLibraryVideo(
            nextVideo,
            savesCurrentPlaybackHistory: false
        )
    }

    private func persistNaturallyCompletedLibraryPlayback(videoPath: String) {
        let playbackViewModel = playback.playbackViewModel
        let resolvedDuration = [
            playbackViewModel?.duration,
            library.selectedLibraryVideo?.duration
        ]
        .compactMap { $0 }
        .first { $0.isFinite && $0 > 0 }
        playbackViewModel?.completeNaturalPlaybackAtEnd(
            fallbackDuration: resolvedDuration
        )
        let positionMilliseconds = resolvedDuration.map {
            max(0, Int(($0 * 1_000).rounded(.down)))
        } ?? max(
            0,
            Int(((playbackViewModel?.currentTime ?? 0) * 1_000).rounded(.down))
        )
        libraryPlaybackCompletedMilestoneVideoPath = videoPath
        pendingLibraryPlaybackHistoryPresentationVideoPaths.insert(videoPath)
        libraryPlaybackHistoryWriter.save(
            LibraryPlaybackHistorySnapshot(
                videoPath: videoPath,
                positionMilliseconds: positionMilliseconds,
                duration: resolvedDuration,
                markCompleted: true
            )
        )
    }

    func libraryPlaybackHistory(for video: LibraryVideo) -> LibraryPlaybackHistory? {
        guard let database = libraryDatabase else {
            return nil
        }
        libraryPlaybackHistoryWriter.flush()
        do {
            return try database.libraryPlaybackHistory(
                forVideoFile: URL.fromMediaPath(video.videoPath)
            )
        } catch {
            AppLogger.shared.error(
                .database,
                "Failed to load Library playback history",
                details: "error=\"\(error.localizedDescription)\""
            )
            return nil
        }
    }

    func openAdjacentLibraryVideo(offset: Int) {
        guard let target = libraryAdjacentVideo(offset: offset) else {
            return
        }

        openLibraryVideo(target)
    }

    func libraryNavigationAvailability(for video: LibraryVideo) -> (previous: Bool, next: Bool) {
        (
            previous: libraryAdjacentVideo(to: video, offset: -1) != nil,
            next: libraryAdjacentVideo(to: video, offset: 1) != nil
        )
    }

    func libraryAdjacentVideo(offset: Int) -> LibraryVideo? {
        guard isLibraryPlaybackActive,
              let selectedLibraryVideo = library.selectedLibraryVideo
        else {
            return nil
        }

        return libraryAdjacentVideo(to: selectedLibraryVideo, offset: offset)
    }

    func libraryAdjacentVideo(to selectedLibraryVideo: LibraryVideo, offset: Int) -> LibraryVideo? {
        let navigationVideos = library.libraryPlaybackNavigationVideos.contains { $0.videoPath == selectedLibraryVideo.videoPath }
            ? library.libraryPlaybackNavigationVideos
            : library.libraryVideos
        guard let currentIndex = navigationVideos.firstIndex(where: { $0.videoPath == selectedLibraryVideo.videoPath }) else {
            return nil
        }

        let targetIndex = currentIndex + offset
        guard navigationVideos.indices.contains(targetIndex) else {
            return nil
        }

        return navigationVideos[targetIndex]
    }

    func startLibraryPlaybackHistoryTracking(videoPath: String) {
        activePlaybackSource = .library(videoPath: videoPath)
        if let selectedLibraryVideo = library.selectedLibraryVideo,
           selectedLibraryVideo.videoPath == videoPath {
            let navigationAvailability = libraryNavigationAvailability(for: selectedLibraryVideo)
            setPlaybackChromeSnapshot(
                displayTitle: playback.chromeSnapshot.displayTitle,
                canGoPrevious: navigationAvailability.previous,
                canGoNext: navigationAvailability.next
            )
        }
        let videoFile = URL.fromMediaPath(videoPath)
        libraryPlaybackFinishMetadata = try? playbackSubtitleDatabase?
            .playbackFinishMetadata(forVideoFile: videoFile)
        libraryPlaybackCompletedMilestoneVideoPath = nil
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
        libraryPlaybackCompletedMilestoneVideoPath = nil
        libraryPlaybackFinishMetadata = nil
    }
}
