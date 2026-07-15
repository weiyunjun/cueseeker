import Combine
import CueSeekerCore
import Foundation

struct PlaybackSearchConfiguration: Equatable, Sendable {
    let databaseURL: URL
    let folders: [URL]
    let languageFilter: SubtitleSearchLanguageFilter
    let watchStateFilter: SubtitleSearchWatchStateFilter
    let filterSet: SubtitleSearchFilterSet
    let pageSize: Int

    init(
        databaseURL: URL,
        folders: [URL],
        languageFilter: SubtitleSearchLanguageFilter,
        watchStateFilter: SubtitleSearchWatchStateFilter,
        filterSet: SubtitleSearchFilterSet,
        pageSize: Int
    ) {
        self.databaseURL = databaseURL
        self.folders = folders
        self.languageFilter = languageFilter
        self.watchStateFilter = watchStateFilter
        self.filterSet = filterSet
        self.pageSize = max(1, pageSize)
    }
}

struct PlaybackSearchPageLoader {
    let visiblePage: @MainActor (
        _ query: String,
        _ configuration: PlaybackSearchConfiguration
    ) async throws -> SubtitleSearchPage
    let exactPage: @MainActor (
        _ query: String,
        _ configuration: PlaybackSearchConfiguration,
        _ progress: @escaping SubtitleSearchProgressSink
    ) async throws -> SubtitleSearchPage
    let windowPage: @MainActor (
        _ query: String,
        _ configuration: PlaybackSearchConfiguration,
        _ range: Range<Int>,
        _ indexedCueIDs: [Int64],
        _ fileSummaries: [SubtitleSearchFileSummary],
        _ totalCount: Int
    ) async throws -> SubtitleSearchPage?

    @MainActor
    static var live: Self {
        Self(
            visiblePage: { query, configuration in
                try await AppCoordinator.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let database = try SubtitleDatabase(
                        path: configuration.databaseURL
                    )
                    return try database.searchVisiblePage(
                        query,
                        limit: configuration.pageSize,
                        cursor: .start,
                        under: configuration.folders,
                        languageFilter: configuration.languageFilter,
                        watchStateFilter: configuration.watchStateFilter,
                        filterSet: configuration.filterSet
                    )
                }
            },
            exactPage: { query, configuration, progress in
                try await AppCoordinator.runCancellableDetached(
                    priority: .utility
                ) {
                    let database = try SubtitleDatabase(
                        path: configuration.databaseURL
                    )
                    return try database.searchPage(
                        query,
                        limit: 0,
                        cursor: .start,
                        under: configuration.folders,
                        languageFilter: configuration.languageFilter,
                        watchStateFilter: configuration.watchStateFilter,
                        filterSet: configuration.filterSet,
                        progress: progress
                    )
                }
            },
            windowPage: {
                query,
                configuration,
                range,
                indexedCueIDs,
                fileSummaries,
                totalCount in
                try await AppCoordinator.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let database = try SubtitleDatabase(
                        path: configuration.databaseURL
                    )
                    if indexedCueIDs.count >= range.upperBound {
                        let windowCueIDs = Array(indexedCueIDs[range])
                        let indexWindow = SubtitleSearchResultIDIndexWindow(
                            cueIDs: windowCueIDs,
                            offset: range.lowerBound,
                            totalCount: totalCount,
                            fileSummaries: fileSummaries,
                            countSnapshot: .exact(
                                totalCount: totalCount,
                                fileSummaryCount: fileSummaries.count
                            ),
                            appliedCursor: SubtitleSearchCursor(
                                offset: range.lowerBound
                            ),
                            nextCursor: range.upperBound < totalCount
                                ? SubtitleSearchCursor(offset: range.upperBound)
                                : nil
                        )
                        return try database.searchIndexedVisiblePage(
                            from: indexWindow
                        )
                    }
                    return try database.searchVisiblePage(
                        query,
                        limit: range.count,
                        cursor: SubtitleSearchCursor(offset: range.lowerBound),
                        under: configuration.folders,
                        languageFilter: configuration.languageFilter,
                        watchStateFilter: configuration.watchStateFilter,
                        filterSet: configuration.filterSet
                    )
                }
            }
        )
    }
}

