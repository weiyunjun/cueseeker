import CMpv
import Foundation

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
}

public enum PlaybackError: Error, Equatable, CustomStringConvertible {
    case invalidVideoURL(String)
    case missingVideoFile(String)
    case mpvCreateFailed
    case mpvInitializeFailed(String)
    case mpvOptionFailed(name: String, message: String)
    case mpvCommandFailed(command: String, message: String)

    public var description: String {
        switch self {
        case .invalidVideoURL(let url):
            "Invalid video URL: \(url)"
        case .missingVideoFile(let path):
            "Video file does not exist: \(path)"
        case .mpvCreateFailed:
            "Failed to create libmpv handle."
        case .mpvInitializeFailed(let message):
            "Failed to initialize libmpv: \(message)"
        case .mpvOptionFailed(let name, let message):
            "Failed to set libmpv option \(name): \(message)"
        case .mpvCommandFailed(let command, let message):
            "Failed to run libmpv command \(command): \(message)"
        }
    }
}

public final class MPVPlayer {
    private var handle: OpaquePointer?

    public init(viewID: UInt? = nil) throws {
        guard let handle = mpv_create() else {
            throw PlaybackError.mpvCreateFailed
        }

        self.handle = handle

        do {
            try setOption(name: "terminal", value: "no")
            try setOption(name: "idle", value: "yes")
            try setOption(name: "keep-open", value: "yes")
            try setOption(name: "force-window", value: "yes")

            if let viewID {
                try setOption(name: "wid", value: String(viewID))
            }

            let status = mpv_initialize(handle)
            guard status >= 0 else {
                throw PlaybackError.mpvInitializeFailed(Self.errorMessage(for: status))
            }
        } catch {
            mpv_terminate_destroy(handle)
            self.handle = nil
            throw error
        }
    }

    deinit {
        if let handle {
            mpv_terminate_destroy(handle)
        }
    }

    public func open(_ request: PlaybackRequest) throws {
        try command([
            "loadfile",
            request.videoURL.path,
            "replace",
            String(format: "start=%.3f", request.startSeconds)
        ])
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
