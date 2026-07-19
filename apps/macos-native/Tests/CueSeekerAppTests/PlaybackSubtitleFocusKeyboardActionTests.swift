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
func subtitleFocusClipboardWritesPlainMarkdownCueLinkOnly() throws {
    let pasteboard = NSPasteboard(
        name: .init("SubtitleFocus-Markdown-\(UUID().uuidString)")
    )
    defer { pasteboard.releaseGlobally() }
    let cueText = "  first line  \n\nthird line"

    #expect(PlaybackSubtitleFocusClipboard.copyMarkdownLink(
        cueText: cueText,
        cueID: 42,
        to: pasteboard
    ))
    #expect(
        pasteboard.string(forType: .string)
            == "[  first line  \n\nthird line](cueseeker://cue?id=42)"
    )
    #expect(pasteboard.data(forType: .html) == nil)
    #expect(pasteboard.data(forType: .rtf) == nil)
    #expect(!PlaybackSubtitleFocusClipboard.copyMarkdownLink(
        cueText: cueText,
        cueID: 0,
        to: pasteboard
    ))
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

        #expect(app.handlePlaybackKeyDown(keyCode: 7, modifierFlagsRawValue: 0))
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "[  exact first  \n\nexact third](cueseeker://cue?id=13)"
        )
        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "Subtitle(markdown format) Copied"
        )

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
            id: 13,
            ordinal: 12,
            eventIndex: 120,
            displayOrder: 0,
            content: "same-time first"
        )
        let secondCue = keyboardActionSiblingCue(
            id: 14,
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

        let savedFirst = try #require(try database.shiori(cueID: firstCue.id))
        let savedSecond = try #require(try database.shiori(cueID: secondCue.id))
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
func playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue() async throws {
    try await withKeyboardActionApp { app, database in
        let result = keyboardActionPlaylistSearchResult(
            id: 22,
            videoPath: keyboardActionSource().videoPath,
            subtitlePath: keyboardActionSource().subtitlePath,
            startMilliseconds: 21_000,
            content: "  playlist first  \n\nplaylist third"
        )
        let item = PlaybackPlaylistItem(searchResult: result, ordinal: 0)
        let (session, window) = try await beginKeyboardActionPlaylistSession(
            app: app,
            item: item
        )
        NSPasteboard.general.clearContents()

        #expect(app.handlePlaybackKeyDown(keyCode: 8, modifierFlagsRawValue: 0))
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "  playlist first  \n\nplaylist third"
        )
        #expect(app.playback.playbackViewModel?.feedback?.text == "Subtitle Copied")

        #expect(app.handlePlaybackKeyDown(keyCode: 7, modifierFlagsRawValue: 0))
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "[  playlist first  \n\nplaylist third](cueseeker://cue?id=22)"
        )
        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "Subtitle(markdown format) Copied"
        )
        #expect(app.playback.subtitleFocusSession === session)
        #expect(window.selectedOrdinal == 0)

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text == "Shiori Saved"
        }
        let saved = try #require(try database.shiori(
            subtitleFile: URL(fileURLWithPath: result.subtitlePath),
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds
        ))

        #expect(saved.content == result.content)
        #expect(saved.videoName == result.videoName)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(window.selectedOrdinal == 0)
        #expect(app.playback.playbackStatus == .paused)

        session.noteCueReelMotion(true)
        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(session.pendingKeyboardAction == .playFromThisCue)
    }
}

@MainActor
@Test
func playbackOverlaySearchDoesNotCopyMarkdownCueLink() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false),
            searchStore: app.search
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        #expect(session.selectModule(.search))
        NSPasteboard.general.clearContents()
        #expect(NSPasteboard.general.setString("unchanged", forType: .string))

        #expect(app.handlePlaybackKeyDown(keyCode: 7, modifierFlagsRawValue: 0))
        #expect(NSPasteboard.general.string(forType: .string) == "unchanged")
        #expect(session.activeKeyboardAction == nil)
        #expect(app.playback.playbackViewModel?.feedback == nil)
    }
}

@MainActor
@Test
func playbackPlaylistShioriItemReportsAlreadySavedWithoutCreatingAnotherRow() async throws {
    try await withKeyboardActionApp { app, database in
        let shiori = Shiori(
            id: 801,
            subtitlePath: "/subtitle/playlist-shiori.ass",
            subtitleFormat: .ass,
            videoPath: "/video/playlist-shiori.mkv",
            videoName: "playlist-shiori.mkv",
            startMilliseconds: 31_000,
            endMilliseconds: 31_900,
            content: "existing playlist shiori",
            isValid: true,
            createdAt: "2026-07-15T00:00:00Z"
        )
        let item = PlaybackPlaylistItem(
            shiori: shiori,
            cuePresentation: nil,
            ordinal: 0
        )
        let (session, window) = try await beginKeyboardActionPlaylistSession(
            app: app,
            item: item
        )

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))

        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "Shiori Already Saved"
        )
        #expect(try database.shioriCount() == 0)
        #expect(session.activeKeyboardAction == nil)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(window.selectedOrdinal == 0)
    }
}

