import AppKit
import CNativePlayback
import CueSeekerCore
import Foundation
import QuartzCore

public protocol PlaybackPlayerDelegate: AnyObject {
    func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: PlaybackPropertyValue?)
    func player(_ player: PlaybackPlayer, didFailWithMessage message: String)
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int)
    func player(_ player: PlaybackPlayer, didReachAutoStopBoundaryAtMilliseconds endMilliseconds: Int)
    @MainActor func player(
        _ player: PlaybackPlayer,
        didCommitPresentationAtMilliseconds milliseconds: Int,
        generation: UInt,
        playing: Bool
    )
}

public extension PlaybackPlayerDelegate {
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int) {}
    func player(_ player: PlaybackPlayer, didReachAutoStopBoundaryAtMilliseconds endMilliseconds: Int) {}
    @MainActor func player(
        _ player: PlaybackPlayer,
        didCommitPresentationAtMilliseconds milliseconds: Int,
        generation: UInt,
        playing: Bool
    ) {}
}

private enum PendingSubtitleAction {
    case preserve
    case replace(PlaybackSubtitleSource?)
}

private struct PendingPresentation {
    var generation: UInt?
    let targetMilliseconds: Int
    let heldMilliseconds: Int
    var subtitleAction: PendingSubtitleAction
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
    private var subtitleLoadTask: Task<Void, Never>?
    private var subtitleRenderTickTask: Task<Void, Never>?
    private var heldSubtitlePresentationMilliseconds: Int?
    private var lastRenderedASSSubtitleMilliseconds = 0
    private var pendingPresentation: PendingPresentation?
    private var committedPresentationGeneration: UInt?
    private var reachedAutoStopBoundaryMilliseconds: Int?
    private var persistentAutoPauseBoundary: PlaybackAutoStopBoundary?
    private var autoPauseAuthorization: PlaybackAutoPauseAuthorization?
    private let autoPauseAuthorizationLock = NSLock()

    public weak var delegate: PlaybackPlayerDelegate?

    public private(set) var currentVideoURL: URL?
    public var decodeMode: PlaybackDecodeMode = .auto {
        didSet {
            nativePlayer.decodeMode = decodeMode.nativeDecodeMode
        }
    }

    @MainActor public lazy var renderView: NSView = PlaybackRenderContainerView()

    public override init() {
        super.init()
        nativePlayer.delegate = self
        nativePlayer.volume = Float(storedVolume / 100)
        nativePlayer.decodeMode = decodeMode.nativeDecodeMode
    }