@MainActor
struct PlaybackSearchPromotion {
    let source: PlaybackCueResultSource
    let query: String
    let scopePaths: [String]
    let selectedOrdinal: Int

    init?(
        source: PlaybackCueResultSource,
        selectedOrdinal: Int
    ) {
        guard case .playbackSearch(_, let context) = source.origin,
              selectedOrdinal >= 0
        else {
            return nil
        }
        self.source = source
        query = context.query
        scopePaths = context.scopePaths
        self.selectedOrdinal = selectedOrdinal
    }
}

@MainActor
final class PlaybackSearchSessionStore: ObservableObject {
    @Published private(set) var query = ""
    @Published private(set) var status: SearchStatus = .idle
    @Published private(set) var window: PlaybackCueResultSessionWindowStore?

    private let configuration: PlaybackSearchConfiguration
    private let pageLoader: PlaybackSearchPageLoader
    private let debounceNanoseconds: UInt64
    private var queryRevision: UInt64 = 0
    private var debounceTask: Task<Void, Never>?
    private var currentRun: PlaybackSearchRun?
    private var isActive = true

    init(
        configuration: PlaybackSearchConfiguration,
        debounceNanoseconds: UInt64 = AppCoordinator.searchInputDebounceNanoseconds,
        pageLoader: PlaybackSearchPageLoader = .live
    ) {
        self.configuration = configuration
        self.debounceNanoseconds = debounceNanoseconds
        self.pageLoader = pageLoader
    }

    var isSessionActive: Bool {
        isActive
    }

    var retainedResultCount: Int {
        currentRun?.retainedResultCount ?? 0
    }

    var retainedCueIDCount: Int {
        currentRun?.retainedCueIDCount ?? 0
    }

    var activeRunID: UUID? {
        currentRun?.id
    }

    var hasActiveExactProgressDelivery: Bool {
        currentRun?.hasActiveExactProgressDelivery ?? false
    }

    func updateQuery(_ newValue: String) {
        guard isActive, query != newValue else {
            return
        }

        query = newValue
        queryRevision &+= 1
        cancelCurrentSearchRun()

        let trimmedQuery = newValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedQuery.isEmpty else {
            status = .idle
            return
        }
        guard !configuration.folders.isEmpty else {
            status = .completed
            return
        }

        status = .searching
        let revision = queryRevision
        debounceTask = Task { @MainActor [weak self] in
            do {
                guard let self else { return }
                try await Task.sleep(nanoseconds: self.debounceNanoseconds)
                try Task.checkCancellation()
                guard self.isActive,
                      self.queryRevision == revision,
                      self.query.trimmingCharacters(
                          in: .whitespacesAndNewlines
                      ) == trimmedQuery
                else {
                    return
                }
                self.debounceTask = nil
                self.startSearchRun(
                    query: trimmedQuery,
                    queryRevision: revision
                )
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      self.isActive,
                      self.queryRevision == revision
                else {
                    return
                }
                self.debounceTask = nil
                self.status = .failed(String(describing: error))
            }
        }
    }

    func promoteForPlayback(
        selectedItem: PlaybackCueResultItem
    ) -> PlaybackSearchPromotion? {
        guard isActive,
              let currentRun,
              let source = currentRun.source,
              source.hasItems,
              let window,
              let selectedOrdinal = window.selectedOrdinal,
              window.item(at: selectedOrdinal) == selectedItem,
              selectedItem.ordinal == selectedOrdinal
        else {
            return nil
        }

        guard let promotion = PlaybackSearchPromotion(
            source: source,
            selectedOrdinal: selectedItem.ordinal
        ) else {
            return nil
        }
        debounceTask?.cancel()
        debounceTask = nil
        currentRun.prepareForPlaybackPromotion()
        window.invalidate()
        self.window = nil
        self.currentRun = nil
        query = ""
        status = .idle
        return promotion
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        queryRevision &+= 1
        cancelCurrentSearchRun()
        query = ""
        status = .idle
    }

