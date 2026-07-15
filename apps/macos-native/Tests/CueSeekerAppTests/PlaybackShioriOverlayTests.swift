import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackShioriEmptySourceRetainsModuleWindowWithoutSelectionOrActions() throws {
    let source = PlaybackCueResultSource(
        kind: .shiori,
        totalCount: 0,
        knownItemIDsByOrdinal: [:]
    ) { _ in
        Issue.record("An empty Shiori source must not request a window")
        return nil
    }
    let playback = PlaybackStore(userDefaults: .standard)
    let session = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: playbackShioriOpenSnapshot(),
        shioriSource: source
    ))
    let window = try #require(session.shioriWindow)

    #expect(window.snapshot.totalCount == 0)
    #expect(window.snapshot.loadedItemCount == 0)
    #expect(window.selectedOrdinal == nil)
    #expect(!window.requestWindow(containing: 0))
    #expect(session.selectModule(.shiori))
    #expect(!session.requestKeyboardNavigation(.forward))
    #expect(session.requestKeyboardAction(.shiori) == .rejected)
    #expect(session.requestKeyboardAction(.copyCueText) == .rejected)
    #expect(session.requestKeyboardAction(.playFromThisCue) == .rejected)

    playback.releaseSubtitleFocusSession(session)
}

@MainActor
@Test
func playbackShioriDefaultsToFirstSelectionAndRetainsOnlyThirtyTwoItems() async throws {
    let totalCount = 50_000
    let source = makePlaybackShioriSource(totalCount: totalCount)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackShioriOpenSnapshot(),
        sessionGeneration: 1,
        shioriSource: source
    )
    let window = try #require(session.shioriWindow)

    #expect(window.selectedOrdinal == 0)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackShioriCondition {
        window.snapshot.loadedItemCount
            == PlaybackVirtualReelWindowPolicy.standard.itemCount
    })

    #expect(window.snapshot.totalCount == totalCount)
    #expect(window.snapshot.loadedOrdinalRange == (0..<32))
    #expect(window.retainedItemCount == 32)
    #expect(window.selectedOrdinal == 0)
    #expect(window.item(at: 0)?.identity == .shiori(10_000))
    #expect(window.item(at: 31)?.identity == .shiori(10_031))

    _ = session.dismissByUser()
}