@MainActor
@Test
func playbackPlaylistEnterDispatchesSelectedTargetAndDestroysOverlaySession() async throws {
    try await withKeyboardActionApp { app, _ in
        let result = keyboardActionPlaylistSearchResult(
            id: 901,
            videoPath: "/video/playlist-target.mkv",
            subtitlePath: "/subtitle/playlist-target.ass",
            startMilliseconds: 41_000,
            content: "playlist play target"
        )
        let item = PlaybackPlaylistItem(searchResult: result, ordinal: 0)
        let (session, _) = try await beginKeyboardActionPlaylistSession(
            app: app,
            item: item
        )

        let execution: PlaybackSubtitleFocusActionExecution
        switch session.requestKeyboardAction(.playFromThisCue) {
        case .ready(let readyExecution):
            execution = readyExecution
        case .deferred, .rejected:
            Issue.record("Expected an immediately ready Playlist play action")
            return
        }
        var openedItem: PlaybackPlaylistItem?

        #expect(app.executePlaybackSubtitleFocusAction(
            execution,
            playCurrentCue: { _ in false },
            openPlaylistItem: { openedItem = $0 }
        ))

        #expect(app.playback.subtitleFocusSession == nil)
        #expect(session.state == .closed)
        #expect(openedItem == item)
        #expect(app.playback.playbackViewModel?.feedback?.text == "Play")
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

        let didExecute = app.executePlaybackSubtitleFocusAction(
            execution,
            playCurrentCue: { context in
                #expect(app.playback.subtitleFocusSession == nil)
                #expect(session.state == .closed)
                #expect(!session.isActive)
                receivedContext = context
                app.settings.autoPauseAfterCueFinishesEnabled = true
                app.beginCueAutoStopPlayback()
                app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
                    startMilliseconds: context.cue.startMilliseconds,
                    endMilliseconds: context.cue.endMilliseconds
                ))
                return true
            }
        )

        #expect(didExecute)
        #expect(receivedContext == execution.context)
        #expect(receivedContext?.cue.startMilliseconds == 12_000)
        #expect(app.activePlaylistCueSettings?.autoPauseEnabled == true)
        #expect(app.activeCueAutoPauseBoundary?.endMilliseconds == 12_900)
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
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: source.subtitlePath),
        videoFile: URL(fileURLWithPath: source.videoPath),
        entries: (0..<30).map { ordinal in
            let startMilliseconds = ordinal == 13 ? 12_000 : ordinal * 1_000
            return SubtitleEntry(
                sequenceNumber: ordinal + 1,
                startTimecode: "\(startMilliseconds)",
                endTimecode: "\(startMilliseconds + 900)",
                startMilliseconds: startMilliseconds,
                endMilliseconds: startMilliseconds + 900,
                text: "keyboard action cue \(ordinal)"
            )
        }
    )
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
private func beginKeyboardActionPlaylistSession(
    app: AppCoordinator,
    item: PlaybackPlaylistItem
) async throws -> (
    PlaybackSubtitleFocusSessionStore,
    PlaybackPlaylistSessionWindowStore
) {
    let source = PlaybackPlaylistSource(
        kind: item.target.playbackPlaylistSourceKind,
        totalCount: 1
    ) { ordinal in
        ordinal == 0 ? item : nil
    }
    app.playback.setPlaylistSource(source)
    let session = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
    ))
    #expect(session.publishInitialSnapshot(
        keyboardActionSnapshot(),
        token: session.token
    ))
    let window = try #require(session.playlistWindow)
    #expect(window.snapshot.loadedItemCount == 1)
    #expect(session.selectModule(.playlist))
    return (session, window)
}

private func keyboardActionPlaylistSearchResult(
    id: Int64,
    videoPath: String,
    subtitlePath: String,
    startMilliseconds: Int,
    content: String
) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        cueGroupID: id + 1,
        cueEventIndex: Int(id),
        cueDisplayOrder: 0,
        primaryGroupIndex: 0,
        subtitlePath: subtitlePath,
        subtitleFormat: .ass,
        videoPath: videoPath,
        videoName: URL(fileURLWithPath: videoPath).lastPathComponent,
        startMilliseconds: startMilliseconds,
        endMilliseconds: startMilliseconds + 900,
        content: content,
        cueLines: [content],
        cueGroupLines: [content],
        searchRank: 0
    )
}

private extension PlaybackPlaylistItemTarget {
    var playbackPlaylistSourceKind: PlaybackPlaylistSourceKind {
        switch self {
        case .search:
            .search
        case .shiori:
            .shiori
        }
    }
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
