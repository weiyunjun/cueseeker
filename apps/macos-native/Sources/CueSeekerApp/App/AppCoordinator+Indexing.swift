import Foundation
import CueSeekerCore
import CueSeekerPlayback

private struct CompletedFolderIndex: Sendable {
    let result: SubtitleIndexingResult
    let auxiliaryFailures: [IndexingAuxiliaryFailure]
    let refreshedAuxiliaryData: Bool
}

/// What one Index run needs from the coordinator, read once before it starts
/// so the run itself never has to come back to the main actor for it.
private struct IndexRunContext: Sendable {
    let database: IndexingDatabase
    let libraryDatabase: LibraryDatabase
    let coverDatabase: LibraryCoverDatabase
    let coverDirectory: URL
    let displayRenditionCommitToken: LibraryCoverDisplayRenditionCommitToken
}

/// Carries an already-worded failure to the task record.
struct LibraryTaskFailure: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

/// Indexes one folder through the four stages. A removed task stops once the
/// file or cover in hand is done; what earlier stages published stays.
///
/// The folder's subtitles are published at the end of the second stage.
/// Before that a removed task throws and leaves the folder as it was; after
/// it, the stages still to come are skipped but the folder's presentation is
/// still brought up to what was published, so the pages can show it.
private func performFolderIndex(
    folder: URL,
    database: IndexingDatabase,
    libraryDatabase: LibraryDatabase,
    coverDatabase: LibraryCoverDatabase,
    coverDirectory: URL,
    displayRenditionCommitToken:
        LibraryCoverDisplayRenditionCommitToken,
    onProgress: @escaping @Sendable (TaskIndexStage, Int, Int) -> Void
) async throws -> CompletedFolderIndex {
    onProgress(.scanningFiles, 0, 0)
    let result = try SubtitleIndexer().index(
        folder: folder,
        into: database
    ) { indexed, total in
        onProgress(.indexingSubtitles, indexed, total)
    }
    var failures: [IndexingAuxiliaryFailure] = []
    var refreshedAuxiliaryData = false

    onProgress(.readingVideoInfo, 0, result.pendingVideoMetadataPaths.count)
    if !Task.isCancelled, !result.pendingVideoMetadataPaths.isEmpty {
        do {
            let metadataResult =
                try PlaybackVideoMetadataIndexer().indexDurations(
                    videoFiles: result.pendingVideoMetadataPaths.map {
                        URL(fileURLWithPath: $0)
                    },
                    into: libraryDatabase
                ) { read, total in
                    onProgress(.readingVideoInfo, read, total)
                }
            refreshedAuxiliaryData =
                !metadataResult.updatedVideoPaths.isEmpty
            if let firstFailure = metadataResult.failures.first {
                failures.append(
                    IndexingAuxiliaryFailure(
                        kind: .videoMetadata,
                        message:
                            L(
                                "status.video_metadata_failed",
                                metadataResult.failures.count,
                                firstFailure.reason
                            )
                    )
                )
            }
        } catch is CancellationError where Task.isCancelled {
            // Removed: the videos read so far are kept, the rest are skipped.
        } catch {
            failures.append(
                IndexingAuxiliaryFailure(
                    kind: .videoMetadata,
                    message:
                        L(
                            "status.video_metadata_refresh_failed",
                            error.localizedDescription
                        )
                )
            )
        }
    }

    if !Task.isCancelled {
        onProgress(.generatingCovers, 0, 0)
        do {
            let coverResult = try await LibraryCoverIndexer(
                configuration: .init(
                    coverDirectory: coverDirectory,
                    displayRenditionCommitToken:
                        displayRenditionCommitToken
                )
            ).indexCovers(
                under: folder,
                affectedVideoPaths: Set(result.affectedVideoPaths),
                affectedFolderPaths: Set(
                    result.affectedFolderPaths
                ),
                into: coverDatabase
            ) { generated, total in
                onProgress(.generatingCovers, generated, total)
            }
            if coverResult.generatedCoverCount > 0
                || coverResult.generatedDisplayCoverCount > 0
            {
                refreshedAuxiliaryData = true
            }
            if coverResult.failedCoverCount > 0
                || coverResult.failedDisplayCoverCount > 0
            {
                failures.append(
                    IndexingAuxiliaryFailure(
                        kind: .automaticCover,
                        message:
                            L(
                                "status.cover_generation_failed_counts",
                                coverResult.failedCoverCount,
                                coverResult.failedDisplayCoverCount
                            )
                    )
                )
            }
        } catch is CancellationError where Task.isCancelled {
            // Removed: the covers already made are kept, the rest are skipped.
        } catch {
            failures.append(
                IndexingAuxiliaryFailure(
                    kind: .automaticCover,
                    message:
                        L(
                            "status.cover_generation_failed",
                            error.localizedDescription
                        )
                )
            )
        }
    }

    if let libraryID = result.libraryID {
        do {
            switch result.presentationRefreshRequest {
            case .none:
                break
            case .affectedFolders(let folderPaths):
                try libraryDatabase
                    .refreshPresentationAfterIndexedContentChange(
                        affectedFolderPaths: Set(folderPaths),
                        clearingRetryForLibraryID: libraryID
                    )
                refreshedAuxiliaryData = true
            case .fullLibrary:
                try libraryDatabase
                    .refreshPresentationAfterIndexedContentChange(
                        libraryID: libraryID
                    )
                refreshedAuxiliaryData = true
            }
        } catch {
            failures.append(
                IndexingAuxiliaryFailure(
                    kind: .libraryPresentation,
                    message:
                        L(
                            "status.library_presentation_failed",
                            error.localizedDescription
                        )
                )
            )
        }
    }

    return CompletedFolderIndex(
        result: result,
        auxiliaryFailures: failures,
        refreshedAuxiliaryData: refreshedAuxiliaryData
    )
}

