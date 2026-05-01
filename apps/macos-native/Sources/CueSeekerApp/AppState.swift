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

@MainActor
final class AppState: ObservableObject {
    private static let selectedFolderPathsKey = "selectedFolderPaths"
    private static let isSidebarVisibleKey = "isSidebarVisible"
    private static let isPlaybackInspectorVisibleKey = "isPlaybackInspectorVisible"
    private static let playbackInspectorWidthKey = "playbackInspectorWidth"
    private static let playbackDecodeModeKey = "playbackDecodeMode"
    private static let continuousPlaybackSentenceCountKey = "continuousPlaybackSentenceCount"
    private static let continuousPlaybackPrecedingSentenceCountKey = "continuousPlaybackPrecedingSentenceCount"

    @Published var selectedSection: AppSection = .search
    @Published var selectedFolders: [URL] = []
    @Published var indexingStatus: IndexingStatus = .idle
    @Published var searchQuery = ""
    @Published var searchStatus: SearchStatus = .idle
    @Published var searchResults: [SubtitleSearchResult] = []
    @Published var selectedSearchResult: SubtitleSearchResult?
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var startupError: String?
    @Published var isSidebarVisible = true
    @Published var isPlaybackInspectorVisible = false
    @Published var playbackInspectorWidth: Double = 520
    @Published var isSearchFocused = false
    @Published var playbackViewModel: PlaybackViewModel?
    @Published private(set) var continuousPlaybackSettings = ContinuousPlaybackSettings()
    @Published var isContinuousPlaybackEnabled = false {
        didSet {
            if isContinuousPlaybackEnabled {
                refreshContinuousPlaybackRuntime()
            } else {
                continuousPlaybackRuntime = nil
                continuousPlaybackPreparedItem = nil
            }
        }
    }
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
    var continuousPlaybackSentenceCount: Int {
        continuousPlaybackSettings.sentenceCount
    }
    var continuousPlaybackPrecedingSentenceCount: Int {
        continuousPlaybackSettings.precedingSentenceCount
    }

