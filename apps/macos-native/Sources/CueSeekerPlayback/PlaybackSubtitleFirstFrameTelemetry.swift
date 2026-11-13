import CueSeekerCore
import Foundation
import QuartzCore

public enum PlaybackSubtitleFirstFrameTrigger: String, Sendable, Equatable {
    case newVideoOpen = "new_video_open"
    case sameVideoSeek = "same_video_seek"
    case manualSubtitleSwitch = "manual_subtitle_switch"
}

public enum PlaybackSubtitleCommitSyncState: String, Sendable, Equatable {
    case noSubtitle = "none"
    case hidden = "hidden"
    case syncReady = "sync_ready"
    case asyncPending = "async_pending"
}

public struct PlaybackSubtitleFirstFrameTelemetryEvent: Sendable, Equatable {
    public let trigger: PlaybackSubtitleFirstFrameTrigger
    public let format: PlaybackSubtitleSourceFormat
    public let subtitleFileName: String
    public let preparationMilliseconds: Double
    public let firstFrameMilliseconds: Double
    public let lagMilliseconds: Double
    public let totalMilliseconds: Double
    public let targetMilliseconds: Int
    public let isSynchronousAtCommit: Bool
    public let level: AppLogLevel
    public let presentationGeneration: UInt?
}

public struct PlaybackPresentationCommitTelemetryEvent: Sendable, Equatable {
    public let generation: UInt
    public let targetMilliseconds: Int
    public let presentedMilliseconds: Int
    public let subtitleSyncState: PlaybackSubtitleCommitSyncState
    public let subtitleFileName: String?
    public let videoFileName: String?
}

public enum PlaybackSubtitleFirstFrameTelemetry {
    public static let warnLagThresholdMilliseconds = 33.0
    public static let warnTotalThresholdMilliseconds = 200.0

    private final class ObserverState: @unchecked Sendable {
        let lock = NSLock()
        var firstFrameObserver: (@Sendable (PlaybackSubtitleFirstFrameTelemetryEvent) -> Void)?
        var presentationCommitObserver: (@Sendable (PlaybackPresentationCommitTelemetryEvent) -> Void)?
    }

    private static let observerState = ObserverState()

    public static func setTestObserver(
        _ observer: (@Sendable (PlaybackSubtitleFirstFrameTelemetryEvent) -> Void)?
    ) {
        observerState.lock.lock()
        observerState.firstFrameObserver = observer
        observerState.lock.unlock()
    }

    public static func setPresentationCommitTestObserver(
        _ observer: (@Sendable (PlaybackPresentationCommitTelemetryEvent) -> Void)?
    ) {
        observerState.lock.lock()
        observerState.presentationCommitObserver = observer
        observerState.lock.unlock()
    }

    public static func resetForTesting() {
        observerState.lock.lock()
        observerState.firstFrameObserver = nil
        observerState.presentationCommitObserver = nil
        observerState.lock.unlock()
    }

    static func emitPresentationCommit(
        generation: UInt,
        targetMilliseconds: Int,
        presentedMilliseconds: Int,
        subtitleSyncState: PlaybackSubtitleCommitSyncState,
        subtitleFileName: String?,
        videoFileName: String? = nil
    ) {
        observerState.lock.lock()
        let observer = observerState.presentationCommitObserver
        observerState.lock.unlock()
        observer?(
            PlaybackPresentationCommitTelemetryEvent(
                generation: generation,
                targetMilliseconds: targetMilliseconds,
                presentedMilliseconds: presentedMilliseconds,
                subtitleSyncState: subtitleSyncState,
                subtitleFileName: subtitleFileName,
                videoFileName: videoFileName
            )
        )
    }

