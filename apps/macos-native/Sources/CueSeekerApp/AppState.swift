import AppKit
import Foundation
import SwiftUI
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

enum TopbarSearchContentMode: Equatable {
    case workbench
    case results
    case playback
}

private enum ActivePlaybackSource: Equatable {
    case none
    case library(videoPath: String)
    case search
    case shiori
}

enum SearchResultNavigationDirection {
    case previous
    case next
}

enum PlaybackDrawerKind: Equatable {
    case results
    case subtitles
}

enum BottomPlaybackMenuKind: Equatable {
    case more
    case speed
}

struct PlaybackDrawerRequest: Equatable, Identifiable {
    let id = UUID()
    let drawer: PlaybackDrawerKind
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

struct ShioriFileGroup: Identifiable, Equatable {
    let subtitlePath: String
    let subtitleDisplayTitle: String
    let shioris: [Shiori]
    let isCollapsed: Bool

    var id: String { subtitlePath }
    var totalCount: Int { shioris.count }
}

struct LibraryVideoRow: Identifiable {
    let video: LibraryVideo
    let displayTitle: String
    let fileExtension: String
    let duration: Double?

    var id: String {
        video.videoPath
    }
}

struct LibraryFolderGroup: Identifiable {
    let folderPath: String
    let folderTitle: String
    let videos: [LibraryVideoRow]

    var id: String {
        folderPath
    }
}

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

@MainActor
enum WorkbenchPanelMode: String, CaseIterable {
    case library
    case search
    case shiori
}

enum WorkbenchSidebarPosition: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:
            "Left"
        case .right:
            "Right"
        }
    }
}

@MainActor
final class WorkbenchLayoutState: ObservableObject {
    private static let isContentPanelVisibleKey = "isWorkbenchContentPanelVisible"
    private static let contentPanelWidthKey = "workbenchContentPanelWidth"
    private static let panelModeKey = "workbenchPanelMode"
    private static let sidebarPositionKey = "workbenchSidebarPosition"

    @Published var isContentPanelVisible: Bool
    @Published var contentPanelWidth: Double
    @Published var panelMode: WorkbenchPanelMode
    @Published var sidebarPosition: WorkbenchSidebarPosition {
        didSet {
            userDefaults.set(sidebarPosition.rawValue, forKey: Self.sidebarPositionKey)
        }
    }
    @Published fileprivate(set) var isVideoSizeTransitionInProgress = false
    @Published var isAppFullscreen = false

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        isContentPanelVisible = userDefaults.bool(forKey: Self.isContentPanelVisibleKey)
        contentPanelWidth = userDefaults.double(forKey: Self.contentPanelWidthKey)
        let storedPanelMode = WorkbenchPanelMode(
            rawValue: userDefaults.string(forKey: Self.panelModeKey) ?? ""
        ) ?? .library
        panelMode = storedPanelMode == .search ? .library : storedPanelMode
        if storedPanelMode == .search {
            userDefaults.set(WorkbenchPanelMode.library.rawValue, forKey: Self.panelModeKey)
        }
        sidebarPosition = WorkbenchSidebarPosition(
            rawValue: userDefaults.string(forKey: Self.sidebarPositionKey) ?? ""
        ) ?? .left
    }

    func toggleContentPanel() {
        isContentPanelVisible.toggle()
        userDefaults.set(isContentPanelVisible, forKey: Self.isContentPanelVisibleKey)
    }

    func showContentPanel() {
        guard !isContentPanelVisible else {
            return
        }

        isContentPanelVisible = true
        userDefaults.set(true, forKey: Self.isContentPanelVisibleKey)
    }

    func updateContentPanelWidth(_ width: Double) {
        contentPanelWidth = width
        userDefaults.set(width, forKey: Self.contentPanelWidthKey)
    }

    func selectPanelMode(_ mode: WorkbenchPanelMode) {
        guard panelMode != mode else {
            return
        }

        panelMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.panelModeKey)
    }

    func beginVideoSizeTransition() -> Bool {
        guard !isVideoSizeTransitionInProgress else {
            return false
        }

        isVideoSizeTransitionInProgress = true
        return true
    }

    func endVideoSizeTransition() {
        isVideoSizeTransitionInProgress = false
    }
}

