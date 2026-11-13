import AppKit
import CASSRendering
import CNativePlayback
import CueSeekerCore
import Foundation
import QuartzCore

public protocol PlaybackPlayerDelegate: AnyObject {
    func player(_ player: PlaybackPlayer, didUpdateTimePosition seconds: Double)
    func player(_ player: PlaybackPlayer, didUpdateDuration seconds: Double)
    func player(_ player: PlaybackPlayer, didUpdateVideoAspectRatio aspectRatio: Double)
    func player(_ player: PlaybackPlayer, didUpdatePaused isPaused: Bool)
    func player(_ player: PlaybackPlayer, didUpdateVolume volume: Double)
    func player(_ player: PlaybackPlayer, didUpdatePlaybackSpeed speed: Double)
    func player(_ player: PlaybackPlayer, didFailWithMessage message: String)
    func player(_ player: PlaybackPlayer, didFailToOpenVideoAt url: URL, error: Error)
    func player(_ player: PlaybackPlayer, didFailToLoadSubtitleSource url: URL)
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int)
    func playerDidFinishPlayback(_ player: PlaybackPlayer)
    func playerDidResetTimelineThumbnails(_ player: PlaybackPlayer)
    func player(_ player: PlaybackPlayer, didReachAutoStopBoundaryAtMilliseconds endMilliseconds: Int)
    @MainActor func player(
        _ player: PlaybackPlayer,
        didCommitPresentationAtMilliseconds milliseconds: Int,
        generation: UInt,
        playing: Bool,
        videoSize: CGSize?
    )
}

public extension PlaybackPlayerDelegate {
    func player(_ player: PlaybackPlayer, didUpdateTimePosition seconds: Double) {}
    func player(_ player: PlaybackPlayer, didUpdateDuration seconds: Double) {}
    func player(_ player: PlaybackPlayer, didUpdateVideoAspectRatio aspectRatio: Double) {}
    func player(_ player: PlaybackPlayer, didUpdatePaused isPaused: Bool) {}
    func player(_ player: PlaybackPlayer, didUpdateVolume volume: Double) {}
    func player(_ player: PlaybackPlayer, didUpdatePlaybackSpeed speed: Double) {}
    func player(_ player: PlaybackPlayer, didFailToOpenVideoAt url: URL, error: Error) {}
    func player(_ player: PlaybackPlayer, didFailToLoadSubtitleSource url: URL) {}
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int) {}
    func playerDidFinishPlayback(_ player: PlaybackPlayer) {}
    func playerDidResetTimelineThumbnails(_ player: PlaybackPlayer) {}
    func player(_ player: PlaybackPlayer, didReachAutoStopBoundaryAtMilliseconds endMilliseconds: Int) {}
    @MainActor func player(
        _ player: PlaybackPlayer,
        didCommitPresentationAtMilliseconds milliseconds: Int,
        generation: UInt,
        playing: Bool,
        videoSize: CGSize?
    ) {}
}

private enum PendingSubtitleAction {
    case preserve
    case replace(PlaybackSubtitleSource?)
}

private struct PreparedVideoFirstFrame {
    let rawMilliseconds: Int
    let alignedMilliseconds: Int
    let videoSize: CGSize?
}

private enum PendingPresentationCommitReason {
    case immediateNoSubtitle
    case immediateHidden
    case synchronizedReady
    case subtitleLoadFailed
    case subtitleWaitTimedOut
}

private struct PendingPresentation {
    let transitionID: UUID
    var generation: UInt?
    let trigger: PlaybackSubtitleFirstFrameTrigger
    let targetMilliseconds: Int
    let heldMilliseconds: Int
    var subtitleAction: PendingSubtitleAction
    var stagedSubtitleFailedURL: URL?
    var preparedVideoFrame: PreparedVideoFirstFrame?
    let startedAt: CFTimeInterval
    var resolve302Milliseconds: Double
}

private struct PlaybackAutoPauseAuthorization: Equatable {
    let boundary: PlaybackAutoStopBoundary
    let presentationGeneration: UInt
}

public final class PlaybackPlayer: NSObject, @unchecked Sendable {
    private let nativePlayer = SFXNativePlaybackPlayer()
    private var currentRequest: PlaybackRequest?
    private var storedVolume: Double = 100
    private var storedSpeed: Double = 1.0
    private var subtitlesVisible = true
    private var activeSubtitleSource: PlaybackSubtitleSource?
    private var assSubtitleRenderTimeGate: PlaybackSubtitleRenderTimeGate?
    private var subtitleRenderTickTask: Task<Void, Never>?
    private var heldSubtitlePresentationMilliseconds: Int?
    private var lastRenderedASSSubtitleMilliseconds = 0
    private var pendingPresentation: PendingPresentation?
    private var committedPresentationGeneration: UInt?
    private var lastCommittedVideoSize: CGSize?
    private var subtitleWaitTimeoutTask: Task<Void, Never>?
    private var pendingManualSubtitleSwitchSource: PlaybackSubtitleSource?
    private var isEvaluatingPendingPresentationGate = false
    internal var subtitleFirstFrameWaitTimeoutSeconds: TimeInterval = 1.0
    private var reachedAutoStopBoundaryMilliseconds: Int?
    private var persistentAutoPauseBoundary: PlaybackAutoStopBoundary?
    private var autoPauseAuthorization: PlaybackAutoPauseAuthorization?
    private let autoPauseAuthorizationLock = NSLock()
    private var activeSubtitleFirstFrameAttempt: PlaybackSubtitleFirstFrameAttempt?
    private let subtitleFirstFrameAttemptLock = NSLock()

    public weak var delegate: PlaybackPlayerDelegate?

    public private(set) var currentVideoURL: URL?
    private var lastOpenedVideoURL: URL?
    public var currentSubtitleURL: URL? {
        if let pendingPresentation {
            switch pendingPresentation.subtitleAction {
            case .preserve:
                break
            case .replace(let source):
                return source?.url.standardizedMediaURL
            }
        }
        return activeSubtitleSource?.url.standardizedMediaURL
    }
    public var usingHardwareDecode: Bool {
        nativePlayer.usingHardwareDecode
    }
    public var activeDecodeMode: PlaybackDecodeMode {
        PlaybackDecodeMode(nativeDecodeMode: nativePlayer.activeDecodeMode)
    }
    public var decodeMode: PlaybackDecodeMode = .auto {
        didSet {
            nativePlayer.decodeMode = decodeMode.nativeDecodeMode
        }
    }

    public var srtSubtitleStyle = SRTSubtitleStyle() {
        didSet {
            guard oldValue != srtSubtitleStyle else {
                return
            }
            let style = srtSubtitleStyle
            Task { @MainActor in
                (self.renderView as? PlaybackRenderContainerView)?.setSRTSubtitleStyle(style)
            }
        }
    }

    @MainActor public lazy var renderView: NSView = PlaybackRenderContainerView()

    public override init() {
        super.init()
        Self.installDebugTelemetryHandlerIfNeeded()
        nativePlayer.delegate = self
        nativePlayer.defersFirstFramePresentationCommit = true
        nativePlayer.volume = Float(storedVolume / 100)
        nativePlayer.decodeMode = decodeMode.nativeDecodeMode
    }

    public static func warmUpSubtitleEnvironment() {
        ASSFontAliasResolver.shared.warmUp()
        SFXASSRenderer.warmUpFontEnvironment()
    }

    public static func warmUpSubtitleEnvironmentInBackground() {
        DispatchQueue.global(qos: .utility).async {
            warmUpSubtitleEnvironment()
        }
    }

    internal static var assEngineInitializationCountForTesting: Int {
        Int(SFXASSRenderer.engineInitializationCountForTesting())
    }

    internal static func resetASSEnginePoolForTesting() {
        SFXASSRenderer.resetFontEnvironmentPoolForTesting()
    }

    public static func setHDRScreenshotEnabled(_ enabled: Bool) {
        Self.installDebugTelemetryHandlerIfNeeded()
        SFXSetHDRScreenshotEnabled(enabled)
    }

    public static var isHDRScreenshotEnabled: Bool {
        SFXIsHDRScreenshotEnabled()
    }

    private static let debugTelemetryInstallOnce: Void = {
        SFXSetDebugTelemetryLogHandler { event, details in
            switch event {
            case "playback.stream.color_state":
                AppLogger.shared.info(.playback, event, details: details)
            case "playback.hardware_decode.fallback",
                 "playback.static_image.slow_render":
                AppLogger.shared.warn(.playback, event, details: details)
            case "playback.diagnostics.open_prepare":
                if details?.contains("slow_open=true") == true {
                    AppLogger.shared.warn(.playback, event, details: details)
                } else {
                    AppLogger.shared.debug(.playback, event, details: details)
                }
            case "playback.diagnostics.first_frame":
                if details?.contains("slow_first_frame=true") == true {
                    AppLogger.shared.warn(.playback, event, details: details)
                } else {
                    AppLogger.shared.debug(.playback, event, details: details)
                }
            case "playback.diagnostics.seek":
                if details?.contains("slow_seek=true") == true {
                    AppLogger.shared.warn(.playback, event, details: details)
                } else {
                    AppLogger.shared.debug(.playback, event, details: details)
                }
            default:
                AppLogger.shared.debug(.playback, event, details: details)
            }
        }
    }()

    private static func installDebugTelemetryHandlerIfNeeded() {
        _ = debugTelemetryInstallOnce
    }

    @discardableResult
    public func open(_ request: PlaybackRequest) throws -> UInt {
        nativePlayer.cancelTimelineThumbnailRequests()
        delegate?.playerDidResetTimelineThumbnails(self)
        reachedAutoStopBoundaryMilliseconds = nil
        let autoPauseBoundary = request.autoStopAtMilliseconds.map {
            PlaybackAutoStopBoundary(
                startMilliseconds: request.startMilliseconds,
                endMilliseconds: $0
            )
        }
        replacePersistentAutoPauseBoundary(autoPauseBoundary)
        beginPresentationTransition(
            trigger: .newVideoOpen,
            targetMilliseconds: request.startMilliseconds,
            subtitleAction: .replace(request.subtitleSource)
        )
        let expectedGeneration = nativePlayer.nativePresentationGeneration &+ 1
        authorizeAutoPauseBoundary(
            autoPauseBoundary,
            generation: expectedGeneration
        )
        currentRequest = request
        nativePlayer.playbackRate = Float(storedSpeed)
        nativePlayer.audioTrackIndex = request.audioTrackIndex
        let resolveStart = CACurrentMediaTime()
        let playableInput = WebDAVClient.shared.resolvePlayableInput(for: request.videoURL)
        let resolveElapsedMs = (CACurrentMediaTime() - resolveStart) * 1000.0
        pendingPresentation?.resolve302Milliseconds = resolveElapsedMs
        nativePlayer.httpHeaders = playableInput.httpHeaders
        do {
            if let autoStopAtMilliseconds = request.autoStopAtMilliseconds {
                try nativePlayer.openPath(
                    playableInput.inputPath,
                    startMilliseconds: request.startMilliseconds,
                    autoStopAtMilliseconds: autoStopAtMilliseconds
                )
            } else if let segmentEndMilliseconds = request.segmentEndMilliseconds {
                try nativePlayer.openPath(
                    playableInput.inputPath,
                    startMilliseconds: request.startMilliseconds,
                    endMilliseconds: segmentEndMilliseconds
                )
            } else {
                try nativePlayer.openPath(
                    playableInput.inputPath,
                    startMilliseconds: request.startMilliseconds
                )
            }
        } catch {
            cancelPendingPresentation()
            throw error
        }
        let generation = bindPendingPresentationToNativeGeneration()
        authorizeAutoPauseBoundary(autoPauseBoundary, generation: generation)
        let standardizedURL = request.videoURL.standardizedMediaURL
        currentVideoURL = standardizedURL
        lastOpenedVideoURL = standardizedURL
        Task { @MainActor in
            self.attachActiveRenderView()
        }
        emitInitialNativeState()
        return generation
    }

