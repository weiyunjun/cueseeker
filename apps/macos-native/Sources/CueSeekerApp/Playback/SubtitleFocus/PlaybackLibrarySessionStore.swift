import Combine
import CueSeekerCore
import Foundation

@MainActor
final class PlaybackLibrarySessionStore: ObservableObject {
    let libraryStore: LibraryStore
    let folderPath: String
    let selection = PlaybackMediaSelectionStore()

    private let initialVideoPath: String?
    private let requestFolderDetail: @MainActor (String) -> Void
    private let isVideoAvailable: @MainActor (String) -> Bool
    private var detailsCancellable: AnyCancellable?
    private var didActivate = false
    private var isActive = true

    init(
        libraryStore: LibraryStore,
        folderPath: String,
        initialVideoPath: String? = nil,
        requestFolderDetail: @escaping @MainActor (String) -> Void = { _ in },
        isVideoAvailable: @escaping @MainActor (String) -> Bool = {
            FileManager.default.fileExists(atPath: $0)
        }
    ) {
        self.libraryStore = libraryStore
        self.folderPath = folderPath
        self.initialVideoPath = initialVideoPath.map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        }
        self.requestFolderDetail = requestFolderDetail
        self.isVideoAvailable = isVideoAvailable
        detailsCancellable = libraryStore.$completeLibraryFolderDetailsByPath
            .dropFirst()
            .sink { [weak self] detailsByPath in
                self?.applyCurrentDetail(from: detailsByPath)
            }
    }

    var detailStatus: LibraryStatus {
        libraryStore.completeLibraryFolderDetailStatusesByPath[
            folderPath
        ] ?? .idle
    }

    var detail: CompleteLibraryFolderDetailPresentation? {
        libraryStore.completeLibraryFolderDetailsByPath[folderPath]
    }

    func activate(refreshesExistingSnapshot: Bool = false) {
        guard isActive else {
            return
        }
        if !didActivate {
            didActivate = true
            if let detail {
                applyDetail(detail, resetsSelection: true)
            }
        }
        if refreshesExistingSnapshot || detail == nil {
            requestFolderDetail(folderPath)
        }
    }

    func refreshForSourceRevision() {
        guard isActive, didActivate else {
            return
        }
        requestFolderDetail(folderPath)
    }

    @discardableResult
    func moveSelection(_ direction: PlaybackMediaSelectionDirection) -> Bool {
        guard isActive else {
            return false
        }
        return selection.move(direction)
    }

    func primaryActionVideo(
        itemID: String? = nil
    ) -> CompleteLibraryVideoPresentation? {
        guard isActive,
              let detail,
              let resolvedItemID = itemID ?? selection.selectedItemID,
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
        detailsCancellable?.cancel()
        detailsCancellable = nil
        selection.invalidate()
    }

    private func applyCurrentDetail(
        from detailsByPath: [String: CompleteLibraryFolderDetailPresentation]
    ) {
        guard isActive,
              let detail = detailsByPath[folderPath]
        else {
            return
        }
        applyDetail(
            detail,
            resetsSelection: selection.orderedItemIDs.isEmpty
        )
    }

    private func applyDetail(
        _ detail: CompleteLibraryFolderDetailPresentation,
        resetsSelection: Bool
    ) {
        guard isActive, detail.folderPath == folderPath else {
            return
        }
        selection.replaceItems(
            orderedItemIDs: detail.videos.map(\.id),
            availableItemIDs: Set(detail.videos.compactMap { video in
                isVideoAvailable(video.videoPath) ? video.id : nil
            }),
            resetsSelection: resetsSelection,
            preferredSelectionID: resetsSelection
                ? preferredInitialVideoID(in: detail)
                : nil
        )
    }

    private func preferredInitialVideoID(
        in detail: CompleteLibraryFolderDetailPresentation
    ) -> String? {
        guard let initialVideoPath else {
            return nil
        }
        return detail.videos.first { video in
            URL(fileURLWithPath: video.videoPath).standardizedFileURL.path
                == initialVideoPath
        }?.id
    }
}
