import AppKit
import Combine
import CueSeekerCore
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackStoreCreatesSubtitleFocusSessionOnlyAfterOpen() throws {
    let playback = PlaybackStore(userDefaults: .standard)

    #expect(playback.subtitleFocusSession == nil)

    let session = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: focusOpenSnapshot(wasPlaying: true)
    ))

    #expect(playback.subtitleFocusSession === session)
    #expect(session.state == .opening)
    #expect(session.retainedCueCount == 0)
}

@MainActor
@Test
func subtitleFocusInitialSnapshotPublishesOnlyThroughChildStore() throws {
    let playback = PlaybackStore(userDefaults: .standard)
    var playbackInvalidations = 0
    let playbackCancellable = playback.objectWillChange.sink {
        playbackInvalidations += 1
    }
    let session = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: focusOpenSnapshot(wasPlaying: true)
    ))
    var sessionInvalidations = 0
    let sessionCancellable = session.objectWillChange.sink {
        sessionInvalidations += 1
    }
    let snapshot = focusPresentationSnapshot()

    #expect(playbackInvalidations == 1)
    #expect(session.publishInitialSnapshot(snapshot, token: session.token))
    #expect(session.state == .cueSelection(snapshot))
    #expect(session.currentSnapshot == snapshot)
    #expect(session.retainedCueCount == snapshot.cues.count)
    #expect(playbackInvalidations == 1)
    #expect(sessionInvalidations == 1)

    withExtendedLifetime(playbackCancellable) {}
    withExtendedLifetime(sessionCancellable) {}
}

@MainActor
@Test
func subtitleFocusCompleteCueBatchPublishesAfterInitialWindow() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    let initial = focusPresentationSnapshot()
    #expect(session.publishInitialSnapshot(initial, token: session.token))
    #expect(session.completeCueLoadTotalCount == 20)

    let anchorY: CGFloat = 224
    #expect(session.selectCue(ordinal: 10, focusAnchorY: anchorY))
    let complete = SubtitleFocusCueBatch(
        totalCount: 20,
        cues: focusCues(0..<20)
    )
    #expect(session.publishCompleteCueBatch(complete, token: session.token))

    #expect(session.completeCueLoadTotalCount == nil)
    #expect(session.retainedCueCount == 20)
    #expect(session.completeCueBatch == complete)
    #expect(session.cue(at: 0)?.text == "cue 0")
    #expect(session.cue(at: 19)?.text == "cue 19")
    #expect(session.currentSnapshot?.selectedOrdinal == 10)
    #expect(session.focusAnchorY == anchorY)
    #expect(session.windowLoadRequestAfterNavigation(.forward) == nil)

    session.noteScrollbarPreviewChanged(ordinal: 19)
    #expect(!session.isTargetWindowLoading)
    #expect(session.commitCachedScrollbarTarget(ordinal: 19))
    #expect(session.currentSnapshot?.selectedOrdinal == 19)
    #expect(session.currentSnapshot?.selectedCue == complete.cues[19])
}

@MainActor
@Test
func subtitleFocusCompleteCueBatchRejectsMalformedAndLateResults() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))

    let wrongTotal = SubtitleFocusCueBatch(
        totalCount: 19,
        cues: focusCues(0..<19)
    )
    let missingCue = SubtitleFocusCueBatch(
        totalCount: 20,
        cues: focusCues(0..<19)
    )
    #expect(!session.publishCompleteCueBatch(wrongTotal, token: session.token))
    #expect(!session.publishCompleteCueBatch(missingCue, token: session.token))
    #expect(session.retainedCueCount == 10)

    let token = session.token
    _ = session.dismissByUser()
    #expect(!session.publishCompleteCueBatch(
        SubtitleFocusCueBatch(totalCount: 20, cues: focusCues(0..<20)),
        token: token
    ))
    #expect(session.retainedCueCount == 0)
}

