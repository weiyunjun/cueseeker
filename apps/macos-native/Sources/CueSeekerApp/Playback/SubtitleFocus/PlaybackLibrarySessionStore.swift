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
    private var detailsCancellable: AnyCancellable?
    private var statusesCancellable: AnyCancellable?
    private var didActivate = false
    private var didRequestDetail = false
    private var isActive = true
    /// The folder as it was shown when the database changed under it.
    private var heldDetail: CompleteLibraryFolderDetailPresentation?

    init(
        libraryStore: LibraryStore,
        folderPath: String,
        initialVideoPath: String? = nil,
        requestFolderDetail: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        self.libraryStore = libraryStore
        self.folderPath = folderPath
        self.initialVideoPath = initialVideoPath.map {
            URL.fromMediaPath($0).mediaPath
        }
        self.requestFolderDetail = requestFolderDetail
        detailsCancellable = libraryStore.$completeLibraryFolderDetailsByPath
            .dropFirst()
            .sink { [weak self] detailsByPath in
                self?.applyCurrentDetail(from: detailsByPath)
            }
        statusesCancellable = libraryStore.$completeLibraryFolderDetailStatusesByPath
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    var detailStatus: LibraryStatus {
        guard heldDetail == nil else {
            return .completed
        }
        return libraryStore.completeLibraryFolderDetailStatusesByPath[
            folderPath
        ] ?? .idle
    }

    var detail: CompleteLibraryFolderDetailPresentation? {
        heldDetail ?? libraryStore.completeLibraryFolderDetailsByPath[folderPath]
    }

    var isHoldingDetail: Bool {
        heldDetail != nil
    }

    var isDetailResolved: Bool {
        if detail != nil {
            return true
        }
        switch detailStatus {
        case .completed, .failed:
            return libraryStore.completeLibraryFolderDetailTasks[folderPath] == nil
        case .idle, .loading:
            return false
        }
    }

    var firstScreenCoverKeys: [LibraryCoverImageKey] {
        guard let detail else {
            return []
        }
        return LibraryCoverImagePipeline.boundedUniqueKeys(
            from: detail.videos.compactMap {
                LibraryCoverImageKey.current(
                    path: $0.coverPath,
                    revision: $0.coverRevision
                )
            }
        )
    }

    var isReadyForPresentation: Bool {
        guard isDetailResolved else {
            return false
        }
        return firstScreenCoverKeys.allSatisfy {
            LibraryCoverImagePipeline.shared.isReadyForPresentation(for: $0)
        }
    }

    var cachedFirstScreenCoverStats: LibraryCoverPrewarmStats {
        let keys = firstScreenCoverKeys
        let hits = keys.filter {
            LibraryCoverImagePipeline.shared.isReadyForPresentation(for: $0)
        }.count
        return LibraryCoverPrewarmStats(
            totalCount: keys.count,
            cacheHitCount: hits,
            decodedCount: 0,
            elapsedMilliseconds: 0
        )
    }

    @discardableResult
    func prepareForPresentation() async -> (dataReadyAt: UInt64, coverStats: LibraryCoverPrewarmStats) {
        activate()
        await libraryStore.completeLibraryFolderDetailTasks[folderPath]?.value
        let dataReadyAt = DebugInteractionLatencyProbe.now()
        guard !Task.isCancelled else {
            return (dataReadyAt, .zero)
        }
        let stats = await LibraryCoverImagePipeline.shared.prewarm(
            keys: firstScreenCoverKeys
        )
        return (dataReadyAt, stats)
    }

    /// Keeps the folder as it is shown now: a database change must not move
    /// what the open Playback Overlay shows. A folder still loading has
    /// nothing shown to keep and goes on loading.
    func holdDetail() {
        guard isActive, heldDetail == nil else {
            return
        }
        heldDetail = libraryStore.completeLibraryFolderDetailsByPath[folderPath]
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
        if heldDetail == nil {
            let needsInitialRequest = !didRequestDetail && detail == nil && detailStatus != .completed
            if needsInitialRequest || refreshesExistingSnapshot {
                didRequestDetail = true
                requestFolderDetail(folderPath)
            }
        }
    }

    func refreshForSourceRevision() {
        guard isActive, didActivate, heldDetail == nil else {
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

    @discardableResult
    func selectFromAccessibility(_ itemID: String) -> Bool {
        guard isActive else {
            return false
        }
        return selection.selectFromAccessibility(itemID)
    }

    func primaryActionVideo(
        itemID: String? = nil
    ) -> CompleteLibraryVideoPresentation? {
        guard isActive,
              let detail,
              let resolvedItemID = itemID ?? selection.selectedItemID,
              let video = detail.videos.first(where: {
                  $0.id == resolvedItemID
              })
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
        statusesCancellable?.cancel()
        statusesCancellable = nil
        selection.invalidate()
    }

    private func applyCurrentDetail(
        from detailsByPath: [String: CompleteLibraryFolderDetailPresentation]
    ) {
        guard isActive,
              heldDetail == nil
        else {
            return
        }
        guard let detail = detailsByPath[folderPath] else {
            objectWillChange.send()
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
            // Every video the database holds can be opened; one whose file
            // is missing fails to load in the player instead.
            availableItemIDs: Set(detail.videos.map(\.id)),
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
            URL.fromMediaPath(video.videoPath).mediaPath
                == initialVideoPath
        }?.id
    }
}
