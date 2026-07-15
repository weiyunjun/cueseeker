import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackSearchRepeatedQueryAcceptsOnlyLatestRun() async throws {
    let state = PlaybackSearchRepeatedLoaderState()
    let store = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 8),
        debounceNanoseconds: 0,
        pageLoader: PlaybackSearchPageLoader(
            visiblePage: { query, _ in
                let call = await state.nextCall(for: query)
                if query == "foo", call == 1 {
                    do {
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                    } catch {
                        // Return a deliberately late stale page after cancellation.
                    }
                }
                let result: SubtitleSearchResult
                if query == "foo", call == 1 {
                    result = playbackSearchResult(id: 101, rank: 0, text: "stale foo")
                } else if query == "foo" {
                    result = playbackSearchResult(id: 303, rank: 0, text: "latest foo")
                } else {
                    result = playbackSearchResult(id: 202, rank: 0, text: "bar")
                }
                return playbackSearchVisiblePage(
                    results: [result],
                    countState: .exact
                )
            },
            exactPage: { _, _, _ in
                playbackSearchExactPage(results: [])
            },
            windowPage: playbackSearchWindowPage
        )
    )
    defer { store.invalidate() }

    store.updateQuery("foo")
    try await waitForPlaybackSearchCondition {
        await state.callCount(for: "foo") == 1
            && store.activeRunID != nil
    }
    let firstFooRunID = try #require(store.activeRunID)

    store.updateQuery("bar")
    try await waitForPlaybackSearchCondition {
        await state.callCount(for: "bar") == 1
            && store.activeRunID != nil
            && store.activeRunID != firstFooRunID
    }
    let barRunID = try #require(store.activeRunID)

    store.updateQuery("foo")
    try await waitForPlaybackSearchCondition {
        guard await state.callCount(for: "foo") == 2,
              let window = store.window
        else {
            return false
        }
        return window.item(at: 0)?.identity == .search(303)
    }

    #expect(store.activeRunID != firstFooRunID)
    #expect(store.activeRunID != barRunID)
    #expect(store.query == "foo")
    #expect(store.status == .completed)
    #expect(store.window?.snapshot.totalCount == 1)

    store.updateQuery("")

    #expect(store.query.isEmpty)
    #expect(store.status == .idle)
    #expect(store.window == nil)
    #expect(store.activeRunID == nil)
    #expect(store.retainedResultCount == 0)
    #expect(store.retainedCueIDCount == 0)
}

@MainActor
@Test
func playbackSearchUsesDefaultDebounceAndCancelsItWithSession() async throws {
    let state = PlaybackSearchDebounceLoaderState()
    let loader = PlaybackSearchPageLoader(
        visiblePage: { query, _ in
            await state.recordCall(for: query)
            return playbackSearchVisiblePage(
                results: [playbackSearchResult(
                    id: 901,
                    rank: 0,
                    text: query
                )],
                countState: .exact
            )
        },
        exactPage: { _, _, _ in
            playbackSearchExactPage(results: [])
        },
        windowPage: playbackSearchWindowPage
    )

    let firstStore = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 8),
        pageLoader: loader
    )
    let firstSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSearchOpenSnapshot(),
        sessionGeneration: 1,
        searchStore: firstStore
    )
    let inputStartedAt = DispatchTime.now().uptimeNanoseconds
    firstStore.updateQuery("first")
    firstStore.updateQuery("latest")

    try await waitForPlaybackSearchCondition {
        await state.callCount(for: "latest") == 1
            && firstStore.status == .completed
    }
    let latestCallTime = try #require(await state.firstCallTime(for: "latest"))
    #expect(await state.callCount(for: "first") == 0)
    #expect(latestCallTime - inputStartedAt >= 90_000_000)
    _ = firstSession.dismissByUser()

    let cancelledStore = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 8),
        pageLoader: loader
    )
    let cancelledSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSearchOpenSnapshot(),
        sessionGeneration: 2,
        searchStore: cancelledStore
    )
    cancelledStore.updateQuery("cancelled before debounce")
    _ = cancelledSession.dismissByUser()
    try await Task.sleep(nanoseconds: 150_000_000)

    #expect(await state.callCount(for: "cancelled before debounce") == 0)
    #expect(!cancelledStore.isSessionActive)
    #expect(cancelledStore.window == nil)
    #expect(cancelledStore.query.isEmpty)
}

