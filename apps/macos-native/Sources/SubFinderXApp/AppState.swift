import Foundation
import SubFinderXCore
import SubFinderXPlayback

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
    case completed(URL, SubtitleIndexingResult)
    case failed(URL, String)

    var isIndexing: Bool {
        if case .indexing = self {
            return true
        }

        return false
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

    @Published var selectedSection: AppSection = .search
    @Published var selectedFolders: [URL] = []
    @Published var indexingStatus: IndexingStatus = .idle
    @Published var searchQuery = ""
    @Published var searchStatus: SearchStatus = .idle
    @Published var searchResults: [SubtitleSearchResult] = []
    @Published var selectedSearchResult: SubtitleSearchResult?
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var startupError: String?

    let databaseURL: URL

    private let userDefaults: UserDefaults
    private var player: MPVPlayer?
    private var playbackViewID: UInt?
    private var indexingTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    init(
        userDefaults: UserDefaults = .standard,
        databaseURL: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
        selectedFolders = Self.loadSelectedFolders(from: userDefaults)

        do {
            try Self.prepareDatabaseDirectory(for: self.databaseURL)
            let database = try SubtitleDatabase(path: self.databaseURL)
            try database.migrate()
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
        selectedFolders.remove(atOffsets: offsets)
        persistSelectedFolders()
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

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        selectedSearchResult = nil
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchStatus = .idle
            searchResults = []
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
                    return try database.search(trimmedQuery)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                searchResults = results
                selectedSearchResult = results.first
                searchStatus = .completed
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                searchResults = []
                selectedSearchResult = nil
                searchStatus = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func selectSearchResult(_ result: SubtitleSearchResult) {
        selectedSearchResult = result
    }

    func attachPlaybackView(id viewID: UInt) {
        playbackViewID = viewID
    }

    func play(_ result: SubtitleSearchResult) {
        playbackStatus = .opening(result)

        do {
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: result.videoPath),
                startMilliseconds: result.startMilliseconds
            )

            try initializePlayerIfNeeded()

            try player?.open(request)
            playbackStatus = .playing(result)
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func pausePlayback() {
        do {
            try player?.setPaused(true)
        } catch {
            playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    private func initializePlayerIfNeeded() throws {
        guard player == nil else {
            return
        }

        guard let playbackViewID else {
            throw PlaybackError.missingPlaybackView
        }

        player = try MPVPlayer(viewID: playbackViewID)
    }

    private func refreshCurrentSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        updateSearchQuery(searchQuery)
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

    private static func defaultDatabaseURL() -> URL {
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return baseDirectory
            .appendingPathComponent(ApplicationInfo.name, isDirectory: true)
            .appendingPathComponent("SubFinderX.sqlite")
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
