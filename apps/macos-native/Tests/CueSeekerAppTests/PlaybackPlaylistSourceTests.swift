import AppKit
import CueSeekerCore
import Foundation
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
