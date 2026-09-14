import Combine
import CueSeekerCore
import Foundation

enum PlaybackPlaylistSourceKind: Hashable, Sendable {
    case search
    case excerpt
}

struct PlaybackPlaylistExcerptTableContext: Hashable, Sendable {
    let runID: UUID
    let searchText: String
    let totalCount: Int

    init(
        runID: UUID = UUID(),
        searchText: String,
        totalCount: Int
    ) {
        self.runID = runID
        self.searchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        self.totalCount = max(0, totalCount)
    }
}

enum PlaybackPlaylistExcerptScope: Hashable, Sendable {
    case explicitIDs([Int64])
    case databaseOrder
    case table(PlaybackPlaylistExcerptTableContext)
}

struct PlaybackSearchPromotion: Equatable, Sendable {
    let query: String
    let scopePaths: [String]
    let selectedOrdinal: Int

    init(query: String, scopePaths: [String], selectedOrdinal: Int) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scopePaths = scopePaths
        self.selectedOrdinal = max(0, selectedOrdinal)
    }
}

enum PlaybackPlaylistSourceOrigin: Hashable, Sendable {
    case search(resultListGeneration: UInt64)
    case cue(cueID: Int64)
    case excerpt(scope: PlaybackPlaylistExcerptScope)
    case unspecified(PlaybackPlaylistSourceKind)

    var kind: PlaybackPlaylistSourceKind {
        switch self {
        case .search, .cue:
            .search
        case .excerpt:
            .excerpt
        case .unspecified(let kind):
            kind
        }
    }
}

enum PlaybackPlaylistItemIdentity: Hashable, Sendable {
    case search(Int64)
    case excerpt(Int64)
}

enum PlaybackPlaylistPrimaryCueIdentity: Hashable, Sendable {
    case cue(Int64)
    case legacyExcerpt(Int64)
}

enum PlaybackPlaylistItemTarget: Equatable, Sendable {
    case search(SubtitleSearchResult)
    case excerpt(Excerpt)
}

struct PlaybackPlaylistItem: Equatable, Sendable {
    let identity: PlaybackPlaylistItemIdentity
    let primaryCueIdentity: PlaybackPlaylistPrimaryCueIdentity
    let ordinal: Int
    let primaryCueText: String
    let additionalCueTexts: [String]
    let target: PlaybackPlaylistItemTarget
    let actionContext: PlaybackSubtitleFocusActionContext?

    var videoPath: String {
        switch target {
        case .search(let result):
            result.videoPath
        case .excerpt(let excerpt):
            excerpt.videoPath
        }
    }

    var displayTitle: String {
        switch target {
        case .search(let result):
            result.displayTitle
        case .excerpt(let excerpt):
            excerpt.displayTitle
        }
    }

    var timeRange: String {
        switch target {
        case .search(let result):
            result.timeRange
        case .excerpt(let excerpt):
            excerpt.timeRange
        }
    }

    init(searchResult: SubtitleSearchResult, ordinal: Int) {
        let resolvedOrdinal = max(0, ordinal)
        identity = .search(searchResult.entryID)
        primaryCueIdentity = .cue(searchResult.entryID)
        self.ordinal = resolvedOrdinal
        primaryCueText = searchResult.content
        additionalCueTexts = Self.additionalCueTexts(
            cueGroupTexts: searchResult.cueGroupLines,
            primaryGroupIndex: searchResult.primaryGroupIndex
        )
        target = .search(searchResult)
        actionContext = PlaybackSubtitleFocusActionContext(
            source: SubtitleFocusSourceIdentity(
                subtitleFileID: searchResult.subtitleFileID,
                videoPath: searchResult.videoPath,
                subtitlePath: searchResult.subtitlePath,
                subtitleFormat: searchResult.subtitleFormat
            ),
            cue: SubtitleFocusCue(
                id: searchResult.entryID,
                cueGroupID: searchResult.cueGroupID,
                ordinal: resolvedOrdinal,
                eventIndex: searchResult.cueEventIndex,
                displayOrder: searchResult.cueDisplayOrder,
                startMilliseconds: searchResult.startMilliseconds,
                endMilliseconds: searchResult.endMilliseconds,
                content: searchResult.content
            )
        )
    }