@MainActor
@Test
func playbackSearchExactCompletionKeepsOnlyOneVirtualWindowHydrated() async throws {
    let allResults = (0..<40).map {
        playbackSearchResult(
            id: Int64(1_000 + $0),
            rank: $0,
            text: "bounded result \($0)"
        )
    }
    let store = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 8),
        debounceNanoseconds: 0,
        pageLoader: PlaybackSearchPageLoader(
            visiblePage: { _, _ in
                playbackSearchVisiblePage(
                    results: Array(allResults.prefix(8)),
                    countState: .exactProgress
                )
            },
            exactPage: { _, _, _ in
                playbackSearchExactPage(results: allResults)
            },
            windowPage: { _, _, range, _, _, _ in
                playbackSearchWindowPage(
                    query: "bounded",
                    configuration: playbackSearchTestConfiguration(pageSize: 8),
                    range: range,
                    indexedCueIDs: allResults.map(\.entryID),
                    fileSummaries: [],
                    totalCount: allResults.count,
                    allResults: allResults
                )
            }
        )
    )
    defer { store.invalidate() }

    store.updateQuery("bounded")
    try await waitForPlaybackSearchCondition {
        store.status == .completed
            && store.retainedCueIDCount == allResults.count
            && store.window?.snapshot.loadedItemCount
                == PlaybackVirtualReelWindowPolicy.standard.itemCount
    }
    let window = try #require(store.window)

    #expect(store.retainedResultCount <= PlaybackVirtualReelWindowPolicy.standard.itemCount)
    #expect(store.retainedCueIDCount == 40)
    #expect(window.snapshot.totalCount == 40)
    #expect(window.snapshot.loadedOrdinalRange == (0..<32))
    #expect(window.retainedItemCount == 32)
    #expect(window.selectedOrdinal == 0)
    #expect(!store.hasActiveExactProgressDelivery)

    #expect(window.requestWindow(containing: 39))
    try await waitForPlaybackSearchCondition {
        window.snapshot.loadedOrdinalRange == (8..<40)
            && window.item(at: 39)?.identity == .search(1_039)
    }

    #expect(window.retainedItemCount == 32)
    #expect(store.retainedResultCount <= 32)
}

@MainActor
@Test
func playbackSearchExactProgressDeliveryPreservesLatestValueAndStopsOnFailure() async throws {
    let gate = PlaybackSearchExactGate()
    let allResults = (0..<8).map {
        playbackSearchResult(
            id: Int64(1_500 + $0),
            rank: $0,
            text: "progress result \($0)"
        )
    }
    let store = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 2),
        debounceNanoseconds: 0,
        pageLoader: PlaybackSearchPageLoader(
            visiblePage: { _, _ in
                playbackSearchVisiblePage(
                    results: Array(allResults.prefix(2)),
                    countState: .exactProgress
                )
            },
            exactPage: { _, _, progress in
                try await gate.waitForCompletion(progress: progress)
            },
            windowPage: playbackSearchWindowPage
        )
    )
    defer { store.invalidate() }

    store.updateQuery("progress lifecycle")
    try await waitForPlaybackSearchCondition {
        await gate.hasStarted()
            && store.hasActiveExactProgressDelivery
            && store.window?.snapshot.totalCount == 2
    }

    await gate.emitProgress(
        results: Array(allResults.prefix(4)),
        totalCount: 4
    )
    try await waitForPlaybackSearchCondition {
        store.window?.snapshot.totalCount == 4
    }

    try await Task.sleep(nanoseconds: 220_000_000)
    await gate.emitProgress(
        results: Array(allResults.prefix(6)),
        totalCount: 6
    )
    try await waitForPlaybackSearchCondition {
        store.window?.snapshot.totalCount == 6
    }

    await gate.failWhileRetainingProgressSink()
    try await waitForPlaybackSearchCondition {
        guard case .failed = store.status else {
            return false
        }
        return !store.hasActiveExactProgressDelivery
    }

    try await Task.sleep(nanoseconds: 220_000_000)
    await gate.emitProgress(results: allResults, totalCount: allResults.count)
    try await Task.sleep(nanoseconds: 50_000_000)

    guard case .failed = store.status else {
        Issue.record("A late Exact progress callback must not revive a failed run")
        return
    }
    #expect(store.window?.snapshot.totalCount == 6)
    #expect(!store.hasActiveExactProgressDelivery)
}

