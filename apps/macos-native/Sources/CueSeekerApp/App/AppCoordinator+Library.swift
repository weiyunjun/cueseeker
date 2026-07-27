import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

struct LibraryPlaybackHistorySnapshot: Sendable {
    let videoPath: String
    let positionMilliseconds: Int
    let duration: Double?
    let markStarted: Bool
    let markCompleted: Bool

    init(
        videoPath: String,
        positionMilliseconds: Int,
        duration: Double?,
        markStarted: Bool = true,
        markCompleted: Bool = false
    ) {
        self.videoPath = videoPath
        self.positionMilliseconds = positionMilliseconds
        self.duration = duration
        self.markStarted = markStarted
        self.markCompleted = markCompleted
    }
}

struct LibraryWatchStateSnapshot: Sendable {
    let videoPath: String
    let duration: Double?
    let state: LibraryWatchState
}

final class LibraryPlaybackHistoryWriter: @unchecked Sendable {
    let database: LibraryDatabase?
    let queue = DispatchQueue(
        label: "app.cueseeker.library-playback-history",
        qos: .utility
    )

    init(database: LibraryDatabase?) {
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

    func flush() {
        queue.sync {}
    }

    func write(_ snapshot: LibraryPlaybackHistorySnapshot) {
        guard let database else {
            return
        }

        do {
            try database.upsertLibraryPlaybackHistory(
                videoFile: URL(fileURLWithPath: snapshot.videoPath),
                positionMilliseconds: snapshot.positionMilliseconds,
                duration: snapshot.duration,
                markStarted: snapshot.markStarted,
                markCompleted: snapshot.markCompleted
            )
        } catch {
            print("Failed to save Library playback history: \(error)")
        }
    }

    func setWatchStatesAndWait(_ snapshots: [LibraryWatchStateSnapshot]) {
        queue.sync {
            setWatchStates(snapshots)
        }
    }

    private func setWatchStates(_ snapshots: [LibraryWatchStateSnapshot]) {
        guard let database else {
            return
        }

        for snapshot in snapshots {
            do {
                try database.setLibraryWatchState(
                    videoFile: URL(fileURLWithPath: snapshot.videoPath),
                    duration: snapshot.duration,
                    state: snapshot.state
                )
            } catch {
                print("Failed to set Library watch state: \(error)")
            }
        }
    }
}

@MainActor
extension AppCoordinator {
    func beginChangingLibraryCover(target: LibraryUserCoverTarget) {
        guard library.coverEditingSession == nil else {
            return
        }

        let panel = NSOpenPanel()
        let delegate = LibraryCoverOpenPanelDelegate()
        panel.delegate = delegate
        panel.title = "Choose Cover Image"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = LibraryCoverOpenPanelPolicy.allowedContentTypes
        panel.allowsOtherFileTypes = false

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self, delegate] response in
            _ = delegate
            guard let self,
                  response == .OK,
                  let sourceURL = panel.url
            else {
                return
            }

