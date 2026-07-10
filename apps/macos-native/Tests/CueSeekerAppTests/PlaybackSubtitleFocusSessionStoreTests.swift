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

    #expect(session.commitNativeReelSelection(ordinal: 10))
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
    #expect(session.focusAnchorY == nil)
    #expect(session.commitNativeReelSelection(ordinal: 19))
    #expect(session.currentSnapshot?.selectedOrdinal == 19)
    #expect(session.currentSnapshot?.selectedCue == complete.cues[19])
}

@MainActor
@Test
func subtitleFocusCompleteBatchPreservesPendingNavigationAndMenuOwnership() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.requestKeyboardNavigation(.forward))
    let request = try #require(session.keyboardNavigationRequest)
    session.noteCueReelMotion(true)

    #expect(session.publishCompleteCueBatch(
        SubtitleFocusCueBatch(totalCount: 20, cues: focusCues(0..<20)),
        token: session.token
    ))

    #expect(session.currentSnapshot?.selectedOrdinal == 12)
    #expect(session.keyboardNavigationRequest == request)
    #expect(!session.allowsNativeWheelInput())
    #expect(session.commitKeyboardNavigation(request))
    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    session.noteCueReelMotion(false)

    let menuSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 2
    )
    #expect(menuSession.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: menuSession.token
    ))
    let cue = try #require(menuSession.actionMenuCandidateForKeyboard())
    #expect(menuSession.openActionMenuFromKeyboard(for: cue))
    let menuState = try #require(menuSession.actionMenuState)
    #expect(menuSession.publishCompleteCueBatch(
        SubtitleFocusCueBatch(totalCount: 20, cues: focusCues(0..<20)),
        token: menuSession.token
    ))
    #expect(menuSession.currentSnapshot?.selectedOrdinal == 12)
    #expect(menuSession.completeCueBatch?.cues.count == 20)
    #expect(menuSession.actionMenuState == menuState)
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
    var mismatchedCues = focusCues(0..<20)
    mismatchedCues[12] = SubtitleFocusCue(
        id: 13,
        ordinal: 12,
        startMilliseconds: 12_000,
        endMilliseconds: 12_900,
        lines: ["changed cue"]
    )
    let mismatchedInitialCue = SubtitleFocusCueBatch(
        totalCount: 20,
        cues: mismatchedCues
    )
    #expect(!session.publishCompleteCueBatch(wrongTotal, token: session.token))
    #expect(!session.publishCompleteCueBatch(missingCue, token: session.token))
    #expect(!session.publishCompleteCueBatch(
        mismatchedInitialCue,
        token: session.token
    ))
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
func subtitleFocusInitialSnapshotRequiresCompleteExpectedWindow() {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    let partialSnapshot = SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: focusCues(7..<16)
    )

    #expect(!session.publishInitialSnapshot(
        partialSnapshot,
        token: session.token
    ))
    #expect(session.state == .opening)
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
    #expect(secondSession.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: secondSession.token
    ))
    #expect(!secondSession.publishCompleteCueBatch(
        SubtitleFocusCueBatch(totalCount: 20, cues: focusCues(0..<20)),
        token: firstToken
    ))
    #expect(secondSession.completeCueBatch == nil)
    #expect(secondSession.retainedCueCount == 10)
}

@MainActor
@Test
func subtitleFocusDismissalReturnsCapturedPlaybackDecisionAndReleasesCues() throws {
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
func subtitleFocusSessionNavigatesAvailableCuesAndPreservesPointerAnchor() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: true),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.focusAnchorY == nil)

    #expect(session.commitNativeReelSelection(ordinal: 13))
    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(session.focusAnchorY == nil)

    let clickedCue = try #require(session.cue(at: 10))
    #expect(session.openActionMenuFromPointer(
        for: clickedCue,
        focusAnchorY: 224
    ))
    #expect(session.currentSnapshot?.selectedOrdinal == 10)
    #expect(session.focusAnchorY == 224)
    #expect(session.dismissActionMenu())
    #expect(session.commitNativeReelSelection(ordinal: 9))
    #expect(session.currentSnapshot?.selectedOrdinal == 9)
    #expect(session.focusAnchorY == 224)
    #expect(!session.commitNativeReelSelection(ordinal: 5))
    #expect(session.currentSnapshot?.selectedOrdinal == 9)
    #expect(session.focusAnchorY == 224)
}