@MainActor
@Test
func playbackShioriReelOmitsSequenceAndPreservesCueGroupIdentity() async throws {
    _ = NSApplication.shared
    let source = makePlaybackShioriSource(totalCount: 3)
    let window = try #require(source.makeSessionWindowStore(includingEmpty: true))
    let adapter = PlaybackCueResultReelAdapter(
        windowStore: window,
        showsCueGroup: true,
        showsSequenceNumber: false
    )

    adapter.requestWindow(playbackShioriWindowRequest(
        snapshot: adapter.snapshot,
        targetOrdinal: 0
    ))
    #expect(await waitForPlaybackShioriCondition {
        adapter.snapshot.loadedItemCount == 3
    })

    let result = try #require(adapter.cueResult(at: 0))
    let itemID = result.itemID
    let primaryCueIdentity = result.primaryCueIdentity

    #expect(result.sequenceNumber == nil)
    #expect(result.itemID == AnyHashable(PlaybackCueResultItemIdentity.shiori(10_000)))
    #expect(result.primaryCueIdentity == AnyHashable(
        PlaybackPlaylistPrimaryCueIdentity.cue(20_000)
    ))
    #expect(result.primaryCueText == "shiori-10000")
    #expect(result.additionalCueTexts == [
        "before-10000",
        "after-10000",
    ])

    #expect(adapter.setShowsCueGroup(false))
    let primaryOnlyResult = try #require(adapter.cueResult(at: 0))
    #expect(primaryOnlyResult.sequenceNumber == nil)
    #expect(primaryOnlyResult.itemID == itemID)
    #expect(primaryOnlyResult.primaryCueIdentity == primaryCueIdentity)

    adapter.invalidate()
    window.invalidate()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistAndShioriKeepWindowsSelectionsAndActionTargetsIsolated() async throws {
    let playlistSource = makePlaybackSearchPlaylistSource(totalCount: 40)
    let shioriSource = makePlaybackShioriSource(totalCount: 40)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackShioriOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: playlistSource,
        shioriSource: shioriSource
    )
    let playlistWindow = try #require(session.playlistWindow)
    let shioriWindow = try #require(session.shioriWindow)

    #expect(playlistWindow.requestWindow(containing: 0))
    #expect(shioriWindow.requestWindow(containing: 0))
    #expect(await waitForPlaybackShioriCondition {
        playlistWindow.snapshot.loadedItemCount == 32
            && shioriWindow.snapshot.loadedItemCount == 32
    })

    #expect(session.selectModule(.playlist))
    #expect(session.commitVirtualReelSelection(
        playbackShioriSelectionCommit(window: playlistWindow, ordinal: 3),
        module: .playlist
    ))
    let playlistItem = try #require(playlistWindow.item(at: 3))
    guard case .ready(let copyExecution) = session.requestKeyboardAction(
        .copyCueText
    ) else {
        Issue.record("Expected Playlist copy action to be ready")
        return
    }
    #expect(copyExecution.target == .playlist(playlistItem))
    #expect(session.finishKeyboardAction(copyExecution))

    #expect(session.selectModule(.shiori))
    #expect(session.commitVirtualReelSelection(
        playbackShioriSelectionCommit(window: shioriWindow, ordinal: 7),
        module: .shiori
    ))
    let shioriItem = try #require(shioriWindow.item(at: 7))
    guard case .ready(let saveExecution) = session.requestKeyboardAction(
        .shiori
    ) else {
        Issue.record("Expected Shiori save action to be ready")
        return
    }
    #expect(saveExecution.target == .shiori(shioriItem))
    #expect(session.finishKeyboardAction(saveExecution))

    guard case .ready(let shioriCopyExecution) = session.requestKeyboardAction(
        .copyCueText
    ) else {
        Issue.record("Expected Shiori copy action to be ready")
        return
    }
    #expect(shioriCopyExecution.target == .shiori(shioriItem))
    #expect(session.finishKeyboardAction(shioriCopyExecution))

    guard case .ready(let playExecution) = session.requestKeyboardAction(
        .playFromThisCue
    ) else {
        Issue.record("Expected Shiori play action to be ready")
        return
    }
    #expect(playExecution.target == .shiori(shioriItem))
    #expect(session.finishKeyboardAction(playExecution))

    #expect(playlistWindow.selectedOrdinal == 3)
    #expect(shioriWindow.selectedOrdinal == 7)
    #expect(playlistWindow.item(at: 3)?.identity == .search(30_003))
    #expect(shioriWindow.item(at: 7)?.identity == .shiori(10_007))

    #expect(session.selectModule(.playlist))
    #expect(playlistWindow.selectedOrdinal == 3)
    #expect(shioriWindow.selectedOrdinal == 7)

    _ = session.dismissByUser()
    playlistSource.invalidate()
}

@MainActor
@Test
func playbackShioriViewRebindsSharedReelBetweenResultModules() async throws {
    _ = NSApplication.shared
    let playlistSource = makePlaybackSearchPlaylistSource(totalCount: 2)
    let shioriSource = makePlaybackShioriSource(totalCount: 2)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackShioriOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: playlistSource,
        shioriSource: shioriSource
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
    #expect(session.selectModule(.shiori))
    let playlistWindow = try #require(session.playlistWindow)
    let shioriWindow = try #require(session.shioriWindow)
    let suiteName = "PlaybackShioriView-\(UUID().uuidString)"
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
    #expect(await waitForPlaybackShioriCondition(attempts: 1_000) {
        shioriWindow.snapshot.loadedItemCount == 2
    })
    #expect(session.commitVirtualReelSelection(
        playbackShioriSelectionCommit(window: shioriWindow, ordinal: 1),
        module: .shiori
    ))

    #expect(session.selectModule(.playlist))
    hostingView.layoutSubtreeIfNeeded()
    #expect(await waitForPlaybackShioriCondition(attempts: 1_000) {
        playlistWindow.snapshot.loadedItemCount == 2
    })
    #expect(playlistWindow.item(at: 0)?.identity == .search(30_000))
    #expect(shioriWindow.item(at: 0)?.identity == .shiori(10_000))

    #expect(session.selectModule(.shiori))
    hostingView.layoutSubtreeIfNeeded()
    #expect(shioriWindow.selectedOrdinal == 1)

    _ = session.dismissByUser()
    playlistSource.invalidate()
    withExtendedLifetime(hostingView) {}
}