    @discardableResult
    public func seek(toMilliseconds milliseconds: Int) throws -> UInt {
        try seek(
            toMilliseconds: milliseconds,
            pauseAfterFirstFrame: false,
            subtitleAction: .preserve
        )
    }

    @discardableResult
    public func seek(
        toMilliseconds milliseconds: Int,
        subtitleSource: PlaybackSubtitleSource?
    ) throws -> UInt {
        try seek(
            toMilliseconds: milliseconds,
            pauseAfterFirstFrame: false,
            subtitleAction: .replace(subtitleSource)
        )
    }

    @discardableResult
    public func seek(to segment: PlaybackSegment) throws -> UInt {
        try seek(to: segment, pauseAfterFirstFrame: false, subtitleAction: .preserve)
    }

    @discardableResult
    public func seek(to boundary: PlaybackAutoStopBoundary) throws -> UInt {
        try seek(
            to: boundary,
            subtitleAction: .preserve
        )
    }

    @discardableResult
    public func seek(
        to boundary: PlaybackAutoStopBoundary,
        subtitleSource: PlaybackSubtitleSource?
    ) throws -> UInt {
        try seek(
            to: boundary,
            subtitleAction: .replace(subtitleSource)
        )
    }

    @discardableResult
    public func seek(
        to segment: PlaybackSegment,
        subtitleSource: PlaybackSubtitleSource?
    ) throws -> UInt {
        try seek(
            to: segment,
            pauseAfterFirstFrame: false,
            subtitleAction: .replace(subtitleSource)
        )
    }

    @discardableResult
    public func seek(toMilliseconds milliseconds: Int, pauseAfterFirstFrame: Bool) throws -> UInt {
        try seek(
            toMilliseconds: milliseconds,
            pauseAfterFirstFrame: pauseAfterFirstFrame,
            subtitleAction: .preserve
        )
    }

    @discardableResult
    public func seek(to segment: PlaybackSegment, pauseAfterFirstFrame: Bool) throws -> UInt {
        try seek(
            to: segment,
            pauseAfterFirstFrame: pauseAfterFirstFrame,
            subtitleAction: .preserve
        )
    }

    public func cancelPendingPresentation() {
        subtitleWaitTimeoutTask?.cancel()
        subtitleWaitTimeoutTask = nil
        pendingPresentation = nil
        cancelActiveSubtitleFirstFrameTelemetry()
        runOnMainActor {
            (self.renderView as? PlaybackRenderContainerView)?.cancelStagedSubtitlePresentation(
                restoringActiveSource: self.activeSubtitleSource,
                videoSize: self.currentNativeVideoSize() ?? self.lastCommittedVideoSize,
                milliseconds: self.lastRenderedASSSubtitleMilliseconds,
                isVisible: self.subtitlesVisible
            )
        }
    }

    @discardableResult
    private func seek(
        toMilliseconds milliseconds: Int,
        pauseAfterFirstFrame: Bool,
        subtitleAction: PendingSubtitleAction
    ) throws -> UInt {
        reachedAutoStopBoundaryMilliseconds = nil
        let safeMilliseconds = max(0, milliseconds)
        AppLogger.shared.info(
            .playback,
            "Player seek requested",
            details: "video=\"\(currentVideoURL?.lastPathComponent ?? "none")\" target_ms=\(safeMilliseconds) hw_decode=\(nativePlayer.usingHardwareDecode ? 1 : 0)"
        )
        beginPresentationTransition(
            trigger: .sameVideoSeek,
            targetMilliseconds: safeMilliseconds,
            subtitleAction: subtitleAction
        )
        let persistentBoundary = currentPersistentAutoPauseBoundary()
        let autoPauseBoundary = persistentBoundary.flatMap {
            safeMilliseconds < $0.endMilliseconds ? $0 : nil
        }
        let previousAuthorization = currentAutoPauseAuthorization()
        let expectedGeneration = nativePlayer.nativePresentationGeneration &+ 1
        authorizeAutoPauseBoundary(
            autoPauseBoundary,
            generation: expectedGeneration
        )
        do {
            if let autoPauseBoundary {
                try nativePlayer.seek(
                    toMilliseconds: safeMilliseconds,
                    autoStopAtMilliseconds: autoPauseBoundary.endMilliseconds,
                    pauseAfterFirstFrame: pauseAfterFirstFrame
                )
            } else {
                try nativePlayer.seek(
                    toMilliseconds: safeMilliseconds,
                    pauseAfterFirstFrame: pauseAfterFirstFrame
                )
            }
        } catch {
            restoreAutoPauseAuthorization(
                previousAuthorization,
                ifBoundaryIs: persistentBoundary
            )
            cancelPendingPresentation()
            throw error
        }
        let generation = bindPendingPresentationToNativeGeneration()
        if currentVideoURL == nil {
            currentVideoURL = lastOpenedVideoURL
        }
        authorizeAutoPauseBoundary(autoPauseBoundary, generation: generation)
        return generation
    }

    @discardableResult
    private func seek(
        to boundary: PlaybackAutoStopBoundary,
        subtitleAction: PendingSubtitleAction
    ) throws -> UInt {
        reachedAutoStopBoundaryMilliseconds = nil
        replacePersistentAutoPauseBoundary(boundary)
        AppLogger.shared.debug(
            .playback,
            "Player seek requested",
            details: "video=\"\(currentVideoURL?.lastPathComponent ?? "none")\" target_ms=\(boundary.startMilliseconds) auto_stop_ms=\(boundary.endMilliseconds) hw_decode=\(nativePlayer.usingHardwareDecode ? 1 : 0)"
        )
        beginPresentationTransition(
            trigger: .sameVideoSeek,
            targetMilliseconds: boundary.startMilliseconds,
            subtitleAction: subtitleAction
        )
        let expectedGeneration = nativePlayer.nativePresentationGeneration &+ 1
        authorizeAutoPauseBoundary(boundary, generation: expectedGeneration)
        do {
            try nativePlayer.seek(
                toMilliseconds: boundary.startMilliseconds,
                autoStopAtMilliseconds: boundary.endMilliseconds
            )
        } catch {
            cancelPendingPresentation()
            throw error
        }
        let generation = bindPendingPresentationToNativeGeneration()
        if currentVideoURL == nil {
            currentVideoURL = lastOpenedVideoURL
        }
        authorizeAutoPauseBoundary(boundary, generation: generation)
        return generation
    }

    @discardableResult
    private func seek(
        to segment: PlaybackSegment,
        pauseAfterFirstFrame: Bool,
        subtitleAction: PendingSubtitleAction
    ) throws -> UInt {
        reachedAutoStopBoundaryMilliseconds = nil
        replacePersistentAutoPauseBoundary(nil)
        beginPresentationTransition(
            trigger: .sameVideoSeek,
            targetMilliseconds: segment.startMilliseconds,
            subtitleAction: subtitleAction
        )
        do {
            try nativePlayer.seek(
                toMilliseconds: segment.startMilliseconds,
                endMilliseconds: segment.endMilliseconds,
                pauseAfterFirstFrame: pauseAfterFirstFrame
            )
        } catch {
            cancelPendingPresentation()
            throw error
        }
        let generation = bindPendingPresentationToNativeGeneration()
        if currentVideoURL == nil {
            currentVideoURL = lastOpenedVideoURL
        }
        return generation
    }

    private func replaceActiveSubtitleFirstFrameAttempt(
        _ nextAttempt: PlaybackSubtitleFirstFrameAttempt?
    ) {
        subtitleFirstFrameAttemptLock.lock()
        let previous = activeSubtitleFirstFrameAttempt
        activeSubtitleFirstFrameAttempt = nextAttempt
        subtitleFirstFrameAttemptLock.unlock()
        previous?.cancel()
    }

    private func cancelActiveSubtitleFirstFrameTelemetry() {
        replaceActiveSubtitleFirstFrameAttempt(nil)
    }

    private func currentActiveSubtitleFirstFrameAttempt() -> PlaybackSubtitleFirstFrameAttempt? {
        subtitleFirstFrameAttemptLock.lock()
        defer { subtitleFirstFrameAttemptLock.unlock() }
        return activeSubtitleFirstFrameAttempt
    }

