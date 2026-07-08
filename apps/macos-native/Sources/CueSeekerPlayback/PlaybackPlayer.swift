import AppKit
import CNativePlayback
import CueSeekerCore
import Foundation
import QuartzCore

public protocol PlaybackPlayerDelegate: AnyObject {
    func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: PlaybackPropertyValue?)
    func player(_ player: PlaybackPlayer, didFailWithMessage message: String)
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int)
}

public extension PlaybackPlayerDelegate {
    func player(_ player: PlaybackPlayer, didFinishSegmentAtMilliseconds endMilliseconds: Int) {}
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

    public func open(_ request: PlaybackRequest) throws {
        clearHeldSubtitlePresentationWithoutRendering()
        currentRequest = request
        nativePlayer.playbackRate = Float(storedSpeed)
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
        currentVideoURL = request.videoURL.standardizedFileURL
        loadSubtitleSource(request.subtitleSource)
        Task { @MainActor in
            self.attachActiveRenderView()
        }
        emitInitialNativeState()
    }

    public func seek(toMilliseconds milliseconds: Int) throws {
        clearHeldSubtitlePresentationWithoutRendering()
        try nativePlayer.seek(toMilliseconds: max(0, milliseconds))
        updateASSSubtitleTime(milliseconds: max(0, milliseconds))
    }

    public func seek(to segment: PlaybackSegment) throws {
        clearHeldSubtitlePresentationWithoutRendering()
        try nativePlayer.seek(
            toMilliseconds: segment.startMilliseconds,
            endMilliseconds: segment.endMilliseconds
        )
        updateASSSubtitleTime(milliseconds: segment.startMilliseconds)
    }

    public func seek(toMilliseconds milliseconds: Int, pauseAfterFirstFrame: Bool) throws {
        let safeMilliseconds = max(0, milliseconds)
        clearHeldSubtitlePresentationWithoutRendering()
        try nativePlayer.seek(
            toMilliseconds: safeMilliseconds,
            pauseAfterFirstFrame: pauseAfterFirstFrame
        )
        updateASSSubtitleTime(milliseconds: safeMilliseconds)
    }

    public func seek(to segment: PlaybackSegment, pauseAfterFirstFrame: Bool) throws {
        clearHeldSubtitlePresentationWithoutRendering()
        try nativePlayer.seek(
            toMilliseconds: segment.startMilliseconds,
            endMilliseconds: segment.endMilliseconds,
            pauseAfterFirstFrame: pauseAfterFirstFrame
        )
        updateASSSubtitleTime(milliseconds: segment.startMilliseconds)
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
        clearHeldSubtitlePresentationWithoutRendering()
        loadSubtitleSource(nil)
        emitPauseState(isPaused: true)
    }

    public func loadSubtitleSource(_ source: PlaybackSubtitleSource?) {
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
        }
    }

    private func updateASSSubtitleTimeFromNative(milliseconds: Int) {
        let effectiveMilliseconds = renderedASSSubtitleMilliseconds(
            forNativeMilliseconds: milliseconds
        )
        Task { @MainActor in
            (self.renderView as? PlaybackRenderContainerView)?.setASSSubtitleTime(milliseconds: effectiveMilliseconds)
        }
    }

    private func currentNativePlaybackMilliseconds() -> Int {
        max(0, Int((nativePlayer.currentTime * 1_000).rounded(.down)))
    }

    private func effectiveASSSubtitleMilliseconds(_ milliseconds: Int) -> Int {
        heldSubtitlePresentationMilliseconds ?? max(0, milliseconds)
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
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    private func stopASSSubtitleRenderTicks() {
        subtitleRenderTickTask?.cancel()
        subtitleRenderTickTask = nil
    }

    private func emitInitialNativeState() {
        delegate?.player(self, didChangeProperty: "duration", value: .double(nativePlayer.duration))
        if let aspectRatio = currentNativeVideoAspectRatio() {
            delegate?.player(self, didChangeProperty: "video-aspect-ratio", value: .double(aspectRatio))
        }
        delegate?.player(self, didChangeProperty: "pause", value: .bool(false))
        delegate?.player(self, didChangeProperty: "volume", value: .double(storedVolume))
        delegate?.player(self, didChangeProperty: "speed", value: .double(storedSpeed))
    }

    private func emitPauseState(isPaused: Bool) {
        delegate?.player(self, didChangeProperty: "pause", value: .bool(isPaused))
    }
}

extension PlaybackPlayer: SFXNativePlaybackPlayerDelegate {
    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool
    ) {
        delegate?.player(self, didChangeProperty: "time-pos", value: .double(time))
        delegate?.player(self, didChangeProperty: "duration", value: .double(duration))
        delegate?.player(self, didChangeProperty: "pause", value: .bool(!playing))
        let milliseconds = max(0, Int((time * 1_000).rounded(.down)))
        updateASSSubtitleTimeFromNative(milliseconds: milliseconds)
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
