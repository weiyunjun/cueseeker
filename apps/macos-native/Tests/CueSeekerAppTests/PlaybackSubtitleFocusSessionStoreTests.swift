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
func playbackOverlaySessionUsesCanonicalModuleOrderWithOptionalPlaylist() throws {
    let withoutPlaylist = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(withoutPlaylist.availableModules == [.current])
    #expect(withoutPlaylist.selectedModule == .current)

    let withPlaylist = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 2,
        availableModules: PlaybackOverlayModule.modules(hasPlaylist: true)
    )
    #expect(withPlaylist.availableModules == [.current, .playlist])
    #expect(withPlaylist.selectedModule == .current)
    #expect(!withPlaylist.presentModule(.search))
    #expect(withPlaylist.selectedModule == .current)

    let reorderedAndDuplicated = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 3,
        availableModules: [.shiori, .playlist, .shiori]
    )
    #expect(reorderedAndDuplicated.availableModules == [
        .current,
        .playlist,
        .shiori,
    ])
}

@MainActor
@Test
func playbackOverlaySessionRejectsModuleSelectionWhileOpening() {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases
    )

    #expect(session.state == .opening)
    #expect(!session.selectModule(.search))
    #expect(!session.selectNextModule())
    #expect(session.selectedModule == .current)
    #expect(session.presentModule(.search))
    #expect(session.selectedModule == .search)
    #expect(session.presentModule(.search))

    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.selectModule(.current))
}

@MainActor
@Test
func playbackOverlaySessionCyclesModulesAndPreservesCurrentSelection() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.commitNativeReelSelection(ordinal: 13))

    for expectedModule in [
        PlaybackOverlayModule.playlist,
        .search,
        .recent,
        .library,
        .shiori,
        .current,
    ] {
        #expect(session.selectNextModule())
        #expect(session.selectedModule == expectedModule)
    }

    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(!session.selectModule(.current))
    #expect(session.selectModule(.library))
    #expect(session.selectModule(.playlist))
}

@MainActor
@Test
func playbackOverlaySessionClearsModuleAndCurrentDataOnCloseThenReopensFresh() throws {
    let playback = PlaybackStore(userDefaults: .standard)
    let first = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: focusOpenSnapshot(wasPlaying: true),
        availableModules: PlaybackOverlayModule.allCases
    ))
    #expect(first.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: first.token
    ))
    #expect(first.selectModule(.search))
    let firstToken = first.token

    #expect(first.dismissByUser() == true)
    #expect(first.selectedModule == nil)
    #expect(first.availableModules.isEmpty)
    #expect(first.retainedCueCount == 0)
    playback.releaseSubtitleFocusSession(first)

    let second = try #require(playback.beginSubtitleFocusSession(
        openSnapshot: focusOpenSnapshot(wasPlaying: false)
    ))
    #expect(second.token.sessionGeneration == firstToken.sessionGeneration + 1)
    #expect(second.selectedModule == .current)
    #expect(second.availableModules == PlaybackOverlayModule.standardModules)
    #expect(!first.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: firstToken
    ))
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
    #expect(session.commitNativeReelSelection(ordinal: 19))
    #expect(session.currentSnapshot?.selectedOrdinal == 19)
    #expect(session.currentSnapshot?.selectedCue == complete.cues[19])
}

@MainActor
@Test
func subtitleFocusCompleteBatchPreservesPendingNavigationAndKeyboardAction() throws {
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
    #expect(session.requestKeyboardAction(.shiori) == .deferred)

    #expect(session.publishCompleteCueBatch(
        SubtitleFocusCueBatch(totalCount: 20, cues: focusCues(0..<20)),
        token: session.token
    ))

    #expect(session.currentSnapshot?.selectedOrdinal == 12)
    #expect(session.keyboardNavigationRequest == request)
    #expect(session.pendingKeyboardAction == .shiori)
    #expect(!session.allowsNativeWheelInput())
    #expect(session.commitKeyboardNavigation(request))
    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
    session.noteCueReelMotion(false)
    let execution = try #require(session.consumeDeferredKeyboardActionIfReady())
    #expect(execution.action == .shiori)
    #expect(execution.context.cue.ordinal == 13)
    #expect(execution.context.cue == session.currentSnapshot?.selectedCue)
    #expect(session.pendingKeyboardAction == nil)
    #expect(session.activeKeyboardAction == execution)
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
    #expect(session.finishKeyboardAction(execution))
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
        cueGroupID: 1_013,
        ordinal: 12,
        eventIndex: 12,
        displayOrder: 0,
        startMilliseconds: 12_000,
        endMilliseconds: 12_900,
        content: "changed cue"
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
func subtitleFocusSessionNavigatesOnlyThroughReelSelection() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: true),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    #expect(session.commitNativeReelSelection(ordinal: 13))
    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(session.commitNativeReelSelection(ordinal: 9))
    #expect(session.currentSnapshot?.selectedOrdinal == 9)
    #expect(!session.commitNativeReelSelection(ordinal: 5))
    #expect(session.currentSnapshot?.selectedOrdinal == 9)
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
func subtitleFocusSessionCloseClearsKeyboardActionsAndRejectsNavigation() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: true),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    session.noteCueReelMotion(true)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)
    #expect(session.pendingKeyboardAction == .copyCueText)

    #expect(session.dismissByUser() == true)
    #expect(session.pendingKeyboardAction == nil)
    #expect(session.activeKeyboardAction == nil)
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
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
func subtitleFocusImmediateKeyboardActionFreezesNavigationUntilFinished() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))

    guard case .ready(let execution) = session.requestKeyboardAction(.shiori) else {
        Issue.record("Expected the idle keyboard action to be ready")
        return
    }
    #expect(execution.action == .shiori)
    #expect(execution.context.cue.ordinal == 12)
    #expect(execution.generation == 1)
    #expect(session.activeKeyboardAction == execution)
    #expect(session.requestKeyboardAction(.copyCueText) == .rejected)
    #expect(!session.requestKeyboardNavigation(.forward))
    #expect(!session.commitNativeReelSelection(ordinal: 13))
    #expect(!session.allowsNativeWheelInput())
    #expect(!session.allowsNativeScrollbarInput())

    #expect(session.finishKeyboardAction(execution))
    #expect(session.activeKeyboardAction == nil)
    #expect(session.currentSnapshot?.selectedOrdinal == 12)
    #expect(session.state != .closed)
    #expect(session.requestKeyboardNavigation(.forward))
}

