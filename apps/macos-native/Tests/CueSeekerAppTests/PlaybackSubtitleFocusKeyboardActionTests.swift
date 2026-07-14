import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@Test
func subtitleFocusClipboardWritesExactCueText() throws {
    let pasteboard = NSPasteboard(name: .init("SubtitleFocus-\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    let text = "  first line  \n\nthird line"

    #expect(PlaybackSubtitleFocusClipboard.copy(text, to: pasteboard))
    #expect(pasteboard.string(forType: .string) == text)
    #expect(!PlaybackSubtitleFocusClipboard.copy("", to: pasteboard))
}

@Test
func subtitleFocusActionContextPreservesExactCueIdentityAndContent() {
    let cue = SubtitleFocusCue(
        id: 42,
        cueGroupID: 7,
        ordinal: 6,
        eventIndex: 123,
        displayOrder: 2,
        startMilliseconds: 1_234,
        endMilliseconds: 2_345,
        content: "  first line  \n\nthird line"
    )
    let context = keyboardActionContext(cue: cue)

    #expect(context.cueTextSelection.cueGroupID == 7)
    #expect(context.cueTextSelection.cueLineID == 42)
    #expect(context.cueTextSelection.cueEventIndex == 123)
    #expect(context.cueTextSelection.cueDisplayOrder == 2)
    #expect(context.cueTextSelection.startMilliseconds == 1_234)
    #expect(context.cueTextSelection.endMilliseconds == 2_345)
    #expect(context.cueTextSelection.lines == ["  first line  ", "", "third line"])
    #expect(context.cueTextSelection.text == "  first line  \n\nthird line")
}

@MainActor
@Test
func playbackOverlayEnterQueuesPlayWhileSpaceRemainsInactive() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        session.noteCueReelMotion(true)

        #expect(app.handlePlaybackKeyDown(keyCode: 49, modifierFlagsRawValue: 0))
        #expect(session.pendingKeyboardAction == nil)

        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(session.pendingKeyboardAction == .playFromThisCue)
        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.pendingKeyboardAction == .playFromThisCue)
        #expect(session.activeKeyboardAction == nil)
        #expect(session.currentSnapshot?.selectedOrdinal == 12)
        #expect(app.playback.playbackViewModel?.feedback == nil)
    }
}

@MainActor
@Test
func playbackOverlayTabCyclesModulesAndIgnoresKeyRepeat() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))

        #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
        #expect(session.selectedModule == .search)
        #expect(app.handlePlaybackKeyDown(
            keyCode: 48,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(session.selectedModule == .search)

        #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
        #expect(session.selectedModule == .recent)
        #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
        #expect(session.selectedModule == .library)
        #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
        #expect(session.selectedModule == .shiori)
        #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
        #expect(session.selectedModule == .current)
    }
}

@MainActor
@Test
func subtitleFocusCopyKeyCopiesExactCueAndKeepsPausedSession() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: true)
        ))
        let snapshot = keyboardActionSnapshot(
            lines: ["  exact first  ", "", "exact third"]
        )
        #expect(session.publishInitialSnapshot(snapshot, token: session.token))
        NSPasteboard.general.clearContents()

        #expect(app.handlePlaybackKeyDown(keyCode: 8, modifierFlagsRawValue: 0))
        #expect(NSPasteboard.general.string(forType: .string) == "  exact first  \n\nexact third")
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.activeKeyboardAction == nil)
        #expect(session.currentSnapshot?.selectedOrdinal == 12)
        #expect(app.playback.playbackStatus == .paused)
        #expect(app.playback.playbackViewModel?.feedback?.text == "Subtitle Copied")

        #expect(app.handlePlaybackKeyDown(
            keyCode: 8,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(session.activeKeyboardAction == nil)
    }
}

@MainActor
@Test
func subtitleFocusShioriKeySavesIdempotentlyAndKeepsPausedSession() async throws {
    try await withKeyboardActionApp { app, database in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: true)
        ))
        let snapshot = keyboardActionSnapshot(
            lines: ["  exact first  ", "", "exact third"]
        )
        #expect(session.publishInitialSnapshot(snapshot, token: session.token))
        let tableRevisionBefore = app.shiori.tableDataRevision

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text == "Shiori Saved"
        }

        let saved = try #require(try database.shiori(
            subtitleFile: URL(fileURLWithPath: keyboardActionSource().subtitlePath),
            startMilliseconds: 12_000,
            endMilliseconds: 12_900
        ))
        #expect(saved.content == "  exact first  \n\nexact third")
        #expect(try database.shioriCount() == 1)
        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 1)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.currentSnapshot?.selectedOrdinal == 12)
        #expect(app.playback.playbackStatus == .paused)

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text
                    == "Shiori Already Saved"
        }

        #expect(try database.shioriCount() == 1)
        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 1)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(app.playback.playbackStatus == .paused)
    }
}