@MainActor
final class AppState: ObservableObject {
    private static let selectedFolderPathsKey = "selectedFolderPaths"
    private static let playbackDecodeModeKey = "playbackDecodeMode"
    private static let playbackVolumeKey = "playbackVolume"
    private static let playbackLastNonzeroVolumeKey = "playbackLastNonzeroVolume"
    private static let playbackSpeedKey = "playbackSpeed"
    private static let playbackSubtitlesVisibleKey = "playbackSubtitlesVisible"
    private static let searchResultThumbnailsEnabledKey = "searchResultThumbnailsEnabled"
    private static let assSubtitlePreparationCueLimit = 8
    private static let searchPageSize = 100
    private static let searchPrefetchThreshold = 10
    private static let sidePanelLayoutTransitionNanoseconds: UInt64 = 180_000_000

    @Published var selectedFolders: [URL] = []
    @Published var indexingStatus: IndexingStatus = .idle
    @Published var searchQuery = ""
    @Published var topbarSearchContentMode: TopbarSearchContentMode = .workbench
    @Published var searchStatus: SearchStatus = .idle
    @Published var searchResults: [SubtitleSearchResult] = []
    @Published var searchResultTotalCount = 0
    @Published var searchFileSummaries: [SubtitleSearchFileSummary] = []
    @Published var hasMoreSearchResults = false
    @Published var libraryStatus: LibraryStatus = .idle
    @Published var libraryVideos: [LibraryVideo] = []
    @Published var collapsedSearchResultGroupPaths: Set<String> = []
    @Published var collapsedShioriGroupPaths: Set<String> = []
    @Published private(set) var libraryFolderGroups: [LibraryFolderGroup] = []
    @Published private(set) var libraryPresentationRevision = 0
    @Published private(set) var searchResultGroups: [SearchResultFileGroup] = []
    @Published private(set) var shioris: [Shiori] = []
    @Published private(set) var shioriFileGroups: [ShioriFileGroup] = []
    @Published private(set) var renderedSearchResultCount = 0
    @Published private(set) var searchNavigationSnapshot: SearchNavigationSnapshot?
    @Published private(set) var searchNavigationResultGroups: [SearchResultFileGroup] = []
    @Published private(set) var currentSubtitleEntries: [SubtitleDatabaseEntry] = []
    @Published private var expandedSearchResultGroupRowsByPath: [String: [SubtitleSearchResult]] = [:]
    @Published var selectedSearchResult: SubtitleSearchResult?
    @Published var selectedShiori: Shiori?
    @Published var selectedLibraryVideo: LibraryVideo?
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var isPlaybackSurfaceExpanded = false
    @Published var playbackDrawerRequest: PlaybackDrawerRequest?
    @Published var activeBottomPlaybackMenu: BottomPlaybackMenuKind?
    @Published var startupError: String?
    @Published var isSearchFocused = false
    @Published var playbackViewModel: PlaybackViewModel?
    @Published var playbackDecodeMode: PlaybackDecodeMode = .auto {
        didSet {
            userDefaults.set(playbackDecodeMode.rawValue, forKey: Self.playbackDecodeModeKey)
            player?.decodeMode = playbackDecodeMode
        }
    }
    @Published var searchResultThumbnailsEnabled = false {
        didSet {
            userDefaults.set(searchResultThumbnailsEnabled, forKey: Self.searchResultThumbnailsEnabledKey)
        }
    }

    let databaseURL: URL
    private var subtitleDatabase: SubtitleDatabase?
    let workbenchLayout: WorkbenchLayoutState
    let playbackFullscreenManager = PlaybackFullscreenManager()
    var playbackPlayer: PlaybackPlayer? {
        player
    }

    var hasSearchResultGroups: Bool {
        !searchResultGroups.isEmpty
    }

    var hasShioriFileGroups: Bool {
        !shioriFileGroups.isEmpty
    }

    var shioriCount: Int {
        shioris.count
    }

    var shioriFileCount: Int {
        shioriFileGroups.count
    }

    var searchResultFileCount: Int {
        searchFileSummaries.count
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
        !libraryFolderGroups.isEmpty
    }

    var hasPlaybackSelection: Bool {
        currentPlaybackVideoPath != nil
    }

    var currentPlaybackVideoPath: String? {
        selectedLibraryVideo?.videoPath ?? selectedSearchResult?.videoPath ?? selectedShiori?.videoPath
    }

    var currentPlaybackSubtitlePath: String? {
        selectedLibraryVideo?.subtitlePath ?? selectedSearchResult?.subtitlePath ?? selectedShiori?.subtitlePath
    }

    var currentPlaybackSubtitleFormat: SubtitleFormat? {
        selectedLibraryVideo?.subtitleFormat ?? selectedSearchResult?.subtitleFormat ?? selectedShiori?.subtitleFormat
    }

