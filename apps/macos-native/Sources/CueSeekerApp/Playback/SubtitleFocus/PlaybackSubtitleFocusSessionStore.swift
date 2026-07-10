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

struct PlaybackSubtitleFocusTargetWindowState: Equatable, Sendable {
    let loadingTargetOrdinal: Int?
    let resolutionGeneration: Int

    static let idle = PlaybackSubtitleFocusTargetWindowState(
        loadingTargetOrdinal: nil,
        resolutionGeneration: 0
    )

    var isLoading: Bool {
        loadingTargetOrdinal != nil
    }
}

struct PlaybackSubtitleFocusTargetWindowCommit: Equatable, Sendable {
    let sequence: Int
    let direction: SubtitleFocusNavigationDirection
}

@MainActor
final class PlaybackSubtitleFocusSessionStore: ObservableObject {
    let openSnapshot: PlaybackSubtitleFocusOpenSnapshot
    let token: PlaybackSubtitleFocusSessionToken

    @Published private(set) var state: PlaybackSubtitleFocusState = .opening
    @Published private(set) var keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
        = nil
    @Published private(set) var targetWindowState: PlaybackSubtitleFocusTargetWindowState = .idle
    @Published private(set) var targetWindowCommit: PlaybackSubtitleFocusTargetWindowCommit? = nil
    @Published private(set) var actionMenuState: PlaybackSubtitleFocusActionMenuState? = nil
    @Published private(set) var isActionMenuOpening = false
    @Published private(set) var completeCueBatch: SubtitleFocusCueBatch? = nil

    private var cueCache = SubtitleFocusCueCache()
    private var loadScheduler: PlaybackSubtitleFocusLoadScheduler
    private var pendingScrollbarPreviewOrdinal: Int?
    private var protectedVisibleOrdinalRange: Range<Int>?
    private var targetWindowCommitSequence = 0
    private var actionMenuGeneration = 0
    private var isSessionActive = true
    private var isScrollbarDragging = false
    private var isCueReelMotionActive = false
    private var keyboardNavigationSequence = 0
    private var pendingKeyboardNavigationTargetOrdinal: Int?
    private(set) var initialSelectedOrdinal: Int?
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
        loadScheduler = PlaybackSubtitleFocusLoadScheduler(
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
        completeCueBatch?.cues.count ?? cueCache.count
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
        guard let completeCueBatch,
              completeCueBatch.cues.indices.contains(ordinal)
        else {
            return cueCache[ordinal]
        }
        return completeCueBatch.cues[ordinal]
    }

    var activeWindowLoadRequest: PlaybackSubtitleFocusWindowLoadRequest? {
        loadScheduler.activeRequest
    }

    var pendingWindowLoadRequest: PlaybackSubtitleFocusWindowLoadRequest? {
        loadScheduler.pendingRequest
    }

    var isTargetWindowLoading: Bool {
        targetWindowState.isLoading
    }

    var isActionMenuOpen: Bool {
        actionMenuState != nil
    }

    @discardableResult
    func publishInitialSnapshot(
        _ snapshot: SubtitleFocusSnapshot,
        token requestToken: PlaybackSubtitleFocusSessionToken
    ) -> Bool {
        guard accepts(requestToken),
              state == .opening,
              snapshot.selectedCue != nil,
              !snapshot.cues.isEmpty,
              snapshot.cues.count <= SubtitleFocusWindowPolicy.standard.maximumRetainedCount
        else {
            return false
        }

        var nextCache = SubtitleFocusCueCache()
        nextCache.replace(with: SubtitleFocusCueBatch(
            totalCount: snapshot.totalCount,
            cues: snapshot.cues
        ))
        guard nextCache.count == snapshot.cues.count else {
            return false
        }

        cueCache = nextCache
        if snapshot.cues.count == snapshot.totalCount,
           snapshot.cues.map(\.ordinal) == Array(0..<snapshot.totalCount) {
            completeCueBatch = SubtitleFocusCueBatch(
                totalCount: snapshot.totalCount,
                cues: snapshot.cues
            )
            loadScheduler.invalidate()
        }
        initialSelectedOrdinal = snapshot.selectedOrdinal
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

        let pendingScrollbarTarget = pendingScrollbarPreviewOrdinal
        let preservesActiveDragPreview = pendingScrollbarTarget != nil
            && isScrollbarDragging
        loadScheduler.invalidate()
        pendingScrollbarPreviewOrdinal = nil
        protectedVisibleOrdinalRange = nil
        completeCueBatch = batch
        if let pendingScrollbarTarget, !isScrollbarDragging {
            _ = selectCachedCue(
                ordinal: pendingScrollbarTarget,
                focusAnchorY: nil
            )
        }
        targetWindowState = PlaybackSubtitleFocusTargetWindowState(
            loadingTargetOrdinal: nil,
            resolutionGeneration: targetWindowState.resolutionGeneration
                + (preservesActiveDragPreview ? 0 : 1)
        )
        return true
    }

