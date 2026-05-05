import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

enum AppSection: String, CaseIterable, Identifiable {
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search:
            "Search"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .search:
            "magnifyingglass"
        case .settings:
            "gearshape"
        }
    }
}

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

enum PlaybackStatus: Equatable {
    case idle
    case opening(SubtitleSearchResult)
    case playing(SubtitleSearchResult)
    case paused(SubtitleSearchResult)
    case failed(String)

    var isOpening: Bool {
        if case .opening = self {
            return true
        }

        return false
    }
}

struct SearchResultFileGroup: Identifiable, Equatable {
    let subtitlePath: String
    let subtitleFileName: String
    let totalCount: Int
    let results: [SubtitleSearchResult]
    let isCollapsed: Bool

    var id: String { subtitlePath }

    var displayCount: String {
        totalCount > 99 ? "99+" : "\(totalCount)"
    }
}

@MainActor
final class AppState: ObservableObject {
    private static let selectedFolderPathsKey = "selectedFolderPaths"
    private static let isSidebarVisibleKey = "isSidebarVisible"
    private static let isPlaybackInspectorVisibleKey = "isPlaybackInspectorVisible"
    private static let playbackInspectorWidthKey = "playbackInspectorWidth"
    private static let playbackDecodeModeKey = "playbackDecodeMode"
    private static let assSubtitleRenderingModeKey = "assSubtitleRenderingMode"
    private static let assSubtitlePreparationCueLimit = 8
    private static let searchPageSize = 100
    private static let searchPrefetchThreshold = 10

    @Published var selectedSection: AppSection = .search
    @Published var selectedFolders: [URL] = []
    @Published var indexingStatus: IndexingStatus = .idle
    @Published var searchQuery = ""
    @Published var searchStatus: SearchStatus = .idle
    @Published var searchResults: [SubtitleSearchResult] = []
    @Published var searchResultTotalCount = 0
    @Published var searchFileSummaries: [SubtitleSearchFileSummary] = []
    @Published var hasMoreSearchResults = false
    @Published var collapsedSearchResultGroupPaths: Set<String> = []
    @Published private var expandedSearchResultGroupRowsByPath: [String: [SubtitleSearchResult]] = [:]
    @Published var selectedSearchResult: SubtitleSearchResult?
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var startupError: String?
    @Published var isSidebarVisible = true
    @Published var isPlaybackInspectorVisible = false
    @Published var playbackInspectorWidth: Double = 520
    @Published var isSearchFocused = false
    @Published var playbackViewModel: PlaybackViewModel?
    @Published var playbackDecodeMode: PlaybackDecodeMode = .auto {
        didSet {
            userDefaults.set(playbackDecodeMode.rawValue, forKey: Self.playbackDecodeModeKey)
            player?.decodeMode = playbackDecodeMode
        }
    }
    @Published var assSubtitleRenderingMode: ASSSubtitleRenderingMode = .native {
        didSet {
            userDefaults.set(assSubtitleRenderingMode.rawValue, forKey: Self.assSubtitleRenderingModeKey)
            player?.assSubtitleRenderingMode = assSubtitleRenderingMode
        }
    }

    let databaseURL: URL
    let playbackFullscreenManager = PlaybackFullscreenManager()
    var playbackPlayer: PlaybackPlayer? {
        player
    }

    var searchResultGroups: [SearchResultFileGroup] {
        let resultsByPath = Dictionary(grouping: searchResults, by: \.subtitlePath)
        guard !searchFileSummaries.isEmpty || !resultsByPath.isEmpty else {
            return []
        }

        let summaryByPath = Dictionary(uniqueKeysWithValues: searchFileSummaries.map { ($0.subtitlePath, $0) })
        let summaryPaths = Set(searchFileSummaries.map(\.subtitlePath))
        let orderedPaths = searchFileSummaries.map(\.subtitlePath)
        let extraPaths = Set(resultsByPath.keys)
            .union(expandedSearchResultGroupRowsByPath.keys)
            .filter { !summaryPaths.contains($0) }
            .sorted(by: Self.searchResultGroupPathSort)

        return (orderedPaths + extraPaths).map { path in
            let summary = summaryByPath[path]
            let groupRows = expandedSearchResultGroupRowsByPath[path] ?? resultsByPath[path] ?? []
            let results = groupRows.sorted(by: Self.searchResultSort)
            return SearchResultFileGroup(
                subtitlePath: path,
                subtitleFileName: summary?.subtitleFileName ?? URL(fileURLWithPath: path).lastPathComponent,
                totalCount: summary?.matchCount ?? results.count,
                results: results,
                isCollapsed: collapsedSearchResultGroupPaths.contains(path)
            )
        }
    }