    private func runOnMainActor(_ operation: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                operation()
            }
        } else {
            Task { @MainActor in
                operation()
            }
        }
    }

    private func resolvedSubtitleSource(for action: PendingSubtitleAction) -> PlaybackSubtitleSource? {
        switch action {
        case .preserve:
            return activeSubtitleSource
        case .replace(let source):
            return source
        }
    }

    private func beginPresentationTransition(
        trigger: PlaybackSubtitleFirstFrameTrigger,
        targetMilliseconds: Int,
        subtitleAction: PendingSubtitleAction
    ) {
        subtitleWaitTimeoutTask?.cancel()
        subtitleWaitTimeoutTask = nil
        pendingManualSubtitleSwitchSource = nil
        cancelActiveSubtitleFirstFrameTelemetry()

        let safeTargetMilliseconds = max(0, targetMilliseconds)
        let startedAt = CACurrentMediaTime()
        let heldMilliseconds = pendingPresentation?.heldMilliseconds
            ?? heldSubtitlePresentationMilliseconds
            ?? lastRenderedASSSubtitleMilliseconds
        let resolvedSubtitleAction: PendingSubtitleAction
        switch (pendingPresentation?.subtitleAction, subtitleAction) {
        case (.replace(let pendingSource), .preserve):
            let retargetedSource = pendingSource.map {
                PlaybackSubtitleSource(
                    url: $0.url,
                    format: $0.format,
                    matchedVideoURL: $0.matchedVideoURL,
                    initialTimestampMilliseconds: safeTargetMilliseconds,
                    preparationTimeWindow: nil,
                    renderCacheProvider: $0.renderCacheProvider
                )
            }
            resolvedSubtitleAction = .replace(retargetedSource)
        default:
            resolvedSubtitleAction = subtitleAction
        }

        let transitionID = UUID()
        pendingPresentation = PendingPresentation(
            transitionID: transitionID,
            generation: nil,
            trigger: trigger,
            targetMilliseconds: safeTargetMilliseconds,
            heldMilliseconds: max(0, heldMilliseconds),
            subtitleAction: resolvedSubtitleAction,
            stagedSubtitleFailedURL: nil,
            preparedVideoFrame: nil,
            startedAt: startedAt,
            resolve302Milliseconds: 0
        )

        let targetSubtitleSource = resolvedSubtitleSource(for: resolvedSubtitleAction)
        let expectedGeneration = nativePlayer.nativePresentationGeneration &+ 1
        let telemetryAttempt: PlaybackSubtitleFirstFrameAttempt?
        if let targetSubtitleSource, subtitlesVisible {
            let attempt = PlaybackSubtitleFirstFrameAttempt(
                trigger: trigger,
                source: targetSubtitleSource,
                targetMilliseconds: safeTargetMilliseconds,
                presentationGeneration: expectedGeneration,
                startedAt: startedAt,
                videoCommittedAt: nil
            )
            replaceActiveSubtitleFirstFrameAttempt(attempt)
            telemetryAttempt = attempt
        } else {
            telemetryAttempt = nil
        }

        runOnMainActor { [weak self] in
            self?.stagePendingPresentationSubtitle(
                transitionID: transitionID,
                telemetryAttempt: telemetryAttempt
            )
        }
    }

    private func bindPendingPresentationToNativeGeneration() -> UInt {
        let generation = nativePlayer.nativePresentationGeneration
        pendingPresentation?.generation = generation
        currentActiveSubtitleFirstFrameAttempt()?.bindPresentationGeneration(generation)
        if let transitionID = pendingPresentation?.transitionID,
           pendingPresentation?.preparedVideoFrame != nil {
            runOnMainActor { [weak self] in
                self?.evaluatePendingPresentationGateIfNeeded(transitionID: transitionID)
            }
        }
        return generation
    }

    public func beginTimelineScrubbing() throws {
        clearSubtitlePresentationHold()
        try nativePlayer.setTimelineScrubbing(true)
    }

    public func keyframeTimestampMilliseconds(forTargetMilliseconds milliseconds: Int) -> Int? {
        let resolved = nativePlayer.keyframeTimestampMilliseconds(
            forTargetMilliseconds: max(0, milliseconds)
        )
        return resolved >= 0 ? resolved : nil
    }

    public func requestTimelineThumbnail(
        atMilliseconds milliseconds: Int,
        targetPixelWidth: Int,
        completion: @escaping @MainActor (CGImage?, Int, CGSize?) -> Void
    ) {
        let safeMilliseconds = max(0, milliseconds)
        let safePixelWidth = max(1, targetPixelWidth)
        nativePlayer.requestTimelineThumbnail(
            atMilliseconds: safeMilliseconds,
            targetPixelWidth: safePixelWidth
        ) { image, keyframeMilliseconds, videoWidth, videoHeight in
            let videoSize: CGSize? = (videoWidth > 0 && videoHeight > 0)
                ? CGSize(width: videoWidth, height: videoHeight)
                : nil
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    completion(image, keyframeMilliseconds, videoSize)
                }
            } else {
                Task { @MainActor in
                    completion(image, keyframeMilliseconds, videoSize)
                }
            }
        }
    }

    public func cancelTimelineThumbnailRequests() {
        nativePlayer.cancelTimelineThumbnailRequests()
    }

    public func invalidateTimelineThumbnailCache() {
        nativePlayer.invalidateTimelineThumbnailCache()
        delegate?.playerDidResetTimelineThumbnails(self)
    }

    public func endTimelineScrubbing() throws {
        try nativePlayer.setTimelineScrubbing(false)
    }

    public func setPaused(_ isPaused: Bool) throws {
        if !isPaused, let resumeMilliseconds = reachedAutoStopBoundaryMilliseconds {
            reachedAutoStopBoundaryMilliseconds = nil
            _ = try seek(
                toMilliseconds: resumeMilliseconds,
                pauseAfterFirstFrame: false,
                subtitleAction: .preserve
            )
            return
        }
        try nativePlayer.setPaused(isPaused)
        if !isPaused {
            startASSSubtitleRenderTicks()
        }
    }

    /// The audio track the open video is playing, counted from 0 among its
    /// audio streams; nil when nothing is open or the video has no audio.
    public var currentAudioTrackIndex: Int? {
        let index = nativePlayer.currentAudioTrackIndex
        return index >= 0 ? index : nil
    }

    /// Plays another audio track of the open video from where it stands.
    public func selectAudioTrack(at index: Int) throws {
        try nativePlayer.selectAudioTrackIndex(index)
    }

    public func setAutoPauseBoundary(_ boundary: PlaybackAutoStopBoundary?) {
        replacePersistentAutoPauseBoundary(boundary)
        if reachedAutoStopBoundaryMilliseconds != boundary?.endMilliseconds {
            reachedAutoStopBoundaryMilliseconds = nil
        }
    }

    public func stop() throws {
        subtitleWaitTimeoutTask?.cancel()
        subtitleWaitTimeoutTask = nil
        pendingManualSubtitleSwitchSource = nil
        nativePlayer.stop()
        delegate?.playerDidResetTimelineThumbnails(self)
        cancelActiveSubtitleFirstFrameTelemetry()
        currentRequest = nil
        currentVideoURL = nil
        lastOpenedVideoURL = nil
        pendingPresentation = nil
        committedPresentationGeneration = nil
        lastCommittedVideoSize = nil
        reachedAutoStopBoundaryMilliseconds = nil
        replacePersistentAutoPauseBoundary(nil)
        clearHeldSubtitlePresentationWithoutRendering()
        runOnMainActor {
            self.clearSubtitleSourceAfterStop()
        }
        emitPauseState(isPaused: true)
    }

    private func replacePersistentAutoPauseBoundary(
        _ boundary: PlaybackAutoStopBoundary?
    ) {
        autoPauseAuthorizationLock.lock()
        persistentAutoPauseBoundary = boundary
        autoPauseAuthorization = nil
        autoPauseAuthorizationLock.unlock()
    }

    private func currentPersistentAutoPauseBoundary() -> PlaybackAutoStopBoundary? {
        autoPauseAuthorizationLock.lock()
        defer { autoPauseAuthorizationLock.unlock() }
        return persistentAutoPauseBoundary
    }

    private func currentAutoPauseAuthorization() -> PlaybackAutoPauseAuthorization? {
        autoPauseAuthorizationLock.lock()
        defer { autoPauseAuthorizationLock.unlock() }
        return autoPauseAuthorization
    }

    private func restoreAutoPauseAuthorization(
        _ authorization: PlaybackAutoPauseAuthorization?,
        ifBoundaryIs boundary: PlaybackAutoStopBoundary?
    ) {
        autoPauseAuthorizationLock.lock()
        defer { autoPauseAuthorizationLock.unlock() }
        autoPauseAuthorization = persistentAutoPauseBoundary == boundary
            ? authorization
            : nil
    }

    private func authorizeAutoPauseBoundary(
        _ boundary: PlaybackAutoStopBoundary?,
        generation: UInt
    ) {
        autoPauseAuthorizationLock.lock()
        defer { autoPauseAuthorizationLock.unlock() }
        guard persistentAutoPauseBoundary == boundary,
              let boundary
        else {
            autoPauseAuthorization = nil
            return
        }
        autoPauseAuthorization = PlaybackAutoPauseAuthorization(
            boundary: boundary,
            presentationGeneration: generation
        )
    }

    public func loadSubtitleSource(_ source: PlaybackSubtitleSource?) {
        if let pending = pendingPresentation {
            subtitleWaitTimeoutTask?.cancel()
            subtitleWaitTimeoutTask = nil
            pendingPresentation?.subtitleAction = .replace(source)
            pendingPresentation?.stagedSubtitleFailedURL = nil
            let targetMilliseconds = pending.preparedVideoFrame?.alignedMilliseconds ?? pending.targetMilliseconds
            let telemetryAttempt: PlaybackSubtitleFirstFrameAttempt?
            if let source, subtitlesVisible {
                let attempt = PlaybackSubtitleFirstFrameAttempt(
                    trigger: pending.trigger,
                    source: source,
                    targetMilliseconds: targetMilliseconds,
                    presentationGeneration: pending.generation,
                    startedAt: CACurrentMediaTime(),
                    videoCommittedAt: nil
                )
                replaceActiveSubtitleFirstFrameAttempt(attempt)
                telemetryAttempt = attempt
            } else {
                cancelActiveSubtitleFirstFrameTelemetry()
                telemetryAttempt = nil
            }
            let transitionID = pending.transitionID
            runOnMainActor { [weak self] in
                guard let self else {
                    telemetryAttempt?.cancel()
                    return
                }
                self.stagePendingPresentationSubtitle(
                    transitionID: transitionID,
                    telemetryAttempt: telemetryAttempt
                )
                self.evaluatePendingPresentationGateIfNeeded(transitionID: transitionID)
            }
            return
        }

        cancelActiveSubtitleFirstFrameTelemetry()
        activeSubtitleSource = source

        guard let source else {
            pendingManualSubtitleSwitchSource = nil
            assSubtitleRenderTimeGate = nil
            stopASSSubtitleRenderTicks()
            runOnMainActor { [weak self] in
                (self?.renderView as? PlaybackRenderContainerView)?.clearSubtitleSourceImmediately()
            }
            return
        }

        let fallbackMilliseconds = effectiveASSSubtitleMilliseconds(
            currentNativePlaybackMilliseconds()
        )
        let initialMilliseconds = source.initialRenderTimestamp(
            fallbackMilliseconds: fallbackMilliseconds
        )
        assSubtitleRenderTimeGate = PlaybackSubtitleRenderTimeGate(
            source: source,
            fallbackMilliseconds: fallbackMilliseconds
        )

        guard subtitlesVisible else {
            pendingManualSubtitleSwitchSource = nil
            runOnMainActor { [weak self] in
                guard let self,
                      self.activeSubtitleSource == source,
                      let container = self.renderView as? PlaybackRenderContainerView
                else {
                    return
                }
                self.installContainerHandlers(on: container)
                _ = container.commitSubtitlePresentation(
                    source: source,
                    videoSize: self.currentNativeVideoSize() ?? self.lastCommittedVideoSize,
                    milliseconds: initialMilliseconds,
                    isVisible: false,
                    telemetryAttempt: nil
                )
                self.lastRenderedASSSubtitleMilliseconds = initialMilliseconds
            }
            return
        }

        pendingManualSubtitleSwitchSource = source
        let telemetryAttempt = PlaybackSubtitleFirstFrameAttempt(
            trigger: .manualSubtitleSwitch,
            source: source,
            targetMilliseconds: initialMilliseconds,
            presentationGeneration: committedPresentationGeneration,
            videoCommittedAt: nil
        )
        replaceActiveSubtitleFirstFrameAttempt(telemetryAttempt)

        runOnMainActor { [weak self] in
            guard let self,
                  self.activeSubtitleSource == source,
                  self.pendingManualSubtitleSwitchSource == source,
                  let container = self.renderView as? PlaybackRenderContainerView
            else {
                telemetryAttempt.cancel()
                return
            }

            self.installContainerHandlers(on: container)
            let videoSize = self.currentNativeVideoSize() ?? self.lastCommittedVideoSize
            container.stageManualSubtitleSwitch(
                to: source,
                videoSize: videoSize,
                milliseconds: initialMilliseconds,
                telemetryAttempt: telemetryAttempt
            )
            self.lastRenderedASSSubtitleMilliseconds = initialMilliseconds
            self.completeManualSubtitleSwitchIfReady()
        }
        startASSSubtitleRenderTicks()
    }

    deinit {
        subtitleRenderTickTask?.cancel()
        subtitleWaitTimeoutTask?.cancel()
    }

    public func setSubtitlesVisible(_ isVisible: Bool) {
        subtitlesVisible = isVisible
        if isVisible {
            if let pending = pendingPresentation {
                let targetMilliseconds = pending.preparedVideoFrame?.alignedMilliseconds ?? pending.targetMilliseconds
                let targetSource = resolvedSubtitleSource(for: pending.subtitleAction)
                let telemetryAttempt: PlaybackSubtitleFirstFrameAttempt?
                if let targetSource {
                    let attempt = PlaybackSubtitleFirstFrameAttempt(
                        trigger: pending.trigger,
                        source: targetSource,
                        targetMilliseconds: targetMilliseconds,
                        presentationGeneration: pending.generation,
                        startedAt: CACurrentMediaTime(),
                        videoCommittedAt: nil
                    )
                    replaceActiveSubtitleFirstFrameAttempt(attempt)
                    telemetryAttempt = attempt
                } else {
                    telemetryAttempt = nil
                }
                let transitionID = pending.transitionID
                runOnMainActor { [weak self] in
                    guard let self else {
                        telemetryAttempt?.cancel()
                        return
                    }
                    self.stagePendingPresentationSubtitle(
                        transitionID: transitionID,
                        telemetryAttempt: telemetryAttempt
                    )
                    self.evaluatePendingPresentationGateIfNeeded(transitionID: transitionID)
                }
                return
            }
            startASSSubtitleRenderTicks()
            runOnMainActor { [weak self] in
                (self?.renderView as? PlaybackRenderContainerView)?.setSubtitlesVisible(true)
            }
        } else {
            pendingManualSubtitleSwitchSource = nil
            subtitleWaitTimeoutTask?.cancel()
            subtitleWaitTimeoutTask = nil
            cancelActiveSubtitleFirstFrameTelemetry()
            stopASSSubtitleRenderTicks()
            let transitionID = pendingPresentation?.transitionID
            runOnMainActor { [weak self] in
                guard let self else { return }
                (self.renderView as? PlaybackRenderContainerView)?.setSubtitlesVisible(false)
                if let transitionID {
                    self.evaluatePendingPresentationGateIfNeeded(transitionID: transitionID)
                }
            }
        }
    }

    @MainActor
    public func captureScreenshotPresentation() -> PlaybackScreenshotPresentation? {
        guard let nativeSnapshot = nativePlayer.latestSubmittedVideoFrameSnapshot else {
            return nil
        }

        guard let container = renderView as? PlaybackRenderContainerView else {
            return PlaybackScreenshotPresentation(
                nativeSnapshot: nativeSnapshot,
                assSubtitleFrame: nil,
                srtSubtitleImage: nil
            )
        }

        return PlaybackScreenshotPresentation(
            nativeSnapshot: nativeSnapshot,
            assSubtitleFrame: container.currentASSSubtitleFrame(),
            srtSubtitleImage: container.currentSRTSubtitleImage()
        )
    }

    public func holdSubtitlePresentation(atMilliseconds milliseconds: Int) {
        let safeMilliseconds = max(0, milliseconds)
        heldSubtitlePresentationMilliseconds = safeMilliseconds
        updateASSSubtitleTime(milliseconds: safeMilliseconds)
    }

    public func clearSubtitlePresentationHold() {
        guard heldSubtitlePresentationMilliseconds != nil else {
            return
        }

        clearHeldSubtitlePresentationWithoutRendering()
        updateASSSubtitleTimeFromNative(milliseconds: currentNativePlaybackMilliseconds())
    }

    public func currentTimePosition() -> Double {
        nativePlayer.currentTime
    }

    public func duration() -> Double {
        nativePlayer.duration
    }

    public func volume() -> Double {
        storedVolume
    }

    internal var nativeAudioMainMixerOutputVolumeForTesting: Float {
        nativePlayer.nativeAudioMainMixerOutputVolume
    }

    public func setVolume(_ value: Double) {
        storedVolume = min(max(value, 0), 100)
        nativePlayer.volume = Float(storedVolume / 100)
        delegate?.player(self, didUpdateVolume: storedVolume)
    }

    public func playbackSpeed() -> Double {
        storedSpeed
    }

    public func setPlaybackSpeed(_ value: Double) {
        storedSpeed = min(max(value, 0.5), 3.0)
        nativePlayer.playbackRate = Float(storedSpeed)
        startASSSubtitleRenderTicks()
        delegate?.player(self, didUpdatePlaybackSpeed: storedSpeed)
    }

    public func videoAspectRatio() -> Double? {
        currentNativeVideoAspectRatio()
    }

    public func isPausedState() -> Bool {
        !nativePlayer.isPlaying
    }

    public func isSubtitleTrackEnabled() -> Bool {
        subtitlesVisible && activeSubtitleSource != nil
    }

    @MainActor public func attachActiveRenderView() {
        guard let container = renderView as? PlaybackRenderContainerView else {
            return
        }

        container.attach(nativePlayer.view)
        if pendingPresentation == nil && pendingManualSubtitleSwitchSource == nil {
            container.setSubtitlesVisible(subtitlesVisible)
        }
    }

    @MainActor private func currentNativeVideoSize() -> CGSize? {
        let width = nativePlayer.videoWidth
        let height = nativePlayer.videoHeight
        guard width > 0, height > 0 else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    private func currentNativeVideoAspectRatio() -> Double? {
        let width = nativePlayer.videoWidth
        let height = nativePlayer.videoHeight
        guard width > 0, height > 0 else {
            return nil
        }

        return Double(width) / Double(height)
    }

    private func updateASSSubtitleTime(milliseconds: Int) {
        guard pendingPresentation == nil else {
            return
        }
        let effectiveMilliseconds = effectiveASSSubtitleMilliseconds(milliseconds)
        retargetASSSubtitleRenderTimeGate(forExplicitMilliseconds: effectiveMilliseconds)
        Task { @MainActor in
            guard self.pendingPresentation == nil else {
                return
            }
            (self.renderView as? PlaybackRenderContainerView)?.setSubtitleTime(
                milliseconds: effectiveMilliseconds,
                targetFormatOnly: self.pendingManualSubtitleSwitchSource?.format
            )
            self.lastRenderedASSSubtitleMilliseconds = effectiveMilliseconds
        }
    }

    private func updateASSSubtitleTimeFromNative(milliseconds: Int) {
        guard pendingPresentation == nil else {
            return
        }
        let effectiveMilliseconds = renderedASSSubtitleMilliseconds(
            forNativeMilliseconds: milliseconds
        )
        Task { @MainActor in
            guard self.pendingPresentation == nil else {
                return
            }
            (self.renderView as? PlaybackRenderContainerView)?.setSubtitleTime(
                milliseconds: effectiveMilliseconds,
                targetFormatOnly: self.pendingManualSubtitleSwitchSource?.format
            )
            self.lastRenderedASSSubtitleMilliseconds = effectiveMilliseconds
        }
    }

    private func currentNativePlaybackMilliseconds() -> Int {
        PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: nativePlayer.currentTime)
    }

    private func effectiveASSSubtitleMilliseconds(_ milliseconds: Int) -> Int {
        pendingPresentation?.heldMilliseconds
            ?? heldSubtitlePresentationMilliseconds
            ?? max(0, milliseconds)
    }

    private func retargetASSSubtitleRenderTimeGate(forExplicitMilliseconds milliseconds: Int) {
        guard let assSubtitleRenderTimeGate else {
            return
        }

        self.assSubtitleRenderTimeGate = assSubtitleRenderTimeGate.retargetingHeldTimestamp(
            forExplicitMilliseconds: milliseconds
        )
    }

    private func renderedASSSubtitleMilliseconds(forNativeMilliseconds milliseconds: Int) -> Int {
        let effectiveMilliseconds = effectiveASSSubtitleMilliseconds(milliseconds)
        guard let assSubtitleRenderTimeGate else {
            return effectiveMilliseconds
        }

        let decision = assSubtitleRenderTimeGate.renderTimestamp(
            forNativeMilliseconds: effectiveMilliseconds
        )
        if decision.releasesGate {
            self.assSubtitleRenderTimeGate = nil
        }
        return decision.timestampMilliseconds
    }

    private func clearHeldSubtitlePresentationWithoutRendering() {
        heldSubtitlePresentationMilliseconds = nil
    }

    private func startASSSubtitleRenderTicks() {
        subtitleRenderTickTask?.cancel()
        guard activeSubtitleSource != nil, subtitlesVisible else {
            subtitleRenderTickTask = nil
            return
        }
        subtitleRenderTickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self,
                      self.activeSubtitleSource != nil,
                      self.subtitlesVisible
                else {
                    return
                }

                guard self.pendingPresentation == nil, self.nativePlayer.isPlaying else {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }

                let milliseconds = self.renderedASSSubtitleMilliseconds(
                    forNativeMilliseconds: self.currentNativePlaybackMilliseconds()
                )
                let container = self.renderView as? PlaybackRenderContainerView
                if milliseconds != self.lastRenderedASSSubtitleMilliseconds {
                    container?.setSubtitleTime(
                        milliseconds: milliseconds,
                        targetFormatOnly: self.pendingManualSubtitleSwitchSource?.format
                    )
                    self.lastRenderedASSSubtitleMilliseconds = milliseconds
                }

                let sleepNanoseconds: UInt64
                if self.assSubtitleRenderTimeGate != nil {
                    sleepNanoseconds = 33_000_000
                } else if let nextBoundaryMilliseconds = container?.nextScheduledSubtitleTickMilliseconds(
                    after: milliseconds
                ) {
                    let mediaDeltaMilliseconds = max(1, nextBoundaryMilliseconds - milliseconds)
                    let speed = max(0.5, self.storedSpeed)
                    let wallMilliseconds = Double(mediaDeltaMilliseconds) / speed
                    let clampedMilliseconds = min(max(wallMilliseconds, 16.0), 500.0)
                    sleepNanoseconds = UInt64(clampedMilliseconds * 1_000_000.0)
                } else {
                    sleepNanoseconds = 500_000_000
                }
                try? await Task.sleep(nanoseconds: sleepNanoseconds)
            }
        }
    }

    private func stopASSSubtitleRenderTicks() {
        subtitleRenderTickTask?.cancel()
        subtitleRenderTickTask = nil
    }

    private func emitInitialNativeState() {
        if pendingPresentation == nil {
            delegate?.player(self, didUpdateDuration: nativePlayer.duration)
            if let aspectRatio = currentNativeVideoAspectRatio() {
                delegate?.player(self, didUpdateVideoAspectRatio: aspectRatio)
            }
            delegate?.player(self, didUpdatePaused: false)
        }
        delegate?.player(self, didUpdateVolume: storedVolume)
        delegate?.player(self, didUpdatePlaybackSpeed: storedSpeed)
    }

    private func emitPauseState(isPaused: Bool) {
        delegate?.player(self, didUpdatePaused: isPaused)
    }

    @MainActor
    private func installContainerHandlers(on container: PlaybackRenderContainerView) {
        container.assRenderingFailureHandler = { [weak self] message in
            guard let self else { return }
            self.delegate?.player(self, didFailWithMessage: message)
        }
        container.subtitleSourceLoadFailureHandler = { [weak self] url in
            guard let self else { return }
            self.handleSubtitleSourceLoadFailure(url)
        }
        container.stagedSubtitleReadyHandler = { [weak self] in
            guard let self else { return }
            self.handleStagedSubtitleReady()
        }
    }

    @MainActor
    private func handleSubtitleSourceLoadFailure(_ url: URL) {
        let standardizedFailedURL = url.standardizedMediaURL
        if let pending = pendingPresentation {
            let targetSource = resolvedSubtitleSource(for: pending.subtitleAction)
            if targetSource?.url.standardizedMediaURL == standardizedFailedURL {
                pendingPresentation?.stagedSubtitleFailedURL = url
                subtitleWaitTimeoutTask?.cancel()
                subtitleWaitTimeoutTask = nil
                evaluatePendingPresentationGateIfNeeded(transitionID: pending.transitionID)
                delegate?.player(self, didFailToLoadSubtitleSource: url)
            }
            return
        }

        if let manualSource = pendingManualSubtitleSwitchSource {
            if manualSource.url.standardizedMediaURL == standardizedFailedURL {
                pendingManualSubtitleSwitchSource = nil
                (renderView as? PlaybackRenderContainerView)?.clearSubtitleSourceImmediately()
                delegate?.player(self, didFailToLoadSubtitleSource: url)
            }
            return
        }

        if activeSubtitleSource?.url.standardizedMediaURL == standardizedFailedURL {
            (renderView as? PlaybackRenderContainerView)?.clearSubtitleSourceImmediately()
            delegate?.player(self, didFailToLoadSubtitleSource: url)
        }
    }

    @MainActor
    private func handleStagedSubtitleReady() {
        if let pending = pendingPresentation {
            evaluatePendingPresentationGateIfNeeded(transitionID: pending.transitionID)
            return
        }
        completeManualSubtitleSwitchIfReady()
    }

    @MainActor
    private func completeManualSubtitleSwitchIfReady() {
        guard pendingPresentation == nil,
              let manualSource = pendingManualSubtitleSwitchSource,
              activeSubtitleSource == manualSource,
              subtitlesVisible,
              let container = renderView as? PlaybackRenderContainerView
        else {
            return
        }
        let videoSize = currentNativeVideoSize() ?? lastCommittedVideoSize
        let targetMilliseconds = container.currentSubtitleMilliseconds(for: manualSource.format)
        guard container.isStagedSubtitleReady(
            for: manualSource,
            atMilliseconds: targetMilliseconds,
            videoSize: videoSize
        ) else {
            return
        }
        pendingManualSubtitleSwitchSource = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.flushManualSubtitleSwitch(for: manualSource)
        CATransaction.commit()
    }

    @MainActor
    private func stagePendingPresentationSubtitle(
        transitionID: UUID,
        telemetryAttempt: PlaybackSubtitleFirstFrameAttempt?
    ) {
        guard let pending = pendingPresentation,
              pending.transitionID == transitionID
        else {
            telemetryAttempt?.cancel()
            return
        }
        attachActiveRenderView()
        guard let container = renderView as? PlaybackRenderContainerView else {
            telemetryAttempt?.cancel()
            return
        }
        installContainerHandlers(on: container)
        let speculativeVideoSize = pending.preparedVideoFrame?.videoSize
            ?? currentNativeVideoSize()
            ?? lastCommittedVideoSize
        let targetMilliseconds = pending.preparedVideoFrame?.alignedMilliseconds
            ?? pending.targetMilliseconds
        container.prepareStagedSubtitlePresentation(
            action: pending.subtitleAction,
            activeSource: activeSubtitleSource,
            speculativeVideoSize: speculativeVideoSize,
            targetMilliseconds: targetMilliseconds,
            isVisible: subtitlesVisible,
            telemetryAttempt: telemetryAttempt
        )
    }

    @MainActor
    private func evaluatePendingPresentationGateIfNeeded(transitionID: UUID) {
        guard !isEvaluatingPendingPresentationGate else {
            return
        }
        isEvaluatingPendingPresentationGate = true
        defer { isEvaluatingPendingPresentationGate = false }

        guard let pending = pendingPresentation,
              pending.transitionID == transitionID,
              pending.generation != nil,
              let preparedVideo = pending.preparedVideoFrame
        else {
            return
        }

        let targetSource = resolvedSubtitleSource(for: pending.subtitleAction)
        guard let targetSource else {
            commitPreparedPendingPresentation(
                transitionID: transitionID,
                reason: .immediateNoSubtitle
            )
            return
        }
        guard subtitlesVisible else {
            commitPreparedPendingPresentation(
                transitionID: transitionID,
                reason: .immediateHidden
            )
            return
        }
        if pending.stagedSubtitleFailedURL != nil {
            commitPreparedPendingPresentation(
                transitionID: transitionID,
                reason: .subtitleLoadFailed
            )
            return
        }

        guard let container = renderView as? PlaybackRenderContainerView else {
            commitPreparedPendingPresentation(
                transitionID: transitionID,
                reason: .subtitleWaitTimedOut
            )
            return
        }

        let fallbackContainerSize = (container.bounds.width > 1 && container.bounds.height > 1)
            ? container.bounds.size
            : CGSize(width: 1920, height: 1080)
        let effectiveVideoSize = preparedVideo.videoSize
            ?? currentNativeVideoSize()
            ?? lastCommittedVideoSize
            ?? fallbackContainerSize

        currentActiveSubtitleFirstFrameAttempt()?.updateTargetMilliseconds(
            preparedVideo.alignedMilliseconds
        )
        container.retargetStagedSubtitlePresentation(
            for: targetSource,
            videoSize: effectiveVideoSize,
            milliseconds: preparedVideo.alignedMilliseconds
        )
        guard self.pendingPresentation?.transitionID == transitionID else {
            return
        }
        if self.pendingPresentation?.stagedSubtitleFailedURL != nil {
            commitPreparedPendingPresentation(
                transitionID: transitionID,
                reason: .subtitleLoadFailed
            )
            return
        }
        if container.isStagedSubtitleReady(
            for: targetSource,
            atMilliseconds: preparedVideo.alignedMilliseconds,
            videoSize: effectiveVideoSize
        ) {
            commitPreparedPendingPresentation(
                transitionID: transitionID,
                reason: .synchronizedReady
            )
            return
        }

        if subtitleWaitTimeoutTask == nil {
            let timeoutSeconds = max(0.01, subtitleFirstFrameWaitTimeoutSeconds)
            let timeoutNanoseconds = UInt64((timeoutSeconds * 1_000_000_000).rounded())
            subtitleWaitTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                guard !Task.isCancelled, let self else { return }
                guard self.pendingPresentation?.transitionID == transitionID else { return }
                self.subtitleWaitTimeoutTask = nil
                self.commitPreparedPendingPresentation(
                    transitionID: transitionID,
                    reason: .subtitleWaitTimedOut
                )
            }
        }
    }

    @MainActor
    private func commitPreparedPendingPresentation(
        transitionID: UUID,
        reason: PendingPresentationCommitReason
    ) {
        guard let pending = pendingPresentation,
              pending.transitionID == transitionID,
              let generation = pending.generation,
              let preparedVideo = pending.preparedVideoFrame
        else {
            return
        }

        subtitleWaitTimeoutTask?.cancel()
        subtitleWaitTimeoutTask = nil
        self.pendingPresentation = nil

        let commitStart = CACurrentMediaTime()
        let safeMilliseconds = preparedVideo.alignedMilliseconds
        let videoSize = preparedVideo.videoSize ?? currentNativeVideoSize()
        committedPresentationGeneration = generation
        if let videoSize {
            lastCommittedVideoSize = videoSize
        }
        heldSubtitlePresentationMilliseconds = nil

        let targetSubtitleSource = resolvedSubtitleSource(for: pending.subtitleAction)
        switch pending.subtitleAction {
        case .preserve:
            retargetASSSubtitleRenderTimeGate(forExplicitMilliseconds: safeMilliseconds)
        case .replace(let source):
            activeSubtitleSource = source
            if let source {
                let initialGate = PlaybackSubtitleRenderTimeGate(
                    source: source,
                    fallbackMilliseconds: safeMilliseconds
                )
                assSubtitleRenderTimeGate = initialGate?.retargetingHeldTimestamp(
                    forExplicitMilliseconds: safeMilliseconds
                ) ?? initialGate
            } else {
                assSubtitleRenderTimeGate = nil
            }
        }
        lastRenderedASSSubtitleMilliseconds = safeMilliseconds

        let subtitleStart = CACurrentMediaTime()
        let subtitleSyncState: PlaybackSubtitleCommitSyncState
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        _ = nativePlayer.commitPreparedPresentation(forGeneration: generation)
        if let container = renderView as? PlaybackRenderContainerView {
            subtitleSyncState = container.finalizePendingPresentationSubtitleCommit(
                targetSource: targetSubtitleSource,
                videoSize: videoSize,
                milliseconds: safeMilliseconds,
                isVisible: subtitlesVisible,
                reason: reason,
                committedAt: commitStart
            )
        } else {
            cancelActiveSubtitleFirstFrameTelemetry()
            subtitleSyncState = targetSubtitleSource == nil
                ? .noSubtitle
                : (subtitlesVisible ? .asyncPending : .hidden)
        }
        CATransaction.commit()
        let subtitleCommitMs = (CACurrentMediaTime() - subtitleStart) * 1000.0

        if activeSubtitleSource != nil && subtitlesVisible {
            startASSSubtitleRenderTicks()
        } else {
            stopASSSubtitleRenderTicks()
        }

        let playing = nativePlayer.isPlaying
        delegate?.player(
            self,
            didCommitPresentationAtMilliseconds: safeMilliseconds,
            generation: generation,
            playing: playing,
            videoSize: videoSize
        )
        delegate?.player(self, didUpdateDuration: nativePlayer.duration)
        delegate?.player(self, didUpdatePaused: !playing)
        delegate?.player(
            self,
            didUpdateTimePosition: Double(safeMilliseconds) / 1_000
        )
        let now = CACurrentMediaTime()
        let totalEndToEndMs = (now - pending.startedAt) * 1000.0
        let commitElapsedMs = (now - commitStart) * 1000.0
        let videoName = (currentVideoURL ?? currentRequest?.videoURL)?.lastPathComponent ?? "none"
        AppLogger.shared.info(
            .playback,
            "Playback presentation committed",
            details: String(
                format: "video=\"%@\" gen=%lu target_ms=%ld presented_ms=%ld hw_decode=%d total_ms=%.1f resolve_ms=%.1f subtitle_ms=%.1f ui_commit_ms=%.1f subtitle_sync=%@",
                videoName,
                generation,
                pending.targetMilliseconds,
                safeMilliseconds,
                nativePlayer.usingHardwareDecode ? 1 : 0,
                totalEndToEndMs,
                pending.resolve302Milliseconds,
                subtitleCommitMs,
                commitElapsedMs,
                subtitleSyncState.rawValue
            )
        )
        PlaybackSubtitleFirstFrameTelemetry.emitPresentationCommit(
            generation: generation,
            targetMilliseconds: pending.targetMilliseconds,
            presentedMilliseconds: safeMilliseconds,
            subtitleSyncState: subtitleSyncState,
            subtitleFileName: targetSubtitleSource?.url.lastPathComponent,
            videoFileName: videoName
        )
    }

    @MainActor
    private func clearSubtitleSourceAfterStop() {
        cancelActiveSubtitleFirstFrameTelemetry()
        pendingManualSubtitleSwitchSource = nil
        activeSubtitleSource = nil
        lastRenderedASSSubtitleMilliseconds = 0
        assSubtitleRenderTimeGate = nil
        stopASSSubtitleRenderTicks()
        (renderView as? PlaybackRenderContainerView)?.clearSubtitleSourceImmediately()
    }
}