    @discardableResult
    func moveSelection(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard isSessionActive,
              actionMenuState == nil,
              pendingKeyboardNavigationTargetOrdinal == nil,
              let snapshot = currentSnapshot
        else {
            return false
        }

        let targetOrdinal: Int
        switch direction {
        case .backward:
            targetOrdinal = snapshot.selectedOrdinal - 1
        case .forward:
            targetOrdinal = snapshot.selectedOrdinal + 1
        }
        return selectCachedCue(ordinal: targetOrdinal, focusAnchorY: nil)
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
        supersedeTargetWindowLoadForNavigationIfNeeded()
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
              selectCachedCue(ordinal: request.targetOrdinal, focusAnchorY: nil)
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
        return selectCachedCue(ordinal: ordinal, focusAnchorY: nil)
    }

    func canMoveSelection(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard isSessionActive,
              actionMenuState == nil,
              let snapshot = currentSnapshot
        else {
            return false
        }

        let targetOrdinal = direction == .backward
            ? snapshot.selectedOrdinal - 1
            : snapshot.selectedOrdinal + 1
        return targetOrdinal >= 0
            && targetOrdinal < snapshot.totalCount
            && cue(at: targetOrdinal) != nil
    }

    func isCueCached(ordinal: Int) -> Bool {
        cue(at: ordinal) != nil
    }

    func updateProtectedVisibleOrdinalRange(_ range: Range<Int>?) {
        guard isSessionActive else {
            return
        }
        protectedVisibleOrdinalRange = range
    }

    func windowLoadRequestAfterNavigation(
        _ direction: SubtitleFocusNavigationDirection
    ) -> PlaybackSubtitleFocusWindowLoadRequest? {
        guard isSessionActive,
              completeCueBatch == nil,
              actionMenuState == nil,
              !isActionMenuOpening,
              let snapshot = currentSnapshot,
              let loadedRange = cueCache.ordinalRange
        else {
            return nil
        }

        supersedeTargetWindowLoadForNavigationIfNeeded()

        if let latestIntent = loadScheduler.latestIntent {
            let keepsLatestSequentialRequest: Bool
            if case .sequential(let latestDirection) = latestIntent.kind {
                keepsLatestSequentialRequest = latestDirection == direction
                    && SubtitleFocusWindowPolicy.standard.shouldPrefetch(
                        selectedOrdinal: snapshot.selectedOrdinal,
                        loadedRange: loadedRange,
                        direction: direction
                    )
            } else {
                keepsLatestSequentialRequest = false
            }
            if !keepsLatestSequentialRequest {
                supersedeWindowLoads(resolvesScrollbar: true)
            }
        }

        let policy = SubtitleFocusWindowPolicy.standard
        guard policy.shouldPrefetch(
            selectedOrdinal: snapshot.selectedOrdinal,
            loadedRange: loadedRange,
            direction: direction
        ),
        let range = policy.prefetchRange(
            totalCount: snapshot.totalCount,
            loadedRange: loadedRange,
            direction: direction
        ) else {
            return nil
        }

        let request = loadScheduler.enqueue(PlaybackSubtitleFocusWindowLoadIntent(
            kind: .sequential(direction: direction),
            range: range,
            totalCount: snapshot.totalCount
        ))
        updateTargetLoadingStateFromLatestIntent()
        return request
    }

    func noteScrollbarPreviewChanged(ordinal: Int) {
        guard actionMenuState == nil,
              !isActionMenuOpening,
              let snapshot = currentSnapshot,
              ordinal >= 0,
              ordinal < snapshot.totalCount
        else {
            return
        }
        loadScheduler.supersede()
        if cue(at: ordinal) == nil {
            pendingScrollbarPreviewOrdinal = ordinal
            guard targetWindowState.loadingTargetOrdinal == nil else {
                return
            }
            targetWindowState = PlaybackSubtitleFocusTargetWindowState(
                loadingTargetOrdinal: ordinal,
                resolutionGeneration: targetWindowState.resolutionGeneration
            )
        } else {
            pendingScrollbarPreviewOrdinal = nil
            guard targetWindowState.loadingTargetOrdinal != nil else {
                return
            }
            targetWindowState = PlaybackSubtitleFocusTargetWindowState(
                loadingTargetOrdinal: nil,
                resolutionGeneration: targetWindowState.resolutionGeneration
            )
        }
    }

