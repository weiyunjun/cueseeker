import AppKit
import CueSeekerCore
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackPlaylistSearchItemMapsPrimaryCueAndRemovesOnlyPrimaryGroupIndex() throws {
    let searchResult = makePlaybackPlaylistSearchResult(
        id: 42,
        content: "same",
        primaryGroupIndex: 1,
        cueGroupLines: ["same", "same", "tail"]
    )

    let item = PlaybackPlaylistItem(searchResult: searchResult, ordinal: 7)
    let actionContext = try #require(item.actionContext)
    let cueResult = item.cueResult(sequenceNumber: 8)

    #expect(item.identity == .search(42))
    #expect(item.primaryCueIdentity == .cue(42))
    #expect(item.ordinal == 7)
    #expect(item.primaryCueText == "same")
    #expect(item.additionalCueTexts == ["same", "tail"])
    #expect(item.target == .search(searchResult))
    #expect(actionContext.source.videoPath == "/video/42.mkv")
    #expect(actionContext.source.subtitlePath == "/subtitle/42.ass")
    #expect(actionContext.source.subtitleFormat == .ass)
    #expect(actionContext.cue.id == 42)
    #expect(actionContext.cue.cueGroupID == 142)
    #expect(actionContext.cue.ordinal == 7)
    #expect(actionContext.cue.eventIndex == 242)
    #expect(actionContext.cue.displayOrder == 1)
    #expect(cueResult.itemID == AnyHashable(PlaybackPlaylistItemIdentity.search(42)))
    #expect(cueResult.primaryCueIdentity == AnyHashable(PlaybackPlaylistPrimaryCueIdentity.cue(42)))
    #expect(cueResult.sequenceNumber == 8)
}

@MainActor
@Test
func playbackPlaylistShioriItemMapsPrimaryCueAndRemovesOnlyPrimaryGroupIndex() throws {
    let shiori = makePlaybackPlaylistShiori(
        id: 9,
        content: "same",
        cueEventIndex: 19,
        cueDisplayOrder: 2
    )
    let presentation = ShioriCuePresentation(
        cueID: 209,
        cueGroupID: 309,
        primaryGroupIndex: 1,
        cueGroupTexts: ["same", "same", "tail"],
        languages: [.unknown],
        speakers: []
    )

    let item = PlaybackPlaylistItem(
        shiori: shiori,
        cuePresentation: presentation,
        ordinal: 4
    )
    let actionContext = try #require(item.actionContext)

    #expect(item.identity == .shiori(9))
    #expect(item.primaryCueIdentity == .cue(209))
    #expect(item.ordinal == 4)
    #expect(item.primaryCueText == "same")
    #expect(item.additionalCueTexts == ["same", "tail"])
    #expect(item.target == .shiori(shiori))
    #expect(actionContext.source.videoPath == "/video/shiori-9.mkv")
    #expect(actionContext.source.subtitlePath == "/subtitle/shiori-9.ass")
    #expect(actionContext.cue.id == 209)
    #expect(actionContext.cue.cueGroupID == 309)
    #expect(actionContext.cue.ordinal == 4)
    #expect(actionContext.cue.eventIndex == 19)
    #expect(actionContext.cue.displayOrder == 2)
}

@MainActor
@Test
func playbackPlaylistTotalCountDoesNotDependOnKnownItemIDCoverage() async throws {
    let totalCount = 73
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: totalCount,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            72: .search(1_072),
        ]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let boundary = source.boundary
    let request = makePlaybackPlaylistWindowRequest(
        boundary: boundary,
        ordinalRange: 32..<64
    )

    let response = try #require(await source.loadWindow(request))

    #expect(boundary.totalCount == totalCount)
    #expect(boundary.knownItemIDsByOrdinal.count == 2)
    #expect(response.totalCount == totalCount)
    #expect(response.ordinalRange == (32..<64))
    #expect(response.items.count == 32)
}

@MainActor
@Test
func playbackPlaylistBoundaryGrowthAdvancesGenerationAndStableRefreshAdvancesRevision() {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ) { _ in nil }
    let initial = source.boundary
    let grownIDs: [Int: PlaybackPlaylistItemIdentity] = [
        0: .search(1_000),
        1: .search(1_001),
        2: .search(1_002),
    ]

    #expect(source.updateBoundary(totalCount: 3, knownItemIDsByOrdinal: grownIDs))
    let grown = source.boundary

    #expect(grown.datasetID == initial.datasetID)
    #expect(grown.generation == initial.generation + 1)
    #expect(grown.revision == 0)
    #expect(grown.totalCount == 3)

    #expect(source.updateBoundary(totalCount: 3, knownItemIDsByOrdinal: grownIDs))
    let refreshed = source.boundary

    #expect(refreshed.datasetID == initial.datasetID)
    #expect(refreshed.generation == grown.generation)
    #expect(refreshed.revision == grown.revision + 1)
    #expect(refreshed.totalCount == grown.totalCount)
    #expect(refreshed.knownItemIDsByOrdinal == grown.knownItemIDsByOrdinal)
}