@MainActor
@Test
func playbackShioriDismissalCancelsLoadClearsWindowAndInvalidatesOwnedSource() async throws {
    let cancellationProbe = PlaybackShioriCancellationProbe()
    let source = PlaybackCueResultSource(
        kind: .shiori,
        totalCount: 1,
        knownItemIDsByOrdinal: [0: .shiori(10_000)]
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
    let activeBoundary = source.boundary
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackShioriOpenSnapshot(),
        sessionGeneration: 1,
        shioriSource: source
    )
    let window = try #require(session.shioriWindow)

    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackShioriCondition(attempts: 1_000) {
        cancellationProbe.didStart
    })

    _ = session.dismissByUser()

    #expect(await waitForPlaybackShioriCondition(attempts: 1_000) {
        cancellationProbe.didObserveCancellation
    })
    #expect(session.shioriWindow == nil)
    #expect(window.retainedItemCount == 0)
    #expect(window.selectedOrdinal == nil)
    #expect(window.snapshot.totalCount == 0)
    #expect(source.boundary.datasetID == activeBoundary.datasetID)
    #expect(source.boundary.generation == activeBoundary.generation + 1)
    #expect(source.boundary.totalCount == 0)
    #expect(!source.updateBoundary(
        totalCount: 1,
        knownItemIDsByOrdinal: [0: .shiori(10_000)]
    ))
}

@MainActor
@Test
func playbackShioriSourceUsesCanonicalDatabaseOrder() async throws {
    try await withTemporaryPlaybackShioriApp { app, database in
        let older = try makeDatabasePlaybackShiori(
            in: database,
            content: "older",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = try makeDatabasePlaybackShiori(
            in: database,
            content: "newer",
            createdAt: Date(timeIntervalSince1970: 3_000)
        )
        let middle = try makeDatabasePlaybackShiori(
            in: database,
            content: "middle",
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        let source = app.makePlaybackShioriOverlaySource()
        let window = try #require(source.makeSessionWindowStore(
            includingEmpty: true
        ))

        #expect(window.snapshot.totalCount == 3)
        #expect(window.requestWindow(containing: 0))
        #expect(await waitForPlaybackShioriCondition {
            window.snapshot.loadedItemCount == 3
        })

        #expect(window.items.map(\.identity) == [
            .shiori(newer.id),
            .shiori(middle.id),
            .shiori(older.id),
        ])

        window.invalidate()
        source.invalidate()
    }
}

@MainActor
@Test
func playbackShioriEnterDispatchesFullDatabaseScopeAndContinuousPlayback() async throws {
    try await withTemporaryPlaybackShioriApp { app, database in
        let shiori = try makeDatabasePlaybackShiori(
            in: database,
            content: "selected",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let item = PlaybackCueResultItem(
            shiori: shiori,
            cuePresentation: nil,
            ordinal: 0
        )
        var didOpen = false
        var receivedScope: [Int64]? = [999]
        var receivedContinuous = false

        #expect(app.dispatchPlaybackShioriOverlayItem(item) {
            receivedShiori,
            scope,
            continuous in
            didOpen = receivedShiori.id == shiori.id
            receivedScope = scope
            receivedContinuous = continuous
        })

        #expect(didOpen)
        #expect(receivedScope == nil)
        #expect(receivedContinuous)
    }
}

