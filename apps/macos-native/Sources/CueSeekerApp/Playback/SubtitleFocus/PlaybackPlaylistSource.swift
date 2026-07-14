import Combine
import CueSeekerCore
import Foundation

enum PlaybackPlaylistSourceKind: Hashable, Sendable {
    case search
    case shiori
}

enum PlaybackPlaylistShioriScope: Hashable, Sendable {
    case explicitIDs([Int64])
    case databaseOrder
}

struct PlaybackSearchPlaylistContext: Hashable, Sendable {
    let query: String
    let scopePaths: [String]
}

enum PlaybackPlaylistSourceOrigin: Hashable, Sendable {
    case search(resultListGeneration: UInt64)
    case playbackSearch(
        runID: UUID,
        context: PlaybackSearchPlaylistContext
    )
    case shiori(scope: PlaybackPlaylistShioriScope)
    case unspecified(PlaybackPlaylistSourceKind)

    var kind: PlaybackPlaylistSourceKind {
        switch self {
        case .search, .playbackSearch:
            .search
        case .shiori:
            .shiori
        case .unspecified(let kind):
            kind
        }
    }
}

enum PlaybackPlaylistItemIdentity: Hashable, Sendable {
    case search(Int64)
    case shiori(Int64)
}

enum PlaybackPlaylistPrimaryCueIdentity: Hashable, Sendable {
    case cue(Int64)
    case legacyShiori(Int64)
}

enum PlaybackPlaylistItemTarget: Equatable, Sendable {
    case search(SubtitleSearchResult)
    case shiori(Shiori)
}