extension PlaybackPlayer: SFXNativePlaybackPlayerDelegate {
    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool
    ) {
        // The native player uses the generation-aware optional callback when
        // available. Keep the required legacy callback only for protocol
        // compatibility so untagged updates cannot cross a presentation gate.
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool,
        presentationGeneration: UInt
    ) {
        guard pendingPresentation == nil,
              committedPresentationGeneration == presentationGeneration
        else {
            return
        }
        delegate?.player(self, didUpdateTimePosition: time)
        delegate?.player(self, didUpdateDuration: duration)
        delegate?.player(self, didUpdatePaused: !playing)
        if activeSubtitleSource != nil,
           subtitlesVisible,
           (!playing || subtitleRenderTickTask == nil || assSubtitleRenderTimeGate != nil) {
            let milliseconds = PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: time)
            updateASSSubtitleTimeFromNative(milliseconds: milliseconds)
        }
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didPrepareFirstVideoFrameAtMilliseconds milliseconds: Int,
        videoWidth: Int,
        videoHeight: Int,
        presentationGeneration: UInt
    ) {
        let actualVideoSize: CGSize? = (videoWidth > 0 && videoHeight > 0)
            ? CGSize(width: videoWidth, height: videoHeight)
            : nil
        runOnMainActor { [weak self] in
            guard let self,
                  let pending = self.pendingPresentation,
                  (pending.generation == nil || pending.generation == presentationGeneration)
            else {
                return
            }
            if pending.generation == nil {
                self.pendingPresentation?.generation = presentationGeneration
                self.currentActiveSubtitleFirstFrameAttempt()?.bindPresentationGeneration(presentationGeneration)
            }
            let alignedMilliseconds = PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
                presentedMilliseconds: milliseconds,
                targetMilliseconds: pending.targetMilliseconds
            )
            self.pendingPresentation?.preparedVideoFrame = PreparedVideoFirstFrame(
                rawMilliseconds: milliseconds,
                alignedMilliseconds: alignedMilliseconds,
                videoSize: actualVideoSize ?? self.currentNativeVideoSize()
            )
            self.evaluatePendingPresentationGateIfNeeded(transitionID: pending.transitionID)
        }
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didPresentVideoFrameAtMilliseconds milliseconds: Int,
        presentationGeneration: UInt
    ) {
        guard !nativePlayer.defersFirstFramePresentationCommit else {
            return
        }
        runOnMainActor { [weak self] in
            guard let self,
                  let pending = self.pendingPresentation,
                  pending.generation == presentationGeneration
            else {
                return
            }
            let alignedMilliseconds = PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
                presentedMilliseconds: milliseconds,
                targetMilliseconds: pending.targetMilliseconds
            )
            self.pendingPresentation?.preparedVideoFrame = PreparedVideoFirstFrame(
                rawMilliseconds: milliseconds,
                alignedMilliseconds: alignedMilliseconds,
                videoSize: self.currentNativeVideoSize()
            )
            self.evaluatePendingPresentationGateIfNeeded(transitionID: pending.transitionID)
        }
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFailWithMessage message: String
    ) {
        delegate?.player(self, didFailWithMessage: message)
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFailToOpenWithError error: Error,
        presentationGeneration: UInt
    ) {
        guard pendingPresentation?.generation == presentationGeneration else {
            return
        }
        let failedURL = currentVideoURL ?? currentRequest?.videoURL
        cancelPendingPresentation()
        currentRequest = nil
        currentVideoURL = nil
        lastOpenedVideoURL = nil
        committedPresentationGeneration = nil
        lastCommittedVideoSize = nil
        runOnMainActor { [weak self] in
            self?.clearSubtitleSourceAfterStop()
        }
        if let failedURL {
            delegate?.player(self, didFailToOpenVideoAt: failedURL, error: error)
        } else {
            delegate?.player(self, didFailWithMessage: error.localizedDescription)
        }
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFinishSegmentAtMilliseconds endMilliseconds: Int
    ) {
        delegate?.player(self, didFinishSegmentAtMilliseconds: endMilliseconds)
    }

    public func nativePlaybackPlayerDidFinishPlayback(
        _ player: SFXNativePlaybackPlayer
    ) {
        currentRequest = nil
        currentVideoURL = nil
        delegate?.playerDidFinishPlayback(self)
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        shouldPauseAtAutoStopBoundaryAtMilliseconds endMilliseconds: Int,
        presentationGeneration: UInt
    ) -> Bool {
        autoPauseAuthorizationLock.lock()
        defer { autoPauseAuthorizationLock.unlock() }
        guard let authorization = autoPauseAuthorization,
              authorization.boundary.endMilliseconds == endMilliseconds,
              authorization.presentationGeneration == presentationGeneration
        else {
            return false
        }
        autoPauseAuthorization = nil
        return true
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didReachAutoStopBoundaryAtMilliseconds endMilliseconds: Int
    ) {
        reachedAutoStopBoundaryMilliseconds = endMilliseconds
        delegate?.player(
            self,
            didReachAutoStopBoundaryAtMilliseconds: endMilliseconds
        )
    }
}

