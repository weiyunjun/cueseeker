import AppKit
import CMpv
import CNativePlayback
import Foundation

public enum PlaybackBackend: String, Sendable {
    case native
    case mpv
}

public protocol PlaybackPlayerDelegate: AnyObject {
    func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: MPVPropertyValue?)
    func player(_ player: PlaybackPlayer, didSwitchBackend backend: PlaybackBackend)
    func player(_ player: PlaybackPlayer, didFailWithMessage message: String)
}

public final class PlaybackPlayer: NSObject, @unchecked Sendable {
    private let nativePlayer = SFXNativePlaybackPlayer()
    private let mpvPlayerFactory: () throws -> MPVPlayer
    private var mpvPlayer: MPVPlayer?
    private var observedProperties: [(name: String, format: mpv_format)] = []
    private var activeBackendStorage: PlaybackBackend = .native
    private var currentRequest: PlaybackRequest?
    private var storedVolume: Double = 100
    private var storedSpeed: Double = 1.0

    public weak var delegate: PlaybackPlayerDelegate?

    public private(set) var currentVideoURL: URL?

    public var activeBackend: PlaybackBackend {
        activeBackendStorage
    }

    @MainActor public lazy var renderView: NSView = PlaybackRenderContainerView()

    public init(mpvPlayerFactory: @escaping () throws -> MPVPlayer = { try MPVPlayer() }) {
        self.mpvPlayerFactory = mpvPlayerFactory
        super.init()
        nativePlayer.delegate = self
        nativePlayer.volume = Float(storedVolume / 100)
    }

    public func open(_ request: PlaybackRequest) throws {
        currentRequest = request
        currentVideoURL = request.videoURL.standardizedFileURL

        do {
            try openNative(request)
            return
        } catch {
            print("Native playback failed, falling back to mpv: \(error)")
        }

        try openMPV(request)
    }

    public func seek(toMilliseconds milliseconds: Int) throws {
        switch activeBackendStorage {
        case .native:
            try nativePlayer.seek(toMilliseconds: max(0, milliseconds))
        case .mpv:
            try requireMPVPlayer().seek(toMilliseconds: milliseconds)
        }
    }

    public func setPaused(_ isPaused: Bool) throws {
        switch activeBackendStorage {
        case .native:
            try nativePlayer.setPaused(isPaused)
        case .mpv:
            try requireMPVPlayer().setPaused(isPaused)
        }
    }

    public func stop() throws {
        nativePlayer.stop()
        try mpvPlayer?.stop()
        currentRequest = nil
        currentVideoURL = nil
        notifyBackendIfNeeded(.native)
        emitPauseState(isPaused: true)
    }

