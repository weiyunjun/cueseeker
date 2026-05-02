import AppKit
import CNativePlayback
import Foundation

public protocol PlaybackPlayerDelegate: AnyObject {
    func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: PlaybackPropertyValue?)
    func player(_ player: PlaybackPlayer, didFailWithMessage message: String)
}

public final class PlaybackPlayer: NSObject, @unchecked Sendable {
    private let nativePlayer = SFXNativePlaybackPlayer()
    private var currentRequest: PlaybackRequest?
    private var storedVolume: Double = 100
    private var storedSpeed: Double = 1.0
    private var subtitlesVisible = true
    private var activeSubtitleSource: PlaybackSubtitleSource?
    private var subtitleLoadTask: Task<Void, Never>?

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
        currentRequest = request
        nativePlayer.playbackRate = Float(storedSpeed)
        try nativePlayer.openPath(
            request.videoURL.path,
            startMilliseconds: request.startMilliseconds
        )
        currentVideoURL = request.videoURL.standardizedFileURL
        loadSubtitleSource(request.subtitleSource)
        Task { @MainActor in
            self.attachActiveRenderView()
        }
        emitInitialNativeState()
    }

    public func seek(toMilliseconds milliseconds: Int) throws {
        try nativePlayer.seek(toMilliseconds: max(0, milliseconds))
        updateASSSubtitleTime(milliseconds: max(0, milliseconds))
    }

    public func setPaused(_ isPaused: Bool) throws {
        try nativePlayer.setPaused(isPaused)
    }

    public func stop() throws {
        nativePlayer.stop()
        currentRequest = nil
        currentVideoURL = nil
        loadSubtitleSource(nil)
        emitPauseState(isPaused: true)
    }

    public func loadSubtitleSource(_ source: PlaybackSubtitleSource?) {
        subtitleLoadTask?.cancel()
        activeSubtitleSource = source

        guard let source, source.format == .ass else {
            Task { @MainActor in
                (self.renderView as? PlaybackRenderContainerView)?.clearASSSubtitleScript()
            }
            return
        }

        Task { @MainActor in
            (self.renderView as? PlaybackRenderContainerView)?.clearASSSubtitleScript()
        }

        subtitleLoadTask = Task(priority: .userInitiated) { [weak self] in
            do {
                let contents = try String(contentsOf: source.url, encoding: .utf8)
                try Task.checkCancellation()
                let script = ASSLiteParser.parse(contents, timeWindow: source.timeWindow)
                try Task.checkCancellation()

                await MainActor.run { [weak self] in
                    guard let self,
                          self.activeSubtitleSource == source,
                          let container = self.renderView as? PlaybackRenderContainerView
                    else {
                        return
                    }

                    let currentMilliseconds = max(0, Int((self.nativePlayer.currentTime * 1_000).rounded(.down)))
                    container.setASSSubtitleScript(script)
                    container.setASSSubtitleTime(milliseconds: currentMilliseconds)
                    container.setSubtitlesVisible(self.subtitlesVisible)
                    container.setVideoSize(self.currentNativeVideoSize())
                }
            } catch is CancellationError {
                return
            } catch {
                print("Failed to load ASS subtitle source: \(error)")
                await MainActor.run { [weak self] in
                    guard let self,
                          self.activeSubtitleSource == source,
                          let container = self.renderView as? PlaybackRenderContainerView
                    else {
                        return
                    }

                    container.clearASSSubtitleScript()
                }
            }
        }
    }

    deinit {
        subtitleLoadTask?.cancel()
    }

    public func setSubtitlesVisible(_ isVisible: Bool) {
        subtitlesVisible = isVisible
        Task { @MainActor in
            (self.renderView as? PlaybackRenderContainerView)?.setSubtitlesVisible(isVisible)
        }
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

    private func updateASSSubtitleTime(milliseconds: Int) {
        Task { @MainActor in
            (self.renderView as? PlaybackRenderContainerView)?.setASSSubtitleTime(milliseconds: milliseconds)
        }
    }

    private func emitInitialNativeState() {
        delegate?.player(self, didChangeProperty: "duration", value: .double(nativePlayer.duration))
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
        updateASSSubtitleTime(milliseconds: milliseconds)
    }

    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFailWithMessage message: String
    ) {
        delegate?.player(self, didFailWithMessage: message)
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
    private var assOverlayView: ASSLiteSubtitleOverlayView?

    init() {
        super.init(frame: .zero)
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
        addSubview(view)
        ensureASSOverlayView()
        needsLayout = true
    }

    public override func layout() {
        super.layout()
        attachedView?.frame = bounds
        assOverlayView?.frame = bounds
    }

    func setASSSubtitleScript(_ script: ASSLiteScript) {
        ensureASSOverlayView()
        assOverlayView?.script = script
    }

    func clearASSSubtitleScript() {
        assOverlayView?.script = nil
    }

    func setASSSubtitleTime(milliseconds: Int) {
        assOverlayView?.currentTimeMilliseconds = milliseconds
    }

    func setSubtitlesVisible(_ isVisible: Bool) {
        ensureASSOverlayView()
        assOverlayView?.areSubtitlesVisible = isVisible
    }

    func setVideoSize(_ videoSize: CGSize?) {
        ensureASSOverlayView()
        assOverlayView?.videoSize = videoSize
    }

    private func ensureASSOverlayView() {
        if assOverlayView == nil {
            assOverlayView = ASSLiteSubtitleOverlayView(frame: bounds)
        }

        guard let assOverlayView else {
            return
        }

        if assOverlayView.superview !== self {
            addSubview(assOverlayView)
        }

        assOverlayView.frame = bounds

        if let attachedView {
            addSubview(assOverlayView, positioned: .above, relativeTo: attachedView)
        }
    }
}
