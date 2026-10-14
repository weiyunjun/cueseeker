import AppKit
import CNativePlayback
import CueSeekerCore
import Foundation
import QuartzCore

public protocol PlaybackPlayerDelegate: AnyObject {
    func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: PlaybackPropertyValue?)
    func player(_ player: PlaybackPlayer, didFailWithMessage message: String)
    func player(_ player: PlaybackPlayer, didFailToLoadSubtitleSource url: URL)
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int)
    func playerDidFinishPlayback(_ player: PlaybackPlayer)
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
    func player(_ player: PlaybackPlayer, didFailToLoadSubtitleSource url: URL) {}
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int) {}
    func playerDidFinishPlayback(_ player: PlaybackPlayer) {}
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

private struct PendingPresentation {
    var generation: UInt?
    let targetMilliseconds: Int
    let heldMilliseconds: Int
    var subtitleAction: PendingSubtitleAction
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
    public var usingHardwareDecode: Bool {
        nativePlayer.usingHardwareDecode
    }
    public var activeDecodeMode: PlaybackDecodeMode {
        PlaybackDecodeMode(nativeDecodeMode: nativePlayer.activeDecodeMode)
    }
    public var decodeMode: PlaybackDecodeMode = .auto {
        didSet {
            NSLog("[Playback] PlaybackPlayer.decodeMode: %@ -> %@",
                  oldValue.rawValue,
                  decodeMode.rawValue)
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
        nativePlayer.delegate = self
        nativePlayer.volume = Float(storedVolume / 100)
        nativePlayer.decodeMode = decodeMode.nativeDecodeMode
    }

    @discardableResult
    public func open(_ request: PlaybackRequest) throws -> UInt {
        NSLog("[Playback] PlaybackPlayer.open: path=%@, startMs=%ld, decodeMode=%@",
              request.videoURL.mediaPath,
              request.startMilliseconds,
              decodeMode.rawValue)
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
        currentVideoURL = request.videoURL.standardizedMediaURL
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
        NSLog("[Playback] PlaybackPlayer.seek: targetMs=%ld, currentVideo=%@, usingHardware=%d",
              safeMilliseconds,
              currentVideoURL?.lastPathComponent ?? "none",
              nativePlayer.usingHardwareDecode ? 1 : 0)
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
            subtitleAction: subtitleAction,
            startedAt: CACurrentMediaTime(),
            resolve302Milliseconds: 0
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
                clearSubtitleSourceAfterStop()
            }
        } else {
            Task { @MainActor in
                self.clearSubtitleSourceAfterStop()
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

        guard let source else {
            assSubtitleRenderTimeGate = nil
            stopASSSubtitleRenderTicks()
            Task { @MainActor in
                guard let container = self.renderView as? PlaybackRenderContainerView else {
                    return
                }

                container.clearSubtitleSource()
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
            container.subtitleSourceLoadFailureHandler = { [weak self] url in
                guard let self else { return }
                self.delegate?.player(self, didFailToLoadSubtitleSource: url)
            }
            container.setVideoSize(self.currentNativeVideoSize())
            container.setSubtitleTime(milliseconds: initialMilliseconds)
            container.setSubtitleSource(source)
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
            (self.renderView as? PlaybackRenderContainerView)?.setSubtitleTime(milliseconds: effectiveMilliseconds)
            self.lastRenderedASSSubtitleMilliseconds = effectiveMilliseconds
        }
    }

    private func updateASSSubtitleTimeFromNative(milliseconds: Int) {
        let effectiveMilliseconds = renderedASSSubtitleMilliseconds(
            forNativeMilliseconds: milliseconds
        )
        Task { @MainActor in
            (self.renderView as? PlaybackRenderContainerView)?.setSubtitleTime(milliseconds: effectiveMilliseconds)
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
                (self.renderView as? PlaybackRenderContainerView)?.setSubtitleTime(milliseconds: milliseconds)
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

        let commitStart = CACurrentMediaTime()
        let safeMilliseconds = max(0, milliseconds)
        self.pendingPresentation = nil
        committedPresentationGeneration = generation
        heldSubtitlePresentationMilliseconds = nil
        let videoSize = currentNativeVideoSize()

        let subtitleStart = CACurrentMediaTime()
        switch pendingPresentation.subtitleAction {
        case .preserve:
            retargetASSSubtitleRenderTimeGate(forExplicitMilliseconds: safeMilliseconds)
            (renderView as? PlaybackRenderContainerView)?.setSubtitleTime(
                milliseconds: safeMilliseconds
            )
            lastRenderedASSSubtitleMilliseconds = safeMilliseconds
        case .replace(let source):
            activateSubtitleSourceForCommittedPresentation(
                source,
                milliseconds: safeMilliseconds,
                videoSize: videoSize
            )
        }
        let subtitleCommitMs = (CACurrentMediaTime() - subtitleStart) * 1000.0

        let playing = nativePlayer.isPlaying
        delegate?.player(
            self,
            didCommitPresentationAtMilliseconds: safeMilliseconds,
            generation: generation,
            playing: playing,
            videoSize: videoSize
        )
        delegate?.player(
            self,
            didChangeProperty: "duration",
            value: .double(nativePlayer.duration)
        )
        delegate?.player(self, didChangeProperty: "pause", value: .bool(!playing))
        delegate?.player(
            self,
            didChangeProperty: "time-pos",
            value: .double(Double(safeMilliseconds) / 1_000)
        )
        let now = CACurrentMediaTime()
        let totalEndToEndMs = (now - pendingPresentation.startedAt) * 1000.0
        let commitElapsedMs = (now - commitStart) * 1000.0
        NSLog(
            "[PlaybackPerf] UI_COMMIT gen=%lu targetMs=%ld presentedMs=%ld totalEndToEnd=%.1fms | S1_resolve302=%.1fms subtitleCommit=%.1fms uiDelegateCommit=%.1fms",
            generation,
            pendingPresentation.targetMilliseconds,
            safeMilliseconds,
            totalEndToEndMs,
            pendingPresentation.resolve302Milliseconds,
            subtitleCommitMs,
            commitElapsedMs
        )
    }

    @MainActor
    private func clearSubtitleSourceAfterStop() {
        subtitleLoadTask?.cancel()
        activeSubtitleSource = nil
        lastRenderedASSSubtitleMilliseconds = 0
        assSubtitleRenderTimeGate = nil
        stopASSSubtitleRenderTicks()
        (renderView as? PlaybackRenderContainerView)?.clearSubtitleSource()
    }

    @MainActor
    private func activateSubtitleSourceForCommittedPresentation(
        _ source: PlaybackSubtitleSource?,
        milliseconds: Int,
        videoSize: CGSize?
    ) {
        subtitleLoadTask?.cancel()
        activeSubtitleSource = source
        lastRenderedASSSubtitleMilliseconds = milliseconds

        guard let source else {
            assSubtitleRenderTimeGate = nil
            stopASSSubtitleRenderTicks()
            (renderView as? PlaybackRenderContainerView)?.commitSubtitlePresentation(
                source: nil,
                videoSize: videoSize,
                milliseconds: milliseconds,
                isVisible: subtitlesVisible
            )
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
        container.subtitleSourceLoadFailureHandler = { [weak self] url in
            guard let self else { return }
            self.delegate?.player(self, didFailToLoadSubtitleSource: url)
        }
        container.commitSubtitlePresentation(
            source: source,
            videoSize: videoSize,
            milliseconds: milliseconds,
            isVisible: subtitlesVisible
        )
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

    func commitSubtitlePresentation(
        source: PlaybackSubtitleSource?,
        videoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool
    ) {
        currentASSSubtitleSource = source
        currentASSSubtitleTimeMilliseconds = max(0, milliseconds)
        currentSubtitlesVisible = isVisible
        currentVideoSize = videoSize

        switch source?.format {
        case .ass:
            srtSubtitleOverlayView?.setSource(nil)
            ensureSourceFaithfulASSOverlayView()
            sourceFaithfulASSOverlayView?.setPresentation(
                source: source,
                videoSize: videoSize,
                milliseconds: currentASSSubtitleTimeMilliseconds,
                isVisible: isVisible
            )
        case .srt:
            sourceFaithfulASSOverlayView?.setSource(nil)
            ensureSRTSubtitleOverlayView()
            srtSubtitleOverlayView?.setPresentation(
                source: source,
                videoSize: videoSize,
                milliseconds: currentASSSubtitleTimeMilliseconds,
                isVisible: isVisible
            )
        case nil:
            sourceFaithfulASSOverlayView?.setSource(nil)
            srtSubtitleOverlayView?.setSource(nil)
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

    func setSubtitleTime(milliseconds: Int) {
        currentASSSubtitleTimeMilliseconds = milliseconds
        sourceFaithfulASSOverlayView?.currentTimeMilliseconds = milliseconds
        srtSubtitleOverlayView?.currentTimeMilliseconds = milliseconds
    }

    func setASSSubtitleTime(milliseconds: Int) {
        setSubtitleTime(milliseconds: milliseconds)
    }

    func setSubtitlesVisible(_ isVisible: Bool) {
        currentSubtitlesVisible = isVisible
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
        if sourceFaithfulASSOverlayView == nil {
            sourceFaithfulASSOverlayView = SourceFaithfulASSSubtitleOverlayView(frame: bounds)
            sourceFaithfulASSOverlayView?.onRenderingFailure = { [weak self] message in
                self?.assRenderingFailureHandler?(message)
            }
            sourceFaithfulASSOverlayView?.onSourceLoadFailure = { [weak self] url in
                self?.subtitleSourceLoadFailureHandler?(url)
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

    private func ensureSRTSubtitleOverlayView() {
        if srtSubtitleOverlayView == nil {
            srtSubtitleOverlayView = SRTSubtitleOverlayView(frame: bounds)
            srtSubtitleOverlayView?.onRenderingFailure = { [weak self] message in
                self?.assRenderingFailureHandler?(message)
            }
            srtSubtitleOverlayView?.onSourceLoadFailure = { [weak self] url in
                self?.subtitleSourceLoadFailureHandler?(url)
            }
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
        srtSubtitleOverlayView.currentTimeMilliseconds = currentASSSubtitleTimeMilliseconds
        srtSubtitleOverlayView.areSubtitlesVisible = currentSubtitlesVisible
        srtSubtitleOverlayView.videoSize = currentVideoSize
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
