import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

enum IndexingStatus: Equatable {
    case idle
    case indexing(URL)
    case indexingAll(currentFolder: URL, completedFolders: Int, totalFolders: Int)
    case completed(URL, SubtitleIndexingResult)
    case completedAll(folderCount: Int, SubtitleIndexingResult)
    case failed(URL, String)

    var isIndexing: Bool {
        switch self {
        case .indexing, .indexingAll:
            return true
        case .idle, .completed, .completedAll, .failed:
            return false
        }
    }
}

enum SearchStatus: Equatable {
    case idle
    case searching
    case completed
    case failed(String)
}

enum LibraryStatus: Equatable {
    case idle
    case loading
    case completed
    case failed(String)
}

enum PlaybackStatus: Equatable {
    case idle
    case opening
    case playing
    case paused
    case failed(String)

    var isOpening: Bool {
        if case .opening = self {
            return true
        }

        return false
    }
}

private enum ActivePlaybackSource: Equatable {
    case none
    case library(videoPath: String)
    case search
}

struct SearchResultFileGroup: Identifiable, Equatable {
    let subtitlePath: String
    let subtitleDisplayTitle: String
    let totalCount: Int
    let results: [SubtitleSearchResult]
    let isCollapsed: Bool

    var id: String { subtitlePath }

    var displayCount: String {
        totalCount > 99 ? "99+" : "\(totalCount)"
    }
}

struct LibraryVideoRow: Identifiable, Equatable {
    let video: LibraryVideo
    let displayTitle: String
    let fileExtension: String
    let duration: Double?

    var id: String {
        video.videoPath
    }
}

struct LibraryFolderGroup: Identifiable, Equatable {
    let folderPath: String
    let folderTitle: String
    let videos: [LibraryVideoRow]
    let isCollapsed: Bool

    var id: String {
        folderPath
    }
}

@MainActor
final class AppState: ObservableObject {
    private static let selectedFolderPathsKey = "selectedFolderPaths"
    private static let isLibraryPanelVisibleKey = "isLibraryPanelVisible"
    private static let libraryPanelWidthKey = "libraryPanelWidth"
    private static let isSearchPanelVisibleKey = "isSearchPanelVisible"
    private static let searchPanelWidthKey = "searchPanelWidth"
    private static let playbackDecodeModeKey = "playbackDecodeMode"
    private static let assSubtitlePreparationCueLimit = 8
    private static let searchPageSize = 100
    private static let searchPrefetchThreshold = 10
    private static let sidePanelLayoutTransitionNanoseconds: UInt64 = 220_000_000

    @Published var selectedFolders: [URL] = []
    @Published var indexingStatus: IndexingStatus = .idle
    @Published var searchQuery = ""
    @Published var searchStatus: SearchStatus = .idle
    @Published var searchResults: [SubtitleSearchResult] = []
    @Published var searchResultTotalCount = 0
    @Published var searchFileSummaries: [SubtitleSearchFileSummary] = []
    @Published var hasMoreSearchResults = false
    @Published var libraryStatus: LibraryStatus = .idle
    @Published var libraryVideos: [LibraryVideo] = []
    @Published var collapsedLibraryFolderPaths: Set<String> = []
    @Published var collapsedSearchResultGroupPaths: Set<String> = []
    @Published private(set) var libraryFolderGroups: [LibraryFolderGroup] = []
    @Published private(set) var searchResultGroups: [SearchResultFileGroup] = []
    @Published private(set) var renderedSearchResultCount = 0
    @Published private var areSearchResultGroupsCollapsedByGlobalControl = false
    @Published private var expandedSearchResultGroupRowsByPath: [String: [SubtitleSearchResult]] = [:]
    @Published var selectedSearchResult: SubtitleSearchResult?
    @Published var selectedLibraryVideo: LibraryVideo?
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var startupError: String?
    @Published var isLibraryPanelVisible = true
    @Published var libraryPanelWidth: Double = 310
    @Published var isSearchPanelVisible = true
    @Published var searchPanelWidth: Double = 480
    @Published var isSearchFocused = false
    @Published private(set) var isVideoSizeTransitionInProgress = false
    @Published var playbackViewModel: PlaybackViewModel?
    @Published var playbackDecodeMode: PlaybackDecodeMode = .auto {
        didSet {
            userDefaults.set(playbackDecodeMode.rawValue, forKey: Self.playbackDecodeModeKey)
            player?.decodeMode = playbackDecodeMode
        }
    }

