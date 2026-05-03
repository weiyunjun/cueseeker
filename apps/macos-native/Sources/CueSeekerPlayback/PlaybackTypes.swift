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

public enum ASSSubtitleRenderingMode: String, CaseIterable, Identifiable, Sendable, Equatable {
    case fullFrameRGBA
    case sparseImages

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .fullFrameRGBA:
            "Full Frame"
        case .sparseImages:
            "Sparse Images"
        }
    }
}

public enum PlaybackSubtitleSourceFormat: String, Sendable, Equatable {
    case ass
}

public struct PlaybackSubtitleSource: Equatable, Sendable {
    public let url: URL
    public let format: PlaybackSubtitleSourceFormat
    public let preparationTimeWindow: PlaybackSubtitleTimeWindow?

    public init(
        url: URL,
        format: PlaybackSubtitleSourceFormat,
        preparationTimeWindow: PlaybackSubtitleTimeWindow? = nil
    ) {
        self.url = url
        self.format = format
        self.preparationTimeWindow = preparationTimeWindow
    }
}

public struct PlaybackSubtitleTimeWindow: Equatable, Sendable {
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(startMilliseconds: Int, endMilliseconds: Int) {
        let startMilliseconds = max(0, startMilliseconds)
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = max(startMilliseconds, endMilliseconds)
    }

    public func overlaps(startMilliseconds: Int, endMilliseconds: Int) -> Bool {
        let cueStartMilliseconds = max(0, startMilliseconds)
        let cueEndMilliseconds = max(cueStartMilliseconds, endMilliseconds)

        if cueStartMilliseconds == cueEndMilliseconds {
            return cueStartMilliseconds >= self.startMilliseconds
                && cueStartMilliseconds <= self.endMilliseconds
        }

        return cueStartMilliseconds < self.endMilliseconds
            && cueEndMilliseconds > self.startMilliseconds
    }
}

public struct PlaybackRequest: Equatable, Sendable {
    public let videoURL: URL
    public let startMilliseconds: Int
    public let subtitleSource: PlaybackSubtitleSource?

    public init(
        videoURL: URL,
        startMilliseconds: Int,
        subtitleSource: PlaybackSubtitleSource? = nil
    ) throws {
        guard videoURL.isFileURL else {
            throw PlaybackError.invalidVideoURL(videoURL.absoluteString)
        }

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw PlaybackError.missingVideoFile(videoURL.path)
        }

        self.videoURL = videoURL
        self.startMilliseconds = max(0, startMilliseconds)
        self.subtitleSource = subtitleSource
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