@MainActor
@Test
func searchPlaybackPlaylistFollowsExactProgressInsteadOfFreezingClickedRows() async throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-playlist-search-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    app.searchResultListGeneration = 7
    let initialResults = (0..<2).map { ordinal in
        makePlaybackPlaylistSearchResult(
            id: Int64(100 + ordinal),
            searchRank: ordinal
        )
    }
    app.search.searchResults = initialResults
    app.search.searchResultTotalCount = initialResults.count
    app.installSearchPlaybackPlaylistSource(seed: initialResults[1])
    let source = try #require(app.playback.playlistSource)
    let initialBoundary = source.boundary
    let window = try #require(source.makeSessionWindowStore())
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 2
    })

    let exactProgressResults = (0..<5).map { ordinal in
        makePlaybackPlaylistSearchResult(
            id: Int64(100 + ordinal),
            searchRank: ordinal
        )
    }
    app.search.searchResults = exactProgressResults
    app.search.searchResultTotalCount = exactProgressResults.count
    app.refreshSearchPlaybackPlaylistSource(resultListGeneration: 7)

    #expect(app.playback.playlistSource === source)
    #expect(source.boundary.datasetID == initialBoundary.datasetID)
    #expect(source.boundary.generation == initialBoundary.generation + 1)
    #expect(source.boundary.totalCount == 5)
    #expect(source.boundary.knownItemIDsByOrdinal[4] == .search(104))
    #expect(window.snapshot.generation == source.boundary.generation)
    #expect(window.snapshot.totalCount == 5)
    #expect(window.retainedItemCount == 0)
    #expect(window.requestWindow(containing: 4))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 5
    })
    #expect(window.item(at: 4)?.identity == .search(104))
    window.invalidate()
    app.playback.clearPlaylistSource()
}

@MainActor
@Test
func shioriPlaybackPlaylistUsesExistingNavigationScopeOrderAndCount() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-playlist-shiori-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    app.shioriPlaybackNavigationScopeIDs = [9, 3, 7]

    app.installShioriPlaybackPlaylistSource()

    let source = try #require(app.playback.playlistSource)
    #expect(source.origin == .shiori(scope: .explicitIDs([9, 3, 7])))
    #expect(source.boundary.totalCount == 3)
    #expect(source.boundary.knownItemIDsByOrdinal == [
        0: .shiori(9),
        1: .shiori(3),
        2: .shiori(7),
    ])
    app.playback.clearPlaylistSource()
}

