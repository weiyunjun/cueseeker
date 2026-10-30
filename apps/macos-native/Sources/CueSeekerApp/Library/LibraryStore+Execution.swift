import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

@MainActor
extension LibraryStore {
    func beginChangingLibraryCover(
        target: LibraryUserCoverTarget,
        currentCoverPath: String?,
        currentCoverRevision: String?
    ) {
        guard coverEditingSession == nil else {
            return
        }

        coverEditingSession = LibraryCoverEditingSession(
            target: target,
            currentCoverPath: currentCoverPath,
            currentCoverRevision: currentCoverRevision
        )
    }

    func beginChoosingLibraryCover(_ session: LibraryCoverEditingSession) {
        guard coverEditingSession?.id == session.id,
              !session.isSaving
        else {
            return
        }

        let panel = NSOpenPanel()
        let delegate = LibraryCoverOpenPanelDelegate()
        panel.delegate = delegate
        panel.title = L("cover.choose_cover_image")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = LibraryCoverOpenPanelPolicy.allowedContentTypes
        panel.allowsOtherFileTypes = false

        let completion: (NSApplication.ModalResponse) -> Void = {
            [weak self, weak session, delegate] response in
            _ = delegate
            guard let self,
                  let session,
                  response == .OK,
                  let sourceURL = panel.url,
                  self.coverEditingSession?.id == session.id
            else {
                return
            }

            self.libraryCoverImportTask?.cancel()
            self.libraryCoverImportTask = Task { [weak self, weak session] in
                do {
                    let source = try await Task.detached(priority: .userInitiated) {
                        try LibraryUserCoverProcessor.loadSource(at: sourceURL)
                    }.value
                    try Task.checkCancellation()
                    guard let self,
                          let session,
                          self.coverEditingSession?.id == session.id
                    else {
                        return
                    }
                    session.selectSource(source)
                } catch is CancellationError {
                    return
                } catch {
                    AppLogger.shared.error(
                        .database,
                        "Failed to load Library cover source",
                        details: "error=\"\(error.localizedDescription)\""
                    )
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
        guard coverEditingSession?.isSaving != true else {
            return
        }
        libraryCoverImportTask?.cancel()
        libraryCoverImportTask = nil
        coverEditingSession = nil
    }

    func saveLibraryCoverEditing(_ session: LibraryCoverEditingSession) {
        guard coverEditingSession?.id == session.id,
              !session.isSaving,
              let source = session.selectedSource,
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
                    source: source,
                    cropRect: session.cropRect,
                    target: session.target
                )
                guard self.coverEditingSession?.id == session.id else {
                    return
                }
                self.applyLibraryUserCoverSave(result, target: session.target)
                AppLogger.shared.info(
                    .library,
                    "Library custom cover saved",
                    fields: [("target", session.target.invalidationDescription)]
                )
                session.isSaving = false
                self.coverEditingSession = nil
            } catch {
                guard self.coverEditingSession?.id == session.id else {
                    return
                }
                session.isSaving = false
                AppLogger.shared.error(
                    .database,
                    "Failed to save Library cover",
                    details: "error=\"\(error.localizedDescription)\""
                )
            }
        }
    }

    func applyLibraryUserCoverSave(
        _ result: LibraryUserCoverSaveResult,
        target: LibraryUserCoverTarget
    ) {
        applyUserCoverSave(result, target: target)

        UIInvalidationProbe.count(
            "UI.LibraryCover.locallyUpdated",
            scope: uiProbeScope,
            details: "target=\(target.invalidationDescription)"
        )
    }

