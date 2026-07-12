import AppKit
import Combine
import Foundation
import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

/// Workflow coordinator. Holds references to the per-domain stores (settings,
/// indexing, workbenchLayout, shiori, library, search, playback) and owns the
/// orchestration methods that span multiple domains. Per-domain @Published
/// state and derived display properties live on the respective stores;
/// AppCoordinator's own @Published surface is intentionally minimal
/// (`startupError` only) so views observing the stores get scoped invalidation.
@MainActor
final class AppCoordinator: ObservableObject {
    static let playbackVolumeKey = "playbackVolume"
    static let playbackLastNonzeroVolumeKey = "playbackLastNonzeroVolume"
    static let playbackSpeedKey = "playbackSpeed"
    static let playbackSubtitlesVisibleKey = "playbackSubtitlesVisible"
    static let assSubtitlePreparationCueLimit = 8
    static let searchPageSize = 100
    static let searchPrefetchThreshold = 10
    static let searchCountProgressMinimumIntervalNanoseconds: UInt64 = 200_000_000
    static let searchNavigationPanelRadius = 120
    nonisolated static let playbackSubtitleWindowRadius = 80
    static let databaseCompactionMinimumReclaimableBytes: Int64 = 100 * 1024 * 1024
    static let databaseCompactionMinimumFreelistRatio = 0.25
    static let aiChunkingPromptAwareCacheClearKey = "aiChunkingPromptAwareCacheCleared"

    @Published var startupError: String?
    let uiProbeScope: String
    let settings: SettingsStore
    let indexing: IndexingStore
    let shiori: ShioriStore
    let library: LibraryStore
    let search: SearchStore
    let playback: PlaybackStore
    var settingsCancellables: Set<AnyCancellable> = []

    let databaseURL: URL
    let playbackSubtitleFocusDatabaseReader: PlaybackSubtitleFocusDatabaseReader
    var subtitleDatabase: SubtitleDatabase?
    let workbenchLayout: WorkbenchLayoutState
    let playbackFullscreenManager = PlaybackFullscreenManager()
    var playbackPlayer: PlaybackPlayer? {
        player
    }

    static func makeLibraryFolderGroups(
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

    static func makeSearchResultGroups(
        results searchResults: [SubtitleSearchResult],
        fileSummaries searchFileSummaries: [SubtitleSearchFileSummary],
        expandedRowsByPath: [String: [SubtitleSearchResult]],
        collapsedGroupPaths: Set<String>,
        includesSummaryOnlyGroups: Bool
    ) -> [SearchResultFileGroup] {
        let nonEmptyExpandedRowsByPath = expandedRowsByPath.filter { !$0.value.isEmpty }
        let loadedCountsByPath = searchResults.reduce(into: [String: Int]()) { counts, result in
            counts[result.subtitlePath, default: 0] += 1
        }
        let loadedPaths = Set(loadedCountsByPath.keys).union(nonEmptyExpandedRowsByPath.keys)
        guard !searchFileSummaries.isEmpty || !loadedPaths.isEmpty else {
            return []
        }

        let summaryByPath = Dictionary(uniqueKeysWithValues: searchFileSummaries.map { ($0.subtitlePath, $0) })
        let summaryPaths = Set(searchFileSummaries.map(\.subtitlePath))
        let orderedPaths = searchFileSummaries
            .map(\.subtitlePath)
            .filter { includesSummaryOnlyGroups || loadedPaths.contains($0) || summaryByPath[$0] != nil }
        let extraPaths = loadedPaths
            .filter { !summaryPaths.contains($0) }
            .sorted(by: Self.searchResultGroupPathSort)

        return (orderedPaths + extraPaths).map { path in
            let summary = summaryByPath[path]
            let groupRows = nonEmptyExpandedRowsByPath[path] ?? []
            let results = groupRows.sorted(by: Self.searchResultSort)
            return SearchResultFileGroup(
                subtitlePath: path,
                subtitleDisplayTitle: summary?.subtitleDisplayTitle
                    ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: path),
                totalCount: summary?.matchCount ?? loadedCountsByPath[path] ?? results.count,
                results: results,
                isCollapsed: collapsedGroupPaths.contains(path)
            )
        }
    }

    static func makeShioriFileGroups(
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
        playback.chromeSnapshot.displayTitle
    }

