import Combine
import CueSeekerCore
import Foundation

@MainActor
final class PlaybackRecentSessionStore: ObservableObject {
    let libraryStore: LibraryStore
    let selection = PlaybackMediaSelectionStore()

    private let requestSource: @MainActor () -> Void
    private let isVideoAvailable: @MainActor (String) -> Bool
    private var itemsCancellable: AnyCancellable?
    private var didActivate = false
    private var isActive = true

    init(
        libraryStore: LibraryStore,
        requestSource: @escaping @MainActor () -> Void = {},
        isVideoAvailable: @escaping @MainActor (String) -> Bool = {
            FileManager.default.fileExists(atPath: $0)
        }
    ) {
        self.libraryStore = libraryStore
        self.requestSource = requestSource
        self.isVideoAvailable = isVideoAvailable
        itemsCancellable = libraryStore.$testRecentWatchingItems
            .dropFirst()
            .sink { [weak self] items in
                self?.applyItems(items, resetsSelection: false)
            }
    }

    var status: LibraryStatus {
        libraryStore.testRecentWatchingStatus
    }

    var items: [RecentLibraryWatchingPresentation] {
        libraryStore.testRecentWatchingItems
    }

    func activate(refreshesExistingSnapshot: Bool = false) {
        guard isActive else {
            return
        }
        if !didActivate {
            didActivate = true
            applyItems(items, resetsSelection: true)
        }
        if refreshesExistingSnapshot || status != .completed {
            requestSource()
        }
    }

    func primaryActionItem(
        itemID: String? = nil
    ) -> RecentLibraryWatchingPresentation? {
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
        itemsCancellable?.cancel()
        itemsCancellable = nil
        selection.invalidate()
    }

    private func applyItems(
        _ items: [RecentLibraryWatchingPresentation],
        resetsSelection: Bool
    ) {
        guard isActive, didActivate else {
            return
        }
        selection.replaceItems(
            orderedItemIDs: items.map(\.id),
            availableItemIDs: Set(items.compactMap { item in
                isVideoAvailable(item.videoPath) ? item.id : nil
            }),
            resetsSelection: resetsSelection
        )
    }
}
