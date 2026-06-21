import Foundation
import CueSeekerCore
import CueSeekerPlayback

@MainActor
extension AppCoordinator {
    func addFolder(_ folder: URL) {
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
        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = "Database compaction is running"
            return
        }

        let folder = folder.standardizedFileURL
        guard let database = subtitleDatabase else {
            startupError = "Database is not initialized"
            return
        }
        cancelStartupDatabaseTask()
        do {
            try database.removeIndexedFolder(folder)
        } catch {
            startupError = "Failed to remove folder index: \(Self.errorMessage(for: error))"
            return
        }

        indexing.removeFolder(folder)
        clearSearchAndPlaybackState(under: folder)
        refreshLibrary()
        refreshRecentWatching()
        refreshCompleteLibrary()
        refreshCurrentSearch(clearExistingResults: true)
        refreshDatabaseStorageStats()
    }

    func indexFolder(_ folder: URL) {
        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = "Database compaction is running"
            return
        }

        indexingTask?.cancel()
        cancelDatabaseReadTasksBeforeIndexing()
        clearSearchAndPlaybackState(under: folder)
        indexing.indexingStatus = .indexing(folder)

        guard let database = subtitleDatabase else {
            indexing.indexingStatus = .failed(folder, "Database is not initialized")
            return
        }
        let coverDirectory = LibraryCoverIndexer.defaultCoverDirectory(forDatabaseURL: databaseURL)
        indexingTask = Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let indexer = SubtitleIndexer()
                    let result = try indexer.index(folder: folder, into: database)
                    _ = try PlaybackVideoMetadataIndexer().indexDurations(under: folder, into: database)
                    let coverIndexer = LibraryCoverIndexer(
                        configuration: .init(coverDirectory: coverDirectory)
                    )
                    _ = try await coverIndexer.indexCovers(under: folder, into: database)
                    try database.rebuildLibraryPresentationSnapshot()
                    return result
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexing.indexingStatus = .completed(folder, result)
                refreshLibrary()
                refreshRecentWatching()
                refreshCompleteLibrary()
                refreshCurrentSearch()
                refreshDatabaseStorageStats()
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexing.indexingStatus = .failed(folder, Self.errorMessage(for: error))
            }
        }
    }

    func indexAllFolders() {
        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            startupError = "Database compaction is running"
            return
        }

        let folders = indexing.selectedFolders
        guard let firstFolder = folders.first else {
            return
        }

        indexingTask?.cancel()
        cancelDatabaseReadTasksBeforeIndexing()
        for folder in folders {
            clearSearchAndPlaybackState(under: folder)
        }
        indexing.indexingStatus = .indexingAll(
            currentFolder: firstFolder,
            completedFolders: 0,
            totalFolders: folders.count
        )

        guard let database = subtitleDatabase else {
            indexing.indexingStatus = .failed(firstFolder, "Database is not initialized")
            return
        }
        let coverDirectory = LibraryCoverIndexer.defaultCoverDirectory(forDatabaseURL: databaseURL)
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
                        _ = try PlaybackVideoMetadataIndexer().indexDurations(under: folder, into: database)
                        let coverIndexer = LibraryCoverIndexer(
                            configuration: .init(coverDirectory: coverDirectory)
                        )
                        _ = try await coverIndexer.indexCovers(under: folder, into: database)
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
                    return
                }
            }

            guard !Task.isCancelled else {
                return
            }

            guard let aggregateResult else {
                return
            }

            do {
                try await Task.detached(priority: .userInitiated) {
                    try database.rebuildLibraryPresentationSnapshot()
                }.value
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexing.indexingStatus = .failed(firstFolder, Self.errorMessage(for: error))
                return
            }

            indexing.indexingStatus = .completedAll(
                folderCount: folders.count,
                aggregateResult
            )
            refreshLibrary()
            refreshRecentWatching()
            refreshCompleteLibrary()
            refreshCurrentSearch()
            refreshDatabaseStorageStats()
        }
    }

    func refreshDatabaseStorageStats() {
        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            return
        }

        databaseStorageStatsTask?.cancel()
        guard let database = subtitleDatabase else {
            indexing.databaseMaintenanceStatus = .failed("Database is not initialized")
            return
        }

        indexing.databaseMaintenanceStatus = .loadingStats
        databaseStorageStatsTask = Task {
            do {
                let stats = try await Task.detached(priority: .utility) {
                    try database.storageStats()
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
        guard let database = subtitleDatabase else {
            indexing.searchFTSVocabularyDiagnosticsStatus = .failed("Database is not initialized")
            return
        }

        let query = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        indexing.searchFTSVocabularyDiagnosticsStatus = .loading
        indexing.searchFTSVocabularyDiagnosticsTask = Task {
            do {
                let diagnostics = try await Task.detached(priority: .utility) {
                    try database.ftsVocabularyDiagnostics(for: query)
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

        guard let database = subtitleDatabase else {
            indexing.databaseMaintenanceStatus = .failed("Database is not initialized")
            return
        }

        let statsBefore: DatabaseStorageStats
        do {
            cancelStartupDatabaseTask()
            statsBefore = try database.storageStats()
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

        databaseCompactionTask = Task {
            do {
                let statsAfter = try await Task.detached(priority: .utility) {
                    try database.compactStorage()
                    return try database.storageStats()
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
        cancelStartupDatabaseTask()
        libraryTask?.cancel()
        libraryTask = nil
        recentWatchingTask?.cancel()
        recentWatchingTask = nil
        completeLibraryTask?.cancel()
        completeLibraryTask = nil
        searchTask?.cancel()
        searchTask = nil
        searchExactCompletionTask?.cancel()
        searchExactCompletionTask = nil
        searchNavigationTask?.cancel()
        searchNavigationTask = nil
        playbackSubtitleCuesTask?.cancel()
        playbackSubtitleCuesTask = nil
        indexing.searchFTSVocabularyDiagnosticsTask?.cancel()
        indexing.searchFTSVocabularyDiagnosticsTask = nil
        cancelSearchResultGroupTasks()

        if case .loading = library.libraryStatus {
            library.libraryStatus = library.libraryVideos.isEmpty ? .idle : .completed
        }
        if case .loading = library.recentWatchingStatus {
            library.recentWatchingStatus = library.recentWatchingItems.isEmpty ? .idle : .completed
        }
        if case .loading = library.completeLibraryStatus {
            library.completeLibraryStatus = library.completeLibraryFolders.isEmpty ? .idle : .completed
        }
        if case .searching = search.searchStatus {
            search.searchStatus = .completed
        }
    }
}