    init(
        excerpt: Excerpt,
        cuePresentation: ExcerptCuePresentation?,
        ordinal: Int
    ) {
        let resolvedOrdinal = max(0, ordinal)
        identity = .excerpt(excerpt.id)
        primaryCueIdentity = cuePresentation?.cueID.map {
            .cue($0)
        } ?? .legacyExcerpt(excerpt.id)
        self.ordinal = resolvedOrdinal
        primaryCueText = excerpt.content
        additionalCueTexts = Self.additionalCueTexts(
            cueGroupTexts: cuePresentation?.cueGroupTexts ?? [],
            primaryGroupIndex: cuePresentation?.primaryGroupIndex
        )
        target = .excerpt(excerpt)

        if let cueID = cuePresentation?.cueID,
           let cueGroupID = cuePresentation?.cueGroupID,
           let eventIndex = excerpt.cueEventIndex {
            actionContext = PlaybackSubtitleFocusActionContext(
                source: SubtitleFocusSourceIdentity(
                    subtitleFileID: excerpt.subtitleFileID,
                    videoPath: excerpt.videoPath,
                    subtitlePath: excerpt.subtitlePath,
                    subtitleFormat: excerpt.subtitleFormat
                ),
                cue: SubtitleFocusCue(
                    id: cueID,
                    cueGroupID: cueGroupID,
                    ordinal: resolvedOrdinal,
                    eventIndex: eventIndex,
                    displayOrder: excerpt.cueDisplayOrder ?? 0,
                    startMilliseconds: excerpt.startMilliseconds,
                    endMilliseconds: excerpt.endMilliseconds,
                    content: excerpt.content
                )
            )
        } else {
            actionContext = nil
        }
    }

    func cueResult() -> PlaybackCueResult {
        PlaybackCueResult(
            itemID: AnyHashable(identity),
            primaryCueIdentity: AnyHashable(primaryCueIdentity),
            primaryCueText: primaryCueText,
            additionalCueTexts: additionalCueTexts,
            metadata: PlaybackCueMetadata(
                ordinal: ordinal,
                displayTitle: displayTitle,
                timeRange: timeRange
            )
        )
    }

    private static func additionalCueTexts(
        cueGroupTexts: [String],
        primaryGroupIndex: Int?
    ) -> [String] {
        guard let primaryGroupIndex,
              cueGroupTexts.indices.contains(primaryGroupIndex)
        else {
            return []
        }

        var result = cueGroupTexts
        result.remove(at: primaryGroupIndex)
        return result
    }
}

struct PlaybackPlaylistSourceBoundary: Equatable {
    let datasetID: UUID
    let generation: UInt64
    let revision: UInt64
    let totalCount: Int
}

struct PlaybackPlaylistPosition: Equatable, Sendable {
    let datasetID: UUID
    let itemIdentity: PlaybackPlaylistItemIdentity
    let ordinal: Int
}

typealias PlaybackPlaylistSharedItemProvider = @MainActor (
    _ ordinal: Int
) -> PlaybackPlaylistItem?

@MainActor
final class PlaybackPlaylistSource: ObservableObject {
    let origin: PlaybackPlaylistSourceOrigin

    var kind: PlaybackPlaylistSourceKind {
        origin.kind
    }

    @Published private(set) var boundary: PlaybackPlaylistSourceBoundary

    private var itemProvider: PlaybackPlaylistSharedItemProvider?
    private var isActive = true

    convenience init(
        kind: PlaybackPlaylistSourceKind,
        totalCount: Int,
        itemProvider: @escaping PlaybackPlaylistSharedItemProvider
    ) {
        self.init(
            origin: .unspecified(kind),
            totalCount: totalCount,
            itemProvider: itemProvider
        )
    }