    func refreshLibrary(force: Bool = false) {
        if !force && panelModeProvider() == .testLibrary {
            libraryNeedsReloadAfterIndexedMutation = true
            return
        }
        libraryTask?.cancel()

        let folders = selectedFoldersProvider()
        guard !folders.isEmpty else {
            applyLibraryPresentation([])
            libraryStatus = .idle
            return
        }

        libraryStatus = .loading
        guard let database = libraryDatabase else {
            applyLibraryPresentation([])
            libraryStatus = .failed(L("status.database_not_initialized"))
            return
        }
        libraryTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    return try database.libraryPresentation(under: folders)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                self?.applyLibraryPresentation(snapshot)
                self?.libraryStatus = .completed
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self?.applyLibraryPresentation([])
                self?.libraryStatus = .failed(AppCoordinator.errorMessage(for: error))
            }
        }
    }

    func hydrateLibraryAsync() {
        let folders = selectedFoldersProvider()
        guard !folders.isEmpty else {
            if libraryStatus != .idle
                || !libraryVideos.isEmpty
                || !libraryFolderGroups.isEmpty
            {
                applyLibraryPresentation([])
                libraryStatus = .idle
            }
            return
        }
        guard libraryStatus != .completed,
              let database = libraryDatabase,
              libraryStatus != .loading
        else {
            return
        }

        libraryStatus = .loading
        libraryTask?.cancel()
        libraryTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.libraryPresentation(under: folders)
                }.value

                guard !Task.isCancelled else { return }

                self?.applyLibraryPresentation(snapshot)
                self?.libraryStatus = .completed
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.shared.error(
                    .database,
                    "Failed to hydrate Library asynchronously",
                    details: "error=\"\(error.localizedDescription)\""
                )
                self?.libraryStatus = .failed(AppCoordinator.errorMessage(for: error))
            }
        }
    }

    func hydrateRecentWatchingAsync() {
        ensureLibraryDisplayRenditionsAsync()
        if selectedFoldersProvider().isEmpty {
            if recentWatchingStatus != .idle || !recentWatchingItems.isEmpty {
                refreshRecentWatching(force: true)
            }
            return
        }
        guard recentWatchingStatus != .completed else {
            return
        }
        if case .loading = recentWatchingStatus, recentWatchingTask != nil {
            return
        }
        refreshRecentWatching(force: true)
    }

    func hydrateTestRecentWatchingAsync() {
        ensureLibraryDisplayRenditionsAsync()
        if selectedFoldersProvider().isEmpty {
            if testRecentWatchingStatus != .idle || !testRecentWatchingItems.isEmpty {
                refreshTestRecentWatching()
            }
            return
        }
        guard testRecentWatchingStatus != .completed else {
            return
        }
        if case .loading = testRecentWatchingStatus, testRecentWatchingTask != nil {
            return
        }
        refreshTestRecentWatching()
    }

    func hydrateCompleteLibraryAsync() {
        ensureLibraryDisplayRenditionsAsync()
        if selectedFoldersProvider().isEmpty {
            if completeLibraryStatus != .idle
                || !completeLibraryFolderSummaries.isEmpty
            {
                refreshCompleteLibrary(force: true)
            }
            return
        }
        guard completeLibraryStatus != .completed else {
            return
        }
        if case .loading = completeLibraryStatus, completeLibraryTask != nil {
            return
        }
        refreshCompleteLibrary(force: true)
    }

    func ensureLibraryDisplayRenditionsAsync() {
        let folders = selectedFoldersProvider()
        guard !folders.isEmpty,
              let database = libraryCoverDatabase,
              !isIndexingBusyProvider()
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
                if self.recentWatchingStatus != .idle {
                    self.refreshRecentWatching()
                }
                if self.testRecentWatchingStatus != .idle {
                    self.refreshTestRecentWatching()
                }
                if self.completeLibraryStatus != .idle {
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
                AppLogger.shared.warn(
                    .database,
                    "Failed to backfill Library display renditions",
                    details: "error=\"\(error.localizedDescription)\""
                )
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

    func libraryDisplayRenditionScopeKey(for folders: [URL]) -> String {
        let paths = folders
            .map(\.mediaPath)
            .sorted()
            .joined(separator: "\n")
        return "v\(LibraryCoverDisplayProfile.current.version)\n\(paths)"
    }

    func refreshRecentWatching(force: Bool = false) {
        if !force && panelModeProvider() == .recentWatching {
            recentNeedsReloadAfterIndexedMutation = true
            return
        }
        recentWatchingTask?.cancel()

        let folders = selectedFoldersProvider()
        guard !folders.isEmpty else {
            applyRecentWatching([])
            recentWatchingStatus = .idle
            return
        }

        guard let database = libraryDatabase else {
            applyRecentWatching([])
            recentWatchingStatus = .failed(L("status.database_not_initialized"))
            return
        }

        recentWatchingStatus = .loading
        recentWatchingTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.recentLibraryWatching(under: folders)
                }.value

                guard !Task.isCancelled else { return }

                self?.applyRecentWatching(snapshot)
                self?.recentWatchingStatus = .completed
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.shared.error(
                    .database,
                    "Failed to hydrate recent Library watching",
                    details: "error=\"\(error.localizedDescription)\""
                )
                self?.applyRecentWatching([])
                self?.recentWatchingStatus = .failed(AppCoordinator.errorMessage(for: error))
            }
        }
    }

    func refreshTestRecentWatching() {
        testRecentWatchingTask?.cancel()

        let folders = selectedFoldersProvider()
        guard !folders.isEmpty else {
            applyTestRecentWatching([])
            testRecentWatchingStatus = .idle
            return
        }

        guard let database = libraryDatabase else {
            applyTestRecentWatching([])
            testRecentWatchingStatus = .failed(L("status.database_not_initialized"))
            return
        }

        testRecentWatchingStatus = .loading
        testRecentWatchingTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.recentLibraryWatching(
                        under: folders,
                        limit: Int.max,
                        includesNeverPlayed: true
                    )
                }.value

                guard !Task.isCancelled else { return }

                self?.applyTestRecentWatching(snapshot)
                self?.testRecentWatchingStatus = .completed
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.shared.error(
                    .database,
                    "Failed to hydrate Test Recent Watching",
                    details: "error=\"\(error.localizedDescription)\""
                )
                self?.applyTestRecentWatching([])
                self?.testRecentWatchingStatus = .failed(AppCoordinator.errorMessage(for: error))
            }
        }
    }

    func refreshLoadedTestRecentWatching(force: Bool = false) {
        guard testRecentWatchingStatus != .idle || !testRecentWatchingItems.isEmpty else {
            return
        }
        if !force && panelModeProvider() == .recentWatching {
            recentNeedsReloadAfterIndexedMutation = true
            return
        }
        refreshTestRecentWatching()
    }

    func refreshCompleteLibrary(force: Bool = false) {
        if !force && panelModeProvider() == .testLibrary {
            libraryNeedsReloadAfterIndexedMutation = true
            return
        }
        completeLibraryTask?.cancel()

        let folders = selectedFoldersProvider()
        guard !folders.isEmpty else {
            applyCompleteLibrary([])
            completeLibraryStatus = .idle
            return
        }

        guard let database = libraryDatabase else {
            applyCompleteLibrary([])
            completeLibraryStatus = .failed(L("status.database_not_initialized"))
            return
        }

        completeLibraryStatus = .loading
        let startedAt = DispatchTime.now().uptimeNanoseconds
        completeLibraryTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.completeLibraryFolderSummaries(under: folders)
                }.value

                guard !Task.isCancelled else { return }

                let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
                AppLogger.shared.info(
                    .library,
                    "Library overview loaded",
                    fields: [
                        ("folders", "\(snapshot.count)"),
                        ("elapsed_ms", String(format: "%.1f", elapsedMs))
                    ]
                )
                self?.applyCompleteLibrary(snapshot)
                self?.completeLibraryStatus = .completed
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.shared.error(
                    .database,
                    "Failed to hydrate Complete Library",
                    details: "error=\"\(error.localizedDescription)\""
                )
                self?.applyCompleteLibrary([])
                self?.completeLibraryStatus = .failed(AppCoordinator.errorMessage(for: error))
            }
        }
    }

    func refreshLibraryOnReappearanceIfNeeded() {
        guard libraryNeedsReloadAfterIndexedMutation else {
            return
        }
        libraryNeedsReloadAfterIndexedMutation = false
        refreshLibrary(force: true)
        refreshCompleteLibrary(force: true)
    }

    func loadCompleteLibraryFolderDetail(
        folderPath: String
    ) async throws -> CompleteLibraryFolderDetailPresentation? {
        try Task.checkCancellation()
        guard let database = libraryDatabase else {
            throw NSError(
                domain: "CueSeeker.Library",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("status.database_not_initialized")]
            )
        }

        return try await AppCoordinator.runCancellableDetached(priority: .userInitiated) {
            try database.completeLibraryFolderDetail(folderPath: folderPath)
        }
    }

    func completeLibraryFolderDetailFromStore(
        folderPath: String
    ) async -> CompleteLibraryFolderDetailPresentation? {
        if let detail = completeLibraryFolderDetailsByPath[folderPath] {
            return detail
        }
        hydrateCompleteLibraryFolderDetailAsync(folderPath: folderPath)
        await completeLibraryFolderDetailTasks[folderPath]?.value
        guard !Task.isCancelled else {
            return nil
        }
        return completeLibraryFolderDetailsByPath[folderPath]
    }

    func hydrateCompleteLibraryFolderDetailAsync(folderPath: String) {
        guard completeLibraryFolderDetailsByPath[folderPath] == nil,
              completeLibraryFolderDetailTasks[folderPath] == nil
        else {
            return
        }

        startCompleteLibraryFolderDetailLoad(
            folderPath: folderPath,
            preservesExistingSnapshot: false
        )
    }

    func refreshCompleteLibraryFolderDetailsPreservingSnapshots(
        affectedVideoPaths: Set<String>
    ) {
        guard !affectedVideoPaths.isEmpty else {
            return
        }

        let affectedFolderPaths = completeLibraryFolderDetailsByPath
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

    func startCompleteLibraryFolderDetailLoad(
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
            completeLibraryFolderDetailStatusesByPath[folderPath] = .loading
        }
        completeLibraryFolderDetailTasks[folderPath] = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.completeLibraryFolderDetailGeneration == generation,
                   self.completeLibraryFolderDetailRequestIDs[folderPath] == requestID
                {
                    self.completeLibraryFolderDetailTasks[folderPath] = nil
                    self.completeLibraryFolderDetailRequestIDs[folderPath] = nil
                }
            }

            do {
                let detail = try await self.loadCompleteLibraryFolderDetail(
                    folderPath: folderPath
                )
                guard !Task.isCancelled,
                      self.completeLibraryFolderDetailGeneration == generation,
                      self.completeLibraryFolderDetailRequestIDs[folderPath] == requestID
                else {
                    return
                }
                guard let detail else {
                    if preservesExistingSnapshot,
                       self.completeLibraryFolderDetailsByPath[folderPath] != nil
                    {
                        return
                    }
                    self.completeLibraryFolderDetailStatusesByPath[folderPath]
                        = .failed(L("status.folder_detail_unavailable"))
                    return
                }
                self.completeLibraryFolderDetailsByPath[folderPath] = detail
                self.completeLibraryFolderDetailStatusesByPath[folderPath]
                    = .completed
                if !preservesExistingSnapshot {
                    AppLogger.shared.info(
                        .library,
                        "Library folder episodes loaded",
                        fields: [
                            ("folder", URL.fromMediaPath(folderPath).lastPathComponent),
                            ("videos", "\(detail.videos.count)")
                        ]
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      self.completeLibraryFolderDetailGeneration == generation,
                      self.completeLibraryFolderDetailRequestIDs[folderPath] == requestID
                else {
                    return
                }
                if preservesExistingSnapshot,
                   self.completeLibraryFolderDetailsByPath[folderPath] != nil
                {
                    AppLogger.shared.warn(
                        .database,
                        "Failed to refresh Complete Library folder detail",
                        details: "error=\"\(error.localizedDescription)\""
                    )
                    return
                }
                self.completeLibraryFolderDetailStatusesByPath[folderPath]
                    = .failed(AppCoordinator.errorMessage(for: error))
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
        completeLibraryFolderDetailsByPath = [:]
        completeLibraryFolderDetailStatusesByPath = [:]
    }

    func prepareLibraryNavigationVideos(_ videos: [CompleteLibraryVideoPresentation]) {
        libraryPlaybackNavigationVideos = videos.map(\.libraryVideo)
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
        if !libraryPlaybackNavigationVideos.contains(where: { $0.videoPath == item.videoPath }) {
            libraryPlaybackNavigationVideos = libraryVideos
        }
    }

    func markLibraryVideo(_ video: LibraryVideo, as state: LibraryWatchState) {
        markLibraryVideos([video], as: state)
    }

    func markCompleteLibraryFolder(folderPath: String, as state: LibraryWatchState) {
        Task { [weak self] in
            guard let self else {
                return
            }
            guard let detail = await self.completeLibraryFolderDetailFromStore(
                folderPath: folderPath
            ) else {
                return
            }
            self.markLibraryVideos(detail.videos.map(\.libraryVideo), as: state)
        }
    }

    func markLibraryVideos(_ videos: [LibraryVideo], as state: LibraryWatchState) {
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
        AppLogger.shared.info(
            .library,
            "Library watch state updated",
            fields: [
                ("videos", "\(videos.count)"),
                ("state", "\(state)"),
                ("first", videos.first.map { URL.fromMediaPath($0.videoPath).lastPathComponent })
            ]
        )

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

    func refreshLibraryPlaybackHistoryPresentations(
        affectedVideoPaths: Set<String>
    ) {
        guard !affectedVideoPaths.isEmpty else {
            return
        }

        libraryPlaybackHistoryRevision += 1
        refreshCompleteLibraryFolderDetailsPreservingSnapshots(
            affectedVideoPaths: affectedVideoPaths
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=playback_history videos=\(affectedVideoPaths.count)"
        )
        refreshRecentWatching(force: true)
        refreshLoadedTestRecentWatching(force: true)
        onWatchStateChanged()
    }

    func applyLibraryPresentation(_ snapshot: [LibraryFolderPresentation]) {
        let groups = AppCoordinator.makeLibraryFolderGroups(from: snapshot)
        libraryFolderGroups = groups
        libraryVideos = groups.flatMap { group in
            group.videos.map(\.video)
        }
        libraryPlaybackNavigationVideos = libraryVideos
        libraryPresentationRevision += 1
        UIInvalidationProbe.count(
            "UI.LibraryPresentationSnapshot.rebuilt",
            details: "groups=\(groups.count) rows=\(libraryVideos.count)"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=library"
        )
    }

    func applyRecentWatching(_ snapshot: [RecentLibraryWatchingPresentation]) {
        recentWatchingItems = snapshot
        recentWatchingRevision += 1
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
        testRecentWatchingItems = snapshot
        testRecentWatchingRevision += 1
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
        completeLibraryFolderSummaries = snapshot
        completeLibraryRevision += 1
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
        if panelModeProvider() == .testLibrary || hasHeldWorkbenchRouteProvider() {
            libraryNeedsReloadAfterIndexedMutation = true
            return
        }
        let prefixes = AppCoordinator.folderPathPrefixes(for: folder)
        let groups = libraryFolderGroups.filter { group in
            !group.videos.contains { AppCoordinator.pathMatchesPrefixes($0.video.videoPath, prefixes: prefixes) }
        }
        libraryFolderGroups = groups
        libraryVideos = groups.flatMap { group in
            group.videos.map(\.video)
        }
        libraryPlaybackNavigationVideos = libraryVideos
        libraryPresentationRevision += 1
        UIInvalidationProbe.count(
            "UI.LibraryPresentationSnapshot.rebuilt",
            details: "groups=\(groups.count) rows=\(libraryVideos.count) reason=remove"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=library reason=remove"
        )
    }

    func removeCompleteLibraryPresentation(under folder: URL) {
        if panelModeProvider() == .testLibrary || hasHeldWorkbenchRouteProvider() {
            libraryNeedsReloadAfterIndexedMutation = true
            return
        }
        invalidateCompleteLibraryFolderDetails()
        let prefixes = AppCoordinator.folderPathPrefixes(for: folder)
        completeLibraryFolderSummaries = completeLibraryFolderSummaries.filter { group in
            !AppCoordinator.pathMatchesPrefixes(group.folderPath, prefixes: prefixes)
        }
        completeLibraryRevision += 1
        UIInvalidationProbe.count(
            "UI.CompleteLibrarySnapshot.rebuilt",
            details: "folders=\(completeLibraryFolderSummaries.count) reason=remove"
        )
        UIInvalidationProbe.count(
            "library.snapshot_rebuild",
            scope: uiProbeScope,
            details: "surface=complete_library reason=remove"
        )
    }
}