@MainActor
@Test
func subtitleFocusNativeWheelCommitsBeforeDeferredActionExecutesOnce() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    session.noteCueReelMotion(true)
    #expect(session.requestKeyboardAction(.copyCueText) == .deferred)
    #expect(session.pendingKeyboardAction == .copyCueText)
    #expect(!session.allowsNativeWheelInput())
    #expect(!session.requestKeyboardNavigation(.forward))

    #expect(session.commitNativeReelSelection(ordinal: 13))
    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
    session.noteCueReelMotion(false)
    let execution = try #require(session.consumeDeferredKeyboardActionIfReady())
    #expect(execution.action == .copyCueText)
    #expect(execution.context.cue.ordinal == 13)
    #expect(session.pendingKeyboardAction == nil)
    #expect(session.activeKeyboardAction == execution)
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
    #expect(session.finishKeyboardAction(execution))
}

@MainActor
@Test
func subtitleFocusScrollbarSettlesBeforeDeferredPlayClosesSession() throws {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: focusOpenSnapshot(wasPlaying: true),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(
        focusPresentationSnapshot(),
        token: session.token
    ))
    session.noteScrollbarDragging(true)
    session.noteCueReelMotion(true)
    #expect(session.requestKeyboardAction(.playFromThisCue) == .deferred)

    #expect(session.commitNativeReelSelection(ordinal: 14))
    session.noteScrollbarDragging(false)
    #expect(session.consumeDeferredKeyboardActionIfReady() == nil)
    session.noteCueReelMotion(false)
    let execution = try #require(session.consumeDeferredKeyboardActionIfReady())
    #expect(execution.action == .playFromThisCue)
    #expect(execution.context.cue.ordinal == 14)
    #expect(!session.closeAfterPlay(PlaybackSubtitleFocusActionExecution(
        action: .copyCueText,
        context: execution.context,
        generation: execution.generation
    )))
    #expect(session.closeAfterPlay(execution))
    #expect(session.state == .closed)
    #expect(session.pendingKeyboardAction == nil)
    #expect(session.activeKeyboardAction == nil)
    #expect(session.retainedCueCount == 0)
    #expect(!session.finishKeyboardAction(execution))
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

@MainActor
func publishPlaybackOverlayInitialTestSnapshot(
    _ session: PlaybackSubtitleFocusSessionStore
) -> Bool {
    let cue = SubtitleFocusCue(
        id: 1,
        cueGroupID: 1,
        ordinal: 0,
        eventIndex: 0,
        displayOrder: 0,
        startMilliseconds: 0,
        endMilliseconds: 1_000,
        content: "current"
    )
    return session.publishInitialSnapshot(
        SubtitleFocusSnapshot(
            totalCount: 1,
            selectedOrdinal: 0,
            cues: [cue]
        ),
        token: session.token
    )
}

private func focusPresentationSnapshot() -> SubtitleFocusSnapshot {
    SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: focusCues(6..<16)
    )
}

private func focusCues(_ range: Range<Int>) -> [SubtitleFocusCue] {
    range.map { ordinal in
        SubtitleFocusCue(
            id: Int64(ordinal + 1),
            cueGroupID: Int64(ordinal + 1_001),
            ordinal: ordinal,
            eventIndex: ordinal,
            displayOrder: 0,
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            content: "cue \(ordinal)"
        )
    }
}