    init(
        origin: PlaybackPlaylistSourceOrigin,
        totalCount: Int,
        itemProvider: @escaping PlaybackPlaylistSharedItemProvider
    ) {
        self.origin = origin
        self.itemProvider = itemProvider
        boundary = PlaybackPlaylistSourceBoundary(
            datasetID: UUID(),
            generation: 1,
            revision: 0,
            totalCount: max(0, totalCount)
        )
    }

    var hasItems: Bool {
        isActive && boundary.totalCount > 0
    }

    func item(at ordinal: Int) -> PlaybackPlaylistItem? {
        guard isActive,
              boundary.totalCount > ordinal,
              ordinal >= 0
        else {
            return nil
        }
        guard let item = itemProvider?(ordinal), item.ordinal == ordinal else {
            return nil
        }
        return item
    }

    @discardableResult
    func updateBoundary(totalCount: Int) -> Bool {
        guard isActive else {
            return false
        }

        publishBoundary(totalCount: totalCount)
        return true
    }

    @discardableResult
    func replaceResidentItems(
        totalCount: Int,
        itemProvider: @escaping PlaybackPlaylistSharedItemProvider
    ) -> Bool {
        guard isActive else {
            return false
        }

        self.itemProvider = itemProvider
        publishBoundary(totalCount: totalCount)
        return true
    }

    private func publishBoundary(totalCount: Int) {
        let resolvedTotalCount = max(0, totalCount)
        let changesIdentityBoundary = boundary.totalCount != resolvedTotalCount
        boundary = PlaybackPlaylistSourceBoundary(
            datasetID: boundary.datasetID,
            generation: changesIdentityBoundary
                ? boundary.generation &+ 1
                : boundary.generation,
            revision: changesIdentityBoundary
                ? 0
                : boundary.revision &+ 1,
            totalCount: resolvedTotalCount
        )
    }

    func itemIdentity(at ordinal: Int) -> PlaybackPlaylistItemIdentity? {
        item(at: ordinal)?.identity
    }

    func makeSessionWindowStore(
        includingEmpty: Bool = false,
        initialPosition: PlaybackPlaylistPosition? = nil
    ) -> PlaybackPlaylistSessionWindowStore? {
        guard isActive,
              includingEmpty || boundary.totalCount > 0
        else {
            return nil
        }
        return PlaybackPlaylistSessionWindowStore(
            source: self,
            initialPosition: initialPosition
        )
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        itemProvider = nil
        boundary = PlaybackPlaylistSourceBoundary(
            datasetID: boundary.datasetID,
            generation: boundary.generation &+ 1,
            revision: 0,
            totalCount: 0
        )
    }
}

@MainActor
final class PlaybackPlaylistSessionWindowStore: ObservableObject {
    @Published private(set) var snapshot: PlaybackVirtualReelSnapshot
    @Published private(set) var selectedOrdinal: Int?

    private(set) var selectedItemIdentity: PlaybackPlaylistItemIdentity?
    private var source: PlaybackPlaylistSource?
    private var boundaryCancellable: AnyCancellable?
    private var isActive = true

    init(
        source: PlaybackPlaylistSource,
        initialPosition: PlaybackPlaylistPosition? = nil
    ) {
        self.source = source
        let boundary = source.boundary
        if let initialPosition,
           initialPosition.datasetID == boundary.datasetID,
           initialPosition.ordinal >= 0,
           initialPosition.ordinal < boundary.totalCount,
           source.itemIdentity(at: initialPosition.ordinal)
               == initialPosition.itemIdentity {
            selectedOrdinal = initialPosition.ordinal
            selectedItemIdentity = initialPosition.itemIdentity
        } else {
            let fallbackOrdinal = boundary.totalCount > 0 ? 0 : nil
            selectedOrdinal = fallbackOrdinal
            selectedItemIdentity = fallbackOrdinal.flatMap {
                source.itemIdentity(at: $0)
            }
        }
        snapshot = Self.snapshot(boundary: boundary)
        boundaryCancellable = source.$boundary
            .dropFirst()
            .sink { [weak self] boundary in
                self?.applySourceBoundary(boundary)
            }
    }

