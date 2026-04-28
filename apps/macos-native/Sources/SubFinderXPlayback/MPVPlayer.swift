import CMpv
import Darwin
import Foundation

public enum MPVPropertyValue: Sendable, Equatable {
    case double(Double)
    case bool(Bool)
}

public protocol MPVPlayerDelegate: AnyObject {
    func player(_ player: MPVPlayer, didChangeProperty name: String, value: MPVPropertyValue?)
}

public struct PlaybackRequest: Equatable, Sendable {
    public let videoURL: URL
    public let startMilliseconds: Int

    public init(videoURL: URL, startMilliseconds: Int) throws {
        guard videoURL.isFileURL else {
            throw PlaybackError.invalidVideoURL(videoURL.absoluteString)
        }

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw PlaybackError.missingVideoFile(videoURL.path)
        }

        self.videoURL = videoURL
        self.startMilliseconds = max(0, startMilliseconds)
    }

    var startSeconds: Double {
        Double(startMilliseconds) / 1_000
    }

    var loadfileCommandArguments: [String] {
        [
            "loadfile",
            videoURL.path,
            "replace",
            "0",
            String(format: "start=%.3f", startSeconds)
        ]
    }
}

public enum PlaybackError: Error, Equatable, CustomStringConvertible {
    case invalidVideoURL(String)
    case missingVideoFile(String)
    case mpvCreateFailed
    case missingPlaybackView
    case mpvInitializeFailed(String)
    case mpvOptionFailed(name: String, message: String)
    case mpvCommandFailed(command: String, message: String)
    case mpvRenderContextCreateFailed(String)
    case mpvRenderFailed(String)

    public var description: String {
        switch self {
        case .invalidVideoURL(let url):
            "Invalid video URL: \(url)"
        case .missingVideoFile(let path):
            "Video file does not exist: \(path)"
        case .mpvCreateFailed:
            "Failed to create libmpv handle."
        case .missingPlaybackView:
            "Playback view is not ready."
        case .mpvInitializeFailed(let message):
            "Failed to initialize libmpv: \(message)"
        case .mpvOptionFailed(let name, let message):
            "Failed to set libmpv option \(name): \(message)"
        case .mpvCommandFailed(let command, let message):
            "Failed to run libmpv command \(command): \(message)"
        case .mpvRenderContextCreateFailed(let message):
            "Failed to create libmpv render context: \(message)"
        case .mpvRenderFailed(let message):
            "Failed to render libmpv frame: \(message)"
        }
    }
}

public final class MPVPlayer: @unchecked Sendable {
    private var handle: OpaquePointer?
    private var renderContext: OpaquePointer?
    private var eventThread: Thread?
    private var isTerminated = false
    
    public weak var delegate: MPVPlayerDelegate?
    public private(set) var currentVideoURL: URL?
    @MainActor public lazy var renderView: MPVRenderView = MPVRenderView(player: self)

    public init() throws {
        guard let handle = mpv_create() else {
            throw PlaybackError.mpvCreateFailed
        }

        self.handle = handle

        do {
            try setOption(name: "terminal", value: "no")
            try setOption(name: "idle", value: "yes")
            try setOption(name: "keep-open", value: "yes")
            try setOption(name: "vo", value: "libmpv")

            let status = mpv_initialize(handle)
            guard status >= 0 else {
                throw PlaybackError.mpvInitializeFailed(Self.errorMessage(for: status))
            }
            
            startEventLoop()
        } catch {
            mpv_terminate_destroy(handle)
            self.handle = nil
            throw error
        }
    }

    deinit {
        isTerminated = true
        if let handle {
            mpv_wakeup(handle)
        }
        
        destroyRenderContext()

        if let handle {
            mpv_terminate_destroy(handle)
        }
    }

    public func open(_ request: PlaybackRequest) throws {
        try command(request.loadfileCommandArguments)
        currentVideoURL = request.videoURL.standardizedFileURL
    }

    public func seek(toMilliseconds milliseconds: Int) throws {
        try command([
            "seek",
            String(format: "%.3f", Double(max(0, milliseconds)) / 1_000),
            "absolute+exact"
        ])
    }

    public func setPaused(_ isPaused: Bool) throws {
        try command([
            "set",
            "pause",
            isPaused ? "yes" : "no"
        ])
    }