@MainActor
@Test
func shioriPlaybackPlaylistTableScopeKeepsCompleteFilteredRowsBeyondLoadedPrefix() async throws {
    _ = NSApplication.shared
    let suiteName = "PlaybackPlaylistShioriTable-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "playback-playlist-shiori-table-\(UUID().uuidString)"
        )
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    await app.startupDatabaseTask?.value
    let database = try #require(app.subtitleDatabase)
    var matchingShioris: [Shiori] = []
    for ordinal in 0..<80 {
        let content: String
        if ordinal.isMultiple(of: 2) {
            content = "needle keep \(ordinal)"
        } else if ordinal.isMultiple(of: 3) {
            content = "needle drop \(ordinal)"
        } else {
            content = "other keep \(ordinal)"
        }
        let shiori = try database.upsertShiori(
            subtitleFile: URL(fileURLWithPath: "/Media/TableScope-\(ordinal).srt"),
            subtitleFormat: .srt,
            videoFile: URL(fileURLWithPath: "/Media/TableScope-\(ordinal).mkv"),
            videoName: "TableScope-\(ordinal).mkv",
            selection: SubtitleCueTextSelection(
                cueGroupID: Int64(ordinal + 1),
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 500,
                lines: [content]
            ),
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_000 + ordinal))
        )
        if ordinal.isMultiple(of: 2) {
            matchingShioris.append(shiori)
        }
    }

    let expectedIDs = matchingShioris.reversed().map(\.id)
    let filterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .cues,
            operatorID: .contains,
            value: "keep"
        )
    ])
    let initialTablePage = try #require(
        await app.loadTableSandboxShioriRows(
            range: 0..<3,
            searchText: "  needle  ",
            filterSet: filterSet
        )
    )
    #expect(initialTablePage.rows.count == 3)
    #expect(initialTablePage.resultShioriIDs == expectedIDs)
    #expect(initialTablePage.totalRowCount == expectedIDs.count)
    let cancelledTableLoad = Task { @MainActor in
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return await app.loadTableSandboxShioriRows(
            range: 0..<3,
            searchText: "needle",
            filterSet: filterSet
        )
    }
    #expect(await cancelledTableLoad.value == nil)
    let context = PlaybackPlaylistShioriTableContext(
        searchText: "  needle  ",
        filterSet: filterSet,
        totalCount: initialTablePage.totalRowCount
    )
    let scope = PlaybackPlaylistShioriScope.table(context)
    let loadedRichPrefixIDs = initialTablePage.rows.map { Int64($0.shiori.id) }
    app.shioriPlaybackNavigationScopeIDs = initialTablePage.resultShioriIDs

    app.installShioriPlaybackPlaylistSource(scope: scope)

    let source = try #require(app.playback.playlistSource)
    let window = try #require(source.makeSessionWindowStore())
    #expect(context.searchText == "needle")
    #expect(source.origin == .shiori(scope: scope))
    #expect(source.boundary.totalCount == 40)
    #expect(source.hasStableIdentityIndex)
    #expect(source.boundary.totalCount > loadedRichPrefixIDs.count)
    #expect(window.requestWindow(containing: 35))
    #expect(await waitForPlaybackPlaylistCondition(attempts: 1_000) {
        window.snapshot.loadedItemCount == 32
    })

    #expect(window.snapshot.loadedOrdinalRange == (8..<40))
    #expect(window.retainedItemCount == PlaybackVirtualReelWindowPolicy.standard.itemCount)
    #expect(window.items.map(\.identity) == Array(expectedIDs[8..<40]).map {
        PlaybackPlaylistItemIdentity.shiori($0)
    })
    #expect(window.item(at: 35)?.identity == .shiori(expectedIDs[35]))

    _ = try database.upsertShiori(
        subtitleFile: URL(fileURLWithPath: "/Media/TableScope-New.srt"),
        subtitleFormat: .srt,
        videoFile: URL(fileURLWithPath: "/Media/TableScope-New.mkv"),
        videoName: "TableScope-New.mkv",
        selection: SubtitleCueTextSelection(
            cueGroupID: 10_000,
            startMilliseconds: 90_000,
            endMilliseconds: 90_500,
            lines: ["needle keep new"]
        ),
        createdAt: Date(timeIntervalSince1970: 9_000)
    )
    #expect(
        try database.shioriTableIDIndex(
            searchText: context.searchText,
            filterSet: filterSet
        ).totalCount == 41
    )
    let stableTablePage = try #require(
        await app.loadTableSandboxShioriRows(
            range: 35..<40,
            searchText: context.searchText,
            filterSet: filterSet,
            resultShioriIDs: initialTablePage.resultShioriIDs
        )
    )
    #expect(stableTablePage.totalRowCount == 40)
    #expect(stableTablePage.rows.map { $0.shiori.id } == Array(expectedIDs[35..<40]))
    #expect(source.boundary.totalCount == 40)
    #expect(source.itemIdentity(at: 0) == .shiori(expectedIDs[0]))
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition(attempts: 1_000) {
        window.snapshot.loadedOrdinalRange == (0..<32)
    })
    #expect(window.items.map(\.identity) == Array(expectedIDs[0..<32]).map {
        PlaybackPlaylistItemIdentity.shiori($0)
    })

    let outsideLoadedPrefix = try #require(
        matchingShioris.first { $0.id == expectedIDs[35] }
    )
    app.openShiori(
        outsideLoadedPrefix,
        navigationScopeIDs: expectedIDs,
        playlistScope: scope
    )
    #expect(app.playback.playlistSource === source)
    #expect(app.canOpenPreviousShiori)
    #expect(app.canOpenNextShiori)
    app.openPreviousShiori()
    #expect(app.shiori.selectedShiori?.id == expectedIDs[34])
    #expect(app.shiori.selectedShiori?.id != expectedIDs[0])

    app.installShioriPlaybackPlaylistSource(scope: scope)
    #expect(app.playback.playlistSource === source)

    _ = try database.removeShiori(id: expectedIDs[10])
    let stableBoundary = source.boundary
    let missingIndexedItemResponse = await source.loadWindow(
        PlaybackPlaylistSourceWindowRequest(
            datasetID: stableBoundary.datasetID,
            generation: stableBoundary.generation,
            sourceRevision: stableBoundary.revision,
            totalCount: stableBoundary.totalCount,
            ordinalRange: 0..<32
        )
    )
    #expect(missingIndexedItemResponse == nil)

    let replacementScope = PlaybackPlaylistShioriScope.table(
        PlaybackPlaylistShioriTableContext(
            searchText: context.searchText,
            filterSet: filterSet,
            totalCount: expectedIDs.count
        )
    )
    app.shioriPlaybackNavigationScopeIDs = expectedIDs
    app.installShioriPlaybackPlaylistSource(scope: replacementScope)
    #expect(app.playback.playlistSource !== source)
    #expect(source.boundary.totalCount == 0)
    #expect(!source.hasStableIdentityIndex)
    let replacementSource = try #require(app.playback.playlistSource)

    window.invalidate()
    app.playback.clearPlaylistSource()
    #expect(app.shioriPlaybackNavigationScopeIDs == nil)
    #expect(!replacementSource.hasStableIdentityIndex)
}