@MainActor
@Test
func playbackSearchEnterPromotesRunningExactSourcePastSessionTeardown() async throws {
    let gate = PlaybackSearchExactGate()
    let allResults = (0..<8).map {
        playbackSearchResult(
            id: Int64(2_000 + $0),
            rank: $0,
            text: "promoted result \($0)"
        )
    }
    let searchStore = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 2),
        debounceNanoseconds: 0,
        pageLoader: PlaybackSearchPageLoader(
            visiblePage: { _, _ in
                playbackSearchVisiblePage(
                    results: Array(allResults.prefix(2)),
                    countState: .exactProgress
                )
            },
            exactPage: { _, _, progress in
                try await gate.waitForCompletion(progress: progress)
            },
            windowPage: { _, _, range, _, _, _ in
                playbackSearchWindowPage(
                    query: "promote",
                    configuration: playbackSearchTestConfiguration(pageSize: 2),
                    range: range,
                    indexedCueIDs: allResults.map(\.entryID),
                    fileSummaries: [],
                    totalCount: allResults.count,
                    allResults: allResults
                )
            }
        )
    )
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSearchOpenSnapshot(),
        sessionGeneration: 1,
        searchStore: searchStore
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    searchStore.updateQuery("promote")

    try await waitForPlaybackSearchCondition {
        await gate.hasStarted()
            && searchStore.window?.snapshot.loadedItemCount == 2
    }
    #expect(session.selectModule(.search))
    let firstWindow = try #require(searchStore.window)
    let reelDatasetID = try #require(firstWindow.reelDatasetID)
    #expect(firstWindow.commitSelection(
        PlaybackVirtualReelSelectionCommit(
            datasetID: AnyHashable(reelDatasetID),
            generation: firstWindow.snapshot.generation,
            ordinal: 1
        )
    ))

    await gate.emitProgress(
        results: Array(allResults.prefix(5)),
        totalCount: 5
    )
    try await waitForPlaybackSearchCondition {
        searchStore.window?.snapshot.totalCount == 5
            && searchStore.window?.snapshot.loadedItemCount == 5
    }
    #expect(searchStore.window?.selectedOrdinal == 0)

    let selectedItem = try #require(searchStore.window?.item(at: 0))
    let actionRequest = session.requestSettledSearchPlayAction()
    guard case .ready(let execution) = actionRequest else {
        Issue.record("Settled Playback Search Enter should create a play action")
        return
    }
    #expect(execution.target == .search(selectedItem))
    let promotion = try #require(session.promoteSearchForPlayback(
        selectedItem: selectedItem
    ))
    let promotedSource = promotion.source
    let promotedDatasetID = promotedSource.boundary.datasetID

    #expect(session.dismissByUser() == false)
    #expect(!searchStore.isSessionActive)
    #expect(searchStore.query.isEmpty)
    #expect(searchStore.window == nil)
    #expect(firstWindow.selectedOrdinal == nil)
    #expect(firstWindow.retainedItemCount == 0)
    #expect(!(await gate.wasCancelled()))

    try await Task.sleep(nanoseconds: 220_000_000)
    await gate.emitProgress(results: allResults, totalCount: allResults.count)
    try await waitForPlaybackSearchCondition {
        promotedSource.boundary.totalCount == allResults.count
    }

    #expect(promotedSource.boundary.datasetID == promotedDatasetID)
    guard case .playbackSearch = promotedSource.origin else {
        Issue.record("Promoted source should retain its Playback Search origin")
        return
    }
    let promotedWindow = try #require(promotedSource.makeSessionWindowStore())
    #expect(promotedWindow.requestWindow(containing: 7))
    try await waitForPlaybackSearchCondition {
        promotedWindow.item(at: 7)?.identity == .search(2_007)
    }

    promotedWindow.invalidate()
    promotedSource.invalidate()
    try await waitForPlaybackSearchCondition {
        await gate.wasCancelled()
    }
}

@MainActor
@Test
func playbackSearchDismissalCancelsUnpromotedExactRunAndClearsSessionData() async throws {
    let gate = PlaybackSearchExactGate()
    let results = (0..<2).map {
        playbackSearchResult(
            id: Int64(3_000 + $0),
            rank: $0,
            text: "dismiss result \($0)"
        )
    }
    let searchStore = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 2),
        debounceNanoseconds: 0,
        pageLoader: PlaybackSearchPageLoader(
            visiblePage: { _, _ in
                playbackSearchVisiblePage(
                    results: results,
                    countState: .exactProgress
                )
            },
            exactPage: { _, _, progress in
                try await gate.waitForCompletion(progress: progress)
            },
            windowPage: playbackSearchWindowPage
        )
    )
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSearchOpenSnapshot(),
        sessionGeneration: 1,
        searchStore: searchStore
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    searchStore.updateQuery("dismiss")

    try await waitForPlaybackSearchCondition {
        await gate.hasStarted()
            && searchStore.window?.snapshot.loadedItemCount == 2
    }
    #expect(searchStore.hasActiveExactProgressDelivery)
    let staleWindow = try #require(searchStore.window)
    #expect(session.selectModule(.search))

    #expect(session.dismissByUser() == false)
    try await waitForPlaybackSearchCondition {
        await gate.wasCancelled()
    }

    #expect(!searchStore.isSessionActive)
    #expect(searchStore.query.isEmpty)
    #expect(searchStore.status == .idle)
    #expect(searchStore.window == nil)
    #expect(searchStore.activeRunID == nil)
    #expect(searchStore.retainedResultCount == 0)
    #expect(searchStore.retainedCueIDCount == 0)
    #expect(!searchStore.hasActiveExactProgressDelivery)
    #expect(session.searchStore == nil)
    #expect(session.selectedModule == nil)
    #expect(staleWindow.selectedOrdinal == nil)
    #expect(staleWindow.retainedItemCount == 0)
}

