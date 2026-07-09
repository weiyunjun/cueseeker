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

    private var cueCache = SubtitleFocusCueCache()
    private var loadScheduler: PlaybackSubtitleFocusLoadScheduler
    private var pendingScrollbarPreviewOrdinal: Int?
    private var protectedVisibleOrdinalRange: Range<Int>?
    private var targetWindowCommitSequence = 0
    private var isSessionActive = true
    private var keyboardNavigationSequence = 0
    private var pendingKeyboardNavigationDirections: [SubtitleFocusNavigationDirection] = []
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
        cueCache.count
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
        initialSelectedOrdinal = snapshot.selectedOrdinal
        focusAnchorY = nil
        state = .cueSelection(snapshot)
        return true
    }

    @discardableResult
    func moveSelection(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard isSessionActive,
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
        guard isSessionActive, currentSnapshot != nil else {
            return false
        }
        supersedeTargetWindowLoadForNavigationIfNeeded()
        keyboardNavigationSequence += 1
        pendingKeyboardNavigationDirections.append(direction)
        keyboardNavigationRequest = PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: keyboardNavigationSequence,
            direction: direction
        )
        return true
    }

    func takePendingKeyboardNavigationDirections() -> [SubtitleFocusNavigationDirection] {
        let directions = pendingKeyboardNavigationDirections
        pendingKeyboardNavigationDirections.removeAll(keepingCapacity: true)
        return directions
    }

    func canMoveSelection(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard isSessionActive,
              let snapshot = currentSnapshot
        else {
            return false
        }

        let targetOrdinal = direction == .backward
            ? snapshot.selectedOrdinal - 1
            : snapshot.selectedOrdinal + 1
        return targetOrdinal >= 0
            && targetOrdinal < snapshot.totalCount
            && cueCache[targetOrdinal] != nil
    }

    func isCueCached(ordinal: Int) -> Bool {
        cueCache[ordinal] != nil
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
        guard let snapshot = currentSnapshot,
              ordinal >= 0,
              ordinal < snapshot.totalCount
        else {
            return
        }
        loadScheduler.supersede()
        if cueCache[ordinal] == nil {
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
        guard let snapshot = currentSnapshot,
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
        guard currentSnapshot != nil,
              cueCache[ordinal] != nil
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
        guard focusAnchorY.isFinite else {
            return false
        }
        supersedeWindowLoads(resolvesScrollbar: true)
        guard currentSnapshot?.selectedOrdinal != ordinal else {
            return true
        }
        return selectCachedCue(ordinal: ordinal, focusAnchorY: focusAnchorY)
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

    private func selectCachedCue(
        ordinal: Int,
        focusAnchorY nextFocusAnchorY: CGFloat?
    ) -> Bool {
        guard let snapshot = currentSnapshot,
              ordinal >= 0,
              ordinal < snapshot.totalCount,
              cueCache[ordinal] != nil
        else {
            return false
        }

        if let nextFocusAnchorY {
            focusAnchorY = nextFocusAnchorY
        }
        state = .cueSelection(SubtitleFocusSnapshot(
            totalCount: snapshot.totalCount,
            selectedOrdinal: ordinal,
            cues: cueCache.cues
        ))
        return true
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
        cueCache.removeAll()
        pendingKeyboardNavigationDirections.removeAll(keepingCapacity: false)
        keyboardNavigationRequest = nil
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
