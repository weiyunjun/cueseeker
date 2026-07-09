import CueSeekerCore
import Foundation

enum PlaybackSubtitleFocusWindowLoadKind: Equatable, Sendable {
    case sequential(direction: SubtitleFocusNavigationDirection)
    case target(ordinal: Int)
}

struct PlaybackSubtitleFocusWindowLoadIntent: Equatable, Sendable {
    let kind: PlaybackSubtitleFocusWindowLoadKind
    let range: Range<Int>
    let totalCount: Int

    var tokenTargetOrdinal: Int {
        switch kind {
        case .sequential:
            return range.lowerBound
        case .target(let ordinal):
            return ordinal
        }
    }
}

struct PlaybackSubtitleFocusWindowLoadRequest: Equatable, Sendable {
    let token: SubtitleFocusRequestToken
    let intent: PlaybackSubtitleFocusWindowLoadIntent
}

struct PlaybackSubtitleFocusWindowLoadCompletion: Equatable, Sendable {
    let shouldPublish: Bool
    let nextRequest: PlaybackSubtitleFocusWindowLoadRequest?
}

struct PlaybackSubtitleFocusLoadScheduler: Equatable, Sendable {
    private var requestGate: SubtitleFocusRequestGate
    private(set) var activeRequest: PlaybackSubtitleFocusWindowLoadRequest?
    private(set) var pendingRequest: PlaybackSubtitleFocusWindowLoadRequest?

    init(
        source: SubtitleFocusSourceIdentity,
        sessionGeneration: Int
    ) {
        requestGate = SubtitleFocusRequestGate(
            source: source,
            sessionGeneration: sessionGeneration
        )
    }

    var latestIntent: PlaybackSubtitleFocusWindowLoadIntent? {
        if let pendingRequest {
            return pendingRequest.intent
        }
        guard let activeRequest,
              requestGate.accepts(activeRequest.token)
        else {
            return nil
        }
        return activeRequest.intent
    }

    var hasWork: Bool {
        activeRequest != nil || pendingRequest != nil
    }

    mutating func enqueue(
        _ intent: PlaybackSubtitleFocusWindowLoadIntent
    ) -> PlaybackSubtitleFocusWindowLoadRequest? {
        if pendingRequest?.intent == intent {
            return nil
        }
        if pendingRequest == nil,
           let activeRequest,
           activeRequest.intent == intent,
           requestGate.accepts(activeRequest.token) {
            return nil
        }
        guard let token = requestGate.issueRequest(
            targetOrdinal: intent.tokenTargetOrdinal
        ) else {
            return nil
        }

        let request = PlaybackSubtitleFocusWindowLoadRequest(
            token: token,
            intent: intent
        )
        guard activeRequest != nil else {
            activeRequest = request
            return request
        }
        pendingRequest = request
        return nil
    }

    mutating func supersede() {
        requestGate.supersedeRequests()
        pendingRequest = nil
    }

    mutating func complete(
        _ request: PlaybackSubtitleFocusWindowLoadRequest
    ) -> PlaybackSubtitleFocusWindowLoadCompletion? {
        guard activeRequest?.token == request.token else {
            return nil
        }

        let shouldPublish = requestGate.accepts(request.token)
        activeRequest = nil
        let nextRequest = pendingRequest
        pendingRequest = nil
        activeRequest = nextRequest
        return PlaybackSubtitleFocusWindowLoadCompletion(
            shouldPublish: shouldPublish,
            nextRequest: nextRequest
        )
    }

    mutating func invalidate() {
        requestGate.invalidate()
        activeRequest = nil
        pendingRequest = nil
    }
}