@MainActor
@Test
func playbackSearchPromotionUsesSessionQueryScopeWithoutReplacingWorkbenchResults() async throws {
    let suiteName = "PlaybackSearchPromotionContext-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSearchPromotionContext-\(UUID().uuidString)")
    let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: defaults, databaseURL: databaseURL)
    let database = try #require(app.subtitleDatabase)
    let workbenchResult = playbackSearchResult(
        id: 4_001,
        rank: 0,
        text: "workbench sentinel"
    )
    let playbackResult = playbackSearchResult(
        id: 4_002,
        rank: 7,
        text: "playback search selection"
    )
    app.search.searchQuery = "workbench query"
    app.search.searchResults = [workbenchResult]
    app.search.searchResultTotalCount = 1
    app.indexing.selectedFolders = [URL(fileURLWithPath: "/Workbench Scope")]

    let source = PlaybackCueResultSource(
        origin: .playbackSearch(
            runID: UUID(),
            context: PlaybackSearchPlaylistContext(
                query: "playback overlay query",
                scopePaths: ["/Playback Scope"]
            )
        ),
        totalCount: 8,
        knownItemIDsByOrdinal: [7: .search(playbackResult.entryID)]
    ) { _ in nil }
    let promotion = try #require(PlaybackSearchPromotion(
        source: source,
        selectedOrdinal: 7
    ))

    app.openSearchResult(
        playbackResult,
        playbackSearchPromotion: promotion
    )
    await Task.yield()

    #expect(app.playback.playlistSource === source)
    #expect(app.search.searchQuery == "workbench query")
    #expect(app.search.searchResults == [workbenchResult])
    #expect(app.search.searchNavigationSnapshot == nil)
    let entry = try #require(try database.playbackNavigationEntries().last)
    guard case .search(let payload) = entry.payload else {
        Issue.record("Playback Search promotion should record Search history")
        return
    }
    #expect(payload.query == "playback overlay query")
    #expect(payload.scopePaths == ["/Playback Scope"])
    #expect(payload.entryID == playbackResult.entryID)

    app.playback.clearPlaylistSource()
}

@MainActor
@Test
func playbackSearchKeyboardRoutingKeepsTextInputPrimaryAndRequiresSettledResult() async throws {
    let suiteName = "PlaybackSearchKeyboardRouting-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSearchKeyboardRouting-\(UUID().uuidString)")
    let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: defaults, databaseURL: databaseURL)
    let results = (0..<2).map {
        playbackSearchResult(
            id: Int64(5_000 + $0),
            rank: $0,
            text: "keyboard result \($0)"
        )
    }
    app.search.selectedSearchResult = results[0]
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused

    let searchStore = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 2),
        debounceNanoseconds: 0,
        pageLoader: PlaybackSearchPageLoader(
            visiblePage: { _, _ in
                playbackSearchVisiblePage(results: results, countState: .exact)
            },
            exactPage: { _, _, _ in
                playbackSearchExactPage(results: results)
            },
            windowPage: playbackSearchWindowPage
        )
    )
    let session = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: playbackSearchOpenSnapshot(),
        searchStore: searchStore
    ))
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    #expect(session.selectModule(.search))
    searchStore.updateQuery("keyboard")
    try await waitForPlaybackSearchCondition {
        searchStore.window?.snapshot.loadedItemCount == 2
    }

    defer { app.playback.releaseSubtitleFocusSession(session) }
    let editableInput = PlaybackKeyboardTextInputState(
        isEditableFocused: true,
        hasMarkedText: false
    )

    #expect(!app.handlePlaybackKeyDown(
        keyCode: 1,
        modifierFlagsRawValue: 0,
        textInputState: editableInput
    ))
    #expect(!app.handlePlaybackKeyDown(
        keyCode: 8,
        modifierFlagsRawValue: 0,
        textInputState: editableInput
    ))
    #expect(!app.handlePlaybackKeyDown(
        keyCode: 49,
        modifierFlagsRawValue: 0,
        textInputState: editableInput
    ))
    #expect(!app.handlePlaybackKeyDown(
        keyCode: 0,
        modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
        textInputState: editableInput
    ))
    #expect(!app.handlePlaybackKeyDown(
        keyCode: 8,
        modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
        textInputState: editableInput
    ))

    #expect(app.handlePlaybackKeyDown(
        keyCode: 48,
        modifierFlagsRawValue: 0,
        textInputState: editableInput
    ))
    #expect(session.selectedModule == .recent)
    #expect(session.selectModule(.search))

    #expect(app.handlePlaybackKeyDown(
        keyCode: 125,
        modifierFlagsRawValue: 0,
        textInputState: editableInput
    ))
    #expect(session.keyboardNavigationRequest?.targetOrdinal == 1)

    #expect(session.selectModule(.recent))
    #expect(session.selectModule(.search))
    session.noteCueReelMotion(true, module: .search)
    #expect(app.handlePlaybackKeyDown(
        keyCode: 36,
        modifierFlagsRawValue: 0,
        textInputState: editableInput
    ))
    #expect(session.pendingKeyboardAction == nil)
    #expect(session.activeKeyboardAction == nil)
    #expect(app.playback.subtitleFocusSession === session)
    session.noteCueReelMotion(false, module: .search)

    guard case .ready(let execution) = session.requestSettledSearchPlayAction() else {
        Issue.record("Settled Search result should accept Enter")
        return
    }
    #expect(execution.action == .playFromThisCue)
    #expect(execution.target == .search(try #require(searchStore.window?.item(at: 0))))
    #expect(session.finishKeyboardAction(execution))

    let markedInput = PlaybackKeyboardTextInputState(
        isEditableFocused: true,
        hasMarkedText: true
    )
    #expect(!app.handlePlaybackKeyDown(
        keyCode: 125,
        modifierFlagsRawValue: 0,
        textInputState: markedInput
    ))
    #expect(!app.handlePlaybackKeyDown(
        keyCode: 36,
        modifierFlagsRawValue: 0,
        textInputState: markedInput
    ))
    #expect(session.keyboardNavigationRequest == nil)
    #expect(session.activeKeyboardAction == nil)
}