    private let userDefaults: UserDefaults
    private var player: PlaybackPlayer?
    private var indexingTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var continuousPlaybackRuntime: ContinuousPlaybackRuntime?
    private var continuousPlaybackPreparedItem: PreparedContinuousPlaybackItem?

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
            Self.continuousPlaybackSentenceCountKey: ContinuousPlaybackSettings.minimumSentenceCount,
            Self.continuousPlaybackPrecedingSentenceCountKey: ContinuousPlaybackSettings.minimumPrecedingSentenceCount
        ])
        isSidebarVisible = userDefaults.bool(forKey: Self.isSidebarVisibleKey)
        isPlaybackInspectorVisible = userDefaults.bool(forKey: Self.isPlaybackInspectorVisibleKey)
        playbackInspectorWidth = userDefaults.double(forKey: Self.playbackInspectorWidthKey)
        playbackDecodeMode = Self.loadPlaybackDecodeMode(from: userDefaults)
        continuousPlaybackSettings = Self.loadContinuousPlaybackSettings(from: userDefaults)
        persistContinuousPlaybackSettings()

        do {
            try Self.prepareDatabaseDirectory(for: self.databaseURL)
            let database = try SubtitleDatabase(path: self.databaseURL)
            try database.migrate()
            try database.reconcileIndexedContent(activeFolders: selectedFolders)
            let player = PlaybackPlayer()
            player.decodeMode = playbackDecodeMode
            self.player = player
            let playbackViewModel = PlaybackViewModel(player: player)
            playbackViewModel.onCurrentTimeChanged = { [weak self] currentTime in
                self?.handlePlaybackTimeChange(currentTime)
            }
            self.playbackViewModel = playbackViewModel
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

    func setContinuousPlaybackSentenceCount(_ value: Int) {
        updateContinuousPlaybackSettings(
            continuousPlaybackSettings.updatingSentenceCount(value)
        )
    }

    func setContinuousPlaybackPrecedingSentenceCount(_ value: Int) {
        updateContinuousPlaybackSettings(
            continuousPlaybackSettings.updatingPrecedingSentenceCount(value)
        )
    }

    func setContinuousPlaybackEnabled(_ isEnabled: Bool) {
        isContinuousPlaybackEnabled = isEnabled
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
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchStatus = .idle
            searchResults = []
            return
        }

        let folders = selectedFolders
        guard !folders.isEmpty else {
            searchStatus = .completed
            searchResults = []
            selectedSearchResult = nil
            return
        }

        searchStatus = .searching

        let databaseURL = databaseURL
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 250_000_000)

                let results = try await Task.detached(priority: .userInitiated) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    try database.migrate()
                    return try database.search(trimmedQuery, under: folders)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                searchResults = results
                searchStatus = .completed
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                searchResults = []
                searchStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func openSearchResult(_ result: SubtitleSearchResult) {
        selectedSearchResult = result
        isPlaybackInspectorVisible = true
        userDefaults.set(true, forKey: Self.isPlaybackInspectorVisibleKey)
        play(result)
    }

    func play(_ result: SubtitleSearchResult) {
        playbackStatus = .opening(result)
        play(result, preparedItem: nil)
    }

    private func play(
        _ result: SubtitleSearchResult,
        preparedItem: PreparedContinuousPlaybackItem?
    ) {
        do {
            playbackStatus = .opening(result)
            let playbackItem = try preparedItem?.playbackItem ?? makePlaybackItem(for: result)
            continuousPlaybackRuntime = playbackItem.continuousRuntime
            continuousPlaybackPreparedItem = nil
            playbackViewModel?.setSubtitleCues(
                playbackItem.subtitleCues,
                currentTimeMilliseconds: playbackItem.request.startMilliseconds
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            if player.currentVideoURL?.standardizedFileURL.path == playbackItem.request.videoURL.standardizedFileURL.path {
                try player.seek(toMilliseconds: playbackItem.request.startMilliseconds)
            } else {
                try player.open(playbackItem.request)
            }

            try player.setPaused(false)
            playbackStatus = .playing(result)
        } catch {
            playbackViewModel?.clearSubtitleCues()
            continuousPlaybackRuntime = nil
            continuousPlaybackPreparedItem = nil
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
        case 8:
            viewModel.toggleSubtitles()
            return true
        case 3:
            if let player {
                playbackFullscreenManager.toggleFullscreen(player: player, viewModel: viewModel)
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
            continuousPlaybackRuntime = nil
            continuousPlaybackPreparedItem = nil
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
        }

        updateSearchQuery(searchQuery)
    }

    private func clearSearchAndPlaybackState(under folder: URL) {
        searchResults.removeAll { Self.path($0.subtitlePath, isUnder: folder) }

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

    private func makePlaybackItem(for result: SubtitleSearchResult) throws -> PlaybackItem {
        let entries = subtitleEntries(for: result)
        let segment = isContinuousPlaybackEnabled
            ? ContinuousPlaybackPlanner.segment(
                forSelectedEntryID: result.entryID,
                entries: entries,
                settings: continuousPlaybackSettings
            )
            : nil
        let request = try PlaybackRequest(
            videoURL: URL(fileURLWithPath: result.videoPath),
            startMilliseconds: segment?.startMilliseconds ?? result.startMilliseconds
        )
        let subtitleCues = playbackSubtitleCues(for: result, entries: entries)
        let runtime = segment.map {
            ContinuousPlaybackRuntime(
                result: result,
                entries: entries,
                segment: $0,
                didPrepareNextItem: false
            )
        }

        return PlaybackItem(
            result: result,
            request: request,
            subtitleCues: subtitleCues,
            continuousRuntime: runtime
        )
    }

    private func subtitleEntries(for result: SubtitleSearchResult) -> [SubtitleDatabaseEntry] {
        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            return try database.entries(
                forSubtitleFile: URL(fileURLWithPath: result.subtitlePath)
            )
        } catch {
            print("Failed to load playback subtitle track: \(error)")
            return []
        }
    }

    private func playbackSubtitleCues(
        for result: SubtitleSearchResult,
        entries: [SubtitleDatabaseEntry]
    ) -> [PlaybackSubtitleCue] {
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

        return [
            PlaybackSubtitleCue(
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds,
                text: result.content
            )
        ]
    }

    private func updateContinuousPlaybackSettings(_ settings: ContinuousPlaybackSettings) {
        guard settings != continuousPlaybackSettings else {
            return
        }

        continuousPlaybackSettings = settings
        persistContinuousPlaybackSettings()
        if isContinuousPlaybackEnabled {
            refreshContinuousPlaybackRuntime()
        }
    }

    private func persistContinuousPlaybackSettings() {
        userDefaults.set(
            continuousPlaybackSettings.sentenceCount,
            forKey: Self.continuousPlaybackSentenceCountKey
        )
        userDefaults.set(
            continuousPlaybackSettings.precedingSentenceCount,
            forKey: Self.continuousPlaybackPrecedingSentenceCountKey
        )
    }

    private func refreshContinuousPlaybackRuntime() {
        continuousPlaybackPreparedItem = nil

        guard isContinuousPlaybackEnabled,
              let selectedSearchResult
        else {
            continuousPlaybackRuntime = nil
            return
        }

        let entries = subtitleEntries(for: selectedSearchResult)
        guard let segment = ContinuousPlaybackPlanner.segment(
            forSelectedEntryID: selectedSearchResult.entryID,
            entries: entries,
            settings: continuousPlaybackSettings
        ) else {
            continuousPlaybackRuntime = nil
            return
        }

        continuousPlaybackRuntime = ContinuousPlaybackRuntime(
            result: selectedSearchResult,
            entries: entries,
            segment: segment,
            didPrepareNextItem: false
        )
    }

    private func handlePlaybackTimeChange(_ currentTime: Double) {
        guard isContinuousPlaybackEnabled,
              playbackViewModel?.isPlaying == true,
              var runtime = continuousPlaybackRuntime
        else {
            return
        }

        let currentMilliseconds = max(0, Int((currentTime * 1_000).rounded()))

        if !runtime.didPrepareNextItem,
           ContinuousPlaybackPlanner.shouldPrepareNextItem(
               currentMilliseconds: currentMilliseconds,
               segment: runtime.segment
           ) {
            runtime.didPrepareNextItem = true
            continuousPlaybackRuntime = runtime
            continuousPlaybackPreparedItem = preparedContinuousPlaybackItem(after: runtime.result)
        }

        let boundaryMilliseconds = ContinuousPlaybackPlanner.boundaryMilliseconds(
            forCurrentMilliseconds: currentMilliseconds,
            segment: runtime.segment,
            entries: runtime.entries
        )

        guard currentMilliseconds >= boundaryMilliseconds else {
            return
        }

        advanceContinuousPlayback(after: runtime.result)
    }

    private func preparedContinuousPlaybackItem(
        after result: SubtitleSearchResult
    ) -> PreparedContinuousPlaybackItem? {
        guard let nextResult = nextContinuousPlaybackResult(after: result),
              let playbackItem = try? makePlaybackItem(for: nextResult)
        else {
            return nil
        }

        return PreparedContinuousPlaybackItem(playbackItem: playbackItem)
    }

    private func advanceContinuousPlayback(after result: SubtitleSearchResult) {
        guard let nextResult = nextContinuousPlaybackResult(after: result) else {
            continuousPlaybackRuntime = nil
            continuousPlaybackPreparedItem = nil
            pausePlayback()
            return
        }

        selectedSearchResult = nextResult
        let preparedItem: PreparedContinuousPlaybackItem?
        if continuousPlaybackPreparedItem?.playbackItem.result.entryID == nextResult.entryID {
            preparedItem = continuousPlaybackPreparedItem
        } else {
            preparedItem = nil
        }
        play(nextResult, preparedItem: preparedItem)
    }

    private func nextContinuousPlaybackResult(
        after result: SubtitleSearchResult
    ) -> SubtitleSearchResult? {
        guard let currentIndex = searchResults.firstIndex(where: { $0.entryID == result.entryID }) else {
            return nil
        }

        let nextIndex = currentIndex + 1
        guard searchResults.indices.contains(nextIndex) else {
            return nil
        }

        return searchResults[nextIndex]
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

    private static func loadContinuousPlaybackSettings(from userDefaults: UserDefaults) -> ContinuousPlaybackSettings {
        ContinuousPlaybackSettings(
            sentenceCount: userDefaults.integer(forKey: continuousPlaybackSentenceCountKey),
            precedingSentenceCount: userDefaults.integer(forKey: continuousPlaybackPrecedingSentenceCountKey)
        )
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

private struct PlaybackItem {
    let result: SubtitleSearchResult
    let request: PlaybackRequest
    let subtitleCues: [PlaybackSubtitleCue]
    let continuousRuntime: ContinuousPlaybackRuntime?
}

private struct ContinuousPlaybackRuntime {
    let result: SubtitleSearchResult
    let entries: [SubtitleDatabaseEntry]
    let segment: ContinuousPlaybackSegment
    var didPrepareNextItem: Bool
}

private struct PreparedContinuousPlaybackItem {
    let playbackItem: PlaybackItem
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