    public func getDoubleProperty(_ name: String) throws -> Double {
        switch activeBackendStorage {
        case .native:
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
                throw PlaybackError.mpvOptionFailed(name: name, message: "Native playback property is unsupported.")
            }
        case .mpv:
            return try requireMPVPlayer().getDoubleProperty(name)
        }
    }

    public func setDoubleProperty(_ name: String, value: Double) throws {
        switch activeBackendStorage {
        case .native:
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
                throw PlaybackError.mpvOptionFailed(name: name, message: "Native playback property is unsupported.")
            }
        case .mpv:
            let mpvPlayer = try requireMPVPlayer()
            if name == "volume" {
                storedVolume = min(max(value, 0), 100)
            } else if name == "speed" {
                storedSpeed = min(max(value, 0.5), 2.0)
            }
            try mpvPlayer.setDoubleProperty(name, value: name == "speed" ? storedSpeed : value)
        }
    }

    public func setStringProperty(_ name: String, value: String) throws {
        switch activeBackendStorage {
        case .native:
            // Native playback does not render embedded subtitles in the first app integration.
            // The command is accepted so the existing subtitle toggle UI remains usable.
            if name != "sid" {
                throw PlaybackError.mpvOptionFailed(name: name, message: "Native playback string property is unsupported.")
            }
        case .mpv:
            try requireMPVPlayer().setStringProperty(name, value: value)
        }
    }

    public func getBoolProperty(_ name: String) throws -> Bool {
        switch activeBackendStorage {
        case .native:
            if name == "pause" {
                return !nativePlayer.isPlaying
            }
            throw PlaybackError.mpvOptionFailed(name: name, message: "Native playback bool property is unsupported.")
        case .mpv:
            return try requireMPVPlayer().getBoolProperty(name)
        }
    }

    public func setBoolProperty(_ name: String, value: Bool) throws {
        switch activeBackendStorage {
        case .native:
            if name == "pause" {
                try nativePlayer.setPaused(value)
            } else {
                throw PlaybackError.mpvOptionFailed(name: name, message: "Native playback bool property is unsupported.")
            }
        case .mpv:
            try requireMPVPlayer().setBoolProperty(name, value: value)
        }
    }

    public func observeProperty(_ name: String, format: mpv_format) {
        observedProperties.append((name, format))
        mpvPlayer?.observeProperty(name, format: format)
    }

    @MainActor public func attachActiveRenderView() {
        guard let container = renderView as? PlaybackRenderContainerView else {
            return
        }

        switch activeBackendStorage {
        case .native:
            container.attach(nativePlayer.view)
        case .mpv:
            guard let mpvPlayer else {
                return
            }
            container.attach(mpvPlayer.renderView)
        }
    }

    private func openNative(_ request: PlaybackRequest) throws {
        nativePlayer.playbackRate = Float(storedSpeed)
        try nativePlayer.openPath(
            request.videoURL.path,
            startMilliseconds: request.startMilliseconds
        )
        try? mpvPlayer?.stop()
        notifyBackendIfNeeded(.native)
        Task { @MainActor in
            self.attachActiveRenderView()
            self.releaseMPVPlayerIfNativeIsActive()
        }
        emitInitialNativeState()
    }

    private func openMPV(_ request: PlaybackRequest) throws {
        nativePlayer.stop()
        let mpvPlayer = try requireMPVPlayer()
        try mpvPlayer.open(request)
        notifyBackendIfNeeded(.mpv)
        Task { @MainActor in
            self.attachActiveRenderView()
        }
        if abs(storedVolume - 100) > 0.001 {
            try? mpvPlayer.setDoubleProperty("volume", value: storedVolume)
        }
        if abs(storedSpeed - 1.0) > 0.001 {
            try? mpvPlayer.setDoubleProperty("speed", value: storedSpeed)
        }
    }

    private func requireMPVPlayer() throws -> MPVPlayer {
        if let mpvPlayer {
            return mpvPlayer
        }

        let player = try mpvPlayerFactory()
        player.delegate = self
        for property in observedProperties {
            player.observeProperty(property.name, format: property.format)
        }
        mpvPlayer = player
        return player
    }

    @MainActor private func releaseMPVPlayerIfNativeIsActive() {
        guard activeBackendStorage == .native else {
            return
        }
        mpvPlayer = nil
    }

    private func notifyBackendIfNeeded(_ backend: PlaybackBackend) {
        guard activeBackendStorage != backend else {
            return
        }
        activeBackendStorage = backend
        print("Playback backend: \(backend.rawValue)")
        delegate?.player(self, didSwitchBackend: backend)
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

extension PlaybackPlayer: MPVPlayerDelegate {
    public func player(_ player: MPVPlayer, didChangeProperty name: String, value: MPVPropertyValue?) {
        guard activeBackendStorage == .mpv else {
            return
        }
        delegate?.player(self, didChangeProperty: name, value: value)
    }
}

extension PlaybackPlayer: SFXNativePlaybackPlayerDelegate {
    public func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool
    ) {
        guard activeBackendStorage == .native else {
            return
        }
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
