import Foundation
import CueSeekerCore
import CueSeekerPlayback

struct RemotePlaybackWarmCandidate: Equatable, Sendable {
    let mediaIdentifier: String
    let result: SubtitleSearchResult
    let provider: MediaSourceProvider
    let priority: Int
}

struct RemotePlaybackWarmPreparedRequest: Sendable {
    let request: PlaybackRequest
    let decodeMode: PlaybackDecodeMode
}

struct RemotePlaybackWarmSession: Sendable {
    let mediaIdentifier: String
    let player: PlaybackPlayer
    let request: PlaybackRequest
    let warmPointMilliseconds: Int
    let createdAt: Date
}

@MainActor
final class RemotePlaybackWarmUpCoordinator {
    typealias RequestBuilder = @MainActor @Sendable (
        RemotePlaybackWarmCandidate
    ) async throws -> RemotePlaybackWarmPreparedRequest

    private static let maximumWarmSessions = 3
    private static let candidateDebounceNanoseconds: UInt64 = 700_000_000
    private static let mediumPrimeNanoseconds: UInt64 = 900_000_000
    private static let warmSessionIdleNanoseconds: UInt64 = 180_000_000_000

    private let requestBuilder: RequestBuilder
    private var generation: UInt64 = 0
    private var schedulerTask: Task<Void, Never>?
    private var warmSessions: [String: RemotePlaybackWarmSession] = [:]
    private var sessionOrder: [String] = []
    private var expiryTasks: [String: Task<Void, Never>] = [:]
    private var activeMediaIdentifier: String?

    init(requestBuilder: @escaping RequestBuilder) {
        self.requestBuilder = requestBuilder
    }

    func publishSearchCandidates(_ candidates: [RemotePlaybackWarmCandidate]) {
        generation += 1
        let currentGeneration = generation
        schedulerTask?.cancel()
        activeMediaIdentifier = nil

        let candidateIdentifiers = Set(candidates.map(\.mediaIdentifier))
        removeSessionsNotIn(candidateIdentifiers)

        guard !candidates.isEmpty else {
            return
        }

        print("Remote warm-up: candidates=\(candidates.count) max_sessions=\(Self.maximumWarmSessions)")
        schedulerTask = Task { [weak self] in
            await self?.run(candidates: candidates, generation: currentGeneration)
        }
    }

    func takeWarmSession(mediaIdentifier: String) -> RemotePlaybackWarmSession? {
        guard let session = warmSessions.removeValue(forKey: mediaIdentifier) else {
            return nil
        }

        sessionOrder.removeAll { $0 == mediaIdentifier }
        expiryTasks.removeValue(forKey: mediaIdentifier)?.cancel()
        print("Remote warm-up: state=promoted media=\(redactedMedia(mediaIdentifier))")
        return session
    }

    func cancel(mediaIdentifier: String) {
        if activeMediaIdentifier == mediaIdentifier {
            schedulerTask?.cancel()
            activeMediaIdentifier = nil
        }
        removeSession(mediaIdentifier)
    }

    func clear() {
        generation += 1
        schedulerTask?.cancel()
        activeMediaIdentifier = nil
        for mediaIdentifier in Array(warmSessions.keys) {
            removeSession(mediaIdentifier)
        }
    }

    static func searchCandidates(
        results: [SubtitleSearchResult],
        remoteSources: [StoredMediaSource],
        currentMediaIdentifier: String?
    ) -> [RemotePlaybackWarmCandidate] {
        let eligibleSourceIDs = Set(
            remoteSources
                .filter { source in
                    source.type == .webdav
                        && (source.provider == .alist || source.provider == .genericWebDAV)
                }
                .map(\.id)
        )
        guard !eligibleSourceIDs.isEmpty else {
            return []
        }

        var candidates: [RemotePlaybackWarmCandidate] = []
        var seenMediaIdentifiers = Set<String>()
        for result in results {
            guard let sourceID = result.videoSourceID,
                  eligibleSourceIDs.contains(sourceID)
            else {
                continue
            }

            let mediaIdentifier = Self.mediaIdentifier(for: result)
            guard mediaIdentifier != currentMediaIdentifier,
                  seenMediaIdentifiers.insert(mediaIdentifier).inserted
            else {
                continue
            }

            let provider = remoteSources.first { $0.id == sourceID }?.provider ?? .genericWebDAV
            candidates.append(
                RemotePlaybackWarmCandidate(
                    mediaIdentifier: mediaIdentifier,
                    result: result,
                    provider: provider,
                    priority: candidates.count
                )
            )

            if candidates.count >= maximumWarmSessions {
                break
            }
        }
        return candidates
    }