@MainActor
@Test
func playbackSearchEnterPreservesItsPlaylistAcrossAdjacentAndPlaylistPlayback() async throws {
    let suiteName = "PlaybackSearchEnterIntegration-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSearchEnterIntegration-\(UUID().uuidString)")
    let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: defaults, databaseURL: databaseURL)
    defer { app.stopPlayback() }

    let workbenchResult = playbackSearchResult(
        id: 6_000,
        rank: 0,
        text: "workbench result"
    )
    let playbackResults = (0..<4).map {
        playbackSearchResult(
            id: Int64(6_100 + $0),
            rank: 40 + $0,
            text: "playback integration \($0)"
        )
    }
    app.search.searchQuery = "workbench query"
    app.search.searchResults = [workbenchResult]
    app.search.searchResultTotalCount = 1
    app.search.selectedSearchResult = workbenchResult
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused

    let gate = PlaybackSearchExactGate()
    let searchStore = PlaybackSearchSessionStore(
        configuration: playbackSearchTestConfiguration(pageSize: 1),
        debounceNanoseconds: 0,
        pageLoader: PlaybackSearchPageLoader(
            visiblePage: { _, _ in
                playbackSearchVisiblePage(
                    results: [playbackResults[0]],
                    countState: .exactProgress
                )
            },
            exactPage: { _, _, progress in
                try await gate.waitForCompletion(progress: progress)
            },
            windowPage: { _, _, range, _, _, _ in
                playbackSearchWindowPage(
                    query: "playback integration",
                    configuration: playbackSearchTestConfiguration(pageSize: 1),
                    range: range,
                    indexedCueIDs: playbackResults.map(\.entryID),
                    fileSummaries: [],
                    totalCount: playbackResults.count,
                    allResults: playbackResults
                )
            }
        )
    )
    let searchSession = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: playbackSearchOpenSnapshot(),
        searchStore: searchStore
    ))
    #expect(publishPlaybackOverlayInitialTestSnapshot(searchSession))
    #expect(searchSession.selectModule(.search))
    searchStore.updateQuery("playback integration")
    try await waitForPlaybackSearchCondition("initial Search window") {
        await gate.hasStarted()
            && searchStore.window?.item(at: 0)?.identity == .search(6_100)
    }

    let editableInput = PlaybackKeyboardTextInputState(
        isEditableFocused: true,
        hasMarkedText: false
    )
    #expect(app.handlePlaybackKeyDown(
        keyCode: 36,
        modifierFlagsRawValue: 0,
        textInputState: editableInput
    ))
    let promotedSource = try #require(app.playback.playlistSource)

    #expect(app.playback.subtitleFocusSession == nil)
    #expect(!searchStore.isSessionActive)
    #expect(app.search.selectedSearchResult?.entryID == 6_100)
    #expect(app.search.searchQuery == "workbench query")
    #expect(app.search.searchResults == [workbenchResult])
    #expect(promotedSource.boundary.totalCount == 1)
    guard case .playbackSearch(_, let promotedContext) = promotedSource.origin else {
        Issue.record("Search Enter should install its Playback Search source")
        return
    }
    #expect(promotedContext.query == "playback integration")
    #expect(promotedContext.scopePaths == ["/Media"])
    #expect(!(await gate.wasCancelled()))
    #expect(!app.playback.chromeSnapshot.canGoNext)

    await gate.emitProgress(
        results: playbackResults,
        totalCount: playbackResults.count
    )
    try await waitForPlaybackSearchCondition("promoted Exact source boundary") {
        promotedSource.boundary.totalCount == playbackResults.count
    }
    try await waitForPlaybackSearchCondition("promoted Exact Chrome navigation") {
        app.playback.chromeSnapshot.canGoNext
    }

    app.goNext()
    try await waitForPlaybackSearchCondition("Playback source next item") {
        app.search.selectedSearchResult?.entryID == 6_101
    }
    #expect(app.playback.playlistSource === promotedSource)
    #expect(app.search.searchQuery == "workbench query")
    #expect(app.search.searchResults == [workbenchResult])

    let playlistSession = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: playbackSearchOpenSnapshot()
    ))
    #expect(publishPlaybackOverlayInitialTestSnapshot(playlistSession))
    #expect(playlistSession.selectModule(.playlist))
    let playlistWindow = try #require(playlistSession.playlistWindow)
    #expect(playlistWindow.requestWindow(containing: 2))
    try await waitForPlaybackSearchCondition("Playlist source window") {
        playlistWindow.item(at: 2)?.identity == .search(6_102)
    }
    let reelDatasetID = try #require(playlistWindow.reelDatasetID)
    #expect(playlistWindow.commitSelection(
        PlaybackVirtualReelSelectionCommit(
            datasetID: AnyHashable(reelDatasetID),
            generation: playlistWindow.snapshot.generation,
            ordinal: 2
        )
    ))
    #expect(app.handlePlaybackKeyDown(
        keyCode: 36,
        modifierFlagsRawValue: 0,
        textInputState: PlaybackKeyboardTextInputState(
            isEditableFocused: false,
            hasMarkedText: false
        )
    ))
    try await waitForPlaybackSearchCondition("Playlist Enter playback") {
        app.search.selectedSearchResult?.entryID == 6_102
            && app.playback.subtitleFocusSession == nil
    }

    #expect(app.playback.playlistSource === promotedSource)
    #expect(promotedSource.boundary.totalCount == playbackResults.count)
    #expect(app.search.searchQuery == "workbench query")
    #expect(app.search.searchResults == [workbenchResult])
    #expect(!(await gate.wasCancelled()))

    app.stopPlayback()
    try await waitForPlaybackSearchCondition("promoted source cancellation") {
        await gate.wasCancelled()
    }
}