    func windowLoadRequestForScrollbarTarget(
        ordinal: Int
    ) -> PlaybackSubtitleFocusWindowLoadRequest? {
        guard actionMenuState == nil,
              completeCueBatch == nil,
              !isActionMenuOpening,
              let snapshot = currentSnapshot,
              ordinal >= 0,
              ordinal < snapshot.totalCount,
              cueCache[ordinal] == nil,
              pendingScrollbarPreviewOrdinal == ordinal
        else {
            return nil
        }
        let range = SubtitleFocusWindowPolicy.standard.windowRange(
            totalCount: snapshot.totalCount,
            selectedOrdinal: ordinal
        )
        let request = loadScheduler.enqueue(PlaybackSubtitleFocusWindowLoadIntent(
            kind: .target(ordinal: ordinal),
            range: range,
            totalCount: snapshot.totalCount
        ))
        updateTargetLoadingStateFromLatestIntent()
        return request
    }

    @discardableResult
    func commitCachedScrollbarTarget(ordinal: Int) -> Bool {
        guard actionMenuState == nil,
              !isActionMenuOpening,
              currentSnapshot != nil,
              cue(at: ordinal) != nil
        else {
            return false
        }
        supersedeWindowLoads(resolvesScrollbar: false)
        let committed = selectCachedCue(ordinal: ordinal, focusAnchorY: nil)
        resolveScrollbarTarget(force: true)
        return committed
    }

    func isActiveWindowLoad(
        _ request: PlaybackSubtitleFocusWindowLoadRequest
    ) -> Bool {
        loadScheduler.activeRequest?.token == request.token
    }

    func completeWindowLoad(
        _ request: PlaybackSubtitleFocusWindowLoadRequest,
        batch: SubtitleFocusCueBatch?
    ) -> PlaybackSubtitleFocusWindowLoadRequest? {
        guard isSessionActive,
              let completion = loadScheduler.complete(request)
        else {
            return nil
        }

        if completion.shouldPublish {
            let didApply = batch.map {
                applyWindowLoad($0, request: request)
            } ?? false
            if case .target = request.intent.kind {
                resolveScrollbarTarget(force: true)
            } else if !didApply {
                updateTargetLoadingStateFromLatestIntent()
            }
        }
        updateTargetLoadingStateFromLatestIntent()
        return completion.nextRequest
    }

    @discardableResult
    func selectCue(
        ordinal: Int,
        focusAnchorY: CGFloat
    ) -> Bool {
        guard actionMenuState == nil,
              !isActionMenuOpening,
              focusAnchorY.isFinite
        else {
            return false
        }
        supersedeWindowLoads(resolvesScrollbar: true)
        guard currentSnapshot?.selectedOrdinal != ordinal else {
            return true
        }
        return selectCachedCue(ordinal: ordinal, focusAnchorY: focusAnchorY)
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
            && !targetWindowState.isLoading
    }

    func allowsNativeScrollbarInput() -> Bool {
        isSessionActive
            && currentSnapshot != nil
            && actionMenuState == nil
            && !isActionMenuOpening
            && pendingKeyboardNavigationTargetOrdinal == nil
            && !isScrollbarDragging
            && !isCueReelMotionActive
            && !targetWindowState.isLoading
    }