@MainActor
@Test
func subtitleFocusShioriIdentityDistinguishesSameTimeSiblingCues() async throws {
    try await withKeyboardActionApp { app, database in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        var cues = (6..<16).map { keyboardActionCue(ordinal: $0) }
        let firstCue = keyboardActionSiblingCue(
            id: 501,
            ordinal: 12,
            eventIndex: 120,
            displayOrder: 0,
            content: "same-time first"
        )
        let secondCue = keyboardActionSiblingCue(
            id: 502,
            ordinal: 13,
            eventIndex: 121,
            displayOrder: 1,
            content: "same-time second"
        )
        cues[6] = firstCue
        cues[7] = secondCue
        let snapshot = SubtitleFocusSnapshot(
            totalCount: 20,
            selectedOrdinal: 12,
            cues: cues
        )
        #expect(session.publishInitialSnapshot(snapshot, token: session.token))
        let tableRevisionBefore = app.shiori.tableDataRevision

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.shiori.tableDataRevision == tableRevisionBefore + 1
        }
        #expect(session.commitNativeReelSelection(ordinal: 13))

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.shiori.tableDataRevision == tableRevisionBefore + 2
        }

        let subtitleFile = URL(fileURLWithPath: keyboardActionSource().subtitlePath)
        let savedFirst = try #require(try database.shiori(
            subtitleFile: subtitleFile,
            cueIdentity: firstCue.cueIdentity
        ))
        let savedSecond = try #require(try database.shiori(
            subtitleFile: subtitleFile,
            cueIdentity: secondCue.cueIdentity
        ))
        #expect(savedFirst.id != savedSecond.id)
        #expect(savedFirst.content == "same-time first")
        #expect(savedSecond.content == "same-time second")
        #expect(try database.shioriCount() == 2)

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text
                    == "Shiori Already Saved"
        }
        #expect(try database.shioriCount() == 2)
        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 2)
        #expect(session.currentSnapshot?.selectedCue == secondCue)
        #expect(app.playback.playbackStatus == .paused)
    }
}

@MainActor
@Test
func subtitleFocusDownThenShioriSavesTheFinalSettledCue() async throws {
    try await withKeyboardActionApp { app, database in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))

        #expect(session.requestKeyboardNavigation(.forward))
        let navigation = try #require(session.keyboardNavigationRequest)
        #expect(session.requestKeyboardAction(.shiori) == .deferred)
        session.noteCueReelMotion(true)
        #expect(session.commitKeyboardNavigation(navigation))
        session.noteCueReelMotion(false)
        let execution = try #require(
            session.consumeDeferredKeyboardActionIfReady()
        )

        #expect(execution.context.cue.ordinal == 13)
        #expect(app.executePlaybackSubtitleFocusAction(execution))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text == "Shiori Saved"
        }

        #expect(try database.shiori(
            subtitleFile: URL(fileURLWithPath: keyboardActionSource().subtitlePath),
            startMilliseconds: 12_000,
            endMilliseconds: 12_900
        ) == nil)
        let saved = try #require(try database.shiori(
            subtitleFile: URL(fileURLWithPath: keyboardActionSource().subtitlePath),
            startMilliseconds: 13_000,
            endMilliseconds: 13_900
        ))
        #expect(saved.content == "keyboard action cue 13")
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.currentSnapshot?.selectedOrdinal == 13)
        #expect(app.playback.playbackStatus == .paused)
    }
}