    var hasSearchResultGroups: Bool {
        !searchResultGroups.isEmpty
    }

    var renderedSearchResultCount: Int {
        searchResultGroups.reduce(0) { count, group in
            group.isCollapsed ? count : count + group.results.count
        }
    }

    var searchResultGroupToggleTitle: String {
        areAllSearchResultGroupsCollapsed ? "Expand All Results" : "Collapse All Results"
    }

    private var areAllSearchResultGroupsCollapsed: Bool {
        let groupPaths = Set(searchResultGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return false
        }

        return groupPaths.isSubset(of: collapsedSearchResultGroupPaths)
    }

    private let userDefaults: UserDefaults
    private var player: PlaybackPlayer?
    private var indexingTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var searchResultGroupTasks: [String: Task<Void, Never>] = [:]
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
            Self.isSidebarVisibleKey: true,
            Self.isPlaybackInspectorVisibleKey: false,
            Self.playbackInspectorWidthKey: 520.0,
            Self.playbackDecodeModeKey: PlaybackDecodeMode.auto.rawValue,
            Self.assSubtitleRenderingModeKey: ASSSubtitleRenderingMode.native.rawValue
        ])
        isSidebarVisible = userDefaults.bool(forKey: Self.isSidebarVisibleKey)
        isPlaybackInspectorVisible = userDefaults.bool(forKey: Self.isPlaybackInspectorVisibleKey)
        playbackInspectorWidth = userDefaults.double(forKey: Self.playbackInspectorWidthKey)
        playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)
        assSubtitleRenderingMode = Self.loadASSSubtitleRenderingMode(from: userDefaults)

        do {
            try Self.prepareDatabaseDirectory(for: self.databaseURL)
            let database = try SubtitleDatabase(path: self.databaseURL)
            try database.migrate()
            try database.reconcileIndexedContent(activeFolders: selectedFolders)
            let player = PlaybackPlayer()
            player.decodeMode = playbackDecodeMode
            player.assSubtitleRenderingMode = assSubtitleRenderingMode
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
        refreshCurrentSearch(clearExistingResults: true)
    }

    func clearSearchFocus() {
        isSearchFocused = false
    }

    func performUserInitiatedAppCommand(_ action: () -> Void) {
        clearSearchFocus()
        action()
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
        userDefaults.set(isSidebarVisible, forKey: Self.isSidebarVisibleKey)
    }

    func togglePlaybackInspector() {
        if isPlaybackInspectorVisible {
            collapsePlaybackInspector()
        } else {
            isPlaybackInspectorVisible = true
            userDefaults.set(true, forKey: Self.isPlaybackInspectorVisibleKey)
        }
    }

    func collapsePlaybackInspector() {
        isPlaybackInspectorVisible = false
        userDefaults.set(false, forKey: Self.isPlaybackInspectorVisibleKey)
        playbackFullscreenManager.exitFullscreen()
        pausePlayback()
    }

    func updatePlaybackInspectorWidth(_ width: Double) {
        playbackInspectorWidth = width
        userDefaults.set(width, forKey: Self.playbackInspectorWidthKey)
    }

    func selectSection(_ section: AppSection) {
        guard selectedSection != section else {
            return
        }

        clearSearchFocus()
        selectedSection = section

        if section != .search {
            playbackFullscreenManager.exitFullscreen()
            pausePlayback()
        }
    }

    func indexFolder(_ folder: URL) {
        indexingTask?.cancel()
        indexingStatus = .indexing(folder)

        let databaseURL = databaseURL
        indexingTask = Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    let indexer = SubtitleIndexer()
                    return try indexer.index(folder: folder, into: database)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexingStatus = .completed(folder, result)
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
                        return try indexer.index(folder: folder, into: database)
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
            revealInitialSearchResultGroupPage(for: subtitlePath)
        } else {
            collapsedSearchResultGroupPaths.insert(subtitlePath)
        }
    }

    func toggleAllSearchResultGroups() {
        let groupPaths = Set(searchResultGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return
        }

        if groupPaths.isSubset(of: collapsedSearchResultGroupPaths) {
            collapsedSearchResultGroupPaths.subtract(groupPaths)
            revealInitialGlobalSearchResultPage()
        } else {
            collapsedSearchResultGroupPaths.formUnion(groupPaths)
        }
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
        selectedSearchResult = result
        isPlaybackInspectorVisible = true
        userDefaults.set(true, forKey: Self.isPlaybackInspectorVisibleKey)
        Task { @MainActor in
            await Task.yield()
            play(result)
        }
    }

    func play(_ result: SubtitleSearchResult) {
        playbackStatus = .opening(result)
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
            playbackStatus = .playing(result)
        } catch {
            playbackViewModel?.clearSubtitleCues()
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func pausePlayback() {
        do {
            try player?.setPaused(true)
            if case .playing(let result) = playbackStatus {
                playbackStatus = .paused(result)
            }
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func resumePlayback() {
        do {
            try player?.setPaused(false)
            if case .paused(let result) = playbackStatus {
                playbackStatus = .playing(result)
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
        guard let selectedSearchResult, let playbackViewModel else {
            playbackViewModel?.showSubtitleCopyFeedback(copied: false)
            return false
        }

        let milliseconds = max(0, Int((playbackViewModel.currentTime * 1_000).rounded(.down)))

        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()

            guard let selection = try database.cueTextSelection(
                forSubtitleFile: URL(fileURLWithPath: selectedSearchResult.subtitlePath),
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
        let isPlaybackInterfaceVisible = selectedSection == .search
            && (isPlaybackInspectorVisible || playbackFullscreenManager.isFullscreen)

        guard isPlaybackInterfaceVisible else {
            return false
        }

        guard selectedSearchResult != nil, let viewModel = playbackViewModel else {
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
            if let player {
                playbackFullscreenManager.toggleFullscreen(
                    player: player,
                    viewModel: viewModel,
                    onCopySubtitle: { [weak self] in
                        self?.copyCurrentSubtitleToClipboard()
                    }
                )
                return true
            }
            return false
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
            playbackFullscreenManager.exitFullscreen()
            try player?.stop()
            playbackViewModel?.clearSubtitleCues()
            playbackStatus = .idle
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
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
        }

        updateSearchQuery(searchQuery)
    }

    private func clearSearchAndPlaybackState(under folder: URL) {
        searchResults.removeAll { Self.path($0.subtitlePath, isUnder: folder) }
        expandedSearchResultGroupRowsByPath = expandedSearchResultGroupRowsByPath.filter { path, _ in
            !Self.path(path, isUnder: folder)
        }
        let groupTaskPaths = searchResultGroupTasks.keys.filter { Self.path($0, isUnder: folder) }
        for path in groupTaskPaths {
            searchResultGroupTasks[path]?.cancel()
            searchResultGroupTasks.removeValue(forKey: path)
        }

        guard let selectedSearchResult,
              Self.path(selectedSearchResult.subtitlePath, isUnder: folder)
        else {
            return
        }

        self.selectedSearchResult = nil
        stopPlayback()
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
        let lhsFileName = URL(fileURLWithPath: lhs).lastPathComponent
        let rhsFileName = URL(fileURLWithPath: rhs).lastPathComponent
        let fileNameComparison = lhsFileName.localizedStandardCompare(rhsFileName)
        if fileNameComparison != .orderedSame {
            return fileNameComparison == .orderedAscending
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

    private func revealInitialSearchResultGroupPage(for subtitlePath: String) {
        let currentRows = searchResults
            .filter { $0.subtitlePath == subtitlePath }
            .sorted(by: Self.searchResultSort)
        expandedSearchResultGroupRowsByPath[subtitlePath] = Array(currentRows.prefix(Self.searchPageSize))

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
        expandedSearchResultGroupRowsByPath = [:]
        loadedGlobalSearchResultCount = 0
    }

    private func cancelSearchResultGroupTasks() {
        searchResultGroupTasks.values.forEach { $0.cancel() }
        searchResultGroupTasks = [:]
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
        guard result.subtitleFormat == .srt else {
            return []
        }

        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            let entries = try database.entries(
                forSubtitleFile: URL(fileURLWithPath: result.subtitlePath)
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

        return [
            PlaybackSubtitleCue(
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds,
                text: result.content
            )
        ]
    }

    private func playbackSubtitleSource(for result: SubtitleSearchResult) -> PlaybackSubtitleSource? {
        guard result.subtitleFormat == .ass else {
            return nil
        }

        return PlaybackSubtitleSource(
            url: URL(fileURLWithPath: result.subtitlePath),
            format: .ass,
            preparationTimeWindow: playbackSubtitleTimeWindow(for: result),
            renderCacheDatabaseURL: databaseURL
        )
    }

    private func playbackSubtitleTimeWindow(for result: SubtitleSearchResult) -> PlaybackSubtitleTimeWindow {
        let fallback = PlaybackSubtitleTimeWindow(
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds
        )

        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            let timings = try database.cueTimings(
                forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
                startingAtMilliseconds: result.startMilliseconds,
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

    private static func loadASSSubtitleRenderingMode(from userDefaults: UserDefaults) -> ASSSubtitleRenderingMode {
        guard let rawValue = userDefaults.string(forKey: assSubtitleRenderingModeKey),
              let mode = ASSSubtitleRenderingMode(rawValue: rawValue)
        else {
            return .native
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
