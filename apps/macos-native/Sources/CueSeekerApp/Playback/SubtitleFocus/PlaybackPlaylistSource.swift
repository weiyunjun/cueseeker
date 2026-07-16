import Combine
import CueSeekerCore
import Foundation

enum PlaybackPlaylistSourceKind: Hashable, Sendable {
    case search
    case shiori
}

struct PlaybackPlaylistShioriTableContext: Hashable, Sendable {
    let runID: UUID
    let searchText: String
    let filterSet: SubtitleSearchFilterSet
    let totalCount: Int

    init(
        runID: UUID = UUID(),
        searchText: String,
        filterSet: SubtitleSearchFilterSet,
        totalCount: Int
    ) {
        self.runID = runID
        self.searchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        self.filterSet = filterSet
        self.totalCount = max(0, totalCount)
    }
}

enum PlaybackPlaylistShioriScope: Hashable, Sendable {
    case explicitIDs([Int64])
    case databaseOrder
    case table(PlaybackPlaylistShioriTableContext)
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
    case shiori(scope: PlaybackPlaylistShioriScope)
    case unspecified(PlaybackPlaylistSourceKind)

    var kind: PlaybackPlaylistSourceKind {
        switch self {
        case .search:
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

typealias PlaybackPlaylistSharedItemProvider = @MainActor (
    _ ordinal: Int
) -> PlaybackPlaylistItem?

enum PlaybackCueResultCompleteLoadPolicy {
    static let batchSize = 256
    static let yieldInterval = 8

    static func batchRanges(in range: Range<Int>) -> [Range<Int>] {
        guard !range.isEmpty else {
            return []
        }

        var ranges: [Range<Int>] = []
        let batchCount = range.count / batchSize
            + (range.count.isMultiple(of: batchSize) ? 0 : 1)
        ranges.reserveCapacity(batchCount)
        var lowerBound = range.lowerBound
        while lowerBound < range.upperBound {
            let (candidateUpperBound, didOverflow) = lowerBound
                .addingReportingOverflow(batchSize)
            let upperBound = didOverflow
                ? range.upperBound
                : min(candidateUpperBound, range.upperBound)
            ranges.append(lowerBound..<upperBound)
            lowerBound = upperBound
        }
        return ranges
    }
}

private final class PlaybackCueResultLoadAccumulator {
    var items: [PlaybackPlaylistItem] = []

    init(capacity: Int) {
        items.reserveCapacity(capacity)
    }

    func clear() {
        items.removeAll(keepingCapacity: false)
    }
}

@MainActor
final class PlaybackPlaylistSource: ObservableObject {
    let origin: PlaybackPlaylistSourceOrigin

    var kind: PlaybackPlaylistSourceKind {
        origin.kind
    }

    @Published private(set) var boundary: PlaybackPlaylistSourceBoundary

    private var loader: PlaybackPlaylistSourceWindowLoader?
    private var sharedItemProvider: PlaybackPlaylistSharedItemProvider?
    private var invalidationHandler: (@MainActor () -> Void)?
    private var stableItemIdentities: [PlaybackPlaylistItemIdentity]?
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
            stableItemIdentities: nil,
            invalidationHandler: nil,
            loader: loader
        )
    }

    init(
        origin: PlaybackPlaylistSourceOrigin,
        totalCount: Int,
        knownItemIDsByOrdinal: [Int: PlaybackPlaylistItemIdentity],
        stableItemIdentities: [PlaybackPlaylistItemIdentity]? = nil,
        invalidationHandler: (@MainActor () -> Void)? = nil,
        loader: @escaping PlaybackPlaylistSourceWindowLoader
    ) {
        self.origin = origin
        self.loader = loader
        self.invalidationHandler = invalidationHandler
        let resolvedTotalCount = max(0, totalCount)
        let resolvedKnownItemIDs = Self.normalizedKnownItemIDs(
            knownItemIDsByOrdinal,
            totalCount: resolvedTotalCount
        )
        boundary = PlaybackPlaylistSourceBoundary(
            datasetID: UUID(),
            generation: 1,
            revision: 0,
            totalCount: resolvedTotalCount,
            knownItemIDsByOrdinal: resolvedKnownItemIDs
        )
        if let stableItemIdentities,
           stableItemIdentities.count == resolvedTotalCount,
           resolvedKnownItemIDs.allSatisfy({ entry in
               stableItemIdentities[entry.key] == entry.value
           }) {
            self.stableItemIdentities = stableItemIdentities
        }
    }

    init(
        origin: PlaybackPlaylistSourceOrigin,
        totalCount: Int,
        sharedItemProvider: @escaping PlaybackPlaylistSharedItemProvider
    ) {
        self.origin = origin
        loader = nil
        self.sharedItemProvider = sharedItemProvider
        invalidationHandler = nil
        stableItemIdentities = nil
        boundary = PlaybackPlaylistSourceBoundary(
            datasetID: UUID(),
            generation: 1,
            revision: 0,
            totalCount: max(0, totalCount),
            knownItemIDsByOrdinal: [:]
        )
    }

    var hasItems: Bool {
        isActive && boundary.totalCount > 0
    }

    var usesSharedItemProvider: Bool {
        isActive && sharedItemProvider != nil
    }

    func sharedItem(at ordinal: Int) -> PlaybackPlaylistItem? {
        guard isActive,
              boundary.totalCount > ordinal,
              ordinal >= 0
        else {
            return nil
        }
        return sharedItemProvider?(ordinal)
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
        if changesIdentityBoundary {
            stableItemIdentities = nil
        }
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

    var hasStableIdentityIndex: Bool {
        stableItemIdentities?.count == boundary.totalCount
    }

    func itemIdentity(at ordinal: Int) -> PlaybackPlaylistItemIdentity? {
        if let sharedItem = sharedItem(at: ordinal) {
            return sharedItem.identity
        }
        if let stableItemIdentities,
           stableItemIdentities.indices.contains(ordinal) {
            return stableItemIdentities[ordinal]
        }
        return boundary.knownItemIDsByOrdinal[ordinal]
    }

    func ordinal(
        of identity: PlaybackPlaylistItemIdentity
    ) -> Int? {
        if let stableItemIdentities {
            return stableItemIdentities.firstIndex(of: identity)
        }
        return boundary.knownItemIDsByOrdinal.first(where: {
            $0.value == identity
        })?.key
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
        let response: PlaybackPlaylistSourceWindowResponse?
        if let sharedItemProvider {
            let items = request.ordinalRange.compactMap(sharedItemProvider)
            guard items.count == request.ordinalRange.count else {
                return nil
            }
            response = PlaybackPlaylistSourceWindowResponse(
                request: request,
                items: items
            )
        } else if let loader {
            response = await loader(request)
        } else {
            response = nil
        }
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
            if let knownID = itemIdentity(at: item.ordinal),
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
        stableItemIdentities = nil
        loader = nil
        sharedItemProvider = nil
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
                <= PlaybackCueResultCompleteLoadPolicy.batchSize
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
    private(set) var selectedItemIdentity: PlaybackPlaylistItemIdentity?
    private var source: PlaybackPlaylistSource?
    private var boundaryCancellable: AnyCancellable?
    private var loadTask: Task<Void, Never>?
    private var loadAccumulator: PlaybackCueResultLoadAccumulator?
    private var pendingRequest: PlaybackPlaylistSourceWindowRequest?
    private var revision: UInt64 = 0
    private var isActive = true

    init(source: PlaybackPlaylistSource) {
        self.source = source
        let boundary = source.boundary
        selectedOrdinal = boundary.totalCount > 0 ? 0 : nil
        selectedItemIdentity = source.itemIdentity(at: 0)
        snapshot = source.usesSharedItemProvider
            ? Self.sharedSnapshot(boundary: boundary, revision: 0)
            : Self.emptySnapshot(boundary: boundary, revision: 0)
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
        source?.itemIdentity(at: ordinal)
    }

    func item(at ordinal: Int) -> PlaybackPlaylistItem? {
        if let sharedItem = source?.sharedItem(at: ordinal) {
            return sharedItem
        }
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
        if source.usesSharedItemProvider {
            return item(at: target) != nil
        }
        if snapshot.isComplete,
           snapshot.loadedOrdinalRange.contains(target),
           item(at: target) != nil {
            return true
        }
        let ordinalRange = 0..<boundary.totalCount
        let request = PlaybackPlaylistSourceWindowRequest(
            datasetID: boundary.datasetID,
            generation: boundary.generation,
            sourceRevision: boundary.revision,
            totalCount: boundary.totalCount,
            ordinalRange: ordinalRange
        )
        if pendingRequest == request, loadTask != nil {
            return true
        }
        loadTask?.cancel()
        loadAccumulator?.clear()
        loadAccumulator = nil
        pendingRequest = request
        loadTask = Task { @MainActor [weak self, weak source] in
            guard let self, let source else {
                return
            }
            defer {
                if self.pendingRequest == request {
                    self.loadTask = nil
                    self.loadAccumulator?.clear()
                    self.loadAccumulator = nil
                    self.pendingRequest = nil
                }
            }
            guard let response = await self.loadCompleteDataset(
                from: source,
                request: request
            ) else {
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
              response.ordinalRange == 0..<response.totalCount,
              response.items.count == response.totalCount,
              response.items.enumerated().allSatisfy({ offset, item in
                  item.ordinal == response.ordinalRange.lowerBound + offset
              }),
              Set(response.items.map(\.identity)).count == response.items.count
        else {
            return false
        }

        loadTask = nil
        loadAccumulator = nil
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
        if let selectedOrdinal,
           let selectedItem = item(at: selectedOrdinal) {
            selectedItemIdentity = selectedItem.identity
        } else if selectedOrdinal == nil {
            selectedItemIdentity = nil
        }
        return true
    }

    private func loadCompleteDataset(
        from source: PlaybackPlaylistSource,
        request: PlaybackPlaylistSourceWindowRequest
    ) async -> PlaybackPlaylistSourceWindowResponse? {
        let accumulator = PlaybackCueResultLoadAccumulator(
            capacity: request.ordinalRange.count
        )
        loadAccumulator = accumulator
        let batchRanges = PlaybackCueResultCompleteLoadPolicy.batchRanges(
            in: request.ordinalRange
        )
        for (index, batchRange) in batchRanges.enumerated() {
            guard isActive,
                  !Task.isCancelled,
                  pendingRequest == request
            else {
                return nil
            }
            let batchRequest = PlaybackPlaylistSourceWindowRequest(
                datasetID: request.datasetID,
                generation: request.generation,
                sourceRevision: request.sourceRevision,
                totalCount: request.totalCount,
                ordinalRange: batchRange
            )
            guard let response = await source.loadWindow(batchRequest) else {
                return nil
            }
            accumulator.items.append(contentsOf: response.items)
            if index == 0, batchRanges.count > 1 {
                guard publishInitialBatch(
                    response,
                    completeRequest: request
                ) else {
                    return nil
                }
            }
            if (index + 1).isMultiple(
                of: PlaybackCueResultCompleteLoadPolicy.yieldInterval
            ), index + 1 < batchRanges.count {
                await Task.yield()
            }
        }
        guard !Task.isCancelled,
              pendingRequest == request,
              accumulator.items.count == request.ordinalRange.count
        else {
            return nil
        }
        return PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: accumulator.items
        )
    }

    private func publishInitialBatch(
        _ response: PlaybackPlaylistSourceWindowResponse,
        completeRequest: PlaybackPlaylistSourceWindowRequest
    ) -> Bool {
        guard isActive,
              let source,
              pendingRequest == completeRequest,
              response.datasetID == completeRequest.datasetID,
              response.generation == completeRequest.generation,
              response.sourceRevision == completeRequest.sourceRevision,
              response.totalCount == completeRequest.totalCount,
              response.ordinalRange.lowerBound
                == completeRequest.ordinalRange.lowerBound,
              response.ordinalRange.count
                <= PlaybackCueResultCompleteLoadPolicy.batchSize,
              response.items.count == response.ordinalRange.count,
              source.boundary.datasetID == response.datasetID,
              source.boundary.generation == response.generation,
              source.boundary.revision == response.sourceRevision,
              source.boundary.totalCount == response.totalCount
        else {
            return false
        }

        items = response.items
        revision &+= 1
        snapshot = PlaybackVirtualReelSnapshot(
            datasetID: AnyHashable(response.datasetID),
            generation: response.generation,
            revision: revision,
            totalCount: response.totalCount,
            loadedOrdinalRange: response.ordinalRange,
            loadedItemCount: response.items.count,
            isComplete: false
        )
        if let selectedOrdinal,
           let selectedItem = item(at: selectedOrdinal) {
            selectedItemIdentity = selectedItem.identity
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
        loadAccumulator?.clear()
        loadAccumulator = nil
        pendingRequest = nil
        boundaryCancellable?.cancel()
        boundaryCancellable = nil
        source = nil
        items.removeAll(keepingCapacity: false)
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
        loadTask?.cancel()
        loadTask = nil
        loadAccumulator?.clear()
        loadAccumulator = nil
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
            selectedItemIdentity = self.selectedOrdinal.flatMap {
                source?.itemIdentity(at: $0)
            }
        } else if selectedOrdinal == nil, boundary.totalCount > 0 {
            selectedOrdinal = 0
            selectedItemIdentity = source?.itemIdentity(at: 0)
        } else if boundary.totalCount == 0 {
            selectedItemIdentity = nil
        }
        snapshot = source?.usesSharedItemProvider == true
            ? Self.sharedSnapshot(boundary: boundary, revision: revision)
            : Self.emptySnapshot(boundary: boundary, revision: revision)
    }

    private static func sharedSnapshot(
        boundary: PlaybackPlaylistSourceBoundary,
        revision: UInt64
    ) -> PlaybackVirtualReelSnapshot {
        PlaybackVirtualReelSnapshot(
            datasetID: AnyHashable(boundary.datasetID),
            generation: boundary.generation,
            revision: revision,
            totalCount: boundary.totalCount,
            loadedOrdinalRange: 0..<boundary.totalCount,
            loadedItemCount: boundary.totalCount,
            isComplete: true
        )
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

// Playlist was the first playback module to consume this result transport.
// The neutral names let Playlist, Search, and Shiori retain their complete
// session dataset while sharing one viewport-virtualized Reel.
typealias PlaybackCueResultItemIdentity = PlaybackPlaylistItemIdentity
typealias PlaybackCueResultItem = PlaybackPlaylistItem
typealias PlaybackCueResultSource = PlaybackPlaylistSource
typealias PlaybackCueResultSourceWindowRequest = PlaybackPlaylistSourceWindowRequest
typealias PlaybackCueResultSourceWindowResponse = PlaybackPlaylistSourceWindowResponse
typealias PlaybackCueResultSessionWindowStore = PlaybackPlaylistSessionWindowStore