@MainActor
@Test
func playbackPlaylistSessionUsesStandardThirtyTwoItemWindowAndInternalSequence() async throws {
    let totalCount = 50_000
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: totalCount,
        knownItemIDsByOrdinal: [:]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = try #require(source.makeSessionWindowStore())

    #expect(session.requestWindow(containing: 25_000))
    let didLoad = await waitForPlaybackPlaylistCondition {
        session.snapshot.loadedItemCount == 32
    }
    let item = try #require(session.item(at: 25_000))
    let cueResult = item.cueResult(sequenceNumber: item.ordinal + 1)

    #expect(didLoad)
    #expect(session.snapshot.totalCount == totalCount)
    #expect(session.snapshot.loadedOrdinalRange == (24_984..<25_016))
    #expect(session.snapshot.loadedItemCount == PlaybackVirtualReelWindowPolicy.standard.itemCount)
    #expect(session.retainedItemCount == PlaybackVirtualReelWindowPolicy.standard.itemCount)
    #expect(item.identity == .search(26_000))
    #expect(cueResult.sequenceNumber == 25_001)
}

@MainActor
@Test
func playbackPlaylistSessionUsesSharedReelSelectionAndSettledActionTarget() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 40,
        knownItemIDsByOrdinal: [:]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let playback = PlaybackStore(userDefaults: .standard)
    playback.setPlaylistSource(source)
    let session = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 1_000,
            wasPlaying: false
        )
    ))
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    let window = try #require(session.playlistWindow)

    #expect(session.availableModules == PlaybackOverlayModule.allCases)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 32
    })
    #expect(session.selectModule(.playlist))
    #expect(session.requestKeyboardNavigation(.forward))
    let request = try #require(session.keyboardNavigationRequest)

    #expect(request.targetOrdinal == 1)
    #expect(request.contentDatasetID == source.boundary.datasetID.uuidString)
    #expect(request.contentGeneration == source.boundary.generation)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)

    session.noteCueReelMotion(true)
    #expect(session.commitVirtualReelSelection(
        PlaybackVirtualReelSelectionCommit(
            datasetID: AnyHashable(source.boundary.datasetID.uuidString),
            generation: source.boundary.generation,
            ordinal: 1
        )
    ))
    session.noteCueReelMotion(false)
    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady()
    )
    let selectedItem = try #require(window.item(at: 1))

    #expect(window.selectedOrdinal == 1)
    #expect(session.keyboardNavigationRequest == nil)
    #expect(execution.target == .playlist(selectedItem))
    #expect(execution.target.primaryCueText == selectedItem.primaryCueText)
    #expect(session.finishKeyboardAction(execution))

    playback.releaseSubtitleFocusSession(session)
    playback.clearPlaylistSource()
}

@MainActor
@Test
func playbackPlaylistViewLoadsSharedWindowAndModuleSwitchPreservesSessionState() async throws {
    _ = NSApplication.shared
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    let currentCue = SubtitleFocusCue(
        id: 1,
        cueGroupID: 11,
        ordinal: 0,
        eventIndex: 0,
        displayOrder: 0,
        startMilliseconds: 0,
        endMilliseconds: 500,
        content: "current"
    )
    #expect(session.publishInitialSnapshot(
        SubtitleFocusSnapshot(
            totalCount: 1,
            selectedOrdinal: 0,
            cues: [currentCue]
        ),
        token: session.token
    ))
    #expect(session.selectModule(.playlist))
    let window = try #require(session.playlistWindow)
    let suiteName = "PlaybackPlaylistView-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let cueGroupPresentation = CueGroupPresentationStore(
        isEnabled: true,
        userDefaults: defaults,
        userDefaultsKey: "showCueGroup",
        uiProbeScope: suiteName
    )
    let hostingView = NSHostingView(
        rootView: PlaybackSubtitleFocusLayer(session: session)
            .environmentObject(cueGroupPresentation)
            .frame(width: 1_280, height: 720)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 1_280, height: 720)
    hostingView.layoutSubtreeIfNeeded()
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 2
    })
    #expect(window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable(source.boundary.datasetID.uuidString),
        generation: source.boundary.generation,
        ordinal: 1
    )))

    #expect(session.selectModule(.current))
    try await Task.sleep(nanoseconds: 20_000_000)
    hostingView.layoutSubtreeIfNeeded()
    #expect(window.retainedItemCount == 2)
    #expect(window.selectedOrdinal == 1)

    #expect(session.selectModule(.playlist))
    try await Task.sleep(nanoseconds: 20_000_000)
    hostingView.layoutSubtreeIfNeeded()
    #expect(window.retainedItemCount == 2)
    #expect(window.selectedOrdinal == 1)

    _ = session.dismissByUser()
    #expect(window.retainedItemCount == 0)
    source.invalidate()
    withExtendedLifetime(hostingView) {}
}

