import AppKit
import CNativePlayback
import CueSeekerCore
import Foundation
import QuartzCore

public protocol PlaybackPlayerDelegate: AnyObject {
    func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: PlaybackPropertyValue?)
    func player(_ player: PlaybackPlayer, didFailWithMessage message: String)
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int)
    @MainActor func player(
        _ player: PlaybackPlayer,
        didCommitPresentationAtMilliseconds milliseconds: Int,
        generation: UInt,
        playing: Bool
    )
}

public extension PlaybackPlayerDelegate {
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int) {}
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
    var preparedASSSubtitleToken: UUID?
    var preparedASSSubtitleVideoFrameMilliseconds: Int?
    var preparedASSSubtitleRenderMilliseconds: Int?
    var isASSSubtitleReady: Bool
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
        beginPresentationTransition(
            targetMilliseconds: request.startMilliseconds,
            subtitleAction: .replace(request.subtitleSource)
        )
        currentRequest = request
        nativePlayer.playbackRate = Float(storedSpeed)
        do {
            if let segmentEndMilliseconds = request.segmentEndMilliseconds {
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
        cancelPreparedASSSubtitleSource()
    }

    @discardableResult
    private func seek(
        toMilliseconds milliseconds: Int,
        pauseAfterFirstFrame: Bool,
        subtitleAction: PendingSubtitleAction
    ) throws -> UInt {
        let safeMilliseconds = max(0, milliseconds)
        beginPresentationTransition(
            targetMilliseconds: safeMilliseconds,
            subtitleAction: subtitleAction
        )
        do {
            try nativePlayer.seek(
                toMilliseconds: safeMilliseconds,
                pauseAfterFirstFrame: pauseAfterFirstFrame
            )
        } catch {
            cancelPendingPresentation()
            throw error
        }
        return bindPendingPresentationToNativeGeneration()
    }

    @discardableResult
    private func seek(
        to segment: PlaybackSegment,
        pauseAfterFirstFrame: Bool,
        subtitleAction: PendingSubtitleAction
    ) throws -> UInt {
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
        cancelPreparedASSSubtitleSource()
        pendingPresentation = PendingPresentation(
            generation: nil,
            targetMilliseconds: max(0, targetMilliseconds),
            heldMilliseconds: max(0, heldMilliseconds),
            subtitleAction: subtitleAction,
            preparedASSSubtitleToken: nil,
            preparedASSSubtitleVideoFrameMilliseconds: nil,
            preparedASSSubtitleRenderMilliseconds: nil,
            isASSSubtitleReady: false
        )
    }

    private func bindPendingPresentationToNativeGeneration() -> UInt {
        let generation = nativePlayer.nativePresentationGeneration
        pendingPresentation?.generation = generation
        return generation
    }

    private func cancelPreparedASSSubtitleSource() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                (renderView as? PlaybackRenderContainerView)?.cancelPreparedASSSubtitleSource()
            }
        } else {
            Task { @MainActor in
                (self.renderView as? PlaybackRenderContainerView)?.cancelPreparedASSSubtitleSource()
            }
        }
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
        try nativePlayer.setPaused(isPaused)
    }

    public func stop() throws {
        nativePlayer.stop()
        currentRequest = nil
        currentVideoURL = nil
        pendingPresentation = nil
        committedPresentationGeneration = nil
        cancelPreparedASSSubtitleSource()
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

    public func loadSubtitleSource(_ source: PlaybackSubtitleSource?) {
        if pendingPresentation != nil {
            let generation = pendingPresentation?.generation
            pendingPresentation?.subtitleAction = .replace(source)
            pendingPresentation?.preparedASSSubtitleToken = nil
            pendingPresentation?.preparedASSSubtitleVideoFrameMilliseconds = nil
            pendingPresentation?.preparedASSSubtitleRenderMilliseconds = nil
            pendingPresentation?.isASSSubtitleReady = false
            cancelPreparedASSSubtitleSource()
            if let generation {
                nativePlayer.resumeVideoPresentation(forGeneration: generation)
            }
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
    private func shouldPresentVideoFrame(
        atMilliseconds milliseconds: Int,
        generation: UInt
    ) -> Bool {
        guard var pendingPresentation else {
            return committedPresentationGeneration == generation
        }
        guard pendingPresentation.generation == generation else {
            return false
        }

        let source: PlaybackSubtitleSource?
        switch pendingPresentation.subtitleAction {
        case .preserve:
            source = activeSubtitleSource
        case .replace(let replacement):
            source = replacement
        }
        guard let source, source.format == .ass else {
            return true
        }

        let videoFrameMilliseconds = max(0, milliseconds)
        let renderMilliseconds = source.initialRenderTimestamp(
            fallbackMilliseconds: videoFrameMilliseconds
        )
        if pendingPresentation.isASSSubtitleReady,
           pendingPresentation.preparedASSSubtitleToken != nil,
           pendingPresentation.preparedASSSubtitleVideoFrameMilliseconds == videoFrameMilliseconds,
           pendingPresentation.preparedASSSubtitleRenderMilliseconds == renderMilliseconds {
            return true
        }
        if pendingPresentation.preparedASSSubtitleToken != nil,
           pendingPresentation.preparedASSSubtitleVideoFrameMilliseconds == videoFrameMilliseconds,
           pendingPresentation.preparedASSSubtitleRenderMilliseconds == renderMilliseconds {
            return false
        }

        guard let container = renderView as? PlaybackRenderContainerView else {
            failPendingPresentation(
                generation: generation,
                message: "ASS subtitle presentation could not attach to the playback view."
            )
            return false
        }
        let token = container.prepareSourceFaithfulASSSubtitleSource(
            source,
            at: renderMilliseconds,
            videoSize: currentNativeVideoSize()
        ) { [weak self] token, result in
            guard let self,
                  var current = self.pendingPresentation,
                  current.generation == generation,
                  current.preparedASSSubtitleToken == token,
                  current.preparedASSSubtitleVideoFrameMilliseconds == videoFrameMilliseconds
            else {
                return
            }

            switch result {
            case .success:
                current.isASSSubtitleReady = true
                self.pendingPresentation = current
                self.nativePlayer.resumeVideoPresentation(forGeneration: generation)
            case .failure(let error):
                self.failPendingPresentation(
                    generation: generation,
                    message: error.message
                )
            }
        }
        pendingPresentation.preparedASSSubtitleToken = token
        pendingPresentation.preparedASSSubtitleVideoFrameMilliseconds = videoFrameMilliseconds
        pendingPresentation.preparedASSSubtitleRenderMilliseconds = renderMilliseconds
        pendingPresentation.isASSSubtitleReady = false
        self.pendingPresentation = pendingPresentation
        return false
    }

    @MainActor
    private func failPendingPresentation(generation: UInt, message: String) {
        guard let pendingPresentation,
              pendingPresentation.generation == generation
        else {
            return
        }
        heldSubtitlePresentationMilliseconds = pendingPresentation.heldMilliseconds
        self.pendingPresentation = nil
        (renderView as? PlaybackRenderContainerView)?.cancelPreparedASSSubtitleSource()
        try? nativePlayer.setPaused(true)
        delegate?.player(self, didFailWithMessage: message)
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

        let targetSubtitleSource: PlaybackSubtitleSource?
        switch pendingPresentation.subtitleAction {
        case .preserve:
            targetSubtitleSource = activeSubtitleSource
        case .replace(let source):
            targetSubtitleSource = source
        }

        if let targetSubtitleSource, targetSubtitleSource.format == .ass {
            guard let token = pendingPresentation.preparedASSSubtitleToken,
                  pendingPresentation.isASSSubtitleReady,
                  let renderMilliseconds = pendingPresentation.preparedASSSubtitleRenderMilliseconds,
                  commitPreparedASSSubtitleSource(
                    token: token,
                    source: targetSubtitleSource,
                    videoMilliseconds: safeMilliseconds,
                    renderMilliseconds: renderMilliseconds
                  )
            else {
                failPendingPresentation(
                    generation: generation,
                    message: "ASS subtitle presentation was not ready for the target video frame."
                )
                return
            }
        } else {
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
        }

        self.pendingPresentation = nil
        committedPresentationGeneration = generation
        heldSubtitlePresentationMilliseconds = nil

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
    private func commitPreparedASSSubtitleSource(
        token: UUID,
        source: PlaybackSubtitleSource,
        videoMilliseconds: Int,
        renderMilliseconds: Int
    ) -> Bool {
        guard let container = renderView as? PlaybackRenderContainerView,
              container.commitPreparedASSSubtitleSource(
                token,
                source: source,
                milliseconds: renderMilliseconds,
                videoSize: currentNativeVideoSize()
              )
        else {
            return false
        }

        subtitleLoadTask?.cancel()
        activeSubtitleSource = source
        lastRenderedASSSubtitleMilliseconds = renderMilliseconds
        let initialGate = PlaybackSubtitleRenderTimeGate(
            source: source,
            fallbackMilliseconds: videoMilliseconds
        )
        assSubtitleRenderTimeGate = initialGate?.retargetingHeldTimestamp(
            forExplicitMilliseconds: renderMilliseconds
        ) ?? initialGate
        container.assRenderingFailureHandler = { [weak self] message in
            guard let self else { return }
            self.delegate?.player(self, didFailWithMessage: message)
        }
        container.setSubtitlesVisible(subtitlesVisible)
        startASSSubtitleRenderTicks()
        return true
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
        shouldPresentVideoFrameAtMilliseconds milliseconds: Int,
        presentationGeneration: UInt
    ) -> Bool {
        guard Thread.isMainThread else {
            return false
        }
        return MainActor.assumeIsolated {
            shouldPresentVideoFrame(
                atMilliseconds: milliseconds,
                generation: presentationGeneration
            )
        }
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
        let generation = player.nativePresentationGeneration
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                if pendingPresentation?.generation == generation {
                    failPendingPresentation(generation: generation, message: message)
                } else {
                    delegate?.player(self, didFailWithMessage: message)
                }
            }
        } else {
            Task { @MainActor in
                if self.pendingPresentation?.generation == generation {
                    self.failPendingPresentation(generation: generation, message: message)
                } else {
                    self.delegate?.player(self, didFailWithMessage: message)
                }
            }
        }
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didReachEndWithoutVideoFrameForPresentationGeneration presentationGeneration: UInt
    ) {
        let message = "No decodable video frame was available at the requested playback position."
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                failPendingPresentation(
                    generation: presentationGeneration,
                    message: message
                )
            }
        } else {
            Task { @MainActor in
                self.failPendingPresentation(
                    generation: presentationGeneration,
                    message: message
                )
            }
        }
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFinishSegmentAtMilliseconds endMilliseconds: Int
    ) {
        delegate?.player(self, didFinishSegmentAtMilliseconds: endMilliseconds)
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

    @discardableResult
    func prepareSourceFaithfulASSSubtitleSource(
        _ source: PlaybackSubtitleSource,
        at milliseconds: Int,
        videoSize: CGSize?,
        completion: @escaping @MainActor @Sendable (
            UUID,
            Result<Void, SourceFaithfulASSSubtitlePreparationError>
        ) -> Void
    ) -> UUID {
        ensureSourceFaithfulASSOverlayView()
        return sourceFaithfulASSOverlayView!.prepareSource(
            source,
            at: milliseconds,
            videoSize: videoSize,
            completion: completion
        )
    }

    @discardableResult
    func commitPreparedASSSubtitleSource(
        _ token: UUID,
        source: PlaybackSubtitleSource,
        milliseconds: Int,
        videoSize: CGSize?
    ) -> Bool {
        guard sourceFaithfulASSOverlayView?.commitPreparedSource(token) == true else {
            return false
        }
        currentASSSubtitleSource = source
        currentASSSubtitleTimeMilliseconds = max(0, milliseconds)
        currentVideoSize = videoSize
        return true
    }

    func cancelPreparedASSSubtitleSource() {
        sourceFaithfulASSOverlayView?.cancelPreparedSource()
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