@MainActor
@Test
func playbackSearchAdjacentNavigationRetriesNewBoundaryAndRejectsLateReplacementResponse() async throws {
    let suiteName = "PlaybackSearchNavigationRace-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSearchNavigationRace-\(UUID().uuidString)")
    let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
    defer {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: defaults, databaseURL: databaseURL)
    defer { app.stopPlayback() }

    let results = (0..<4).map {
        playbackSearchResult(
            id: Int64(7_100 + $0),
            rank: 100 + $0,
            text: "navigation race \($0)"
        )
    }
    let gate = PlaybackSearchNavigationLoaderGate(
        results: results,
        blockedCallNumbers: [1, 3]
    )
    let source = PlaybackCueResultSource(
        origin: .playbackSearch(
            runID: UUID(),
            context: PlaybackSearchPlaylistContext(
                query: "promoted query",
                scopePaths: ["/Promoted Scope"]
            )
        ),
        totalCount: 3,
        knownItemIDsByOrdinal: Dictionary(
            uniqueKeysWithValues: results.prefix(3).enumerated().map {
                ($0.offset, PlaybackCueResultItemIdentity.search($0.element.entryID))
            }
        )
    ) { request in
        await gate.load(request)
    }
    app.search.searchQuery = "workbench query"
    app.search.searchResults = [playbackSearchResult(
        id: 7_000,
        rank: 0,
        text: "workbench sentinel"
    )]
    app.search.searchResultTotalCount = 1
    app.search.selectedSearchResult = results[0]
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused
    app.activePlaybackSource = .search
    app.playback.setPlaylistSource(
        source,
        playbackSearchSelectedOrdinal: 0
    )
    app.refreshPlaybackChromeSnapshot(displayTitle: "Navigation Race")

    app.goNext()
    try await waitForPlaybackSearchCondition("first stale navigation request") {
        gate.requestCount == 1
    }
    #expect(source.updateBoundary(
        totalCount: results.count,
        knownItemIDsByOrdinal: Dictionary(
            uniqueKeysWithValues: results.enumerated().map {
                ($0.offset, PlaybackCueResultItemIdentity.search($0.element.entryID))
            }
        )
    ))
    gate.release(callNumber: 1)

    try await waitForPlaybackSearchCondition("retried navigation request") {
        gate.requestCount == 2
            && app.search.selectedSearchResult?.entryID == 7_101
    }
    #expect(gate.requests[0].generation != gate.requests[1].generation)
    #expect(app.playback.playlistSource === source)
    #expect(app.playback.playbackSearchPlaylistOrdinal == 1)
    #expect(app.search.searchQuery == "workbench query")
    #expect(app.search.searchResults.first?.entryID == 7_000)

    app.goNext()
    try await waitForPlaybackSearchCondition("late navigation request") {
        gate.requestCount == 3
    }
    let replacementSource = PlaybackCueResultSource(
        kind: .search,
        totalCount: 0,
        knownItemIDsByOrdinal: [:]
    ) { _ in nil }
    app.playback.setPlaylistSource(replacementSource)
    gate.release(callNumber: 3)
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(app.playback.playlistSource === replacementSource)
    #expect(app.playback.playbackSearchPlaylistOrdinal == nil)
    #expect(app.search.selectedSearchResult?.entryID == 7_101)
    #expect(app.activePlaybackSource == .search)
    #expect(gate.requestCount == 3)
}

