import Combine
import CueSeekerCore
import Foundation

struct PlaybackRecentLoader {
    let load: @MainActor () async throws -> [RecentLibraryWatchingPresentation]

    @MainActor
    static func live(databaseURL: URL, folders: [URL]) -> Self {
        Self {
            guard !folders.isEmpty else {
                return []
            }
            return try await AppCoordinator.runCancellableDetached(
                priority: .userInitiated
            ) {
                let database = try SubtitleDatabase(path: databaseURL)
                return try database.recentLibraryWatching(
                    under: folders,
                    limit: Int.max
                )
            }
        }
    }
}

@MainActor
final class PlaybackRecentSessionStore: ObservableObject {
    @Published private(set) var status: LibraryStatus = .idle
    @Published private(set) var items: [RecentLibraryWatchingPresentation] = []

    let selection = PlaybackMediaSelectionStore()

    private let loader: PlaybackRecentLoader
    private let isVideoAvailable: @MainActor (String) -> Bool
    private let sourceRevision: @MainActor () -> Int
    private var loadTask: Task<Void, Never>?
    private var loadedSourceRevision: Int?
    private var loadingSourceRevision: Int?
    private var loadGeneration: UInt64 = 0
    private var didActivate = false
    private var isActive = true

    init(
        loader: PlaybackRecentLoader,
        isVideoAvailable: @escaping @MainActor (String) -> Bool = {
            FileManager.default.fileExists(atPath: $0)
        },
        sourceRevision: @escaping @MainActor () -> Int = { 0 }
    ) {
        self.loader = loader
        self.isVideoAvailable = isVideoAvailable
        self.sourceRevision = sourceRevision
    }

    var hasActiveLoadTask: Bool {
        loadTask != nil
    }

    func activate(refreshesExistingSnapshot: Bool = false) {
        guard isActive else {
            return
        }
        if didActivate {
            if refreshesExistingSnapshot {
                let currentSourceRevision = sourceRevision()
                let representedRevision = status == .loading
                    ? loadingSourceRevision
                    : loadedSourceRevision
                if representedRevision != currentSourceRevision {
                    startLoad(resetsSelection: false)
                }
            }
            return
        }
        didActivate = true
        startLoad(resetsSelection: true)
    }

    func refresh() {
        guard isActive, didActivate else {
            return
        }
        startLoad(resetsSelection: false)
    }

    private func startLoad(resetsSelection: Bool) {
        loadTask?.cancel()
        loadGeneration &+= 1
        let generation = loadGeneration
        status = .loading
        let requestedSourceRevision = sourceRevision()
        loadingSourceRevision = requestedSourceRevision

        loadTask = Task { @MainActor [weak self, loader] in
            do {
                let snapshot = try await loader.load()
                try Task.checkCancellation()
                guard let self,
                      isActive,
                      loadGeneration == generation
                else {
                    return
                }
                guard sourceRevision() == requestedSourceRevision else {
                    loadTask = nil
                    loadingSourceRevision = nil
                    startLoad(resetsSelection: resetsSelection)
                    return
                }
                loadTask = nil
                loadingSourceRevision = nil
                loadedSourceRevision = requestedSourceRevision
                items = snapshot
                let availableIDs = Set(snapshot.compactMap { item in
                    isVideoAvailable(item.videoPath) ? item.id : nil
                })
                selection.replaceItems(
                    orderedItemIDs: snapshot.map(\.id),
                    availableItemIDs: availableIDs,
                    resetsSelection: resetsSelection
                )
                status = .completed
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      isActive,
                      !Task.isCancelled,
                      loadGeneration == generation
                else {
                    return
                }
                guard sourceRevision() == requestedSourceRevision else {
                    loadTask = nil
                    loadingSourceRevision = nil
                    startLoad(resetsSelection: resetsSelection)
                    return
                }
                loadTask = nil
                loadingSourceRevision = nil
                items = []
                selection.replaceItems(
                    orderedItemIDs: [],
                    availableItemIDs: [],
                    resetsSelection: true
                )
                status = .failed(AppCoordinator.errorMessage(for: error))
            }
        }
    }

    func primaryActionItem(itemID: String? = nil) -> RecentLibraryWatchingPresentation? {
        guard isActive,
              let resolvedItemID = itemID ?? selection.selectedItemID,
              let item = items.first(where: { $0.id == resolvedItemID }),
              isVideoAvailable(item.videoPath)
        else {
            return nil
        }
        return item
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        loadGeneration &+= 1
        loadTask?.cancel()
        loadTask = nil
        loadedSourceRevision = nil
        loadingSourceRevision = nil
        items = []
        status = .idle
        selection.invalidate()
    }
}
