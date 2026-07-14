import Combine
import CueSeekerCore
import Foundation

struct PlaybackSubtitleFocusOpenSnapshot: Equatable, Sendable {
    let source: SubtitleFocusSourceIdentity
    let timestampMilliseconds: Int
    let wasPlaying: Bool

    init(
        source: SubtitleFocusSourceIdentity,
        timestampMilliseconds: Int,
        wasPlaying: Bool
    ) {
        self.source = source
        self.timestampMilliseconds = max(0, timestampMilliseconds)
        self.wasPlaying = wasPlaying
    }
}

struct PlaybackSubtitleFocusSessionToken: Equatable, Sendable {
    let source: SubtitleFocusSourceIdentity
    let sessionGeneration: Int
}

enum PlaybackSubtitleFocusState: Equatable, Sendable {
    case closed
    case opening
    case cueSelection(SubtitleFocusSnapshot)
}

enum PlaybackOverlayModule: String, CaseIterable, Equatable, Sendable {
    case current
    case playlist
    case search
    case recent
    case library
    case shiori

    static let standardModules: [Self] = [
        .current,
        .search,
        .recent,
        .library,
        .shiori,
    ]

    static func modules(hasPlaylist: Bool) -> [Self] {
        hasPlaylist ? allCases : standardModules
    }

    var label: String {
        switch self {
        case .current:
            "Current"
        case .playlist:
            "Playlist"
        case .search:
            "Search"
        case .recent:
            "Recent"
        case .library:
            "Library"
        case .shiori:
            "Shiori"
        }
    }

    var systemImage: String {
        switch self {
        case .current, .recent:
            "clock"
        case .playlist:
            "list.bullet"
        case .search:
            "magnifyingglass"
        case .library:
            "folder"
        case .shiori:
            "bookmark"
        }
    }
}

struct PlaybackSubtitleFocusKeyboardNavigationRequest: Equatable, Sendable {
    let sequence: Int
    let direction: SubtitleFocusNavigationDirection
    let targetOrdinal: Int
}

@MainActor
final class PlaybackSubtitleFocusSessionStore: ObservableObject {
    let openSnapshot: PlaybackSubtitleFocusOpenSnapshot
    let token: PlaybackSubtitleFocusSessionToken

    @Published private(set) var state: PlaybackSubtitleFocusState = .opening
    @Published private(set) var keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
        = nil
    @Published private(set) var pendingKeyboardAction: PlaybackSubtitleFocusAction? = nil
    @Published private(set) var activeKeyboardAction: PlaybackSubtitleFocusActionExecution? = nil
    @Published private(set) var completeCueBatch: SubtitleFocusCueBatch? = nil
    @Published private(set) var availableModules: [PlaybackOverlayModule]
    @Published private(set) var selectedModule: PlaybackOverlayModule? = .current

    private var keyboardActionGeneration = 0
    private var isSessionActive = true
    private var isScrollbarDragging = false
    private var isCueReelMotionActive = false
    private var keyboardNavigationSequence = 0
    private var pendingKeyboardNavigationTargetOrdinal: Int?

    init(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot,
        sessionGeneration: Int,
        availableModules: [PlaybackOverlayModule] = PlaybackOverlayModule.standardModules
    ) {
        self.openSnapshot = openSnapshot
        let requestedModules = Set(availableModules)
        var normalizedModules = PlaybackOverlayModule.allCases.filter {
            requestedModules.contains($0)
        }
        if !normalizedModules.contains(.current) {
            normalizedModules.insert(.current, at: 0)
        }
        self.availableModules = normalizedModules
        token = PlaybackSubtitleFocusSessionToken(
            source: openSnapshot.source,
            sessionGeneration: sessionGeneration
        )
    }

    var isActive: Bool {
        isSessionActive
    }

    var currentSnapshot: SubtitleFocusSnapshot? {
        guard case .cueSelection(let snapshot) = state else {
            return nil
        }
        return snapshot
    }

    var retainedCueCount: Int {
        completeCueBatch?.cues.count ?? currentSnapshot?.cues.count ?? 0
    }

    var completeCueLoadTotalCount: Int? {
        guard completeCueBatch == nil,
              let snapshot = currentSnapshot,
              snapshot.cues.count < snapshot.totalCount
        else {
            return nil
        }
        return snapshot.totalCount
    }

    @discardableResult
    func selectModule(_ module: PlaybackOverlayModule) -> Bool {
        guard isSessionActive,
              availableModules.contains(module),
              selectedModule != module
        else {
            return false
        }

        prepareCurrentReelForModuleTransition()
        selectedModule = module
        return true
    }

    @discardableResult
    func selectNextModule() -> Bool {
        guard isSessionActive,
              let selectedModule,
              let currentIndex = availableModules.firstIndex(of: selectedModule),
              !availableModules.isEmpty
        else {
            return false
        }

        let nextIndex = availableModules.index(
            after: currentIndex
        ) == availableModules.endIndex
            ? availableModules.startIndex
            : availableModules.index(after: currentIndex)
        return selectModule(availableModules[nextIndex])
    }

