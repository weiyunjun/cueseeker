import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@Test
func subtitleFocusActionMenuMetricsMatchPlayerSpeedMenuGeometry() {
    #expect(PlaybackSubtitleFocusActionMenuMetrics.width == 172)
    #expect(PlaybackSubtitleFocusActionMenuMetrics.height == 106)
    #expect(PlaybackSubtitleFocusActionMenuMetrics.itemHeight == 30)
    #expect(PlaybackSubtitleFocusActionMenuMetrics.padding == 6)
    #expect(PlaybackSubtitleFocusActionMenuMetrics.itemVerticalGap == 2)
    #expect(PlaybackSubtitleFocusActionMenuMetrics.iconSize == 16)
    #expect(PlaybackSubtitleFocusActionMenuMetrics.iconTextGap == 8)
    #expect(PlaybackSubtitleFocusActionMenuMetrics.cueGap == 12)
}

@MainActor
@Test
func subtitleFocusActionMenuUsesDocumentedIntrinsicSize() {
    _ = NSApplication.shared
    let menu = PlaybackSubtitleFocusActionMenu(
        state: PlaybackSubtitleFocusActionMenuState(
            context: actionContext(cue: actionCue(ordinal: 6)),
            shioriAvailability: .alreadySaved,
            generation: 1
        ),
        onHover: { _ in },
        onExecute: { _ in }
    )
    let hostingView = NSHostingView(rootView: menu)
    hostingView.layoutSubtreeIfNeeded()

    #expect(hostingView.fittingSize.width == 172)
    #expect(hostingView.fittingSize.height == 106)
}

@Test
func subtitleFocusActionMenuPlacementPrefersBelowThenFlipsAndClamps() {
    let bounds = CGRect(x: 0, y: 0, width: 1_280, height: 720)

    #expect(PlaybackSubtitleFocusActionMenuPlacement.origin(
        cueFrame: CGRect(x: 100, y: 100, width: 960, height: 104),
        overlayBounds: bounds
    ) == CGPoint(x: 100, y: 216))

    #expect(PlaybackSubtitleFocusActionMenuPlacement.origin(
        cueFrame: CGRect(x: 100, y: 620, width: 960, height: 104),
        overlayBounds: bounds
    ) == CGPoint(x: 100, y: 502))

    #expect(PlaybackSubtitleFocusActionMenuPlacement.origin(
        cueFrame: CGRect(x: 1_200, y: 100, width: 960, height: 104),
        overlayBounds: bounds
    ).x == 1_108)

    #expect(PlaybackSubtitleFocusActionMenuPlacement.origin(
        cueFrame: CGRect(x: -20, y: 10, width: 200, height: 104),
        overlayBounds: CGRect(x: 0, y: 0, width: 140, height: 80)
    ) == .zero)
}

