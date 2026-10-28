import Foundation
import CNativePlayback
import CueSeekerCore

public struct PlaybackVideoMetadataIndexer {
    public init() {}

    @discardableResult
    public func indexDurations(
        under folder: URL,
        into database: any PlaybackVideoMetadataPersistence
    ) throws -> PlaybackVideoMetadataIndexResult {
        try database.indexVideoMetadata(
            under: folder,
            probe: Self.probeMetadata
        )
    }

    @discardableResult
    public func indexDurations(
        videoFiles: [URL],
        into database: any PlaybackVideoMetadataPersistence,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) throws -> PlaybackVideoMetadataIndexResult {
        try database.indexVideoMetadata(
            videoFiles: videoFiles,
            onProgress: onProgress,
            probe: Self.probeMetadata
        )
    }

    private static func probeMetadata(for videoFile: URL) throws -> ProbedVideoMediaMetadata {
        let playableInput = WebDAVClient.shared.resolvePlayableInput(
            for: videoFile
        )
        let metadata = try SFXMediaMetadataInspector.metadata(
            atMediaPath: playableInput.inputPath,
            httpHeaders: playableInput.httpHeaders
        )
        let containerFormat: String?
        if let formatName = metadata.formatName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !formatName.isEmpty {
            let resolved = MediaDetailFormatter.resolvedVideoContainerExtension(
                formatName: formatName,
                majorBrand: metadata.majorBrand,
                videoCodec: metadata.videoCodec,
                fallbackExtension: videoFile.pathExtension
            )
            containerFormat = resolved.isEmpty ? nil : resolved
        } else {
            containerFormat = nil
        }
        return ProbedVideoMediaMetadata(
            durationSeconds: metadata.durationSeconds?.doubleValue,
            videoWidth: metadata.videoWidth?.intValue,
            videoHeight: metadata.videoHeight?.intValue,
            frameRate: metadata.frameRate?.doubleValue,
            videoCodec: metadata.videoCodec,
            videoBitDepth: metadata.videoBitDepth?.intValue,
            videoPixelFormat: metadata.videoPixelFormat,
            containerFormat: containerFormat,
            audioTracks: metadata.audioTracks.map {
                VideoAudioTrack(
                    language: $0.language,
                    title: $0.title,
                    codec: $0.codec,
                    channels: $0.channels?.intValue,
                    sampleRate: $0.sampleRate?.intValue,
                    bitDepth: $0.bitDepth?.intValue
                )
            }
        )
    }
}