    func cue(at ordinal: Int) -> SubtitleFocusCue? {
        if let completeCueBatch,
           completeCueBatch.cues.indices.contains(ordinal) {
            let cue = completeCueBatch.cues[ordinal]
            return cue.ordinal == ordinal ? cue : nil
        }
        return currentSnapshot?.cues.first { $0.ordinal == ordinal }
    }

    @discardableResult
    func publishInitialSnapshot(
        _ snapshot: SubtitleFocusSnapshot,
        token requestToken: PlaybackSubtitleFocusSessionToken
    ) -> Bool {
        let expectedRange = SubtitleFocusWindowPolicy.standard.windowRange(
            totalCount: snapshot.totalCount,
            selectedOrdinal: snapshot.selectedOrdinal
        )
        guard accepts(requestToken),
              state == .opening,
              snapshot.selectedCue != nil,
              !snapshot.cues.isEmpty,
              snapshot.totalCount > 0,
              snapshot.selectedOrdinal < snapshot.totalCount,
              snapshot.cues.count == expectedRange.count,
              let ordinalRange = snapshot.ordinalRange,
              ordinalRange.count == snapshot.cues.count,
              ordinalRange == expectedRange,
              snapshot.cues.map(\.ordinal) == Array(expectedRange)
        else {
            return false
        }
        if snapshot.cues.count == snapshot.totalCount,
           snapshot.cues.map(\.ordinal) == Array(0..<snapshot.totalCount) {
            completeCueBatch = SubtitleFocusCueBatch(
                totalCount: snapshot.totalCount,
                cues: snapshot.cues
            )
        }
        state = .cueSelection(snapshot)
        return true
    }

    @discardableResult
    func publishCompleteCueBatch(
        _ batch: SubtitleFocusCueBatch,
        token requestToken: PlaybackSubtitleFocusSessionToken
    ) -> Bool {
        guard accepts(requestToken),
              completeCueBatch == nil,
              let snapshot = currentSnapshot,
              batch.totalCount == snapshot.totalCount,
              batch.cues.count == snapshot.totalCount,
              batch.cues.map(\.ordinal) == Array(0..<snapshot.totalCount),
              snapshot.cues.allSatisfy({ cue in
                  batch.cues.indices.contains(cue.ordinal)
                      && batch.cues[cue.ordinal] == cue
              }),
              batch.cues.indices.contains(snapshot.selectedOrdinal),
              batch.cues[snapshot.selectedOrdinal] == snapshot.selectedCue
        else {
            return false
        }

        completeCueBatch = batch
        return true
    }

