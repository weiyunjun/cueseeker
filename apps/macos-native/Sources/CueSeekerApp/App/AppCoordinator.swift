import AppKit
import Combine
import Foundation
import SwiftUI
import CueSeekerCore
import CueSeekerPlayback


private struct LibraryPlaybackHistorySnapshot: Sendable {
    let videoPath: String
    let positionMilliseconds: Int
    let duration: Double?
}

private final class LibraryPlaybackHistoryWriter: @unchecked Sendable {
    private let database: SubtitleDatabase?
    private let queue = DispatchQueue(
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

    private func write(_ snapshot: LibraryPlaybackHistorySnapshot) {
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


private struct SearchPageLoad: Sendable {
    let page: SubtitleSearchPage
    let databaseSearchMilliseconds: Double
}

/// Workflow coordinator. Holds references to the per-domain stores (settings,
/// indexing, workbenchLayout, shiori, library, search, playback) and owns the
/// orchestration methods that span multiple domains. Per-domain @Published
/// state and derived display properties live on the respective stores;
/// AppCoordinator's own @Published surface is intentionally minimal
/// (`startupError` only) so views observing the stores get scoped invalidation.
@MainActor
final class AppCoordinator: ObservableObject {
    private static let playbackVolumeKey = "playbackVolume"
    private static let playbackLastNonzeroVolumeKey = "playbackLastNonzeroVolume"
    private static let playbackSpeedKey = "playbackSpeed"
    private static let playbackSubtitlesVisibleKey = "playbackSubtitlesVisible"
    private static let assSubtitlePreparationCueLimit = 8
    private static let searchPageSize = 100
    private static let searchPrefetchThreshold = 10
    private static let searchCountProgressMinimumIntervalNanoseconds: UInt64 = 200_000_000
    private static let searchNavigationPanelRadius = 10_000
    private static let databaseCompactionMinimumReclaimableBytes: Int64 = 100 * 1024 * 1024
    private static let databaseCompactionMinimumFreelistRatio = 0.25

    @Published var startupError: String?
    let settings: SettingsStore
    let indexing: IndexingStore
    let shiori: ShioriStore
    let library: LibraryStore
    let search: SearchStore
    let playback: PlaybackStore
    private var settingsCancellables: Set<AnyCancellable> = []

    let databaseURL: URL
    private var subtitleDatabase: SubtitleDatabase?
    let workbenchLayout: WorkbenchLayoutState
    let playbackFullscreenManager = PlaybackFullscreenManager()
    var playbackPlayer: PlaybackPlayer? {
        player
    }

    var searchGlobalLoadMoreTriggerID: String {
        "\(nextGlobalSearchCursor?.offset ?? loadedGlobalSearchResultCount)-\(search.isSearching)"
    }

    private static func makeLibraryFolderGroups(
        from snapshot: [LibraryFolderPresentation]
    ) -> [LibraryFolderGroup] {
        snapshot.map { folder in
            LibraryFolderGroup(
                folderPath: folder.folderPath,
                folderTitle: folder.folderTitle,
                videos: folder.videos.map { row in
                    LibraryVideoRow(
                        video: row.libraryVideo,
                        displayTitle: row.displayTitle,
                        fileExtension: row.fileExtension,
                        duration: row.duration
                    )
                }
            )
        }
    }

    private static func makeSearchResultGroups(
        results searchResults: [SubtitleSearchResult],
        fileSummaries searchFileSummaries: [SubtitleSearchFileSummary],
        expandedRowsByPath: [String: [SubtitleSearchResult]],
        collapsedGroupPaths: Set<String>,
        includesSummaryOnlyGroups: Bool
    ) -> [SearchResultFileGroup] {
        let resultsByPath = Dictionary(grouping: searchResults, by: \.subtitlePath)
        let nonEmptyExpandedRowsByPath = expandedRowsByPath.filter { !$0.value.isEmpty }
        let loadedPaths = Set(resultsByPath.keys).union(nonEmptyExpandedRowsByPath.keys)
        guard !searchFileSummaries.isEmpty || !loadedPaths.isEmpty else {
            return []
        }

        let summaryByPath = Dictionary(uniqueKeysWithValues: searchFileSummaries.map { ($0.subtitlePath, $0) })
        let summaryPaths = Set(searchFileSummaries.map(\.subtitlePath))
        let orderedPaths = searchFileSummaries
            .map(\.subtitlePath)
            .filter { includesSummaryOnlyGroups || loadedPaths.contains($0) }
        let extraPaths = loadedPaths
            .filter { !summaryPaths.contains($0) }
            .sorted(by: Self.searchResultGroupPathSort)

        return (orderedPaths + extraPaths).map { path in
            let summary = summaryByPath[path]
            let groupRows = nonEmptyExpandedRowsByPath[path] ?? resultsByPath[path] ?? []
            let results = groupRows.sorted(by: Self.searchResultSort)
            return SearchResultFileGroup(
                subtitlePath: path,
                subtitleDisplayTitle: summary?.subtitleDisplayTitle
                    ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: path),
                totalCount: summary?.matchCount ?? results.count,
                results: results,
                isCollapsed: collapsedGroupPaths.contains(path)
            )
        }
    }

    private static func makeShioriFileGroups(
        from shioris: [Shiori],
        collapsedGroupPaths: Set<String>
    ) -> [ShioriFileGroup] {
        let shiorisByPath = Dictionary(grouping: shioris, by: \.subtitlePath)
        let displayTitlesByPath = Dictionary(
            uniqueKeysWithValues: shiorisByPath.keys.map { path in
                (
                    path,
                    SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: path)
                )
            }
        )

        return shiorisByPath.keys.sorted { lhs, rhs in
            let lhsDisplayTitle = displayTitlesByPath[lhs] ?? URL(fileURLWithPath: lhs).lastPathComponent
            let rhsDisplayTitle = displayTitlesByPath[rhs] ?? URL(fileURLWithPath: rhs).lastPathComponent
            let displayTitleComparison = SubtitleDisplayTitleResolver.compareDisplayTitles(lhsDisplayTitle, rhsDisplayTitle)
            if displayTitleComparison != .orderedSame {
                return displayTitleComparison == .orderedAscending
            }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        .map { path in
            ShioriFileGroup(
                subtitlePath: path,
                subtitleDisplayTitle: displayTitlesByPath[path] ?? URL(fileURLWithPath: path).lastPathComponent,
                shioris: (shiorisByPath[path] ?? []).sorted(by: Self.shioriSort),
                isCollapsed: collapsedGroupPaths.contains(path)
            )
        }
    }

    var hasLibraryFolderGroups: Bool {
        !library.libraryFolderGroups.isEmpty
    }

    var hasPlaybackSelection: Bool {
        currentPlaybackVideoPath != nil
    }

    var isPlaybackPageVisible: Bool {
        hasPlaybackSelection && playback.isPlaybackSurfaceExpanded
    }

    var currentPlaybackVideoPath: String? {
        library.selectedLibraryVideo?.videoPath ?? search.selectedSearchResult?.videoPath ?? shiori.selectedShiori?.videoPath
    }

    var currentPlaybackSubtitlePath: String? {
        library.selectedLibraryVideo?.subtitlePath ?? search.selectedSearchResult?.subtitlePath ?? shiori.selectedShiori?.subtitlePath
    }

    var currentPlaybackSubtitleFormat: SubtitleFormat? {
        library.selectedLibraryVideo?.subtitleFormat ?? search.selectedSearchResult?.subtitleFormat ?? shiori.selectedShiori?.subtitleFormat
    }

    var currentPlaybackTitle: String {
        library.selectedLibraryVideo?.videoName
            ?? search.selectedSearchResult?.videoName
            ?? shiori.selectedShiori?.videoName
            ?? "No video selected"
    }

    var currentPlaybackDisplayTitle: String {
        if let selectedLibraryVideo = library.selectedLibraryVideo {
            return library.libraryFolderGroups
                .lazy
                .flatMap(\.videos)
                .first { $0.video.videoPath == selectedLibraryVideo.videoPath }?
                .displayTitle
                ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedLibraryVideo.subtitlePath)
        }

        if let selectedSearchResult = search.selectedSearchResult {
            return search.searchResultGroups
                .first { $0.subtitlePath == selectedSearchResult.subtitlePath }?
                .subtitleDisplayTitle
                ?? search.searchFileSummaries
                    .first { $0.subtitlePath == selectedSearchResult.subtitlePath }?
                    .subtitleDisplayTitle
                ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedSearchResult.subtitlePath)
        }

        if let selectedShiori = shiori.selectedShiori {
            return shiori.shioriFileGroups
                .first { $0.subtitlePath == selectedShiori.subtitlePath }?
                .subtitleDisplayTitle
                ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedShiori.subtitlePath)
        }