@Test
func subtitleFocusActionMenuSelectsAndNavigatesOnlyEnabledItems() {
    let context = actionContext(cue: actionCue(ordinal: 6))
    var checking = PlaybackSubtitleFocusActionMenuState(
        context: context,
        generation: 0
    )
    #expect(checking.shioriAvailability == .checking)
    #expect(checking.selectedAction == .copyCueText)
    #expect(!checking.isAvailable(.shiori))
    let resolvedAvailable = checking.resolveShioriAvailability(.available)
    #expect(resolvedAvailable)
    #expect(checking.selectedAction == .shiori)

    var available = PlaybackSubtitleFocusActionMenuState(
        context: context,
        shioriAvailability: .available,
        generation: 1
    )
    #expect(available.selectedAction == .shiori)
    #expect(available.label(for: .shiori) == "Shiori")
    #expect(available.systemImage(for: .shiori) == "bookmark")
    let movedToCopy = available.moveSelection(.forward)
    #expect(movedToCopy)
    #expect(available.selectedAction == .copyCueText)
    let movedToPlay = available.moveSelection(.forward)
    #expect(movedToPlay)
    #expect(available.selectedAction == .playFromThisCue)
    let movedPastEnd = available.moveSelection(.forward)
    #expect(!movedPastEnd)
    let movedBackToCopy = available.moveSelection(.backward)
    #expect(movedBackToCopy)
    #expect(available.selectedAction == .copyCueText)

    var saved = PlaybackSubtitleFocusActionMenuState(
        context: context,
        shioriAvailability: .alreadySaved,
        generation: 2
    )
    #expect(saved.selectedAction == .copyCueText)
    #expect(saved.label(for: .shiori) == "Shiori Already Saved")
    #expect(saved.systemImage(for: .shiori) == "bookmark.fill")
    #expect(!saved.isAvailable(.shiori))
    let selectedDisabledShiori = saved.select(.shiori)
    #expect(!selectedDisabledShiori)
    let movedBeforeFirstEnabled = saved.moveSelection(.backward)
    #expect(!movedBeforeFirstEnabled)
    let movedToSavedPlay = saved.moveSelection(.forward)
    #expect(movedToSavedPlay)
    #expect(saved.selectedAction == .playFromThisCue)
}

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
func subtitleFocusActionContextPreservesExactCueGroupData() {
    let cue = SubtitleFocusCue(
        id: 42,
        ordinal: 6,
        startMilliseconds: 1_234,
        endMilliseconds: 2_345,
        lines: ["  first line  ", "", "third line"]
    )
    let context = actionContext(cue: cue)

    #expect(context.cueTextSelection.cueGroupID == 42)
    #expect(context.cueTextSelection.startMilliseconds == 1_234)
    #expect(context.cueTextSelection.endMilliseconds == 2_345)
    #expect(context.cueTextSelection.lines == ["  first line  ", "", "third line"])
    #expect(context.cueTextSelection.text == "  first line  \n\nthird line")
}

@MainActor
@Test
func subtitleFocusSessionMenuPreservesCueAndGatesExecution() throws {
    let session = actionSession()
    let originalSnapshot = try #require(session.currentSnapshot)

    let cue = try #require(session.actionMenuCandidateForKeyboard())
    #expect(session.openActionMenuFromKeyboard(for: cue))
    let lookup = try #require(session.actionMenuShioriLookupRequest)
    #expect(session.resolveActionMenuShioriAvailability(.available, request: lookup))
    #expect(session.currentSnapshot == originalSnapshot)
    #expect(session.focusAnchorY == nil)
    #expect(session.actionMenuState?.context.cue == cue)
    #expect(!session.moveSelection(.forward))
    #expect(!session.requestKeyboardNavigation(.forward))

    #expect(session.moveActionMenuSelection(.forward))
    #expect(session.actionMenuState?.selectedAction == .copyCueText)
    #expect(session.hoverActionMenuItem(.playFromThisCue))
    #expect(session.actionMenuState?.selectedAction == .playFromThisCue)

    let execution = try #require(session.beginActionMenuExecution())
    #expect(execution.action == .playFromThisCue)
    #expect(session.beginActionMenuExecution() == nil)
    #expect(!session.dismissActionMenu())
    #expect(session.failActionMenuExecution(menuGeneration: execution.menuGeneration))
    #expect(!session.actionMenuState!.isPerforming)

    let retry = try #require(session.beginActionMenuExecution(action: .copyCueText))
    #expect(session.completeActionMenuExecution(menuGeneration: retry.menuGeneration) == false)
    #expect(session.state == .closed)
    #expect(session.retainedCueCount == 0)
}

@MainActor
@Test
func subtitleFocusPointerMenuSupersedesQueuedKeyboardNavigation() throws {
    let session = actionSession()
    #expect(session.requestKeyboardNavigation(.forward))
    let clickedCue = try #require(session.currentSnapshot?.cues.first {
        $0.ordinal == 9
    })

    #expect(session.openActionMenuFromPointer(
        for: clickedCue,
        focusAnchorY: 224
    ))

    #expect(session.currentSnapshot?.selectedOrdinal == 9)
    #expect(session.focusAnchorY == 224)
    #expect(session.actionMenuState?.context.cue == clickedCue)
    #expect(session.takePendingKeyboardNavigationDirections().isEmpty)
}