@MainActor
@Test
func playbackPlaylistSelectionRejectsStaleOrUnloadedSharedReelCommits() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 40,
        knownItemIDsByOrdinal: [:]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let window = try #require(source.makeSessionWindowStore())
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 32
    })
    let datasetID = AnyHashable(source.boundary.datasetID.uuidString)
    let generation = source.boundary.generation

    #expect(!window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: "wrong-dataset",
        generation: generation,
        ordinal: 1
    )))
    #expect(!window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: datasetID,
        generation: generation + 1,
        ordinal: 1
    )))
    #expect(!window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: datasetID,
        generation: generation,
        ordinal: 39
    )))
    #expect(window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: datasetID,
        generation: generation,
        ordinal: 1
    )))
    #expect(window.selectedOrdinal == 1)
    window.invalidate()
}

@MainActor
@Test
func playbackPlaylistUnloadedKeyboardTargetSettlesBeforeDeferredAction() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 40,
        knownItemIDsByOrdinal: [:]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    let window = try #require(session.playlistWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedOrdinalRange == (0..<32)
    })
    #expect(window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable(source.boundary.datasetID.uuidString),
        generation: source.boundary.generation,
        ordinal: 31
    )))
    #expect(session.selectModule(.playlist))
    #expect(session.requestKeyboardNavigation(.forward))
    #expect(session.keyboardNavigationRequest?.targetOrdinal == 32)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)

    #expect(window.requestWindow(containing: 32))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedOrdinalRange.contains(32)
    })
    #expect(session.commitVirtualReelSelection(
        PlaybackVirtualReelSelectionCommit(
            datasetID: AnyHashable(source.boundary.datasetID.uuidString),
            generation: source.boundary.generation,
            ordinal: 32
        )
    ))
    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady()
    )
    let selectedItem = try #require(window.item(at: 32))

    #expect(window.selectedOrdinal == 32)
    #expect(session.keyboardNavigationRequest == nil)
    #expect(execution.target == .playlist(selectedItem))
    _ = session.finishKeyboardAction(execution)
    _ = session.dismissByUser()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistGenerationChangeRebindsIntentAndPreservesDeferredAction() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    let window = try #require(session.playlistWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 2
    })
    #expect(session.selectModule(.playlist))
    #expect(session.requestKeyboardNavigation(.forward))
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)

    #expect(source.updateBoundary(
        totalCount: 3,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
            2: .search(1_002),
        ]
    ))

    let reboundRequest = try #require(session.keyboardNavigationRequest)
    #expect(reboundRequest.targetOrdinal == 1)
    #expect(reboundRequest.contentGeneration == source.boundary.generation)
    #expect(reboundRequest.contentDatasetID == source.boundary.datasetID.uuidString)
    #expect(session.pendingKeyboardAction == .copyCueText)
    #expect(window.snapshot.generation == source.boundary.generation)
    #expect(window.retainedItemCount == 0)
    #expect(window.requestWindow(containing: 1))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 3
    })
    #expect(session.commitVirtualReelSelection(
        PlaybackVirtualReelSelectionCommit(
            datasetID: AnyHashable(source.boundary.datasetID.uuidString),
            generation: source.boundary.generation,
            ordinal: 1
        )
    ))
    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady()
    )
    let selectedItem = try #require(window.item(at: 1))
    #expect(execution.target == .playlist(selectedItem))
    _ = session.finishKeyboardAction(execution)
    _ = session.dismissByUser()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistRevisionRefreshRebindsIntentAndPreservesDeferredAction() async throws {
    let knownIDs: [Int: PlaybackPlaylistItemIdentity] = [
        0: .search(1_000),
        1: .search(1_001),
    ]
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: knownIDs
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    let window = try #require(session.playlistWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 2
    })
    #expect(session.selectModule(.playlist))
    #expect(session.requestKeyboardNavigation(.forward))
    let initialRequest = try #require(session.keyboardNavigationRequest)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)

    #expect(source.updateBoundary(
        totalCount: 2,
        knownItemIDsByOrdinal: knownIDs
    ))

    let reboundRequest = try #require(session.keyboardNavigationRequest)
    #expect(reboundRequest.sequence > initialRequest.sequence)
    #expect(reboundRequest.targetOrdinal == 1)
    #expect(reboundRequest.contentGeneration == source.boundary.generation)
    #expect(session.pendingKeyboardAction == .copyCueText)
    #expect(window.retainedItemCount == 0)
    #expect(window.requestWindow(containing: 1))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 2
    })
    #expect(session.commitVirtualReelSelection(
        PlaybackVirtualReelSelectionCommit(
            datasetID: AnyHashable(source.boundary.datasetID.uuidString),
            generation: source.boundary.generation,
            ordinal: 1
        )
    ))
    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady()
    )
    let selectedItem = try #require(window.item(at: 1))
    #expect(execution.target == .playlist(selectedItem))
    _ = session.finishKeyboardAction(execution)
    _ = session.dismissByUser()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistRevisionRefreshKeepsRemoteNativeActionDeferredUntilSettle() async throws {
    let knownIDs: [Int: PlaybackPlaylistItemIdentity] = [
        0: .search(1_000),
        1: .search(1_001),
    ]
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: knownIDs
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    let window = try #require(session.playlistWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 2
    })
    #expect(session.selectModule(.playlist))
    session.noteCueReelMotion(true)

    #expect(source.updateBoundary(
        totalCount: 2,
        knownItemIDsByOrdinal: knownIDs
    ))

    #expect(window.retainedItemCount == 0)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)
    #expect(window.requestWindow(containing: 1))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 2
    })
    #expect(session.commitVirtualReelSelection(
        PlaybackVirtualReelSelectionCommit(
            datasetID: AnyHashable(source.boundary.datasetID.uuidString),
            generation: source.boundary.generation,
            ordinal: 1
        )
    ))
    session.noteCueReelMotion(false)
    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady()
    )
    let selectedItem = try #require(window.item(at: 1))
    #expect(execution.target == .playlist(selectedItem))
    _ = session.finishKeyboardAction(execution)
    _ = session.dismissByUser()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistBoundaryRefreshSettlesDeferredNativeMotionActionAfterReload() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    let window = try #require(session.playlistWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 2
    })
    #expect(session.selectModule(.playlist))
    session.noteCueReelMotion(true)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)

    #expect(source.updateBoundary(
        totalCount: 3,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
            2: .search(1_002),
        ]
    ))

    #expect(session.pendingKeyboardAction == .copyCueText)
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 3
    })
    session.noteCueReelMotion(false)
    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady()
    )
    let selectedItem = try #require(window.item(at: 0))
    #expect(execution.target == .playlist(selectedItem))
    _ = session.finishKeyboardAction(execution)
    _ = session.dismissByUser()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistEmptyBoundaryCancelsDeferredNativeMotionAction() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 1,
        knownItemIDsByOrdinal: [0: .search(1_000)]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    let window = try #require(session.playlistWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedItemCount == 1
    })
    #expect(session.selectModule(.playlist))
    session.noteCueReelMotion(true)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)

    #expect(source.updateBoundary(totalCount: 0, knownItemIDsByOrdinal: [:]))

    #expect(session.pendingKeyboardAction == nil)
    #expect(session.keyboardNavigationRequest == nil)
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
    #expect(session.requestKeyboardAction(.copyCueText) == .rejected)
    #expect(session.pendingKeyboardAction == nil)
    _ = session.dismissByUser()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistRemoteScrollbarTargetAcceptsActionBeforeWindowSettles() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 100,
        knownItemIDsByOrdinal: [:]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    let window = try #require(session.playlistWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedOrdinalRange == (0..<32)
    })
    #expect(session.selectModule(.playlist))
    session.noteScrollbarDragging(true)
    #expect(window.requestWindow(containing: 80))
    #expect(await waitForPlaybackPlaylistCondition {
        window.snapshot.loadedOrdinalRange.contains(80)
    })
    #expect(window.item(at: 0) == nil)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)
    #expect(session.commitVirtualReelSelection(
        PlaybackVirtualReelSelectionCommit(
            datasetID: AnyHashable(source.boundary.datasetID.uuidString),
            generation: source.boundary.generation,
            ordinal: 80
        )
    ))
    session.noteScrollbarDragging(false)

    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady()
    )
    let selectedItem = try #require(window.item(at: 80))
    #expect(execution.target == .playlist(selectedItem))
    _ = session.finishKeyboardAction(execution)
    _ = session.dismissByUser()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistBackgroundGenerationChangeDoesNotCancelCurrentIntent() throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ) { _ in nil }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    func currentCue(_ ordinal: Int) -> SubtitleFocusCue {
        SubtitleFocusCue(
            id: Int64(ordinal + 1),
            cueGroupID: Int64(ordinal + 11),
            ordinal: ordinal,
            eventIndex: ordinal,
            displayOrder: 0,
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 500,
            content: "current-\(ordinal)"
        )
    }
    let cues = [currentCue(0), currentCue(1)]
    #expect(session.publishInitialSnapshot(
        SubtitleFocusSnapshot(
            totalCount: 2,
            selectedOrdinal: 0,
            cues: cues
        ),
        token: session.token
    ))
    #expect(session.requestKeyboardNavigation(.forward))
    let currentRequest = try #require(session.keyboardNavigationRequest)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)

    #expect(source.updateBoundary(
        totalCount: 3,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
            2: .search(1_002),
        ]
    ))

    #expect(session.keyboardNavigationRequest == currentRequest)
    #expect(session.pendingKeyboardAction == .copyCueText)
    session.noteCueReelMotion(true)
    #expect(session.commitKeyboardNavigation(currentRequest))
    session.noteCueReelMotion(false)
    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady()
    )
    #expect(execution.context.cue == cues[1])
    _ = session.finishKeyboardAction(execution)
    _ = session.dismissByUser()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistSourceRejectsResponseThatArrivesAfterBoundaryChanges() async throws {
    let deferredLoader = DeferredPlaybackPlaylistWindowLoader()
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 1,
        knownItemIDsByOrdinal: [0: .search(1_000)]
    ) { request in
        await deferredLoader.load(request)
    }
    let request = makePlaybackPlaylistWindowRequest(
        boundary: source.boundary,
        ordinalRange: 0..<1
    )
    let loadTask = Task { @MainActor in
        await source.loadWindow(request)
    }

    let didStart = await waitForPlaybackPlaylistCondition {
        deferredLoader.pendingRequest != nil
    }
    #expect(didStart)
    #expect(source.updateBoundary(
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ))
    deferredLoader.resolve(
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    )

    #expect(await loadTask.value == nil)
}