public enum PlaybackHardwareCapabilities {
    public static func isHardwareDecodeSupported(forCodec codec: String?) -> Bool {
        guard let codec else { return false }
        return SFXNativePlaybackPlayer.isHardwareDecodeSupported(forCodecName: codec)
    }

    public static func isHardwareDecodeSupported(forCodec codec: String?, pixelFormat: String?) -> Bool {
        guard let codec else { return false }
        return SFXNativePlaybackPlayer.isHardwareDecodeSupported(
            forCodecName: codec,
            pixelFormatName: pixelFormat
        )
    }
}

public extension PlaybackDecodeMode {
    init(nativeDecodeMode: SFXNativePlaybackDecodeMode) {
        switch nativeDecodeMode {
        case .hardware:
            self = .hardware
        case .software:
            self = .software
        case .auto:
            self = .auto
        @unknown default:
            self = .auto
        }
    }

    var nativeDecodeMode: SFXNativePlaybackDecodeMode {
        SFXNativePlaybackDecodeMode(rawValue: nativeRawValue)!
    }

    private var nativeRawValue: Int {
        switch self {
        case .hardware:
            return 0
        case .software:
            return 1
        case .auto:
            return 2
        }
    }
}

@MainActor
public final class PlaybackRenderContainerView: NSView {
    private weak var attachedView: NSView?
    private var sourceFaithfulASSOverlayView: SourceFaithfulASSSubtitleOverlayView?
    private var srtSubtitleOverlayView: SRTSubtitleOverlayView?
    private var currentASSSubtitleSource: PlaybackSubtitleSource?
    private var currentASSSubtitleTimeMilliseconds = 0
    private var currentSubtitlesVisible = true
    private var currentVideoSize: CGSize?
    private var currentSRTSubtitleStyle = SRTSubtitleStyle()