@MainActor
@Test
func subtitleFocusDismissedMenuRejectsLateShioriLookup() throws {
    let session = actionSession()
    let cue = try #require(session.actionMenuCandidateForKeyboard())
    #expect(session.openActionMenuFromKeyboard(for: cue))
    let request = try #require(session.actionMenuShioriLookupRequest)

    #expect(session.dismissActionMenu())
    #expect(!session.resolveActionMenuShioriAvailability(
        .alreadySaved,
        request: request
    ))
    #expect(session.actionMenuState == nil)
}

@MainActor
@Test
func subtitleFocusMenuOpeningHonorsLoadingDragWheelAndPendingBlockers() throws {
    let pendingSession = actionSession()
    #expect(pendingSession.requestKeyboardNavigation(.forward))
    #expect(pendingSession.actionMenuCandidateForKeyboard() == nil)
    _ = pendingSession.takePendingKeyboardNavigationDirections()
    #expect(pendingSession.actionMenuCandidateForKeyboard() != nil)

    pendingSession.noteScrollbarDragging(true)
    #expect(pendingSession.actionMenuCandidateForKeyboard() == nil)
    pendingSession.noteScrollbarDragging(false)
    pendingSession.noteCueReelMotion(true)
    #expect(pendingSession.actionMenuCandidateForKeyboard() == nil)
    pendingSession.noteCueReelMotion(false)
    #expect(pendingSession.actionMenuCandidateForKeyboard() != nil)

    let loadingSession = actionSession()
    loadingSession.noteScrollbarPreviewChanged(ordinal: 18)
    #expect(loadingSession.isTargetWindowLoading)
    #expect(loadingSession.actionMenuCandidateForKeyboard() == nil)
}

@MainActor
@Test
func subtitleFocusDeferredMenuOwnsNavigationUntilOpenedOrCancelled() throws {
    let session = actionSession()
    #expect(session.requestKeyboardNavigation(.forward))
    #expect(session.deferActionMenuOpenUntilNavigationCompletes())
    #expect(session.isActionMenuOpening)

    #expect(!session.requestKeyboardNavigation(.forward))
    #expect(!session.commitCachedScrollbarTarget(ordinal: 13))
    #expect(!session.selectCue(ordinal: 13, focusAnchorY: 224))
    session.noteScrollbarPreviewChanged(ordinal: 18)
    #expect(!session.isTargetWindowLoading)
    #expect(session.currentSnapshot?.selectedOrdinal == 12)

    #expect(session.cancelDeferredActionMenuOpen())
    #expect(!session.isActionMenuOpening)
    #expect(session.requestKeyboardNavigation(.forward))

    let blockedSession = actionSession()
    blockedSession.noteCueReelMotion(true)
    #expect(blockedSession.deferActionMenuOpenUntilNavigationCompletes())
    #expect(!blockedSession.consumeDeferredActionMenuOpen())
    #expect(!blockedSession.isActionMenuOpening)
    #expect(!blockedSession.consumeDeferredActionMenuOpen())
}

@MainActor
@Test
func subtitleFocusKeyboardEscapeClosesMenuBeforeOverlay() async throws {
    try await withActionMenuApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: actionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(actionSnapshot(), token: session.token))

        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(session.isActionMenuOpen)
        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(session.isActionMenuOpen)

        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(app.playback.subtitleFocusSession === session)
        #expect(!session.isActionMenuOpen)
        #expect(session.currentSnapshot?.selectedOrdinal == 12)

        #expect(app.handlePlaybackKeyDown(
            keyCode: 53,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(app.playback.subtitleFocusSession === session)

        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(app.playback.subtitleFocusSession == nil)
        #expect(session.state == .closed)
    }
}

@MainActor
@Test
func subtitleFocusEscapeCancelsDeferredMenuBeforeClosingOverlay() async throws {
    try await withActionMenuApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: actionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(actionSnapshot(), token: session.token))

        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(session.isActionMenuOpening)

        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(app.playback.subtitleFocusSession === session)
        #expect(!session.isActionMenuOpening)
        #expect(!session.isActionMenuOpen)

        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(app.playback.subtitleFocusSession == nil)
    }
}