private actor PlaybackSearchRepeatedLoaderState {
    private var calls: [String: Int] = [:]

    func nextCall(for query: String) -> Int {
        calls[query, default: 0] += 1
        return calls[query, default: 0]
    }

    func callCount(for query: String) -> Int {
        calls[query, default: 0]
    }
}

private actor PlaybackSearchDebounceLoaderState {
    private var calls: [String: Int] = [:]
    private var firstCallTimes: [String: UInt64] = [:]

    func recordCall(for query: String) {
        calls[query, default: 0] += 1
        if firstCallTimes[query] == nil {
            firstCallTimes[query] = DispatchTime.now().uptimeNanoseconds
        }
    }

    func callCount(for query: String) -> Int {
        calls[query, default: 0]
    }

    func firstCallTime(for query: String) -> UInt64? {
        firstCallTimes[query]
    }
}

@MainActor
private final class PlaybackSearchNavigationLoaderGate {
    let results: [SubtitleSearchResult]
    let blockedCallNumbers: Set<Int>
    private(set) var requests: [PlaybackCueResultSourceWindowRequest] = []
    private var continuations: [
        Int: CheckedContinuation<PlaybackCueResultSourceWindowResponse?, Never>
    ] = [:]

    init(
        results: [SubtitleSearchResult],
        blockedCallNumbers: Set<Int>
    ) {
        self.results = results
        self.blockedCallNumbers = blockedCallNumbers
    }

    var requestCount: Int {
        requests.count
    }

    func load(
        _ request: PlaybackCueResultSourceWindowRequest
    ) async -> PlaybackCueResultSourceWindowResponse? {
        requests.append(request)
        let callNumber = requests.count
        guard blockedCallNumbers.contains(callNumber) else {
            return response(for: request)
        }
        return await withCheckedContinuation { continuation in
            continuations[callNumber] = continuation
        }
    }

    func release(callNumber: Int) {
        guard requests.indices.contains(callNumber - 1),
              let continuation = continuations.removeValue(forKey: callNumber)
        else {
            return
        }
        continuation.resume(returning: response(
            for: requests[callNumber - 1]
        ))
    }

    private func response(
        for request: PlaybackCueResultSourceWindowRequest
    ) -> PlaybackCueResultSourceWindowResponse? {
        guard request.ordinalRange.upperBound <= results.count else {
            return nil
        }
        return PlaybackCueResultSourceWindowResponse(
            request: request,
            items: request.ordinalRange.map {
                PlaybackCueResultItem(
                    searchResult: results[$0],
                    ordinal: $0
                )
            }
        )
    }
}

private actor PlaybackSearchExactGate {
    private var continuation: CheckedContinuation<SubtitleSearchPage, any Error>?
    private var progressSink: SubtitleSearchProgressSink?
    private var started = false
    private var cancelled = false

    func waitForCompletion(
        progress: @escaping SubtitleSearchProgressSink
    ) async throws -> SubtitleSearchPage {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if cancelled || Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                progressSink = progress
                started = true
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func emitProgress(
        results: [SubtitleSearchResult],
        totalCount: Int
    ) {
        progressSink?(SubtitleSearchProgressSnapshot(
            countSnapshot: .exactProgress(
                knownResultCount: totalCount,
                knownFileCount: results.isEmpty ? 0 : 1
            ),
            fileSummaries: [],
            results: results,
            cueIDs: results.map(\.entryID)
        ))
    }

    func hasStarted() -> Bool {
        started
    }

    func wasCancelled() -> Bool {
        cancelled
    }

    func failWhileRetainingProgressSink() {
        let pending = continuation
        continuation = nil
        pending?.resume(throwing: PlaybackSearchExactGateError.forcedFailure)
    }

    private func cancel() {
        guard !cancelled else { return }
        cancelled = true
        progressSink = nil
        let pending = continuation
        continuation = nil
        pending?.resume(throwing: CancellationError())
    }
}

private enum PlaybackSearchExactGateError: Error {
    case forcedFailure
}

private func playbackSearchTestConfiguration(
    pageSize: Int
) -> PlaybackSearchConfiguration {
    PlaybackSearchConfiguration(
        databaseURL: URL(fileURLWithPath: "/tmp/playback-search-tests.sqlite"),
        folders: [URL(fileURLWithPath: "/Media")],
        languageFilter: .all,
        watchStateFilter: .all,
        filterSet: SubtitleSearchFilterSet(),
        pageSize: pageSize
    )
}

private func playbackSearchOpenSnapshot() -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/Media/Current.mkv",
            subtitlePath: "/Media/Current.srt",
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 1_000,
        wasPlaying: false
    )
}