    var reelDatasetID: String? {
        (snapshot.datasetID.base as? UUID)?.uuidString
    }

    func knownItemIdentity(at ordinal: Int) -> PlaybackPlaylistItemIdentity? {
        source?.itemIdentity(at: ordinal)
    }

    func item(at ordinal: Int) -> PlaybackPlaylistItem? {
        source?.item(at: ordinal)
    }

    func resetSelectionToFirst() {
        selectedOrdinal = snapshot.totalCount > 0 ? 0 : nil
        selectedItemIdentity = selectedOrdinal.flatMap { ordinal in
            item(at: ordinal)?.identity
                ?? source?.itemIdentity(at: ordinal)
        }
    }

    @discardableResult
    func restoreSelection(
        itemIdentity: PlaybackPlaylistItemIdentity,
        at ordinal: Int
    ) -> Bool {
        guard isActive,
              ordinal >= 0,
              ordinal < snapshot.totalCount,
              source?.itemIdentity(at: ordinal) == itemIdentity
        else {
            return false
        }
        selectedOrdinal = ordinal
        selectedItemIdentity = itemIdentity
        return true
    }

    @discardableResult
    func commitSelection(
        _ commit: PlaybackVirtualReelSelectionCommit
    ) -> Bool {
        guard isActive,
              let reelDatasetID,
              commit.datasetID == AnyHashable(reelDatasetID),
              commit.generation == snapshot.generation,
              snapshot.loadedOrdinalRange.contains(commit.ordinal),
              let selectedItem = item(at: commit.ordinal)
        else {
            return false
        }
        selectedOrdinal = commit.ordinal
        selectedItemIdentity = selectedItem.identity
        return true
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        boundaryCancellable?.cancel()
        boundaryCancellable = nil
        source = nil
        selectedOrdinal = nil
        selectedItemIdentity = nil
        snapshot = PlaybackVirtualReelSnapshot(
            datasetID: snapshot.datasetID,
            generation: snapshot.generation &+ 1,
            revision: 0,
            totalCount: 0,
            loadedOrdinalRange: 0..<0,
            loadedItemCount: 0,
            isComplete: true
        )
    }

    private func applySourceBoundary(_ boundary: PlaybackPlaylistSourceBoundary) {
        guard isActive else {
            return
        }
        if let selectedOrdinal,
           selectedOrdinal >= boundary.totalCount {
            self.selectedOrdinal = boundary.totalCount > 0 ? 0 : nil
            selectedItemIdentity = self.selectedOrdinal.flatMap {
                source?.itemIdentity(at: $0)
            }
        } else if selectedOrdinal == nil, boundary.totalCount > 0 {
            selectedOrdinal = 0
            selectedItemIdentity = source?.itemIdentity(at: 0)
        } else if boundary.totalCount == 0 {
            selectedItemIdentity = nil
        } else if let selectedOrdinal {
            selectedItemIdentity = source?.itemIdentity(at: selectedOrdinal)
        }
        snapshot = Self.snapshot(boundary: boundary)
    }

    private static func snapshot(
        boundary: PlaybackPlaylistSourceBoundary
    ) -> PlaybackVirtualReelSnapshot {
        PlaybackVirtualReelSnapshot(
            datasetID: AnyHashable(boundary.datasetID),
            generation: boundary.generation,
            revision: boundary.revision,
            totalCount: boundary.totalCount,
            loadedOrdinalRange: 0..<boundary.totalCount,
            loadedItemCount: boundary.totalCount,
            isComplete: true
        )
    }
}

// Playlist was the first playback module to consume this result transport.
// The neutral names let Playlist, Search, and Excerpt retain their complete
// session dataset while sharing one viewport-virtualized Reel.
typealias PlaybackCueResultItemIdentity = PlaybackPlaylistItemIdentity
typealias PlaybackCueResultItem = PlaybackPlaylistItem
typealias PlaybackCueResultSource = PlaybackPlaylistSource
typealias PlaybackCueResultSessionWindowStore = PlaybackPlaylistSessionWindowStore