    func playbackDisplayTitle(
        providedDisplayTitle: String?,
        fallback: @autoclosure () -> String
    ) -> String {
        let trimmedDisplayTitle = providedDisplayTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedDisplayTitle, !trimmedDisplayTitle.isEmpty else {
            return fallback()
        }
        return trimmedDisplayTitle
    }

    func playbackDisplayTitle(
        for selectedLibraryVideo: LibraryVideo,
        providedDisplayTitle: String? = nil
    ) -> String {
        playbackDisplayTitle(
            providedDisplayTitle: providedDisplayTitle,
            fallback: library.libraryFolderGroups
                .lazy
                .flatMap(\.videos)
                .first { $0.video.videoPath == selectedLibraryVideo.videoPath }?
                .displayTitle
            ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedLibraryVideo.subtitlePath)
        )
    }

    func playbackDisplayTitle(
        for selectedSearchResult: SubtitleSearchResult,
        providedDisplayTitle: String? = nil
    ) -> String {
        let resolvedDisplayTitle = [
            providedDisplayTitle,
            selectedSearchResult.displayTitle
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return playbackDisplayTitle(
            providedDisplayTitle: resolvedDisplayTitle,
            fallback: search.searchResultGroups
                .first { $0.subtitlePath == selectedSearchResult.subtitlePath }?
                .subtitleDisplayTitle
            ?? search.searchFileSummaries
                .first { $0.subtitlePath == selectedSearchResult.subtitlePath }?
                .subtitleDisplayTitle
            ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedSearchResult.subtitlePath)
        )
    }

    func playbackDisplayTitle(
        for selectedShiori: Shiori,
        providedDisplayTitle: String? = nil
    ) -> String {
        playbackDisplayTitle(
            providedDisplayTitle: providedDisplayTitle,
            fallback: shiori.shioriFileGroups
                .first { $0.subtitlePath == selectedShiori.subtitlePath }?
                .subtitleDisplayTitle
            ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedShiori.subtitlePath)
        )
    }

    func setPlaybackChromeSnapshot(
        displayTitle: String,
        canGoPrevious: Bool,
        canGoNext: Bool
    ) {
        playback.setChromeSnapshot(
            PlaybackChromeSnapshot(
                displayTitle: displayTitle,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                hasPlaybackSelection: currentPlaybackVideoPath != nil
            )
        )
    }

    func refreshPlaybackChromeSnapshot(displayTitle: String) {
        setPlaybackChromeSnapshot(
            displayTitle: displayTitle,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext
        )
    }

    func clearPlaybackChromeSnapshot() {
        playback.clearChromeSnapshot()
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
        guard isSearchPlaybackActive, let selectedSearchResult = search.selectedSearchResult else {
            return false
        }

        if let searchNavigationSnapshot = search.searchNavigationSnapshot {
            return searchNavigationSnapshot.previous != nil
        }

        return selectedSearchResult.searchRank > 0
    }

    var canOpenNextSearchResult: Bool {
        guard isSearchPlaybackActive, let selectedSearchResult = search.selectedSearchResult else {
            return false
        }

        if let searchNavigationSnapshot = search.searchNavigationSnapshot {
            return searchNavigationSnapshot.next != nil
        }

        let totalCount = max(search.searchResultTotalCount, search.searchResults.count)
        return selectedSearchResult.searchRank + 1 < totalCount
    }

    // MARK: - Unified Navigation

    var canGoPrevious: Bool {
        switch activePlaybackSource {
        case .search:
            return canOpenPreviousSearchResult
        case .library:
            return canOpenPreviousLibraryVideo
        case .shiori:
            return canOpenPreviousShiori
        case .none:
            return false
        }
    }

    func goPrevious() {
        switch activePlaybackSource {
        case .search:
            openAdjacentSearchResult(.previous)
        case .library:
            openPreviousLibraryVideo()
        case .shiori:
            openPreviousShiori()
        case .none:
            break
        }
    }

    var canGoNext: Bool {
        switch activePlaybackSource {
        case .search:
            return canOpenNextSearchResult
        case .library:
            return canOpenNextLibraryVideo
        case .shiori:
            return canOpenNextShiori
        case .none:
            return false
        }
    }

    func goNext() {
        switch activePlaybackSource {
        case .search:
            openAdjacentSearchResult(.next)
        case .library:
            openNextLibraryVideo()
        case .shiori:
            openNextShiori()
        case .none:
            break
        }
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
            && library.recentWatchingStatus != .loading
            && library.testRecentWatchingStatus != .loading
            && library.completeLibraryStatus != .loading
    }

    let userDefaults: UserDefaults
    var player: PlaybackPlayer?
    let libraryPlaybackHistoryWriter: LibraryPlaybackHistoryWriter
    var startupDatabaseTask: Task<Void, Never>?
    var indexingTask: Task<Void, Never>?
    var libraryTask: Task<Void, Never>?
    var recentWatchingTask: Task<Void, Never>?
    var testRecentWatchingTask: Task<Void, Never>?
    var completeLibraryTask: Task<Void, Never>?
    let libraryDisplayRenditionCommitGate = LibraryCoverDisplayRenditionCommitGate()
    var libraryDisplayRenditionTask: Task<Void, Never>?
    var libraryDisplayRenditionAttemptedScopeKey: String?
    var libraryDisplayRenditionGeneration = 0
    var shiorisTask: Task<Void, Never>?
    var libraryPlaybackHistoryTask: Task<Void, Never>?
    var searchTask: Task<Void, Never>?
    var searchExactCompletionTask: Task<Void, Never>?
    var searchNavigationTask: Task<Void, Never>?
    var playbackSubtitleCuesTask: Task<Void, Never>?
    var playbackSubtitleFocusInitialLoadTask: Task<Void, Never>?
    var playbackSubtitleFocusCompleteLoadTask: Task<Void, Never>?
    var playbackSubtitleFocusActionTask: Task<Void, Never>?
    var playbackSubtitleFocusActionGeneration = 0
    var databaseStorageStatsTask: Task<Void, Never>?
    var databaseCompactionTask: Task<Void, Never>?
    var videoSizeTransitionTask: Task<Void, Never>?
    var windowFrameBeforeUserZoom: NSRect?
    var searchResultGroupTasks: [String: Task<Void, Never>] = [:]
    var activeSearchPerformanceRun: SearchPerformanceRun?
    var pendingSearchVisibleEntryIDs: Set<Int64> = []
    var shioriPlaybackNavigationScopeIDs: [Int64]?
    var shioriPlaybackNavigationSnapshot: (currentID: Int64, previousID: Int64?, nextID: Int64?)?
    var activePlaybackSource: ActivePlaybackSource = .none
    var playbackOriginatingPanelMode: WorkbenchPanelMode?
    var currentCueSegmentFinished = false
    var cueSegmentPlaybackGeneration = 0
    var activeCueSegmentEndMilliseconds: Int?
    var libraryPlaybackCompletedMilestoneVideoPath: String?
    var libraryPlaybackFinishMetadata: SubtitlePlaybackFinishMetadata?
    var autoPlayCueSequenceTask: Task<Void, Never>?
    var loadedGlobalSearchResultCount = 0
    var lastSearchCountProgressUpdate: UInt64 = 0
    var nextGlobalSearchCursor: SubtitleSearchCursor?
    var pendingURLSchemeDirectPlayIntent: URLSchemeDirectPlayIntent?

    init(
        userDefaults: UserDefaults? = nil,
        databaseURL: URL? = nil,
        uiProbeScope: String = UUID().uuidString
    ) {
        let userDefaults = userDefaults ?? ApplicationPersistence.sharedUserDefaults()
        self.uiProbeScope = uiProbeScope
        self.userDefaults = userDefaults
        let resolvedDatabaseURL = databaseURL ?? Self.defaultDatabaseURL()
        self.databaseURL = resolvedDatabaseURL
        playbackSubtitleFocusDatabaseReader = PlaybackSubtitleFocusDatabaseReader(
            databaseURL: resolvedDatabaseURL
        )

        userDefaults.register(defaults: [
            "workbenchPanelMode": WorkbenchPanelMode.search.rawValue,
            "workbenchSidebarVisible": true,
            Self.playbackVolumeKey: 100.0,
            Self.playbackLastNonzeroVolumeKey: 100.0,
            Self.playbackSpeedKey: 1.0,
            Self.playbackSubtitlesVisibleKey: true
        ])
        workbenchLayout = WorkbenchLayoutState(userDefaults: userDefaults)
        settings = SettingsStore(
            userDefaults: userDefaults,
            uiProbeScope: uiProbeScope
        )
        indexing = IndexingStore(userDefaults: userDefaults, settings: settings)
        shiori = ShioriStore(uiProbeScope: uiProbeScope)
        library = LibraryStore()
        search = SearchStore()
        playback = PlaybackStore(userDefaults: userDefaults)

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

        guard openedDatabase != nil else {
            return
        }

        setupSettingsObservers()
    }

    func setupSettingsObservers() {
        settings.$playbackDecodeMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.player?.decodeMode = mode
            }
            .store(in: &settingsCancellables)

        settings.$primarySearchLanguage
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshCurrentSearch(clearExistingResults: true)
            }
            .store(in: &settingsCancellables)

        settings.$searchScope
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshCurrentSearch(clearExistingResults: true)
            }
            .store(in: &settingsCancellables)

        settings.$playbackSpeakerDisplayEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshCurrentPlaybackSubtitleDisplay()
            }
            .store(in: &settingsCancellables)

        settings.$autoPlayCueSequenceEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                guard let self, !isEnabled else {
                    return
                }

                self.cancelAutoPlayCueSequenceTask()
                self.clearCueSubtitlePresentationHold()
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

    func toggleWorkbenchSidebarVisibilityFromUser() {
        AppPerformanceProbe.action("AppCoordinator.toggleWorkbenchSidebarVisibility", thresholdMilliseconds: 4) {
            UIInvalidationProbe.mark(
                "ACTION UI.AppSidebar.toggled",
                details: "visibleBefore=\(workbenchLayout.isSidebarVisible)"
            )
            withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
                workbenchLayout.toggleSidebarVisibility()
            }
        }
    }


    func clearSearchAndPlaybackState(under folder: URL) {
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
        removeCompleteLibraryPresentation(under: folder)
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

    static func path(_ path: String, isUnder folder: URL) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return folderPathPrefixes(for: folder).contains { prefix in
            standardizedPath.hasPrefix(prefix)
        }
    }

    static func folderPathPrefixes(for folder: URL) -> [String] {
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

    static func normalizedFolderPath(_ path: String) -> String {
        var path = path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    static func searchResultGroupPathSort(_ lhs: String, _ rhs: String) -> Bool {
        let lhsDisplayTitle = SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: lhs)
        let rhsDisplayTitle = SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: rhs)
        let displayTitleComparison = SubtitleDisplayTitleResolver.compareDisplayTitles(lhsDisplayTitle, rhsDisplayTitle)
        if displayTitleComparison != .orderedSame {
            return displayTitleComparison == .orderedAscending
        }

        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    static func searchResultSort(_ lhs: SubtitleSearchResult, _ rhs: SubtitleSearchResult) -> Bool {
        if lhs.startMilliseconds != rhs.startMilliseconds {
            return lhs.startMilliseconds < rhs.startMilliseconds
        }

        if lhs.endMilliseconds != rhs.endMilliseconds {
            return lhs.endMilliseconds < rhs.endMilliseconds
        }

        return lhs.entryID < rhs.entryID
    }

    static func shioriSort(_ lhs: Shiori, _ rhs: Shiori) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id > rhs.id
    }

    func aggregate(
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

    static func defaultDatabaseURL() -> URL {
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return baseDirectory
            .appendingPathComponent(ApplicationInfo.name, isDirectory: true)
            .appendingPathComponent("CueSeeker.sqlite")
    }

    static func prepareDatabaseDirectory(for databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    static func clearAIChunkCacheForPromptAwareSettingsIfNeeded(
        database: SubtitleDatabase,
        userDefaults: UserDefaults
    ) throws {
        guard !userDefaults.bool(forKey: aiChunkingPromptAwareCacheClearKey) else {
            return
        }

        try database.clearAIChunkCacheEntries()
        userDefaults.set(true, forKey: aiChunkingPromptAwareCacheClearKey)
    }

    static func availableDiskSpaceBytes(for databaseURL: URL) -> Int64? {
        let directory = databaseURL.deletingLastPathComponent()
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: directory.path)
        return (attributes?[.systemFreeSize] as? NSNumber)?.int64Value
    }

    static func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func errorMessage(for error: Error) -> String {
        String(describing: error)
    }
}