@MainActor
@Test
func subtitleFocusDownThenEnterOpensMenuForFinalNavigatedCue() async throws {
    try await withActionMenuApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: actionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(actionSnapshot(), token: session.token))

        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(!session.isActionMenuOpen)
        #expect(session.isActionMenuOpening)

        let hostingView = NSHostingView(
            rootView: PlaybackSubtitleFocusLayer(
                session: session,
                onOpenSelectedActionMenu:
                    app.openPlaybackSubtitleFocusActionMenuFromKeyboard
            )
            .frame(width: 1_280, height: 720)
        )
        hostingView.frame = CGRect(x: 0, y: 0, width: 1_280, height: 720)
        hostingView.layoutSubtreeIfNeeded()

        try await waitForActionMenuState {
            session.actionMenuState?.context.cue.ordinal == 13
        }
        #expect(session.currentSnapshot?.selectedOrdinal == 13)
        #expect(session.actionMenuState?.context.cue.ordinal == 13)
        withExtendedLifetime(hostingView) {}
    }
}

@MainActor
@Test
func subtitleFocusDeferredMenuWaitsWhenOnlyEarlierBatchStepMoves() async throws {
    try await withActionMenuApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: actionOpenSnapshot(wasPlaying: false)
        ))
        let boundarySnapshot = SubtitleFocusSnapshot(
            totalCount: 14,
            selectedOrdinal: 12,
            cues: (6..<14).map { actionCue(ordinal: $0) }
        )
        #expect(session.publishInitialSnapshot(boundarySnapshot, token: session.token))
        #expect(session.requestKeyboardNavigation(.forward))
        #expect(session.requestKeyboardNavigation(.forward))
        #expect(session.deferActionMenuOpenUntilNavigationCompletes())

        let hostingView = NSHostingView(
            rootView: PlaybackSubtitleFocusLayer(
                session: session,
                onOpenSelectedActionMenu:
                    app.openPlaybackSubtitleFocusActionMenuFromKeyboard
            )
            .frame(width: 1_280, height: 720)
        )
        hostingView.frame = CGRect(x: 0, y: 0, width: 1_280, height: 720)
        hostingView.layoutSubtreeIfNeeded()

        try await waitForActionMenuState {
            session.currentSnapshot?.selectedOrdinal == 13
        }
        #expect(session.actionMenuState == nil)
        #expect(session.isActionMenuOpening)
        try await waitForActionMenuState {
            session.actionMenuState?.context.cue.ordinal == 13
        }
        withExtendedLifetime(hostingView) {}
    }
}

@MainActor
@Test
func subtitleFocusShioriActionSavesExactCueWithoutHydratingLegacyPresentation() async throws {
    try await withActionMenuApp { app, database in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: actionOpenSnapshot(wasPlaying: false)
        ))
        let snapshot = actionSnapshot(lines: ["  exact first  ", "", "exact third"])
        #expect(session.publishInitialSnapshot(snapshot, token: session.token))
        let tableRevisionBefore = app.shiori.tableDataRevision

        #expect(app.openPlaybackSubtitleFocusActionMenuFromKeyboard())
        #expect(session.actionMenuState?.shioriAvailability == .checking)
        try await waitForActionMenuState {
            session.actionMenuState?.shioriAvailability == .available
        }
        #expect(session.actionMenuState?.selectedAction == .shiori)
        #expect(app.playback.playbackViewModel?.feedback == nil)
        #expect(app.executePlaybackSubtitleFocusAction(.shiori))
        try await waitForActionMenuState {
            app.playback.subtitleFocusSession == nil
        }

        #expect(app.playback.subtitleFocusSession == nil)
        let saved = try #require(try database.shiori(
            subtitleFile: URL(fileURLWithPath: actionSource().subtitlePath),
            startMilliseconds: 12_000,
            endMilliseconds: 12_900
        ))
        #expect(saved.content == "  exact first  \n\nexact third")
        #expect(try database.shioriCount() == 1)
        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 1)
        #expect(app.shiori.shioris.isEmpty)
        #expect(app.shiori.shioriFileGroups.isEmpty)
        #expect(!app.shiori.tableHasLoadedInitialPage)
        #expect(app.playback.playbackViewModel?.feedback == nil)

        let savedSession = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: actionOpenSnapshot(wasPlaying: false)
        ))
        #expect(savedSession.publishInitialSnapshot(snapshot, token: savedSession.token))
        #expect(app.openPlaybackSubtitleFocusActionMenuFromKeyboard())
        try await waitForActionMenuState {
            savedSession.actionMenuState?.shioriAvailability == .alreadySaved
        }
        #expect(savedSession.actionMenuState?.isShioriSaved == true)
        #expect(savedSession.actionMenuState?.selectedAction == .copyCueText)
        #expect(savedSession.actionMenuState?.label(for: .shiori) == "Shiori Already Saved")
        #expect(!app.executePlaybackSubtitleFocusAction(.shiori))
        #expect(try database.shioriCount() == 1)
    }
}