            self.libraryCoverImportTask?.cancel()
            self.libraryCoverImportTask = Task { [weak self] in
                do {
                    let source = try await Task.detached(priority: .userInitiated) {
                        try LibraryUserCoverProcessor.loadSource(at: sourceURL)
                    }.value
                    try Task.checkCancellation()
                    guard let self else {
                        return
                    }
                    self.library.coverEditingSession = LibraryCoverEditingSession(
                        target: target,
                        source: source
                    )
                } catch is CancellationError {
                    return
                } catch {
                    print("Failed to load Library cover source: \(error)")
                }
            }
        }

        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
            return
        }
        completion(panel.runModal())
    }

    func cancelLibraryCoverEditing() {
        guard library.coverEditingSession?.isSaving != true else {
            return
        }
        library.coverEditingSession = nil
    }

    func saveLibraryCoverEditing(_ session: LibraryCoverEditingSession) {
        guard library.coverEditingSession?.id == session.id,
              !session.isSaving,
              let libraryUserCoverService
        else {
            return
        }

        session.isSaving = true
        libraryCoverSaveTask = Task { [weak self, weak session] in
            guard let self, let session else {
                return
            }
            do {
                let result = try await libraryUserCoverService.save(
                    source: session.source,
                    cropRect: session.cropRect,
                    target: session.target
                )
                guard self.library.coverEditingSession?.id == session.id else {
                    return
                }
                self.applyLibraryUserCoverSave(result, target: session.target)
                session.isSaving = false
                self.library.coverEditingSession = nil
            } catch {
                guard self.library.coverEditingSession?.id == session.id else {
                    return
                }
                session.isSaving = false
                print("Failed to save Library cover: \(error)")
            }
        }
    }

    private func applyLibraryUserCoverSave(
        _ result: LibraryUserCoverSaveResult,
        target: LibraryUserCoverTarget
    ) {
        library.applyUserCoverSave(result, target: target)

        UIInvalidationProbe.count(
            "UI.LibraryCover.locallyUpdated",
            scope: uiProbeScope,
            details: "target=\(target.invalidationDescription)"
        )
    }

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
        guard let database = libraryDatabase else {
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
        let folders = indexing.selectedFolders
        guard !folders.isEmpty else {
            if library.libraryStatus != .idle
                || !library.libraryVideos.isEmpty
                || !library.libraryFolderGroups.isEmpty
            {
                applyLibraryPresentation([])
                library.libraryStatus = .idle
            }
            return
        }
        guard library.libraryStatus != .completed,
              let database = libraryDatabase,
              library.libraryStatus != .loading
        else {
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
        ensureLibraryDisplayRenditionsAsync()
        if indexing.selectedFolders.isEmpty {
            if library.recentWatchingStatus != .idle || !library.recentWatchingItems.isEmpty {
                refreshRecentWatching()
            }
            return
        }
        guard library.recentWatchingStatus != .completed else {
            return
        }
        if case .loading = library.recentWatchingStatus, recentWatchingTask != nil {
            return
        }
        refreshRecentWatching()
    }

    func hydrateTestRecentWatchingAsync() {
        ensureLibraryDisplayRenditionsAsync()
        if indexing.selectedFolders.isEmpty {
            if library.testRecentWatchingStatus != .idle || !library.testRecentWatchingItems.isEmpty {
                refreshTestRecentWatching()
            }
            return
        }
        guard library.testRecentWatchingStatus != .completed else {
            return
        }
        if case .loading = library.testRecentWatchingStatus, testRecentWatchingTask != nil {
            return
        }
        refreshTestRecentWatching()
    }

    func hydrateCompleteLibraryAsync() {
        ensureLibraryDisplayRenditionsAsync()
        if indexing.selectedFolders.isEmpty {
            if library.completeLibraryStatus != .idle
                || !library.completeLibraryFolderSummaries.isEmpty
            {
                refreshCompleteLibrary()
            }
            return
        }
        guard library.completeLibraryStatus != .completed else {
            return
        }
        if case .loading = library.completeLibraryStatus, completeLibraryTask != nil {
            return
        }
        refreshCompleteLibrary()
    }

    func ensureLibraryDisplayRenditionsAsync() {
        let folders = indexing.selectedFolders
        guard !folders.isEmpty,
              let database = libraryCoverDatabase,
              !indexing.indexingStatus.isIndexing,
              !indexing.folderRemovalStatus.isRemoving,
              !indexing.databaseMaintenanceStatus.isCompacting
        else {
            return
        }

        let scopeKey = libraryDisplayRenditionScopeKey(for: folders)
        guard libraryDisplayRenditionAttemptedScopeKey != scopeKey,
              libraryDisplayRenditionTask == nil
        else {
            return
        }

        let commitToken = libraryDisplayRenditionCommitGate.beginGeneration()
        libraryDisplayRenditionGeneration += 1
        let generation = libraryDisplayRenditionGeneration
        let coverDirectory = libraryCoverDirectory
        libraryDisplayRenditionTask = Task { [weak self] in
            let worker = Task.detached(priority: .utility) {
                try await LibraryCoverDisplayRenditionIndexer(
                    configuration: .init(
                        coverDirectory: coverDirectory,
                        maxConcurrentRenditions: 4,
                        commitToken: commitToken
                    )
                ).backfillDisplayRenditions(under: folders, into: database)
            }

            do {
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }

                guard let self,
                      !Task.isCancelled,
                      self.libraryDisplayRenditionGeneration == generation
                else {
                    return
                }
                self.libraryDisplayRenditionTask = nil
                self.libraryDisplayRenditionAttemptedScopeKey = scopeKey
                let presentationChangeCount = result.generatedDisplayCoverCount
                    + result.clearedInvalidDisplayCoverCount
                guard presentationChangeCount > 0 else {
                    return
                }
                if self.library.recentWatchingStatus != .idle {
                    self.refreshRecentWatching()
                }
                if self.library.testRecentWatchingStatus != .idle {
                    self.refreshTestRecentWatching()
                }
                if self.library.completeLibraryStatus != .idle {
                    self.refreshCompleteLibrary()
                }
            } catch {
                guard let self,
                      self.libraryDisplayRenditionGeneration == generation
                else {
                    return
                }
                self.libraryDisplayRenditionTask = nil
                guard !(error is CancellationError) else {
                    return
                }
                print("Failed to backfill Library display renditions: \(error)")
            }
        }
    }

    func cancelLibraryDisplayRenditionTask() {
        libraryDisplayRenditionTask?.cancel()
        libraryDisplayRenditionCommitGate.invalidateCurrentGeneration()
        libraryDisplayRenditionGeneration += 1
        libraryDisplayRenditionTask = nil
        libraryDisplayRenditionAttemptedScopeKey = nil
    }

    private func libraryDisplayRenditionScopeKey(for folders: [URL]) -> String {
        let paths = folders
            .map { $0.standardizedFileURL.path }
            .sorted()
            .joined(separator: "\n")
        return "v\(LibraryCoverDisplayProfile.current.version)\n\(paths)"
    }

    func refreshRecentWatching() {
        recentWatchingTask?.cancel()

        let folders = indexing.selectedFolders
        guard !folders.isEmpty else {
            applyRecentWatching([])
            library.recentWatchingStatus = .idle
            return
        }

        guard let database = libraryDatabase else {
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

    func refreshTestRecentWatching() {
        testRecentWatchingTask?.cancel()

        let folders = indexing.selectedFolders
        guard !folders.isEmpty else {
            applyTestRecentWatching([])
            library.testRecentWatchingStatus = .idle
            return
        }

        guard let database = libraryDatabase else {
            applyTestRecentWatching([])
            library.testRecentWatchingStatus = .failed("Database is not initialized")
            return
        }

        library.testRecentWatchingStatus = .loading
        testRecentWatchingTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.recentLibraryWatching(under: folders, limit: Int.max)
                }.value

                guard !Task.isCancelled else { return }

                self?.applyTestRecentWatching(snapshot)
                self?.library.testRecentWatchingStatus = .completed
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to hydrate Test Recent Watching asynchronously: \(error)")
                self?.applyTestRecentWatching([])
                self?.library.testRecentWatchingStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func refreshLoadedTestRecentWatching() {
        guard library.testRecentWatchingStatus != .idle || !library.testRecentWatchingItems.isEmpty else {
            return
        }
        refreshTestRecentWatching()
    }

    func refreshCompleteLibrary() {
        completeLibraryTask?.cancel()

        let folders = indexing.selectedFolders
        guard !folders.isEmpty else {
            applyCompleteLibrary([])
            library.completeLibraryStatus = .idle
            return
        }

        guard let database = libraryDatabase else {
            applyCompleteLibrary([])
            library.completeLibraryStatus = .failed("Database is not initialized")
            return
        }

        library.completeLibraryStatus = .loading
        completeLibraryTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.completeLibraryFolderSummaries(under: folders)
                }.value

                guard !Task.isCancelled else { return }

                self?.applyCompleteLibrary(snapshot)
                self?.library.completeLibraryStatus = .completed
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to hydrate Complete Library asynchronously: \(error)")
                self?.applyCompleteLibrary([])
                self?.library.completeLibraryStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    private func loadCompleteLibraryFolderDetail(
        folderPath: String
    ) async throws -> CompleteLibraryFolderDetailPresentation? {
        try Task.checkCancellation()
        guard let database = libraryDatabase else {
            throw NSError(
                domain: "CueSeeker.Library",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Database is not initialized"]
            )
        }

        return try await Self.runCancellableDetached(priority: .userInitiated) {
            try database.completeLibraryFolderDetail(folderPath: folderPath)
        }
    }

    func completeLibraryFolderDetailFromStore(
        folderPath: String
    ) async -> CompleteLibraryFolderDetailPresentation? {
        if let detail = library.completeLibraryFolderDetailsByPath[folderPath] {
            return detail
        }
        hydrateCompleteLibraryFolderDetailAsync(folderPath: folderPath)
        await completeLibraryFolderDetailTasks[folderPath]?.value
        guard !Task.isCancelled else {
            return nil
        }
        return library.completeLibraryFolderDetailsByPath[folderPath]
    }

    func hydrateCompleteLibraryFolderDetailAsync(folderPath: String) {
        guard library.completeLibraryFolderDetailsByPath[folderPath] == nil,
              completeLibraryFolderDetailTasks[folderPath] == nil
        else {
            return
        }

        startCompleteLibraryFolderDetailLoad(
            folderPath: folderPath,
            preservesExistingSnapshot: false
        )
    }

    private func refreshCompleteLibraryFolderDetailsPreservingSnapshots(
        affectedVideoPaths: Set<String>
    ) {
        guard !affectedVideoPaths.isEmpty else {
            return
        }

        let affectedFolderPaths = library.completeLibraryFolderDetailsByPath
            .compactMap { folderPath, detail in
                detail.videos.contains(where: {
                    affectedVideoPaths.contains($0.videoPath)
                }) ? folderPath : nil
            }

        for folderPath in affectedFolderPaths {
            startCompleteLibraryFolderDetailLoad(
                folderPath: folderPath,
                preservesExistingSnapshot: true
            )
        }
    }

    private func startCompleteLibraryFolderDetailLoad(
        folderPath: String,
        preservesExistingSnapshot: Bool
    ) {
        if preservesExistingSnapshot {
            completeLibraryFolderDetailTasks[folderPath]?.cancel()
        } else if completeLibraryFolderDetailTasks[folderPath] != nil {
            return
        }

        let generation = completeLibraryFolderDetailGeneration
        let requestID = UUID()
        completeLibraryFolderDetailRequestIDs[folderPath] = requestID
        if !preservesExistingSnapshot {
            library.completeLibraryFolderDetailStatusesByPath[folderPath] = .loading
        }
        completeLibraryFolderDetailTasks[folderPath] = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if completeLibraryFolderDetailGeneration == generation,
                   completeLibraryFolderDetailRequestIDs[folderPath] == requestID
                {
                    completeLibraryFolderDetailTasks[folderPath] = nil
                    completeLibraryFolderDetailRequestIDs[folderPath] = nil
                }
            }

            do {
                let detail = try await loadCompleteLibraryFolderDetail(
                    folderPath: folderPath
                )
                guard !Task.isCancelled,
                      completeLibraryFolderDetailGeneration == generation,
                      completeLibraryFolderDetailRequestIDs[folderPath] == requestID
                else {
                    return
                }
                guard let detail else {
                    if preservesExistingSnapshot,
                       library.completeLibraryFolderDetailsByPath[folderPath] != nil
                    {
                        return
                    }
                    library.completeLibraryFolderDetailStatusesByPath[folderPath]
                        = .failed("Folder detail is unavailable")
                    return
                }
                library.completeLibraryFolderDetailsByPath[folderPath] = detail
                library.completeLibraryFolderDetailStatusesByPath[folderPath]
                    = .completed
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      completeLibraryFolderDetailGeneration == generation,
                      completeLibraryFolderDetailRequestIDs[folderPath] == requestID
                else {
                    return
                }
                if preservesExistingSnapshot,
                   library.completeLibraryFolderDetailsByPath[folderPath] != nil
                {
                    print("Failed to refresh Complete Library folder detail asynchronously: \(error)")
                    return
                }
                library.completeLibraryFolderDetailStatusesByPath[folderPath]
                    = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func invalidateCompleteLibraryFolderDetails() {
        completeLibraryFolderDetailGeneration &+= 1
        for task in completeLibraryFolderDetailTasks.values {
            task.cancel()
        }
        completeLibraryFolderDetailTasks.removeAll(keepingCapacity: false)
        completeLibraryFolderDetailRequestIDs.removeAll(keepingCapacity: false)
        library.completeLibraryFolderDetailsByPath = [:]
        library.completeLibraryFolderDetailStatusesByPath = [:]
    }

    func prepareLibraryNavigationVideos(_ videos: [CompleteLibraryVideoPresentation]) {
        library.libraryPlaybackNavigationVideos = videos.map(\.libraryVideo)
    }

    func prepareRecentLibraryNavigation(for item: RecentLibraryWatchingPresentation) async {
        if let folderDetail = await completeLibraryFolderDetailFromStore(
            folderPath: item.folderPath
        ) {
            guard !Task.isCancelled else {
                return
            }
            prepareLibraryNavigationVideos(folderDetail.videos)
            return
        }

        guard !Task.isCancelled else {
            return
        }
        if !library.libraryPlaybackNavigationVideos.contains(where: { $0.videoPath == item.videoPath }) {
            library.libraryPlaybackNavigationVideos = library.libraryVideos
        }
    }

    func openRecentLibraryWatching(_ item: RecentLibraryWatchingPresentation) async {
        await prepareRecentLibraryNavigation(for: item)
        openLibraryVideo(item.libraryVideo, displayTitle: item.displayTitle)
    }

    func openFolder(atPath path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
    }

    func markLibraryVideo(_ video: LibraryVideo, as state: LibraryWatchState) {
        markLibraryVideos([video], as: state)
    }

    func markCompleteLibraryFolder(folderPath: String, as state: LibraryWatchState) {
        Task { [weak self] in
            guard let self else {
                return
            }
            guard let detail = await completeLibraryFolderDetailFromStore(
                folderPath: folderPath
            ) else {
                return
            }
            markLibraryVideos(detail.videos.map(\.libraryVideo), as: state)
        }
    }

    private func markLibraryVideos(_ videos: [LibraryVideo], as state: LibraryWatchState) {
        let snapshots = videos.map { video in
            LibraryWatchStateSnapshot(
                videoPath: video.videoPath,
                duration: video.duration,
                state: state
            )
        }
        guard !snapshots.isEmpty else {
            return
        }

        let writer = libraryPlaybackHistoryWriter
        let affectedVideoPaths = Set(snapshots.map(\.videoPath))
        Task { [weak self] in
            await Task.detached(priority: .userInitiated) {
                writer.setWatchStatesAndWait(snapshots)
            }.value

            await MainActor.run {
                guard let self else {
                    return
                }
                self.refreshLibraryPlaybackHistoryPresentations(
                    affectedVideoPaths: affectedVideoPaths
                )
            }
        }
    }

    private func refreshLibraryPlaybackHistoryPresentations(
        affectedVideoPaths: Set<String>
    ) {
        guard !affectedVideoPaths.isEmpty else {
            return
        }

        library.libraryPlaybackHistoryRevision += 1
        refreshCompleteLibraryFolderDetailsPreservingSnapshots(
            affectedVideoPaths: affectedVideoPaths
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=playback_history videos=\(affectedVideoPaths.count)"
        )
        refreshRecentWatching()
        refreshLoadedTestRecentWatching()
        refreshSearchForLibraryWatchStateChange()
    }

    func applyLibraryPresentation(_ snapshot: [LibraryFolderPresentation]) {
        let groups = Self.makeLibraryFolderGroups(from: snapshot)
        library.libraryFolderGroups = groups
        library.libraryVideos = groups.flatMap { group in
            group.videos.map(\.video)
        }
        library.libraryPlaybackNavigationVideos = library.libraryVideos
        library.libraryPresentationRevision += 1
        UIInvalidationProbe.count(
            "UI.LibraryPresentationSnapshot.rebuilt",
            details: "groups=\(groups.count) rows=\(library.libraryVideos.count)"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=library"
        )
    }

    func applyRecentWatching(_ snapshot: [RecentLibraryWatchingPresentation]) {
        library.recentWatchingItems = snapshot
        library.recentWatchingRevision += 1
        UIInvalidationProbe.count(
            "UI.RecentWatchingSnapshot.rebuilt",
            details: "rows=\(snapshot.count)"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=recent_watching"
        )
    }

    func applyTestRecentWatching(_ snapshot: [RecentLibraryWatchingPresentation]) {
        library.testRecentWatchingItems = snapshot
        library.testRecentWatchingRevision += 1
        UIInvalidationProbe.count(
            "UI.TestRecentWatchingSnapshot.rebuilt",
            details: "rows=\(snapshot.count)"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=test_recent_watching"
        )
    }

    func applyCompleteLibrary(_ snapshot: [CompleteLibraryFolderSummaryPresentation]) {
        invalidateCompleteLibraryFolderDetails()
        library.completeLibraryFolderSummaries = snapshot
        library.completeLibraryRevision += 1
        UIInvalidationProbe.count(
            "UI.CompleteLibrarySnapshot.rebuilt",
            details: "folders=\(snapshot.count)"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=complete_library"
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
        library.libraryPlaybackNavigationVideos = library.libraryVideos
        library.libraryPresentationRevision += 1
        UIInvalidationProbe.count(
            "UI.LibraryPresentationSnapshot.rebuilt",
            details: "groups=\(groups.count) rows=\(library.libraryVideos.count) reason=remove"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=library reason=remove"
        )
    }

    func removeCompleteLibraryPresentation(under folder: URL) {
        invalidateCompleteLibraryFolderDetails()
        library.completeLibraryFolderSummaries = library.completeLibraryFolderSummaries.filter { group in
            !Self.path(group.folderPath, isUnder: folder)
        }
        library.completeLibraryRevision += 1
        UIInvalidationProbe.count(
            "UI.CompleteLibrarySnapshot.rebuilt",
            details: "folders=\(library.completeLibraryFolderSummaries.count) reason=remove"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=complete_library reason=remove"
        )
    }

    func openLibraryVideo(
        _ video: LibraryVideo,
        displayTitle: String? = nil,
        playbackReturnContextOnSuccessfulPlay: PlaybackReturnContext? = nil,
        savesCurrentPlaybackHistory: Bool = true
    ) {
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        playback.clearPlaylistSource()
        playback.playbackStatus = .opening
        UIInvalidationProbe.mark(
            "ACTION UI.LibraryVideo.opened",
            details: "duration=\(video.duration.map { String(format: "%.2f", $0) } ?? "unknown")"
        )
        preparePlaybackKeyboardFocus()
        initializePlaybackReturnContextIfEntering()
        if savesCurrentPlaybackHistory, case .library = activePlaybackSource {
            saveCurrentLibraryPlaybackHistory()
        }
        recordRecentLibraryWatching(for: video, refreshPresentation: false)
        library.selectedLibraryVideo = video
        search.selectResult(nil)
        shiori.selectedShiori = nil
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
        Task { @MainActor in
            await Task.yield()
            let didStartPlayback = play(video)
            if let playbackReturnContextOnSuccessfulPlay {
                commitPlaybackReturnContext(
                    playbackReturnContextOnSuccessfulPlay,
                    afterSuccessfulPlayback: didStartPlayback
                )
            }
        }
    }

    func recordRecentLibraryWatching(
        for video: LibraryVideo,
        refreshPresentation: Bool = true
    ) {
        let existingHistory = libraryPlaybackHistory(for: video)
        let snapshot = LibraryPlaybackHistorySnapshot(
            videoPath: video.videoPath,
            positionMilliseconds: existingHistory?.positionMilliseconds ?? 0,
            duration: existingHistory?.duration ?? video.duration
        )
        libraryPlaybackHistoryWriter.saveAndWait(snapshot)
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
        clearCueAutoStopPlayback()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .none
        playback.playbackStatus = .opening
        let startMilliseconds = libraryResumePositionMilliseconds(for: video)
        playback.playbackViewModel?.preparePresentationTransition(
            to: Double(startMilliseconds) / 1_000,
            subtitleCues: []
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

            let generation: UInt
            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
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
            playback.playbackViewModel?.cancelPendingPresentation()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
            return false
        }
    }

    func saveCurrentLibraryPlaybackHistory() {
        saveCurrentLibraryPlaybackHistory(waitUntilFinished: false)
    }

    func saveCurrentLibraryPlaybackHistorySynchronously() {
        saveCurrentLibraryPlaybackHistory(waitUntilFinished: true)
    }

    func markCurrentLibraryPlaybackCompletedIfNeeded(
        currentTime: Double,
        duration: Double
    ) {
        guard case .library(let videoPath) = activePlaybackSource,
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
        guard case .library(let videoPath) = activePlaybackSource,
              let playbackViewModel = playback.playbackViewModel
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

    func handlePlaybackFinishedNaturally() {
        guard case .library(let videoPath) = activePlaybackSource,
              library.selectedLibraryVideo?.videoPath == videoPath
        else {
            return
        }

        persistNaturallyCompletedLibraryPlayback(videoPath: videoPath)
        playback.playbackStatus = .paused

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
        let positionMilliseconds = resolvedDuration.map {
            max(0, Int(($0 * 1_000).rounded(.down)))
        } ?? max(
            0,
            Int(((playbackViewModel?.currentTime ?? 0) * 1_000).rounded(.down))
        )
        libraryPlaybackCompletedMilestoneVideoPath = videoPath
        pendingLibraryPlaybackHistoryPresentationVideoPaths.insert(videoPath)
        libraryPlaybackHistoryWriter.saveAndWait(
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
        let videoFile = URL(fileURLWithPath: videoPath)
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