@MainActor
@Test
func playbackShioriActionsStayIdempotentAndEnterDestroysSession() async throws {
    try await withTemporaryPlaybackShioriApp { app, database in
        let shiori = try makeDatabasePlaybackShiori(
            in: database,
            content: "primary\ncue",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let source = app.makePlaybackShioriOverlaySource()
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackShioriOpenSnapshot(),
            shioriSource: source
        ))
        app.playback.playbackViewModel = PlaybackViewModel(
            player: PlaybackPlayer()
        )
        app.playback.playbackStatus = .paused
        app.shiori.selectedShiori = shiori
        let window = try #require(session.shioriWindow)
        #expect(window.requestWindow(containing: 0))
        #expect(await waitForPlaybackShioriCondition {
            window.snapshot.loadedItemCount == 1
        })
        #expect(session.selectModule(.shiori))
        let selectedItem = try #require(window.item(at: 0))
        #expect(selectedItem.primaryCueText == "primary\ncue")

        #expect(app.handlePlaybackKeyDown(
            keyCode: 1,
            modifierFlagsRawValue: 0
        ))
        #expect(try database.shioriCount() == 1)
        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "Shiori Already Saved"
        )
        #expect(session.activeKeyboardAction == nil)

        guard case .ready(let playExecution) = session.requestKeyboardAction(
            .playFromThisCue
        ) else {
            Issue.record("Expected Shiori play action to be ready")
            return
        }
        var openedShioriItem: PlaybackCueResultItem?
        #expect(app.executePlaybackSubtitleFocusAction(
            playExecution,
            continuousPlay: { _ in false },
            openPlaylistItem: { _ in
                Issue.record("Standalone Shiori must not use Playlist dispatch")
            },
            openShioriItem: { openedShioriItem = $0 }
        ))

        #expect(openedShioriItem == selectedItem)
        #expect(app.playback.subtitleFocusSession == nil)
        #expect(session.state == .closed)
        #expect(session.shioriWindow == nil)
        #expect(window.retainedItemCount == 0)
        #expect(source.boundary.totalCount == 0)
    }
}

@MainActor
@Test
func playbackShioriSaveRefreshesAnEmptySessionWindow() async throws {
    let source = makePlaybackShioriSource(totalCount: 0)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackShioriOpenSnapshot(),
        sessionGeneration: 1,
        shioriSource: source
    )
    let window = try #require(session.shioriWindow)
    let initialGeneration = window.snapshot.generation

    #expect(window.selectedOrdinal == nil)
    #expect(session.refreshShioriAfterSave())
    #expect(window.snapshot.totalCount == 1)
    #expect(window.snapshot.generation == initialGeneration + 1)
    #expect(window.selectedOrdinal == 0)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackShioriCondition {
        window.snapshot.loadedItemCount == 1
    })
    #expect(window.item(at: 0)?.identity == .shiori(10_000))

    _ = session.dismissByUser()
}

@MainActor
@Test
func playbackShioriSavePreservesSelectedResultIdentityAfterPrepend() async throws {
    let before = (0..<80).map { ordinal in
        playbackShioriItem(identityOrdinal: ordinal, ordinal: ordinal)
    }
    let probe = PlaybackShioriPrependProbe(items: before)
    let source = PlaybackCueResultSource(
        kind: .shiori,
        totalCount: before.count,
        knownItemIDsByOrdinal: [:]
    ) { request in
        PlaybackCueResultSourceWindowResponse(
            request: request,
            items: Array(probe.items[request.ordinalRange])
        )
    }
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackShioriOpenSnapshot(),
        sessionGeneration: 1,
        shioriSource: source
    )
    let window = try #require(session.shioriWindow)
    #expect(window.requestWindow(containing: 5))
    #expect(await waitForPlaybackShioriCondition {
        window.snapshot.loadedOrdinalRange.contains(5)
    })
    #expect(window.commitSelection(playbackShioriSelectionCommit(
        window: window,
        ordinal: 5
    )))
    let selectedIdentity = try #require(window.item(at: 5)?.identity)

    #expect(window.requestWindow(containing: 70))
    #expect(await waitForPlaybackShioriCondition {
        window.snapshot.loadedOrdinalRange.contains(70)
            && window.item(at: 5) == nil
    })
    #expect(window.selectedOrdinal == 5)
    #expect(window.selectedItemIdentity == selectedIdentity)

    probe.items = [playbackShioriItem(identityOrdinal: 10_000, ordinal: 0)]
        + before.enumerated().map { ordinal, _ in
            playbackShioriItem(identityOrdinal: ordinal, ordinal: ordinal + 1)
        }
    #expect(session.refreshShioriAfterSave())
    #expect(window.snapshot.totalCount == 81)
    #expect(window.selectedOrdinal == 6)
    #expect(window.selectedItemIdentity == selectedIdentity)
    #expect(window.requestWindow(containing: 6))
    #expect(await waitForPlaybackShioriCondition {
        window.snapshot.loadedOrdinalRange.contains(6)
    })
    #expect(window.item(at: 6)?.identity == selectedIdentity)

    _ = session.dismissByUser()
}

