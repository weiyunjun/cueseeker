import AppKit
import Combine
import Foundation
import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

/// Workflow coordinator. Holds references to the per-domain stores (settings,
/// indexing, workbenchLayout, excerpt, library, search, playback) and owns the
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
    static let searchNavigationPanelRadius = 120
    nonisolated static let playbackSubtitleWindowRadius = 80
    static let databaseCompactionMinimumReclaimableBytes: Int64 = 100 * 1024 * 1024
    static let databaseCompactionMinimumFreelistRatio = 0.25

    @Published var startupError: String?
    let uiProbeScope: String
    let settings: SettingsStore
    let indexing: IndexingStore
    let excerpt: ExcerptStore
    let library: LibraryStore
    let search: SearchStore
    let cueContent: CueContentStore
    let playback: PlaybackStore
    let toast = ToastCenter()
    let confirmation = ConfirmationCenter()
    let filterDialog = CueFacetFilterDialogCenter()
    let tasks: TaskQueueStore
    let interfaceLayers = InterfaceLayerRegistry()
    var settingsCancellables: Set<AnyCancellable> = []
    private var interfaceLayerCancellables: Set<AnyCancellable> = []

    let databaseURL: URL
    let libraryCoverDirectory: URL
    let playbackSubtitleFocusDatabaseReader: PlaybackSubtitleFocusDatabaseReader
    var indexingDatabase: IndexingDatabase?
    let playbackSubtitleDatabase: PlaybackSubtitleDatabase?
    let libraryDatabase: LibraryDatabase?
    let indexedContentDatabase: IndexedContentDatabase?
    let libraryCoverDatabase: LibraryCoverDatabase?
    let excerptDatabase: ExcerptDatabase?
    let taskRecordDatabase: TaskRecordDatabase?
    let libraryUserCoverService: LibraryUserCoverService?
    let excerptListCoverStorage: ExcerptListCoverStorage
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

    static func makeExcerptFileGroups(
        from excerpts: [Excerpt],
        collapsedGroupPaths: Set<String>
    ) -> [ExcerptFileGroup] {
        let excerptsByPath = Dictionary(grouping: excerpts, by: \.subtitlePath)
        let displayTitlesByPath = Dictionary(
            uniqueKeysWithValues: excerptsByPath.keys.map { path in
                (
                    path,
                    SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: path)
                )
            }
        )

        return excerptsByPath.keys.sorted { lhs, rhs in
            let lhsDisplayTitle = displayTitlesByPath[lhs] ?? URL(fileURLWithPath: lhs).lastPathComponent
            let rhsDisplayTitle = displayTitlesByPath[rhs] ?? URL(fileURLWithPath: rhs).lastPathComponent
            let displayTitleComparison = SubtitleDisplayTitleResolver.compareDisplayTitles(lhsDisplayTitle, rhsDisplayTitle)
            if displayTitleComparison != .orderedSame {
                return displayTitleComparison == .orderedAscending
            }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        .map { path in
            ExcerptFileGroup(
                subtitlePath: path,
                subtitleDisplayTitle: displayTitlesByPath[path] ?? URL(fileURLWithPath: path).lastPathComponent,
                excerpts: (excerptsByPath[path] ?? []).sorted(by: Self.excerptSort),
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
        library.selectedLibraryVideo?.videoPath ?? search.selectedSearchResult?.videoPath ?? excerpt.selectedExcerpt?.videoPath
    }

    var currentPlaybackSubtitlePath: String? {
        library.selectedLibraryVideo?.subtitlePath ?? search.selectedSearchResult?.subtitlePath ?? excerpt.selectedExcerpt?.subtitlePath
    }

    var currentPlaybackSubtitleFileID: Int64? {
        library.selectedLibraryVideo?.subtitleFileID
            ?? search.selectedSearchResult?.subtitleFileID
            ?? excerpt.selectedExcerpt?.subtitleFileID
    }

    var currentPlaybackSubtitleFormat: SubtitleFormat? {
        library.selectedLibraryVideo?.subtitleFormat ?? search.selectedSearchResult?.subtitleFormat ?? excerpt.selectedExcerpt?.subtitleFormat
    }

    var currentPlaybackTitle: String {
        library.selectedLibraryVideo?.videoName
            ?? search.selectedSearchResult?.videoName
            ?? excerpt.selectedExcerpt?.videoName
            ?? L("playback.no_video_selected")
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
        return playbackDisplayTitle(
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
            fallback: search.searchFileSummaries
                .first { $0.subtitlePath == selectedSearchResult.subtitlePath }?
                .subtitleDisplayTitle
            ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedSearchResult.subtitlePath)
        )
    }

    func playbackDisplayTitle(
        for selectedExcerpt: Excerpt,
        providedDisplayTitle: String? = nil
    ) -> String {
        let residentDisplayTitle = excerpt.residentRelations
            .first { $0.id == selectedExcerpt.id }
            .flatMap { cueContent.content(for: $0.cueID)?.displayTitle }
        return playbackDisplayTitle(
            providedDisplayTitle: providedDisplayTitle,
            fallback: residentDisplayTitle
            ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: selectedExcerpt.subtitlePath)
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
        guard isSearchPlaybackActive,
              !isCueDeepLinkPlaybackSource,
              let selectedSearchResult = search.selectedSearchResult
        else {
            return false
        }

        if let context = activePlaybackSearchPlaylistContext {
            let ordinal = context.selectedOrdinal
            let totalCount = playback.playlistSource?.boundary.totalCount ?? 0
            return ordinal > 0 && ordinal < totalCount
        }

        if let searchNavigationSnapshot = search.searchNavigationSnapshot {
            return searchNavigationSnapshot.previous != nil
        }

        return selectedSearchResult.searchRank > 0
    }

    var canOpenNextSearchResult: Bool {
        guard isSearchPlaybackActive,
              !isCueDeepLinkPlaybackSource,
              let selectedSearchResult = search.selectedSearchResult
        else {
            return false
        }

        if let context = activePlaybackSearchPlaylistContext {
            let ordinal = context.selectedOrdinal
            let totalCount = playback.playlistSource?.boundary.totalCount ?? 0
            return ordinal + 1 < totalCount
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
        case .excerpt:
            return canOpenPreviousExcerpt
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
        case .excerpt:
            openPreviousExcerpt()
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
        case .excerpt:
            return canOpenNextExcerpt
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
        case .excerpt:
            openNextExcerpt()
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
        indexingDatabase != nil
            && !indexing.indexingStatus.isIndexing
            && !indexing.folderRemovalStatus.isRemoving
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
    var folderRemovalTask: Task<Void, Never>?
    var excerptNeedsReloadAfterIndexedContentMutation = false
    var libraryTask: Task<Void, Never>?
    var recentWatchingTask: Task<Void, Never>?
    var testRecentWatchingTask: Task<Void, Never>?
    var completeLibraryTask: Task<Void, Never>?
    var completeLibraryFolderDetailTasks: [String: Task<Void, Never>] = [:]
    var completeLibraryFolderDetailRequestIDs: [String: UUID] = [:]
    var completeLibraryFolderDetailGeneration: UInt64 = 0
    let libraryDisplayRenditionCommitGate = LibraryCoverDisplayRenditionCommitGate()
    var libraryDisplayRenditionTask: Task<Void, Never>?
    var libraryDisplayRenditionAttemptedScopeKey: String?
    var libraryDisplayRenditionGeneration = 0
    var libraryCoverImportTask: Task<Void, Never>?
    var libraryCoverSaveTask: Task<Void, Never>?
    var excerptListCoverImportTask: Task<Void, Never>?
    var excerptListSaveTask: Task<Void, Never>?
    var excerptListOverviewTask: Task<Void, Never>?
    var excerptTableRowsTask: Task<Void, Never>?
    var libraryPlaybackHistoryTask: Task<Void, Never>?
    var playbackSubtitleFocusInitialLoadTask: Task<Void, Never>?
    var playbackSubtitleFocusCompleteLoadTask: Task<Void, Never>?
    var playbackSubtitleFocusActionTask: Task<Void, Never>?
    var playbackSubtitleFocusActionGeneration = 0
    var databaseStorageStatsTask: Task<Void, Never>?
    var databaseCompactionTask: Task<Void, Never>?
    var videoSizeTransitionTask: Task<Void, Never>?
    var windowFrameBeforeUserZoom: NSRect?
    var excerptPlaybackNavigationScopeIDs: [Int64]?
    var excerptPlaybackNavigationSnapshot: (currentID: Int64, previousID: Int64?, nextID: Int64?)?
    var activePlaybackSource: ActivePlaybackSource = .none
    var currentCueAutoStopReached = false
    var cuePlaybackGeneration = 0
    var activeCueAutoPauseBoundary: PlaybackAutoStopBoundary?
    var cueAutoPauseArmed = false
    var activePlaylistCueSettings: PlaylistCueEffectiveSettings?
    var activePlaylistCuePosition: PlaybackPlaylistPosition?
    var libraryPlaybackCompletedMilestoneVideoPath: String?
    var libraryPlaybackFinishMetadata: SubtitlePlaybackFinishMetadata?
    var pendingLibraryPlaybackHistoryPresentationVideoPaths: Set<String> = []
    var autoSwitchCueSequenceTask: Task<Void, Never>?
    var autoSwitchCueSequenceGeneration = 0
    var pendingURLSchemeDirectPlayIntent: URLSchemeDirectPlayIntent?
    var pendingURLSchemeCuePlaybackIntent: URLSchemeCuePlaybackIntent?
    var urlSchemeCueLookupTask: Task<Void, Never>?
    let libraryFolderRemovalExecutor: any LibraryFolderRemovalExecuting

    init(
        userDefaults: UserDefaults? = nil,
        databaseURL: URL? = nil,
        uiProbeScope: String = UUID().uuidString,
        libraryFolderRemovalExecutor: any LibraryFolderRemovalExecuting = LibraryFolderRemovalExecutor()
    ) {
        let userDefaults = userDefaults ?? ApplicationPersistence.sharedUserDefaults()
        self.uiProbeScope = uiProbeScope
        self.userDefaults = userDefaults
        let resolvedDatabaseURL = databaseURL ?? Self.defaultDatabaseURL()
        let resolvedLibraryCoverDirectory = resolvedDatabaseURL
            .deletingLastPathComponent()
            .appendingPathComponent("Covers", isDirectory: true)
        self.databaseURL = resolvedDatabaseURL
        self.libraryCoverDirectory = resolvedLibraryCoverDirectory
        self.excerptListCoverStorage = ExcerptListCoverStorage(
            coverDirectory: resolvedLibraryCoverDirectory
        )
        self.libraryFolderRemovalExecutor = libraryFolderRemovalExecutor
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
        library = LibraryStore()
        let cueContentStore = CueContentStore()
        cueContent = cueContentStore
        excerpt = ExcerptStore(
            cueContentStore: cueContentStore,
            uiProbeScope: uiProbeScope
        )
        playback = PlaybackStore(
            userDefaults: userDefaults,
            interfaceLayers: interfaceLayers
        )

        var openedDatabase: IndexingDatabase?
        var openedSearchDatabase: SearchDatabase?
        var openedPlaybackSubtitleDatabase: PlaybackSubtitleDatabase?
        var openedLibraryDatabase: LibraryDatabase?
        var openedIndexedContentDatabase: IndexedContentDatabase?
        var openedLibraryCoverDatabase: LibraryCoverDatabase?
        var openedExcerptDatabase: ExcerptDatabase?
        var openedTaskRecordDatabase: TaskRecordDatabase?
        var initialError: Error?
        do {
            try Self.prepareDatabaseDirectory(for: self.databaseURL)
            try DatabaseBootstrap.prepare(at: self.databaseURL)
            let database = try IndexingDatabase(path: self.databaseURL)
            openedDatabase = database
            openedSearchDatabase = try SearchDatabase(path: self.databaseURL)
            openedPlaybackSubtitleDatabase = try PlaybackSubtitleDatabase(path: self.databaseURL)
            openedLibraryDatabase = try LibraryDatabase(path: self.databaseURL)
            openedIndexedContentDatabase = try IndexedContentDatabase(path: self.databaseURL)
            openedLibraryCoverDatabase = try LibraryCoverDatabase(path: self.databaseURL)
            openedExcerptDatabase = try ExcerptDatabase(path: self.databaseURL)
            openedTaskRecordDatabase = try TaskRecordDatabase(path: self.databaseURL)
            initialError = nil
        } catch {
            openedDatabase = nil
            openedSearchDatabase = nil
            openedPlaybackSubtitleDatabase = nil
            openedLibraryDatabase = nil
            openedIndexedContentDatabase = nil
            openedLibraryCoverDatabase = nil
            openedExcerptDatabase = nil
            openedTaskRecordDatabase = nil
            initialError = error
        }
        if let openedExcerptDatabase {
            do {
                try ExcerptListCoverStorage.adoptPreRenameCovers(
                    coverDirectory: resolvedLibraryCoverDirectory,
                    database: openedExcerptDatabase
                )
            } catch {
                print("Failed to copy pre-rename Excerpt list covers: \(error)")
            }
        }

        self.indexingDatabase = openedDatabase
        search = SearchStore(
            cueContentStore: cueContentStore,
            databaseURL: resolvedDatabaseURL,
            database: openedSearchDatabase,
            uiProbeScope: uiProbeScope
        )
        search.updateSearchFacetFilter(settings.searchFacetFilter)
        _ = search.updateFolderScope(indexing.selectedFolders)
        self.playbackSubtitleDatabase = openedPlaybackSubtitleDatabase
        self.libraryDatabase = openedLibraryDatabase
        self.indexedContentDatabase = openedIndexedContentDatabase
        self.libraryCoverDatabase = openedLibraryCoverDatabase
        self.excerptDatabase = openedExcerptDatabase
        self.taskRecordDatabase = openedTaskRecordDatabase
        self.tasks = TaskQueueStore(database: openedTaskRecordDatabase)
        self.libraryUserCoverService = openedLibraryCoverDatabase.map { database in
            LibraryUserCoverService(
                database: database,
                coverDirectory: resolvedLibraryCoverDirectory
            )
        }
        libraryPlaybackHistoryWriter = LibraryPlaybackHistoryWriter(database: openedLibraryDatabase)
        configureRenameRunner()

        if let initialError {
            startupError = Self.errorMessage(for: initialError)
            return
        }

        guard openedDatabase != nil else {
            return
        }

        let initialExcerptListID = try? openedExcerptDatabase?.firstExcerptListID()
        if let initialExcerptListID {
            excerpt.updateTableFacetFilter(
                settings.excerptFacetFilter(forListID: initialExcerptListID)
            )
        }
        excerpt.setActiveListID(initialExcerptListID)
        excerpt.setRecentSaveListID(settings.recentExcerptSaveListID)
        tasks.loadPersistedRecords()
        setupSettingsObservers()
        setupInterfaceLayerObservers()
    }

    /// Edit Cover, the Excerpt List Editor, Rename, Filter, the Task panel and
    /// Confirmation are the dialog layer. Their open state lives on the
    /// stores, so the registry follows them.
    private func setupInterfaceLayerObservers() {
        let isEditorOrPanelOpen = Publishers.CombineLatest4(
            library.$coverEditingSession,
            excerpt.$listEditorSession,
            confirmation.$session,
            tasks.$isPanelOpen
        )
        .map { coverEditing, listEditor, confirmation, isTaskPanelOpen in
            coverEditing != nil || listEditor != nil || confirmation != nil
                || isTaskPanelOpen
        }
        Publishers.CombineLatest3(
            isEditorOrPanelOpen,
            library.$renameSession.map { $0 != nil },
            filterDialog.$session.map { $0 != nil }
        )
        .map { $0 || $1 || $2 }
        .removeDuplicates()
        .sink { [interfaceLayers] isDialogOpen in
            interfaceLayers.setOpen(.dialog, isDialogOpen)
            guard isDialogOpen,
                  let window = NSApplication.shared.keyWindow,
                  let pageFocus = Self.focusOwner(in: window)
            else {
                return
            }
            // The page gives its focus up as the dialog opens, the way it does
            // for a menu, so nothing it had focused comes back when the dialog
            // closes. This runs before the store keeps the open state, and a
            // field giving its focus up redraws the window at once: given up
            // here, that redraw reads the dialog as closed and nothing draws
            // it until something else changes. So the focus is given up once
            // the state is kept, and only while the page still holds it: a
            // dialog that focused its own field on appearing keeps it.
            Task { @MainActor in
                guard Self.focusOwner(in: window) === pageFocus else {
                    return
                }
                window.makeFirstResponder(nil)
            }
        }
        .store(in: &interfaceLayerCancellables)

        // A Confirmation is the one dialog that keeps the App open, and it is
        // always the top one. The quit half of the rule is the App delegate's.
        confirmation.$session
            .map { $0 == nil }
            .removeDuplicates()
            .sink { isClosable in
                AppWindowControls.setCloseEnabled(isClosable)
            }
            .store(in: &interfaceLayerCancellables)
    }

    /// The control that holds the window's keyboard, or nil when nothing does.
    /// Every text field in a window edits through the one field editor, so
    /// the field it is editing answers for it.
    private static func focusOwner(in window: NSWindow) -> NSResponder? {
        guard let responder = window.firstResponder, responder !== window else {
            return nil
        }
        if let editor = responder as? NSTextView,
           editor.isFieldEditor,
           let field = editor.delegate as? NSResponder {
            return field
        }
        return responder
    }

    func setupSettingsObservers() {
        indexing.$selectedFolders
            .dropFirst()
            .sink { [weak self] folders in
                guard let self,
                      search.updateFolderScope(folders)
                else {
                    return
                }
                refreshCurrentSearch(
                    clearExistingResults: true,
                    folderScopeOverride: folders
                )
            }
            .store(in: &settingsCancellables)

        // The remembered save target is answered from the store, and settings
        // keep whatever it currently is — both the list a save just went to and
        // the nil left behind when that list is deleted.
        excerpt.$recentSaveListID
            .removeDuplicates()
            .sink { [settings] listID in
                settings.setRecentExcerptSaveListID(listID)
            }
            .store(in: &settingsCancellables)

        playback.$playlistSource
            .dropFirst()
            .sink { [weak self] source in
                guard let self else {
                    return
                }
                guard let source,
                      case .excerpt = source.origin
                else {
                    self.excerptPlaybackNavigationScopeIDs = nil
                    self.excerptPlaybackNavigationSnapshot = nil
                    return
                }
            }
            .store(in: &settingsCancellables)

        playback.$playlistSource
            .map { source -> AnyPublisher<PlaybackPlaylistSourceBoundary?, Never> in
                guard let source else {
                    return Just(nil).eraseToAnyPublisher()
                }
                return source.$boundary
                    .map(Optional.some)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [weak self] boundary in
                self?.playbackPlaylistBoundaryDidChange(boundary)
            }
            .store(in: &settingsCancellables)

        settings.$playbackDecodeMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.player?.decodeMode = mode
            }
            .store(in: &settingsCancellables)

        settings.$srtSubtitleStyle
            .sink { [weak self] style in
                self?.player?.srtSubtitleStyle = style
                self?.playback.srtSubtitleStyle = style
            }
            .store(in: &settingsCancellables)

    }

    nonisolated static func runCancellableDetached<T: Sendable>(
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

    /// A Sidebar item opens its section's first level. On its own section it
    /// does nothing, whichever level is open.
    func activateWorkbenchPanelMode(_ mode: WorkbenchPanelMode) {
        AppPerformanceProbe.action("AppCoordinator.activateWorkbenchPanelMode", thresholdMilliseconds: 4) {
            if workbenchLayout.panelMode == mode {
                return
            }

            UIInvalidationProbe.mark(
                "ACTION UI.WorkbenchMode.selected",
                details: "from=\(workbenchLayout.panelMode.rawValue) to=\(mode.rawValue)"
            )
            navigateWorkbench(to: .firstLevel(of: mode))
        }
    }

    /// Shows a Workbench page as one step of the history.
    func navigateWorkbench(to route: WorkbenchRoute) {
        guard workbenchLayout.currentRoute != route else {
            return
        }

        workbenchLayout.navigate(to: route)
        prepareWorkbenchRoute(route)
    }

    func goBackInWorkbench() {
        guard workbenchLayout.route.canGoBack else {
            return
        }

        workbenchLayout.goBack()
        prepareWorkbenchRoute(workbenchLayout.currentRoute)
    }

    func goForwardInWorkbench() {
        guard workbenchLayout.route.canGoForward else {
            return
        }

        workbenchLayout.goForward()
        prepareWorkbenchRoute(workbenchLayout.currentRoute)
    }

    /// The data a page needs that its own view does not load: the Excerpt
    /// overview, and the list a Excerpt detail shows in its table.
    private func prepareWorkbenchRoute(_ route: WorkbenchRoute) {
        switch route {
        case .excerpt:
            loadExcerptListOverviewIfNeeded()
        case .excerptList(let id):
            guard !isWorkbenchRouteUnknown(route) else {
                return
            }
            excerpt.updateTableFacetFilter(
                settings.excerptFacetFilter(forListID: id)
            )
            excerpt.setActiveListID(id)
            reloadExcerptTableRows()
        case .search, .recent, .library, .libraryFolder, .file:
            break
        }
    }

    /// Whether the page a history entry points to is gone: a Excerpt list that
    /// was deleted, or a Library folder that is no longer indexed. Unknown is
    /// never claimed before the store that would know has loaded.
    func isWorkbenchRouteUnknown(_ route: WorkbenchRoute) -> Bool {
        switch route {
        case .libraryFolder(let folderPath):
            guard library.completeLibraryStatus == .completed else {
                return false
            }
            return !library.completeLibraryFolderSummaries.contains {
                $0.folderPath == folderPath
            }
        case .excerptList(let id):
            return excerpt.hasLoadedListOverview
                && !excerpt.listOverview.lists.contains { $0.id == id }
        case .search, .recent, .library, .file, .excerpt:
            return false
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
        let remainingSearchResults = search.searchResults.filter {
            !Self.path($0.subtitlePath, isUnder: folder)
        }
        let remainingFileSummaries = search.searchFileSummaries.filter {
            !Self.path($0.subtitlePath, isUnder: folder)
        }
        let remainingResultCount = remainingFileSummaries.reduce(0) { $0 + $1.matchCount }
        search.replaceResultState(
            results: remainingSearchResults,
            orderedCueIDs: remainingSearchResults.map(\.entryID),
            status: search.searchStatus,
            totalCount: remainingResultCount,
            fileSummaries: remainingFileSummaries,
            countState: .exact,
            knownResultCount: remainingResultCount,
            knownFileCount: remainingFileSummaries.count,
            hasMore: false,
            loadedResultCount: remainingSearchResults.count,
            nextCursor: nil
        )
        removeLibraryPresentation(under: folder)
        removeCompleteLibraryPresentation(under: folder)

        let selectedSearchResultIsUnderFolder = search.selectedSearchResult.map {
            Self.path($0.subtitlePath, isUnder: folder)
        } ?? false
        let selectedLibraryVideoIsUnderFolder = library.selectedLibraryVideo.map {
            Self.path($0.videoPath, isUnder: folder)
        } ?? false
        let selectedExcerptIsUnderFolder = excerpt.selectedExcerpt.map {
            Self.path($0.videoPath, isUnder: folder)
        } ?? false

        if selectedSearchResultIsUnderFolder || selectedLibraryVideoIsUnderFolder || selectedExcerptIsUnderFolder {
            search.selectResult(nil)
            library.selectedLibraryVideo = nil
            excerpt.selectedExcerpt = nil
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

    static func excerptSort(_ lhs: Excerpt, _ rhs: Excerpt) -> Bool {
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
        aggregateResult.changedSubtitlePaths = Array(
            Set(aggregateResult.changedSubtitlePaths)
                .union(result.changedSubtitlePaths)
        ).sorted()
        aggregateResult.affectedVideoPaths = Array(
            Set(aggregateResult.affectedVideoPaths)
                .union(result.affectedVideoPaths)
        ).sorted()
        aggregateResult.affectedFolderPaths = Array(
            Set(aggregateResult.affectedFolderPaths)
                .union(result.affectedFolderPaths)
        ).sorted()
        aggregateResult.clearedCueChangeNotices =
            aggregateResult.clearedCueChangeNotices
            || result.clearedCueChangeNotices
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