    @discardableResult
    public func open(_ request: PlaybackRequest) throws -> UInt {
        reachedAutoStopBoundaryMilliseconds = nil
        let autoPauseBoundary = request.autoStopAtMilliseconds.map {
            PlaybackAutoStopBoundary(
                startMilliseconds: request.startMilliseconds,
                endMilliseconds: $0
            )
        }
        replacePersistentAutoPauseBoundary(autoPauseBoundary)
        beginPresentationTransition(
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
        do {
            if let autoStopAtMilliseconds = request.autoStopAtMilliseconds {
                try nativePlayer.openPath(
                    request.videoURL.path,
                    startMilliseconds: request.startMilliseconds,
                    autoStopAtMilliseconds: autoStopAtMilliseconds
                )
            } else if let segmentEndMilliseconds = request.segmentEndMilliseconds {
                try nativePlayer.openPath(
                    request.videoURL.path,
                    startMilliseconds: request.startMilliseconds,
                    endMilliseconds: segmentEndMilliseconds
                )
            } else {
                try nativePlayer.openPath(
                    request.videoURL.path,
                    startMilliseconds: request.startMilliseconds
                )
            }
        } catch {
            cancelPendingPresentation()
            throw error
        }
        let generation = bindPendingPresentationToNativeGeneration()
        authorizeAutoPauseBoundary(autoPauseBoundary, generation: generation)
        currentVideoURL = request.videoURL.standardizedFileURL
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
        pendingPresentation = nil
    }

    @discardableResult
    private func seek(
        toMilliseconds milliseconds: Int,
        pauseAfterFirstFrame: Bool,
        subtitleAction: PendingSubtitleAction
    ) throws -> UInt {
        reachedAutoStopBoundaryMilliseconds = nil
        let safeMilliseconds = max(0, milliseconds)
        beginPresentationTransition(
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
        beginPresentationTransition(
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
        return bindPendingPresentationToNativeGeneration()
    }

    private func beginPresentationTransition(
        targetMilliseconds: Int,
        subtitleAction: PendingSubtitleAction
    ) {
        let heldMilliseconds = pendingPresentation?.heldMilliseconds
            ?? heldSubtitlePresentationMilliseconds
            ?? lastRenderedASSSubtitleMilliseconds
        pendingPresentation = PendingPresentation(
            generation: nil,
            targetMilliseconds: max(0, targetMilliseconds),
            heldMilliseconds: max(0, heldMilliseconds),
            subtitleAction: subtitleAction
        )
    }

    private func bindPendingPresentationToNativeGeneration() -> UInt {
        let generation = nativePlayer.nativePresentationGeneration
        pendingPresentation?.generation = generation
        return generation
    }

    public func beginTimelineScrubbing() throws {
        clearSubtitlePresentationHold()
        try nativePlayer.setTimelineScrubbing(true)
    }

    public func requestTimelineScrubPreview(toMilliseconds milliseconds: Int) {
        let safeMilliseconds = max(0, milliseconds)
        clearHeldSubtitlePresentationWithoutRendering()
        nativePlayer.requestTimelineScrubPreview(atMilliseconds: safeMilliseconds)
        updateASSSubtitleTime(milliseconds: safeMilliseconds)
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
    }

    public func setAutoPauseBoundary(_ boundary: PlaybackAutoStopBoundary?) {
        replacePersistentAutoPauseBoundary(boundary)
        if reachedAutoStopBoundaryMilliseconds != boundary?.endMilliseconds {
            reachedAutoStopBoundaryMilliseconds = nil
        }
    }

    public func stop() throws {
        nativePlayer.stop()
        currentRequest = nil
        currentVideoURL = nil
        pendingPresentation = nil
        committedPresentationGeneration = nil
        reachedAutoStopBoundaryMilliseconds = nil
        replacePersistentAutoPauseBoundary(nil)
        clearHeldSubtitlePresentationWithoutRendering()
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                activateSubtitleSourceForCommittedPresentation(nil, milliseconds: 0)
            }
        } else {
            Task { @MainActor in
                self.activateSubtitleSourceForCommittedPresentation(nil, milliseconds: 0)
            }
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
        if pendingPresentation != nil {
            pendingPresentation?.subtitleAction = .replace(source)
            return
        }

        subtitleLoadTask?.cancel()
        activeSubtitleSource = source

        guard let source, source.format == .ass else {
            assSubtitleRenderTimeGate = nil
            stopASSSubtitleRenderTicks()
            Task { @MainActor in
                guard let container = self.renderView as? PlaybackRenderContainerView else {
                    return
                }

                container.clearSourceFaithfulASSSubtitleSource()
            }
            return
        }

        SubtitleSpeakerDisplayDiagnostics.log(
            "player.assSubtitleSource.loadRequested",
            fields: [
                "subtitle": source.url.lastPathComponent,
                "subtitlePath": source.url.path,
                "speakerCueCount": "\(source.speakerDisplayCues.count)"
            ]
        )

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

        Task { @MainActor in
            guard self.activeSubtitleSource == source,
                  let container = self.renderView as? PlaybackRenderContainerView
            else {
                return
            }

            container.assRenderingFailureHandler = { [weak self] message in
                guard let self else { return }
                self.delegate?.player(self, didFailWithMessage: message)
            }
            container.setVideoSize(self.currentNativeVideoSize())
            container.setASSSubtitleTime(milliseconds: initialMilliseconds)
            container.setSourceFaithfulASSSubtitleSource(source)
            container.setSubtitlesVisible(self.subtitlesVisible)
            self.lastRenderedASSSubtitleMilliseconds = initialMilliseconds
        }
        startASSSubtitleRenderTicks()
    }

    deinit {
        subtitleLoadTask?.cancel()
        subtitleRenderTickTask?.cancel()
    }

    public func setSubtitlesVisible(_ isVisible: Bool) {
        subtitlesVisible = isVisible
        Task { @MainActor in
            (self.renderView as? PlaybackRenderContainerView)?.setSubtitlesVisible(isVisible)
        }
    }

    public func captureLatestSubmittedVideoFrame() -> PlaybackSubmittedVideoFrame? {
        guard let snapshot = nativePlayer.latestSubmittedVideoFrameSnapshot else {
            return nil
        }
        return PlaybackSubmittedVideoFrame(nativeSnapshot: snapshot)
    }

    @MainActor
    public func captureScreenshotPresentation() -> PlaybackScreenshotPresentation? {
        guard let frame = captureLatestSubmittedVideoFrame() else {
            return nil
        }

        let fallbackSize = CGSize(width: frame.width, height: frame.height)
        guard let container = renderView as? PlaybackRenderContainerView else {
            return PlaybackScreenshotPresentation(
                frame: frame,
                geometry: PlaybackScreenshotGeometry(
                    viewportSize: fallbackSize,
                    videoRect: CGRect(origin: .zero, size: fallbackSize)
                ),
                assSubtitleSurface: nil
            )
        }

        return PlaybackScreenshotPresentation(
            frame: frame,
            geometry: container.screenshotGeometry(fallbackSize: fallbackSize),
            assSubtitleSurface: container.currentASSSubtitleSurface()
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

    public func getDoubleProperty(_ name: String) throws -> Double {
        switch name {
        case "time-pos":
            return nativePlayer.currentTime
        case "duration":
            return nativePlayer.duration
        case "volume":
            return storedVolume
        case "speed":
            return storedSpeed
        default:
            throw PlaybackError.nativePropertyUnsupported(name: name)
        }
    }

    public func setDoubleProperty(_ name: String, value: Double) throws {
        switch name {
        case "volume":
            storedVolume = min(max(value, 0), 100)
            nativePlayer.volume = Float(storedVolume / 100)
            delegate?.player(self, didChangeProperty: "volume", value: .double(storedVolume))
        case "speed":
            storedSpeed = min(max(value, 0.5), 2.0)
            nativePlayer.playbackRate = Float(storedSpeed)
            delegate?.player(self, didChangeProperty: "speed", value: .double(storedSpeed))
        default:
            throw PlaybackError.nativePropertyUnsupported(name: name)
        }
    }

    public func setStringProperty(_ name: String, value: String) throws {
        if name != "sid" {
            throw PlaybackError.nativePropertyUnsupported(name: name)
        }

        setSubtitlesVisible(value != "no")
    }

    public func getBoolProperty(_ name: String) throws -> Bool {
        if name == "pause" {
            return !nativePlayer.isPlaying
        }
        throw PlaybackError.nativePropertyUnsupported(name: name)
    }

    public func setBoolProperty(_ name: String, value: Bool) throws {
        if name == "pause" {
            try nativePlayer.setPaused(value)
        } else {
            throw PlaybackError.nativePropertyUnsupported(name: name)
        }
    }

    @MainActor public func attachActiveRenderView() {
        guard let container = renderView as? PlaybackRenderContainerView else {
            return
        }

        container.attach(nativePlayer.view)
        container.setVideoSize(currentNativeVideoSize())
        container.setSubtitlesVisible(subtitlesVisible)
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
        let effectiveMilliseconds = effectiveASSSubtitleMilliseconds(milliseconds)
        retargetASSSubtitleRenderTimeGate(forExplicitMilliseconds: effectiveMilliseconds)
        Task { @MainActor in
            (self.renderView as? PlaybackRenderContainerView)?.setASSSubtitleTime(milliseconds: effectiveMilliseconds)
            self.lastRenderedASSSubtitleMilliseconds = effectiveMilliseconds
        }
    }

    private func updateASSSubtitleTimeFromNative(milliseconds: Int) {
        let effectiveMilliseconds = renderedASSSubtitleMilliseconds(
            forNativeMilliseconds: milliseconds
        )
        Task { @MainActor in
            (self.renderView as? PlaybackRenderContainerView)?.setASSSubtitleTime(milliseconds: effectiveMilliseconds)
            self.lastRenderedASSSubtitleMilliseconds = effectiveMilliseconds
        }
    }

    private func currentNativePlaybackMilliseconds() -> Int {
        max(0, Int((nativePlayer.currentTime * 1_000).rounded(.down)))
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
        subtitleRenderTickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }

                let milliseconds = self.renderedASSSubtitleMilliseconds(
                    forNativeMilliseconds: self.currentNativePlaybackMilliseconds()
                )
                (self.renderView as? PlaybackRenderContainerView)?.setASSSubtitleTime(milliseconds: milliseconds)
                self.lastRenderedASSSubtitleMilliseconds = milliseconds
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    private func stopASSSubtitleRenderTicks() {
        subtitleRenderTickTask?.cancel()
        subtitleRenderTickTask = nil
    }

    private func emitInitialNativeState() {
        if pendingPresentation == nil {
            delegate?.player(self, didChangeProperty: "duration", value: .double(nativePlayer.duration))
            if let aspectRatio = currentNativeVideoAspectRatio() {
                delegate?.player(self, didChangeProperty: "video-aspect-ratio", value: .double(aspectRatio))
            }
            delegate?.player(self, didChangeProperty: "pause", value: .bool(false))
        }
        delegate?.player(self, didChangeProperty: "volume", value: .double(storedVolume))
        delegate?.player(self, didChangeProperty: "speed", value: .double(storedSpeed))
    }

    private func emitPauseState(isPaused: Bool) {
        delegate?.player(self, didChangeProperty: "pause", value: .bool(isPaused))
    }

    @MainActor
    private func commitPendingPresentation(
        atMilliseconds milliseconds: Int,
        generation: UInt
    ) {
        guard let pendingPresentation,
              pendingPresentation.generation == generation
        else {
            return
        }

        let safeMilliseconds = max(0, milliseconds)
        self.pendingPresentation = nil
        committedPresentationGeneration = generation
        heldSubtitlePresentationMilliseconds = nil

        switch pendingPresentation.subtitleAction {
        case .preserve:
            retargetASSSubtitleRenderTimeGate(forExplicitMilliseconds: safeMilliseconds)
            (renderView as? PlaybackRenderContainerView)?.setASSSubtitleTime(
                milliseconds: safeMilliseconds
            )
            lastRenderedASSSubtitleMilliseconds = safeMilliseconds
        case .replace(let source):
            activateSubtitleSourceForCommittedPresentation(
                source,
                milliseconds: safeMilliseconds
            )
        }

        let playing = nativePlayer.isPlaying
        delegate?.player(
            self,
            didCommitPresentationAtMilliseconds: safeMilliseconds,
            generation: generation,
            playing: playing
        )
        delegate?.player(
            self,
            didChangeProperty: "duration",
            value: .double(nativePlayer.duration)
        )
        if let aspectRatio = currentNativeVideoAspectRatio() {
            delegate?.player(
                self,
                didChangeProperty: "video-aspect-ratio",
                value: .double(aspectRatio)
            )
        }
        delegate?.player(self, didChangeProperty: "pause", value: .bool(!playing))
        delegate?.player(
            self,
            didChangeProperty: "time-pos",
            value: .double(Double(safeMilliseconds) / 1_000)
        )
    }

    @MainActor
    private func activateSubtitleSourceForCommittedPresentation(
        _ source: PlaybackSubtitleSource?,
        milliseconds: Int
    ) {
        subtitleLoadTask?.cancel()
        activeSubtitleSource = source
        lastRenderedASSSubtitleMilliseconds = milliseconds

        guard let source, source.format == .ass else {
            assSubtitleRenderTimeGate = nil
            stopASSSubtitleRenderTicks()
            (renderView as? PlaybackRenderContainerView)?.clearSourceFaithfulASSSubtitleSource()
            return
        }

        let initialGate = PlaybackSubtitleRenderTimeGate(
            source: source,
            fallbackMilliseconds: milliseconds
        )
        assSubtitleRenderTimeGate = initialGate?.retargetingHeldTimestamp(
            forExplicitMilliseconds: milliseconds
        ) ?? initialGate

        guard let container = renderView as? PlaybackRenderContainerView else {
            return
        }
        container.assRenderingFailureHandler = { [weak self] message in
            guard let self else { return }
            self.delegate?.player(self, didFailWithMessage: message)
        }
        container.setVideoSize(currentNativeVideoSize())
        container.setASSSubtitleTime(milliseconds: milliseconds)
        container.setSourceFaithfulASSSubtitleSource(source)
        container.setSubtitlesVisible(subtitlesVisible)
        startASSSubtitleRenderTicks()
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
        delegate?.player(self, didChangeProperty: "time-pos", value: .double(time))
        delegate?.player(self, didChangeProperty: "duration", value: .double(duration))
        delegate?.player(self, didChangeProperty: "pause", value: .bool(!playing))
        let milliseconds = max(0, Int((time * 1_000).rounded(.down)))
        updateASSSubtitleTimeFromNative(milliseconds: milliseconds)
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didPresentVideoFrameAtMilliseconds milliseconds: Int,
        presentationGeneration: UInt
    ) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                commitPendingPresentation(
                    atMilliseconds: milliseconds,
                    generation: presentationGeneration
                )
            }
        } else {
            Task { @MainActor in
                self.commitPendingPresentation(
                    atMilliseconds: milliseconds,
                    generation: presentationGeneration
                )
            }
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
        didFinishSegmentAtMilliseconds endMilliseconds: Int
    ) {
        delegate?.player(self, didFinishSegmentAtMilliseconds: endMilliseconds)
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

private extension PlaybackDecodeMode {
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
    private var currentASSSubtitleSource: PlaybackSubtitleSource?
    private var currentASSSubtitleTimeMilliseconds = 0
    private var currentSubtitlesVisible = true
    private var currentVideoSize: CGSize?

    var assRenderingFailureHandler: ((String) -> Void)?

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
        ensureASSOverlaysStayAboveAttachedView()
        needsLayout = true
    }

    public override func layout() {
        super.layout()

        synchronizeAttachedRenderFrames(logName: "PlaybackRenderContainerView.layout")
    }

    func setSourceFaithfulASSSubtitleSource(_ source: PlaybackSubtitleSource) {
        currentASSSubtitleSource = source
        applyASSSubtitleSource()
    }

    func clearSourceFaithfulASSSubtitleSource() {
        currentASSSubtitleSource = nil
        sourceFaithfulASSOverlayView?.setSource(nil)
    }

    func setASSSubtitleTime(milliseconds: Int) {
        currentASSSubtitleTimeMilliseconds = milliseconds
        sourceFaithfulASSOverlayView?.currentTimeMilliseconds = milliseconds
    }

    func setSubtitlesVisible(_ isVisible: Bool) {
        currentSubtitlesVisible = isVisible
        sourceFaithfulASSOverlayView?.areSubtitlesVisible = isVisible
    }

    func setVideoSize(_ videoSize: CGSize?) {
        currentVideoSize = videoSize
        sourceFaithfulASSOverlayView?.videoSize = videoSize
    }

    func currentASSSubtitleSurface() -> PlaybackASSSubtitleSurface? {
        guard currentSubtitlesVisible else {
            return nil
        }
        return sourceFaithfulASSOverlayView?.currentPresentationSurface()
    }

    func screenshotGeometry(fallbackSize: CGSize) -> PlaybackScreenshotGeometry {
        let viewportSize = bounds.size.width > 0 && bounds.size.height > 0
            ? bounds.size
            : fallbackSize
        guard let currentVideoSize,
              currentVideoSize.width > 0,
              currentVideoSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0
        else {
            return PlaybackScreenshotGeometry(
                viewportSize: viewportSize,
                videoRect: CGRect(origin: .zero, size: viewportSize)
            )
        }

        let scale = min(
            viewportSize.width / currentVideoSize.width,
            viewportSize.height / currentVideoSize.height
        )
        let displayedSize = CGSize(
            width: currentVideoSize.width * scale,
            height: currentVideoSize.height * scale
        )
        return PlaybackScreenshotGeometry(
            viewportSize: viewportSize,
            videoRect: CGRect(
                x: (viewportSize.width - displayedSize.width) / 2,
                y: (viewportSize.height - displayedSize.height) / 2,
                width: displayedSize.width,
                height: displayedSize.height
            )
        )
    }

    private func ensureSourceFaithfulASSOverlayView() {
        if sourceFaithfulASSOverlayView == nil {
            sourceFaithfulASSOverlayView = SourceFaithfulASSSubtitleOverlayView(frame: bounds)
            sourceFaithfulASSOverlayView?.onRenderingFailure = { [weak self] message in
                self?.assRenderingFailureHandler?(message)
            }
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

        sourceFaithfulASSOverlayView.currentTimeMilliseconds = currentASSSubtitleTimeMilliseconds
        sourceFaithfulASSOverlayView.areSubtitlesVisible = currentSubtitlesVisible
        sourceFaithfulASSOverlayView.videoSize = currentVideoSize
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

    private func ensureASSOverlaysStayAboveAttachedView() {
        guard let attachedView else {
            return
        }

        if let sourceFaithfulASSOverlayView, sourceFaithfulASSOverlayView.superview === self {
            addSubview(sourceFaithfulASSOverlayView, positioned: .above, relativeTo: attachedView)
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
            CATransaction.commit()
        }
    }
}
