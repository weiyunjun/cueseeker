import Foundation
import CueSeekerCore

public enum PlaybackPropertyValue: Sendable, Equatable {
    case double(Double)
    case bool(Bool)
}

public struct PlaybackSegment: Equatable, Sendable {
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(startMilliseconds: Int, endMilliseconds: Int) {
        let startMilliseconds = max(0, startMilliseconds)
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = max(startMilliseconds, endMilliseconds)
    }
}

public struct PlaybackAutoStopBoundary: Equatable, Sendable {
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(startMilliseconds: Int, endMilliseconds: Int) {
        let startMilliseconds = max(0, startMilliseconds)
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = max(startMilliseconds, endMilliseconds)
    }
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

public enum PlaybackSubtitleSourceFormat: String, Sendable, Equatable {
    case srt
    case ass
}

public struct PlaybackSubtitleSource: Equatable, Sendable {
    public let url: URL
    public let format: PlaybackSubtitleSourceFormat
    public let matchedVideoURL: URL?
    public let initialTimestampMilliseconds: Int?
    public let preparationTimeWindow: PlaybackSubtitleTimeWindow?
    public let renderCacheDatabaseURL: URL?

    public init(
        url: URL,
        format: PlaybackSubtitleSourceFormat,
        matchedVideoURL: URL? = nil,
        initialTimestampMilliseconds: Int? = nil,
        preparationTimeWindow: PlaybackSubtitleTimeWindow? = nil,
        renderCacheDatabaseURL: URL? = nil
    ) {
        self.url = url
        self.format = format
        self.matchedVideoURL = matchedVideoURL
        self.initialTimestampMilliseconds = initialTimestampMilliseconds.map { max(0, $0) }
        self.preparationTimeWindow = preparationTimeWindow
        self.renderCacheDatabaseURL = renderCacheDatabaseURL
    }

    public func initialRenderTimestamp(fallbackMilliseconds: Int) -> Int {
        let requestedTimestamp = max(0, initialTimestampMilliseconds ?? fallbackMilliseconds)
        guard let preparationTimeWindow else {
            return requestedTimestamp
        }

        return preparationTimeWindow.clampedTimestampMilliseconds(requestedTimestamp)
    }

    public func fillingPlaybackRequestDefaults(
        fallbackVideoURL: URL,
        startMilliseconds: Int
    ) -> PlaybackSubtitleSource {
        PlaybackSubtitleSource(
            url: url,
            format: format,
            matchedVideoURL: matchedVideoURL ?? fallbackVideoURL,
            initialTimestampMilliseconds: initialTimestampMilliseconds ?? max(0, startMilliseconds),
            preparationTimeWindow: preparationTimeWindow,
            renderCacheDatabaseURL: renderCacheDatabaseURL
        )
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

    public func clampedTimestampMilliseconds(_ milliseconds: Int) -> Int {
        let timestamp = max(0, milliseconds)
        guard endMilliseconds > startMilliseconds else {
            return startMilliseconds
        }

        return min(max(timestamp, startMilliseconds), endMilliseconds - 1)
    }

    public func contains(timestampMilliseconds: Int) -> Bool {
        let timestamp = max(0, timestampMilliseconds)
        guard endMilliseconds > startMilliseconds else {
            return timestamp == startMilliseconds
        }

        return timestamp >= startMilliseconds && timestamp < endMilliseconds
    }
}

struct PlaybackSubtitleRenderTimeGateDecision: Equatable, Sendable {
    let timestampMilliseconds: Int
    let releasesGate: Bool
}

struct PlaybackSubtitleRenderTimeGate: Equatable, Sendable {
    private(set) var heldTimestampMilliseconds: Int
    let preparationTimeWindow: PlaybackSubtitleTimeWindow

    init?(source: PlaybackSubtitleSource, fallbackMilliseconds: Int) {
        guard let preparationTimeWindow = source.preparationTimeWindow else {
            return nil
        }

        self.heldTimestampMilliseconds = source.initialRenderTimestamp(
            fallbackMilliseconds: fallbackMilliseconds
        )
        self.preparationTimeWindow = preparationTimeWindow
    }

    func retargetingHeldTimestamp(forExplicitMilliseconds milliseconds: Int) -> PlaybackSubtitleRenderTimeGate? {
        let timestamp = max(0, milliseconds)
        guard preparationTimeWindow.contains(timestampMilliseconds: timestamp) else {
            return nil
        }

        var nextGate = self
        nextGate.heldTimestampMilliseconds = timestamp
        return nextGate
    }

    func renderTimestamp(forNativeMilliseconds milliseconds: Int) -> PlaybackSubtitleRenderTimeGateDecision {
        let nativeMilliseconds = max(0, milliseconds)
        guard preparationTimeWindow.contains(timestampMilliseconds: nativeMilliseconds) else {
            return PlaybackSubtitleRenderTimeGateDecision(
                timestampMilliseconds: heldTimestampMilliseconds,
                releasesGate: false
            )
        }

        return PlaybackSubtitleRenderTimeGateDecision(
            timestampMilliseconds: nativeMilliseconds,
            releasesGate: true
        )
    }
}

public struct PlaybackRequest: Equatable, Sendable {
    public let videoURL: URL
    public let startMilliseconds: Int
    public let segmentEndMilliseconds: Int?
    public let autoStopAtMilliseconds: Int?
    public let subtitleSource: PlaybackSubtitleSource?
    /// Counted from 0 among the file's audio streams; a file without it plays
    /// its first audio track.
    public let audioTrackIndex: Int

    public init(
        videoURL: URL,
        startMilliseconds: Int,
        segmentEndMilliseconds: Int? = nil,
        autoStopAtMilliseconds: Int? = nil,
        subtitleSource: PlaybackSubtitleSource? = nil,
        audioTrackIndex: Int = 0
    ) throws {
        guard videoURL.isFileURL || videoURL.isWebDAVURL || videoURL.isSMBURL else {
            throw PlaybackError.invalidVideoURL(videoURL.absoluteString)
        }

        if videoURL.isFileURL {
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                throw PlaybackError.missingVideoFile(videoURL.path)
            }
        }

        let safeStartMilliseconds = max(0, startMilliseconds)
        self.videoURL = videoURL
        self.startMilliseconds = safeStartMilliseconds
        self.segmentEndMilliseconds = segmentEndMilliseconds.map {
            max(safeStartMilliseconds, $0)
        }
        self.autoStopAtMilliseconds = autoStopAtMilliseconds.map {
            max(safeStartMilliseconds, $0)
        }
        self.subtitleSource = subtitleSource?.fillingPlaybackRequestDefaults(
            fallbackVideoURL: videoURL.standardizedMediaURL,
            startMilliseconds: safeStartMilliseconds
        )
        self.audioTrackIndex = max(0, audioTrackIndex)
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