@MainActor
private final class PlaybackShioriPrependProbe {
    var items: [PlaybackCueResultItem]

    init(items: [PlaybackCueResultItem]) {
        self.items = items
    }
}

@MainActor
@Test
func playbackShioriRemoteNavigationDefersOneActionUntilTargetSettles() async throws {
    let source = makePlaybackShioriSource(totalCount: 40)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackShioriOpenSnapshot(),
        sessionGeneration: 1,
        shioriSource: source
    )
    let window = try #require(session.shioriWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackShioriCondition {
        window.snapshot.loadedOrdinalRange == (0..<32)
    })
    #expect(session.selectModule(.shiori))
    #expect(session.commitVirtualReelSelection(
        playbackShioriSelectionCommit(window: window, ordinal: 31),
        module: .shiori
    ))

    #expect(session.requestKeyboardNavigation(.forward))
    #expect(session.keyboardNavigationRequest?.targetOrdinal == 32)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)
    #expect(window.requestWindow(containing: 32))
    #expect(await waitForPlaybackShioriCondition {
        window.snapshot.loadedOrdinalRange.contains(32)
            && window.item(at: 32) != nil
    })
    #expect(session.commitVirtualReelSelection(
        playbackShioriSelectionCommit(window: window, ordinal: 32),
        module: .shiori
    ))

    let execution = try #require(session.consumeDeferredKeyboardActionIfReady())
    let targetItem = try #require(window.item(at: 32))
    #expect(execution.action == .copyCueText)
    #expect(execution.target == .shiori(targetItem))
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
    #expect(session.finishKeyboardAction(execution))

    _ = session.dismissByUser()
}

@MainActor
@Test
func playbackShioriIgnoresLateCurrentMotionAndDeferredActionCallbacks() async throws {
    let source = makePlaybackShioriSource(totalCount: 1)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackShioriOpenSnapshot(),
        sessionGeneration: 1,
        shioriSource: source
    )
    let window = try #require(session.shioriWindow)
    #expect(window.requestWindow(containing: 0))
    #expect(await waitForPlaybackShioriCondition {
        window.snapshot.loadedItemCount == 1
    })
    #expect(session.selectModule(.shiori))
    session.noteCueReelMotion(true, module: .shiori)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)

    session.noteCueReelMotion(false, module: .current)
    session.noteScrollbarDragging(false, module: .current)
    #expect(
        session.consumeDeferredKeyboardActionIfReady(module: .current) == nil
    )
    #expect(
        session.consumeDeferredKeyboardActionIfReady(module: .shiori) == nil
    )

    session.noteCueReelMotion(false, module: .shiori)
    let execution = try #require(
        session.consumeDeferredKeyboardActionIfReady(module: .shiori)
    )
    let targetItem = try #require(window.item(at: 0))
    #expect(execution.target == .shiori(targetItem))
    #expect(session.finishKeyboardAction(execution))

    _ = session.dismissByUser()
}

@MainActor
private func makePlaybackShioriSource(
    totalCount: Int
) -> PlaybackCueResultSource {
    PlaybackCueResultSource(
        kind: .shiori,
        totalCount: totalCount,
        knownItemIDsByOrdinal: [:]
    ) { request in
        PlaybackCueResultSourceWindowResponse(
            request: request,
            items: request.ordinalRange.map(playbackShioriItem)
        )
    }
}