    private func startSearchRun(
        query: String,
        queryRevision: UInt64
    ) {
        guard isActive,
              self.queryRevision == queryRevision,
              currentRun == nil,
              window == nil
        else {
            return
        }

        let (run, source) = PlaybackSearchRun.make(
            query: query,
            configuration: configuration,
            pageLoader: pageLoader,
            onStatusChanged: { [weak self] runID, status in
                guard let self,
                      self.isActive,
                      self.currentRun?.id == runID
                else {
                    return
                }
                self.status = status
            },
            onBoundaryPublished: { [weak self] runID in
                guard let self,
                      self.isActive,
                      self.currentRun?.id == runID,
                      let window = self.window
                else {
                    return
                }
                window.resetSelectionToFirst()
                if window.selectedOrdinal != nil {
                    _ = window.requestWindow(containing: 0)
                }
            }
        )
        guard let window = source.makeSessionWindowStore(
            includingEmpty: true
        ) else {
            source.invalidate()
            return
        }
        currentRun = run
        self.window = window
        run.start()
    }

    private func cancelCurrentSearchRun() {
        debounceTask?.cancel()
        debounceTask = nil
        let source = currentRun?.source
        window?.invalidate()
        window = nil
        source?.invalidate()
        currentRun = nil
    }
}

@MainActor
private final class PlaybackSearchRun {
    let id = UUID()
    let query: String

    private let configuration: PlaybackSearchConfiguration
    private let pageLoader: PlaybackSearchPageLoader
    private let onStatusChanged: @MainActor (UUID, SearchStatus) -> Void
    private let onBoundaryPublished: @MainActor (UUID) -> Void
    private(set) weak var source: PlaybackCueResultSource?
    private var visibleTask: Task<Void, Never>?
    private var exactTask: Task<Void, Never>?
    private var exactProgressContinuation:
        AsyncStream<SubtitleSearchProgressSnapshot>.Continuation?
    private var exactProgressDeliveryTask: Task<Void, Never>?
    private var hydratedResultsByOrdinal: [Int: SubtitleSearchResult] = [:]
    private var cueIDs: [Int64] = []
    private var fileSummaries: [SubtitleSearchFileSummary] = []
    private var totalCount = 0
    private var countState: SubtitleSearchCountState = .exact
    private var knownResultCount = 0
    private var knownFileCount = 0
    private var lastProgressUpdateNanoseconds: UInt64 = 0
    private var retainsCompleteHydratedResults = true
    private var isActive = true

    private init(
        query: String,
        configuration: PlaybackSearchConfiguration,
        pageLoader: PlaybackSearchPageLoader,
        onStatusChanged: @escaping @MainActor (UUID, SearchStatus) -> Void,
        onBoundaryPublished: @escaping @MainActor (UUID) -> Void
    ) {
        self.query = query
        self.configuration = configuration
        self.pageLoader = pageLoader
        self.onStatusChanged = onStatusChanged
        self.onBoundaryPublished = onBoundaryPublished
    }

    static func make(
        query: String,
        configuration: PlaybackSearchConfiguration,
        pageLoader: PlaybackSearchPageLoader,
        onStatusChanged: @escaping @MainActor (UUID, SearchStatus) -> Void,
        onBoundaryPublished: @escaping @MainActor (UUID) -> Void
    ) -> (PlaybackSearchRun, PlaybackCueResultSource) {
        let run = PlaybackSearchRun(
            query: query,
            configuration: configuration,
            pageLoader: pageLoader,
            onStatusChanged: onStatusChanged,
            onBoundaryPublished: onBoundaryPublished
        )
        let source = PlaybackCueResultSource(
            origin: .playbackSearch(
                runID: run.id,
                context: PlaybackSearchPlaylistContext(
                    query: query,
                    scopePaths: configuration.folders.map {
                        $0.standardizedFileURL.path
                    }
                )
            ),
            totalCount: 0,
            knownItemIDsByOrdinal: [:],
            invalidationHandler: { [weak run] in
                run?.invalidate()
            }
        ) { [run] request in
            await run.loadWindow(request)
        }
        run.source = source
        return (run, source)
    }

