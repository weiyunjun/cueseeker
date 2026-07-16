import Combine
import CueSeekerCore
import Foundation

enum PlaybackLibraryLevel: Equatable, Sendable {
    case folders
    case folderDetail(folderPath: String, folderTitle: String)
}

@MainActor
final class PlaybackLibrarySessionStore: ObservableObject {
    let libraryStore: LibraryStore
    let folderSelection = PlaybackMediaSelectionStore()

    @Published private(set) var level: PlaybackLibraryLevel = .folders
    @Published private(set) var episodeSelection: PlaybackMediaSelectionStore?

    private let requestFolders: @MainActor () -> Void
    private let requestFolderDetail: @MainActor (String) -> Void
    private let isVideoAvailable: @MainActor (String) -> Bool
    private var foldersCancellable: AnyCancellable?
    private var detailsCancellable: AnyCancellable?
    private var didActivate = false
    private var isActive = true

    init(
        libraryStore: LibraryStore,
        requestFolders: @escaping @MainActor () -> Void = {},
        requestFolderDetail: @escaping @MainActor (String) -> Void = { _ in },
        isVideoAvailable: @escaping @MainActor (String) -> Bool = {
            FileManager.default.fileExists(atPath: $0)
        }
    ) {
        self.libraryStore = libraryStore
        self.requestFolders = requestFolders
        self.requestFolderDetail = requestFolderDetail
        self.isVideoAvailable = isVideoAvailable
        foldersCancellable = libraryStore.$completeLibraryFolderSummaries
            .dropFirst()
            .sink { [weak self] folders in
                self?.applyFolders(folders, resetsSelection: false)
            }
        detailsCancellable = libraryStore.$completeLibraryFolderDetailsByPath
            .dropFirst()
            .sink { [weak self] detailsByPath in
                self?.applyCurrentDetail(from: detailsByPath)
            }
    }

    var folderStatus: LibraryStatus {
        libraryStore.completeLibraryStatus
    }

    var folders: [CompleteLibraryFolderSummaryPresentation] {
        libraryStore.completeLibraryFolderSummaries
    }

    var detailStatus: LibraryStatus {
        guard case .folderDetail(let folderPath, _) = level else {
            return .idle
        }
        return libraryStore.completeLibraryFolderDetailStatusesByPath[
            folderPath
        ] ?? .idle
    }

    var detail: CompleteLibraryFolderDetailPresentation? {
        guard case .folderDetail(let folderPath, _) = level else {
            return nil
        }
        return libraryStore.completeLibraryFolderDetailsByPath[folderPath]
    }

    func activate(refreshesExistingSnapshot: Bool = false) {
        guard isActive else {
            return
        }
        if !didActivate {
            didActivate = true
            applyFolders(folders, resetsSelection: true)
        }
        if refreshesExistingSnapshot || folderStatus != .completed {
            requestFolders()
        }
        if case .folderDetail(let folderPath, _) = level,
           refreshesExistingSnapshot || detail == nil {
            requestFolderDetail(folderPath)
        }
    }

    func refreshForSourceRevision() {
        guard isActive, didActivate else {
            return
        }
        requestFolders()
        if case .folderDetail(let folderPath, _) = level {
            requestFolderDetail(folderPath)
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
        if let detail {
            applyDetail(detail, resetsSelection: true)
        } else {
            requestFolderDetail(folder.folderPath)
        }
        return true
    }

    @discardableResult
    func returnToFolders() -> Bool {
        guard isActive, case .folderDetail = level else {
            return false
        }
        episodeSelection?.invalidate()
        episodeSelection = nil
        level = .folders
        return true
    }

    func primaryActionVideo(
        itemID: String? = nil
    ) -> CompleteLibraryVideoPresentation? {
        guard isActive,
              let detail,
              let resolvedItemID = itemID ?? episodeSelection?.selectedItemID,
              let video = detail.videos.first(where: {
                  $0.id == resolvedItemID
              }),
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
        foldersCancellable?.cancel()
        foldersCancellable = nil
        detailsCancellable?.cancel()
        detailsCancellable = nil
        folderSelection.invalidate()
        episodeSelection?.invalidate()
        episodeSelection = nil
        level = .folders
    }

    private func applyFolders(
        _ folders: [CompleteLibraryFolderSummaryPresentation],
        resetsSelection: Bool
    ) {
        guard isActive, didActivate else {
            return
        }
        folderSelection.replaceItems(
            orderedItemIDs: folders.map(\.id),
            availableItemIDs: Set(folders.compactMap { folder in
                folder.episodeCount > 0 ? folder.id : nil
            }),
            resetsSelection: resetsSelection
        )
        reconcileOpenDetail(with: folders)
    }

    private func applyCurrentDetail(
        from detailsByPath: [String: CompleteLibraryFolderDetailPresentation]
    ) {
        guard isActive,
              case .folderDetail(let folderPath, _) = level,
              let detail = detailsByPath[folderPath]
        else {
            return
        }
        applyDetail(detail, resetsSelection: false)
    }

    private func applyDetail(
        _ detail: CompleteLibraryFolderDetailPresentation,
        resetsSelection: Bool
    ) {
        guard isActive,
              case .folderDetail(let folderPath, _) = level,
              detail.folderPath == folderPath
        else {
            return
        }
        episodeSelection?.replaceItems(
            orderedItemIDs: detail.videos.map(\.id),
            availableItemIDs: Set(detail.videos.compactMap { video in
                isVideoAvailable(video.videoPath) ? video.id : nil
            }),
            resetsSelection: resetsSelection
        )
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
            _ = returnToFolders()
            return
        }
        level = .folderDetail(
            folderPath: refreshedFolder.folderPath,
            folderTitle: refreshedFolder.folderTitle
        )
    }
}