    public func stop() throws {
        try command(["stop"])
        currentVideoURL = nil
    }

    public func getDoubleProperty(_ name: String) throws -> Double {
        guard let handle else { throw PlaybackError.mpvCreateFailed }
        var value: Double = 0
        let status = mpv_get_property(handle, name, MPV_FORMAT_DOUBLE, &value)
        guard status >= 0 else {
            throw PlaybackError.mpvOptionFailed(name: name, message: Self.errorMessage(for: status))
        }
        return value
    }

    public func setDoubleProperty(_ name: String, value: Double) throws {
        guard let handle else { throw PlaybackError.mpvCreateFailed }
        var val = value
        let status = mpv_set_property(handle, name, MPV_FORMAT_DOUBLE, &val)
        guard status >= 0 else {
            throw PlaybackError.mpvOptionFailed(name: name, message: Self.errorMessage(for: status))
        }
    }

    public func setStringProperty(_ name: String, value: String) throws {
        guard let handle else { throw PlaybackError.mpvCreateFailed }

        let status = name.withCString { namePointer in
            value.withCString { valuePointer in
                mpv_set_property_string(handle, namePointer, valuePointer)
            }
        }

        guard status >= 0 else {
            throw PlaybackError.mpvOptionFailed(name: name, message: Self.errorMessage(for: status))
        }
    }

    public func getBoolProperty(_ name: String) throws -> Bool {
        guard let handle else { throw PlaybackError.mpvCreateFailed }
        var value: Int32 = 0
        let status = mpv_get_property(handle, name, MPV_FORMAT_FLAG, &value)
        guard status >= 0 else {
            throw PlaybackError.mpvOptionFailed(name: name, message: Self.errorMessage(for: status))
        }
        return value != 0
    }

    public func setBoolProperty(_ name: String, value: Bool) throws {
        guard let handle else { throw PlaybackError.mpvCreateFailed }
        var val: Int32 = value ? 1 : 0
        let status = mpv_set_property(handle, name, MPV_FORMAT_FLAG, &val)
        guard status >= 0 else {
            throw PlaybackError.mpvOptionFailed(name: name, message: Self.errorMessage(for: status))
        }
    }

    public func observeProperty(_ name: String, format: mpv_format) {
        guard let handle else { return }
        mpv_observe_property(handle, 0, name, format)
    }

    private func startEventLoop() {
        eventThread = Thread { [weak self] in
            self?.runEventLoop()
        }
        eventThread?.name = "SubFinderX.MPVEventThread"
        eventThread?.start()
    }

    private func runEventLoop() {
        while !isTerminated {
            guard let handle else { break }
            let event = mpv_wait_event(handle, 1.0)
            guard let event = event, event.pointee.event_id != MPV_EVENT_NONE else {
                continue
            }
            if event.pointee.event_id == MPV_EVENT_SHUTDOWN {
                break
            }
            if event.pointee.event_id == MPV_EVENT_PROPERTY_CHANGE {
                let prop = event.pointee.data.bindMemory(to: mpv_event_property.self, capacity: 1)
                let name = String(cString: prop.pointee.name)
                var value: MPVPropertyValue? = nil
                
                if prop.pointee.format == MPV_FORMAT_DOUBLE {
                    let doubleValue = prop.pointee.data.bindMemory(to: Double.self, capacity: 1).pointee
                    value = .double(doubleValue)
                } else if prop.pointee.format == MPV_FORMAT_FLAG {
                    let boolValue = prop.pointee.data.bindMemory(to: Int32.self, capacity: 1).pointee != 0
                    value = .bool(boolValue)
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.player(self, didChangeProperty: name, value: value)
                }
            }
        }
    }