    var retainedResultCount: Int {
        hydratedResultsByOrdinal.count
    }

    var retainedCueIDCount: Int {
        cueIDs.count
    }

    var hasActiveExactProgressDelivery: Bool {
        exactProgressDeliveryTask != nil
    }

    func start() {
        guard isActive, visibleTask == nil else {
            return
        }
        visibleTask = Task { @MainActor [weak self] in
            do {
                guard let self else { return }
                let page = try await self.pageLoader.visiblePage(
                    self.query,
                    self.configuration
                )
                try Task.checkCancellation()
                self.applyVisiblePage(page)
            } catch is CancellationError {
                return
            } catch {
                self?.fail(error)
            }
        }
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        visibleTask?.cancel()
        visibleTask = nil
        exactTask?.cancel()
        exactTask = nil
        stopExactProgressDelivery()
        source = nil
        hydratedResultsByOrdinal.removeAll(keepingCapacity: false)
        cueIDs.removeAll(keepingCapacity: false)
        fileSummaries.removeAll(keepingCapacity: false)
        totalCount = 0
        knownResultCount = 0
        knownFileCount = 0
    }

    func prepareForPlaybackPromotion() {
        guard isActive else {
            return
        }
        retainsCompleteHydratedResults = false
        hydratedResultsByOrdinal = hydratedResultsByOrdinal
            .keys.sorted().prefix(
                PlaybackVirtualReelWindowPolicy.standard.itemCount
            ).reduce(into: [:]) { retained, ordinal in
                retained[ordinal] = hydratedResultsByOrdinal[ordinal]
            }
    }