@MainActor
@Test
func playbackPlaylistSessionInvalidationClearsWindowWithoutInvalidatingSource() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let originalBoundary = source.boundary
    let session = try #require(source.makeSessionWindowStore())

    #expect(session.requestWindow(containing: 0))
    let didLoad = await waitForPlaybackPlaylistCondition {
        session.snapshot.loadedItemCount == 2
    }
    #expect(didLoad)
    #expect(session.retainedItemCount == 2)

    session.invalidate()

    #expect(session.retainedItemCount == 0)
    #expect(session.items.isEmpty)
    #expect(session.selectedOrdinal == nil)
    #expect(session.snapshot.totalCount == 0)
    #expect(session.snapshot.loadedItemCount == 0)
    #expect(source.hasItems)
    #expect(source.boundary == originalBoundary)

    let request = makePlaybackPlaylistWindowRequest(
        boundary: source.boundary,
        ordinalRange: 0..<2
    )
    #expect(await source.loadWindow(request) != nil)
    let replacementSession = source.makeSessionWindowStore()
    #expect(replacementSession != nil)
    replacementSession?.invalidate()
}

@MainActor
@Test
func playbackPlaylistSessionDismissalCancelsDetachedWindowWorker() async throws {
    let cancellationProbe = PlaybackPlaylistCancellationProbe()
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 1,
        knownItemIDsByOrdinal: [0: .search(1_000)]
    ) { _ in
        do {
            try await AppCoordinator.runCancellableDetached(
                priority: .userInitiated
            ) {
                try cancellationProbe.waitForCancellation()
            }
        } catch {
            return nil
        }
        return nil
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/current.mkv",
                subtitlePath: "/subtitle/current.ass",
                subtitleFormat: .ass
            ),
            timestampMilliseconds: 0,
            wasPlaying: false
        ),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: source
    )
    let window = try #require(session.playlistWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition(attempts: 1_000) {
        cancellationProbe.didStart
    })

    _ = session.dismissByUser()

    #expect(await waitForPlaybackPlaylistCondition(attempts: 1_000) {
        cancellationProbe.didObserveCancellation
    })
    #expect(window.retainedItemCount == 0)
    #expect(window.snapshot.totalCount == 0)
    source.invalidate()
}