    func createOpenGLRenderContext(
        updateCallback: mpv_render_update_fn?,
        updateContext: UnsafeMutableRawPointer?
    ) throws {
        guard renderContext == nil else {
            return
        }

        guard let handle else {
            throw PlaybackError.mpvCreateFailed
        }

        var context: OpaquePointer?
        var apiType = MPV_RENDER_API_TYPE_OPENGL
        var initParameters = mpv_opengl_init_params(
            get_proc_address: openglGetProcAddress,
            get_proc_address_ctx: nil
        )

        let status = withUnsafeMutablePointer(to: &apiType) { apiTypePointer in
            withUnsafeMutablePointer(to: &initParameters) { initParametersPointer in
                var parameters = [
                    mpv_render_param(
                        type: MPV_RENDER_PARAM_API_TYPE,
                        data: UnsafeMutableRawPointer(apiTypePointer)
                    ),
                    mpv_render_param(
                        type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
                        data: UnsafeMutableRawPointer(initParametersPointer)
                    ),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                ]

                return parameters.withUnsafeMutableBufferPointer { parametersPointer in
                    mpv_render_context_create(&context, handle, parametersPointer.baseAddress)
                }
            }
        }

        guard status >= 0, let context else {
            throw PlaybackError.mpvRenderContextCreateFailed(Self.errorMessage(for: status))
        }

        renderContext = context
        mpv_render_context_set_update_callback(context, updateCallback, updateContext)
    }

    func destroyRenderContext() {
        guard let renderContext else {
            return
        }

        mpv_render_context_set_update_callback(renderContext, nil, nil)
        mpv_render_context_free(renderContext)
        self.renderContext = nil
    }

    func renderOpenGL(width: Int32, height: Int32) throws {
        guard let renderContext else {
            return
        }

        _ = mpv_render_context_update(renderContext)

        var fbo = mpv_opengl_fbo(
            fbo: 0,
            w: Int32(max(1, width)),
            h: Int32(max(1, height)),
            internal_format: 0
        )
        var flipY: Int32 = 1

        let status = withUnsafeMutablePointer(to: &fbo) { fboPointer in
            withUnsafeMutablePointer(to: &flipY) { flipYPointer in
                var parameters = [
                    mpv_render_param(
                        type: MPV_RENDER_PARAM_OPENGL_FBO,
                        data: UnsafeMutableRawPointer(fboPointer)
                    ),
                    mpv_render_param(
                        type: MPV_RENDER_PARAM_FLIP_Y,
                        data: UnsafeMutableRawPointer(flipYPointer)
                    ),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                ]

                return parameters.withUnsafeMutableBufferPointer { parametersPointer in
                    mpv_render_context_render(renderContext, parametersPointer.baseAddress)
                }
            }
        }

        guard status >= 0 else {
            throw PlaybackError.mpvRenderFailed(Self.errorMessage(for: status))
        }

        mpv_render_context_report_swap(renderContext)
    }

    private func setOption(name: String, value: String) throws {
        guard let handle else {
            throw PlaybackError.mpvCreateFailed
        }

        let status = name.withCString { namePointer in
            value.withCString { valuePointer in
                mpv_set_option_string(handle, namePointer, valuePointer)
            }
        }

        guard status >= 0 else {
            throw PlaybackError.mpvOptionFailed(
                name: name,
                message: Self.errorMessage(for: status)
            )
        }
    }

    private func command(_ arguments: [String]) throws {
        guard let handle else {
            throw PlaybackError.mpvCreateFailed
        }

        let duplicatedArguments = arguments.map { strdup($0) }
        defer {
            for argument in duplicatedArguments {
                free(argument)
            }
        }

        var commandArguments = duplicatedArguments.map {
            UnsafePointer<CChar>($0)
        }
        commandArguments.append(nil)

        let status = commandArguments.withUnsafeMutableBufferPointer { buffer in
            mpv_command(handle, buffer.baseAddress)
        }

        guard status >= 0 else {
            throw PlaybackError.mpvCommandFailed(
                command: arguments.first ?? "",
                message: Self.errorMessage(for: status)
            )
        }
    }

    private static func errorMessage(for status: Int32) -> String {
        guard let message = mpv_error_string(status) else {
            return "Unknown libmpv error \(status)"
        }

        return String(cString: message)
    }
}

private func openglGetProcAddress(
    _ context: UnsafeMutableRawPointer?,
    _ name: UnsafePointer<CChar>?
) -> UnsafeMutableRawPointer? {
    guard let name else {
        return nil
    }

    let framework = dlopen(
        "/System/Library/Frameworks/OpenGL.framework/OpenGL",
        RTLD_LAZY
    )

    return dlsym(framework, name)
}