    @discardableResult
    func deferActionMenuOpenUntilNavigationCompletes() -> Bool {
        guard isSessionActive,
              currentSnapshot != nil,
              actionMenuState == nil,
              !isActionMenuOpening,
              !targetWindowState.isLoading,
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
                  selectCachedCue(
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
            && !targetWindowState.isLoading
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
        supersedeWindowLoads(resolvesScrollbar: true)
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

    private func selectCachedCue(
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
            cues = cueCache.cues
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

    private func applyWindowLoad(
        _ batch: SubtitleFocusCueBatch,
        request: PlaybackSubtitleFocusWindowLoadRequest
    ) -> Bool {
        guard let snapshot = currentSnapshot,
              batch.totalCount == request.intent.totalCount,
              batch.totalCount == snapshot.totalCount,
              batch.cues.map(\.ordinal) == Array(request.intent.range)
        else {
            return false
        }

        switch request.intent.kind {
        case .target(let ordinal):
            guard batch.cues.contains(where: { $0.ordinal == ordinal }) else {
                return false
            }
            var nextCache = SubtitleFocusCueCache()
            nextCache.replace(with: batch)
            guard nextCache[ordinal] != nil,
                  nextCache.count <= SubtitleFocusWindowPolicy.standard.maximumRetainedCount
            else {
                return false
            }
            let direction: SubtitleFocusNavigationDirection = ordinal < snapshot.selectedOrdinal
                ? .backward
                : .forward
            cueCache = nextCache
            protectedVisibleOrdinalRange = nil
            isCueReelMotionActive = true
            targetWindowCommitSequence += 1
            targetWindowCommit = PlaybackSubtitleFocusTargetWindowCommit(
                sequence: targetWindowCommitSequence,
                direction: direction
            )
            state = .cueSelection(SubtitleFocusSnapshot(
                totalCount: snapshot.totalCount,
                selectedOrdinal: ordinal,
                cues: nextCache.cues
            ))
            return true

        case .sequential(let direction):
            guard let loadedRange = cueCache.ordinalRange,
                  SubtitleFocusWindowPolicy.standard.shouldPrefetch(
                    selectedOrdinal: snapshot.selectedOrdinal,
                    loadedRange: loadedRange,
                    direction: direction
                  ),
                  isAdjacent(request.intent.range, to: loadedRange, direction: direction)
            else {
                return false
            }
            var nextCache = cueCache
            _ = nextCache.merge(batch, direction: direction)
            let protectedRange = SubtitleFocusWindowPolicy.standard.windowRange(
                totalCount: snapshot.totalCount,
                selectedOrdinal: snapshot.selectedOrdinal
            )
            let protectedRanges = [
                protectedRange,
                protectedVisibleOrdinalRange,
            ].compactMap { $0 }
            guard nextCache.count <= SubtitleFocusWindowPolicy.standard.maximumRetainedCount,
                  nextCache[snapshot.selectedOrdinal] != nil,
                  protectedRanges.allSatisfy({ range in
                      range.allSatisfy { nextCache[$0] != nil }
                  }),
                  let nextRange = nextCache.ordinalRange,
                  nextRange.count == nextCache.count
            else {
                return false
            }
            cueCache = nextCache
            state = .cueSelection(SubtitleFocusSnapshot(
                totalCount: snapshot.totalCount,
                selectedOrdinal: snapshot.selectedOrdinal,
                cues: nextCache.cues
            ))
            return true
        }
    }

    private func isAdjacent(
        _ requestedRange: Range<Int>,
        to loadedRange: Range<Int>,
        direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        switch direction {
        case .backward:
            return requestedRange.upperBound == loadedRange.lowerBound
        case .forward:
            return requestedRange.lowerBound == loadedRange.upperBound
        }
    }

    private func supersedeWindowLoads(resolvesScrollbar: Bool) {
        loadScheduler.supersede()
        if resolvesScrollbar {
            resolveScrollbarTarget()
        }
    }

    private func supersedeTargetWindowLoadForNavigationIfNeeded() {
        let latestIntentIsTarget: Bool
        if let latestIntent = loadScheduler.latestIntent,
           case .target = latestIntent.kind {
            latestIntentIsTarget = true
        } else {
            latestIntentIsTarget = false
        }
        guard targetWindowState.isLoading || latestIntentIsTarget else {
            return
        }
        supersedeWindowLoads(resolvesScrollbar: true)
    }

    private func updateTargetLoadingStateFromLatestIntent() {
        let targetOrdinal: Int?
        if let latestIntent = loadScheduler.latestIntent,
           case .target(let ordinal) = latestIntent.kind {
            targetOrdinal = ordinal
        } else {
            targetOrdinal = pendingScrollbarPreviewOrdinal
        }
        guard targetWindowState.loadingTargetOrdinal != targetOrdinal else {
            return
        }
        targetWindowState = PlaybackSubtitleFocusTargetWindowState(
            loadingTargetOrdinal: targetOrdinal,
            resolutionGeneration: targetWindowState.resolutionGeneration
        )
    }

    private func resolveScrollbarTarget(force: Bool = false) {
        let hadUnresolvedTarget = pendingScrollbarPreviewOrdinal != nil
            || targetWindowState.loadingTargetOrdinal != nil
        pendingScrollbarPreviewOrdinal = nil
        guard force || hadUnresolvedTarget else {
            return
        }
        targetWindowState = PlaybackSubtitleFocusTargetWindowState(
            loadingTargetOrdinal: nil,
            resolutionGeneration: targetWindowState.resolutionGeneration + 1
        )
    }

    private func closeSession() -> Bool {
        let wasPlaying = openSnapshot.wasPlaying
        isSessionActive = false
        loadScheduler.invalidate()
        pendingScrollbarPreviewOrdinal = nil
        protectedVisibleOrdinalRange = nil
        actionMenuState = nil
        isScrollbarDragging = false
        isCueReelMotionActive = false
        isActionMenuOpening = false
        cueCache.removeAll()
        completeCueBatch = nil
        cancelKeyboardNavigationIntent()
        targetWindowState = PlaybackSubtitleFocusTargetWindowState(
            loadingTargetOrdinal: nil,
            resolutionGeneration: targetWindowState.resolutionGeneration + 1
        )
        targetWindowCommit = nil
        initialSelectedOrdinal = nil
        focusAnchorY = nil
        state = .closed
        return wasPlaying
    }
}