        return "No video selected"
    }

    var isLibraryPlaybackActive: Bool {
        if case .library = activePlaybackSource {
            return true
        }

        return false
    }

    var isSearchPlaybackActive: Bool {
        activePlaybackSource == .search
    }

    var canOpenPreviousLibraryVideo: Bool {
        libraryAdjacentVideo(offset: -1) != nil
    }

    var canOpenNextLibraryVideo: Bool {
        libraryAdjacentVideo(offset: 1) != nil
    }

    var canOpenPreviousSearchResult: Bool {
        guard isSearchPlaybackActive, search.selectedSearchResult != nil else {
            return false
        }

        if let searchNavigationSnapshot = search.searchNavigationSnapshot {
            return searchNavigationSnapshot.previous != nil
        }

        return search.searchResultTotalCount > 1
    }

    var canOpenNextSearchResult: Bool {
        guard isSearchPlaybackActive, search.selectedSearchResult != nil else {
            return false
        }

        if let searchNavigationSnapshot = search.searchNavigationSnapshot {
            return searchNavigationSnapshot.next != nil
        }

        return search.searchResultTotalCount > 1
    }

    var isPlaybackFullscreenToggleDisabled: Bool {
        currentPlaybackVideoPath == nil
            || workbenchLayout.isVideoSizeTransitionInProgress
            || playbackFullscreenManager.isTransitioning
    }

    var isDatabaseCompactionRecommended: Bool {
        guard let stats = indexing.databaseStorageStats else {
            return false
        }

        return stats.freelistBytes >= Self.databaseCompactionMinimumReclaimableBytes
            && stats.freelistRatio >= Self.databaseCompactionMinimumFreelistRatio
    }

    var canCompactDatabase: Bool {
        subtitleDatabase != nil
            && !indexing.indexingStatus.isIndexing
            && !indexing.databaseMaintenanceStatus.isCompacting
            && !search.isSearching
            && indexing.searchFTSVocabularyDiagnosticsTask == nil
            && library.libraryStatus != .loading
    }

    private let userDefaults: UserDefaults
    private var player: PlaybackPlayer?
    private let libraryPlaybackHistoryWriter: LibraryPlaybackHistoryWriter
    private var startupDatabaseTask: Task<Void, Never>?
    private var indexingTask: Task<Void, Never>?
    private var libraryTask: Task<Void, Never>?
    private var shiorisTask: Task<Void, Never>?
    private var libraryPlaybackHistoryTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var searchExactCompletionTask: Task<Void, Never>?
    private var searchNavigationTask: Task<Void, Never>?
    private var currentSubtitleEntriesTask: Task<Void, Never>?
    private var databaseStorageStatsTask: Task<Void, Never>?
    private var databaseCompactionTask: Task<Void, Never>?
    private var videoSizeTransitionTask: Task<Void, Never>?
    private var windowFrameBeforeUserZoom: NSRect?
    private var searchResultGroupTasks: [String: Task<Void, Never>] = [:]
    private var activeSearchPerformanceRun: SearchPerformanceRun?
    private var pendingSearchVisibleEntryIDs: Set<Int64> = []
    private var activePlaybackSource: ActivePlaybackSource = .none
    private var playbackOriginatingPanelMode: WorkbenchPanelMode?
    private var loadedGlobalSearchResultCount = 0
    private var lastSearchCountProgressUpdate: UInt64 = 0
    private var nextGlobalSearchCursor: SubtitleSearchCursor?

    init(
        userDefaults: UserDefaults = .standard,
        databaseURL: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()

        userDefaults.register(defaults: [
            "workbenchPanelMode": WorkbenchPanelMode.search.rawValue,
            Self.playbackVolumeKey: 100.0,
            Self.playbackLastNonzeroVolumeKey: 100.0,
            Self.playbackSpeedKey: 1.0,
            Self.playbackSubtitlesVisibleKey: true
        ])
        workbenchLayout = WorkbenchLayoutState(userDefaults: userDefaults)
        settings = SettingsStore(userDefaults: userDefaults)
        indexing = IndexingStore(userDefaults: userDefaults, settings: settings)
        shiori = ShioriStore()
        library = LibraryStore()
        search = SearchStore()
        playback = PlaybackStore()

        let openedDatabase: SubtitleDatabase?
        let initialError: Error?
        do {
            try Self.prepareDatabaseDirectory(for: self.databaseURL)
            let database = try SubtitleDatabase(path: self.databaseURL)
            try database.migrate()
            openedDatabase = database
            initialError = nil
        } catch {
            openedDatabase = nil
            initialError = error
        }

        self.subtitleDatabase = openedDatabase
        libraryPlaybackHistoryWriter = LibraryPlaybackHistoryWriter(database: openedDatabase)

        if let initialError {
            startupError = Self.errorMessage(for: initialError)
            return
        }

        guard let database = openedDatabase else {
            return
        }

        let folders = indexing.selectedFolders
        startupDatabaseTask = Task { [weak self] in
            do {
                try await Self.runCancellableDetached(priority: .background) {
                    try database.reconcileIndexedContent(activeFolders: folders)
                }

                guard !Task.isCancelled else {
                    await MainActor.run {
                        self?.startupDatabaseTask = nil
                    }
                    return
                }

                let stats = try await Self.runCancellableDetached(priority: .background) {
                    try database.storageStats()
                }

                guard !Task.isCancelled else {
                    await MainActor.run {
                        self?.startupDatabaseTask = nil
                    }
                    return
                }

                await MainActor.run {
                    self?.indexing.databaseStorageStats = stats
                    self?.startupDatabaseTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.startupDatabaseTask = nil
                }
            } catch {
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self?.startupDatabaseTask = nil
                    }
                    return
                }

                print("Failed background reconciliation/stats query: \(error)")
                await MainActor.run {
                    self?.startupDatabaseTask = nil
                }
            }
        }

        setupSettingsObservers()
    }

    private func setupSettingsObservers() {
        settings.$playbackDecodeMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.player?.decodeMode = mode
            }
            .store(in: &settingsCancellables)

    }

    nonisolated private static func runCancellableDetached<T: Sendable>(
        priority: TaskPriority,
        operation: @Sendable @escaping () throws -> T
    ) async throws -> T {
        let task = Task.detached(priority: priority, operation: operation)
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

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
        refreshCurrentSearch(clearExistingResults: true)
        refreshDatabaseStorageStats()
    }

    func performUserInitiatedAppCommand(_ action: () -> Void) {
        AppPerformanceProbe.action("AppCoordinator.performUserInitiatedAppCommand", thresholdMilliseconds: 4) {
            workbenchLayout.clearSearchFocus()
            action()
        }
    }

    func beginTitlebarZoomTransitionFromUser(window: NSWindow) -> Bool {
        let targetFrame: NSRect
        if window.isZoomed, let windowFrameBeforeUserZoom {
            targetFrame = windowFrameBeforeUserZoom
            self.windowFrameBeforeUserZoom = nil
        } else {
            windowFrameBeforeUserZoom = window.frame
            targetFrame = window.screen?.visibleFrame ?? window.frame
        }

        return beginVideoSizeTransition(duration: Self.animationResizeDuration(
            for: window,
            targetFrame: targetFrame
        ))
    }

    func activateWorkbenchPanelMode(_ mode: WorkbenchPanelMode) {
        AppPerformanceProbe.action("AppCoordinator.activateWorkbenchPanelMode", thresholdMilliseconds: 4) {
            if workbenchLayout.panelMode == mode {
                return
            }

            UIInvalidationProbe.mark(
                "ACTION UI.WorkbenchMode.selected",
                details: "from=\(workbenchLayout.panelMode.rawValue) to=\(mode.rawValue)"
            )
            workbenchLayout.selectPanelMode(mode)
        }
    }

    func togglePlaybackFullscreenFromUser() {
        guard let player, let playbackViewModel = playback.playbackViewModel else {
            return
        }

        guard beginVideoSizeTransition() else {
            return
        }

        let enteringFullscreen = !playbackFullscreenManager.isFullscreen
        let started = playbackFullscreenManager.toggleFullscreen(
            player: player,
            onTransitionCompleted: { [weak self] in
                self?.endVideoSizeTransition()
            }
        )
        if !started {
            endVideoSizeTransition()
        } else {
            playbackViewModel.showFullscreenFeedback(enteringFullscreen: enteringFullscreen)
        }
    }

    func openPreviousLibraryVideo() {
        openAdjacentLibraryVideo(offset: -1)
    }

    func openNextLibraryVideo() {
        openAdjacentLibraryVideo(offset: 1)
    }

    func togglePlaybackSidePanelFromUser() {
        guard hasPlaybackSelection else {
            return
        }

        // The overlay panel floats over the video and never resizes it, so
        // this toggle is NOT a video-size-changing command: it must not pass
        // through the serialized resize gate (it must never be swallowed by
        // the rapid-repeat guard or serialized with fullscreen/zoom) and must
        // not animate as a video-size transition or mutate
        // playback.isPlaybackSurfaceExpanded (architecture §7.1, doc 12 §11). The
        // panel's own ~180 ms show/hide animation is owned by PlaybackPageView.
        playback.isPlaybackSidePanelVisible.toggle()
    }

    func exitPlaybackFullscreenFromUser() {
        guard playbackFullscreenManager.isFullscreen else {
            return
        }

        guard beginVideoSizeTransition() else {
            return
        }

        let started = playbackFullscreenManager.exitFullscreen(
            animated: true,
            onTransitionCompleted: { [weak self] in
                self?.endVideoSizeTransition()
            }
        )
        if !started {
            endVideoSizeTransition()
        } else {
            playback.playbackViewModel?.showFullscreenFeedback(enteringFullscreen: false)
        }
    }

    func minimizePlaybackWindowFromUser() {
        // Minimize is windowed-only (the custom top bar is hidden in
        // fullscreen, which has no minimize affordance), so just miniaturize
        // the window to the Dock.
        let window = player?.renderView.window
            ?? NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
        window?.miniaturize(nil)
    }

    private func beginVideoSizeTransition(durationNanoseconds: UInt64) -> Bool {
        beginVideoSizeTransition(duration: TimeInterval(durationNanoseconds) / 1_000_000_000)
    }

    private func beginVideoSizeTransition(duration: TimeInterval) -> Bool {
        guard beginVideoSizeTransition() else {
            return false
        }

        completeVideoSizeTransition(after: duration)
        return true
    }

    private func beginVideoSizeTransition() -> Bool {
        guard workbenchLayout.beginVideoSizeTransition() else {
            return false
        }

        videoSizeTransitionTask?.cancel()
        return true
    }

    private func completeVideoSizeTransition(after duration: TimeInterval?) {
        let duration = max(0, duration ?? 0)
        guard duration > 0 else {
            endVideoSizeTransition()
            return
        }

        videoSizeTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.endVideoSizeTransition()
            }
        }
    }

    private func endVideoSizeTransition() {
        workbenchLayout.endVideoSizeTransition()
        videoSizeTransitionTask = nil
    }

    private static func animationResizeDuration(
        for window: NSWindow,
        targetFrame: NSRect
    ) -> TimeInterval {
        max(0, window.animationResizeTime(targetFrame))
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
        indexingTask = Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let indexer = SubtitleIndexer()
                    let result = try indexer.index(folder: folder, into: database)
                    _ = try PlaybackVideoMetadataIndexer().indexDurations(under: folder, into: database)
                    try database.rebuildLibraryPresentationSnapshot()
                    return result
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexing.indexingStatus = .completed(folder, result)
                refreshLibrary()
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
            refreshCurrentSearch()
            refreshDatabaseStorageStats()
        }
    }

    func updateSearchQuery(_ query: String) {
        UIInvalidationProbe.mark(
            "ACTION UI.SearchQuery.changed",
            details: "length=\(query.count)"
        )
        search.searchQuery = query
        startSearch(query: query, cursor: .start, appending: false, debounce: true)
    }

    func submitTopbarSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        UIInvalidationProbe.mark(
            "ACTION UI.TopbarSearch.submitted",
            details: "length=\(trimmedQuery.count)"
        )
        if playback.playbackViewModel?.isPlaying == true {
            pausePlayback()
        }
        workbenchLayout.selectPanelMode(.search)
        search.searchQuery = trimmedQuery
        search.searchNavigationSnapshot = nil
        search.searchNavigationResultGroups = []
        startSearch(query: trimmedQuery, cursor: .start, appending: false, debounce: false)
    }

    func loadMoreSearchResultsIfNeeded(currentResult result: SubtitleSearchResult) {
        if search.searchResultPresentationState == .collapsed {
            loadMoreSearchResultGroupRowsIfNeeded(currentResult: result)
            return
        }

        guard search.hasMoreSearchResults, !search.isSearching else {
            return
        }

        guard let index = search.searchResults.firstIndex(where: { $0.entryID == result.entryID }),
              index >= search.searchResults.count - Self.searchPrefetchThreshold
        else {
            return
        }

        loadMoreSearchResultsIfNeeded()
    }

    func loadMoreSearchResultsIfNeeded() {
        guard search.searchResultPresentationState != .collapsed else {
            return
        }

        guard search.hasMoreSearchResults, !search.isSearching else {
            return
        }

        guard let cursor = nextGlobalSearchCursor else {
            return
        }

        startSearch(
            query: search.searchQuery,
            cursor: cursor,
            appending: true,
            debounce: false
        )
    }

    func toggleSearchResultGroup(_ subtitlePath: String) {
        let hasLoadedRows = searchResultGroupHasLoadedRows(subtitlePath)
        UIInvalidationProbe.mark(
            "ACTION UI.SearchResultGroup.toggled",
            details: "collapsedBefore=\(search.collapsedSearchResultGroupPaths.contains(subtitlePath)) loadedRows=\(hasLoadedRows)"
        )
        if search.collapsedSearchResultGroupPaths.contains(subtitlePath) {
            search.collapsedSearchResultGroupPaths.remove(subtitlePath)
            rebuildSearchResultGroups()
            if search.searchResultPresentationState == .collapsed {
                revealInitialSearchResultGroupPage(for: subtitlePath)
            }
        } else if hasLoadedRows {
            search.collapsedSearchResultGroupPaths.insert(subtitlePath)
            rebuildSearchResultGroups()
        } else if searchResultGroupTasks[subtitlePath] == nil {
            revealInitialSearchResultGroupPage(for: subtitlePath)
        } else {
            return
        }
    }

    func collapseAllSearchResultGroups() {
        guard search.canCollapseAllSearchResultGroups else {
            return
        }

        let groupPaths = Set(search.searchFileSummaries.map(\.subtitlePath))
        guard !groupPaths.isEmpty else {
            return
        }

        UIInvalidationProbe.mark(
            "ACTION UI.SearchResults.collapseAll",
            details: "groups=\(groupPaths.count)"
        )
        search.searchResultPresentationState = .collapsed
        search.expandedSearchResultGroupRowsByPath = [:]
        search.collapsedSearchResultGroupPaths = groupPaths
        rebuildSearchResultGroups()
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

    func hydrateShiorisAsync() {
        guard let database = subtitleDatabase else {
            return
        }

        shiorisTask?.cancel()
        shiorisTask = Task { [weak self] in
            do {
                let loadedShioris = try await Task.detached(priority: .userInitiated) {
                    try database.shioris()
                }.value

                guard !Task.isCancelled else { return }

                self?.applyShioris(loadedShioris)
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load shioris asynchronously: \(error)")
            }
        }
    }

    private func ensurePlayerInitialized() {
        guard player == nil else { return }
        let player = PlaybackPlayer()
        player.decodeMode = settings.playbackDecodeMode
        self.player = player
        playback.playbackViewModel = PlaybackViewModel(
            player: player,
            initialVolume: Self.loadPlaybackVolume(from: userDefaults),
            initialLastNonzeroVolume: Self.loadPlaybackLastNonzeroVolume(from: userDefaults),
            initialPlaybackSpeed: Self.loadPlaybackSpeed(from: userDefaults),
            initialSubtitlesVisible: userDefaults.bool(forKey: Self.playbackSubtitlesVisibleKey),
            onVolumeChanged: { [weak self] volume in
                self?.userDefaults.set(volume, forKey: Self.playbackVolumeKey)
            },
            onLastNonzeroVolumeChanged: { [weak self] volume in
                self?.userDefaults.set(volume, forKey: Self.playbackLastNonzeroVolumeKey)
            },
            onPlaybackSpeedChanged: { [weak self] speed in
                self?.userDefaults.set(speed, forKey: Self.playbackSpeedKey)
            },
            onSubtitlesVisibleChanged: { [weak self] isVisible in
                self?.userDefaults.set(isVisible, forKey: Self.playbackSubtitlesVisibleKey)
            }
        )
    }

    private func applyLibraryPresentation(_ snapshot: [LibraryFolderPresentation]) {
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

    private func removeLibraryPresentation(under folder: URL) {
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

    private func applyShioris(_ nextShioris: [Shiori]) {
        shiori.shioris = nextShioris.sorted(by: Self.shioriSort)
        rebuildShioriFileGroups()
    }

    private func rebuildShioriFileGroups() {
        shiori.shioriFileGroups = Self.makeShioriFileGroups(
            from: shiori.shioris,
            collapsedGroupPaths: shiori.collapsedShioriGroupPaths
        )
        UIInvalidationProbe.count(
            "UI.ShioriPresentation.rebuilt",
            details: "groups=\(shiori.shioriFileGroups.count) rows=\(shiori.shioris.count)"
        )
    }

    private func startSearch(
        query: String,
        cursor: SubtitleSearchCursor,
        appending: Bool,
        debounce: Bool
    ) {
        searchTask?.cancel()
        if !appending {
            searchExactCompletionTask?.cancel()
            searchExactCompletionTask = nil
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let folders = indexing.selectedFolders
        let pageSize = Self.searchPageSize
        let offset = cursor.offset
        if let activeSearchPerformanceRun {
            SearchPerformanceLogger.mark(activeSearchPerformanceRun, "search_superseded_by_new_search")
            SearchPerformanceLogger.writeE2ESearchPage(
                activeSearchPerformanceRun,
                event: "search_superseded_by_new_search",
                page: nil,
                status: "cancelled"
            )
        }
        let searchPerformanceRun = SearchPerformanceLogger.startRun(
            query: trimmedQuery,
            queryLength: trimmedQuery.count,
            offset: offset,
            cursor: cursor,
            limit: pageSize,
            appending: appending,
            debounce: debounce,
            folderPaths: folders.map(\.path),
            e2eLoggingEnabled: settings.searchE2ELoggingEnabled
        )
        activeSearchPerformanceRun = searchPerformanceRun
        pendingSearchVisibleEntryIDs = []

        if !appending {
            let resetStart = SearchPerformanceLogger.now()
            resetSearchResultLoadingState()
            SearchPerformanceLogger.mark(
                searchPerformanceRun,
                "search_state_reset",
                phaseStart: resetStart,
                groupCount: search.searchResultGroups.count,
                renderedRowCount: search.renderedSearchResultCount,
                status: "reset"
            )
        }

        guard !trimmedQuery.isEmpty else {
            search.searchStatus = .idle
            SearchPerformanceLogger.mark(searchPerformanceRun, "search_skipped_empty_query", status: "idle")
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_skipped_empty_query",
                page: nil,
                status: "idle"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }

        guard !folders.isEmpty else {
            search.searchStatus = .completed
            search.selectedSearchResult = nil
            SearchPerformanceLogger.mark(searchPerformanceRun, "search_skipped_no_folders", status: "completed")
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_skipped_no_folders",
                page: nil,
                status: "completed"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }

        search.searchStatus = .searching
        SearchPerformanceLogger.mark(searchPerformanceRun, "search_status_searching", status: "searching")

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            search.searchStatus = .failed("Database compaction is running")
            SearchPerformanceLogger.mark(
                searchPerformanceRun,
                "search_failed_database_compacting",
                status: "failed",
                error: "Database compaction is running"
            )
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_failed_database_compacting",
                page: nil,
                status: "failed",
                error: "Database compaction is running"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }

        guard let database = subtitleDatabase else {
            search.searchStatus = .failed("Database is not initialized")
            SearchPerformanceLogger.mark(
                searchPerformanceRun,
                "search_failed_no_database",
                status: "failed",
                error: "Database is not initialized"
            )
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_failed_no_database",
                page: nil,
                status: "failed",
                error: "Database is not initialized"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }
        searchTask = Task {
            do {
                if debounce {
                    let debounceStart = SearchPerformanceLogger.now()
                    try await Task.sleep(nanoseconds: 250_000_000)
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "search_debounce_finished",
                        phaseStart: debounceStart
                    )
                }

                SearchPerformanceLogger.mark(searchPerformanceRun, "database_search_started")
                let diagnosticsSink = SearchPerformanceLogger.coreDiagnosticsSink(for: searchPerformanceRun)
                let pageLoad = try await Task.detached(priority: .userInitiated) {
                    let databaseSearchStart = SearchPerformanceLogger.now()
                    let page = try database.searchVisiblePage(
                        trimmedQuery,
                        limit: pageSize,
                        cursor: cursor,
                        under: folders,
                        diagnostics: diagnosticsSink
                    )
                    let databaseSearchMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(
                        since: databaseSearchStart
                    )
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "database_search_returned",
                        phaseStart: databaseSearchStart,
                        resultCount: page.results.count,
                        totalCount: page.totalCount,
                        fileSummaryCount: page.fileSummaries.count
                    )
                    return SearchPageLoad(
                        page: page,
                        databaseSearchMilliseconds: databaseSearchMilliseconds
                    )
                }.value
                let page = pageLoad.page
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "database_page_received_on_main",
                    resultCount: page.results.count,
                    totalCount: page.totalCount,
                    fileSummaryCount: page.fileSummaries.count
                )

                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled_after_database")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_cancelled_after_database",
                        page: page,
                        databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                let stateAssignStart = SearchPerformanceLogger.now()
                if appending {
                    appendGlobalSearchResults(page.results)
                    loadedGlobalSearchResultCount = max(
                        loadedGlobalSearchResultCount,
                        offset + page.results.count
                    )
                } else {
                    search.searchResults = page.results
                    loadedGlobalSearchResultCount = page.results.count
                }
                let shouldPreserveExactMetadata = appending && search.searchCountState == .exact
                if shouldPreserveExactMetadata && page.countState != .exact {
                    search.searchKnownResultCount = max(search.searchKnownResultCount, page.knownResultCount)
                    search.searchKnownFileCount = max(search.searchKnownFileCount, page.knownFileCount)
                } else {
                    search.searchResultTotalCount = page.totalCount
                    search.searchFileSummaries = page.fileSummaries
                    search.searchCountState = page.countState
                    search.searchKnownResultCount = page.knownResultCount
                    search.searchKnownFileCount = page.knownFileCount
                }
                search.hasMoreSearchResults = page.hasMore
                nextGlobalSearchCursor = page.nextCursor
                let stateAssignMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: stateAssignStart)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_state_assigned",
                    phaseStart: stateAssignStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count
                )

                let rebuildStart = SearchPerformanceLogger.now()
                rebuildSearchResultGroups()
                let groupRebuildMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: rebuildStart)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_groups_rebuilt",
                    phaseStart: rebuildStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount
                )
                prepareSearchPerformanceVisibility(
                    for: searchPerformanceRun,
                    resultsAwaitingFirstAppearance: page.results
                )

                let completionStart = SearchPerformanceLogger.now()
                let pageCompletesSearch = page.countState == .exact || shouldPreserveExactMetadata
                if pageCompletesSearch {
                    search.searchStatus = .completed
                } else {
                    search.searchStatus = .searching
                }
                let statusCompletionMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: completionStart)
                let logPageHasExactCounts = page.countState == .exact
                let statusText = logPageHasExactCounts ? "completed" : "searching"
                let eventName = logPageHasExactCounts ? "search_status_completed" : "search_visible_page_loaded"
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    eventName,
                    phaseStart: completionStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: statusText
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: eventName,
                    page: page,
                    databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                    stateAssignMilliseconds: stateAssignMilliseconds,
                    groupRebuildMilliseconds: groupRebuildMilliseconds,
                    statusCompletionMilliseconds: statusCompletionMilliseconds,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: statusText
                )
                if !appending && !pageCompletesSearch {
                    startSearchExactCompletion(
                        query: trimmedQuery,
                        folders: folders,
                        run: searchPerformanceRun
                    )
                }
                if page.results.isEmpty {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_no_result_rows_to_render")
                    clearSearchPerformanceRunIfActive(searchPerformanceRun)
                }
            } catch is CancellationError {
                SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled")
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_cancelled",
                    page: nil,
                    status: "cancelled"
                )
                return
            } catch {
                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled_after_error")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_cancelled_after_error",
                        page: nil,
                        status: "cancelled"
                    )
                    return
                }

                if !appending {
                    let resetStart = SearchPerformanceLogger.now()
                    resetSearchResultLoadingState()
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "search_state_reset_after_error",
                        phaseStart: resetStart,
                        groupCount: search.searchResultGroups.count,
                        renderedRowCount: search.renderedSearchResultCount
                    )
                }
                search.hasMoreSearchResults = false
                let message = Self.errorMessage(for: error)
                search.searchStatus = .failed(message)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_failed",
                    status: "failed",
                    error: message
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_failed",
                    page: nil,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: "failed",
                    error: message
                )
                clearSearchPerformanceRunIfActive(searchPerformanceRun)
            }
        }
    }

    private func applySearchCountProgress(
        _ progress: SubtitleSearchProgressSnapshot,
        query trimmedQuery: String,
        folderPaths: [String],
        run searchPerformanceRun: SearchPerformanceRun?
    ) {
        guard progress.countState == .exactProgress,
              search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
              indexing.selectedFolders.map(\.path) == folderPaths,
              search.searchCountState != .exact,
              progress.knownResultCount >= search.searchKnownResultCount,
              progress.knownFileCount >= search.searchKnownFileCount
        else {
            return
        }

        let now = SearchPerformanceLogger.now()
        if lastSearchCountProgressUpdate != 0,
           now - lastSearchCountProgressUpdate < Self.searchCountProgressMinimumIntervalNanoseconds {
            return
        }
        lastSearchCountProgressUpdate = now

        search.searchResultTotalCount = progress.knownResultCount
        search.searchFileSummaries = progress.fileSummaries
        search.searchCountState = progress.countState
        search.searchKnownResultCount = progress.knownResultCount
        search.searchKnownFileCount = progress.knownFileCount
        if loadedGlobalSearchResultCount < search.searchResultTotalCount {
            search.hasMoreSearchResults = true
            nextGlobalSearchCursor = nextGlobalSearchCursor
                ?? SubtitleSearchCursor(offset: loadedGlobalSearchResultCount)
        }
        rebuildSearchResultGroups()

        SearchPerformanceLogger.mark(
            searchPerformanceRun,
            "search_count_progress",
            resultCount: search.searchResults.count,
            totalCount: search.searchResultTotalCount,
            fileSummaryCount: search.searchFileSummaries.count,
            groupCount: search.searchResultGroups.count,
            renderedRowCount: search.renderedSearchResultCount,
            status: "searching"
        )
        SearchPerformanceLogger.writeE2ECountProgress(
            searchPerformanceRun,
            progress: progress,
            resultCount: search.searchResults.count,
            groupCount: search.searchResultGroups.count,
            renderedRowCount: search.renderedSearchResultCount
        )
    }

    private func startSearchExactCompletion(
        query trimmedQuery: String,
        folders: [URL],
        run searchPerformanceRun: SearchPerformanceRun?
    ) {
        searchExactCompletionTask?.cancel()

        guard let database = subtitleDatabase else {
            return
        }

        let pageSize = Self.searchPageSize
        let folderPaths = folders.map(\.path)
        let progressSink: SubtitleSearchProgressSink = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.applySearchCountProgress(
                    snapshot,
                    query: trimmedQuery,
                    folderPaths: folderPaths,
                    run: searchPerformanceRun
                )
            }
        }
        searchExactCompletionTask = Task {
            do {
                SearchPerformanceLogger.mark(searchPerformanceRun, "database_exact_completion_started")
                let diagnosticsSink = SearchPerformanceLogger.coreDiagnosticsSink(for: searchPerformanceRun)
                let pageLoad = try await Task.detached(priority: .utility) {
                    let databaseSearchStart = SearchPerformanceLogger.now()
                    let page = try database.searchPage(
                        trimmedQuery,
                        limit: pageSize,
                        cursor: .start,
                        under: folders,
                        diagnostics: diagnosticsSink,
                        progress: progressSink
                    )
                    let databaseSearchMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(
                        since: databaseSearchStart
                    )
                    return SearchPageLoad(
                        page: page,
                        databaseSearchMilliseconds: databaseSearchMilliseconds
                    )
                }.value
                let page = pageLoad.page

                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_cancelled")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_exact_completion_cancelled",
                        page: page,
                        databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                guard search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folderPaths
                else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_stale")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_exact_completion_stale",
                        page: page,
                        databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                let stateAssignStart = SearchPerformanceLogger.now()
                search.searchResultTotalCount = page.totalCount
                search.searchFileSummaries = page.fileSummaries
                search.searchCountState = page.countState
                search.searchKnownResultCount = page.knownResultCount
                search.searchKnownFileCount = page.knownFileCount
                search.hasMoreSearchResults = loadedGlobalSearchResultCount < page.totalCount
                nextGlobalSearchCursor = search.hasMoreSearchResults
                    ? (nextGlobalSearchCursor ?? SubtitleSearchCursor(offset: loadedGlobalSearchResultCount))
                    : nil
                let stateAssignMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: stateAssignStart)

                let rebuildStart = SearchPerformanceLogger.now()
                rebuildSearchResultGroups()
                let groupRebuildMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: rebuildStart)

                let completionStart = SearchPerformanceLogger.now()
                search.searchStatus = .completed
                searchExactCompletionTask = nil
                let statusCompletionMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: completionStart)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_status_completed",
                    phaseStart: completionStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: "completed"
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_status_completed",
                    page: page,
                    databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                    stateAssignMilliseconds: stateAssignMilliseconds,
                    groupRebuildMilliseconds: groupRebuildMilliseconds,
                    statusCompletionMilliseconds: statusCompletionMilliseconds,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: "completed"
                )
            } catch is CancellationError {
                SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_cancelled")
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_exact_completion_cancelled",
                    page: nil,
                    status: "cancelled"
                )
                return
            } catch {
                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_cancelled_after_error")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_exact_completion_cancelled_after_error",
                        page: nil,
                        status: "cancelled"
                    )
                    return
                }

                guard search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folderPaths
                else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_error_stale")
                    return
                }

                let message = Self.errorMessage(for: error)
                search.searchStatus = .failed(message)
                searchExactCompletionTask = nil
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_exact_completion_failed",
                    status: "failed",
                    error: message
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_exact_completion_failed",
                    page: nil,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: "failed",
                    error: message
                )
            }
        }
    }

    func markSearchResultVisible(_ result: SubtitleSearchResult) {
        guard let activeSearchPerformanceRun,
              pendingSearchVisibleEntryIDs.contains(result.entryID)
        else {
            return
        }

        pendingSearchVisibleEntryIDs = []
        SearchPerformanceLogger.mark(
            activeSearchPerformanceRun,
            "first_result_row_appeared",
            resultCount: search.searchResults.count,
            totalCount: search.searchResultTotalCount,
            fileSummaryCount: search.searchFileSummaries.count,
            groupCount: search.searchResultGroups.count,
            renderedRowCount: search.renderedSearchResultCount,
            entryID: result.entryID
        )
        SearchPerformanceLogger.writeE2EFirstVisible(
            activeSearchPerformanceRun,
            result: result,
            resultCount: search.searchResults.count,
            countState: search.searchCountState,
            knownResultCount: search.searchKnownResultCount,
            knownFileCount: search.searchKnownFileCount,
            totalCount: search.searchResultTotalCount,
            fileSummaryCount: search.searchFileSummaries.count,
            groupCount: search.searchResultGroups.count,
            renderedRowCount: search.renderedSearchResultCount
        )
        clearSearchPerformanceRunIfActive(activeSearchPerformanceRun)
    }

    private func prepareSearchPerformanceVisibility(
        for run: SearchPerformanceRun?,
        resultsAwaitingFirstAppearance results: [SubtitleSearchResult]
    ) {
        guard let run, activeSearchPerformanceRun?.id == run.id else {
            return
        }

        pendingSearchVisibleEntryIDs = Set(results.map(\.entryID))
    }

    private func clearSearchPerformanceRunIfActive(_ run: SearchPerformanceRun?) {
        guard let run, activeSearchPerformanceRun?.id == run.id else {
            return
        }

        activeSearchPerformanceRun = nil
        pendingSearchVisibleEntryIDs = []
    }

    // Capture the return target only on the transition into the video page so a
    // mid-session source switch keeps the original originating mode.
    private func rememberPlaybackOriginatingPanelModeIfEntering() {
        guard !playback.isPlaybackSurfaceExpanded else {
            return
        }
        playbackOriginatingPanelMode = workbenchLayout.panelMode
    }

    func openSearchResult(_ result: SubtitleSearchResult) {
        UIInvalidationProbe.mark(
            "ACTION UI.SearchResult.opened",
            details: "time=\(String(format: "%.2f", Double(result.startMilliseconds) / 1000.0))"
        )
        rememberPlaybackOriginatingPanelModeIfEntering()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        workbenchLayout.selectPanelMode(.search)
        search.selectedSearchResult = result
        shiori.selectedShiori = nil
        library.selectedLibraryVideo = nil
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            play(result)
        }
    }

    /// Seeks the current playback to an absolute timestamp through the shared
    /// playback command model. Used by the overlay-panel Subtitles rows. It
    /// must not touch the native render/seek core; `PlaybackViewModel.seek`
    /// already owns that dispatch.
    func seekCurrentPlayback(toMilliseconds milliseconds: Int) {
        guard let playbackViewModel = playback.playbackViewModel else {
            return
        }

        playbackViewModel.seek(to: Double(max(0, milliseconds)) / 1_000)
    }

    func openLibraryVideo(_ video: LibraryVideo) {
        UIInvalidationProbe.mark(
            "ACTION UI.LibraryVideo.opened",
            details: "duration=\(video.duration.map { String(format: "%.2f", $0) } ?? "unknown")"
        )
        rememberPlaybackOriginatingPanelModeIfEntering()
        if case .library = activePlaybackSource {
            saveCurrentLibraryPlaybackHistory()
        }
        library.selectedLibraryVideo = video
        search.selectedSearchResult = nil
        shiori.selectedShiori = nil
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            play(video)
        }
    }

    func openShiori(_ shiori: Shiori) {
        UIInvalidationProbe.mark(
            "ACTION UI.Shiori.opened",
            details: "time=\(String(format: "%.2f", Double(shiori.startMilliseconds) / 1000.0))"
        )
        rememberPlaybackOriginatingPanelModeIfEntering()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        self.shiori.selectedShiori = shiori
        search.selectedSearchResult = nil
        library.selectedLibraryVideo = nil
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            play(shiori)
        }
    }

    func revealCurrentVideoFile() {
        guard let currentPlaybackVideoPath else {
            return
        }

        revealFile(atPath: currentPlaybackVideoPath)
    }

    func revealCurrentSubtitleFile() {
        guard let currentPlaybackSubtitlePath else {
            return
        }

        revealFile(atPath: currentPlaybackSubtitlePath)
    }

    func play(_ result: SubtitleSearchResult) {
        ensurePlayerInitialized()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        playback.playbackStatus = .opening
        let subtitleCues = playbackSubtitleCues(for: result)
        playback.playbackViewModel?.setSubtitleCues(
            subtitleCues,
            currentTimeMilliseconds: result.startMilliseconds
        )

        do {
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: result.videoPath),
                startMilliseconds: result.startMilliseconds,
                subtitleSource: playbackSubtitleSource(for: result)
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
            refreshSearchNavigationSnapshot()
        } catch {
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func play(_ video: LibraryVideo) {
        ensurePlayerInitialized()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .none
        playback.playbackStatus = .opening
        let startMilliseconds = libraryResumePositionMilliseconds(for: video)
        let subtitleCues = playbackSubtitleCues(
            forSubtitleFile: URL(fileURLWithPath: video.subtitlePath),
            format: video.subtitleFormat,
            fallbackStartMilliseconds: startMilliseconds,
            fallbackEndMilliseconds: startMilliseconds,
            fallbackContent: ""
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
            startLibraryPlaybackHistoryTracking(videoPath: video.videoPath)
        } catch {
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func play(_ shiori: Shiori) {
        ensurePlayerInitialized()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        playback.playbackStatus = .opening
        let subtitleCues = playbackSubtitleCues(for: shiori)
        playback.playbackViewModel?.setSubtitleCues(
            subtitleCues,
            currentTimeMilliseconds: shiori.startMilliseconds
        )

        do {
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: shiori.videoPath),
                startMilliseconds: shiori.startMilliseconds,
                subtitleSource: playbackSubtitleSource(for: shiori)
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
        } catch {
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func pausePlayback() {
        do {
            try player?.setPaused(true)
            if hasPlaybackSelection {
                playback.playbackStatus = .paused
            }
            saveCurrentLibraryPlaybackHistory()
        } catch {
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func resumePlayback() {
        do {
            try player?.setPaused(false)
            if hasPlaybackSelection {
                playback.playbackStatus = .playing
            }
        } catch {
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func togglePlayback() {
        switch playback.playbackStatus {
        case .playing, .paused:
            if playback.playbackViewModel?.isPlaying == true {
                pausePlayback()
            } else {
                resumePlayback()
            }
        case .idle:
            if let selectedSearchResult = search.selectedSearchResult {
                play(selectedSearchResult)
            } else if let selectedLibraryVideo = library.selectedLibraryVideo {
                play(selectedLibraryVideo)
            } else if let selectedShiori = shiori.selectedShiori {
                play(selectedShiori)
            }
        case .opening, .failed:
            break
        }
    }

    func togglePlaybackFromUser() {
        let willPlay = !(playback.playbackViewModel?.isPlaying ?? false)
        togglePlayback()
        playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: willPlay)
    }

    func refreshSearchNavigationSnapshot() {
        loadSearchNavigationSnapshot(opening: nil)
    }

    func openAdjacentSearchResult(_ direction: SearchResultNavigationDirection) {
        loadSearchNavigationSnapshot(opening: direction)
    }

    func refreshCurrentSubtitleEntries() {
        currentSubtitleEntriesTask?.cancel()

        guard let currentPlaybackSubtitlePath,
              let database = subtitleDatabase
        else {
            applyCurrentSubtitleEntries([])
            return
        }

        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        currentSubtitleEntriesTask = Task { [weak self] in
            do {
                let entries = try await Task.detached(priority: .userInitiated) {
                    try database.entries(forSubtitleFile: subtitleFile)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                self?.applyCurrentSubtitleEntries(entries)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load current subtitle entries: \(error)")
                self?.applyCurrentSubtitleEntries([])
            }
        }
    }

    @discardableResult
    func copyCurrentSubtitleToClipboard() -> Bool {
        guard let currentPlaybackSubtitlePath, let playbackViewModel = playback.playbackViewModel else {
            playback.playbackViewModel?.showSubtitleCopyFeedback(copied: false)
            return false
        }

        let milliseconds = max(0, Int((playbackViewModel.currentTime * 1_000).rounded(.down)))

        guard let database = subtitleDatabase else {
            playbackViewModel.showSubtitleCopyFeedback(copied: false)
            return false
        }

        do {
            guard let selection = try database.cueTextSelection(
                forSubtitleFile: URL(fileURLWithPath: currentPlaybackSubtitlePath),
                atMilliseconds: milliseconds
            ), !selection.text.isEmpty else {
                playbackViewModel.showSubtitleCopyFeedback(copied: false)
                return false
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let copied = pasteboard.setString(selection.text, forType: .string)
            playbackViewModel.showSubtitleCopyFeedback(copied: copied)
            return copied
        } catch {
            print("Failed to copy current subtitle: \(error)")
            playbackViewModel.showSubtitleCopyFeedback(copied: false)
            return false
        }
    }

    @discardableResult
    func toggleCurrentShiori() -> Bool {
        guard let currentPlaybackSubtitlePath,
              let currentPlaybackSubtitleFormat,
              let currentPlaybackVideoPath,
              let playbackViewModel = playback.playbackViewModel
        else {
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            return false
        }

        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        let videoFile = URL(fileURLWithPath: currentPlaybackVideoPath)
        let videoName = library.selectedLibraryVideo?.videoName
            ?? search.selectedSearchResult?.videoName
            ?? shiori.selectedShiori?.videoName
            ?? videoFile.lastPathComponent
        let milliseconds = max(0, Int((playbackViewModel.currentTime * 1_000).rounded(.down)))

        guard let database = subtitleDatabase else {
            playbackViewModel.showShioriFeedback(.unavailable)
            return false
        }

        do {
            guard let selection = try database.cueTextSelection(
                forSubtitleFile: subtitleFile,
                atMilliseconds: milliseconds
            ), !selection.text.isEmpty else {
                playbackViewModel.showShioriFeedback(.unavailable)
                return false
            }

            if try database.shiori(
                subtitleFile: subtitleFile,
                startMilliseconds: selection.startMilliseconds,
                endMilliseconds: selection.endMilliseconds
            ) != nil {
                guard confirmShioriRemoval() else {
                    return false
                }

                try database.removeShiori(
                    subtitleFile: subtitleFile,
                    startMilliseconds: selection.startMilliseconds,
                    endMilliseconds: selection.endMilliseconds
                )
                applyShioris(try database.shioris())
                playbackViewModel.showShioriFeedback(.removed)
                return true
            }

            _ = try database.upsertShiori(
                subtitleFile: subtitleFile,
                subtitleFormat: currentPlaybackSubtitleFormat,
                videoFile: videoFile,
                videoName: videoName,
                selection: selection
            )
            applyShioris(try database.shioris())
            playbackViewModel.showShioriFeedback(.saved)
            return true
        } catch {
            print("Failed to toggle Shiori: \(error)")
            playbackViewModel.showShioriFeedback(.unavailable)
            return false
        }
    }

    private func confirmShioriRemoval() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove Shiori?"
        alert.informativeText = "This subtitle is already saved. Remove it from Shiori?"
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func handlePlaybackKeyDown(
        keyCode: UInt16,
        modifierFlagsRawValue: UInt
    ) -> Bool {
        let isPlaybackInterfaceVisible = currentPlaybackVideoPath != nil || playbackFullscreenManager.isFullscreen

        guard isPlaybackInterfaceVisible else {
            return false
        }

        guard currentPlaybackVideoPath != nil, let viewModel = playback.playbackViewModel else {
            return false
        }

        guard !Self.isEditableTextInputFocused() else {
            return false
        }

        let modifierFlags = NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
        let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]

        guard modifierFlags.intersection(disallowedModifiers).isEmpty else {
            return false
        }

        let hasShift = modifierFlags.contains(.shift)

        switch keyCode {
        case 0:
            openAdjacentSearchResult(.previous)
            return true
        case 2:
            openAdjacentSearchResult(.next)
            return true
        case 12:
            copyCurrentSubtitleToClipboard()
            return true
        case 1:
            toggleCurrentShiori()
            return true
        case 8:
            viewModel.toggleSubtitles()
            return true
        case 3:
            togglePlaybackFullscreenFromUser()
            return true
        case 49:
            togglePlaybackFromUser()
            return true
        case 123:
            viewModel.seekRelative(by: -5)
            return true
        case 124:
            viewModel.seekRelative(by: 5)
            return true
        case 126:
            viewModel.adjustVolume(by: 5)
            return true
        case 125:
            viewModel.adjustVolume(by: -5)
            return true
        case 43 where hasShift:
            viewModel.adjustSpeed(by: -0.25)
            return true
        case 47 where hasShift:
            viewModel.adjustSpeed(by: 0.25)
            return true
        default:
            return false
        }
    }

    func stopPlayback() {
        do {
            saveCurrentLibraryPlaybackHistory()
            stopLibraryPlaybackHistoryTracking()
            playbackFullscreenManager.exitFullscreen()
            try player?.stop()
            playback.playbackViewModel?.clearSubtitleCues()
            activePlaybackSource = .none
            search.selectedSearchResult = nil
            library.selectedLibraryVideo = nil
            shiori.selectedShiori = nil
            playback.isPlaybackSurfaceExpanded = false
            if let originatingMode = playbackOriginatingPanelMode {
                workbenchLayout.selectPanelMode(originatingMode)
                playbackOriginatingPanelMode = nil
            }
            playback.playbackStatus = .idle
        } catch {
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func saveCurrentLibraryPlaybackHistory() {
        saveCurrentLibraryPlaybackHistory(waitUntilFinished: false)
    }

    func saveCurrentLibraryPlaybackHistorySynchronously() {
        saveCurrentLibraryPlaybackHistory(waitUntilFinished: true)
    }

    func toggleShioriGroup(_ subtitlePath: String) {
        UIInvalidationProbe.mark(
            "ACTION UI.ShioriGroup.toggled",
            details: "collapsedBefore=\(shiori.collapsedShioriGroupPaths.contains(subtitlePath))"
        )
        if shiori.collapsedShioriGroupPaths.contains(subtitlePath) {
            shiori.collapsedShioriGroupPaths.remove(subtitlePath)
        } else {
            shiori.collapsedShioriGroupPaths.insert(subtitlePath)
        }
        rebuildShioriFileGroups()
    }

    func collapseAllShioriGroups() {
        let groupPaths = Set(shiori.shioriFileGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return
        }

        let collapsedPaths = shiori.collapsedShioriGroupPaths.union(groupPaths)
        guard collapsedPaths != shiori.collapsedShioriGroupPaths else {
            return
        }

        UIInvalidationProbe.mark(
            "ACTION UI.Shiori.collapseAll",
            details: "groups=\(groupPaths.count)"
        )
        shiori.collapsedShioriGroupPaths = collapsedPaths
        rebuildShioriFileGroups()
    }

    private func saveCurrentLibraryPlaybackHistory(waitUntilFinished: Bool) {
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

    private static func isEditableTextInputFocused() -> Bool {
        guard let firstResponder = NSApplication.shared.keyWindow?.firstResponder else {
            return false
        }

        if let textView = firstResponder as? NSTextView {
            return textView.isEditable
        }

        if let textField = firstResponder as? NSTextField {
            return textField.isEditable
        }

        if let view = firstResponder as? NSView {
            return view.ancestorOrSelfContainsEditableTextInput
        }

        return false
    }

    private func refreshCurrentSearch(clearExistingResults: Bool = false) {
        guard !search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if clearExistingResults {
            search.searchResults = []
            search.searchResultTotalCount = 0
            search.searchFileSummaries = []
            search.expandedSearchResultGroupRowsByPath = [:]
            search.searchCountState = .exact
            search.searchKnownResultCount = 0
            search.searchKnownFileCount = 0
            search.hasMoreSearchResults = false
            loadedGlobalSearchResultCount = 0
            lastSearchCountProgressUpdate = 0
            nextGlobalSearchCursor = nil
            rebuildSearchResultGroups()
        }

        updateSearchQuery(search.searchQuery)
    }

    private func loadSearchNavigationSnapshot(opening direction: SearchResultNavigationDirection?) {
        searchNavigationTask?.cancel()

        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty,
              !indexing.selectedFolders.isEmpty,
              let database = subtitleDatabase
        else {
            search.searchNavigationSnapshot = nil
            search.searchNavigationResultGroups = []
            if let direction {
                playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
            }
            return
        }

        let folders = indexing.selectedFolders
        let anchor = currentSearchNavigationAnchor()
        let panelRadius = Self.searchNavigationPanelRadius
        searchNavigationTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.searchNavigationSnapshot(
                        trimmedQuery,
                        under: folders,
                        anchor: anchor,
                        radius: panelRadius
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                guard let self else {
                    return
                }

                self.applySearchNavigationSnapshot(snapshot)
                let target: SubtitleSearchResult? = switch direction {
                case .previous:
                    snapshot.previous
                case .next:
                    snapshot.next
                case nil:
                    nil
                }

                if let target, let direction {
                    self.playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: true)
                    self.openSearchResult(target)
                } else if let direction {
                    self.playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load Search navigation snapshot: \(error)")
                self?.search.searchNavigationSnapshot = nil
                self?.search.searchNavigationResultGroups = []
            }
        }
    }

    private func currentSearchNavigationAnchor() -> SearchNavigationAnchor {
        let milliseconds = max(
            0,
            Int(((playback.playbackViewModel?.currentTime ?? 0) * 1_000).rounded(.down))
        )

        return SearchNavigationAnchor(
            selectedEntryID: search.selectedSearchResult?.entryID,
            videoPath: currentPlaybackVideoPath,
            subtitlePath: currentPlaybackSubtitlePath,
            currentMilliseconds: milliseconds
        )
    }

    private func applySearchNavigationSnapshot(_ snapshot: SearchNavigationSnapshot) {
        search.searchNavigationSnapshot = snapshot
        let paths = Set(snapshot.neighborhood.map(\.subtitlePath))
        let summaries = search.searchFileSummaries.filter { paths.contains($0.subtitlePath) }
        search.searchNavigationResultGroups = Self.makeSearchResultGroups(
            results: snapshot.neighborhood,
            fileSummaries: summaries,
            expandedRowsByPath: [:],
            collapsedGroupPaths: [],
            includesSummaryOnlyGroups: false
        )
    }

    private func libraryResumePositionMilliseconds(for video: LibraryVideo) -> Int {
        guard let database = subtitleDatabase else {
            return 0
        }
        do {
            return try database.libraryPlaybackHistory(
                forVideoFile: URL(fileURLWithPath: video.videoPath)
            )?.positionMilliseconds ?? 0
        } catch {
            print("Failed to load Library playback history: \(error)")
            return 0
        }
    }

    private func openAdjacentLibraryVideo(offset: Int) {
        guard let target = libraryAdjacentVideo(offset: offset) else {
            return
        }

        openLibraryVideo(target)
    }

    private func libraryAdjacentVideo(offset: Int) -> LibraryVideo? {
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

    private func startLibraryPlaybackHistoryTracking(videoPath: String) {
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

    private func stopLibraryPlaybackHistoryTracking() {
        libraryPlaybackHistoryTask?.cancel()
        libraryPlaybackHistoryTask = nil
    }

    private func clearSearchAndPlaybackState(under folder: URL) {
        search.searchResults.removeAll { Self.path($0.subtitlePath, isUnder: folder) }
        search.searchFileSummaries.removeAll { Self.path($0.subtitlePath, isUnder: folder) }
        search.searchResultTotalCount = search.searchFileSummaries.reduce(0) { $0 + $1.matchCount }
        search.searchCountState = .exact
        search.searchKnownResultCount = search.searchResultTotalCount
        search.searchKnownFileCount = search.searchFileSummaries.count
        loadedGlobalSearchResultCount = search.searchResults.count
        nextGlobalSearchCursor = nil
        search.hasMoreSearchResults = false
        search.collapsedSearchResultGroupPaths = search.collapsedSearchResultGroupPaths.filter { !Self.path($0, isUnder: folder) }
        removeLibraryPresentation(under: folder)
        search.expandedSearchResultGroupRowsByPath = search.expandedSearchResultGroupRowsByPath.filter { path, _ in
            !Self.path(path, isUnder: folder)
        }
        rebuildSearchResultGroups()
        let groupTaskPaths = searchResultGroupTasks.keys.filter { Self.path($0, isUnder: folder) }
        for path in groupTaskPaths {
            searchResultGroupTasks[path]?.cancel()
            searchResultGroupTasks.removeValue(forKey: path)
        }

        let selectedSearchResultIsUnderFolder = search.selectedSearchResult.map {
            Self.path($0.subtitlePath, isUnder: folder)
        } ?? false
        let selectedLibraryVideoIsUnderFolder = library.selectedLibraryVideo.map {
            Self.path($0.videoPath, isUnder: folder)
        } ?? false
        let selectedShioriIsUnderFolder = shiori.selectedShiori.map {
            Self.path($0.videoPath, isUnder: folder)
        } ?? false

        if selectedSearchResultIsUnderFolder || selectedLibraryVideoIsUnderFolder || selectedShioriIsUnderFolder {
            search.selectedSearchResult = nil
            library.selectedLibraryVideo = nil
            shiori.selectedShiori = nil
            stopPlayback()
        }
    }

    private static func path(_ path: String, isUnder folder: URL) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return folderPathPrefixes(for: folder).contains { prefix in
            standardizedPath.hasPrefix(prefix)
        }
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = normalizedFolderPath(folder.standardizedFileURL.path)
        if !path.hasSuffix("/") {
            path.append("/")
        }

        var prefixes = Set([path])
        if path.hasPrefix("/var/") {
            prefixes.insert("/private" + path)
        } else if path.hasPrefix("/private/var/") {
            prefixes.insert(String(path.dropFirst("/private".count)))
        }

        return prefixes.sorted()
    }

    private static func normalizedFolderPath(_ path: String) -> String {
        var path = path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private static func searchResultGroupPathSort(_ lhs: String, _ rhs: String) -> Bool {
        let lhsDisplayTitle = SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: lhs)
        let rhsDisplayTitle = SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: rhs)
        let displayTitleComparison = SubtitleDisplayTitleResolver.compareDisplayTitles(lhsDisplayTitle, rhsDisplayTitle)
        if displayTitleComparison != .orderedSame {
            return displayTitleComparison == .orderedAscending
        }

        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private static func searchResultSort(_ lhs: SubtitleSearchResult, _ rhs: SubtitleSearchResult) -> Bool {
        if lhs.startMilliseconds != rhs.startMilliseconds {
            return lhs.startMilliseconds < rhs.startMilliseconds
        }

        if lhs.endMilliseconds != rhs.endMilliseconds {
            return lhs.endMilliseconds < rhs.endMilliseconds
        }

        return lhs.entryID < rhs.entryID
    }

    private static func shioriSort(_ lhs: Shiori, _ rhs: Shiori) -> Bool {
        if lhs.subtitlePath != rhs.subtitlePath {
            return searchResultGroupPathSort(lhs.subtitlePath, rhs.subtitlePath)
        }

        if lhs.startMilliseconds != rhs.startMilliseconds {
            return lhs.startMilliseconds < rhs.startMilliseconds
        }

        if lhs.endMilliseconds != rhs.endMilliseconds {
            return lhs.endMilliseconds < rhs.endMilliseconds
        }

        return lhs.id < rhs.id
    }

    private func revealInitialSearchResultGroupPage(for subtitlePath: String) {
        let currentRows = loadedRowsForSearchResultGroup(subtitlePath)
        if !currentRows.isEmpty {
            search.expandedSearchResultGroupRowsByPath[subtitlePath] = Array(currentRows.prefix(Self.searchPageSize))
            rebuildSearchResultGroups()
        }

        loadSearchResultGroupPage(for: subtitlePath, offset: 0)
    }

    private func loadMoreSearchResultGroupRowsIfNeeded(currentResult result: SubtitleSearchResult) {
        let subtitlePath = result.subtitlePath
        guard searchResultGroupTasks[subtitlePath] == nil else {
            return
        }

        let currentRows = loadedRowsForSearchResultGroup(subtitlePath)
        guard let index = currentRows.firstIndex(where: { $0.entryID == result.entryID }),
              index >= currentRows.count - Self.searchPrefetchThreshold
        else {
            return
        }

        guard let totalCount = search.searchFileSummaries.first(where: { $0.subtitlePath == subtitlePath })?.matchCount,
              currentRows.count < totalCount
        else {
            return
        }

        loadSearchResultGroupPage(for: subtitlePath, offset: currentRows.count)
    }

    private func loadSearchResultGroupPage(for subtitlePath: String, offset: Int) {
        guard searchResultGroupTasks[subtitlePath] == nil else {
            return
        }

        let currentRows = loadedRowsForSearchResultGroup(subtitlePath)
        let rowsBefore = currentRows.count
        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !indexing.selectedFolders.isEmpty else {
            return
        }

        let folders = indexing.selectedFolders
        guard let database = subtitleDatabase else {
            return
        }
        let pageSize = Self.searchPageSize
        let subtitleDisplayTitle = search.searchFileSummaries
            .first(where: { $0.subtitlePath == subtitlePath })?
            .subtitleDisplayTitle
            ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: subtitlePath)
        let totalCount = search.searchFileSummaries
            .first(where: { $0.subtitlePath == subtitlePath })?
            .matchCount
        let loadMoreRun = SearchPerformanceLogger.startRun(
            query: trimmedQuery,
            queryLength: trimmedQuery.count,
            offset: offset,
            limit: pageSize,
            appending: true,
            debounce: false,
            folderPaths: folders.map(\.path),
            e2eLoggingEnabled: settings.searchE2ELoggingEnabled
        )
        searchResultGroupTasks[subtitlePath] = Task { [weak self] in
            do {
                let pageLoad = try await Task.detached(priority: .userInitiated) {
                    let databaseSearchStart = SearchPerformanceLogger.now()
                    let results = try database.search(
                        trimmedQuery,
                        limit: pageSize,
                        offset: offset,
                        under: folders,
                        inSubtitlePath: subtitlePath
                    )
                    let databaseSearchMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(
                        since: databaseSearchStart
                    )
                    return (results, databaseSearchMilliseconds)
                }.value
                let results = pageLoad.0
                let databaseSearchMilliseconds = pageLoad.1

                guard !Task.isCancelled else {
                    SearchPerformanceLogger.writeE2EFileLoadMore(
                        loadMoreRun,
                        subtitlePath: subtitlePath,
                        subtitleDisplayTitle: subtitleDisplayTitle,
                        rowsBefore: rowsBefore,
                        rowsAfter: nil,
                        returned: nil,
                        totalCount: totalCount,
                        databaseSearchMilliseconds: databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                guard let self,
                      self.search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      self.search.searchFileSummaries.contains(where: { $0.subtitlePath == subtitlePath })
                else {
                    SearchPerformanceLogger.writeE2EFileLoadMore(
                        loadMoreRun,
                        subtitlePath: subtitlePath,
                        subtitleDisplayTitle: subtitleDisplayTitle,
                        rowsBefore: rowsBefore,
                        rowsAfter: nil,
                        returned: results.count,
                        totalCount: totalCount,
                        databaseSearchMilliseconds: databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                let mergedResults: [SubtitleSearchResult]
                if offset == 0 {
                    mergedResults = results
                } else {
                    let existingEntryIDs = Set(currentRows.map(\.entryID))
                    mergedResults = (currentRows + results.filter { !existingEntryIDs.contains($0.entryID) })
                        .sorted(by: Self.searchResultSort)
                }
                self.search.expandedSearchResultGroupRowsByPath[subtitlePath] = mergedResults
                self.searchResultGroupTasks.removeValue(forKey: subtitlePath)
                self.rebuildSearchResultGroups()
                SearchPerformanceLogger.writeE2EFileLoadMore(
                    loadMoreRun,
                    subtitlePath: subtitlePath,
                    subtitleDisplayTitle: subtitleDisplayTitle,
                    rowsBefore: rowsBefore,
                    rowsAfter: mergedResults.count,
                    returned: results.count,
                    totalCount: totalCount,
                    databaseSearchMilliseconds: databaseSearchMilliseconds,
                    groupCount: self.search.searchResultGroups.count,
                    renderedRowCount: self.search.renderedSearchResultCount,
                    status: "completed"
                )
            } catch is CancellationError {
                SearchPerformanceLogger.writeE2EFileLoadMore(
                    loadMoreRun,
                    subtitlePath: subtitlePath,
                    subtitleDisplayTitle: subtitleDisplayTitle,
                    rowsBefore: rowsBefore,
                    rowsAfter: nil,
                    returned: nil,
                    totalCount: totalCount,
                    status: "cancelled"
                )
                return
            } catch {
                guard !Task.isCancelled else {
                    SearchPerformanceLogger.writeE2EFileLoadMore(
                        loadMoreRun,
                        subtitlePath: subtitlePath,
                        subtitleDisplayTitle: subtitleDisplayTitle,
                        rowsBefore: rowsBefore,
                        rowsAfter: nil,
                        returned: nil,
                        totalCount: totalCount,
                        status: "cancelled"
                    )
                    return
                }

                self?.searchResultGroupTasks.removeValue(forKey: subtitlePath)
                self?.search.searchStatus = .failed(Self.errorMessage(for: error))
                SearchPerformanceLogger.writeE2EFileLoadMore(
                    loadMoreRun,
                    subtitlePath: subtitlePath,
                    subtitleDisplayTitle: subtitleDisplayTitle,
                    rowsBefore: rowsBefore,
                    rowsAfter: nil,
                    returned: nil,
                    totalCount: totalCount,
                    status: "failed",
                    error: Self.errorMessage(for: error)
                )
            }
        }
    }

    private func loadedRowsForSearchResultGroup(_ subtitlePath: String) -> [SubtitleSearchResult] {
        let rows = search.expandedSearchResultGroupRowsByPath[subtitlePath]
            ?? search.searchResults.filter { $0.subtitlePath == subtitlePath }
        return rows.sorted(by: Self.searchResultSort)
    }

    private func searchResultGroupHasLoadedRows(_ subtitlePath: String) -> Bool {
        if search.expandedSearchResultGroupRowsByPath[subtitlePath]?.isEmpty == false {
            return true
        }

        return search.searchResults.contains { $0.subtitlePath == subtitlePath }
    }

    private func revealInitialGlobalSearchResultPage() {
        cancelSearchResultGroupTasks()
        search.expandedSearchResultGroupRowsByPath = [:]
        search.searchResults = Array(search.searchResults.prefix(Self.searchPageSize))
        loadedGlobalSearchResultCount = search.searchResults.count
        search.searchKnownResultCount = search.searchResultTotalCount
        search.searchKnownFileCount = search.searchFileSummaries.count
        search.hasMoreSearchResults = loadedGlobalSearchResultCount < search.searchResultTotalCount
        nextGlobalSearchCursor = search.hasMoreSearchResults
            ? SubtitleSearchCursor(offset: loadedGlobalSearchResultCount)
            : nil
        rebuildSearchResultGroups()
    }

    private func appendGlobalSearchResults(_ results: [SubtitleSearchResult]) {
        let existingEntryIDs = Set(search.searchResults.map(\.entryID))
        search.searchResults.append(contentsOf: results.filter { !existingEntryIDs.contains($0.entryID) })
    }

    private func resetSearchResultLoadingState() {
        cancelSearchResultGroupTasks()
        searchExactCompletionTask?.cancel()
        searchExactCompletionTask = nil
        searchNavigationTask?.cancel()
        search.searchResults = []
        search.searchResultTotalCount = 0
        search.searchFileSummaries = []
        search.searchCountState = .exact
        search.searchKnownResultCount = 0
        search.searchKnownFileCount = 0
        search.hasMoreSearchResults = false
        lastSearchCountProgressUpdate = 0
        search.searchResultPresentationState = .initial
        search.collapsedSearchResultGroupPaths = []
        search.expandedSearchResultGroupRowsByPath = [:]
        loadedGlobalSearchResultCount = 0
        nextGlobalSearchCursor = nil
        search.searchNavigationSnapshot = nil
        search.searchNavigationResultGroups = []
        rebuildSearchResultGroups()
    }

    private func rebuildSearchResultGroups() {
        search.searchResultGroups = Self.makeSearchResultGroups(
            results: search.searchResults,
            fileSummaries: search.searchFileSummaries,
            expandedRowsByPath: search.expandedSearchResultGroupRowsByPath,
            collapsedGroupPaths: search.collapsedSearchResultGroupPaths,
            includesSummaryOnlyGroups: search.searchResultPresentationState == .collapsed
        )
        search.renderedSearchResultCount = search.searchResultGroups.reduce(0) { count, group in
            group.isCollapsed ? count : count + group.results.count
        }
        UIInvalidationProbe.count(
            "UI.SearchPresentation.rebuilt",
            details: "groups=\(search.searchResultGroups.count) rows=\(search.renderedSearchResultCount)"
        )
    }

    private func revealFile(atPath path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: path)
        ])
    }

    private func applyCurrentSubtitleEntries(_ entries: [SubtitleDatabaseEntry]) {
        playback.currentSubtitleEntries = entries
        playback.currentSubtitleEntryLookup = SubtitleActiveEntryLookup(entries: entries)
    }

    private func cancelSearchResultGroupTasks() {
        searchResultGroupTasks.values.forEach { $0.cancel() }
        searchResultGroupTasks = [:]
    }

    private func cancelStartupDatabaseTask() {
        startupDatabaseTask?.cancel()
        startupDatabaseTask = nil
    }

    private func cancelDatabaseReadTasksBeforeIndexing() {
        cancelStartupDatabaseTask()
        libraryTask?.cancel()
        libraryTask = nil
        searchTask?.cancel()
        searchTask = nil
        searchExactCompletionTask?.cancel()
        searchExactCompletionTask = nil
        searchNavigationTask?.cancel()
        searchNavigationTask = nil
        currentSubtitleEntriesTask?.cancel()
        currentSubtitleEntriesTask = nil
        indexing.searchFTSVocabularyDiagnosticsTask?.cancel()
        indexing.searchFTSVocabularyDiagnosticsTask = nil
        cancelSearchResultGroupTasks()

        if case .loading = library.libraryStatus {
            library.libraryStatus = library.libraryVideos.isEmpty ? .idle : .completed
        }
        if case .searching = search.searchStatus {
            search.searchStatus = .completed
        }
    }

    private func aggregate(
        _ result: SubtitleIndexingResult,
        into aggregateResult: inout SubtitleIndexingResult
    ) {
        aggregateResult.scannedSubtitleFiles += result.scannedSubtitleFiles
        aggregateResult.indexedSubtitleFiles += result.indexedSubtitleFiles
        aggregateResult.indexedSubtitleEntries += result.indexedSubtitleEntries
        aggregateResult.skippedUnchangedSubtitleFiles += result.skippedUnchangedSubtitleFiles
        aggregateResult.skippedMissingVideo += result.skippedMissingVideo
        aggregateResult.skippedUnreadableSubtitle += result.skippedUnreadableSubtitle
        aggregateResult.failedFiles.append(contentsOf: result.failedFiles)
    }

    private func playbackSubtitleCues(for result: SubtitleSearchResult) -> [PlaybackSubtitleCue] {
        playbackSubtitleCues(
            forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
            format: result.subtitleFormat,
            fallbackStartMilliseconds: result.startMilliseconds,
            fallbackEndMilliseconds: result.endMilliseconds,
            fallbackContent: result.content
        )
    }

    private func playbackSubtitleCues(for shiori: Shiori) -> [PlaybackSubtitleCue] {
        playbackSubtitleCues(
            forSubtitleFile: URL(fileURLWithPath: shiori.subtitlePath),
            format: shiori.subtitleFormat,
            fallbackStartMilliseconds: shiori.startMilliseconds,
            fallbackEndMilliseconds: shiori.endMilliseconds,
            fallbackContent: shiori.content
        )
    }

    private func playbackSubtitleCues(
        forSubtitleFile subtitleFile: URL,
        format: SubtitleFormat,
        fallbackStartMilliseconds: Int,
        fallbackEndMilliseconds: Int,
        fallbackContent: String
    ) -> [PlaybackSubtitleCue] {
        guard format == .srt else {
            return []
        }

        guard let database = subtitleDatabase else {
            return []
        }

        do {
            let entries = try database.entries(
                forSubtitleFile: subtitleFile
            )
            let cues = entries.map {
                PlaybackSubtitleCue(
                    startMilliseconds: $0.startMilliseconds,
                    endMilliseconds: $0.endMilliseconds,
                    text: $0.content
                )
            }

            if !cues.isEmpty {
                return cues
            }
        } catch {
            print("Failed to load playback subtitle track: \(error)")
        }

        guard !fallbackContent.isEmpty else {
            return []
        }

        return [
            PlaybackSubtitleCue(
                startMilliseconds: fallbackStartMilliseconds,
                endMilliseconds: fallbackEndMilliseconds,
                text: fallbackContent
            )
        ]
    }

    private func playbackSubtitleSource(for result: SubtitleSearchResult) -> PlaybackSubtitleSource? {
        guard result.subtitleFormat == .ass else {
            return nil
        }

        let subtitleURL = URL(fileURLWithPath: result.subtitlePath)
        let videoURL = URL(fileURLWithPath: result.videoPath)

        return PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            matchedVideoURL: videoURL,
            preparationTimeWindow: playbackSubtitleTimeWindow(for: result),
            renderCacheDatabaseURL: databaseURL
        )
    }

    private func playbackSubtitleSource(for shiori: Shiori) -> PlaybackSubtitleSource? {
        guard shiori.subtitleFormat == .ass else {
            return nil
        }

        let subtitleURL = URL(fileURLWithPath: shiori.subtitlePath)
        let videoURL = URL(fileURLWithPath: shiori.videoPath)

        return PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            matchedVideoURL: videoURL,
            preparationTimeWindow: playbackSubtitleTimeWindow(
                forSubtitleFile: subtitleURL,
                startingAtMilliseconds: shiori.startMilliseconds,
                fallbackEndMilliseconds: shiori.endMilliseconds
            ),
            renderCacheDatabaseURL: databaseURL
        )
    }

    private func playbackSubtitleSource(
        for video: LibraryVideo,
        startingAtMilliseconds startMilliseconds: Int
    ) -> PlaybackSubtitleSource? {
        guard video.subtitleFormat == .ass else {
            return nil
        }

        let subtitleURL = URL(fileURLWithPath: video.subtitlePath)
        let videoURL = URL(fileURLWithPath: video.videoPath)

        return PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            matchedVideoURL: videoURL,
            preparationTimeWindow: playbackSubtitleTimeWindow(
                forSubtitleFile: subtitleURL,
                startingAtMilliseconds: startMilliseconds,
                fallbackEndMilliseconds: startMilliseconds
            ),
            renderCacheDatabaseURL: databaseURL
        )
    }

    private func playbackSubtitleTimeWindow(for result: SubtitleSearchResult) -> PlaybackSubtitleTimeWindow {
        playbackSubtitleTimeWindow(
            forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
            startingAtMilliseconds: result.startMilliseconds,
            fallbackEndMilliseconds: result.endMilliseconds
        )
    }

    private func playbackSubtitleTimeWindow(
        forSubtitleFile subtitleFile: URL,
        startingAtMilliseconds startMilliseconds: Int,
        fallbackEndMilliseconds: Int
    ) -> PlaybackSubtitleTimeWindow {
        let fallback = PlaybackSubtitleTimeWindow(
            startMilliseconds: startMilliseconds,
            endMilliseconds: fallbackEndMilliseconds
        )

        guard let database = subtitleDatabase else {
            return fallback
        }

        do {
            let timings = try database.cueTimings(
                forSubtitleFile: subtitleFile,
                startingAtMilliseconds: startMilliseconds,
                limit: Self.assSubtitlePreparationCueLimit
            )

            guard !timings.isEmpty else {
                return fallback
            }

            let startMilliseconds = min(
                fallback.startMilliseconds,
                timings.map(\.startMilliseconds).min() ?? fallback.startMilliseconds
            )
            let endMilliseconds = max(
                fallback.endMilliseconds,
                timings.map(\.endMilliseconds).max() ?? fallback.endMilliseconds
            )

            return PlaybackSubtitleTimeWindow(
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds
            )
        } catch {
            print("Failed to load ASS subtitle preparation window: \(error)")
            return fallback
        }
    }

    private static func loadPlaybackVolume(from userDefaults: UserDefaults) -> Double {
        clampedPlaybackVolume(
            userDefaults.double(forKey: playbackVolumeKey),
            fallback: 100
        )
    }

    private static func loadPlaybackLastNonzeroVolume(from userDefaults: UserDefaults) -> Double {
        let volume = clampedPlaybackVolume(
            userDefaults.double(forKey: playbackLastNonzeroVolumeKey),
            fallback: 100
        )

        return volume > 0 ? volume : 100
    }

    private static func loadPlaybackSpeed(from userDefaults: UserDefaults) -> Double {
        let speed = userDefaults.double(forKey: playbackSpeedKey)
        guard speed.isFinite else {
            return 1.0
        }

        return min(
            max(speed, PlaybackViewModel.minimumPlaybackSpeed),
            PlaybackViewModel.maximumPlaybackSpeed
        )
    }

    private static func clampedPlaybackVolume(_ volume: Double, fallback: Double) -> Double {
        guard volume.isFinite else {
            return fallback
        }

        return min(max(volume, 0), 100)
    }

    private static func defaultDatabaseURL() -> URL {
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return baseDirectory
            .appendingPathComponent(ApplicationInfo.name, isDirectory: true)
            .appendingPathComponent("CueSeeker.sqlite")
    }

    private static func prepareDatabaseDirectory(for databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private static func availableDiskSpaceBytes(for databaseURL: URL) -> Int64? {
        let directory = databaseURL.deletingLastPathComponent()
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: directory.path)
        return (attributes?[.systemFreeSize] as? NSNumber)?.int64Value
    }

    private static func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static func errorMessage(for error: Error) -> String {
        String(describing: error)
    }
}

private extension NSView {
    var ancestorOrSelfContainsEditableTextInput: Bool {
        if let textView = self as? NSTextView {
            return textView.isEditable
        }

        if let textField = self as? NSTextField {
            return textField.isEditable
        }

        var ancestor = superview
        while let current = ancestor {
            if let textView = current as? NSTextView {
                return textView.isEditable
            }

            if let textField = current as? NSTextField {
                return textField.isEditable
            }
            ancestor = current.superview
        }

        return false
    }
}
