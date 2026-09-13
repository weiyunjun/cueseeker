import Foundation
import CueSeekerCore
import CueSeekerPlayback

private struct CompletedFolderIndex: Sendable {
    let result: SubtitleIndexingResult
    let auxiliaryFailures: [IndexingAuxiliaryFailure]
    let refreshedAuxiliaryData: Bool
}

private func performFolderIndex(
    folder: URL,
    database: IndexingDatabase,
    libraryDatabase: LibraryDatabase,
    coverDatabase: LibraryCoverDatabase,
    coverDirectory: URL,
    displayRenditionCommitToken:
        LibraryCoverDisplayRenditionCommitToken
) async throws -> CompletedFolderIndex {
    let result = try SubtitleIndexer().index(
        folder: folder,
        into: database
    )
    var failures: [IndexingAuxiliaryFailure] = []
    var refreshedAuxiliaryData = false

    if !result.pendingVideoMetadataPaths.isEmpty {
        do {
            let metadataResult =
                try PlaybackVideoMetadataIndexer().indexDurations(
                    videoFiles: result.pendingVideoMetadataPaths.map {
                        URL(fileURLWithPath: $0)
                    },
                    into: libraryDatabase
                )
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
        )
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
    func addFolder(_ folder: URL) {
        guard !indexing.folderRemovalStatus.isRemoving else {
            startupError = L("status.folder_removal_running")
            return
        }

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = L("status.compaction_running")
            return
        }

        let folder = folder.standardizedFileURL

        guard !indexing.selectedFolders.contains(folder) else {
            indexFolder(folder)
            return
        }

        indexing.appendFolder(folder)
        indexFolder(folder)
    }

    func removeFolders(at offsets: IndexSet) {
        let folders = offsets.map { indexing.selectedFolders[$0] }
        for folder in folders {
            removeFolder(folder)
        }
    }

    func removeFolder(_ folder: URL) {
        guard !indexing.indexingStatus.isIndexing else {
            startupError = L("status.indexing_running")
            return
        }

        guard !indexing.folderRemovalStatus.isRemoving else {
            startupError = L("status.folder_removal_running")
            return
        }

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = L("status.compaction_running")
            return
        }

        let folder = folder.standardizedFileURL
        guard indexingDatabase != nil else {
            startupError = L("status.database_not_initialized")
            return
        }
        let searchMutationToken = search.beginIndexedCueDataMutation()

        startupError = nil
        indexing.removedFolderNotice = nil
        indexing.folderRemovalStatus = .removing(folder)
        databaseStorageStatsTask?.cancel()
        databaseStorageStatsTask = nil
        if case .loadingStats = indexing.databaseMaintenanceStatus {
            indexing.databaseMaintenanceStatus = .idle
        }
        cancelDatabaseReadTasksBeforeIndexing()
        prepareExcerptForIndexedContentMutation(under: [folder])

        let databaseURL = self.databaseURL
        let removalExecutor = libraryFolderRemovalExecutor
        folderRemovalTask = Task { [weak self] in
            do {
                try await removalExecutor.removeFolder(folder, databaseURL: databaseURL)
                guard let self else {
                    return
                }

                self.indexing.removeFolder(folder)
                self.clearSearchAndPlaybackState(under: folder)
                self.indexing.folderRemovalStatus = .idle
                self.reloadExcerptAfterIndexedContentMutation()
                self.search.completeIndexedCueDataMutation(searchMutationToken)
                self.indexing.removedFolderNotice = folder
                self.refreshLibrary()
                self.refreshRecentWatching()
                self.refreshLoadedTestRecentWatching()
                self.refreshCompleteLibrary()
                self.refreshCurrentSearch(clearExistingResults: true)
                self.refreshDatabaseStorageStats()
                self.folderRemovalTask = nil
            } catch {
                guard let self else {
                    return
                }

                self.indexing.folderRemovalStatus = .idle
                self.reloadExcerptAfterIndexedContentMutation()
                self.search.completeIndexedCueDataMutation(searchMutationToken)
                self.restoreCurrentSearchAfterIndexedCueMutationFailure(
                    reloadFromDatabase: false
                )
                self.startupError = L("status.folder_index_removal_failed", Self.errorMessage(for: error))
                self.folderRemovalTask = nil
            }
        }
    }

    func indexFolder(_ folder: URL) {
        guard !indexing.folderRemovalStatus.isRemoving else {
            startupError = L("status.folder_removal_running")
            return
        }

        guard !indexing.indexingStatus.isIndexing else {
            startupError = L("status.indexing_running")
            return
        }

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = L("status.compaction_running")
            return
        }

        indexing.removedFolderNotice = nil
        guard let database = indexingDatabase,
              let libraryDatabase,
              let coverDatabase = libraryCoverDatabase
        else {
            indexing.indexingStatus = .failed(folder, L("status.database_not_initialized"))
            return
        }
        let displayRenditionCommitToken = libraryDisplayRenditionCommitGate.beginGeneration()
        indexing.indexingStatus = .indexing(folder)
        indexing.auxiliaryFailures = []

        let coverDirectory = libraryCoverDirectory
        indexingTask = Task {
            do {
                let completed = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try await performFolderIndex(
                        folder: folder,
                        database: database,
                        libraryDatabase: libraryDatabase,
                        coverDatabase: coverDatabase,
                        coverDirectory: coverDirectory,
                        displayRenditionCommitToken:
                            displayRenditionCommitToken
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexing.indexingStatus = .completed(
                    folder,
                    completed.result
                )
                indexing.auxiliaryFailures =
                    completed.auxiliaryFailures
                applyPublishedIndexMutation(
                    completed.result,
                    excerptFallbackFolders: [folder]
                )
                applyAuxiliaryDataRefreshIfNeeded(
                    completed,
                    mainIndexRefreshedUI:
                        completed.result.hasIndexedContentChanges
                )
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexing.indexingStatus = .failed(folder, Self.errorMessage(for: error))
            }
        }
    }

    func indexAllFolders() {
        guard !indexing.folderRemovalStatus.isRemoving else {
            startupError = L("status.folder_removal_running")
            return
        }

        guard !indexing.indexingStatus.isIndexing else {
            startupError = L("status.indexing_running")
            return
        }

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = L("status.compaction_running")
            return
        }

        let folders = indexing.selectedFolders
        guard let firstFolder = folders.first else {
            return
        }

        indexing.removedFolderNotice = nil
        guard let database = indexingDatabase,
              let libraryDatabase,
              let coverDatabase = libraryCoverDatabase
        else {
            indexing.indexingStatus = .failed(firstFolder, L("status.database_not_initialized"))
            return
        }
        let displayRenditionCommitToken = libraryDisplayRenditionCommitGate.beginGeneration()
        indexing.indexingStatus = .indexingAll(
            currentFolder: firstFolder,
            completedFolders: 0,
            totalFolders: folders.count
        )
        indexing.auxiliaryFailures = []

        let coverDirectory = libraryCoverDirectory
        indexingTask = Task {
            var aggregateResult: SubtitleIndexingResult?
            var auxiliaryFailures: [IndexingAuxiliaryFailure] = []
            var refreshedAuxiliaryData = false

            for (index, folder) in folders.enumerated() {
                guard !Task.isCancelled else {
                    return
                }

                indexing.indexingStatus = .indexingAll(
                    currentFolder: folder,
                    completedFolders: index,
                    totalFolders: folders.count
                )

                do {
                    let completed = try await Task.detached(
                        priority: .userInitiated
                    ) {
                        try await performFolderIndex(
                            folder: folder,
                            database: database,
                            libraryDatabase: libraryDatabase,
                            coverDatabase: coverDatabase,
                            coverDirectory: coverDirectory,
                            displayRenditionCommitToken:
                                displayRenditionCommitToken
                        )
                    }.value
                    auxiliaryFailures.append(
                        contentsOf: completed.auxiliaryFailures
                    )
                    refreshedAuxiliaryData =
                        refreshedAuxiliaryData
                        || completed.refreshedAuxiliaryData

                    if var currentResult = aggregateResult {
                        aggregate(
                            completed.result,
                            into: &currentResult
                        )
                        aggregateResult = currentResult
                    } else {
                        aggregateResult = completed.result
                    }
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    indexing.indexingStatus = .failed(folder, Self.errorMessage(for: error))
                    indexing.auxiliaryFailures =
                        auxiliaryFailures
                    if let aggregateResult {
                        applyPublishedIndexMutation(
                            aggregateResult,
                            excerptFallbackFolders: folders
                        )
                        if refreshedAuxiliaryData
                            && !aggregateResult
                                .hasIndexedContentChanges
                        {
                            refreshLibraryAfterAuxiliaryDataMutation()
                        }
                    }
                    return
                }
            }

            guard !Task.isCancelled else {
                return
            }

            guard let aggregateResult else {
                return
            }

            indexing.indexingStatus = .completedAll(
                folderCount: folders.count,
                aggregateResult
            )
            indexing.auxiliaryFailures = auxiliaryFailures
            applyPublishedIndexMutation(
                aggregateResult,
                excerptFallbackFolders: folders
            )
            if refreshedAuxiliaryData
                && !aggregateResult.hasIndexedContentChanges
            {
                refreshLibraryAfterAuxiliaryDataMutation()
            }
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
        refreshCurrentSearch()
        refreshDatabaseStorageStats()
    }

    private func applyAuxiliaryDataRefreshIfNeeded(
        _ completed: CompletedFolderIndex,
        mainIndexRefreshedUI: Bool
    ) {
        guard completed.refreshedAuxiliaryData,
              !mainIndexRefreshedUI
        else {
            return
        }
        refreshLibraryAfterAuxiliaryDataMutation()
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

        guard !indexing.indexingStatus.isIndexing else {
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
        search.cancelAllSearchTasks()
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
        if case .searching = search.searchStatus {
            search.markSearchCompleted()
        }
    }
}
