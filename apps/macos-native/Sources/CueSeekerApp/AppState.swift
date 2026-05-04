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
    case validatingRemote(String, detail: String?)
    case indexingRemote(String, detail: String?)
    case indexingAll(currentFolder: URL, completedFolders: Int, totalFolders: Int)
    case completed(URL, SubtitleIndexingResult)
    case completedRemote(String, SubtitleIndexingResult)
    case completedAll(folderCount: Int, SubtitleIndexingResult)
    case failed(URL, String)
    case failedRemote(String, String)

    var isIndexing: Bool {
        switch self {
        case .indexing, .validatingRemote, .indexingRemote, .indexingAll:
            return true
        case .idle, .completed, .completedRemote, .completedAll, .failed, .failedRemote:
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
    private static let assSubtitleRenderingModeKey = "assSubtitleRenderingMode"
    private static let assSubtitlePreparationCueLimit = 8

    @Published var selectedSection: AppSection = .search
    @Published var selectedFolders: [URL] = []
    @Published var remoteSources: [StoredMediaSource] = []
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

    private let userDefaults: UserDefaults
    private let credentialStore = RemoteCredentialStore()
    private var player: PlaybackPlayer?
    private var indexingTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

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
            remoteSources = try database.remoteMediaSources()
            try database.reconcileIndexedContent(
                activeFolders: selectedFolders,
                activeRemoteSourceIDs: remoteSources.map(\.id)
            )
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

    func addAListRemoteSource(
        displayName: String,
        rootURLString: String,
        username: String,
        password: String
    ) {
        let trimmedURL = rootURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rootURL = URL(string: trimmedURL) else {
            startupError = "Invalid WebDAV URL."
            return
        }

        indexingTask?.cancel()
        let sourceName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? rootURL.host
            ?? trimmedURL
        let credentials = RemoteMediaSourceCredentials(username: username, password: password)
        indexingStatus = .validatingRemote(sourceName, detail: "Checking WebDAV and AList access...")

        let databaseURL = databaseURL
        let credentialStore = credentialStore
        let credentialRef = UUID().uuidString
        indexingTask = Task {
            do {
                try await Self.validateAListRemoteSource(
                    name: sourceName,
                    rootURL: rootURL,
                    credentials: credentials
                ) { [weak self] detail in
                    Task { @MainActor in
                        guard case .validatingRemote(let currentName, _) = self?.indexingStatus,
                              currentName == sourceName
                        else {
                            return
                        }
                        self?.indexingStatus = .validatingRemote(sourceName, detail: detail)
                    }
                }

                guard !Task.isCancelled else {
                    return
                }

                try credentialStore.save(credentials, credentialRef: credentialRef)

                let database = try SubtitleDatabase(path: databaseURL)
                try database.migrate()
                let sourceID = try database.addRemoteMediaSource(
                    provider: .alist,
                    rootURL: rootURL,
                    displayName: sourceName,
                    credentialRef: credentialRef
                )
                remoteSources = try database.remoteMediaSources()

                guard let source = remoteSources.first(where: { $0.id == sourceID }) else {
                    return
                }
                startRemoteIndexing(source, cancelExisting: false)
            } catch {
                credentialStore.delete(credentialRef: credentialRef)
                guard !Task.isCancelled else {
                    return
                }
                indexingStatus = .failedRemote(sourceName, Self.errorMessage(for: error))
                startupError = "Failed to add remote source: \(Self.errorMessage(for: error))"
            }
        }
    }

    func removeRemoteSource(_ source: StoredMediaSource) {
        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            try database.removeIndexedRemoteSource(id: source.id)
            credentialStore.delete(credentialRef: source.credentialRef)
            remoteSources = try database.remoteMediaSources()
            clearSearchAndPlaybackState(sourceID: source.id)
            refreshCurrentSearch(clearExistingResults: true)
        } catch {
            startupError = "Failed to remove remote source: \(Self.errorMessage(for: error))"
        }
    }

    func indexRemoteSource(_ source: StoredMediaSource) {
        startRemoteIndexing(source, cancelExisting: true)
    }

    private func startRemoteIndexing(_ source: StoredMediaSource, cancelExisting: Bool) {
        if cancelExisting {
            indexingTask?.cancel()
        }
        indexingStatus = .indexingRemote(source.displayName, detail: "Starting remote index...")

        let databaseURL = databaseURL
        let credentialStore = credentialStore
        indexingTask = Task {
            do {
                let credentials = try credentialStore.load(credentialRef: source.credentialRef)
                let configuration = try Self.remoteConfiguration(source: source, credentials: credentials)
                let progressHandler: @Sendable (RemoteIndexingProgress) -> Void = { [weak self] progress in
                    print("REMOTE_INDEX source=\"\(source.displayName)\" \(progress.logMessage)")
                    Task { @MainActor in
                        guard case .indexingRemote(let currentName, _) = self?.indexingStatus,
                              currentName == source.displayName
                        else {
                            return
                        }
                        self?.indexingStatus = .indexingRemote(
                            source.displayName,
                            detail: progress.userMessage
                        )
                    }
                }
                let result = try await Task.detached(priority: .userInitiated) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    let indexer = RemoteSubtitleIndexer()
                    return try await indexer.index(
                        source: configuration,
                        into: database,
                        progress: progressHandler
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                indexingStatus = .completedRemote(source.displayName, result)
                refreshCurrentSearch()
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                indexingStatus = .failedRemote(source.displayName, Self.errorMessage(for: error))
            }
        }
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
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchStatus = .idle
            searchResults = []
            return
        }

        let folders = selectedFolders
        let remoteSourceIDs = remoteSources.map(\.id)
        guard !folders.isEmpty || !remoteSourceIDs.isEmpty else {
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
                    return try database.search(
                        trimmedQuery,
                        under: folders,
                        remoteSourceIDs: remoteSourceIDs
                    )
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
        Task { @MainActor in
            await Task.yield()
            play(result)
        }
    }

    func play(_ result: SubtitleSearchResult) {
        Task {
            await playResolved(result)
        }
    }

    private func playResolved(_ result: SubtitleSearchResult) async {
        playbackStatus = .opening(result)
        let subtitleCues = playbackSubtitleCues(for: result)
        playbackViewModel?.setSubtitleCues(
            subtitleCues,
            currentTimeMilliseconds: result.startMilliseconds
        )

        do {
            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            let mediaIdentifier = Self.playbackMediaIdentifier(for: result)
            if player.currentMediaIdentifier == mediaIdentifier {
                player.loadSubtitleSource(try await playbackSubtitleSource(for: result))
                try player.seek(toMilliseconds: result.startMilliseconds)
            } else {
                let request = try await playbackRequest(
                    for: result,
                    mediaIdentifier: mediaIdentifier
                )
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

    private func clearSearchAndPlaybackState(sourceID: Int64) {
        searchResults.removeAll { result in
            result.subtitleSourceID == sourceID || result.videoSourceID == sourceID
        }

        guard let selectedSearchResult,
              selectedSearchResult.subtitleSourceID == sourceID || selectedSearchResult.videoSourceID == sourceID
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

    private func playbackRequest(
        for result: SubtitleSearchResult,
        mediaIdentifier: String? = nil
    ) async throws -> PlaybackRequest {
        let subtitleSource = try await playbackSubtitleSource(for: result)

        guard let sourceID = result.videoSourceID else {
            return try PlaybackRequest(
                videoURL: URL(fileURLWithPath: result.videoPath),
                startMilliseconds: result.startMilliseconds,
                subtitleSource: subtitleSource,
                mediaIdentifier: mediaIdentifier
            )
        }

        guard let source = remoteSources.first(where: { $0.id == sourceID }) else {
            throw RemotePlaybackError.remoteSourceUnavailable
        }
        let credentials = try credentialStore.load(credentialRef: source.credentialRef)
        let configuration = try Self.remoteConfiguration(source: source, credentials: credentials)

        let resolved: ResolvedRemoteMedia
        switch source.provider {
        case .alist:
            guard let relativePath = result.videoSourceRelativePath else {
                throw RemotePlaybackError.remoteRelativePathMissing
            }
            resolved = try await AListResolver().resolve(
                source: configuration,
                sourceRelativePath: relativePath
            )
        case .genericWebDAV:
            guard let url = URL(string: result.videoPath) else {
                throw RemotePlaybackError.invalidRemoteURL
            }
            resolved = ResolvedRemoteMedia(
                url: url,
                headers: Self.basicAuthHeaders(credentials: credentials)
            )
        case .local:
            throw RemotePlaybackError.remoteSourceUnavailable
        }

        let proxyURL = try await LocalStreamProxy.shared.register(
            remoteURL: resolved.url,
            headers: resolved.headers
        )

        return try PlaybackRequest(
            videoURL: proxyURL,
            httpHeaders: [:],
            startMilliseconds: result.startMilliseconds,
            subtitleSource: subtitleSource,
            mediaIdentifier: mediaIdentifier ?? Self.remoteMediaIdentifier(sourceID: sourceID, result: result)
        )
    }

    private static func playbackMediaIdentifier(for result: SubtitleSearchResult) -> String {
        guard let sourceID = result.videoSourceID else {
            return result.videoPath
        }
        return remoteMediaIdentifier(sourceID: sourceID, result: result)
    }

    private static func remoteMediaIdentifier(sourceID: Int64, result: SubtitleSearchResult) -> String {
        let path = result.videoSourceRelativePath?.removingPercentEncoding
            ?? result.videoSourceRelativePath
            ?? result.videoPath
        return "remote:\(sourceID):\(path)"
    }

    private func playbackSubtitleCues(for result: SubtitleSearchResult) -> [PlaybackSubtitleCue] {
        guard result.subtitleFormat == .srt else {
            return []
        }

        do {
            let database = try SubtitleDatabase(path: databaseURL)
            try database.migrate()
            let entries = try database.entries(
                forSubtitlePath: result.subtitlePath
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

    private func playbackSubtitleSource(for result: SubtitleSearchResult) async throws -> PlaybackSubtitleSource? {
        guard result.subtitleFormat == .ass else {
            return nil
        }

        let subtitleURL: URL
        if result.subtitleSourceID != nil {
            subtitleURL = try await cachedRemoteSubtitleURL(for: result)
        } else {
            subtitleURL = URL(fileURLWithPath: result.subtitlePath)
        }

        return PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            preparationTimeWindow: playbackSubtitleTimeWindow(for: result),
            renderCacheDatabaseURL: databaseURL,
            renderCacheSubtitlePath: result.subtitlePath
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
                forSubtitlePath: result.subtitlePath,
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

    private func cachedRemoteSubtitleURL(for result: SubtitleSearchResult) async throws -> URL {
        guard let sourceID = result.subtitleSourceID,
              let relativePath = result.subtitleSourceRelativePath,
              let source = remoteSources.first(where: { $0.id == sourceID })
        else {
            throw RemotePlaybackError.remoteRelativePathMissing
        }

        let credentials = try credentialStore.load(credentialRef: source.credentialRef)
        let rootURL = try Self.remoteRootURL(source.path)
        let client = try WebDAVClient(rootURL: rootURL, credentials: credentials)
        let data = try await client.downloadData(relativePath: relativePath)
        let cacheURL = try remoteSubtitleCacheURL(
            sourceID: sourceID,
            relativePath: relativePath,
            pathExtension: URL(fileURLWithPath: relativePath).pathExtension.nilIfEmpty ?? "ass"
        )
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: cacheURL, options: .atomic)
        return cacheURL
    }

    private func remoteSubtitleCacheURL(
        sourceID: Int64,
        relativePath: String,
        pathExtension: String
    ) throws -> URL {
        let cacheRoot = databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent("RemoteSubtitleCache", isDirectory: true)
            .appendingPathComponent(String(sourceID), isDirectory: true)
        let fileName = RemoteSubtitleCacheKey.fileName(
            sourceID: sourceID,
            relativePath: relativePath,
            pathExtension: pathExtension
        )
        return cacheRoot.appendingPathComponent(fileName)
    }

    private static func validateAListRemoteSource(
        name: String,
        rootURL: URL,
        credentials: RemoteMediaSourceCredentials,
        progress: @escaping @Sendable (String) -> Void
    ) async throws {
        let configuration = RemoteMediaSourceConfiguration(
            id: -1,
            provider: .alist,
            displayName: name,
            rootURL: rootURL,
            credentialRef: nil,
            credentials: credentials
        )

        progress("Validating WebDAV root...")
        var startedAt = Date()
        let rootEntries = try await WebDAVClient(
            rootURL: rootURL,
            credentials: credentials
        ).validateRoot()
        print(
            "REMOTE_VALIDATE source=\"\(name)\" stage=webdav_root entries=\(rootEntries.count) elapsed_ms=\(elapsedMilliseconds(since: startedAt))"
        )

        progress("Validating AList API login and root path...")
        startedAt = Date()
        try await AListResolver().validateRoot(source: configuration)
        print(
            "REMOTE_VALIDATE source=\"\(name)\" stage=alist_root elapsed_ms=\(elapsedMilliseconds(since: startedAt))"
        )
    }

    private static func remoteConfiguration(
        source: StoredMediaSource,
        credentials: RemoteMediaSourceCredentials
    ) throws -> RemoteMediaSourceConfiguration {
        RemoteMediaSourceConfiguration(
            id: source.id,
            provider: source.provider,
            displayName: source.displayName,
            rootURL: try remoteRootURL(source.path),
            credentialRef: source.credentialRef,
            credentials: credentials
        )
    }

    private static func remoteRootURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw RemotePlaybackError.invalidRemoteURL
        }
        return url
    }

    private static func basicAuthHeaders(credentials: RemoteMediaSourceCredentials) -> [String: String] {
        guard !credentials.username.isEmpty || !credentials.password.isEmpty else {
            return [:]
        }

        let userPassword = "\(credentials.username):\(credentials.password)"
        let encoded = Data(userPassword.utf8).base64EncodedString()
        return ["Authorization": "Basic \(encoded)"]
    }

    private static func elapsedMilliseconds(since startDate: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startDate) * 1_000))
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

private enum RemotePlaybackError: Error, CustomStringConvertible {
    case remoteSourceUnavailable
    case remoteRelativePathMissing
    case invalidRemoteURL

    var description: String {
        switch self {
        case .remoteSourceUnavailable:
            "Remote media source is unavailable."
        case .remoteRelativePathMissing:
            "Remote media relative path is missing."
        case .invalidRemoteURL:
            "Remote media URL is invalid."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
