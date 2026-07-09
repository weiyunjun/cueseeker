import AppKit
import Combine
import CueSeekerCore
import Foundation
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