@MainActor
@Test
func subtitleFocusCommittedShioriInvalidatesTableAfterMenuGenerationIsCancelled() async throws {
    try await withActionMenuApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: actionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(actionSnapshot(), token: session.token))
        let cue = try #require(session.actionMenuCandidateForKeyboard())
        #expect(session.openActionMenuFromKeyboard(for: cue))
        let lookup = try #require(session.actionMenuShioriLookupRequest)
        #expect(session.resolveActionMenuShioriAvailability(.available, request: lookup))
        let execution = try #require(session.beginActionMenuExecution(action: .shiori))
        let tableRevisionBefore = app.shiori.tableDataRevision

        app.finishPlaybackSubtitleFocusShioriSave(
            .saved,
            execution,
            session: session,
            taskGeneration: .min
        )

        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 1)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.actionMenuState?.isPerforming == true)
    }
}

@MainActor
private func withActionMenuApp(
    _ body: (AppCoordinator, SubtitleDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerSubtitleFocusActionMenuTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerSubtitleFocusActionMenuTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("action-menu.sqlite")
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
    let source = actionSource()
    app.search.selectedSearchResult = SubtitleSearchResult(
        entryID: 1,
        subtitlePath: source.subtitlePath,
        subtitleFormat: source.subtitleFormat,
        videoPath: source.videoPath,
        videoName: "Action Menu Video",
        startMilliseconds: 12_000,
        endMilliseconds: 12_900,
        content: "selected cue",
        cueLines: ["selected cue"]
    )
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    try await body(app, database)
}

@MainActor
private func waitForActionMenuState(
    timeout: TimeInterval = 3,
    condition: () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else {
            throw PlaybackSubtitleFocusActionMenuTestError.timedOut
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

private enum PlaybackSubtitleFocusActionMenuTestError: Error {
    case timedOut
}

@MainActor
private func actionSession() -> PlaybackSubtitleFocusSessionStore {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: actionOpenSnapshot(wasPlaying: false),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(actionSnapshot(), token: session.token))
    return session
}

private func actionOpenSnapshot(wasPlaying: Bool) -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: actionSource(),
        timestampMilliseconds: 12_500,
        wasPlaying: wasPlaying
    )
}

private func actionSource() -> SubtitleFocusSourceIdentity {
    SubtitleFocusSourceIdentity(
        videoPath: "/Media/Action-Menu.mkv",
        subtitlePath: "/Media/Action-Menu.srt",
        subtitleFormat: .srt
    )
}

private func actionSnapshot(
    lines: [String]? = nil
) -> SubtitleFocusSnapshot {
    SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: (6..<16).map { ordinal in
            actionCue(
                ordinal: ordinal,
                lines: ordinal == 12 ? lines : nil
            )
        }
    )
}

private func actionCue(
    ordinal: Int,
    lines: [String]? = nil
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: Int64(ordinal + 1),
        ordinal: ordinal,
        startMilliseconds: ordinal * 1_000,
        endMilliseconds: ordinal * 1_000 + 900,
        lines: lines ?? ["action cue \(ordinal)"]
    )
}

private func actionContext(
    cue: SubtitleFocusCue
) -> PlaybackSubtitleFocusActionContext {
    PlaybackSubtitleFocusActionContext(source: actionSource(), cue: cue)
}
