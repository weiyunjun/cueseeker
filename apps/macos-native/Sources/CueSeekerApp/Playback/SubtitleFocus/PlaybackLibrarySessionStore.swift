import Combine
import CueSeekerCore
import Foundation

struct PlaybackLibrarySourceRevision: Equatable, Sendable {
    let folders: Int
    let playbackHistory: Int
}

enum PlaybackLibraryLevel: Equatable, Sendable {
    case folders
    case folderDetail(folderPath: String, folderTitle: String)
}

struct PlaybackLibraryLoader {
    let loadFolders:
        @MainActor () async throws -> [CompleteLibraryFolderSummaryPresentation]
    let loadFolderDetail:
        @MainActor (String) async throws -> CompleteLibraryFolderDetailPresentation?

    @MainActor
    static func live(databaseURL: URL, folders: [URL]) -> Self {
        Self(
            loadFolders: {
                guard !folders.isEmpty else {
                    return []
                }
                return try await AppCoordinator.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    return try database.completeLibraryFolderSummaries(
                        under: folders
                    )
                }
            },
            loadFolderDetail: { folderPath in
                try await AppCoordinator.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let database = try SubtitleDatabase(path: databaseURL)
                    return try database.completeLibraryFolderDetail(
                        folderPath: folderPath
                    )
                }
            }
        )
    }
}

@MainActor
final class PlaybackLibrarySessionStore: ObservableObject {
    @Published private(set) var folderStatus: LibraryStatus = .idle
    @Published private(set) var folders: [CompleteLibraryFolderSummaryPresentation]
        = []
    @Published private(set) var level: PlaybackLibraryLevel = .folders
    @Published private(set) var detailStatus: LibraryStatus = .idle
    @Published private(set) var detail: CompleteLibraryFolderDetailPresentation?
    @Published private(set) var episodeSelection: PlaybackMediaSelectionStore?

    let folderSelection = PlaybackMediaSelectionStore()

    private let loader: PlaybackLibraryLoader
    private let isVideoAvailable: @MainActor (String) -> Bool
    private let sourceRevision: @MainActor () -> PlaybackLibrarySourceRevision

    private var folderLoadTask: Task<Void, Never>?
    private var folderLoadGeneration: UInt64 = 0
    private var loadedFolderRevision: Int?
    private var loadingFolderRevision: Int?

    private var detailLoadTask: Task<Void, Never>?
    private var detailLoadGeneration: UInt64 = 0
    private var loadedDetailRevision: PlaybackLibrarySourceRevision?
    private var loadingDetailRevision: PlaybackLibrarySourceRevision?

    private var didActivate = false
    private var isActive = true

    init(
        loader: PlaybackLibraryLoader,
        isVideoAvailable: @escaping @MainActor (String) -> Bool = {
            FileManager.default.fileExists(atPath: $0)
        },
        sourceRevision: @escaping @MainActor () -> PlaybackLibrarySourceRevision = {
            PlaybackLibrarySourceRevision(folders: 0, playbackHistory: 0)
        }
    ) {
        self.loader = loader
        self.isVideoAvailable = isVideoAvailable
        self.sourceRevision = sourceRevision
    }

    var hasActiveFolderLoadTask: Bool {
        folderLoadTask != nil
    }

    var hasActiveDetailLoadTask: Bool {
        detailLoadTask != nil
    }

    func activate(refreshesExistingSnapshot: Bool = false) {
        guard isActive else {
            return
        }
        guard didActivate else {
            didActivate = true
            startFolderLoad(resetsSelection: true)
            return
        }
        if refreshesExistingSnapshot {
            refreshForSourceRevision()
        }
    }

    func refreshForSourceRevision() {
        guard isActive, didActivate else {
            return
        }
        let revision = sourceRevision()
        let representedFolderRevision = folderStatus == .loading
            ? loadingFolderRevision
            : loadedFolderRevision
        if representedFolderRevision != revision.folders {
            startFolderLoad(resetsSelection: false)
        }

        guard case .folderDetail(let folderPath, _) = level else {
            return
        }
        let representedDetailRevision = detailStatus == .loading
            ? loadingDetailRevision
            : loadedDetailRevision
        if representedDetailRevision != revision {
            startDetailLoad(
                folderPath: folderPath,
                resetsSelection: false,
                clearsDetail: false
            )
        }
    }