    static func emitFirstFrame(
        attempt: PlaybackSubtitleFirstFrameAttempt,
        preparationMilliseconds: Double,
        firstFrameMilliseconds: Double,
        lagMilliseconds: Double
    ) {
        let totalMilliseconds = preparationMilliseconds + firstFrameMilliseconds
        let level: AppLogLevel = (
            lagMilliseconds > warnLagThresholdMilliseconds
                || totalMilliseconds >= warnTotalThresholdMilliseconds
        ) ? .warn : .debug
        let formatLabel = attempt.source.format.telemetryLabel
        let subtitleFileName = attempt.source.url.lastPathComponent

        var fields: [(String, String?)] = [
            ("subtitle", subtitleFileName),
            ("format", formatLabel),
            ("trigger", attempt.trigger.rawValue),
            ("target_ms", "\(attempt.targetMilliseconds)"),
            ("prep_ms", formatMilliseconds(preparationMilliseconds)),
            ("first_frame_ms", formatMilliseconds(firstFrameMilliseconds)),
            ("lag_ms", formatMilliseconds(lagMilliseconds)),
            ("total_ms", formatMilliseconds(totalMilliseconds)),
            ("sync_at_commit", attempt.wasSynchronousAtCommit ? "true" : "false")
        ]
        if let presentationGeneration = attempt.presentationGeneration {
            fields.append(("gen", "\(presentationGeneration)"))
        }

        AppLogger.shared.log(
            level: level,
            category: .playback,
            message: "Subtitle first frame presented",
            details: AppLogger.formatFields(fields)
        )

        observerState.lock.lock()
        let observer = observerState.firstFrameObserver
        observerState.lock.unlock()
        observer?(
            PlaybackSubtitleFirstFrameTelemetryEvent(
                trigger: attempt.trigger,
                format: attempt.source.format,
                subtitleFileName: subtitleFileName,
                preparationMilliseconds: preparationMilliseconds,
                firstFrameMilliseconds: firstFrameMilliseconds,
                lagMilliseconds: lagMilliseconds,
                totalMilliseconds: totalMilliseconds,
                targetMilliseconds: attempt.targetMilliseconds,
                isSynchronousAtCommit: attempt.wasSynchronousAtCommit,
                level: level,
                presentationGeneration: attempt.presentationGeneration
            )
        )
    }

    static func formatMilliseconds(_ value: Double) -> String {
        String(format: "%.2f", max(0, value))
    }
}

final class PlaybackSubtitleFirstFrameAttempt: @unchecked Sendable {
    let id = UUID()
    let trigger: PlaybackSubtitleFirstFrameTrigger
    let source: PlaybackSubtitleSource
    private var storedTargetMilliseconds: Int
    private var storedPresentationGeneration: UInt?
    let startedAt: CFTimeInterval
    private(set) var videoCommittedAt: CFTimeInterval?

    private let stateLock = NSLock()
    private var cancelled = false
    private var completed = false

    private(set) var didPrepareSource = false
    private(set) var prepStartedAt: CFTimeInterval?
    private(set) var prepFinishedAt: CFTimeInterval?
    private(set) var renderStartedAt: CFTimeInterval?
    private(set) var wasSynchronousAtCommit = false

    init(
        trigger: PlaybackSubtitleFirstFrameTrigger,
        source: PlaybackSubtitleSource,
        targetMilliseconds: Int,
        presentationGeneration: UInt?,
        startedAt: CFTimeInterval = CACurrentMediaTime(),
        videoCommittedAt: CFTimeInterval?
    ) {
        self.trigger = trigger
        self.source = source
        self.storedTargetMilliseconds = max(0, targetMilliseconds)
        self.storedPresentationGeneration = presentationGeneration
        self.startedAt = startedAt
        self.videoCommittedAt = videoCommittedAt
    }

