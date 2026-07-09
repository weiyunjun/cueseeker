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

@MainActor
final class PlaybackSubtitleFocusSessionStore: ObservableObject {
    let openSnapshot: PlaybackSubtitleFocusOpenSnapshot
    let token: PlaybackSubtitleFocusSessionToken

    @Published private(set) var state: PlaybackSubtitleFocusState = .opening

    private var cueCache = SubtitleFocusCueCache()
    private var isSessionActive = true

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
        state = .cueSelection(snapshot)
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

    private func closeSession() -> Bool {
        let wasPlaying = openSnapshot.wasPlaying
        isSessionActive = false
        cueCache.removeAll()
        state = .closed
        return wasPlaying
    }
}