@MainActor
@Test
func playbackStoreKeepsOriginSourceAcrossOverlaySessionsAndClearsItOnPlaybackReplacement() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistSearchItems(in: request.ordinalRange)
        )
    }
    let playback = PlaybackStore(userDefaults: .standard)
    playback.setPlaylistSource(source)
    let openSnapshot = PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/video/current.mkv",
            subtitlePath: "/subtitle/current.ass",
            subtitleFormat: .ass
        ),
        timestampMilliseconds: 1_000,
        wasPlaying: false
    )
    let firstSession = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: openSnapshot
    ))
    #expect(firstSession.availableModules == PlaybackOverlayModule.allCases)
    let firstWindow = try #require(firstSession.playlistWindow)
    #expect(firstWindow.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistCondition {
        firstWindow.snapshot.loadedItemCount == 2
    })

    playback.releaseSubtitleFocusSession(firstSession)

    #expect(firstWindow.retainedItemCount == 0)
    #expect(playback.playlistSource === source)
    #expect(source.hasItems)
    let secondSession = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: openSnapshot
    ))
    #expect(secondSession.playlistWindow != nil)
    playback.releaseSubtitleFocusSession(secondSession)

    playback.clearPlaylistSource()

    #expect(playback.playlistSource == nil)
    #expect(!source.hasItems)
}

@MainActor
@Test
func playbackPlaylistSourceInvalidationRejectsLoadsAndBoundaryUpdates() async {
    var loaderCallCount = 0
    let source = PlaybackPlaylistSource(
        kind: .shiori,
        totalCount: 1,
        knownItemIDsByOrdinal: [0: .shiori(9)]
    ) { request in
        loaderCallCount += 1
        return PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: [PlaybackPlaylistItem(
                shiori: makePlaybackPlaylistShiori(id: 9),
                cuePresentation: nil,
                ordinal: 0
            )]
        )
    }
    let activeBoundary = source.boundary
    let request = makePlaybackPlaylistWindowRequest(
        boundary: activeBoundary,
        ordinalRange: 0..<1
    )

    source.invalidate()

    #expect(!source.hasItems)
    #expect(source.boundary.datasetID == activeBoundary.datasetID)
    #expect(source.boundary.generation == activeBoundary.generation + 1)
    #expect(source.boundary.totalCount == 0)
    #expect(await source.loadWindow(request) == nil)
    #expect(loaderCallCount == 0)
    #expect(!source.updateBoundary(
        totalCount: 1,
        knownItemIDsByOrdinal: [0: .shiori(9)]
    ))
    #expect(source.makeSessionWindowStore() == nil)
}