@MainActor
extension AppCoordinator {
    /// Starts an Add Folder. The folder joins the root list only once its task
    /// completes, so one that does not finish leaves the list as it was.
    func addFolder(_ folder: URL) {
        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = L("status.compaction_running")
            return
        }

        indexing.removedFolderNotice = nil
        tasks.enqueueAddFolder(folder.standardizedFileURL)
    }

    /// Starts a Remove Folder. The confirmation came before this; the root
    /// leaves the list only once its task completes.
    func removeFolder(_ folder: URL) {
        AppPerformanceProbe.breadcrumb("AppCoordinator.removeFolder folder=\(folder.path)")
        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = L("status.compaction_running")
            return
        }

        guard indexingDatabase != nil else {
            startupError = L("status.database_not_initialized")
            return
        }

        startupError = nil
        indexing.removedFolderNotice = nil
        tasks.enqueueRemoveFolder(folder.standardizedFileURL)
    }

    /// Starts Index Now over the outermost root of every group, in group order.
    func indexAllFolders() {
        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = L("status.compaction_running")
            return
        }

        let folders = LibraryRootGroups.representatives(of: indexing.selectedFolders)
        guard !folders.isEmpty else {
            return
        }

        indexing.removedFolderNotice = nil
        tasks.enqueueIndex(folders: folders)
    }

    /// Takes back what the Add Folder tasks the previous launch left
    /// unfinished had indexed. Runs before any page is shown, so none sees
    /// it; the Filter Dialog's options, read when Search was set up, are read
    /// again.
    func discardUnfinishedFolderAdditions(_ folders: [URL]) {
        guard let indexingDatabase, !folders.isEmpty else {
            return
        }

        for folder in folders
        where LibraryRootGroups.coveringRoot(of: folder, in: indexing.selectedFolders) == nil {
            do {
                try indexingDatabase.removeIndexedFolder(
                    folder,
                    keepingNestedRoots: LibraryRootGroups.representatives(
                        inside: folder,
                        of: indexing.selectedFolders
                    )
                )
            } catch {
                print("Failed to take back an unfinished folder addition: \(error)")
            }
        }
        search.reloadEmptySearchFacetDistribution()
    }

    // MARK: - The tasks

    /// Hands the queue the runners it cannot build itself: the databases, the
    /// root list, the status the File page shows, and the page refresh once
    /// the indexed content has moved. The queue only orders and records.
    func configureLibraryTaskRunners() {
        tasks.runIndex = { [weak self] folders, onProgress in
            await AppCoordinator.waitForDebugTaskDelay()
            return try await AppCoordinator.runIndex(
                folders: folders,
                isAllFolders: true,
                onProgress: onProgress,
                coordinator: self
            )
        }
        tasks.runAddFolder = { [weak self] folders, onProgress in
            await AppCoordinator.waitForDebugTaskDelay()
            guard let self, let folder = folders.first else {
                throw CancellationError()
            }
            return try await self.performFolderAddition(folder, onProgress: onProgress)
        }
        tasks.runRemoveFolder = { [weak self] folder in
            AppPerformanceProbe.breadcrumb("tasks.runRemoveFolder.beforeDelay folder=\(folder.path)")
            await AppCoordinator.waitForDebugTaskDelay()
            AppPerformanceProbe.breadcrumb("tasks.runRemoveFolder.afterDelay folder=\(folder.path)")
            guard let self else {
                throw CancellationError()
            }
            try await self.performFolderRemoval(folder)
        }
    }

    /// A Debug build waits the seconds in `CUESEEKER_DEBUG_TASK_DELAY_SECONDS`
    /// before an Add Folder, Index, Remove Folder, Export to Anki or Rename starts
    /// its work, so what the task does to an open page can be accepted in the App.
    /// The take-backs of an unfinished Add Folder call the removal directly and
    /// never wait (20260925-Feature-Playback Continues When Content Leaves The
    /// Database, 5; 20260926-Engineering-Debug Delay For Anki Export And Rename).
    nonisolated static func waitForDebugTaskDelay(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async {
        #if DEBUG
        if let seconds = environment["CUESEEKER_DEBUG_TASK_DELAY_SECONDS"]
            .flatMap({ Double($0.trimmingCharacters(in: .whitespaces)) }),
           seconds.isFinite,
           seconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
        #endif
    }

    /// Indexes a new root and then adds it to the list. A folder a root
    /// already holds has nothing new to index. One that does not finish —
    /// removed or failed — takes back what it indexed, also from the Filter
    /// Dialog's options, which were read again when its subtitles were
    /// published.
    private func performFolderAddition(
        _ folder: URL,
        onProgress: @escaping @Sendable (TaskIndexProgress) -> Void
    ) async throws -> Int {
        guard LibraryRootGroups.coveringRoot(of: folder, in: indexing.selectedFolders) == nil else {
            if !indexing.selectedFolders.contains(folder) {
                indexing.appendFolder(folder)
            }
            return 0
        }

        do {
            let indexedCount = try await Self.runIndex(
                folders: [folder],
                isAllFolders: false,
                onProgress: onProgress,
                coordinator: self
            )
            indexing.appendFolder(folder)
            // The pages refreshed when the index published, before the folder
            // was in the scope they read.
            refreshLibraryAfterAuxiliaryDataMutation()
            return indexedCount
        } catch {
            do {
                try await libraryFolderRemovalExecutor.removeFolder(
                    folder,
                    keepingNestedRoots: LibraryRootGroups.representatives(
                        inside: folder,
                        of: indexing.selectedFolders
                    ),
                    databaseURL: databaseURL
                )
            } catch {
                print("Failed to take back an unfinished folder addition: \(error)")
            }
            search.reloadEmptySearchFacetDistribution()
            throw error
        }
    }

    /// Removes a root. One that another root still holds only leaves the
    /// list. Otherwise its indexed content goes, except what lies in the
    /// groups inside it that stay. The `await` on the executor leaves the main
    /// actor free while the deletion runs.
    private func performFolderRemoval(_ folder: URL) async throws {
        AppPerformanceProbe.breadcrumb("performFolderRemoval.begin folder=\(folder.path)")
        let remainingRoots = indexing.selectedFolders.filter { $0 != folder }
        guard LibraryRootGroups.coveringRoot(of: folder, in: remainingRoots) == nil else {
            indexing.removeFolder(folder)
            indexing.removedFolderNotice = folder
            return
        }

        guard indexingDatabase != nil else {
            throw LibraryTaskFailure(message: L("status.database_not_initialized"))
        }

        let searchMutationToken = search.beginIndexedCueDataMutation()

        indexing.removedFolderNotice = nil
        indexing.folderRemovalStatus = .removing(folder)
        databaseStorageStatsTask?.cancel()
        databaseStorageStatsTask = nil
        if case .loadingStats = indexing.databaseMaintenanceStatus {
            indexing.databaseMaintenanceStatus = .idle
        }
        cancelDatabaseReadTasksBeforeIndexing()
        let prefixes = Self.folderPathPrefixes(for: folder)
        if let currentPath = currentPlaybackVideoPath,
           Self.pathMatchesPrefixes(currentPath, prefixes: prefixes) {
            currentPlaybackItemLeftLibrary = true
            stopLibraryPlaybackHistoryTracking()
        }
        pendingLibraryPlaybackHistoryPresentationVideoPaths = pendingLibraryPlaybackHistoryPresentationVideoPaths.filter {
            !Self.pathMatchesPrefixes($0, prefixes: prefixes)
        }
        AppPerformanceProbe.breadcrumb("performFolderRemoval.holdPlaybackBeforeIndexedContentChange")
        holdPlaybackBeforeIndexedContentChange()
        AppPerformanceProbe.breadcrumb("performFolderRemoval.prepareExcerptForIndexedContentMutation")
        prepareExcerptForIndexedContentMutation(under: [folder])

        AppPerformanceProbe.breadcrumb("performFolderRemoval.removeFolderOnExecutor.begin")
        do {
            try await libraryFolderRemovalExecutor.removeFolder(
                folder,
                keepingNestedRoots: LibraryRootGroups.representatives(
                    inside: folder,
                    of: remainingRoots
                ),
                databaseURL: databaseURL
            )
        } catch {
            AppPerformanceProbe.breadcrumb("performFolderRemoval.removeFolderOnExecutor.failed error=\(error)")
            indexing.folderRemovalStatus = .idle
            reloadExcerptAfterIndexedContentMutation()
            search.completeIndexedCueDataMutation(searchMutationToken)
            restoreCurrentSearchAfterIndexedCueMutationFailure(
                reloadFromDatabase: false
            )
            let message = L(
                "status.folder_index_removal_failed",
                Self.errorMessage(for: error)
            )
            startupError = message
            throw LibraryTaskFailure(message: message)
        }
        AppPerformanceProbe.breadcrumb("performFolderRemoval.removeFolderOnExecutor.end")

        AppPerformanceProbe.breadcrumb("performFolderRemoval.indexing.removeFolder")
        indexing.removeFolder(folder)
        AppPerformanceProbe.breadcrumb("performFolderRemoval.clearSearchAndPlaybackState")
        clearSearchAndPlaybackState(under: folder)
        AppPerformanceProbe.breadcrumb("performFolderRemoval.reconcilePlaybackAfterIndexedContentChange")
        reconcilePlaybackAfterIndexedContentChange()
        indexing.folderRemovalStatus = .idle
        AppPerformanceProbe.breadcrumb("performFolderRemoval.reloadExcerptAfterIndexedContentMutation")
        reloadExcerptAfterIndexedContentMutation()
        AppPerformanceProbe.breadcrumb("performFolderRemoval.search.completeIndexedCueDataMutation")
        search.completeIndexedCueDataMutation(searchMutationToken)
        indexing.removedFolderNotice = folder
        AppPerformanceProbe.breadcrumb("performFolderRemoval.refreshLibrary")
        refreshLibrary()
        AppPerformanceProbe.breadcrumb("performFolderRemoval.refreshRecentWatching")
        refreshRecentWatching()
        AppPerformanceProbe.breadcrumb("performFolderRemoval.refreshLoadedTestRecentWatching")
        refreshLoadedTestRecentWatching()
        AppPerformanceProbe.breadcrumb("performFolderRemoval.refreshCompleteLibrary")
        refreshCompleteLibrary()
        AppPerformanceProbe.breadcrumb("performFolderRemoval.refreshDatabaseStorageStats")
        refreshDatabaseStorageStats()
        AppPerformanceProbe.breadcrumb("performFolderRemoval.end")
    }

    /// Indexes the folders one after another and answers how many subtitle
    /// files were indexed.
    ///
    /// A removed task stops once the file or cover in hand is done and keeps
    /// what earlier folders already published; a folder that fails ends the
    /// run and reports itself, as the File page always showed it.
    nonisolated private static func runIndex(
        folders: [URL],
        isAllFolders: Bool,
        onProgress: @escaping @Sendable (TaskIndexProgress) -> Void,
        coordinator: AppCoordinator?
    ) async throws -> Int {
        guard let coordinator, let firstFolder = folders.first else {
            throw CancellationError()
        }

        let context = await MainActor.run { () -> IndexRunContext? in
            guard let database = coordinator.indexingDatabase,
                  let libraryDatabase = coordinator.libraryDatabase,
                  let coverDatabase = coordinator.libraryCoverDatabase
            else {
                coordinator.indexing.indexingStatus = .failed(
                    firstFolder,
                    L("status.database_not_initialized")
                )
                return nil
            }

            coordinator.indexing.removedFolderNotice = nil
            coordinator.indexing.auxiliaryFailures = []
            coordinator.indexing.indexingStatus = Self.runningStatus(
                for: folders,
                at: 0,
                isAllFolders: isAllFolders
            )
            return IndexRunContext(
                database: database,
                libraryDatabase: libraryDatabase,
                coverDatabase: coverDatabase,
                coverDirectory: coordinator.libraryCoverDirectory,
                displayRenditionCommitToken:
                    coordinator.libraryDisplayRenditionCommitGate.beginGeneration()
            )
        }

        guard let context else {
            throw LibraryTaskFailure(message: L("status.database_not_initialized"))
        }

        var aggregateResult: SubtitleIndexingResult?
        var auxiliaryFailures: [IndexingAuxiliaryFailure] = []
        var refreshedAuxiliaryData = false
        var indexedSubtitleFiles = 0

        for (offset, folder) in folders.enumerated() {
            if Task.isCancelled {
                break
            }

            await MainActor.run {
                coordinator.indexing.indexingStatus = Self.runningStatus(
                    for: folders,
                    at: offset,
                    isAllFolders: isAllFolders
                )
            }

            do {
                let completed = try await performFolderIndex(
                    folder: folder,
                    database: context.database,
                    libraryDatabase: context.libraryDatabase,
                    coverDatabase: context.coverDatabase,
                    coverDirectory: context.coverDirectory,
                    displayRenditionCommitToken: context.displayRenditionCommitToken
                ) { stage, stageCompleted, stageTotal in
                    onProgress(
                        TaskIndexProgress(
                            stage: stage,
                            folderName: folder.lastPathComponent,
                            completedFolders: offset,
                            totalFolders: folders.count,
                            stageCompleted: stageCompleted,
                            stageTotal: stageTotal
                        )
                    )
                }

                auxiliaryFailures.append(contentsOf: completed.auxiliaryFailures)
                refreshedAuxiliaryData =
                    refreshedAuxiliaryData || completed.refreshedAuxiliaryData
                indexedSubtitleFiles += completed.result.indexedSubtitleFiles
                if var currentResult = aggregateResult {
                    coordinator.aggregate(completed.result, into: &currentResult)
                    aggregateResult = currentResult
                } else {
                    aggregateResult = completed.result
                }
            } catch is CancellationError {
                break
            } catch {
                let message = Self.errorMessage(for: error)
                await coordinator.finishIndexRun(
                    aggregateResult,
                    folders: folders,
                    auxiliaryFailures: auxiliaryFailures,
                    refreshedAuxiliaryData: refreshedAuxiliaryData,
                    status: .failed(folder, message)
                )
                throw LibraryTaskFailure(message: message)
            }
        }

        guard !Task.isCancelled, let aggregateResult else {
            await coordinator.finishIndexRun(
                aggregateResult,
                folders: folders,
                auxiliaryFailures: auxiliaryFailures,
                refreshedAuxiliaryData: refreshedAuxiliaryData,
                status: .idle
            )
            throw CancellationError()
        }

        await coordinator.finishIndexRun(
            aggregateResult,
            folders: folders,
            auxiliaryFailures: auxiliaryFailures,
            refreshedAuxiliaryData: refreshedAuxiliaryData,
            status: Self.completedStatus(
                for: folders,
                result: aggregateResult,
                isAllFolders: isAllFolders
            )
        )
        return indexedSubtitleFiles
    }

    /// Add Folder keeps the single-folder status the File page has always
    /// shown for it; Index Now keeps the counted one.
    nonisolated private static func runningStatus(
        for folders: [URL],
        at offset: Int,
        isAllFolders: Bool
    ) -> IndexingStatus {
        guard isAllFolders else {
            return .indexing(folders[offset])
        }
        return .indexingAll(
            currentFolder: folders[offset],
            completedFolders: offset,
            totalFolders: folders.count
        )
    }

    nonisolated private static func completedStatus(
        for folders: [URL],
        result: SubtitleIndexingResult,
        isAllFolders: Bool
    ) -> IndexingStatus {
        guard isAllFolders else {
            return .completed(folders[0], result)
        }
        return .completedAll(folderCount: folders.count, result)
    }

    /// Publishes what the run produced: the status the File page shows, the
    /// auxiliary failures under it, and the refresh every page needs once the
    /// indexed content has moved.
    private func finishIndexRun(
        _ aggregateResult: SubtitleIndexingResult?,
        folders: [URL],
        auxiliaryFailures: [IndexingAuxiliaryFailure],
        refreshedAuxiliaryData: Bool,
        status: IndexingStatus
    ) {
        indexing.indexingStatus = status
        indexing.auxiliaryFailures = auxiliaryFailures

        guard let aggregateResult else {
            return
        }

        let changesIndexedContent = aggregateResult.hasIndexedContentChanges
            || aggregateResult.requiresExcerptRefresh
        if changesIndexedContent {
            holdPlaybackBeforeIndexedContentChange()
        }
        applyPublishedIndexMutation(
            aggregateResult,
            excerptFallbackFolders: folders
        )
        if changesIndexedContent {
            reconcilePlaybackAfterIndexedContentChange()
        }
        if refreshedAuxiliaryData && !aggregateResult.hasIndexedContentChanges {
            refreshLibraryAfterAuxiliaryDataMutation()
        }
    }

    func applyPublishedIndexMutation(
        _ result: SubtitleIndexingResult,
        excerptFallbackFolders: [URL]
    ) {
        if result.requiresExcerptRefresh {
            let affectedFolders = result.affectedFolderPaths.isEmpty
                ? excerptFallbackFolders
                : result.affectedFolderPaths.map(
                    URL.init(fileURLWithPath:)
                )
            prepareExcerptForIndexedContentMutation(
                under: affectedFolders
            )
            reloadExcerptAfterIndexedContentMutation()
        }

        guard result.hasIndexedContentChanges else {
            return
        }
        cancelDatabaseReadTasksBeforeIndexing()
        let searchMutationToken = search.beginIndexedCueDataMutation()
        for folderPath in result.affectedFolderPaths {
            clearSearchAndPlaybackState(
                under: URL(fileURLWithPath: folderPath)
            )
        }
        search.completeIndexedCueDataMutation(searchMutationToken)
        refreshLibrary()
        refreshRecentWatching()
        refreshLoadedTestRecentWatching()
        refreshCompleteLibrary()
        refreshDatabaseStorageStats()
    }

    private func refreshLibraryAfterAuxiliaryDataMutation() {
        refreshLibrary()
        refreshRecentWatching()
        refreshLoadedTestRecentWatching()
        refreshCompleteLibrary()
    }

    func restoreCurrentSearchAfterIndexedCueMutationFailure(
        reloadFromDatabase: Bool = true
    ) {
        guard !search.searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return
        }
        search.activateResidentSearchTableProjection()
        guard reloadFromDatabase else {
            return
        }
        refreshCurrentSearch(clearExistingResults: true)
    }

    func refreshDatabaseStorageStats() {
        guard !indexing.folderRemovalStatus.isRemoving,
              !indexing.databaseMaintenanceStatus.isCompacting
        else {
            return
        }

        databaseStorageStatsTask?.cancel()
        guard indexingDatabase != nil else {
            indexing.databaseMaintenanceStatus = .failed(L("status.database_not_initialized"))
            return
        }
        let databaseURL = self.databaseURL

        indexing.databaseMaintenanceStatus = .loadingStats
        databaseStorageStatsTask = Task {
            do {
                let stats = try await Task.detached(priority: .utility) {
                    let maintenance = try DatabaseMaintenanceDatabase(
                        path: databaseURL,
                        access: .readOnly
                    )
                    return try maintenance.storageStats()
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexing.databaseStorageStats = stats
                indexing.databaseMaintenanceStatus = .idle
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexing.databaseMaintenanceStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func refreshSearchFTSVocabularyDiagnostics() {
        guard settings.searchFTSVocabularyDiagnosticsEnabled else {
            indexing.searchFTSVocabularyDiagnosticsTask?.cancel()
            indexing.searchFTSVocabularyDiagnosticsTask = nil
            indexing.searchFTSVocabularyDiagnosticsStatus = .idle
            return
        }

        indexing.searchFTSVocabularyDiagnosticsTask?.cancel()
        guard search.isDatabaseAvailable else {
            indexing.searchFTSVocabularyDiagnosticsStatus = .failed(L("status.database_not_initialized"))
            return
        }

        let query = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let diagnosticsDatabaseURL = databaseURL
        indexing.searchFTSVocabularyDiagnosticsStatus = .loading
        indexing.searchFTSVocabularyDiagnosticsTask = Task {
            do {
                let diagnostics = try await Task.detached(priority: .utility) {
                    let database = try SearchDatabase(
                        path: diagnosticsDatabaseURL,
                        access: .readWrite
                    )
                    return try database.ftsVocabularyDiagnostics(for: query)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexing.searchFTSVocabularyDiagnostics = diagnostics
                indexing.searchFTSVocabularyDiagnosticsStatus = .completed(Date())
                indexing.searchFTSVocabularyDiagnosticsTask = nil
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexing.searchFTSVocabularyDiagnosticsStatus = .failed(Self.errorMessage(for: error))
                indexing.searchFTSVocabularyDiagnosticsTask = nil
            }
        }
    }

    func compactDatabaseStorage() {
        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            return
        }

        guard !indexing.folderRemovalStatus.isRemoving else {
            indexing.databaseMaintenanceStatus = .failed(L("status.folder_removal_running"))
            return
        }

        // Compaction is a developer option and stays out of the queue, so it is
        // the one that stands aside for every library task.
        guard !tasks.hasLibraryTask else {
            indexing.databaseMaintenanceStatus = .failed(L("status.indexing_running"))
            return
        }

        guard !search.isSearching else {
            indexing.databaseMaintenanceStatus = .failed(L("status.search_running"))
            return
        }

        guard indexing.searchFTSVocabularyDiagnosticsTask == nil else {
            indexing.databaseMaintenanceStatus = .failed(L("status.search_diagnostics_loading"))
            return
        }

        guard library.libraryStatus != .loading else {
            indexing.databaseMaintenanceStatus = .failed(L("status.library_loading"))
            return
        }

        guard library.completeLibraryStatus != .loading else {
            indexing.databaseMaintenanceStatus = .failed(L("status.complete_library_loading"))
            return
        }

        guard indexingDatabase != nil else {
            indexing.databaseMaintenanceStatus = .failed(L("status.database_not_initialized"))
            return
        }

        let statsBefore: DatabaseStorageStats
        do {
            cancelStartupDatabaseTask()
            let maintenance = try DatabaseMaintenanceDatabase(
                path: databaseURL,
                access: .readOnly
            )
            statsBefore = try maintenance.storageStats()
        } catch {
            indexing.databaseMaintenanceStatus = .failed(Self.errorMessage(for: error))
            return
        }

        if let availableBytes = Self.availableDiskSpaceBytes(for: databaseURL),
           availableBytes < max(statsBefore.databaseFileBytes, 100 * 1024 * 1024) {
            indexing.databaseMaintenanceStatus = .failed(L("status.not_enough_disk_space"))
            return
        }

        databaseStorageStatsTask?.cancel()
        cancelDatabaseReadTasksBeforeIndexing()
        indexing.databaseStorageStats = statsBefore
        indexing.databaseMaintenanceStatus = .compacting
        let databaseURL = self.databaseURL

        databaseCompactionTask = Task {
            do {
                let statsAfter = try await Task.detached(priority: .utility) {
                    let maintenance = try DatabaseMaintenanceDatabase(path: databaseURL)
                    try maintenance.compactStorage()
                    return try maintenance.storageStats()
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexing.databaseStorageStats = statsAfter
                let bytesBefore = statsBefore.databaseFileBytes + statsBefore.walFileBytes
                let bytesAfter = statsAfter.databaseFileBytes + statsAfter.walFileBytes
                let reclaimedBytes = max(0, bytesBefore - bytesAfter)
                indexing.databaseMaintenanceStatus = .completed(L("status.reclaimed", Self.formattedBytes(reclaimedBytes)))
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexing.databaseMaintenanceStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func cancelStartupDatabaseTask() {
        startupDatabaseTask?.cancel()
        startupDatabaseTask = nil
    }

    func cancelDatabaseReadTasksBeforeIndexing() {
        cancelLibraryDisplayRenditionTask()
        cancelStartupDatabaseTask()
        libraryTask?.cancel()
        libraryTask = nil
        recentWatchingTask?.cancel()
        recentWatchingTask = nil
        testRecentWatchingTask?.cancel()
        testRecentWatchingTask = nil
        completeLibraryTask?.cancel()
        completeLibraryTask = nil
        indexing.searchFTSVocabularyDiagnosticsTask?.cancel()
        indexing.searchFTSVocabularyDiagnosticsTask = nil

        if case .loading = library.libraryStatus {
            library.libraryStatus = library.libraryVideos.isEmpty ? .idle : .completed
        }
        if case .loading = library.recentWatchingStatus {
            library.recentWatchingStatus = library.recentWatchingItems.isEmpty ? .idle : .completed
        }
        if case .loading = library.testRecentWatchingStatus {
            library.testRecentWatchingStatus = library.testRecentWatchingItems.isEmpty ? .idle : .completed
        }
        if case .loading = library.completeLibraryStatus {
            library.completeLibraryStatus = library.completeLibraryFolderSummaries.isEmpty ? .idle : .completed
        }
    }
}