@MainActor
@Test
func playbackOverlayPlayActionUsesExactCueThenDestroysSession() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        let execution: PlaybackSubtitleFocusActionExecution
        switch session.requestKeyboardAction(.playFromThisCue) {
        case .ready(let readyExecution):
            execution = readyExecution
        case .deferred, .rejected:
            Issue.record("Expected an immediately ready play action")
            return
        }
        var receivedContext: PlaybackSubtitleFocusActionContext?

        #expect(app.executePlaybackSubtitleFocusAction(
            execution,
            continuousPlay: { context in
                receivedContext = context
                return true
            }
        ))

        #expect(receivedContext == execution.context)
        #expect(receivedContext?.cue.startMilliseconds == 12_000)
        #expect(app.playback.subtitleFocusSession == nil)
        #expect(session.state == .closed)
        #expect(app.playback.playbackStatus == .playing)
        #expect(app.playback.playbackViewModel?.feedback?.text == "Play")
    }
}

@MainActor
@Test
func subtitleFocusCommittedShioriInvalidatesRowsAfterActionIsSuperseded() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        let execution: PlaybackSubtitleFocusActionExecution
        switch session.requestKeyboardAction(.shiori) {
        case .ready(let readyExecution):
            execution = readyExecution
        case .deferred, .rejected:
            Issue.record("Expected an immediately ready Shiori action")
            return
        }
        let tableRevisionBefore = app.shiori.tableDataRevision

        app.finishPlaybackSubtitleFocusShioriSave(
            .saved,
            execution,
            session: session,
            taskGeneration: .min
        )

        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 1)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.activeKeyboardAction == execution)
        #expect(app.playback.playbackViewModel?.feedback == nil)
    }
}

@MainActor
private func withKeyboardActionApp(
    _ body: (AppCoordinator, SubtitleDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerSubtitleFocusKeyboardActionTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerSubtitleFocusKeyboardActionTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("keyboard-actions.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.subtitleDatabase)
    let source = keyboardActionSource()
    app.search.selectedSearchResult = SubtitleSearchResult(
        entryID: 1,
        subtitlePath: source.subtitlePath,
        subtitleFormat: source.subtitleFormat,
        videoPath: source.videoPath,
        videoName: "Keyboard Action Video",
        startMilliseconds: 12_000,
        endMilliseconds: 12_900,
        content: "selected cue",
        cueLines: ["selected cue"]
    )
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused
    try await body(app, database)
}

@MainActor
private func waitForKeyboardActionState(
    timeout: TimeInterval = 3,
    condition: () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else {
            throw PlaybackSubtitleFocusKeyboardActionTestError.timedOut
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

private enum PlaybackSubtitleFocusKeyboardActionTestError: Error {
    case timedOut
}

private func keyboardActionOpenSnapshot(
    wasPlaying: Bool
) -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: keyboardActionSource(),
        timestampMilliseconds: 12_500,
        wasPlaying: wasPlaying
    )
}

private func keyboardActionSource() -> SubtitleFocusSourceIdentity {
    SubtitleFocusSourceIdentity(
        videoPath: "/Media/Keyboard-Actions.mkv",
        subtitlePath: "/Media/Keyboard-Actions.srt",
        subtitleFormat: .srt
    )
}

private func keyboardActionSnapshot(
    lines: [String]? = nil
) -> SubtitleFocusSnapshot {
    SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: (6..<16).map { ordinal in
            keyboardActionCue(
                ordinal: ordinal,
                lines: ordinal == 12 ? lines : nil
            )
        }
    )
}

private func keyboardActionCue(
    ordinal: Int,
    lines: [String]? = nil
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: Int64(ordinal + 1),
        cueGroupID: Int64(ordinal + 1_001),
        ordinal: ordinal,
        eventIndex: ordinal,
        displayOrder: 0,
        startMilliseconds: ordinal * 1_000,
        endMilliseconds: ordinal * 1_000 + 900,
        content: lines?.joined(separator: "\n") ?? "keyboard action cue \(ordinal)"
    )
}

private func keyboardActionSiblingCue(
    id: Int64,
    ordinal: Int,
    eventIndex: Int,
    displayOrder: Int,
    content: String
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: id,
        cueGroupID: 500,
        ordinal: ordinal,
        eventIndex: eventIndex,
        displayOrder: displayOrder,
        startMilliseconds: 12_000,
        endMilliseconds: 12_900,
        content: content
    )
}

private func keyboardActionContext(
    cue: SubtitleFocusCue
) -> PlaybackSubtitleFocusActionContext {
    PlaybackSubtitleFocusActionContext(
        source: keyboardActionSource(),
        cue: cue
    )
}