private func makePlaybackPlaylistSearchResult(
    id: Int64,
    content: String? = nil,
    primaryGroupIndex: Int = 0,
    cueGroupLines: [String]? = nil,
    searchRank: Int? = nil
) -> SubtitleSearchResult {
    let resolvedContent = content ?? "cue-\(id)"
    let resolvedCueGroupLines = cueGroupLines ?? [resolvedContent]
    return SubtitleSearchResult(
        entryID: id,
        cueGroupID: id + 100,
        cueEventIndex: Int(id + 200),
        cueDisplayOrder: primaryGroupIndex,
        primaryGroupIndex: primaryGroupIndex,
        subtitlePath: "/subtitle/\(id).ass",
        subtitleFormat: .ass,
        videoPath: "/video/\(id).mkv",
        videoName: "\(id).mkv",
        startMilliseconds: Int(id * 1_000),
        endMilliseconds: Int(id * 1_000 + 500),
        content: resolvedContent,
        cueLines: resolvedCueGroupLines,
        cueGroupLines: resolvedCueGroupLines,
        searchRank: searchRank ?? Int(id)
    )
}

private func makePlaybackPlaylistSearchItems(
    in ordinalRange: Range<Int>
) -> [PlaybackPlaylistItem] {
    ordinalRange.map { ordinal in
        PlaybackPlaylistItem(
            searchResult: makePlaybackPlaylistSearchResult(
                id: Int64(1_000 + ordinal)
            ),
            ordinal: ordinal
        )
    }
}

private func makePlaybackPlaylistShiori(
    id: Int64,
    content: String? = nil,
    cueEventIndex: Int? = nil,
    cueDisplayOrder: Int? = nil
) -> Shiori {
    Shiori(
        id: id,
        subtitlePath: "/subtitle/shiori-\(id).ass",
        subtitleFormat: .ass,
        videoPath: "/video/shiori-\(id).mkv",
        videoName: "shiori-\(id).mkv",
        startMilliseconds: Int(id * 1_000),
        endMilliseconds: Int(id * 1_000 + 500),
        cueEventIndex: cueEventIndex,
        cueDisplayOrder: cueDisplayOrder,
        content: content ?? "shiori-\(id)",
        isValid: true,
        createdAt: "2026-07-15T00:00:00Z"
    )
}

private func makePlaybackPlaylistWindowRequest(
    boundary: PlaybackPlaylistSourceBoundary,
    ordinalRange: Range<Int>
) -> PlaybackPlaylistSourceWindowRequest {
    PlaybackPlaylistSourceWindowRequest(
        datasetID: boundary.datasetID,
        generation: boundary.generation,
        sourceRevision: boundary.revision,
        totalCount: boundary.totalCount,
        ordinalRange: ordinalRange
    )
}

@MainActor
private func waitForPlaybackPlaylistCondition(
    attempts: Int = 100,
    _ condition: () -> Bool
) async -> Bool {
    for _ in 0..<attempts {
        if condition() {
            return true
        }
        await Task.yield()
    }
    return condition()
}

@MainActor
private final class DeferredPlaybackPlaylistWindowLoader {
    private(set) var pendingRequest: PlaybackPlaylistSourceWindowRequest?
    private var continuation: CheckedContinuation<
        PlaybackPlaylistSourceWindowResponse?,
        Never
    >?

    func load(
        _ request: PlaybackPlaylistSourceWindowRequest
    ) async -> PlaybackPlaylistSourceWindowResponse? {
        await withCheckedContinuation { continuation in
            pendingRequest = request
            self.continuation = continuation
        }
    }

    func resolve(_ response: PlaybackPlaylistSourceWindowResponse?) {
        let continuation = continuation
        self.continuation = nil
        pendingRequest = nil
        continuation?.resume(returning: response)
    }
}

private final class PlaybackPlaylistCancellationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var observedCancellation = false

    var didStart: Bool {
        lock.lock()
        defer { lock.unlock() }
        return started
    }

    var didObserveCancellation: Bool {
        lock.lock()
        defer { lock.unlock() }
        return observedCancellation
    }

    func waitForCancellation() throws {
        lock.lock()
        started = true
        lock.unlock()

        while !Task.isCancelled {
            Thread.sleep(forTimeInterval: 0.001)
        }

        lock.lock()
        observedCancellation = true
        lock.unlock()
        try Task.checkCancellation()
    }
}