struct PlaybackPlaylistItem: Equatable, Sendable {
    let identity: PlaybackPlaylistItemIdentity
    let primaryCueIdentity: PlaybackPlaylistPrimaryCueIdentity
    let ordinal: Int
    let primaryCueText: String
    let additionalCueTexts: [String]
    let target: PlaybackPlaylistItemTarget
    let actionContext: PlaybackSubtitleFocusActionContext?

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
        shiori: Shiori,
        cuePresentation: ShioriCuePresentation?,
        ordinal: Int
    ) {
        let resolvedOrdinal = max(0, ordinal)
        identity = .shiori(shiori.id)
        primaryCueIdentity = cuePresentation?.cueID.map {
            .cue($0)
        } ?? .legacyShiori(shiori.id)
        self.ordinal = resolvedOrdinal
        primaryCueText = shiori.content
        additionalCueTexts = Self.additionalCueTexts(
            cueGroupTexts: cuePresentation?.cueGroupTexts ?? [],
            primaryGroupIndex: cuePresentation?.primaryGroupIndex
        )
        target = .shiori(shiori)

        if let cueID = cuePresentation?.cueID,
           let cueGroupID = cuePresentation?.cueGroupID,
           let eventIndex = shiori.cueEventIndex {
            actionContext = PlaybackSubtitleFocusActionContext(
                source: SubtitleFocusSourceIdentity(
                    videoPath: shiori.videoPath,
                    subtitlePath: shiori.subtitlePath,
                    subtitleFormat: shiori.subtitleFormat
                ),
                cue: SubtitleFocusCue(
                    id: cueID,
                    cueGroupID: cueGroupID,
                    ordinal: resolvedOrdinal,
                    eventIndex: eventIndex,
                    displayOrder: shiori.cueDisplayOrder ?? 0,
                    startMilliseconds: shiori.startMilliseconds,
                    endMilliseconds: shiori.endMilliseconds,
                    content: shiori.content
                )
            )
        } else {
            actionContext = nil
        }
    }

    func cueResult(sequenceNumber: Int?) -> PlaybackCueResult {
        PlaybackCueResult(
            itemID: AnyHashable(identity),
            primaryCueIdentity: AnyHashable(primaryCueIdentity),
            primaryCueText: primaryCueText,
            additionalCueTexts: additionalCueTexts,
            sequenceNumber: sequenceNumber
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
    let knownItemIDsByOrdinal: [Int: PlaybackPlaylistItemIdentity]
}

struct PlaybackPlaylistSourceWindowRequest: Equatable {
    let datasetID: UUID
    let generation: UInt64
    let sourceRevision: UInt64
    let totalCount: Int
    let ordinalRange: Range<Int>
}

struct PlaybackPlaylistSourceWindowResponse: Equatable {
    let datasetID: UUID
    let generation: UInt64
    let sourceRevision: UInt64
    let totalCount: Int
    let ordinalRange: Range<Int>
    let items: [PlaybackPlaylistItem]

    init(
        request: PlaybackPlaylistSourceWindowRequest,
        items: [PlaybackPlaylistItem]
    ) {
        datasetID = request.datasetID
        generation = request.generation
        sourceRevision = request.sourceRevision
        totalCount = request.totalCount
        ordinalRange = request.ordinalRange
        self.items = items
    }
}

typealias PlaybackPlaylistSourceWindowLoader = @MainActor (
    PlaybackPlaylistSourceWindowRequest
) async -> PlaybackPlaylistSourceWindowResponse?

@MainActor
final class PlaybackPlaylistSource: ObservableObject {
    let origin: PlaybackPlaylistSourceOrigin

    var kind: PlaybackPlaylistSourceKind {
        origin.kind
    }

    @Published private(set) var boundary: PlaybackPlaylistSourceBoundary

    private let loader: PlaybackPlaylistSourceWindowLoader
    private var invalidationHandler: (@MainActor () -> Void)?
    private var isActive = true

    convenience init(
        kind: PlaybackPlaylistSourceKind,
        totalCount: Int,
        knownItemIDsByOrdinal: [Int: PlaybackPlaylistItemIdentity],
        loader: @escaping PlaybackPlaylistSourceWindowLoader
    ) {
        self.init(
            origin: .unspecified(kind),
            totalCount: totalCount,
            knownItemIDsByOrdinal: knownItemIDsByOrdinal,
            invalidationHandler: nil,
            loader: loader
        )
    }

    init(
        origin: PlaybackPlaylistSourceOrigin,
        totalCount: Int,
        knownItemIDsByOrdinal: [Int: PlaybackPlaylistItemIdentity],
        invalidationHandler: (@MainActor () -> Void)? = nil,
        loader: @escaping PlaybackPlaylistSourceWindowLoader
    ) {
        self.origin = origin
        self.loader = loader
        self.invalidationHandler = invalidationHandler
        let resolvedTotalCount = max(0, totalCount)
        boundary = PlaybackPlaylistSourceBoundary(
            datasetID: UUID(),
            generation: 1,
            revision: 0,
            totalCount: resolvedTotalCount,
            knownItemIDsByOrdinal: Self.normalizedKnownItemIDs(
                knownItemIDsByOrdinal,
                totalCount: resolvedTotalCount
            )
        )
    }

    var hasItems: Bool {
        isActive && boundary.totalCount > 0
    }

    @discardableResult
    func updateBoundary(
        totalCount: Int,
        knownItemIDsByOrdinal: [Int: PlaybackPlaylistItemIdentity]
    ) -> Bool {
        guard isActive else {
            return false
        }

        let resolvedTotalCount = max(0, totalCount)
        let resolvedKnownIDs = Self.normalizedKnownItemIDs(
            knownItemIDsByOrdinal,
            totalCount: resolvedTotalCount
        )
        let changesIdentityBoundary = boundary.totalCount != resolvedTotalCount
            || boundary.knownItemIDsByOrdinal != resolvedKnownIDs
        boundary = PlaybackPlaylistSourceBoundary(
            datasetID: boundary.datasetID,
            generation: changesIdentityBoundary
                ? boundary.generation &+ 1
                : boundary.generation,
            revision: changesIdentityBoundary
                ? 0
                : boundary.revision &+ 1,
            totalCount: resolvedTotalCount,
            knownItemIDsByOrdinal: resolvedKnownIDs
        )
        return true
    }

    func makeSessionWindowStore(
        includingEmpty: Bool = false
    ) -> PlaybackPlaylistSessionWindowStore? {
        guard isActive,
              includingEmpty || boundary.totalCount > 0
        else {
            return nil
        }
        return PlaybackPlaylistSessionWindowStore(source: self)
    }

    func loadWindow(
        _ request: PlaybackPlaylistSourceWindowRequest
    ) async -> PlaybackPlaylistSourceWindowResponse? {
        guard accepts(request) else {
            return nil
        }
        let response = await loader(request)
        guard !Task.isCancelled,
              accepts(request),
              let response,
              response.datasetID == request.datasetID,
              response.generation == request.generation,
              response.sourceRevision == request.sourceRevision,
              response.totalCount == request.totalCount,
              response.ordinalRange == request.ordinalRange,
              response.items.count == request.ordinalRange.count,
              response.items.map(\.ordinal) == Array(request.ordinalRange),
              Set(response.items.map(\.identity)).count == response.items.count
        else {
            return nil
        }

        for item in response.items {
            if let knownID = boundary.knownItemIDsByOrdinal[item.ordinal],
               knownID != item.identity {
                return nil
            }
        }
        return response
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        boundary = PlaybackPlaylistSourceBoundary(
            datasetID: boundary.datasetID,
            generation: boundary.generation &+ 1,
            revision: 0,
            totalCount: 0,
            knownItemIDsByOrdinal: [:]
        )
        let handler = invalidationHandler
        invalidationHandler = nil
        handler?()
    }

    private func accepts(_ request: PlaybackPlaylistSourceWindowRequest) -> Bool {
        isActive
            && request.datasetID == boundary.datasetID
            && request.generation == boundary.generation
            && request.sourceRevision == boundary.revision
            && request.totalCount == boundary.totalCount
            && request.ordinalRange.lowerBound >= 0
            && request.ordinalRange.upperBound <= boundary.totalCount
            && request.ordinalRange.count
                <= PlaybackVirtualReelWindowPolicy.standard.itemCount
    }

    private static func normalizedKnownItemIDs(
        _ itemIDs: [Int: PlaybackPlaylistItemIdentity],
        totalCount: Int
    ) -> [Int: PlaybackPlaylistItemIdentity] {
        var seenIDs: Set<PlaybackPlaylistItemIdentity> = []
        var result: [Int: PlaybackPlaylistItemIdentity] = [:]
        for ordinal in itemIDs.keys.sorted() {
            guard ordinal >= 0,
                  ordinal < totalCount,
                  let identity = itemIDs[ordinal],
                  seenIDs.insert(identity).inserted
            else {
                continue
            }
            result[ordinal] = identity
        }
        return result
    }
}

@MainActor
final class PlaybackPlaylistSessionWindowStore: ObservableObject {
    @Published private(set) var snapshot: PlaybackVirtualReelSnapshot
    @Published private(set) var selectedOrdinal: Int?

    private(set) var items: [PlaybackPlaylistItem] = []
    private var source: PlaybackPlaylistSource?
    private var boundaryCancellable: AnyCancellable?
    private var loadTask: Task<Void, Never>?
    private var pendingRequest: PlaybackPlaylistSourceWindowRequest?
    private var revision: UInt64 = 0
    private var isActive = true

    init(source: PlaybackPlaylistSource) {
        self.source = source
        let boundary = source.boundary
        selectedOrdinal = boundary.totalCount > 0 ? 0 : nil
        snapshot = Self.emptySnapshot(boundary: boundary, revision: 0)
        boundaryCancellable = source.$boundary
            .dropFirst()
            .sink { [weak self] boundary in
                self?.applySourceBoundary(boundary)
            }
    }

    var retainedItemCount: Int {
        items.count
    }

    var reelDatasetID: String? {
        (snapshot.datasetID.base as? UUID)?.uuidString
    }

    func knownItemIdentity(at ordinal: Int) -> PlaybackPlaylistItemIdentity? {
        source?.boundary.knownItemIDsByOrdinal[ordinal]
    }

    func item(at ordinal: Int) -> PlaybackPlaylistItem? {
        guard let firstOrdinal = items.first?.ordinal else {
            return nil
        }
        let index = ordinal - firstOrdinal
        guard items.indices.contains(index), items[index].ordinal == ordinal else {
            return nil
        }
        return items[index]
    }

    func resetSelectionToFirst() {
        selectedOrdinal = snapshot.totalCount > 0 ? 0 : nil
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
              item(at: commit.ordinal) != nil
        else {
            return false
        }
        selectedOrdinal = commit.ordinal
        return true
    }

    @discardableResult
    func requestWindow(containing targetOrdinal: Int) -> Bool {
        guard isActive,
              let source,
              source.boundary.totalCount > 0
        else {
            return false
        }
        let boundary = source.boundary
        let target = min(max(0, targetOrdinal), boundary.totalCount - 1)
        let ordinalRange = PlaybackVirtualReelWindowPolicy.standard.windowRange(
            totalCount: boundary.totalCount,
            targetOrdinal: target
        )
        let request = PlaybackPlaylistSourceWindowRequest(
            datasetID: boundary.datasetID,
            generation: boundary.generation,
            sourceRevision: boundary.revision,
            totalCount: boundary.totalCount,
            ordinalRange: ordinalRange
        )
        loadTask?.cancel()
        pendingRequest = request
        loadTask = Task { @MainActor [weak self, weak source] in
            guard let self, let source else {
                return
            }
            guard let response = await source.loadWindow(request) else {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            _ = self.publishWindow(response)
        }
        return true
    }

    @discardableResult
    func requestWindow(_ request: PlaybackVirtualReelWindowRequest) -> Bool {
        guard request.datasetID == snapshot.datasetID,
              request.generation == snapshot.generation,
              request.revision == snapshot.revision
        else {
            return false
        }
        return requestWindow(containing: request.targetOrdinal)
    }

    @discardableResult
    func publishWindow(
        _ response: PlaybackPlaylistSourceWindowResponse
    ) -> Bool {
        guard isActive,
              let source,
              pendingRequest.map({ request in
                  response.datasetID == request.datasetID
                      && response.generation == request.generation
                      && response.sourceRevision == request.sourceRevision
                      && response.totalCount == request.totalCount
                      && response.ordinalRange == request.ordinalRange
              }) == true,
              source.boundary.datasetID == response.datasetID,
              source.boundary.generation == response.generation,
              source.boundary.revision == response.sourceRevision,
              source.boundary.totalCount == response.totalCount,
              response.items.count == response.ordinalRange.count,
              response.items.count
                <= PlaybackVirtualReelWindowPolicy.standard.itemCount
        else {
            return false
        }

        loadTask = nil
        pendingRequest = nil
        items = response.items
        revision &+= 1
        snapshot = PlaybackVirtualReelSnapshot(
            datasetID: AnyHashable(response.datasetID),
            generation: response.generation,
            revision: revision,
            totalCount: response.totalCount,
            loadedOrdinalRange: response.ordinalRange,
            loadedItemCount: response.items.count,
            isComplete: response.ordinalRange == 0..<response.totalCount
                && response.items.count == response.totalCount
        )
        if let selectedOrdinal,
           selectedOrdinal >= response.totalCount {
            self.selectedOrdinal = response.totalCount > 0 ? 0 : nil
        }
        return true
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        loadTask?.cancel()
        loadTask = nil
        pendingRequest = nil
        boundaryCancellable?.cancel()
        boundaryCancellable = nil
        source = nil
        items.removeAll(keepingCapacity: false)
        selectedOrdinal = nil
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
        loadTask?.cancel()
        loadTask = nil
        pendingRequest = nil
        items.removeAll(keepingCapacity: true)
        if snapshot.datasetID != AnyHashable(boundary.datasetID)
            || snapshot.generation != boundary.generation {
            revision = 0
        } else {
            revision &+= 1
        }
        if let selectedOrdinal,
           selectedOrdinal >= boundary.totalCount {
            self.selectedOrdinal = boundary.totalCount > 0 ? 0 : nil
        } else if selectedOrdinal == nil, boundary.totalCount > 0 {
            selectedOrdinal = 0
        }
        snapshot = Self.emptySnapshot(boundary: boundary, revision: revision)
    }

    private static func emptySnapshot(
        boundary: PlaybackPlaylistSourceBoundary,
        revision: UInt64
    ) -> PlaybackVirtualReelSnapshot {
        PlaybackVirtualReelSnapshot(
            datasetID: AnyHashable(boundary.datasetID),
            generation: boundary.generation,
            revision: revision,
            totalCount: boundary.totalCount,
            loadedOrdinalRange: 0..<0,
            loadedItemCount: 0,
            isComplete: boundary.totalCount == 0
        )
    }
}

// Playlist was the first playback module to consume this result-window
// transport. The neutral names make the same bounded transport available to
// standalone Shiori and Search modules without introducing another virtual
// list or changing the established playback-origin Playlist semantics.
typealias PlaybackCueResultItemIdentity = PlaybackPlaylistItemIdentity
typealias PlaybackCueResultItem = PlaybackPlaylistItem
typealias PlaybackCueResultSource = PlaybackPlaylistSource
typealias PlaybackCueResultSourceWindowRequest = PlaybackPlaylistSourceWindowRequest
typealias PlaybackCueResultSourceWindowResponse = PlaybackPlaylistSourceWindowResponse
typealias PlaybackCueResultSessionWindowStore = PlaybackPlaylistSessionWindowStore