private func playbackSearchResult(
    id: Int64,
    rank: Int,
    text: String
) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        cueGroupID: id + 10_000,
        cueEventIndex: Int(id),
        cueDisplayOrder: 0,
        primaryGroupIndex: 0,
        subtitlePath: "/Media/Playback-Search.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Playback-Search.mkv",
        videoName: "Playback-Search.mkv",
        startMilliseconds: rank * 1_000,
        endMilliseconds: rank * 1_000 + 900,
        content: text,
        cueLines: [text],
        cueGroupLines: [text],
        searchRank: rank
    )
}

private func playbackSearchVisiblePage(
    results: [SubtitleSearchResult],
    countState: SubtitleSearchCountState
) -> SubtitleSearchPage {
    let snapshot: SubtitleSearchCountSnapshot = countState == .exact
        ? .exact(totalCount: results.count, fileSummaryCount: results.isEmpty ? 0 : 1)
        : .exactProgress(
            knownResultCount: results.count,
            knownFileCount: results.isEmpty ? 0 : 1
        )
    return SubtitleSearchPage(
        results: results,
        totalCount: results.count,
        fileSummaries: [],
        countSnapshot: snapshot,
        appliedCursor: .start,
        nextCursor: countState == .exact
            ? nil
            : SubtitleSearchCursor(offset: results.count),
        pageMode: .visibleWindow
    )
}

private func playbackSearchExactPage(
    results: [SubtitleSearchResult]
) -> SubtitleSearchPage {
    SubtitleSearchPage(
        results: [],
        renderableResults: results,
        cueIDs: results.map(\.entryID),
        totalCount: results.count,
        fileSummaries: [],
        countSnapshot: .exact(
            totalCount: results.count,
            fileSummaryCount: results.isEmpty ? 0 : 1
        )
    )
}

@MainActor
private func playbackSearchWindowPage(
    _ query: String,
    _ configuration: PlaybackSearchConfiguration,
    _ range: Range<Int>,
    _ indexedCueIDs: [Int64],
    _ fileSummaries: [SubtitleSearchFileSummary],
    _ totalCount: Int
) async throws -> SubtitleSearchPage? {
    let results = indexedCueIDs.enumerated().map {
        playbackSearchResult(
            id: $0.element,
            rank: $0.offset,
            text: "\(query) result \($0.offset)"
        )
    }
    return playbackSearchWindowPage(
        query: query,
        configuration: configuration,
        range: range,
        indexedCueIDs: indexedCueIDs,
        fileSummaries: fileSummaries,
        totalCount: totalCount,
        allResults: results
    )
}

private func playbackSearchWindowPage(
    query _: String,
    configuration _: PlaybackSearchConfiguration,
    range: Range<Int>,
    indexedCueIDs _: [Int64],
    fileSummaries: [SubtitleSearchFileSummary],
    totalCount: Int,
    allResults: [SubtitleSearchResult]
) -> SubtitleSearchPage? {
    guard range.upperBound <= allResults.count else {
        return nil
    }
    return SubtitleSearchPage(
        results: Array(allResults[range]),
        totalCount: totalCount,
        fileSummaries: fileSummaries,
        countSnapshot: .exact(
            totalCount: totalCount,
            fileSummaryCount: fileSummaries.count
        ),
        appliedCursor: SubtitleSearchCursor(offset: range.lowerBound),
        nextCursor: range.upperBound < totalCount
            ? SubtitleSearchCursor(offset: range.upperBound)
            : nil,
        pageMode: .visibleWindow
    )
}

@MainActor
private func waitForPlaybackSearchCondition(
    _ description: String = "condition",
    timeout: TimeInterval = 10,
    condition: @MainActor () async -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !(await condition()) {
        guard Date() < deadline else {
            throw PlaybackSearchOverlayTestError.timedOut(description)
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

private enum PlaybackSearchOverlayTestError: Error {
    case timedOut(String)
}