@MainActor
private func withTemporaryPlaybackShioriApp(
    _ body: @MainActor (AppCoordinator, SubtitleDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerPlaybackShioriTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackShioriTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    await app.startupDatabaseTask?.value
    let database = try #require(app.subtitleDatabase)
    try await body(app, database)
}

private func makeDatabasePlaybackShiori(
    in database: SubtitleDatabase,
    content: String,
    createdAt: Date
) throws -> Shiori {
    let identity = Int(createdAt.timeIntervalSince1970)
    return try database.upsertShiori(
        subtitleFile: URL(fileURLWithPath: "/Media/Shiori-\(identity).srt"),
        subtitleFormat: .srt,
        videoFile: URL(fileURLWithPath: "/Media/Shiori-\(identity).mkv"),
        videoName: "Shiori-\(identity).mkv",
        selection: SubtitleCueTextSelection(
            cueGroupID: Int64(identity),
            startMilliseconds: identity,
            endMilliseconds: identity + 500,
            lines: [content]
        ),
        createdAt: createdAt
    )
}

@MainActor
private func makePlaybackSearchPlaylistSource(
    totalCount: Int
) -> PlaybackPlaylistSource {
    PlaybackPlaylistSource(
        kind: .search,
        totalCount: totalCount,
        knownItemIDsByOrdinal: [:]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: request.ordinalRange.map { ordinal in
                PlaybackPlaylistItem(
                    searchResult: playbackShioriSearchResult(ordinal: ordinal),
                    ordinal: ordinal
                )
            }
        )
    }
}

private func playbackShioriItem(ordinal: Int) -> PlaybackCueResultItem {
    playbackShioriItem(identityOrdinal: ordinal, ordinal: ordinal)
}

private func playbackShioriItem(
    identityOrdinal: Int,
    ordinal: Int
) -> PlaybackCueResultItem {
    let shioriID = Int64(10_000 + identityOrdinal)
    let content = "shiori-\(shioriID)"
    return PlaybackCueResultItem(
        shiori: Shiori(
            id: shioriID,
            subtitlePath: "/subtitle/shiori-\(shioriID).ass",
            subtitleFormat: .ass,
            videoPath: "/video/shiori-\(shioriID).mkv",
            videoName: "shiori-\(shioriID).mkv",
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            cueEventIndex: ordinal,
            cueDisplayOrder: 1,
            content: content,
            isValid: true,
            createdAt: "2026-07-15T00:00:00Z"
        ),
        cuePresentation: ShioriCuePresentation(
            cueID: shioriID + 10_000,
            cueGroupID: shioriID + 20_000,
            primaryGroupIndex: 1,
            cueGroupTexts: [
                "before-\(shioriID)",
                content,
                "after-\(shioriID)",
            ],
            languages: [.japanese],
            speakers: []
        ),
        ordinal: ordinal
    )
}

private func playbackShioriSearchResult(ordinal: Int) -> SubtitleSearchResult {
    let entryID = Int64(30_000 + ordinal)
    let content = "search-\(entryID)"
    return SubtitleSearchResult(
        entryID: entryID,
        cueGroupID: entryID + 10_000,
        cueEventIndex: ordinal,
        cueDisplayOrder: 0,
        primaryGroupIndex: 0,
        subtitlePath: "/subtitle/search-\(entryID).ass",
        subtitleFormat: .ass,
        videoPath: "/video/search-\(entryID).mkv",
        videoName: "search-\(entryID).mkv",
        startMilliseconds: ordinal * 1_000,
        endMilliseconds: ordinal * 1_000 + 900,
        content: content,
        cueLines: [content],
        cueGroupLines: [content],
        searchRank: ordinal
    )
}

private func playbackShioriOpenSnapshot() -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/video/current.mkv",
            subtitlePath: "/subtitle/current.ass",
            subtitleFormat: .ass
        ),
        timestampMilliseconds: 0,
        wasPlaying: false
    )
}

private func playbackShioriWindowRequest(
    snapshot: PlaybackVirtualReelSnapshot,
    targetOrdinal: Int
) -> PlaybackVirtualReelWindowRequest {
    PlaybackVirtualReelWindowRequest(
        datasetID: snapshot.datasetID,
        generation: snapshot.generation,
        revision: snapshot.revision,
        targetOrdinal: targetOrdinal,
        suggestedOrdinalRange: PlaybackVirtualReelWindowPolicy.standard.windowRange(
            totalCount: snapshot.totalCount,
            targetOrdinal: targetOrdinal
        ),
        reason: .visible
    )
}

@MainActor
private func playbackShioriSelectionCommit(
    window: PlaybackCueResultSessionWindowStore,
    ordinal: Int
) -> PlaybackVirtualReelSelectionCommit {
    PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable(window.reelDatasetID ?? ""),
        generation: window.snapshot.generation,
        ordinal: ordinal
    )
}

@MainActor
private func waitForPlaybackShioriCondition(
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

private final class PlaybackShioriCancellationProbe: @unchecked Sendable {
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
