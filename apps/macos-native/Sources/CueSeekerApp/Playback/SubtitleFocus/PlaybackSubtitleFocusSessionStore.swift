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
    @Published private(set) var actionMenuState: PlaybackSubtitleFocusActionMenuState? = nil
    @Published private(set) var isActionMenuOpening = false
    @Published private(set) var completeCueBatch: SubtitleFocusCueBatch? = nil

    private var actionMenuGeneration = 0
    private var isSessionActive = true
    private var isScrollbarDragging = false
    private var isCueReelMotionActive = false
    private var keyboardNavigationSequence = 0
    private var pendingKeyboardNavigationTargetOrdinal: Int?
    private(set) var focusAnchorY: CGFloat?

    init(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot,
        sessionGeneration: Int
    ) {
        self.openSnapshot = openSnapshot
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

    func cue(at ordinal: Int) -> SubtitleFocusCue? {
        if let completeCueBatch,
           completeCueBatch.cues.indices.contains(ordinal) {
            let cue = completeCueBatch.cues[ordinal]
            return cue.ordinal == ordinal ? cue : nil
        }
        return currentSnapshot?.cues.first { $0.ordinal == ordinal }
    }

    var isActionMenuOpen: Bool {
        actionMenuState != nil
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
        focusAnchorY = nil
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
              actionMenuState == nil,
              !isActionMenuOpening,
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
              actionMenuState == nil,
              selectAvailableCue(ordinal: request.targetOrdinal, focusAnchorY: nil)
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
              actionMenuState == nil,
              (!isActionMenuOpening || isCueReelMotionActive),
              pendingKeyboardNavigationTargetOrdinal == nil
        else {
            return false
        }
        if currentSnapshot?.selectedOrdinal == ordinal {
            return true
        }
        return selectAvailableCue(ordinal: ordinal, focusAnchorY: nil)
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
            && actionMenuState == nil
            && !isActionMenuOpening
            && pendingKeyboardNavigationTargetOrdinal == nil
            && !isScrollbarDragging
    }

    func allowsNativeScrollbarInput() -> Bool {
        isSessionActive
            && currentSnapshot != nil
            && actionMenuState == nil
            && !isActionMenuOpening
            && pendingKeyboardNavigationTargetOrdinal == nil
            && !isScrollbarDragging
            && !isCueReelMotionActive
    }

    @discardableResult
    func deferActionMenuOpenUntilNavigationCompletes() -> Bool {
        guard isSessionActive,
              currentSnapshot != nil,
              actionMenuState == nil,
              !isActionMenuOpening,
              !isScrollbarDragging,
              (pendingKeyboardNavigationTargetOrdinal != nil || isCueReelMotionActive)
        else {
            return false
        }
        isActionMenuOpening = true
        return true
    }

    @discardableResult
    func consumeDeferredActionMenuOpen() -> Bool {
        guard isActionMenuOpening else {
            return false
        }
        isActionMenuOpening = false
        return canOpenActionMenu(requiresEmptyKeyboardQueue: true)
    }

    @discardableResult
    func cancelDeferredActionMenuOpen() -> Bool {
        guard isActionMenuOpening else {
            return false
        }
        isActionMenuOpening = false
        return true
    }

    func actionMenuCandidateForKeyboard() -> SubtitleFocusCue? {
        guard canOpenActionMenu(requiresEmptyKeyboardQueue: true) else {
            return nil
        }
        return currentSnapshot?.selectedCue
    }

    func canOpenActionMenuFromPointer(for cue: SubtitleFocusCue) -> Bool {
        guard canOpenActionMenu(requiresEmptyKeyboardQueue: false) else {
            return false
        }
        return self.cue(at: cue.ordinal) == cue
    }

    var actionMenuShioriLookupRequest: PlaybackSubtitleFocusShioriLookupRequest? {
        guard let actionMenuState,
              actionMenuState.shioriAvailability == .checking
        else {
            return nil
        }
        return PlaybackSubtitleFocusShioriLookupRequest(
            context: actionMenuState.context,
            menuGeneration: actionMenuState.generation
        )
    }

    @discardableResult
    func openActionMenuFromKeyboard(
        for expectedCue: SubtitleFocusCue
    ) -> Bool {
        guard actionMenuCandidateForKeyboard() == expectedCue else {
            return false
        }
        return publishActionMenu(for: expectedCue)
    }

    @discardableResult
    func openActionMenuFromPointer(
        for cue: SubtitleFocusCue,
        focusAnchorY clickedFocusAnchorY: CGFloat
    ) -> Bool {
        guard canOpenActionMenuFromPointer(for: cue),
              let snapshot = currentSnapshot
        else {
            return false
        }

        cancelKeyboardNavigationIntent()
        isActionMenuOpening = false
        if snapshot.selectedOrdinal != cue.ordinal {
            guard clickedFocusAnchorY.isFinite,
                  selectAvailableCue(
                      ordinal: cue.ordinal,
                      focusAnchorY: clickedFocusAnchorY
                  )
            else {
                return false
            }
        }
        return publishActionMenu(for: cue)
    }

    @discardableResult
    func resolveActionMenuShioriAvailability(
        _ availability: PlaybackSubtitleFocusShioriAvailability,
        request: PlaybackSubtitleFocusShioriLookupRequest
    ) -> Bool {
        guard var nextState = actionMenuState,
              nextState.generation == request.menuGeneration,
              nextState.context == request.context,
              nextState.resolveShioriAvailability(availability)
        else {
            return false
        }
        actionMenuState = nextState
        return true
    }

    @discardableResult
    func dismissActionMenu() -> Bool {
        guard let actionMenuState,
              !actionMenuState.isPerforming
        else {
            return false
        }
        self.actionMenuState = nil
        return true
    }

    @discardableResult
    func moveActionMenuSelection(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard var nextState = actionMenuState,
              nextState.moveSelection(direction)
        else {
            return false
        }
        actionMenuState = nextState
        return true
    }

    @discardableResult
    func hoverActionMenuItem(_ action: PlaybackSubtitleFocusAction) -> Bool {
        guard var nextState = actionMenuState,
              nextState.select(action)
        else {
            return false
        }
        actionMenuState = nextState
        return true
    }

    func beginActionMenuExecution(
        action requestedAction: PlaybackSubtitleFocusAction? = nil
    ) -> PlaybackSubtitleFocusActionExecution? {
        guard var nextState = actionMenuState,
              let action = nextState.beginExecution(action: requestedAction)
        else {
            return nil
        }
        actionMenuState = nextState
        return PlaybackSubtitleFocusActionExecution(
            action: action,
            context: nextState.context,
            menuGeneration: nextState.generation
        )
    }

    @discardableResult
    func failActionMenuExecution(menuGeneration: Int) -> Bool {
        guard var nextState = actionMenuState,
              nextState.generation == menuGeneration,
              nextState.isPerforming
        else {
            return false
        }
        nextState.finishFailedExecution()
        actionMenuState = nextState
        return true
    }

    @discardableResult
    func markActionMenuShioriSaved(menuGeneration: Int) -> Bool {
        guard var nextState = actionMenuState,
              nextState.generation == menuGeneration,
              nextState.isPerforming
        else {
            return false
        }
        nextState.markShioriSaved()
        actionMenuState = nextState
        return true
    }

    func completeActionMenuExecution(menuGeneration: Int) -> Bool? {
        guard let actionMenuState,
              actionMenuState.generation == menuGeneration,
              actionMenuState.isPerforming
        else {
            return nil
        }
        return closeSession()
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

    private func canOpenActionMenu(
        requiresEmptyKeyboardQueue: Bool
    ) -> Bool {
        isSessionActive
            && currentSnapshot != nil
            && actionMenuState == nil
            && !isActionMenuOpening
            && !isScrollbarDragging
            && !isCueReelMotionActive
            && (!requiresEmptyKeyboardQueue
                || pendingKeyboardNavigationTargetOrdinal == nil)
    }

    private func publishActionMenu(
        for cue: SubtitleFocusCue
    ) -> Bool {
        guard isSessionActive,
              actionMenuState == nil,
              currentSnapshot?.selectedCue == cue
        else {
            return false
        }
        cancelKeyboardNavigationIntent()
        isActionMenuOpening = false
        actionMenuGeneration += 1
        actionMenuState = PlaybackSubtitleFocusActionMenuState(
            context: PlaybackSubtitleFocusActionContext(
                source: openSnapshot.source,
                cue: cue
            ),
            generation: actionMenuGeneration
        )
        return true
    }

    private func selectAvailableCue(
        ordinal: Int,
        focusAnchorY nextFocusAnchorY: CGFloat?
    ) -> Bool {
        guard let snapshot = currentSnapshot,
              ordinal >= 0,
              ordinal < snapshot.totalCount,
              cue(at: ordinal) != nil
        else {
            return false
        }

        if let nextFocusAnchorY {
            focusAnchorY = nextFocusAnchorY
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

    private func closeSession() -> Bool {
        let wasPlaying = openSnapshot.wasPlaying
        isSessionActive = false
        actionMenuState = nil
        isScrollbarDragging = false
        isCueReelMotionActive = false
        isActionMenuOpening = false
        completeCueBatch = nil
        cancelKeyboardNavigationIntent()
        focusAnchorY = nil
        state = .closed
        return wasPlaying
    }
}