    var targetMilliseconds: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedTargetMilliseconds
    }

    var presentationGeneration: UInt? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedPresentationGeneration
    }

    func updateTargetMilliseconds(_ milliseconds: Int) {
        stateLock.lock()
        if !cancelled && !completed {
            storedTargetMilliseconds = max(0, milliseconds)
        }
        stateLock.unlock()
    }

    func bindPresentationGeneration(_ generation: UInt) {
        stateLock.lock()
        if !cancelled && !completed {
            storedPresentationGeneration = generation
        }
        stateLock.unlock()
    }

    var isCancelled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return cancelled
    }

    func cancel() {
        stateLock.lock()
        cancelled = true
        stateLock.unlock()
    }

    @MainActor
    func markReusedSource(renderStartedAt: CFTimeInterval? = nil) {
        guard !isCancelled, !completed else {
            return
        }
        didPrepareSource = false
        prepStartedAt = nil
        prepFinishedAt = nil
        if let renderStartedAt {
            self.renderStartedAt = renderStartedAt
        } else if self.renderStartedAt == nil {
            self.renderStartedAt = startedAt
        }
    }

    @MainActor
    func markPrepStarted(at timestamp: CFTimeInterval) {
        guard !isCancelled, !completed else {
            return
        }
        didPrepareSource = true
        prepStartedAt = timestamp
        prepFinishedAt = nil
    }

    @MainActor
    func markPrepFinished(at timestamp: CFTimeInterval) {
        guard !isCancelled, !completed else {
            return
        }
        if !didPrepareSource {
            didPrepareSource = true
            prepStartedAt = startedAt
        }
        prepFinishedAt = timestamp
        renderStartedAt = timestamp
    }

    @MainActor
    func markVideoCommitted(at timestamp: CFTimeInterval) {
        guard !isCancelled, !completed else {
            return
        }
        videoCommittedAt = timestamp
    }

    @MainActor
    func completeSynchronouslyAtCommit(
        at completedAt: CFTimeInterval = CACurrentMediaTime(),
        frameReadyAt: CFTimeInterval? = nil
    ) {
        stateLock.lock()
        guard !cancelled, !completed else {
            stateLock.unlock()
            return
        }
        completed = true
        stateLock.unlock()

        if videoCommittedAt == nil, presentationGeneration != nil {
            videoCommittedAt = completedAt
        }
        wasSynchronousAtCommit = (videoCommittedAt != nil)
        let effectiveReadyAt = frameReadyAt ?? completedAt
        let preparationMilliseconds: Double
        let firstFrameStart: CFTimeInterval
        if didPrepareSource {
            let prepStart = prepStartedAt ?? startedAt
            let prepEnd = prepFinishedAt ?? effectiveReadyAt
            preparationMilliseconds = max(0, (prepEnd - prepStart) * 1000.0)
            firstFrameStart = renderStartedAt ?? prepEnd
        } else {
            preparationMilliseconds = 0
            firstFrameStart = renderStartedAt ?? startedAt
        }
        let firstFrameMilliseconds = max(0, (effectiveReadyAt - firstFrameStart) * 1000.0)
        PlaybackSubtitleFirstFrameTelemetry.emitFirstFrame(
            attempt: self,
            preparationMilliseconds: preparationMilliseconds,
            firstFrameMilliseconds: firstFrameMilliseconds,
            lagMilliseconds: 0
        )
    }

    @MainActor
    func completeAsynchronously(at completedAt: CFTimeInterval = CACurrentMediaTime()) {
        stateLock.lock()
        guard !cancelled, !completed else {
            stateLock.unlock()
            return
        }
        completed = true
        stateLock.unlock()

        wasSynchronousAtCommit = false
        let preparationMilliseconds: Double
        let firstFrameStart: CFTimeInterval
        if didPrepareSource {
            let prepStart = prepStartedAt ?? startedAt
            let prepEnd = prepFinishedAt ?? completedAt
            preparationMilliseconds = max(0, (prepEnd - prepStart) * 1000.0)
            firstFrameStart = renderStartedAt ?? prepEnd
        } else {
            preparationMilliseconds = 0
            firstFrameStart = renderStartedAt ?? startedAt
        }

        let firstFrameMilliseconds = max(0, (completedAt - firstFrameStart) * 1000.0)
        let lagMilliseconds: Double
        if let videoCommittedAt {
            lagMilliseconds = max(0, (completedAt - videoCommittedAt) * 1000.0)
        } else {
            lagMilliseconds = 0
        }

        PlaybackSubtitleFirstFrameTelemetry.emitFirstFrame(
            attempt: self,
            preparationMilliseconds: preparationMilliseconds,
            firstFrameMilliseconds: firstFrameMilliseconds,
            lagMilliseconds: lagMilliseconds
        )
    }
}

private extension PlaybackSubtitleSourceFormat {
    var telemetryLabel: String {
        switch self {
        case .ass:
            return "ass"
        case .srt:
            return "srt"
        }
    }
}