@MainActor
@Test
func subtitleFocusShortInitialWindowIsAlreadyComplete() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    let snapshot = SubtitleFocusSnapshot(
        totalCount: 7,
        selectedOrdinal: 3,
        cues: focusCues(0..<7)
    )

    #expect(session.publishInitialSnapshot(snapshot, token: session.token))
    #expect(session.completeCueLoadTotalCount == nil)
    #expect(session.completeCueBatch == SubtitleFocusCueBatch(
        totalCount: 7,
        cues: focusCues(0..<7)
    ))
    #expect(session.retainedCueCount == 7)
}

@MainActor
@Test
func subtitleFocusSessionRejectsStaleGenerationAndSource() throws {
    let playback = PlaybackStore(userDefaults: .standard)
    let firstSession = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: focusOpenSnapshot(wasPlaying: true)
    ))
    let firstToken = firstSession.token
    firstSession.invalidateForSourceReplacement()
    playback.releaseSubtitleFocusSession(firstSession)

    let secondSession = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: focusOpenSnapshot(wasPlaying: false)
    ))
    #expect(secondSession.token.sessionGeneration == firstToken.sessionGeneration + 1)
    #expect(!secondSession.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: firstToken
    ))

    let otherSourceToken = PlaybackSubtitleFocusSessionToken(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/Media/Other.mkv",
            subtitlePath: "/Media/Other.srt",
            subtitleFormat: .srt
        ),
        sessionGeneration: secondSession.token.sessionGeneration
    )
    #expect(!secondSession.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: otherSourceToken
    ))
    #expect(secondSession.state == .opening)
    #expect(secondSession.retainedCueCount == 0)
}

@MainActor
@Test
func subtitleFocusDismissalReturnsCapturedPlaybackDecisionAndClearsCache() throws {
    let playback = PlaybackStore(userDefaults: .standard)
    let session = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: focusOpenSnapshot(wasPlaying: true)
    ))
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))

    #expect(session.dismissByUser() == true)
    #expect(session.state == .closed)
    #expect(session.retainedCueCount == 0)
    #expect(session.dismissByUser() == nil)

    playback.releaseSubtitleFocusSession(session)
    #expect(playback.subtitleFocusSession == nil)
}

@MainActor
@Test
func subtitleFocusOpeningFailureRestoresOnlyOriginallyPlayingSession() throws {
    let playingSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: true),
        sessionGeneration: 1
    )
    #expect(playingSession.failOpening(token: playingSession.token) == true)
    #expect(playingSession.state == .closed)

    let pausedSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 2
    )
    #expect(pausedSession.failOpening(token: pausedSession.token) == false)
    #expect(pausedSession.state == .closed)
}

@MainActor
@Test
func subtitleFocusSessionNavigatesCachedCuesAndPreservesFocusAnchor() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: true),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.initialSelectedOrdinal == 12)
    #expect(session.focusAnchorY == nil)
    #expect(session.canMoveSelection(.backward))
    #expect(session.canMoveSelection(.forward))

    #expect(session.moveSelection(.forward))
    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(session.initialSelectedOrdinal == 12)
    #expect(session.focusAnchorY == nil)

    #expect(session.selectCue(ordinal: 10, focusAnchorY: 224))
    #expect(session.currentSnapshot?.selectedOrdinal == 10)
    #expect(session.focusAnchorY == 224)
    #expect(session.selectCue(ordinal: 10, focusAnchorY: 999))
    #expect(session.focusAnchorY == 224)

    #expect(session.moveSelection(.backward))
    #expect(session.currentSnapshot?.selectedOrdinal == 9)
    #expect(session.focusAnchorY == 224)
    #expect(!session.selectCue(ordinal: 5, focusAnchorY: 88))
    #expect(!session.selectCue(ordinal: 11, focusAnchorY: .nan))
    #expect(session.currentSnapshot?.selectedOrdinal == 9)
    #expect(session.focusAnchorY == 224)
}