@MainActor
@Test
func subtitleFocusSessionStopsAtDocumentAndInitialWindowBoundaries() throws {
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
    #expect(!firstSession.requestKeyboardNavigation(.backward))
    #expect(!firstSession.commitNativeReelSelection(ordinal: -1))
    #expect(firstSession.currentSnapshot?.selectedOrdinal == 0)

    let initialWindowEndSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 2
    )
    #expect(initialWindowEndSession.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: initialWindowEndSession.token
    ))
    #expect(initialWindowEndSession.commitNativeReelSelection(ordinal: 15))
    #expect(!initialWindowEndSession.requestKeyboardNavigation(.forward))
    #expect(!initialWindowEndSession.commitNativeReelSelection(ordinal: 16))
    #expect(initialWindowEndSession.currentSnapshot?.selectedOrdinal == 15)

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
    #expect(!lastSession.requestKeyboardNavigation(.forward))
    #expect(!lastSession.commitNativeReelSelection(ordinal: 20))
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
    let clickedCue = try #require(session.cue(at: 10))
    #expect(session.openActionMenuFromPointer(
        for: clickedCue,
        focusAnchorY: 224
    ))
    #expect(session.dismissActionMenu())

    #expect(session.dismissByUser() == true)
    #expect(session.focusAnchorY == nil)
    #expect(!session.requestKeyboardNavigation(.forward))
    #expect(!session.commitNativeReelSelection(ordinal: 11))
}

@MainActor
@Test
func subtitleFocusSessionKeepsOneCumulativeKeyboardTarget() throws {
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
    #expect(session.keyboardNavigationRequest?.targetOrdinal == 12)
    #expect(session.currentSnapshot?.selectedOrdinal == 12)
    let request = try #require(session.keyboardNavigationRequest)
    #expect(session.commitKeyboardNavigation(request))
    #expect(session.keyboardNavigationRequest == nil)
}

@MainActor
@Test
func subtitleFocusKeyboardRepeatUsesConstantPendingState() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        SubtitleFocusSnapshot(
            totalCount: 200,
            selectedOrdinal: 12,
            cues: focusCues(6..<16)
        ),
        token: session.token
    ))
    #expect(session.publishCompleteCueBatch(
        SubtitleFocusCueBatch(totalCount: 200, cues: focusCues(0..<200)),
        token: session.token
    ))

    for _ in 0..<100 {
        #expect(session.requestKeyboardNavigation(.forward))
    }

    let request = try #require(session.keyboardNavigationRequest)
    #expect(request.sequence == 100)
    #expect(request.targetOrdinal == 112)
    #expect(session.currentSnapshot?.selectedOrdinal == 12)
    #expect(session.commitKeyboardNavigation(request))
    #expect(session.currentSnapshot?.selectedOrdinal == 112)
    #expect(session.keyboardNavigationRequest == nil)
}

@MainActor
@Test
func subtitleFocusKeyboardRepeatContinuesOnlyItsOwnNativeMotion() throws {
    let wheelSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(wheelSession.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: wheelSession.token
    ))
    #expect(wheelSession.allowsNativeWheelInput())
    #expect(wheelSession.allowsNativeScrollbarInput())
    wheelSession.noteCueReelMotion(true)
    #expect(!wheelSession.requestKeyboardNavigation(.forward))
    #expect(!wheelSession.allowsNativeScrollbarInput())

    let keyboardSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 2
    )
    #expect(keyboardSession.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: keyboardSession.token
    ))
    #expect(keyboardSession.requestKeyboardNavigation(.forward))
    #expect(!keyboardSession.allowsNativeWheelInput())
    #expect(!keyboardSession.allowsNativeScrollbarInput())
    keyboardSession.noteCueReelMotion(true)
    #expect(keyboardSession.requestKeyboardNavigation(.forward))
    #expect(keyboardSession.keyboardNavigationRequest?.targetOrdinal == 14)
}

@MainActor
@Test
func subtitleFocusNativeWheelCommitsBeforeDeferredMenuOpens() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    session.noteCueReelMotion(true)
    #expect(session.deferActionMenuOpenUntilNavigationCompletes())
    #expect(!session.allowsNativeWheelInput())

    #expect(session.commitNativeReelSelection(ordinal: 13))
    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    session.noteCueReelMotion(false)
    #expect(session.consumeDeferredActionMenuOpen())
}

@MainActor
@Test
func subtitleFocusOverlayCommitsKeyboardTargetQueuedBeforeMount() throws {
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
    RunLoop.main.run(until: Date().addingTimeInterval(0.35))

    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(session.keyboardNavigationRequest == nil)
    withExtendedLifetime(hostingView) {}
}

@MainActor
@Test
func playbackSourceReplacementReleasesCompleteSubtitleFocusCollection() async throws {
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
    #expect(session.publishCompleteCueBatch(
        SubtitleFocusCueBatch(totalCount: 20, cues: focusCues(0..<20)),
        token: session.token
    ))
    #expect(session.retainedCueCount == 20)

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
