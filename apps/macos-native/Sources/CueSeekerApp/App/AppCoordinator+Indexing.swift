import Foundation
import CueSeekerCore
import CueSeekerPlayback

@MainActor
extension AppCoordinator {
    func addFolder(_ folder: URL) {
        guard !indexing.folderRemovalStatus.isRemoving else {
            startupError = "Folder removal is running"
            return
        }

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = "Database compaction is running"
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
            startupError = "Indexing is running"
            return
        }

        guard !indexing.folderRemovalStatus.isRemoving else {
            startupError = "Folder removal is running"
            return
        }

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = "Database compaction is running"
            return
        }

        let folder = folder.standardizedFileURL
        guard indexingDatabase != nil else {
            startupError = "Database is not initialized"
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
        prepareShioriForIndexedContentMutation(under: [folder])

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
                self.reloadShioriAfterIndexedContentMutation()
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
                self.reloadShioriAfterIndexedContentMutation()
                self.search.completeIndexedCueDataMutation(searchMutationToken)
                self.restoreCurrentSearchAfterIndexedCueMutationFailure(
                    reloadFromDatabase: false
                )
                self.startupError = "Failed to remove folder index: \(Self.errorMessage(for: error))"
                self.folderRemovalTask = nil
            }
        }
    }

    func indexFolder(_ folder: URL) {
        guard !indexing.folderRemovalStatus.isRemoving else {
            startupError = "Folder removal is running"
            return
        }

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = "Database compaction is running"
            return
        }

        indexing.removedFolderNotice = nil
        indexingTask?.cancel()
        guard let database = indexingDatabase,
              let libraryDatabase,
              let coverDatabase = libraryCoverDatabase
        else {
            indexing.indexingStatus = .failed(folder, "Database is not initialized")
            return
        }
        let displayRenditionCommitToken = libraryDisplayRenditionCommitGate.beginGeneration()
        indexing.indexingStatus = .indexing(folder)

        let coverDirectory = libraryCoverDirectory
        indexingTask = Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let indexer = SubtitleIndexer()
                    let result = try indexer.index(folder: folder, into: database)
                    if result.hasIndexedContentChanges {
                        _ = try PlaybackVideoMetadataIndexer().indexDurations(
                            videoFiles: result.affectedVideoPaths.map {
                                URL(fileURLWithPath: $0)
                            },
                            into: libraryDatabase
                        )
                        let coverIndexer = LibraryCoverIndexer(
                            configuration: .init(
                                coverDirectory: coverDirectory,
                                displayRenditionCommitToken: displayRenditionCommitToken
                            )
                        )
                        _ = try await coverIndexer.indexCovers(
                            videoPaths: Set(result.affectedVideoPaths),
                            affectedFolderPaths: Set(
                                result.affectedFolderPaths
                            ),
                            into: coverDatabase
                        )
                        try libraryDatabase
                            .refreshPresentationAfterIndexedContentChange(
                                affectedFolderPaths: Set(
                                    result.affectedFolderPaths
                                )
                            )
                    }
                    return result
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexing.indexingStatus = .completed(folder, result)
                applyPublishedIndexMutation(
                    result,
                    shioriFallbackFolders: [folder]
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
            startupError = "Folder removal is running"
            return
        }

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = "Database compaction is running"
            return
        }

        let folders = indexing.selectedFolders
        guard let firstFolder = folders.first else {
            return
        }

        indexing.removedFolderNotice = nil
        indexingTask?.cancel()
        guard let database = indexingDatabase,
              let libraryDatabase,
              let coverDatabase = libraryCoverDatabase
        else {
            indexing.indexingStatus = .failed(firstFolder, "Database is not initialized")
            return
        }
        let displayRenditionCommitToken = libraryDisplayRenditionCommitGate.beginGeneration()
        indexing.indexingStatus = .indexingAll(
            currentFolder: firstFolder,
            completedFolders: 0,
            totalFolders: folders.count
        )

        let coverDirectory = libraryCoverDirectory
        indexingTask = Task {
            var aggregateResult: SubtitleIndexingResult?

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
                    let result = try await Task.detached(priority: .userInitiated) {
                        let indexer = SubtitleIndexer()
                        let result = try indexer.index(folder: folder, into: database)
                        if result.hasIndexedContentChanges {
                            _ = try PlaybackVideoMetadataIndexer().indexDurations(
                                videoFiles: result.affectedVideoPaths.map {
                                    URL(fileURLWithPath: $0)
                                },
                                into: libraryDatabase
                            )
                            let coverIndexer = LibraryCoverIndexer(
                                configuration: .init(
                                    coverDirectory: coverDirectory,
                                    displayRenditionCommitToken: displayRenditionCommitToken
                                )
                            )
                            _ = try await coverIndexer.indexCovers(
                                videoPaths: Set(result.affectedVideoPaths),
                                affectedFolderPaths: Set(
                                    result.affectedFolderPaths
                                ),
                                into: coverDatabase
                            )
                            try libraryDatabase
                                .refreshPresentationAfterIndexedContentChange(
                                    affectedFolderPaths: Set(
                                        result.affectedFolderPaths
                                    )
                                )
                        }
                        return result
                    }.value

                    if var currentResult = aggregateResult {
                        aggregate(result, into: &currentResult)
                        aggregateResult = currentResult
                    } else {
                        aggregateResult = result
                    }
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    indexing.indexingStatus = .failed(folder, Self.errorMessage(for: error))
                    if let aggregateResult {
                        applyPublishedIndexMutation(
                            aggregateResult,
                            shioriFallbackFolders: folders
                        )
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
            applyPublishedIndexMutation(
                aggregateResult,
                shioriFallbackFolders: folders
            )
        }
    }

    private func applyPublishedIndexMutation(
        _ result: SubtitleIndexingResult,
        shioriFallbackFolders: [URL]
    ) {
        if result.requiresShioriRefresh {
            let affectedFolders = result.affectedFolderPaths.isEmpty
                ? shioriFallbackFolders
                : result.affectedFolderPaths.map(
                    URL.init(fileURLWithPath:)
                )
            prepareShioriForIndexedContentMutation(
                under: affectedFolders
            )
            reloadShioriAfterIndexedContentMutation()
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
            indexing.databaseMaintenanceStatus = .failed("Database is not initialized")
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
        guard searchDatabase != nil else {
            indexing.searchFTSVocabularyDiagnosticsStatus = .failed("Database is not initialized")
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
            indexing.databaseMaintenanceStatus = .failed("Folder removal is running")
            return
        }

        guard !indexing.indexingStatus.isIndexing else {
            indexing.databaseMaintenanceStatus = .failed("Indexing is running")
            return
        }

        guard !search.isSearching else {
            indexing.databaseMaintenanceStatus = .failed("Search is running")
            return
        }

        guard indexing.searchFTSVocabularyDiagnosticsTask == nil else {
            indexing.databaseMaintenanceStatus = .failed("Search diagnostics are loading")
            return
        }

        guard library.libraryStatus != .loading else {
            indexing.databaseMaintenanceStatus = .failed("Library is loading")
            return
        }

        guard library.completeLibraryStatus != .loading else {
            indexing.databaseMaintenanceStatus = .failed("Complete Library is loading")
            return
        }

        guard indexingDatabase != nil else {
            indexing.databaseMaintenanceStatus = .failed("Database is not initialized")
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
            indexing.databaseMaintenanceStatus = .failed("Not enough free disk space")
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
                indexing.databaseMaintenanceStatus = .completed("Reclaimed \(Self.formattedBytes(reclaimedBytes))")
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
        searchTask?.cancel()
        searchTask = nil
        searchExactCompletionTask?.cancel()
        searchExactCompletionTask = nil
        searchNavigationTask?.cancel()
        searchNavigationTask = nil
        indexing.searchFTSVocabularyDiagnosticsTask?.cancel()
        indexing.searchFTSVocabularyDiagnosticsTask = nil
        cancelSearchResultGroupTasks()

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
            search.searchStatus = .completed
        }
    }
}
