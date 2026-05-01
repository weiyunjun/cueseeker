import Foundation

public enum PlaybackPropertyValue: Sendable, Equatable {
    case double(Double)
    case bool(Bool)
}

public enum PlaybackDecodeMode: String, CaseIterable, Identifiable, Sendable, Equatable {
    case hardware
    case software
    case auto

    public var id: String {
        rawValue
    }

    public var displayName: String {
        rawValue
    }
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
}

public enum PlaybackError: Error, Equatable, CustomStringConvertible {
    case invalidVideoURL(String)
    case missingVideoFile(String)
    case playbackPlayerUnavailable
    case nativePropertyUnsupported(name: String)

    public var description: String {
        switch self {
        case .invalidVideoURL(let url):
            "Invalid video URL: \(url)"
        case .missingVideoFile(let path):
            "Video file does not exist: \(path)"
        case .playbackPlayerUnavailable:
            "Playback player is not available."
        case .nativePropertyUnsupported(let name):
            "Native playback property is unsupported: \(name)"
        }
    }
}