    var assRenderingFailureHandler: ((String) -> Void)?
    var subtitleSourceLoadFailureHandler: ((URL) -> Void)?
    var stagedSubtitleReadyHandler: (() -> Void)?

    internal var hasDisplayedSubtitleImageForTesting: Bool {
        guard currentSubtitlesVisible else { return false }
        return (sourceFaithfulASSOverlayView?.hasDisplayedSubtitleImage == true)
            || (srtSubtitleOverlayView?.hasDisplayedSubtitleImage == true)
    }

    internal var assOverlayViewForTesting: SourceFaithfulASSSubtitleOverlayView? {
        sourceFaithfulASSOverlayView
    }

    internal var srtOverlayViewForTesting: SRTSubtitleOverlayView? {
        srtSubtitleOverlayView
    }

    init() {
        super.init(frame: .zero)
        PlaybackPerformanceProbe.countUI("UI.PlaybackRenderContainer.created")
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    public func attach(_ view: NSView) {
        guard attachedView !== view else {
            return
        }

        attachedView?.removeFromSuperview()
        attachedView = view
        view.removeFromSuperview()
        view.autoresizingMask = [.width, .height]
        addSubview(view)
        ensureSubtitleOverlaysStayAboveAttachedView()
        needsLayout = true
    }

    public override func layout() {
        super.layout()

        synchronizeAttachedRenderFrames(logName: "PlaybackRenderContainerView.layout")
    }

    fileprivate func prepareStagedSubtitlePresentation(
        action: PendingSubtitleAction,
        activeSource: PlaybackSubtitleSource?,
        speculativeVideoSize: CGSize?,
        targetMilliseconds: Int,
        isVisible: Bool,
        telemetryAttempt: PlaybackSubtitleFirstFrameAttempt?
    ) {
        let safeMilliseconds = max(0, targetMilliseconds)
        currentASSSubtitleTimeMilliseconds = safeMilliseconds
        currentSubtitlesVisible = isVisible
        if let speculativeVideoSize {
            currentVideoSize = speculativeVideoSize
        }

        sourceFaithfulASSOverlayView?.defersLayerPresentation = true
        srtSubtitleOverlayView?.defersLayerPresentation = true

        let targetSource: PlaybackSubtitleSource?
        switch action {
        case .preserve:
            targetSource = activeSource
        case .replace(let nextSource):
            targetSource = nextSource
        }

        guard let targetSource, isVisible else {
            sourceFaithfulASSOverlayView?.cancelPendingTelemetry()
            srtSubtitleOverlayView?.cancelPendingTelemetry()
            telemetryAttempt?.cancel()
            return
        }

        switch action {
        case .preserve:
            switch targetSource.format {
            case .ass:
                ensureSourceFaithfulASSOverlayView()
                sourceFaithfulASSOverlayView?.defersLayerPresentation = true
                _ = sourceFaithfulASSOverlayView?.commitPreservedPresentation(
                    videoSize: speculativeVideoSize,
                    milliseconds: safeMilliseconds,
                    attempt: telemetryAttempt
                )
            case .srt:
                ensureSRTSubtitleOverlayView()
                srtSubtitleOverlayView?.defersLayerPresentation = true
                _ = srtSubtitleOverlayView?.commitPreservedPresentation(
                    videoSize: speculativeVideoSize,
                    milliseconds: safeMilliseconds,
                    attempt: telemetryAttempt
                )
            }
        case .replace(let nextSource):
            currentASSSubtitleSource = nextSource
            switch targetSource.format {
            case .ass:
                srtSubtitleOverlayView?.defersLayerPresentation = true
                srtSubtitleOverlayView?.setSource(nil)
                ensureSourceFaithfulASSOverlayView()
                sourceFaithfulASSOverlayView?.defersLayerPresentation = true
                _ = sourceFaithfulASSOverlayView?.setPresentation(
                    source: targetSource,
                    videoSize: speculativeVideoSize,
                    milliseconds: safeMilliseconds,
                    isVisible: true,
                    telemetryAttempt: telemetryAttempt
                )
            case .srt:
                sourceFaithfulASSOverlayView?.defersLayerPresentation = true
                sourceFaithfulASSOverlayView?.setSource(nil)
                ensureSRTSubtitleOverlayView()
                srtSubtitleOverlayView?.defersLayerPresentation = true
                _ = srtSubtitleOverlayView?.setPresentation(
                    source: targetSource,
                    videoSize: speculativeVideoSize,
                    milliseconds: safeMilliseconds,
                    isVisible: true,
                    telemetryAttempt: telemetryAttempt
                )
            }
        }
    }

    fileprivate func retargetStagedSubtitlePresentation(
        for source: PlaybackSubtitleSource,
        videoSize: CGSize?,
        milliseconds: Int
    ) {
        let safeMilliseconds = max(0, milliseconds)
        currentASSSubtitleTimeMilliseconds = safeMilliseconds
        currentVideoSize = videoSize
        switch source.format {
        case .ass:
            ensureSourceFaithfulASSOverlayView()
            sourceFaithfulASSOverlayView?.defersLayerPresentation = true
            sourceFaithfulASSOverlayView?.retargetDeferredPresentation(
                videoSize: videoSize,
                milliseconds: safeMilliseconds
            )
        case .srt:
            ensureSRTSubtitleOverlayView()
            srtSubtitleOverlayView?.defersLayerPresentation = true
            srtSubtitleOverlayView?.retargetDeferredPresentation(
                videoSize: videoSize,
                milliseconds: safeMilliseconds
            )
        }
    }

    fileprivate func isStagedSubtitleReady(
        for source: PlaybackSubtitleSource,
        atMilliseconds milliseconds: Int,
        videoSize: CGSize?
    ) -> Bool {
        switch source.format {
        case .ass:
            return sourceFaithfulASSOverlayView?.isPreparedForPresentation(
                atMilliseconds: milliseconds,
                videoSize: videoSize
            ) == true
        case .srt:
            return srtSubtitleOverlayView?.isPreparedForPresentation(
                atMilliseconds: milliseconds,
                videoSize: videoSize
            ) == true
        }
    }

    fileprivate func finalizePendingPresentationSubtitleCommit(
        targetSource: PlaybackSubtitleSource?,
        videoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool,
        reason: PendingPresentationCommitReason,
        committedAt: CFTimeInterval
    ) -> PlaybackSubtitleCommitSyncState {
        let safeMilliseconds = max(0, milliseconds)
        currentASSSubtitleSource = targetSource
        currentASSSubtitleTimeMilliseconds = safeMilliseconds
        currentSubtitlesVisible = isVisible
        currentVideoSize = videoSize

        switch reason {
        case .immediateNoSubtitle, .subtitleLoadFailed:
            sourceFaithfulASSOverlayView?.clearDisplayedLayersImmediately()
            srtSubtitleOverlayView?.clearDisplayedLayersImmediately()
            sourceFaithfulASSOverlayView?.setSource(nil)
            srtSubtitleOverlayView?.setSource(nil)
            return .noSubtitle

        case .immediateHidden:
            sourceFaithfulASSOverlayView?.clearDisplayedLayersImmediately()
            srtSubtitleOverlayView?.clearDisplayedLayersImmediately()
            return commitSubtitlePresentation(
                source: targetSource,
                videoSize: videoSize,
                milliseconds: safeMilliseconds,
                isVisible: false,
                telemetryAttempt: nil
            )

        case .synchronizedReady:
            guard let targetSource else {
                sourceFaithfulASSOverlayView?.clearDisplayedLayersImmediately()
                srtSubtitleOverlayView?.clearDisplayedLayersImmediately()
                sourceFaithfulASSOverlayView?.setSource(nil)
                srtSubtitleOverlayView?.setSource(nil)
                return .noSubtitle
            }
            switch targetSource.format {
            case .ass:
                srtSubtitleOverlayView?.clearDisplayedLayersImmediately()
                srtSubtitleOverlayView?.setSource(nil)
                sourceFaithfulASSOverlayView?.flushDeferredLayerPresentation(
                    isSynchronousCommit: true,
                    committedAt: committedAt
                )
            case .srt:
                sourceFaithfulASSOverlayView?.clearDisplayedLayersImmediately()
                sourceFaithfulASSOverlayView?.setSource(nil)
                srtSubtitleOverlayView?.flushDeferredLayerPresentation(
                    isSynchronousCommit: true,
                    committedAt: committedAt
                )
            }
            return .syncReady

        case .subtitleWaitTimedOut:
            guard let targetSource else {
                sourceFaithfulASSOverlayView?.clearDisplayedLayersImmediately()
                srtSubtitleOverlayView?.clearDisplayedLayersImmediately()
                sourceFaithfulASSOverlayView?.setSource(nil)
                srtSubtitleOverlayView?.setSource(nil)
                return .noSubtitle
            }
            switch targetSource.format {
            case .ass:
                srtSubtitleOverlayView?.clearDisplayedLayersImmediately()
                srtSubtitleOverlayView?.setSource(nil)
                sourceFaithfulASSOverlayView?.releaseDeferredLayerPresentationForTimeout(
                    committedAt: committedAt
                )
            case .srt:
                sourceFaithfulASSOverlayView?.clearDisplayedLayersImmediately()
                sourceFaithfulASSOverlayView?.setSource(nil)
                srtSubtitleOverlayView?.releaseDeferredLayerPresentationForTimeout(
                    committedAt: committedAt
                )
            }
            return .asyncPending
        }
    }

    fileprivate func cancelStagedSubtitlePresentation(
        restoringActiveSource activeSource: PlaybackSubtitleSource?,
        videoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool
    ) {
        sourceFaithfulASSOverlayView?.defersLayerPresentation = false
        srtSubtitleOverlayView?.defersLayerPresentation = false
        _ = commitSubtitlePresentation(
            source: activeSource,
            videoSize: videoSize,
            milliseconds: milliseconds,
            isVisible: isVisible,
            telemetryAttempt: nil
        )
    }

    fileprivate func stageManualSubtitleSwitch(
        to source: PlaybackSubtitleSource,
        videoSize: CGSize?,
        milliseconds: Int,
        telemetryAttempt: PlaybackSubtitleFirstFrameAttempt?
    ) {
        let safeMilliseconds = max(0, milliseconds)
        currentASSSubtitleSource = source
        currentASSSubtitleTimeMilliseconds = safeMilliseconds
        currentSubtitlesVisible = true
        currentVideoSize = videoSize

        sourceFaithfulASSOverlayView?.defersLayerPresentation = true
        srtSubtitleOverlayView?.defersLayerPresentation = true

        let resolvedVideoSize = videoSize
            ?? ((bounds.width > 1 && bounds.height > 1) ? bounds.size : CGSize(width: 1920, height: 1080))

        switch source.format {
        case .ass:
            srtSubtitleOverlayView?.defersLayerPresentation = true
            srtSubtitleOverlayView?.setSource(nil)
            ensureSourceFaithfulASSOverlayView()
            sourceFaithfulASSOverlayView?.defersLayerPresentation = true
            _ = sourceFaithfulASSOverlayView?.setPresentation(
                source: source,
                videoSize: resolvedVideoSize,
                milliseconds: safeMilliseconds,
                isVisible: true,
                telemetryAttempt: telemetryAttempt
            )
        case .srt:
            sourceFaithfulASSOverlayView?.defersLayerPresentation = true
            sourceFaithfulASSOverlayView?.setSource(nil)
            ensureSRTSubtitleOverlayView()
            srtSubtitleOverlayView?.defersLayerPresentation = true
            _ = srtSubtitleOverlayView?.setPresentation(
                source: source,
                videoSize: resolvedVideoSize,
                milliseconds: safeMilliseconds,
                isVisible: true,
                telemetryAttempt: telemetryAttempt
            )
        }
    }

    fileprivate func flushManualSubtitleSwitch(for source: PlaybackSubtitleSource) {
        let now = CACurrentMediaTime()
        switch source.format {
        case .ass:
            srtSubtitleOverlayView?.clearDisplayedLayersImmediately()
            srtSubtitleOverlayView?.setSource(nil)
            sourceFaithfulASSOverlayView?.flushDeferredLayerPresentation(
                isSynchronousCommit: false,
                committedAt: now
            )
        case .srt:
            sourceFaithfulASSOverlayView?.clearDisplayedLayersImmediately()
            sourceFaithfulASSOverlayView?.setSource(nil)
            srtSubtitleOverlayView?.flushDeferredLayerPresentation(
                isSynchronousCommit: false,
                committedAt: now
            )
        }
    }

    fileprivate func currentSubtitleMilliseconds(for format: PlaybackSubtitleSourceFormat) -> Int {
        switch format {
        case .ass:
            return sourceFaithfulASSOverlayView?.currentTimeMilliseconds ?? currentASSSubtitleTimeMilliseconds
        case .srt:
            return srtSubtitleOverlayView?.currentTimeMilliseconds ?? currentASSSubtitleTimeMilliseconds
        }
    }

    fileprivate func clearSubtitleSourceImmediately() {
        currentASSSubtitleSource = nil
        sourceFaithfulASSOverlayView?.clearDisplayedLayersImmediately()
        srtSubtitleOverlayView?.clearDisplayedLayersImmediately()
        sourceFaithfulASSOverlayView?.setSource(nil)
        srtSubtitleOverlayView?.setSource(nil)
    }

    @discardableResult
    func commitSubtitlePresentation(
        source: PlaybackSubtitleSource?,
        videoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool,
        telemetryAttempt: PlaybackSubtitleFirstFrameAttempt? = nil
    ) -> PlaybackSubtitleCommitSyncState {
        currentASSSubtitleSource = source
        currentASSSubtitleTimeMilliseconds = max(0, milliseconds)
        currentSubtitlesVisible = isVisible
        currentVideoSize = videoSize
        sourceFaithfulASSOverlayView?.defersLayerPresentation = false
        srtSubtitleOverlayView?.defersLayerPresentation = false

        switch source?.format {
        case .ass:
            srtSubtitleOverlayView?.setSource(nil)
            ensureSourceFaithfulASSOverlayView()
            return sourceFaithfulASSOverlayView?.setPresentation(
                source: source,
                videoSize: videoSize,
                milliseconds: currentASSSubtitleTimeMilliseconds,
                isVisible: isVisible,
                telemetryAttempt: telemetryAttempt
            ) ?? {
                telemetryAttempt?.cancel()
                return isVisible ? .asyncPending : .hidden
            }()
        case .srt:
            sourceFaithfulASSOverlayView?.setSource(nil)
            ensureSRTSubtitleOverlayView()
            return srtSubtitleOverlayView?.setPresentation(
                source: source,
                videoSize: videoSize,
                milliseconds: currentASSSubtitleTimeMilliseconds,
                isVisible: isVisible,
                telemetryAttempt: telemetryAttempt
            ) ?? {
                telemetryAttempt?.cancel()
                return isVisible ? .asyncPending : .hidden
            }()
        case nil:
            sourceFaithfulASSOverlayView?.setSource(nil)
            srtSubtitleOverlayView?.setSource(nil)
            telemetryAttempt?.cancel()
            return .noSubtitle
        }
    }

    @discardableResult
    func commitPreservedSubtitlePresentation(
        videoSize: CGSize?,
        milliseconds: Int,
        activeSource: PlaybackSubtitleSource?,
        isVisible: Bool,
        telemetryAttempt: PlaybackSubtitleFirstFrameAttempt?
    ) -> PlaybackSubtitleCommitSyncState {
        currentVideoSize = videoSize
        currentASSSubtitleTimeMilliseconds = milliseconds

        guard let activeSource else {
            sourceFaithfulASSOverlayView?.videoSize = videoSize
            srtSubtitleOverlayView?.videoSize = videoSize
            sourceFaithfulASSOverlayView?.currentTimeMilliseconds = milliseconds
            srtSubtitleOverlayView?.currentTimeMilliseconds = milliseconds
            telemetryAttempt?.cancel()
            return .noSubtitle
        }

        guard isVisible else {
            sourceFaithfulASSOverlayView?.videoSize = videoSize
            srtSubtitleOverlayView?.videoSize = videoSize
            sourceFaithfulASSOverlayView?.currentTimeMilliseconds = milliseconds
            srtSubtitleOverlayView?.currentTimeMilliseconds = milliseconds
            telemetryAttempt?.cancel()
            return .hidden
        }

        switch activeSource.format {
        case .ass:
            srtSubtitleOverlayView?.videoSize = videoSize
            srtSubtitleOverlayView?.currentTimeMilliseconds = milliseconds
            if let sourceFaithfulASSOverlayView {
                return sourceFaithfulASSOverlayView.commitPreservedPresentation(
                    videoSize: videoSize,
                    milliseconds: milliseconds,
                    attempt: telemetryAttempt
                )
            }
        case .srt:
            sourceFaithfulASSOverlayView?.videoSize = videoSize
            sourceFaithfulASSOverlayView?.currentTimeMilliseconds = milliseconds
            if let srtSubtitleOverlayView {
                return srtSubtitleOverlayView.commitPreservedPresentation(
                    videoSize: videoSize,
                    milliseconds: milliseconds,
                    attempt: telemetryAttempt
                )
            }
        }
        telemetryAttempt?.cancel()
        return .asyncPending
    }

    func bindManualSubtitleSwitchTelemetry(
        for source: PlaybackSubtitleSource,
        milliseconds: Int,
        attempt: PlaybackSubtitleFirstFrameAttempt
    ) {
        switch source.format {
        case .ass:
            if let sourceFaithfulASSOverlayView {
                sourceFaithfulASSOverlayView.bindTelemetryAttemptAfterLoadSetup(
                    milliseconds: milliseconds,
                    attempt: attempt
                )
            } else {
                attempt.cancel()
            }
        case .srt:
            if let srtSubtitleOverlayView {
                srtSubtitleOverlayView.bindTelemetryAttemptAfterLoadSetup(
                    milliseconds: milliseconds,
                    attempt: attempt
                )
            } else {
                attempt.cancel()
            }
        }
    }

    func setSourceFaithfulASSSubtitleSource(_ source: PlaybackSubtitleSource) {
        currentASSSubtitleSource = source
        applyASSSubtitleSource()
    }

    func setSubtitleSource(_ source: PlaybackSubtitleSource) {
        switch source.format {
        case .ass:
            srtSubtitleOverlayView?.setSource(nil)
            setSourceFaithfulASSSubtitleSource(source)
        case .srt:
            clearSourceFaithfulASSSubtitleSource()
            currentASSSubtitleSource = source
            ensureSRTSubtitleOverlayView()
            srtSubtitleOverlayView?.setSource(source)
        }
    }

    func clearSubtitleSource() {
        clearSourceFaithfulASSSubtitleSource()
        srtSubtitleOverlayView?.setSource(nil)
    }

    func clearSourceFaithfulASSSubtitleSource() {
        currentASSSubtitleSource = nil
        sourceFaithfulASSOverlayView?.setSource(nil)
    }

    func setSubtitleTime(
        milliseconds: Int,
        targetFormatOnly: PlaybackSubtitleSourceFormat? = nil
    ) {
        currentASSSubtitleTimeMilliseconds = milliseconds
        switch targetFormatOnly {
        case .ass:
            sourceFaithfulASSOverlayView?.currentTimeMilliseconds = milliseconds
        case .srt:
            srtSubtitleOverlayView?.currentTimeMilliseconds = milliseconds
        case nil:
            sourceFaithfulASSOverlayView?.currentTimeMilliseconds = milliseconds
            srtSubtitleOverlayView?.currentTimeMilliseconds = milliseconds
        }
    }

    func nextScheduledSubtitleTickMilliseconds(after milliseconds: Int) -> Int? {
        guard currentSubtitlesVisible else {
            return nil
        }
        return sourceFaithfulASSOverlayView?.nextScheduledRenderMilliseconds(after: milliseconds)
            ?? srtSubtitleOverlayView?.nextScheduledRenderMilliseconds(after: milliseconds)
    }

    func setSubtitlesVisible(_ isVisible: Bool) {
        currentSubtitlesVisible = isVisible
        if !isVisible {
            sourceFaithfulASSOverlayView?.defersLayerPresentation = false
            srtSubtitleOverlayView?.defersLayerPresentation = false
        }
        sourceFaithfulASSOverlayView?.areSubtitlesVisible = isVisible
        srtSubtitleOverlayView?.areSubtitlesVisible = isVisible
    }

    func setVideoSize(_ videoSize: CGSize?) {
        currentVideoSize = videoSize
        sourceFaithfulASSOverlayView?.videoSize = videoSize
        srtSubtitleOverlayView?.videoSize = videoSize
    }

    func setSRTSubtitleStyle(_ style: SRTSubtitleStyle) {
        currentSRTSubtitleStyle = style
        srtSubtitleOverlayView?.style = style
    }

    func currentASSSubtitleFrame() -> ASSSparseFrame? {
        guard currentSubtitlesVisible else {
            return nil
        }
        return sourceFaithfulASSOverlayView?.currentPresentationFrame()
    }

    func currentSRTSubtitleImage() -> CGImage? {
        guard currentSubtitlesVisible else {
            return nil
        }
        return srtSubtitleOverlayView?.currentPresentationImage()
    }

    private func ensureSourceFaithfulASSOverlayView() {
        let isNewOverlay = (sourceFaithfulASSOverlayView == nil)
        if isNewOverlay {
            let newOverlay = SourceFaithfulASSSubtitleOverlayView(frame: bounds)
            newOverlay.onRenderingFailure = { [weak self] message in
                self?.assRenderingFailureHandler?(message)
            }
            newOverlay.onSourceLoadFailure = { [weak self] url in
                self?.subtitleSourceLoadFailureHandler?(url)
            }
            newOverlay.onPreparedFrameReady = { [weak self] in
                self?.stagedSubtitleReadyHandler?()
            }
            newOverlay.currentTimeMilliseconds = currentASSSubtitleTimeMilliseconds
            newOverlay.areSubtitlesVisible = currentSubtitlesVisible
            newOverlay.videoSize = currentVideoSize
            sourceFaithfulASSOverlayView = newOverlay
        }

        guard let sourceFaithfulASSOverlayView else {
            return
        }

        if sourceFaithfulASSOverlayView.superview !== self {
            sourceFaithfulASSOverlayView.autoresizingMask = [.width, .height]
            addSubview(sourceFaithfulASSOverlayView)
        }

        sourceFaithfulASSOverlayView.frame = bounds

        if let attachedView {
            addSubview(sourceFaithfulASSOverlayView, positioned: .above, relativeTo: attachedView)
        }
    }

    private func ensureSRTSubtitleOverlayView() {
        let isNewOverlay = (srtSubtitleOverlayView == nil)
        if isNewOverlay {
            let newOverlay = SRTSubtitleOverlayView(frame: bounds)
            newOverlay.onRenderingFailure = { [weak self] message in
                self?.assRenderingFailureHandler?(message)
            }
            newOverlay.onSourceLoadFailure = { [weak self] url in
                self?.subtitleSourceLoadFailureHandler?(url)
            }
            newOverlay.onPreparedFrameReady = { [weak self] in
                self?.stagedSubtitleReadyHandler?()
            }
            newOverlay.currentTimeMilliseconds = currentASSSubtitleTimeMilliseconds
            newOverlay.areSubtitlesVisible = currentSubtitlesVisible
            newOverlay.videoSize = currentVideoSize
            srtSubtitleOverlayView = newOverlay
        }
        guard let srtSubtitleOverlayView else { return }
        srtSubtitleOverlayView.style = currentSRTSubtitleStyle
        if srtSubtitleOverlayView.superview !== self {
            srtSubtitleOverlayView.autoresizingMask = [.width, .height]
            addSubview(srtSubtitleOverlayView)
        }
        srtSubtitleOverlayView.frame = bounds
        if let attachedView {
            addSubview(srtSubtitleOverlayView, positioned: .above, relativeTo: attachedView)
        }
    }

    private func applyASSSubtitleSource() {
        guard let currentASSSubtitleSource else {
            return
        }

        ensureSourceFaithfulASSOverlayView()
        sourceFaithfulASSOverlayView?.currentTimeMilliseconds = currentASSSubtitleTimeMilliseconds
        sourceFaithfulASSOverlayView?.areSubtitlesVisible = currentSubtitlesVisible
        sourceFaithfulASSOverlayView?.videoSize = currentVideoSize
        sourceFaithfulASSOverlayView?.setSource(currentASSSubtitleSource)
    }

    private func ensureSubtitleOverlaysStayAboveAttachedView() {
        guard let attachedView else {
            return
        }

        if let sourceFaithfulASSOverlayView, sourceFaithfulASSOverlayView.superview === self {
            addSubview(sourceFaithfulASSOverlayView, positioned: .above, relativeTo: attachedView)
        }
        if let srtSubtitleOverlayView, srtSubtitleOverlayView.superview === self {
            addSubview(srtSubtitleOverlayView, positioned: .above, relativeTo: attachedView)
        }
    }

    private func synchronizeAttachedRenderFrames(logName: String) {
        PlaybackPerformanceProbe.measure(logName, thresholdMilliseconds: 8) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if let attachedView {
                attachedView.frame = bounds
                attachedView.needsLayout = true
                attachedView.layoutSubtreeIfNeeded()
            }
            if let sourceFaithfulASSOverlayView {
                sourceFaithfulASSOverlayView.frame = bounds
                sourceFaithfulASSOverlayView.needsLayout = true
                sourceFaithfulASSOverlayView.layoutSubtreeIfNeeded()
            }
            if let srtSubtitleOverlayView {
                srtSubtitleOverlayView.frame = bounds
                srtSubtitleOverlayView.needsLayout = true
                srtSubtitleOverlayView.layoutSubtreeIfNeeded()
            }
            CATransaction.commit()
        }
    }
}
