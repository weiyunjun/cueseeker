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
    case native
    case legacy

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .native:
            "native v0"
        case .legacy:
            "legacy libass"
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
    public let renderCacheDatabaseURL: URL?
    public let renderCacheSubtitlePath: String?

    public init(
        url: URL,
        format: PlaybackSubtitleSourceFormat,
        preparationTimeWindow: PlaybackSubtitleTimeWindow? = nil,
        renderCacheDatabaseURL: URL? = nil,
        renderCacheSubtitlePath: String? = nil
    ) {
        self.url = url
        self.format = format
        self.preparationTimeWindow = preparationTimeWindow
        self.renderCacheDatabaseURL = renderCacheDatabaseURL
        self.renderCacheSubtitlePath = renderCacheSubtitlePath
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
    public let httpHeaders: [String: String]
    public let startMilliseconds: Int
    public let subtitleSource: PlaybackSubtitleSource?

    public init(
        videoURL: URL,
        httpHeaders: [String: String] = [:],
        startMilliseconds: Int,
        subtitleSource: PlaybackSubtitleSource? = nil
    ) throws {
        guard videoURL.isFileURL || videoURL.isHTTPURL else {
            throw PlaybackError.invalidVideoURL(videoURL.absoluteString)
        }

        if videoURL.isFileURL && !FileManager.default.fileExists(atPath: videoURL.path) {
            throw PlaybackError.missingVideoFile(videoURL.path)
        }

        self.videoURL = videoURL
        self.httpHeaders = httpHeaders
        self.startMilliseconds = max(0, startMilliseconds)
        self.subtitleSource = subtitleSource
    }

    public var nativeMediaPath: String {
        videoURL.isFileURL ? videoURL.path : videoURL.absoluteString
    }

    public var mediaIdentifier: String {
        nativeMediaPath
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

private extension URL {
    var isHTTPURL: Bool {
        guard let scheme else {
            return false
        }
        return ["http", "https"].contains(scheme.lowercased())
    }
}