    var currentPlaybackTitle: String {
        selectedLibraryVideo?.videoName
            ?? selectedSearchResult?.videoName
            ?? selectedShiori?.videoName
            ?? "No video selected"
    }

    var currentPlaybackDisplayTitle: String {
        if let selectedLibraryVideo {
            return libraryFolderGroups
                .lazy
                .flatMap(\.videos)
                .first { $0.video.videoPath == selectedLibraryVideo.videoPath }?
                .displayTitle
                ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedLibraryVideo.subtitlePath)
        }

        if let selectedSearchResult {
            return searchResultGroups
                .first { $0.subtitlePath == selectedSearchResult.subtitlePath }?
                .subtitleDisplayTitle
                ?? searchFileSummaries
                    .first { $0.subtitlePath == selectedSearchResult.subtitlePath }?
                    .subtitleDisplayTitle
                ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedSearchResult.subtitlePath)
        }

        if let selectedShiori {
            return shioriFileGroups
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
        guard isSearchPlaybackActive, selectedSearchResult != nil else {
            return false
        }

        if let searchNavigationSnapshot {
            return searchNavigationSnapshot.previous != nil
        }

        return searchResultTotalCount > 1
    }

    var canOpenNextSearchResult: Bool {
        guard isSearchPlaybackActive, selectedSearchResult != nil else {
            return false
        }

        if let searchNavigationSnapshot {
            return searchNavigationSnapshot.next != nil
        }

        return searchResultTotalCount > 1
    }

    var isPlaybackFullscreenToggleDisabled: Bool {
        currentPlaybackVideoPath == nil || workbenchLayout.isVideoSizeTransitionInProgress
    }

    var isPlaybackSurfaceToggleDisabled: Bool {
        currentPlaybackVideoPath == nil || workbenchLayout.isVideoSizeTransitionInProgress
    }

    private let userDefaults: UserDefaults
    private var player: PlaybackPlayer?
    private let libraryPlaybackHistoryWriter: LibraryPlaybackHistoryWriter
    private var indexingTask: Task<Void, Never>?
    private var libraryTask: Task<Void, Never>?
    private var libraryPlaybackHistoryTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var searchNavigationTask: Task<Void, Never>?
    private var currentSubtitleEntriesTask: Task<Void, Never>?
    private var videoSizeTransitionTask: Task<Void, Never>?
    private var windowFrameBeforeUserZoom: NSRect?
    private var searchResultGroupTasks: [String: Task<Void, Never>] = [:]
    private var activeSearchPerformanceRun: SearchPerformanceRun?
    private var pendingSearchVisibleEntryIDs: Set<Int64> = []
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

        userDefaults.register(defaults: [
            "isWorkbenchContentPanelVisible": true,
            "workbenchContentPanelWidth": 420.0,
            "workbenchPanelMode": WorkbenchPanelMode.library.rawValue,
            "workbenchSidebarPosition": WorkbenchSidebarPosition.left.rawValue,
            Self.playbackDecodeModeKey: PlaybackDecodeMode.auto.rawValue,
            Self.playbackVolumeKey: 100.0,
            Self.playbackLastNonzeroVolumeKey: 100.0,
            Self.playbackSpeedKey: 1.0,
            Self.playbackSubtitlesVisibleKey: true,
            Self.searchResultThumbnailsEnabledKey: false
        ])
        workbenchLayout = WorkbenchLayoutState(userDefaults: userDefaults)

        selectedFolders = Self.loadSelectedFolders(from: userDefaults)
        playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)
        searchResultThumbnailsEnabled = userDefaults.bool(forKey: Self.searchResultThumbnailsEnabledKey)

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

        do {
            try database.reconcileIndexedContent(activeFolders: selectedFolders)
            try hydrateLibrarySynchronously(from: database)
            try hydrateShiorisSynchronously(from: database)
            let player = PlaybackPlayer()
            player.decodeMode = playbackDecodeMode
            self.player = player
            playbackViewModel = PlaybackViewModel(
                player: player,
                initialVolume: Self.loadPlaybackVolume(from: userDefaults),
                initialLastNonzeroVolume: Self.loadPlaybackLastNonzeroVolume(from: userDefaults),
                initialPlaybackSpeed: Self.loadPlaybackSpeed(from: userDefaults),
                initialSubtitlesVisible: userDefaults.bool(forKey: Self.playbackSubtitlesVisibleKey),
                onVolumeChanged: { volume in
                    userDefaults.set(volume, forKey: Self.playbackVolumeKey)
                },
                onLastNonzeroVolumeChanged: { volume in
                    userDefaults.set(volume, forKey: Self.playbackLastNonzeroVolumeKey)
                },
                onPlaybackSpeedChanged: { speed in
                    userDefaults.set(speed, forKey: Self.playbackSpeedKey)
                },
                onSubtitlesVisibleChanged: { isVisible in
                    userDefaults.set(isVisible, forKey: Self.playbackSubtitlesVisibleKey)
                }
            )
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
        guard let database = subtitleDatabase else {
            startupError = "Database is not initialized"
            return
        }
        do {
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
        guard isSearchFocused else {
            return
        }

        AppPerformanceProbe.measure("AppState.clearSearchFocus", thresholdMilliseconds: 4) {
            isSearchFocused = false
        }
    }

    func performUserInitiatedAppCommand(_ action: () -> Void) {
        AppPerformanceProbe.action("AppState.performUserInitiatedAppCommand", thresholdMilliseconds: 4) {
            clearSearchFocus()
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
        AppPerformanceProbe.action("AppState.activateWorkbenchPanelMode", thresholdMilliseconds: 4) {
            if workbenchLayout.panelMode == mode {
                toggleWorkbenchContentPanel()
                return
            }

            UIInvalidationProbe.mark(
                "ACTION UI.WorkbenchMode.selected",
                details: "from=\(workbenchLayout.panelMode.rawValue) to=\(mode.rawValue) visibleBefore=\(workbenchLayout.isContentPanelVisible)"
            )
            workbenchLayout.selectPanelMode(mode)

            guard !workbenchLayout.isContentPanelVisible else {
                return
            }

            guard beginVideoSizeTransition(durationNanoseconds: Self.sidePanelLayoutTransitionNanoseconds) else {
                return
            }

            withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
                workbenchLayout.showContentPanel()
            }
        }
    }

    func toggleWorkbenchContentPanel() {
        AppPerformanceProbe.action("AppState.toggleWorkbenchContentPanel", thresholdMilliseconds: 4) {
            guard beginVideoSizeTransition(durationNanoseconds: Self.sidePanelLayoutTransitionNanoseconds) else {
                return
            }

            UIInvalidationProbe.mark(
                "ACTION UI.WorkbenchContentPanel.toggled",
                details: "visibleBefore=\(workbenchLayout.isContentPanelVisible) mode=\(workbenchLayout.panelMode.rawValue)"
            )
            withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
                workbenchLayout.toggleContentPanel()
            }
        }
    }

    func togglePlaybackFullscreenFromUser(
        onCopySubtitle: @escaping () -> Void = {},
        onSaveShiori: @escaping () -> Void = {}
    ) {
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
            onSaveShiori: onSaveShiori,
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

    func togglePlaybackSurfaceFromUser() {
        guard hasPlaybackSelection else {
            return
        }

        guard beginVideoSizeTransition(durationNanoseconds: Self.sidePanelLayoutTransitionNanoseconds) else {
            return
        }

        if isPlaybackSurfaceExpanded {
            pausePlayback()
        }

        activeBottomPlaybackMenu = nil
        withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
            isPlaybackSurfaceExpanded.toggle()
        }
    }

    func expandPlaybackSurface() {
        guard hasPlaybackSelection, !isPlaybackSurfaceExpanded else {
            return
        }

        guard beginVideoSizeTransition(durationNanoseconds: Self.sidePanelLayoutTransitionNanoseconds) else {
            return
        }

        activeBottomPlaybackMenu = nil
        withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
            isPlaybackSurfaceExpanded = true
        }
    }

    func toggleBottomPlaybackMenu(_ menu: BottomPlaybackMenuKind) {
        activeBottomPlaybackMenu = activeBottomPlaybackMenu == menu ? nil : menu
    }

    func dismissBottomPlaybackMenu() {
        activeBottomPlaybackMenu = nil
    }

    func openPreviousLibraryVideo() {
        openAdjacentLibraryVideo(offset: -1)
    }

    func openNextLibraryVideo() {
        openAdjacentLibraryVideo(offset: 1)
    }

    func requestPlaybackDrawer(_ drawer: PlaybackDrawerKind) {
        guard hasPlaybackSelection else {
            return
        }

        if !isPlaybackSurfaceExpanded {
            guard beginVideoSizeTransition(durationNanoseconds: Self.sidePanelLayoutTransitionNanoseconds) else {
                return
            }

            withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
                isPlaybackSurfaceExpanded = true
            }
        }
        playbackDrawerRequest = PlaybackDrawerRequest(drawer: drawer)
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

    func updateWorkbenchContentPanelWidth(_ width: Double) {
        workbenchLayout.updateContentPanelWidth(width)
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
        indexingTask?.cancel()
        cancelDatabaseReadTasksBeforeIndexing()
        clearSearchAndPlaybackState(under: folder)
        indexingStatus = .indexing(folder)

        guard let database = subtitleDatabase else {
            indexingStatus = .failed(folder, "Database is not initialized")
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

        guard let database = subtitleDatabase else {
            indexingStatus = .failed(firstFolder, "Database is not initialized")
            return
        }
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

            do {
                try await Task.detached(priority: .userInitiated) {
                    try database.rebuildLibraryPresentationSnapshot()
                }.value
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexingStatus = .failed(firstFolder, Self.errorMessage(for: error))
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
        UIInvalidationProbe.mark(
            "ACTION UI.SearchQuery.changed",
            details: "length=\(query.count)"
        )
        searchQuery = query
        startSearch(query: query, offset: 0, appending: false, debounce: true)
    }

    func submitTopbarSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        UIInvalidationProbe.mark(
            "ACTION UI.TopbarSearch.submitted",
            details: "length=\(trimmedQuery.count)"
        )
        clearSearchFocus()
        if playbackViewModel?.isPlaying == true {
            pausePlayback()
        }
        topbarSearchContentMode = .results
        searchQuery = trimmedQuery
        searchNavigationSnapshot = nil
        searchNavigationResultGroups = []
        startSearch(query: trimmedQuery, offset: 0, appending: false, debounce: false)
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
        UIInvalidationProbe.mark(
            "ACTION UI.SearchResultGroup.toggled",
            details: "collapsedBefore=\(collapsedSearchResultGroupPaths.contains(subtitlePath))"
        )
        if collapsedSearchResultGroupPaths.contains(subtitlePath) {
            collapsedSearchResultGroupPaths.remove(subtitlePath)
            rebuildSearchResultGroups()
            revealInitialSearchResultGroupPage(for: subtitlePath)
        } else {
            collapsedSearchResultGroupPaths.insert(subtitlePath)
            rebuildSearchResultGroups()
        }
    }

    func collapseAllSearchResultGroups() {
        let groupPaths = Set(searchResultGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return
        }

        let collapsedPaths = collapsedSearchResultGroupPaths.union(groupPaths)
        guard collapsedPaths != collapsedSearchResultGroupPaths else {
            return
        }

        UIInvalidationProbe.mark(
            "ACTION UI.SearchResults.collapseAll",
            details: "groups=\(groupPaths.count)"
        )
        collapsedSearchResultGroupPaths = collapsedPaths
        rebuildSearchResultGroups()
    }

    func refreshLibrary() {
        libraryTask?.cancel()

        let folders = selectedFolders
        guard !folders.isEmpty else {
            applyLibraryPresentation([])
            libraryStatus = .idle
            return
        }

        libraryStatus = .loading
        guard let database = subtitleDatabase else {
            applyLibraryPresentation([])
            libraryStatus = .failed("Database is not initialized")
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
                libraryStatus = .completed
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                applyLibraryPresentation([])
                libraryStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    private func hydrateLibrarySynchronously(from database: SubtitleDatabase) throws {
        let folders = selectedFolders
        guard !folders.isEmpty else {
            applyLibraryPresentation([])
            libraryStatus = .idle
            return
        }

        let snapshot = try database.libraryPresentation(under: folders)
        applyLibraryPresentation(snapshot)
        libraryStatus = .completed
    }

    private func hydrateShiorisSynchronously(from database: SubtitleDatabase) throws {
        applyShioris(try database.shioris())
    }

    private func applyLibraryPresentation(_ snapshot: [LibraryFolderPresentation]) {
        let groups = Self.makeLibraryFolderGroups(from: snapshot)
        libraryFolderGroups = groups
        libraryVideos = groups.flatMap { group in
            group.videos.map(\.video)
        }
        libraryPresentationRevision += 1
        UIInvalidationProbe.count(
            "UI.LibraryPresentationSnapshot.rebuilt",
            details: "groups=\(groups.count) rows=\(libraryVideos.count)"
        )
    }

    private func removeLibraryPresentation(under folder: URL) {
        let groups = libraryFolderGroups.filter { group in
            !group.videos.contains { Self.path($0.video.videoPath, isUnder: folder) }
        }
        libraryFolderGroups = groups
        libraryVideos = groups.flatMap { group in
            group.videos.map(\.video)
        }
        libraryPresentationRevision += 1
        UIInvalidationProbe.count(
            "UI.LibraryPresentationSnapshot.rebuilt",
            details: "groups=\(groups.count) rows=\(libraryVideos.count) reason=remove"
        )
    }

    private func applyShioris(_ nextShioris: [Shiori]) {
        shioris = nextShioris.sorted(by: Self.shioriSort)
        rebuildShioriFileGroups()
    }

    private func rebuildShioriFileGroups() {
        shioriFileGroups = Self.makeShioriFileGroups(
            from: shioris,
            collapsedGroupPaths: collapsedShioriGroupPaths
        )
        UIInvalidationProbe.count(
            "UI.ShioriPresentation.rebuilt",
            details: "groups=\(shioriFileGroups.count) rows=\(shioris.count)"
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
        let folders = selectedFolders
        let pageSize = Self.searchPageSize
        if let activeSearchPerformanceRun {
            SearchPerformanceLogger.mark(activeSearchPerformanceRun, "search_superseded_by_new_search")
        }
        let searchPerformanceRun = SearchPerformanceLogger.startRun(
            queryLength: trimmedQuery.count,
            offset: offset,
            limit: pageSize,
            appending: appending,
            debounce: debounce,
            folderCount: folders.count
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
                groupCount: searchResultGroups.count,
                renderedRowCount: renderedSearchResultCount,
                status: "reset"
            )
        }

        guard !trimmedQuery.isEmpty else {
            searchStatus = .idle
            SearchPerformanceLogger.mark(searchPerformanceRun, "search_skipped_empty_query", status: "idle")
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }

        guard !folders.isEmpty else {
            searchStatus = .completed
            selectedSearchResult = nil
            SearchPerformanceLogger.mark(searchPerformanceRun, "search_skipped_no_folders", status: "completed")
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }

        searchStatus = .searching
        SearchPerformanceLogger.mark(searchPerformanceRun, "search_status_searching", status: "searching")

        guard let database = subtitleDatabase else {
            searchStatus = .failed("Database is not initialized")
            SearchPerformanceLogger.mark(
                searchPerformanceRun,
                "search_failed_no_database",
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
                let page = try await Task.detached(priority: .userInitiated) {
                    let databaseSearchStart = SearchPerformanceLogger.now()
                    let page = try database.searchPage(
                        trimmedQuery,
                        limit: pageSize,
                        offset: offset,
                        under: folders,
                        diagnostics: diagnosticsSink
                    )
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "database_search_returned",
                        phaseStart: databaseSearchStart,
                        resultCount: page.results.count,
                        totalCount: page.totalCount,
                        fileSummaryCount: page.fileSummaries.count
                    )
                    return page
                }.value
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "database_page_received_on_main",
                    resultCount: page.results.count,
                    totalCount: page.totalCount,
                    fileSummaryCount: page.fileSummaries.count
                )

                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled_after_database")
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
                    searchResults = page.results
                    loadedGlobalSearchResultCount = page.results.count
                }
                searchResultTotalCount = page.totalCount
                searchFileSummaries = page.fileSummaries
                hasMoreSearchResults = loadedGlobalSearchResultCount < page.totalCount
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_state_assigned",
                    phaseStart: stateAssignStart,
                    resultCount: searchResults.count,
                    totalCount: searchResultTotalCount,
                    fileSummaryCount: searchFileSummaries.count
                )

                let rebuildStart = SearchPerformanceLogger.now()
                rebuildSearchResultGroups()
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_groups_rebuilt",
                    phaseStart: rebuildStart,
                    resultCount: searchResults.count,
                    totalCount: searchResultTotalCount,
                    fileSummaryCount: searchFileSummaries.count,
                    groupCount: searchResultGroups.count,
                    renderedRowCount: renderedSearchResultCount
                )
                prepareSearchPerformanceVisibility(
                    for: searchPerformanceRun,
                    resultsAwaitingFirstAppearance: page.results
                )

                let completionStart = SearchPerformanceLogger.now()
                searchStatus = .completed
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_status_completed",
                    phaseStart: completionStart,
                    resultCount: searchResults.count,
                    totalCount: searchResultTotalCount,
                    fileSummaryCount: searchFileSummaries.count,
                    groupCount: searchResultGroups.count,
                    renderedRowCount: renderedSearchResultCount,
                    status: "completed"
                )
                if page.results.isEmpty {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_no_result_rows_to_render")
                    clearSearchPerformanceRunIfActive(searchPerformanceRun)
                }
            } catch is CancellationError {
                SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled")
                return
            } catch {
                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled_after_error")
                    return
                }

                if !appending {
                    let resetStart = SearchPerformanceLogger.now()
                    resetSearchResultLoadingState()
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "search_state_reset_after_error",
                        phaseStart: resetStart,
                        groupCount: searchResultGroups.count,
                        renderedRowCount: renderedSearchResultCount
                    )
                }
                hasMoreSearchResults = false
                let message = Self.errorMessage(for: error)
                searchStatus = .failed(message)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_failed",
                    status: "failed",
                    error: message
                )
                clearSearchPerformanceRunIfActive(searchPerformanceRun)
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
            resultCount: searchResults.count,
            totalCount: searchResultTotalCount,
            fileSummaryCount: searchFileSummaries.count,
            groupCount: searchResultGroups.count,
            renderedRowCount: renderedSearchResultCount,
            entryID: result.entryID
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

    func openSearchResult(_ result: SubtitleSearchResult) {
        UIInvalidationProbe.mark(
            "ACTION UI.SearchResult.opened",
            details: "time=\(String(format: "%.2f", Double(result.startMilliseconds) / 1000.0))"
        )
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        selectedSearchResult = result
        selectedShiori = nil
        selectedLibraryVideo = nil
        topbarSearchContentMode = .results
        activeBottomPlaybackMenu = nil
        withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
            isPlaybackSurfaceExpanded = true
        }
        searchNavigationSnapshot = nil
        searchNavigationResultGroups = []
        Task { @MainActor in
            await Task.yield()
            play(result)
        }
    }

    func openLibraryVideo(_ video: LibraryVideo) {
        UIInvalidationProbe.mark(
            "ACTION UI.LibraryVideo.opened",
            details: "duration=\(video.duration.map { String(format: "%.2f", $0) } ?? "unknown")"
        )
        if case .library = activePlaybackSource {
            saveCurrentLibraryPlaybackHistory()
        }
        selectedLibraryVideo = video
        selectedSearchResult = nil
        selectedShiori = nil
        topbarSearchContentMode = .workbench
        activeBottomPlaybackMenu = nil
        withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
            isPlaybackSurfaceExpanded = true
        }
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
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        selectedShiori = shiori
        selectedSearchResult = nil
        selectedLibraryVideo = nil
        topbarSearchContentMode = .workbench
        activeBottomPlaybackMenu = nil
        withAnimation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration)) {
            isPlaybackSurfaceExpanded = true
        }
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
            refreshSearchNavigationSnapshot()
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

    func play(_ shiori: Shiori) {
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        playbackStatus = .opening
        let subtitleCues = playbackSubtitleCues(for: shiori)
        playbackViewModel?.setSubtitleCues(
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
            playbackStatus = .playing
        } catch {
            playbackViewModel?.clearSubtitleCues()
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func pausePlayback() {
        do {
            try player?.setPaused(true)
            if hasPlaybackSelection {
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
            if hasPlaybackSelection {
                playbackStatus = .playing
            }
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func togglePlayback() {
        switch playbackStatus {
        case .playing, .paused:
            if playbackViewModel?.isPlaying == true {
                pausePlayback()
            } else {
                resumePlayback()
            }
        case .idle:
            if let selectedSearchResult {
                play(selectedSearchResult)
            } else if let selectedLibraryVideo {
                play(selectedLibraryVideo)
            } else if let selectedShiori {
                play(selectedShiori)
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
            currentSubtitleEntries = []
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

                self?.currentSubtitleEntries = entries
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load current subtitle entries: \(error)")
                self?.currentSubtitleEntries = []
            }
        }
    }

    @discardableResult
    func copyCurrentSubtitleToClipboard() -> Bool {
        guard let currentPlaybackSubtitlePath, let playbackViewModel else {
            playbackViewModel?.showSubtitleCopyFeedback(copied: false)
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
              let playbackViewModel
        else {
            playbackViewModel?.showShioriFeedback(.unavailable)
            return false
        }

        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        let videoFile = URL(fileURLWithPath: currentPlaybackVideoPath)
        let videoName = selectedLibraryVideo?.videoName
            ?? selectedSearchResult?.videoName
            ?? selectedShiori?.videoName
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
            togglePlaybackFullscreenFromUser(
                onCopySubtitle: { [weak self] in
                    self?.copyCurrentSubtitleToClipboard()
                },
                onSaveShiori: { [weak self] in
                    self?.toggleCurrentShiori()
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
            isPlaybackSurfaceExpanded = false
            playbackDrawerRequest = nil
            playbackStatus = .idle
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
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
            details: "collapsedBefore=\(collapsedShioriGroupPaths.contains(subtitlePath))"
        )
        if collapsedShioriGroupPaths.contains(subtitlePath) {
            collapsedShioriGroupPaths.remove(subtitlePath)
        } else {
            collapsedShioriGroupPaths.insert(subtitlePath)
        }
        rebuildShioriFileGroups()
    }

    func collapseAllShioriGroups() {
        let groupPaths = Set(shioriFileGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return
        }

        let collapsedPaths = collapsedShioriGroupPaths.union(groupPaths)
        guard collapsedPaths != collapsedShioriGroupPaths else {
            return
        }

        UIInvalidationProbe.mark(
            "ACTION UI.Shiori.collapseAll",
            details: "groups=\(groupPaths.count)"
        )
        collapsedShioriGroupPaths = collapsedPaths
        rebuildShioriFileGroups()
    }

    private func saveCurrentLibraryPlaybackHistory(waitUntilFinished: Bool) {
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

    private func loadSearchNavigationSnapshot(opening direction: SearchResultNavigationDirection?) {
        searchNavigationTask?.cancel()

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty,
              !selectedFolders.isEmpty,
              let database = subtitleDatabase
        else {
            searchNavigationSnapshot = nil
            searchNavigationResultGroups = []
            return
        }

        let folders = selectedFolders
        let anchor = currentSearchNavigationAnchor()
        searchNavigationTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.searchNavigationSnapshot(
                        trimmedQuery,
                        under: folders,
                        anchor: anchor,
                        radius: 1
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

                if let target {
                    self.openSearchResult(target)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load Search navigation snapshot: \(error)")
                self?.searchNavigationSnapshot = nil
                self?.searchNavigationResultGroups = []
            }
        }
    }

    private func currentSearchNavigationAnchor() -> SearchNavigationAnchor {
        let milliseconds = max(
            0,
            Int(((playbackViewModel?.currentTime ?? 0) * 1_000).rounded(.down))
        )

        return SearchNavigationAnchor(
            selectedEntryID: selectedSearchResult?.entryID,
            videoPath: currentPlaybackVideoPath,
            subtitlePath: currentPlaybackSubtitlePath,
            currentMilliseconds: milliseconds
        )
    }

    private func applySearchNavigationSnapshot(_ snapshot: SearchNavigationSnapshot) {
        searchNavigationSnapshot = snapshot
        let paths = Set(snapshot.neighborhood.map(\.subtitlePath))
        let summaries = searchFileSummaries.filter { paths.contains($0.subtitlePath) }
        searchNavigationResultGroups = Self.makeSearchResultGroups(
            results: snapshot.neighborhood,
            fileSummaries: summaries,
            expandedRowsByPath: [:],
            collapsedGroupPaths: []
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
              let selectedLibraryVideo,
              let currentIndex = libraryVideos.firstIndex(where: { $0.videoPath == selectedLibraryVideo.videoPath })
        else {
            return nil
        }

        let targetIndex = currentIndex + offset
        guard libraryVideos.indices.contains(targetIndex) else {
            return nil
        }

        return libraryVideos[targetIndex]
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
        removeLibraryPresentation(under: folder)
        expandedSearchResultGroupRowsByPath = expandedSearchResultGroupRowsByPath.filter { path, _ in
            !Self.path(path, isUnder: folder)
        }
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
        let selectedShioriIsUnderFolder = selectedShiori.map {
            Self.path($0.videoPath, isUnder: folder)
        } ?? false

        if selectedSearchResultIsUnderFolder || selectedLibraryVideoIsUnderFolder || selectedShioriIsUnderFolder {
            selectedSearchResult = nil
            selectedLibraryVideo = nil
            selectedShiori = nil
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
        guard let database = subtitleDatabase else {
            return
        }
        let pageSize = Self.searchPageSize
        searchResultGroupTasks[subtitlePath] = Task { [weak self] in
            do {
                let results = try await Task.detached(priority: .userInitiated) {
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
        searchNavigationTask?.cancel()
        searchResults = []
        searchResultTotalCount = 0
        searchFileSummaries = []
        hasMoreSearchResults = false
        collapsedSearchResultGroupPaths = []
        expandedSearchResultGroupRowsByPath = [:]
        loadedGlobalSearchResultCount = 0
        searchNavigationSnapshot = nil
        searchNavigationResultGroups = []
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
        UIInvalidationProbe.count(
            "UI.SearchPresentation.rebuilt",
            details: "groups=\(searchResultGroups.count) rows=\(renderedSearchResultCount)"
        )
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
        searchNavigationTask?.cancel()
        searchNavigationTask = nil
        currentSubtitleEntriesTask?.cancel()
        currentSubtitleEntriesTask = nil
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