    @discardableResult
    func moveSelection(_ direction: PlaybackMediaSelectionDirection) -> Bool {
        guard isActive else {
            return false
        }
        switch level {
        case .folders:
            return folderSelection.move(direction)
        case .folderDetail:
            return episodeSelection?.move(direction) == true
        }
    }

    @discardableResult
    func enterFolder(itemID: String? = nil) -> Bool {
        guard isActive,
              level == .folders,
              let resolvedItemID = itemID ?? folderSelection.selectedItemID,
              let folder = folders.first(where: { $0.id == resolvedItemID }),
              folder.episodeCount > 0
        else {
            return false
        }

        episodeSelection?.invalidate()
        episodeSelection = PlaybackMediaSelectionStore()
        level = .folderDetail(
            folderPath: folder.folderPath,
            folderTitle: folder.folderTitle
        )
        detail = nil
        detailStatus = .loading
        startDetailLoad(
            folderPath: folder.folderPath,
            resetsSelection: true,
            clearsDetail: true
        )
        return true
    }

    @discardableResult
    func returnToFolders() -> Bool {
        guard isActive, case .folderDetail = level else {
            return false
        }
        clearDetailState()
        level = .folders
        return true
    }

    func primaryActionVideo(
        itemID: String? = nil
    ) -> CompleteLibraryVideoPresentation? {
        guard isActive,
              case .folderDetail(let folderPath, _) = level,
              let detail,
              detail.folderPath == folderPath,
              let resolvedItemID = itemID ?? episodeSelection?.selectedItemID,
              let video = detail.videos.first(where: { $0.id == resolvedItemID }),
              isVideoAvailable(video.videoPath)
        else {
            return nil
        }
        return video
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false

        folderLoadGeneration &+= 1
        folderLoadTask?.cancel()
        folderLoadTask = nil
        loadedFolderRevision = nil
        loadingFolderRevision = nil

        detailLoadGeneration &+= 1
        detailLoadTask?.cancel()
        detailLoadTask = nil
        loadedDetailRevision = nil
        loadingDetailRevision = nil

        folders = []
        folderStatus = .idle
        folderSelection.invalidate()
        episodeSelection?.invalidate()
        episodeSelection = nil
        detail = nil
        detailStatus = .idle
        level = .folders
    }

    private func startFolderLoad(resetsSelection: Bool) {
        folderLoadTask?.cancel()
        folderLoadGeneration &+= 1
        let generation = folderLoadGeneration
        let requestedRevision = sourceRevision().folders
        loadingFolderRevision = requestedRevision
        folderStatus = .loading

        folderLoadTask = Task { @MainActor [weak self, loader] in
            do {
                let snapshot = try await loader.loadFolders()
                try Task.checkCancellation()
                guard let self,
                      isActive,
                      folderLoadGeneration == generation
                else {
                    return
                }
                guard sourceRevision().folders == requestedRevision else {
                    folderLoadTask = nil
                    loadingFolderRevision = nil
                    startFolderLoad(resetsSelection: resetsSelection)
                    return
                }

                folderLoadTask = nil
                loadingFolderRevision = nil
                loadedFolderRevision = requestedRevision
                folders = snapshot
                folderSelection.replaceItems(
                    orderedItemIDs: snapshot.map(\.id),
                    availableItemIDs: Set(snapshot.compactMap { folder in
                        folder.episodeCount > 0 ? folder.id : nil
                    }),
                    resetsSelection: resetsSelection
                )
                folderStatus = .completed
                reconcileOpenDetail(with: snapshot)
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      isActive,
                      !Task.isCancelled,
                      folderLoadGeneration == generation
                else {
                    return
                }
                guard sourceRevision().folders == requestedRevision else {
                    folderLoadTask = nil
                    loadingFolderRevision = nil
                    startFolderLoad(resetsSelection: resetsSelection)
                    return
                }

                folderLoadTask = nil
                loadingFolderRevision = nil
                folders = []
                folderSelection.replaceItems(
                    orderedItemIDs: [],
                    availableItemIDs: [],
                    resetsSelection: true
                )
                folderStatus = .failed(AppCoordinator.errorMessage(for: error))
            }
        }
    }

