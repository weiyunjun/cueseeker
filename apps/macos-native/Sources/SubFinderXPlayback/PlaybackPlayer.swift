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
        Task { @MainActor in
            self.attachActiveRenderView()
        }
        emitInitialNativeState()
    }

    public func seek(toMilliseconds milliseconds: Int) throws {
        try nativePlayer.seek(toMilliseconds: max(0, milliseconds))
    }

    public func setPaused(_ isPaused: Bool) throws {
        try nativePlayer.setPaused(isPaused)
    }

    public func stop() throws {
        nativePlayer.stop()
        currentRequest = nil
        currentVideoURL = nil
        emitPauseState(isPaused: true)
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
        // Native playback does not render embedded subtitles in the first app integration.
        // The command is accepted so the existing subtitle toggle UI remains usable.
        if name != "sid" {
            throw PlaybackError.nativePropertyUnsupported(name: name)
        }
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
        needsLayout = true
    }

    public override func layout() {
        super.layout()
        attachedView?.frame = bounds
    }
}