    let databaseURL: URL
    let playbackFullscreenManager = PlaybackFullscreenManager()
    var playbackPlayer: PlaybackPlayer? {
        player
    }

    var hasSearchResultGroups: Bool {
        !searchResultGroups.isEmpty
    }

    private static func makeLibraryFolderGroups(
        videos libraryVideos: [LibraryVideo],
        collapsedFolderPaths: Set<String>
    ) -> [LibraryFolderGroup] {
        let videosByFolderPath = Dictionary(grouping: libraryVideos) {
            URL(fileURLWithPath: $0.videoPath)
                .deletingLastPathComponent()
                .standardizedFileURL
                .path
        }

        return videosByFolderPath.keys.sorted { lhs, rhs in
            let lhsTitle = URL(fileURLWithPath: lhs).lastPathComponent
            let rhsTitle = URL(fileURLWithPath: rhs).lastPathComponent
            let titleComparison = lhsTitle.localizedStandardCompare(rhsTitle)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        .map { folderPath in
            let folderTitle = URL(fileURLWithPath: folderPath).lastPathComponent
            let videos = (videosByFolderPath[folderPath] ?? []).sorted(by: Self.libraryVideoSort)
            let rankWidth = max(2, String(videos.count).count)
            let rows = videos.enumerated().map { index, video in
                let sequence = String(format: "%0*d", rankWidth, index + 1)
                let fileExtension = URL(fileURLWithPath: video.videoPath).pathExtension.lowercased()
                return LibraryVideoRow(
                    video: video,
                    displayTitle: "\(folderTitle) - \(sequence)",
                    fileExtension: fileExtension,
                    duration: video.duration
                )
            }

            return LibraryFolderGroup(
                folderPath: folderPath,
                folderTitle: folderTitle,
                videos: rows,
                isCollapsed: collapsedFolderPaths.contains(folderPath)
            )
        }
    }

    private static func makeSearchResultGroups(
        results searchResults: [SubtitleSearchResult],
        fileSummaries searchFileSummaries: [SubtitleSearchFileSummary],
        expandedRowsByPath: [String: [SubtitleSearchResult]],
        collapsedGroupPaths: Set<String>
    ) -> [SearchResultFileGroup] {
        let resultsByPath = Dictionary(grouping: searchResults, by: \.subtitlePath)
        guard !searchFileSummaries.isEmpty || !resultsByPath.isEmpty else {
            return []
        }

        let summaryByPath = Dictionary(uniqueKeysWithValues: searchFileSummaries.map { ($0.subtitlePath, $0) })
        let summaryPaths = Set(searchFileSummaries.map(\.subtitlePath))
        let orderedPaths = searchFileSummaries.map(\.subtitlePath)
        let extraPaths = Set(resultsByPath.keys)
            .union(expandedRowsByPath.keys)
            .filter { !summaryPaths.contains($0) }
            .sorted(by: Self.searchResultGroupPathSort)

        return (orderedPaths + extraPaths).map { path in
            let summary = summaryByPath[path]
            let groupRows = expandedRowsByPath[path] ?? resultsByPath[path] ?? []
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

    var hasLibraryFolderGroups: Bool {
        !libraryFolderGroups.isEmpty
    }

    var libraryGroupToggleTitle: String {
        let groups = libraryFolderGroups
        guard !groups.isEmpty else {
            return "Collapse All"
        }

        return groups.allSatisfy(\.isCollapsed) ? "Expand All" : "Collapse All"
    }

    var hasPlaybackSelection: Bool {
        currentPlaybackVideoPath != nil
    }

    var currentPlaybackVideoPath: String? {
        selectedLibraryVideo?.videoPath ?? selectedSearchResult?.videoPath
    }

    var currentPlaybackSubtitlePath: String? {
        selectedLibraryVideo?.subtitlePath ?? selectedSearchResult?.subtitlePath
    }

    var searchResultGroupToggleTitle: String {
        areSearchResultGroupsCollapsedByGlobalControl ? "Expand All Results" : "Collapse All Results"
    }

    private let userDefaults: UserDefaults
    private var player: PlaybackPlayer?
    private var indexingTask: Task<Void, Never>?
    private var libraryTask: Task<Void, Never>?
    private var libraryPlaybackHistoryTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var videoSizeTransitionTask: Task<Void, Never>?
    private var windowFrameBeforeUserZoom: NSRect?
    private var searchResultGroupTasks: [String: Task<Void, Never>] = [:]
    private var activePlaybackSource: ActivePlaybackSource = .none
    private var loadedGlobalSearchResultCount = 0
    private var isSearching: Bool {
        if case .searching = searchStatus {
            return true
        }

        return false
    }

    init(
        userDefaults: UserDefaults = .standard,
        databaseURL: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
        selectedFolders = Self.loadSelectedFolders(from: userDefaults)

        userDefaults.register(defaults: [
            Self.isLibraryPanelVisibleKey: true,
            Self.libraryPanelWidthKey: 310.0,
            Self.isSearchPanelVisibleKey: true,
            Self.searchPanelWidthKey: 480.0,
            Self.playbackDecodeModeKey: PlaybackDecodeMode.auto.rawValue
        ])
        isLibraryPanelVisible = userDefaults.bool(forKey: Self.isLibraryPanelVisibleKey)
        libraryPanelWidth = userDefaults.double(forKey: Self.libraryPanelWidthKey)
        isSearchPanelVisible = userDefaults.bool(forKey: Self.isSearchPanelVisibleKey)
        searchPanelWidth = userDefaults.double(forKey: Self.searchPanelWidthKey)
        playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)

        do {
            try Self.prepareDatabaseDirectory(for: self.databaseURL)
            let database = try SubtitleDatabase(path: self.databaseURL)
            try database.migrate()
            try database.reconcileIndexedContent(activeFolders: selectedFolders)
            try hydrateLibrarySynchronously(from: database)
            let player = PlaybackPlayer()
            player.decodeMode = playbackDecodeMode
            self.player = player
            playbackViewModel = PlaybackViewModel(player: player)
        } catch {
            startupError = Self.errorMessage(for: error)
        }
    }

    func addFolder(_ folder: URL) {
        let folder = folder.standardizedFileURL

        guard !selectedFolders.contains(folder) else {
            indexFolder(folder)
            return
        }

        selectedFolders.append(folder)
        persistSelectedFolders()
        indexFolder(folder)
    }

    func removeFolders(at offsets: IndexSet) {
        let folders = offsets.map { selectedFolders[$0] }
        for folder in folders {
            removeFolder(folder)
        }
    }

    func removeFolder(_ folder: URL) {
        let folder = folder.standardizedFileURL
        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            try database.removeIndexedFolder(folder)
        } catch {
            startupError = "Failed to remove folder index: \(Self.errorMessage(for: error))"
            return
        }

        selectedFolders.removeAll { $0 == folder }
        persistSelectedFolders()
        clearSearchAndPlaybackState(under: folder)
        refreshLibrary()
        refreshCurrentSearch(clearExistingResults: true)
    }

    func clearSearchFocus() {
        isSearchFocused = false
    }

    func performUserInitiatedAppCommand(_ action: () -> Void) {
        clearSearchFocus()
        action()
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

    func toggleLibraryPanel() {
        guard beginVideoSizeTransition(durationNanoseconds: Self.sidePanelLayoutTransitionNanoseconds) else {
            return
        }

        isLibraryPanelVisible.toggle()
        userDefaults.set(isLibraryPanelVisible, forKey: Self.isLibraryPanelVisibleKey)
    }

    func toggleSearchPanel() {
        guard beginVideoSizeTransition(durationNanoseconds: Self.sidePanelLayoutTransitionNanoseconds) else {
            return
        }

        isSearchPanelVisible.toggle()
        userDefaults.set(isSearchPanelVisible, forKey: Self.isSearchPanelVisibleKey)
    }

    func togglePlaybackFullscreenFromUser(onCopySubtitle: @escaping () -> Void = {}) {
        guard let player, let playbackViewModel else {
            return
        }

        guard beginVideoSizeTransition() else {
            return
        }

        let started = playbackFullscreenManager.toggleFullscreen(
            player: player,
            viewModel: playbackViewModel,
            onCopySubtitle: onCopySubtitle,
            onExitRequest: { [weak self] in
                self?.exitPlaybackFullscreenFromUser()
            },
            onTransitionCompleted: { [weak self] in
                self?.endVideoSizeTransition()
            }
        )
        if !started {
            endVideoSizeTransition()
        }
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
        }
    }

    func updateLibraryPanelWidth(_ width: Double) {
        libraryPanelWidth = width
        userDefaults.set(width, forKey: Self.libraryPanelWidthKey)
    }

    func updateSearchPanelWidth(_ width: Double) {
        searchPanelWidth = width
        userDefaults.set(width, forKey: Self.searchPanelWidthKey)
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
        guard !isVideoSizeTransitionInProgress else {
            return false
        }

        isVideoSizeTransitionInProgress = true
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
        isVideoSizeTransitionInProgress = false
        videoSizeTransitionTask = nil
    }

    private static func animationResizeDuration(
        for window: NSWindow,
        targetFrame: NSRect
    ) -> TimeInterval {
        max(0, window.animationResizeTime(targetFrame))
    }

    func indexFolder(_ folder: URL) {
        indexingTask?.cancel()
        cancelDatabaseReadTasksBeforeIndexing()
        clearSearchAndPlaybackState(under: folder)
        indexingStatus = .indexing(folder)

        let databaseURL = databaseURL
        indexingTask = Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    let indexer = SubtitleIndexer()
                    let result = try indexer.index(folder: folder, into: database)
                    _ = try PlaybackASSFontResourceIndexer().index(folder: folder, into: database)
                    _ = try PlaybackVideoMetadataIndexer().indexDurations(under: folder, into: database)
                    return result
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexingStatus = .completed(folder, result)
                refreshLibrary()
                refreshCurrentSearch()
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexingStatus = .failed(folder, Self.errorMessage(for: error))
            }
        }
    }

    func indexAllFolders() {
        let folders = selectedFolders
        guard let firstFolder = folders.first else {
            return
        }

        indexingTask?.cancel()
        cancelDatabaseReadTasksBeforeIndexing()
        for folder in folders {
            clearSearchAndPlaybackState(under: folder)
        }
        indexingStatus = .indexingAll(
            currentFolder: firstFolder,
            completedFolders: 0,
            totalFolders: folders.count
        )

        let databaseURL = databaseURL
        indexingTask = Task {
            var aggregateResult: SubtitleIndexingResult?

            for (index, folder) in folders.enumerated() {
                guard !Task.isCancelled else {
                    return
                }

                indexingStatus = .indexingAll(
                    currentFolder: folder,
                    completedFolders: index,
                    totalFolders: folders.count
                )

                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        let database = try SubtitleDatabase(path: databaseURL)
                        let indexer = SubtitleIndexer()
                        let result = try indexer.index(folder: folder, into: database)
                        _ = try PlaybackASSFontResourceIndexer().index(folder: folder, into: database)
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

                    indexingStatus = .failed(folder, Self.errorMessage(for: error))
                    return
                }
            }

            guard !Task.isCancelled else {
                return
            }

            guard let aggregateResult else {
                return
            }

            indexingStatus = .completedAll(
                folderCount: folders.count,
                aggregateResult
            )
            refreshLibrary()
            refreshCurrentSearch()
        }
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        startSearch(query: query, offset: 0, appending: false, debounce: true)
    }

    func loadMoreSearchResultsIfNeeded(currentResult result: SubtitleSearchResult) {
        guard hasMoreSearchResults, !isSearching else {
            return
        }

        guard let index = searchResults.firstIndex(where: { $0.entryID == result.entryID }),
              index >= searchResults.count - Self.searchPrefetchThreshold
        else {
            return
        }

        startSearch(
            query: searchQuery,
            offset: loadedGlobalSearchResultCount,
            appending: true,
            debounce: false
        )
    }

    func toggleSearchResultGroup(_ subtitlePath: String) {
        if collapsedSearchResultGroupPaths.contains(subtitlePath) {
            collapsedSearchResultGroupPaths.remove(subtitlePath)
            rebuildSearchResultGroups()
            revealInitialSearchResultGroupPage(for: subtitlePath)
        } else {
            collapsedSearchResultGroupPaths.insert(subtitlePath)
            rebuildSearchResultGroups()
        }
    }

    func toggleAllSearchResultGroups() {
        let groupPaths = Set(searchResultGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return
        }

        if areSearchResultGroupsCollapsedByGlobalControl {
            collapsedSearchResultGroupPaths.subtract(groupPaths)
            areSearchResultGroupsCollapsedByGlobalControl = false
            rebuildSearchResultGroups()
            revealInitialGlobalSearchResultPage()
        } else {
            collapsedSearchResultGroupPaths.formUnion(groupPaths)
            areSearchResultGroupsCollapsedByGlobalControl = true
            rebuildSearchResultGroups()
        }
    }

    func refreshLibrary() {
        libraryTask?.cancel()

        let folders = selectedFolders
        guard !folders.isEmpty else {
            libraryVideos = []
            collapsedLibraryFolderPaths = []
            rebuildLibraryFolderGroups()
            libraryStatus = .idle
            return
        }

        libraryStatus = .loading
        let databaseURL = databaseURL
        libraryTask = Task {
            do {
                let videos = try await Task.detached(priority: .userInitiated) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    try database.migrate()
                    return try database.libraryVideos(under: folders)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                applyLibraryVideos(videos)
                libraryStatus = .completed
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                libraryVideos = []
                collapsedLibraryFolderPaths = []
                rebuildLibraryFolderGroups()
                libraryStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func toggleLibraryFolderGroup(_ folderPath: String) {
        if collapsedLibraryFolderPaths.contains(folderPath) {
            collapsedLibraryFolderPaths.remove(folderPath)
        } else {
            collapsedLibraryFolderPaths.insert(folderPath)
        }
        rebuildLibraryFolderGroups()
    }

    func toggleAllLibraryFolderGroups() {
        let groupPaths = Set(libraryFolderGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return
        }

        if libraryFolderGroups.allSatisfy(\.isCollapsed) {
            collapsedLibraryFolderPaths.subtract(groupPaths)
        } else {
            collapsedLibraryFolderPaths.formUnion(groupPaths)
        }
        rebuildLibraryFolderGroups()
    }

    private func hydrateLibrarySynchronously(from database: SubtitleDatabase) throws {
        let folders = selectedFolders
        guard !folders.isEmpty else {
            libraryVideos = []
            collapsedLibraryFolderPaths = []
            rebuildLibraryFolderGroups()
            libraryStatus = .idle
            return
        }

        let videos = try database.libraryVideos(under: folders)
        applyLibraryVideos(videos)
        libraryStatus = .completed
    }

    private func applyLibraryVideos(_ videos: [LibraryVideo]) {
        libraryVideos = videos
        collapsedLibraryFolderPaths = Self.libraryGroupPaths(for: videos)
        rebuildLibraryFolderGroups()
    }

    private func rebuildLibraryFolderGroups() {
        libraryFolderGroups = Self.makeLibraryFolderGroups(
            videos: libraryVideos,
            collapsedFolderPaths: collapsedLibraryFolderPaths
        )
    }

    private static func libraryGroupPaths(for videos: [LibraryVideo]) -> Set<String> {
        Set(
            videos.map {
                URL(fileURLWithPath: $0.videoPath)
                    .deletingLastPathComponent()
                    .standardizedFileURL
                    .path
            }
        )
    }

    private func startSearch(
        query: String,
        offset: Int,
        appending: Bool,
        debounce: Bool
    ) {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appending {
            resetSearchResultLoadingState()
        }

        guard !trimmedQuery.isEmpty else {
            searchStatus = .idle
            return
        }

        let folders = selectedFolders
        guard !folders.isEmpty else {
            searchStatus = .completed
            selectedSearchResult = nil
            return
        }

        searchStatus = .searching

        let databaseURL = databaseURL
        let pageSize = Self.searchPageSize
        searchTask = Task {
            do {
                if debounce {
                    try await Task.sleep(nanoseconds: 250_000_000)
                }

                let page = try await Task.detached(priority: .userInitiated) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    try database.migrate()
                    return try database.searchPage(
                        trimmedQuery,
                        limit: pageSize,
                        offset: offset,
                        under: folders
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                if appending {
                    appendGlobalSearchResults(page.results)
                    loadedGlobalSearchResultCount = max(
                        loadedGlobalSearchResultCount,
                        offset + page.results.count
                    )
                } else {
                    searchResults = page.results
                    loadedGlobalSearchResultCount = page.results.count
                }
                searchResultTotalCount = page.totalCount
                searchFileSummaries = page.fileSummaries
                hasMoreSearchResults = loadedGlobalSearchResultCount < page.totalCount
                rebuildSearchResultGroups()
                searchStatus = .completed
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                if !appending {
                    resetSearchResultLoadingState()
                }
                hasMoreSearchResults = false
                searchStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func openSearchResult(_ result: SubtitleSearchResult) {
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        selectedSearchResult = result
        selectedLibraryVideo = nil
        Task { @MainActor in
            await Task.yield()
            play(result)
        }
    }

    func openLibraryVideo(_ video: LibraryVideo) {
        if case .library = activePlaybackSource {
            saveCurrentLibraryPlaybackHistory()
        }
        selectedLibraryVideo = video
        selectedSearchResult = nil
        Task { @MainActor in
            await Task.yield()
            play(video)
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
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        playbackStatus = .opening
        let subtitleCues = playbackSubtitleCues(for: result)
        playbackViewModel?.setSubtitleCues(
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
            playbackStatus = .playing
        } catch {
            playbackViewModel?.clearSubtitleCues()
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func play(_ video: LibraryVideo) {
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .none
        playbackStatus = .opening
        let startMilliseconds = libraryResumePositionMilliseconds(for: video)
        let subtitleCues = playbackSubtitleCues(
            forSubtitleFile: URL(fileURLWithPath: video.subtitlePath),
            format: video.subtitleFormat,
            fallbackStartMilliseconds: startMilliseconds,
            fallbackEndMilliseconds: startMilliseconds,
            fallbackContent: ""
        )
        playbackViewModel?.setSubtitleCues(
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
            playbackStatus = .playing
            startLibraryPlaybackHistoryTracking(videoPath: video.videoPath)
        } catch {
            playbackViewModel?.clearSubtitleCues()
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func pausePlayback() {
        do {
            try player?.setPaused(true)
            if case .playing = playbackStatus {
                playbackStatus = .paused
            }
            saveCurrentLibraryPlaybackHistory()
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func resumePlayback() {
        do {
            try player?.setPaused(false)
            if case .paused = playbackStatus {
                playbackStatus = .playing
            }
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func togglePlayback() {
        switch playbackStatus {
        case .playing:
            pausePlayback()
        case .paused:
            resumePlayback()
        case .idle:
            if let selectedSearchResult {
                play(selectedSearchResult)
            } else if let selectedLibraryVideo {
                play(selectedLibraryVideo)
            }
        case .opening, .failed:
            break
        }
    }

    func togglePlaybackFromUser() {
        let willPlay = !(playbackViewModel?.isPlaying ?? false)
        togglePlayback()
        playbackViewModel?.showPlayPauseFeedback(isPlaying: willPlay)
    }

    @discardableResult
    func copyCurrentSubtitleToClipboard() -> Bool {
        guard let currentPlaybackSubtitlePath, let playbackViewModel else {
            playbackViewModel?.showSubtitleCopyFeedback(copied: false)
            return false
        }

        let milliseconds = max(0, Int((playbackViewModel.currentTime * 1_000).rounded(.down)))

        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()

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

    func handlePlaybackKeyDown(
        keyCode: UInt16,
        modifierFlagsRawValue: UInt
    ) -> Bool {
        let isPlaybackInterfaceVisible = currentPlaybackVideoPath != nil || playbackFullscreenManager.isFullscreen

        guard isPlaybackInterfaceVisible else {
            return false
        }

        guard currentPlaybackVideoPath != nil, let viewModel = playbackViewModel else {
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
        case 12:
            copyCurrentSubtitleToClipboard()
            return true
        case 8:
            viewModel.toggleSubtitles()
            return true
        case 3:
            togglePlaybackFullscreenFromUser(
                onCopySubtitle: { [weak self] in
                    self?.copyCurrentSubtitleToClipboard()
                }
            )
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
            playbackViewModel?.clearSubtitleCues()
            activePlaybackSource = .none
            playbackStatus = .idle
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func saveCurrentLibraryPlaybackHistory() {
        guard case .library(let videoPath) = activePlaybackSource,
              let playbackViewModel
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

        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            try database.upsertLibraryPlaybackHistory(
                videoFile: URL(fileURLWithPath: videoPath),
                positionMilliseconds: positionMilliseconds,
                duration: duration
            )
        } catch {
            print("Failed to save Library playback history: \(error)")
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
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if clearExistingResults {
            searchResults = []
            expandedSearchResultGroupRowsByPath = [:]
            loadedGlobalSearchResultCount = 0
            rebuildSearchResultGroups()
        }

        updateSearchQuery(searchQuery)
    }

    private func libraryResumePositionMilliseconds(for video: LibraryVideo) -> Int {
        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            return try database.libraryPlaybackHistory(
                forVideoFile: URL(fileURLWithPath: video.videoPath)
            )?.positionMilliseconds ?? 0
        } catch {
            print("Failed to load Library playback history: \(error)")
            return 0
        }
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
        searchResults.removeAll { Self.path($0.subtitlePath, isUnder: folder) }
        searchFileSummaries.removeAll { Self.path($0.subtitlePath, isUnder: folder) }
        searchResultTotalCount = searchFileSummaries.reduce(0) { $0 + $1.matchCount }
        loadedGlobalSearchResultCount = searchResults.count
        hasMoreSearchResults = false
        collapsedSearchResultGroupPaths = collapsedSearchResultGroupPaths.filter { !Self.path($0, isUnder: folder) }
        libraryVideos.removeAll { Self.path($0.videoPath, isUnder: folder) }
        collapsedLibraryFolderPaths = collapsedLibraryFolderPaths.filter { !Self.path($0, isUnder: folder) }
        expandedSearchResultGroupRowsByPath = expandedSearchResultGroupRowsByPath.filter { path, _ in
            !Self.path(path, isUnder: folder)
        }
        rebuildLibraryFolderGroups()
        rebuildSearchResultGroups()
        let groupTaskPaths = searchResultGroupTasks.keys.filter { Self.path($0, isUnder: folder) }
        for path in groupTaskPaths {
            searchResultGroupTasks[path]?.cancel()
            searchResultGroupTasks.removeValue(forKey: path)
        }

        let selectedSearchResultIsUnderFolder = selectedSearchResult.map {
            Self.path($0.subtitlePath, isUnder: folder)
        } ?? false
        let selectedLibraryVideoIsUnderFolder = selectedLibraryVideo.map {
            Self.path($0.videoPath, isUnder: folder)
        } ?? false

        if selectedSearchResultIsUnderFolder || selectedLibraryVideoIsUnderFolder {
            selectedSearchResult = nil
            selectedLibraryVideo = nil
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

    private static func libraryVideoSort(_ lhs: LibraryVideo, _ rhs: LibraryVideo) -> Bool {
        let nameComparison = lhs.videoName.localizedStandardCompare(rhs.videoName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.videoPath.localizedStandardCompare(rhs.videoPath) == .orderedAscending
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

    private func revealInitialSearchResultGroupPage(for subtitlePath: String) {
        let currentRows = searchResults
            .filter { $0.subtitlePath == subtitlePath }
            .sorted(by: Self.searchResultSort)
        expandedSearchResultGroupRowsByPath[subtitlePath] = Array(currentRows.prefix(Self.searchPageSize))
        rebuildSearchResultGroups()

        searchResultGroupTasks[subtitlePath]?.cancel()

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !selectedFolders.isEmpty else {
            return
        }

        let folders = selectedFolders
        let databaseURL = databaseURL
        let pageSize = Self.searchPageSize
        searchResultGroupTasks[subtitlePath] = Task { [weak self] in
            do {
                let results = try await Task.detached(priority: .userInitiated) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    try database.migrate()
                    return try database.search(
                        trimmedQuery,
                        limit: pageSize,
                        offset: 0,
                        under: folders,
                        inSubtitlePath: subtitlePath
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                guard let self,
                      self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      self.searchFileSummaries.contains(where: { $0.subtitlePath == subtitlePath })
                else {
                    return
                }

                self.expandedSearchResultGroupRowsByPath[subtitlePath] = results
                self.searchResultGroupTasks.removeValue(forKey: subtitlePath)
                self.rebuildSearchResultGroups()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self?.searchResultGroupTasks.removeValue(forKey: subtitlePath)
                self?.searchStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    private func revealInitialGlobalSearchResultPage() {
        cancelSearchResultGroupTasks()
        expandedSearchResultGroupRowsByPath = [:]
        searchResults = Array(searchResults.prefix(Self.searchPageSize))
        loadedGlobalSearchResultCount = searchResults.count
        hasMoreSearchResults = loadedGlobalSearchResultCount < searchResultTotalCount
        rebuildSearchResultGroups()
    }

    private func appendGlobalSearchResults(_ results: [SubtitleSearchResult]) {
        let existingEntryIDs = Set(searchResults.map(\.entryID))
        searchResults.append(contentsOf: results.filter { !existingEntryIDs.contains($0.entryID) })
    }

    private func resetSearchResultLoadingState() {
        cancelSearchResultGroupTasks()
        searchResults = []
        searchResultTotalCount = 0
        searchFileSummaries = []
        hasMoreSearchResults = false
        collapsedSearchResultGroupPaths = []
        areSearchResultGroupsCollapsedByGlobalControl = false
        expandedSearchResultGroupRowsByPath = [:]
        loadedGlobalSearchResultCount = 0
        rebuildSearchResultGroups()
    }

    private func rebuildSearchResultGroups() {
        searchResultGroups = Self.makeSearchResultGroups(
            results: searchResults,
            fileSummaries: searchFileSummaries,
            expandedRowsByPath: expandedSearchResultGroupRowsByPath,
            collapsedGroupPaths: collapsedSearchResultGroupPaths
        )
        renderedSearchResultCount = searchResultGroups.reduce(0) { count, group in
            group.isCollapsed ? count : count + group.results.count
        }
    }

    private func revealFile(atPath path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: path)
        ])
    }

    private func cancelSearchResultGroupTasks() {
        searchResultGroupTasks.values.forEach { $0.cancel() }
        searchResultGroupTasks = [:]
    }

    private func cancelDatabaseReadTasksBeforeIndexing() {
        libraryTask?.cancel()
        libraryTask = nil
        searchTask?.cancel()
        searchTask = nil
        cancelSearchResultGroupTasks()

        if case .loading = libraryStatus {
            libraryStatus = libraryVideos.isEmpty ? .idle : .completed
        }
        if case .searching = searchStatus {
            searchStatus = .completed
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

        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
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
        let fontResourceDirectoryURL = assFontResourceDirectory(
            subtitleFile: subtitleURL,
            videoFile: videoURL
        )

        return PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            matchedVideoURL: videoURL,
            fontResourceDirectoryURL: fontResourceDirectoryURL,
            preparationTimeWindow: playbackSubtitleTimeWindow(for: result),
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
        let fontResourceDirectoryURL = assFontResourceDirectory(
            subtitleFile: subtitleURL,
            videoFile: videoURL
        )

        return PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            matchedVideoURL: videoURL,
            fontResourceDirectoryURL: fontResourceDirectoryURL,
            preparationTimeWindow: playbackSubtitleTimeWindow(
                forSubtitleFile: subtitleURL,
                startingAtMilliseconds: startMilliseconds,
                fallbackEndMilliseconds: startMilliseconds
            ),
            renderCacheDatabaseURL: databaseURL
        )
    }

    private func assFontResourceDirectory(subtitleFile: URL, videoFile: URL) -> URL? {
        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            guard let manifest = try database.assFontResourceManifest(
                forSubtitleFile: subtitleFile,
                videoFile: videoFile
            ), manifest.status == .readyWithFonts,
               let fontsDirectoryPath = manifest.fontsDirectoryPath
            else {
                return nil
            }

            return URL(fileURLWithPath: fontsDirectoryPath)
        } catch {
            print("Failed to load ASS font resource manifest: \(error)")
            return nil
        }
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

        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
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

    private func persistSelectedFolders() {
        userDefaults.set(
            selectedFolders.map(\.path),
            forKey: Self.selectedFolderPathsKey
        )
    }

    private static func loadSelectedFolders(from userDefaults: UserDefaults) -> [URL] {
        userDefaults
            .stringArray(forKey: selectedFolderPathsKey)?
            .map { URL(fileURLWithPath: $0).standardizedFileURL } ?? []
    }

    private static func loadPlaybackDecodeMode(from userDefaults: UserDefaults) -> PlaybackDecodeMode {
        guard let rawValue = userDefaults.string(forKey: playbackDecodeModeKey),
              let mode = PlaybackDecodeMode(rawValue: rawValue)
        else {
            return .auto
        }

        return mode
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