    private func startDetailLoad(
        folderPath: String,
        resetsSelection: Bool,
        clearsDetail: Bool
    ) {
        detailLoadTask?.cancel()
        detailLoadGeneration &+= 1
        let generation = detailLoadGeneration
        let requestedRevision = sourceRevision()
        loadingDetailRevision = requestedRevision
        detailStatus = .loading
        if clearsDetail {
            detail = nil
        }

        detailLoadTask = Task { @MainActor [weak self, loader] in
            do {
                let snapshot = try await loader.loadFolderDetail(folderPath)
                try Task.checkCancellation()
                guard let self,
                      isActive,
                      detailLoadGeneration == generation,
                      isShowingDetail(folderPath: folderPath)
                else {
                    return
                }
                guard sourceRevision() == requestedRevision else {
                    detailLoadTask = nil
                    loadingDetailRevision = nil
                    startDetailLoad(
                        folderPath: folderPath,
                        resetsSelection: resetsSelection,
                        clearsDetail: false
                    )
                    return
                }
                guard let snapshot else {
                    detailLoadTask = nil
                    loadingDetailRevision = nil
                    detail = nil
                    episodeSelection?.replaceItems(
                        orderedItemIDs: [],
                        availableItemIDs: [],
                        resetsSelection: true
                    )
                    detailStatus = .failed("Folder detail is unavailable")
                    return
                }

                detailLoadTask = nil
                loadingDetailRevision = nil
                loadedDetailRevision = requestedRevision
                detail = snapshot
                level = .folderDetail(
                    folderPath: snapshot.folderPath,
                    folderTitle: snapshot.folderTitle
                )
                episodeSelection?.replaceItems(
                    orderedItemIDs: snapshot.videos.map(\.id),
                    availableItemIDs: Set(snapshot.videos.compactMap { video in
                        isVideoAvailable(video.videoPath) ? video.id : nil
                    }),
                    resetsSelection: resetsSelection
                )
                detailStatus = .completed
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      isActive,
                      !Task.isCancelled,
                      detailLoadGeneration == generation,
                      isShowingDetail(folderPath: folderPath)
                else {
                    return
                }
                guard sourceRevision() == requestedRevision else {
                    detailLoadTask = nil
                    loadingDetailRevision = nil
                    startDetailLoad(
                        folderPath: folderPath,
                        resetsSelection: resetsSelection,
                        clearsDetail: false
                    )
                    return
                }

                detailLoadTask = nil
                loadingDetailRevision = nil
                detail = nil
                episodeSelection?.replaceItems(
                    orderedItemIDs: [],
                    availableItemIDs: [],
                    resetsSelection: true
                )
                detailStatus = .failed(AppCoordinator.errorMessage(for: error))
            }
        }
    }

    private func reconcileOpenDetail(
        with refreshedFolders: [CompleteLibraryFolderSummaryPresentation]
    ) {
        guard case .folderDetail(let folderPath, _) = level else {
            return
        }
        guard let refreshedFolder = refreshedFolders.first(where: {
            $0.folderPath == folderPath && $0.episodeCount > 0
        }) else {
            clearDetailState()
            level = .folders
            return
        }
        level = .folderDetail(
            folderPath: refreshedFolder.folderPath,
            folderTitle: refreshedFolder.folderTitle
        )
    }

    private func clearDetailState() {
        detailLoadGeneration &+= 1
        detailLoadTask?.cancel()
        detailLoadTask = nil
        loadedDetailRevision = nil
        loadingDetailRevision = nil
        detail = nil
        detailStatus = .idle
        episodeSelection?.invalidate()
        episodeSelection = nil
    }

    private func isShowingDetail(folderPath: String) -> Bool {
        guard case .folderDetail(let currentFolderPath, _) = level else {
            return false
        }
        return currentFolderPath == folderPath
    }
}