@MainActor
@Test
func subtitleFocusSessionStopsAtDocumentAndCacheBoundaries() throws {
    let firstSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    let firstSnapshot = SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 0,
        cues: focusCues(0..<10)
    )
    #expect(firstSession.publishInitialSnapshot(firstSnapshot, token: firstSession.token))
    #expect(!firstSession.canMoveSelection(.backward))
    #expect(!firstSession.moveSelection(.backward))
    #expect(firstSession.currentSnapshot?.selectedOrdinal == 0)

    let cacheEndSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 2
    )
    let cacheEndSnapshot = SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 9,
        cues: focusCues(0..<10)
    )
    #expect(cacheEndSession.publishInitialSnapshot(cacheEndSnapshot, token: cacheEndSession.token))
    #expect(!cacheEndSession.canMoveSelection(.forward))
    #expect(!cacheEndSession.moveSelection(.forward))
    #expect(cacheEndSession.currentSnapshot?.selectedOrdinal == 9)

    let lastSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 3
    )
    let lastSnapshot = SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 19,
        cues: focusCues(10..<20)
    )
    #expect(lastSession.publishInitialSnapshot(lastSnapshot, token: lastSession.token))
    #expect(!lastSession.canMoveSelection(.forward))
    #expect(!lastSession.moveSelection(.forward))
    #expect(lastSession.currentSnapshot?.selectedOrdinal == 19)
}

@MainActor
@Test
func subtitleFocusSessionCloseClearsAnchorAndRejectsNavigation() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: true),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.selectCue(ordinal: 10, focusAnchorY: 224))

    #expect(session.dismissByUser() == true)
    #expect(session.initialSelectedOrdinal == nil)
    #expect(session.focusAnchorY == nil)
    #expect(!session.canMoveSelection(.forward))
    #expect(!session.moveSelection(.forward))
    #expect(!session.selectCue(ordinal: 11, focusAnchorY: 360))
}

@MainActor
@Test
func subtitleFocusSessionQueuesEveryKeyboardNavigationRequest() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))

    #expect(session.requestKeyboardNavigation(.backward))
    #expect(session.requestKeyboardNavigation(.forward))
    #expect(session.keyboardNavigationRequest?.sequence == 2)
    #expect(session.currentSnapshot?.selectedOrdinal == 12)
    #expect(session.takePendingKeyboardNavigationDirections() == [.backward, .forward])
    #expect(session.takePendingKeyboardNavigationDirections().isEmpty)
}

@MainActor
@Test
func subtitleFocusOverlayDrainsKeyboardRequestQueuedBeforeMount() throws {
    _ = NSApplication.shared
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.requestKeyboardNavigation(.forward))
    #expect(session.currentSnapshot?.selectedOrdinal == 12)

    let hostingView = NSHostingView(
        rootView: PlaybackSubtitleFocusLayer(session: session)
            .frame(width: 1_280, height: 720)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 1_280, height: 720)
    hostingView.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))

    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(session.takePendingKeyboardNavigationDirections().isEmpty)
    withExtendedLifetime(hostingView) {}
}

@MainActor
@Test
func playbackSourceReplacementReleasesSubtitleFocusSessionAndCache() async throws {
    let suiteName = "CueSeekerSubtitleFocusLifecycleTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSubtitleFocusLifecycleTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let session = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: focusOpenSnapshot(wasPlaying: true)
    ))
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.retainedCueCount == 10)

    app.invalidatePlaybackSubtitleFocusForSourceReplacement()

    #expect(app.playback.subtitleFocusSession == nil)
    #expect(session.state == .closed)
    #expect(session.retainedCueCount == 0)
}

private func focusOpenSnapshot(wasPlaying: Bool) -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/Media/Focus.mkv",
            subtitlePath: "/Media/Focus.srt",
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 12_500,
        wasPlaying: wasPlaying
    )
}

private func focusPresentationSnapshot() -> SubtitleFocusSnapshot {
    SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: (6..<16).map { ordinal in
            SubtitleFocusCue(
                id: Int64(ordinal + 1),
                ordinal: ordinal,
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 900,
                lines: ["cue \(ordinal)"]
            )
        }
    )
}

private func focusCues(_ range: Range<Int>) -> [SubtitleFocusCue] {
    range.map { ordinal in
        SubtitleFocusCue(
            id: Int64(ordinal + 1),
            ordinal: ordinal,
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            lines: ["cue \(ordinal)"]
        )
    }
}