    private func run(
        candidates: [RemotePlaybackWarmCandidate],
        generation: UInt64
    ) async {
        do {
            try await Task.sleep(nanoseconds: Self.candidateDebounceNanoseconds)

            for candidate in candidates {
                guard !Task.isCancelled, generation == self.generation else {
                    return
                }
                guard warmSessions[candidate.mediaIdentifier] == nil else {
                    continue
                }

                activeMediaIdentifier = candidate.mediaIdentifier
                print(
                    "Remote warm-up: state=resolving provider=\(candidate.provider.rawValue) media=\(redactedMedia(candidate.mediaIdentifier))"
                )
                let preparedRequest = try await requestBuilder(candidate)
                guard !Task.isCancelled, generation == self.generation else {
                    activeMediaIdentifier = nil
                    return
                }

                print("Remote warm-up: state=opening media=\(redactedMedia(candidate.mediaIdentifier))")
                let session = try await Self.openMediumWarmSession(
                    candidate: candidate,
                    preparedRequest: preparedRequest
                )
                guard !Task.isCancelled, generation == self.generation else {
                    try? session.player.stop()
                    activeMediaIdentifier = nil
                    return
                }

                store(session)
                activeMediaIdentifier = nil
                print("Remote warm-up: state=warm media=\(redactedMedia(candidate.mediaIdentifier))")
            }
        } catch is CancellationError {
            activeMediaIdentifier = nil
            print("Remote warm-up: state=cancelled")
        } catch {
            activeMediaIdentifier = nil
            print("Remote warm-up: state=failed reason=\(error)")
        }
    }

    private static func openMediumWarmSession(
        candidate: RemotePlaybackWarmCandidate,
        preparedRequest: RemotePlaybackWarmPreparedRequest
    ) async throws -> RemotePlaybackWarmSession {
        try await Task.detached(priority: .utility) {
            let player = PlaybackPlayer()
            player.decodeMode = preparedRequest.decodeMode
            try? player.setDoubleProperty("volume", value: 0)

            do {
                try Task.checkCancellation()
                try player.open(preparedRequest.request)
                try await Task.sleep(nanoseconds: mediumPrimeNanoseconds)
                try? player.setPaused(true)
                try Task.checkCancellation()
                return RemotePlaybackWarmSession(
                    mediaIdentifier: candidate.mediaIdentifier,
                    player: player,
                    request: preparedRequest.request,
                    warmPointMilliseconds: candidate.result.startMilliseconds,
                    createdAt: Date()
                )
            } catch {
                try? player.stop()
                throw error
            }
        }.value
    }

    private func store(_ session: RemotePlaybackWarmSession) {
        if warmSessions[session.mediaIdentifier] == nil {
            sessionOrder.append(session.mediaIdentifier)
        }
        warmSessions[session.mediaIdentifier] = session
        evictOverflowSessions()
        scheduleExpiry(for: session.mediaIdentifier)
    }

    private func evictOverflowSessions() {
        while sessionOrder.count > Self.maximumWarmSessions {
            guard let mediaIdentifier = sessionOrder.first else {
                return
            }
            removeSession(mediaIdentifier)
        }
    }

    private func scheduleExpiry(for mediaIdentifier: String) {
        expiryTasks.removeValue(forKey: mediaIdentifier)?.cancel()
        expiryTasks[mediaIdentifier] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.warmSessionIdleNanoseconds)
            } catch {
                return
            }
            self?.expire(mediaIdentifier: mediaIdentifier)
        }
    }

    private func expire(mediaIdentifier: String) {
        guard warmSessions[mediaIdentifier] != nil else {
            return
        }
        print("Remote warm-up: state=expired media=\(redactedMedia(mediaIdentifier))")
        removeSession(mediaIdentifier)
    }

    private func removeSessionsNotIn(_ identifiers: Set<String>) {
        for mediaIdentifier in Array(warmSessions.keys) where !identifiers.contains(mediaIdentifier) {
            removeSession(mediaIdentifier)
        }
    }

    private func removeSession(_ mediaIdentifier: String) {
        if let session = warmSessions.removeValue(forKey: mediaIdentifier) {
            try? session.player.stop()
        }
        sessionOrder.removeAll { $0 == mediaIdentifier }
        expiryTasks.removeValue(forKey: mediaIdentifier)?.cancel()
    }

    private static func mediaIdentifier(for result: SubtitleSearchResult) -> String {
        guard let sourceID = result.videoSourceID else {
            return result.videoPath
        }
        let path = result.videoSourceRelativePath?.removingPercentEncoding
            ?? result.videoSourceRelativePath
            ?? result.videoPath
        return "remote:\(sourceID):\(path)"
    }

    private func redactedMedia(_ mediaIdentifier: String) -> String {
        String(mediaIdentifier.hashValue)
    }
}