    @discardableResult
    func requestKeyboardNavigation(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard isSessionActive,
              pendingKeyboardAction == nil,
              activeKeyboardAction == nil,
              (!isCueReelMotionActive
                  || pendingKeyboardNavigationTargetOrdinal != nil),
              let snapshot = currentSnapshot
        else {
            return false
        }
        let currentTarget = pendingKeyboardNavigationTargetOrdinal
            ?? snapshot.selectedOrdinal
        let targetOrdinal = direction == .backward
            ? currentTarget - 1
            : currentTarget + 1
        guard targetOrdinal >= 0,
              targetOrdinal < snapshot.totalCount,
              cue(at: targetOrdinal) != nil
        else {
            return false
        }
        keyboardNavigationSequence += 1
        pendingKeyboardNavigationTargetOrdinal = targetOrdinal
        keyboardNavigationRequest = PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: keyboardNavigationSequence,
            direction: direction,
            targetOrdinal: targetOrdinal
        )
        return true
    }

    @discardableResult
    func commitKeyboardNavigation(
        _ request: PlaybackSubtitleFocusKeyboardNavigationRequest
    ) -> Bool {
        guard isSessionActive,
              keyboardNavigationRequest == request,
              pendingKeyboardNavigationTargetOrdinal == request.targetOrdinal,
              activeKeyboardAction == nil,
              selectAvailableCue(ordinal: request.targetOrdinal)
        else {
            return false
        }
        pendingKeyboardNavigationTargetOrdinal = nil
        keyboardNavigationRequest = nil
        return true
    }

    @discardableResult
    func commitNativeReelSelection(ordinal: Int) -> Bool {
        guard isSessionActive,
              activeKeyboardAction == nil,
              (pendingKeyboardAction == nil
                  || isCueReelMotionActive
                  || isScrollbarDragging),
              pendingKeyboardNavigationTargetOrdinal == nil
        else {
            return false
        }
        if currentSnapshot?.selectedOrdinal == ordinal {
            return true
        }
        return selectAvailableCue(ordinal: ordinal)
    }

    func noteScrollbarDragging(_ isDragging: Bool) {
        guard isSessionActive else {
            return
        }
        isScrollbarDragging = isDragging
    }

    func noteCueReelMotion(_ isActive: Bool) {
        guard isSessionActive else {
            return
        }
        isCueReelMotionActive = isActive
    }

    func allowsNativeWheelInput() -> Bool {
        isSessionActive
            && pendingKeyboardAction == nil
            && activeKeyboardAction == nil
            && pendingKeyboardNavigationTargetOrdinal == nil
            && !isScrollbarDragging
    }

    func allowsNativeScrollbarInput() -> Bool {
        isSessionActive
            && currentSnapshot != nil
            && pendingKeyboardAction == nil
            && activeKeyboardAction == nil
            && pendingKeyboardNavigationTargetOrdinal == nil
            && !isScrollbarDragging
            && !isCueReelMotionActive
    }

    func requestKeyboardAction(
        _ action: PlaybackSubtitleFocusAction
    ) -> PlaybackSubtitleFocusKeyboardActionRequestResult {
        guard isSessionActive,
              currentSnapshot?.selectedCue != nil,
              pendingKeyboardAction == nil,
              activeKeyboardAction == nil
        else {
            return .rejected
        }

        if pendingKeyboardNavigationTargetOrdinal != nil
            || isCueReelMotionActive
            || isScrollbarDragging {
            pendingKeyboardAction = action
            return .deferred
        }

        guard let execution = beginKeyboardAction(action) else {
            return .rejected
        }
        return .ready(execution)
    }

    func consumeDeferredKeyboardActionIfReady()
        -> PlaybackSubtitleFocusActionExecution? {
        guard isSessionActive,
              let action = pendingKeyboardAction,
              activeKeyboardAction == nil,
              pendingKeyboardNavigationTargetOrdinal == nil,
              !isCueReelMotionActive,
              !isScrollbarDragging,
              currentSnapshot?.selectedCue != nil
        else {
            return nil
        }

        pendingKeyboardAction = nil
        return beginKeyboardAction(action)
    }

    @discardableResult
    func finishKeyboardAction(
        _ execution: PlaybackSubtitleFocusActionExecution
    ) -> Bool {
        guard isSessionActive,
              activeKeyboardAction == execution
        else {
            return false
        }
        activeKeyboardAction = nil
        return true
    }

    @discardableResult
    func closeAfterPlay(
        _ execution: PlaybackSubtitleFocusActionExecution
    ) -> Bool {
        guard isSessionActive,
              execution.action == .playFromThisCue,
              activeKeyboardAction == execution
        else {
            return false
        }
        _ = closeSession()
        return true
    }

    @discardableResult
    func failOpening(
        token requestToken: PlaybackSubtitleFocusSessionToken
    ) -> Bool? {
        guard accepts(requestToken), state == .opening else {
            return nil
        }
        return closeSession()
    }

    @discardableResult
    func dismissByUser() -> Bool? {
        guard isSessionActive else {
            return nil
        }
        return closeSession()
    }

    func invalidateForSourceReplacement() {
        guard isSessionActive else {
            return
        }
        _ = closeSession()
    }

    private func accepts(_ requestToken: PlaybackSubtitleFocusSessionToken) -> Bool {
        isSessionActive && requestToken == token
    }

    private func beginKeyboardAction(
        _ action: PlaybackSubtitleFocusAction
    ) -> PlaybackSubtitleFocusActionExecution? {
        guard isSessionActive,
              pendingKeyboardAction == nil,
              activeKeyboardAction == nil,
              let cue = currentSnapshot?.selectedCue
        else {
            return nil
        }

        keyboardActionGeneration += 1
        let execution = PlaybackSubtitleFocusActionExecution(
            action: action,
            context: PlaybackSubtitleFocusActionContext(
                source: openSnapshot.source,
                cue: cue
            ),
            generation: keyboardActionGeneration
        )
        activeKeyboardAction = execution
        return execution
    }

    private func selectAvailableCue(ordinal: Int) -> Bool {
        guard let snapshot = currentSnapshot,
              ordinal >= 0,
              ordinal < snapshot.totalCount,
              cue(at: ordinal) != nil
        else {
            return false
        }

        let cues: [SubtitleFocusCue]
        if let completeCueBatch {
            let range = SubtitleFocusWindowPolicy.standard.windowRange(
                totalCount: snapshot.totalCount,
                selectedOrdinal: ordinal
            )
            cues = Array(completeCueBatch.cues[range])
        } else {
            cues = snapshot.cues
        }
        state = .cueSelection(SubtitleFocusSnapshot(
            totalCount: snapshot.totalCount,
            selectedOrdinal: ordinal,
            cues: cues
        ))
        return true
    }

    private func cancelKeyboardNavigationIntent() {
        pendingKeyboardNavigationTargetOrdinal = nil
        keyboardNavigationRequest = nil
    }

    private func prepareCurrentReelForModuleTransition() {
        pendingKeyboardAction = nil
        isScrollbarDragging = false
        isCueReelMotionActive = false
        cancelKeyboardNavigationIntent()
    }

    private func closeSession() -> Bool {
        let wasPlaying = openSnapshot.wasPlaying
        isSessionActive = false
        pendingKeyboardAction = nil
        activeKeyboardAction = nil
        isScrollbarDragging = false
        isCueReelMotionActive = false
        completeCueBatch = nil
        cancelKeyboardNavigationIntent()
        selectedModule = nil
        availableModules = []
        state = .closed
        return wasPlaying
    }
}