    func loadWindow(
        _ request: PlaybackCueResultSourceWindowRequest
    ) async -> PlaybackCueResultSourceWindowResponse? {
        guard accepts(request) else {
            return nil
        }

        let localResults = request.ordinalRange.compactMap {
            hydratedResultsByOrdinal[$0]
        }
        if localResults.count == request.ordinalRange.count {
            return PlaybackCueResultSourceWindowResponse(
                request: request,
                items: zip(request.ordinalRange, localResults).map {
                    PlaybackCueResultItem(
                        searchResult: $1,
                        ordinal: $0
                    )
                }
            )
        }

        let indexedCueIDs = cueIDs
        let fileSummaries = fileSummaries
        let range = request.ordinalRange
        do {
            let page = try await pageLoader.windowPage(
                query,
                configuration,
                range,
                indexedCueIDs,
                fileSummaries,
                request.totalCount
            )
            try Task.checkCancellation()
            guard accepts(request),
                  let page,
                  page.results.count == range.count
            else {
                return nil
            }
            replaceHydratedResults(page.results)
            return PlaybackCueResultSourceWindowResponse(
                request: request,
                items: zip(range, page.results).map {
                    PlaybackCueResultItem(
                        searchResult: $1,
                        ordinal: $0
                    )
                }
            )
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    private func applyVisiblePage(_ page: SubtitleSearchPage) {
        guard isActive else {
            return
        }
        visibleTask = nil
        replaceHydratedResults(page.results)
        cueIDs = page.cueIDs
        fileSummaries = page.fileSummaries
        totalCount = page.totalCount
        countState = page.countState
        knownResultCount = page.knownResultCount
        knownFileCount = page.knownFileCount
        publishBoundary()

        if page.countState == .exact {
            onStatusChanged(id, .completed)
        } else {
            onStatusChanged(id, .searching)
            startExactCompletion()
        }
    }

    private func startExactCompletion() {
        guard isActive, exactTask == nil else {
            return
        }

        let (progressStream, progressContinuation) = AsyncStream.makeStream(
            of: SubtitleSearchProgressSnapshot.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        exactProgressContinuation = progressContinuation
        exactProgressDeliveryTask = Task { @MainActor [weak self] in
            for await progress in progressStream {
                guard !Task.isCancelled, let self else {
                    return
                }
                self.applyExactProgress(progress)
            }
        }
        let progressSink: SubtitleSearchProgressSink = { progress in
            progressContinuation.yield(progress)
        }
        exactTask = Task { @MainActor [weak self] in
            do {
                guard let self else { return }
                let page = try await self.pageLoader.exactPage(
                    self.query,
                    self.configuration,
                    progressSink
                )
                try Task.checkCancellation()
                self.applyExactPage(page)
            } catch is CancellationError {
                self?.exactTask = nil
                self?.stopExactProgressDelivery()
                return
            } catch {
                self?.fail(error)
            }
        }
    }

    private func applyExactProgress(
        _ progress: SubtitleSearchProgressSnapshot
    ) {
        guard isActive,
              progress.countState == .exactProgress,
              countState != .exact,
              progress.knownResultCount >= knownResultCount,
              progress.knownFileCount >= knownFileCount
        else {
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        if lastProgressUpdateNanoseconds != 0,
           now - lastProgressUpdateNanoseconds
              < AppCoordinator.searchCountProgressMinimumIntervalNanoseconds {
            return
        }
        lastProgressUpdateNanoseconds = now

        if !progress.results.isEmpty {
            replaceHydratedResults(progress.results)
            cueIDs = progress.cueIDs
        }
        fileSummaries = progress.fileSummaries
        totalCount = progress.knownResultCount
        countState = progress.countState
        knownResultCount = progress.knownResultCount
        knownFileCount = progress.knownFileCount
        publishBoundary()
        onStatusChanged(id, .searching)
    }

    private func applyExactPage(_ page: SubtitleSearchPage) {
        guard isActive else {
            return
        }
        exactTask = nil
        stopExactProgressDelivery()
        replaceHydratedResults(page.renderableResults)
        cueIDs = page.cueIDs
        fileSummaries = page.fileSummaries
        totalCount = page.totalCount
        countState = page.countState
        knownResultCount = page.knownResultCount
        knownFileCount = page.knownFileCount
        publishBoundary()
        onStatusChanged(id, .completed)
    }

    private func replaceHydratedResults(
        _ results: [SubtitleSearchResult]
    ) {
        let retainedResults = retainsCompleteHydratedResults
            ? results[...]
            : results.prefix(
                PlaybackVirtualReelWindowPolicy.standard.itemCount
            )
        hydratedResultsByOrdinal = retainedResults
            .reduce(into: [:]) { indexed, result in
                indexed[max(0, result.searchRank)] = result
            }
    }

    private func publishBoundary() {
        guard isActive, let source else {
            return
        }
        var knownItemIDs: [Int: PlaybackCueResultItemIdentity] = [:]
        for (ordinal, result) in hydratedResultsByOrdinal {
            knownItemIDs[ordinal] = .search(result.entryID)
        }
        guard source.updateBoundary(
            totalCount: totalCount,
            knownItemIDsByOrdinal: knownItemIDs
        ) else {
            return
        }
        onBoundaryPublished(id)
    }

    private func accepts(
        _ request: PlaybackCueResultSourceWindowRequest
    ) -> Bool {
        guard isActive, let source else {
            return false
        }
        let boundary = source.boundary
        return request.datasetID == boundary.datasetID
            && request.generation == boundary.generation
            && request.sourceRevision == boundary.revision
            && request.totalCount == boundary.totalCount
            && request.ordinalRange.lowerBound >= 0
            && request.ordinalRange.upperBound <= boundary.totalCount
    }

    private func fail(_ error: Error) {
        guard isActive else {
            return
        }
        visibleTask = nil
        exactTask = nil
        stopExactProgressDelivery()
        onStatusChanged(id, .failed(String(describing: error)))
    }

    private func stopExactProgressDelivery() {
        exactProgressContinuation?.finish()
        exactProgressContinuation = nil
        exactProgressDeliveryTask?.cancel()
        exactProgressDeliveryTask = nil
    }
}
