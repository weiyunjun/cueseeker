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

@MainActor
final class PlaybackSubtitleFocusSessionStore: ObservableObject {
    let openSnapshot: PlaybackSubtitleFocusOpenSnapshot
    let token: PlaybackSubtitleFocusSessionToken

    @Published private(set) var state: PlaybackSubtitleFocusState = .opening
    @Published private(set) var keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
        = nil

    private var cueCache = SubtitleFocusCueCache()
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

    @discardableResult
    func selectCue(
        ordinal: Int,
        focusAnchorY: CGFloat
    ) -> Bool {
        guard focusAnchorY.isFinite else {
            return false
        }
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

    private func closeSession() -> Bool {
        let wasPlaying = openSnapshot.wasPlaying
        isSessionActive = false
        cueCache.removeAll()
        pendingKeyboardNavigationDirections.removeAll(keepingCapacity: false)
        keyboardNavigationRequest = nil
        initialSelectedOrdinal = nil
        focusAnchorY = nil
        state = .closed
        return wasPlaying
    }
}
