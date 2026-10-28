import AppKit
import CASSRendering
import CNativePlayback
import CueSeekerCore
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct SubtitleCollageGroupRenderMetrics: Sendable, Equatable {
    public let subtitleLoadMilliseconds: Double
    public let frameGrabMilliseconds: Double
    public let subtitleRenderMilliseconds: Double

    public init(
        subtitleLoadMilliseconds: Double = 0,
        frameGrabMilliseconds: Double = 0,
        subtitleRenderMilliseconds: Double = 0
    ) {
        self.subtitleLoadMilliseconds = subtitleLoadMilliseconds
        self.frameGrabMilliseconds = frameGrabMilliseconds
        self.subtitleRenderMilliseconds = subtitleRenderMilliseconds
    }
}

public struct SubtitleCollageRenderedGroup: @unchecked Sendable {
    let image: CGImage
    let subtitleBands: [ClosedRange<Int>]
    public let metrics: SubtitleCollageGroupRenderMetrics

    public init(
        image: CGImage,
        subtitleBands: [ClosedRange<Int>],
        metrics: SubtitleCollageGroupRenderMetrics = SubtitleCollageGroupRenderMetrics()
    ) {
        self.image = image
        self.subtitleBands = subtitleBands
        self.metrics = metrics
    }
}

public final class SubtitleCollageRenderSession: @unchecked Sendable {
    private static let maximumCachedVideoFrames = 8

    private let videoURL: URL
    private let subtitleSource: PlaybackSubtitleSource
    private let srtSubtitleStyle: SRTSubtitleStyle
    private let videoFrameProvider: (@Sendable (String, Int) async throws -> CGImage)?
    private let lock = NSLock()
    private let inputResolutionLock = NSLock()
    private var cachedPreparedASSScript: SubtitleScreenshotExporter.PreparedASSRenderScript?
    private var cachedRequestedFontNames: [String]?
    private var hasPreparedASSScript = false
    private var cachedVideoFrames: [(timestampMilliseconds: Int, image: CGImage)] = []
    private var cachedPlayableInput: WebDAVPlayableInput?
    private var cachedContainerProbe: SubtitleScreenshotExporter.VideoContainerProbeResult?

    public init(
        videoURL: URL,
        subtitleSource: PlaybackSubtitleSource,
        srtSubtitleStyle: SRTSubtitleStyle,
        videoFrameProvider: (@Sendable (String, Int) async throws -> CGImage)? = nil
    ) {
        self.videoURL = videoURL
        self.subtitleSource = subtitleSource
        self.srtSubtitleStyle = srtSubtitleStyle
        self.videoFrameProvider = videoFrameProvider
    }

    public func renderGroup(
        _ group: SubtitleCollageGroup
    ) async throws -> SubtitleCollageRenderedGroup {
        try Task.checkCancellation()
        let (preparedASSScript, requestedFontNames, subtitleLoadMilliseconds) =
            try prepareASSRenderInputsIfNeeded()
        try Task.checkCancellation()
        let timestampMilliseconds = group.renderTimestampMilliseconds
        let (frameImage, frameGrabMilliseconds) = try await resolveVideoFrame(
            timestampMilliseconds: timestampMilliseconds
        )
        try Task.checkCancellation()
        let subtitleRenderStart = DispatchTime.now().uptimeNanoseconds
        let renderedFrame = try SubtitleScreenshotExporter.renderSelectedSubtitleFrame(
            group: group,
            source: subtitleSource,
            preparedASSScript: preparedASSScript,
            requestedFontNames: requestedFontNames,
            timestampMilliseconds: timestampMilliseconds,
            frameImage: frameImage,
            srtSubtitleStyle: srtSubtitleStyle
        )
        let subtitleRenderMilliseconds = SubtitleScreenshotExporter.elapsedMilliseconds(
            since: subtitleRenderStart
        )
        return SubtitleCollageRenderedGroup(
            image: renderedFrame.image,
            subtitleBands: renderedFrame.subtitleBands.map {
                $0.y1...$0.y2
            },
            metrics: SubtitleCollageGroupRenderMetrics(
                subtitleLoadMilliseconds: subtitleLoadMilliseconds,
                frameGrabMilliseconds: frameGrabMilliseconds,
                subtitleRenderMilliseconds: subtitleRenderMilliseconds
            )
        )
    }

    private func resolveVideoFrame(
        timestampMilliseconds: Int
    ) async throws -> (image: CGImage, frameGrabMilliseconds: Double) {
        if let cachedImage = cachedVideoFrame(for: timestampMilliseconds) {
            return (cachedImage, 0)
        }

        let frameGrabStart = DispatchTime.now().uptimeNanoseconds
        let frameImage: CGImage
        if let videoFrameProvider {
            frameImage = try await videoFrameProvider(
                videoURL.mediaPath,
                timestampMilliseconds
            )
        } else {
            guard let ffmpegExecutable = SubtitleScreenshotExporter.ffmpegExecutable() else {
                throw SubtitleScreenshotExportError.ffmpegNotFound
            }
            let (playableInput, containerProbe) = resolveInputAndContainerProbe()
            frameImage = try await SubtitleScreenshotExporter.videoFrame(
                videoPath: videoURL.mediaPath,
                timestampMilliseconds: timestampMilliseconds,
                ffmpegExecutable: ffmpegExecutable,
                playableInput: playableInput,
                containerProbe: containerProbe
            )
        }
        let frameGrabMilliseconds = SubtitleScreenshotExporter.elapsedMilliseconds(
            since: frameGrabStart
        )
        storeCachedVideoFrame(frameImage, for: timestampMilliseconds)
        return (frameImage, frameGrabMilliseconds)
    }

    private func resolveInputAndContainerProbe() -> (
        playableInput: WebDAVPlayableInput,
        containerProbe: SubtitleScreenshotExporter.VideoContainerProbeResult
    ) {
        inputResolutionLock.lock()
        defer {
            inputResolutionLock.unlock()
        }
        if let cachedPlayableInput, let cachedContainerProbe {
            return (cachedPlayableInput, cachedContainerProbe)
        }
        let playableInput = WebDAVClient.shared.resolvePlayableInput(for: videoURL)
        let probe = SubtitleScreenshotExporter.probeVideoContainer(
            resolvedInputPath: playableInput.inputPath,
            httpHeaders: playableInput.httpHeaders
        )
        cachedPlayableInput = playableInput
        cachedContainerProbe = probe
        return (playableInput, probe)
    }

    private func cachedVideoFrame(for timestampMilliseconds: Int) -> CGImage? {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard let index = cachedVideoFrames.firstIndex(where: {
            $0.timestampMilliseconds == timestampMilliseconds
        }) else {
            return nil
        }
        let entry = cachedVideoFrames.remove(at: index)
        cachedVideoFrames.append(entry)
        return entry.image
    }

    private func storeCachedVideoFrame(
        _ image: CGImage,
        for timestampMilliseconds: Int
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }
        cachedVideoFrames.removeAll {
            $0.timestampMilliseconds == timestampMilliseconds
        }
        cachedVideoFrames.append((
            timestampMilliseconds: timestampMilliseconds,
            image: image
        ))
        if cachedVideoFrames.count > Self.maximumCachedVideoFrames {
            cachedVideoFrames.removeFirst(
                cachedVideoFrames.count - Self.maximumCachedVideoFrames
            )
        }
    }

    private func prepareASSRenderInputsIfNeeded() throws -> (
        preparedScript: SubtitleScreenshotExporter.PreparedASSRenderScript?,
        requestedFontNames: [String]?,
        subtitleLoadMilliseconds: Double
    ) {
        guard subtitleSource.format == .ass else {
            return (nil, nil, 0)
        }

        lock.lock()
        defer {
            lock.unlock()
        }

        if hasPreparedASSScript {
            return (cachedPreparedASSScript, cachedRequestedFontNames, 0)
        }

        let startNanoseconds = DispatchTime.now().uptimeNanoseconds
        let sourceScript = try SubtitleTextDecoder.decode(
            contentsOf: subtitleSource.url,
            format: .ass
        )
        let preparedScript = SubtitleScreenshotExporter.PreparedASSRenderScript(sourceScript)
        let requestedFontNames = try? ASSPlaybackFontIntentProvider.requestedFontNames(
            sourcePath: subtitleSource.url.mediaPath,
            renderCacheProvider: subtitleSource.renderCacheProvider
        )
        let subtitleLoadMilliseconds = SubtitleScreenshotExporter.elapsedMilliseconds(
            since: startNanoseconds
        )

        cachedPreparedASSScript = preparedScript
        cachedRequestedFontNames = requestedFontNames
        hasPreparedASSScript = true

        return (preparedScript, requestedFontNames, subtitleLoadMilliseconds)
    }
}

/// A collage and where each group sits in it: the groups' heights in image
/// pixels, in group order, so a viewer can map a point back to its group.
public struct SubtitleCollageComposition: @unchecked Sendable {
    public let image: CGImage
    public let groupHeights: [Int]

    public init(image: CGImage, groupHeights: [Int]) {
        self.image = image
        self.groupHeights = groupHeights
    }
}

public enum SubtitleScreenshotExportError: Error, CustomStringConvertible {
    case emptyItems
    case ffmpegNotFound
    case missingFrameImage(String)
    case imageDecodeFailed(String)
    case imageContextFailed
    case pngWriteFailed(String)
    case processFailed(String, Int32, String)

    public var description: String {
        switch self {
        case .emptyItems:
            "No subtitle screenshot items."
        case .ffmpegNotFound:
            "ffmpeg was not found."
        case .missingFrameImage(let path):
            "Video frame image was not created: \(path)"
        case .imageDecodeFailed(let path):
            "Could not decode image: \(path)"
        case .imageContextFailed:
            "Could not create image rendering context."
        case .pngWriteFailed(let path):
            "Could not write PNG file: \(path)"
        case .processFailed(let executable, let status, let output):
            "\(executable) exited with status \(status). \(output)"
        }
    }
}

public enum SubtitleScreenshotExporter {
    struct FFmpegExecutable: Sendable {
        let url: URL
        let supportsSkipInternalSubtitles: Bool
    }

    struct VideoContainerProbeResult: Equatable, Sendable {
        let isMatroska: Bool
        let canSkipFindStreamInfo: Bool
        let swapsVideoDimensions: Bool

        init(
            isMatroska: Bool,
            canSkipFindStreamInfo: Bool,
            swapsVideoDimensions: Bool = false
        ) {
            self.isMatroska = isMatroska
            self.canSkipFindStreamInfo = canSkipFindStreamInfo
            self.swapsVideoDimensions = swapsVideoDimensions
        }

        static func evaluate(
            formatName: String,
            hasHeaderVideoParameters: Bool,
            swapsVideoDimensions: Bool = false
        ) -> VideoContainerProbeResult {
            let formatTokens = Set(
                formatName
                    .lowercased()
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            )
            let isMatroska = formatTokens.contains("matroska") || formatTokens.contains("webm")
            let isISOContainer = !formatTokens.isDisjoint(
                with: ["mov", "mp4", "m4a", "3gp", "3g2", "mj2"]
            )
            let canSkipFindStreamInfo = hasHeaderVideoParameters
                && (isMatroska || isISOContainer)
            return VideoContainerProbeResult(
                isMatroska: isMatroska,
                canSkipFindStreamInfo: canSkipFindStreamInfo,
                swapsVideoDimensions: swapsVideoDimensions
            )
        }
    }

    struct PreparedASSRenderScript: Sendable {
        private enum SectionDisposition {
            case keptHeaderOrStyles
            case events
            case ignored
        }

        private static let scriptInfoSection = Array("[script info]".utf8)
        private static let v4PlusStylesSection = Array("[v4+ styles]".utf8)
        private static let v4StylesSection = Array("[v4 styles]".utf8)
        private static let v4StylesPlusSection = Array("[v4 styles+]".utf8)

        private let utf8Bytes: [UInt8]
        private let prefixBytes: [UInt8]
        private let dialogueRanges: [Range<Int>]

        init(_ sourceScript: String) {
            let utf8Bytes = Array(sourceScript.utf8)
            var headerAndStyleBytes: [UInt8] = []
            var eventsHeaderBytes: [UInt8] = []
            var dialogueRanges: [Range<Int>] = []

            utf8Bytes.withUnsafeBufferPointer { bytes in
                var currentSection: SectionDisposition = .keptHeaderOrStyles
                ASSScriptScanner.scanLines(bytes) { lineRange, kind in
                    switch kind {
                    case .sectionHeader(let isEvents):
                        if isEvents {
                            currentSection = .events
                            SubtitleScreenshotExporter.appendWithoutBOM(
                                bytes,
                                in: lineRange,
                                to: &eventsHeaderBytes
                            )
                            eventsHeaderBytes.append(0x0A)
                        } else if Self.isKeptMetadataOrStyleSection(bytes, in: lineRange) {
                            currentSection = .keptHeaderOrStyles
                            SubtitleScreenshotExporter.appendWithoutBOM(
                                bytes,
                                in: lineRange,
                                to: &headerAndStyleBytes
                            )
                            headerAndStyleBytes.append(0x0A)
                        } else {
                            currentSection = .ignored
                        }

                    case .eventFormat:
                        SubtitleScreenshotExporter.appendWithoutBOM(
                            bytes,
                            in: lineRange,
                            to: &eventsHeaderBytes
                        )
                        eventsHeaderBytes.append(0x0A)

                    case .dialogue:
                        dialogueRanges.append(lineRange)

                    case .other:
                        guard currentSection == .keptHeaderOrStyles,
                              Self.shouldKeepHeaderOrStyleLine(bytes, in: lineRange)
                        else {
                            return
                        }
                        SubtitleScreenshotExporter.appendWithoutBOM(
                            bytes,
                            in: lineRange,
                            to: &headerAndStyleBytes
                        )
                        headerAndStyleBytes.append(0x0A)
                    }
                }
            }

            var prefixBytes = headerAndStyleBytes
            prefixBytes.append(contentsOf: eventsHeaderBytes)
            self.utf8Bytes = utf8Bytes
            self.prefixBytes = prefixBytes
            self.dialogueRanges = dialogueRanges
        }

        func script(for eventIndices: Set<Int>) -> String? {
            guard !eventIndices.isEmpty,
                  eventIndices.allSatisfy({ $0 >= 0 && $0 < dialogueRanges.count })
            else {
                return nil
            }

            return utf8Bytes.withUnsafeBufferPointer { bytes in
                var selectedSignatures: [[UInt8]] = []
                selectedSignatures.reserveCapacity(eventIndices.count)
                for eventIndex in eventIndices.sorted() {
                    let signature = SubtitleScreenshotExporter.glyphSignature(
                        bytes,
                        dialogueRanges[eventIndex]
                    )
                    if !selectedSignatures.contains(signature) {
                        selectedSignatures.append(signature)
                    }
                }

                var selectedBytes = prefixBytes
                selectedBytes.reserveCapacity(prefixBytes.count + eventIndices.count * 128)

                for (eventIndex, lineRange) in dialogueRanges.enumerated() {
                    let isIncluded = eventIndices.contains(eventIndex)
                        || selectedSignatures.contains { signature in
                            SubtitleScreenshotExporter.matchesGlyphSignature(
                                bytes,
                                lineRange,
                                signature
                            )
                        }
                    guard isIncluded else {
                        continue
                    }
                    SubtitleScreenshotExporter.appendWithoutBOM(
                        bytes,
                        in: lineRange,
                        to: &selectedBytes
                    )
                    selectedBytes.append(0x0A)
                }

                return String(decoding: selectedBytes, as: UTF8.self)
            }
        }

        private static func isKeptMetadataOrStyleSection(
            _ bytes: UnsafeBufferPointer<UInt8>,
            in lineRange: Range<Int>
        ) -> Bool {
            let trimmed = trimmedRange(bytes, in: lineRange)
            guard !trimmed.isEmpty else {
                return false
            }
            if bytes[trimmed.lowerBound] >= 0x80
                || (bytes[trimmed.lowerBound] == 0x5B && bytes[trimmed.upperBound - 1] >= 0x80) {
                let normalized = String(decoding: bytes[lineRange], as: UTF8.self)
                    .replacingOccurrences(of: "\u{feff}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return normalized == "[script info]"
                    || normalized == "[v4+ styles]"
                    || normalized == "[v4 styles]"
                    || normalized == "[v4 styles+]"
            }
            return equalsIgnoringASCIICase(bytes, trimmed, scriptInfoSection)
                || equalsIgnoringASCIICase(bytes, trimmed, v4PlusStylesSection)
                || equalsIgnoringASCIICase(bytes, trimmed, v4StylesSection)
                || equalsIgnoringASCIICase(bytes, trimmed, v4StylesPlusSection)
        }

        private static func shouldKeepHeaderOrStyleLine(
            _ bytes: UnsafeBufferPointer<UInt8>,
            in lineRange: Range<Int>
        ) -> Bool {
            let trimmed = trimmedRange(bytes, in: lineRange)
            guard !trimmed.isEmpty else {
                return false
            }
            let first = bytes[trimmed.lowerBound]
            if first == 0x3B {
                return false
            }
            if first == 0x21,
               trimmed.count >= 2,
               bytes[trimmed.lowerBound + 1] == 0x3A {
                return false
            }
            return true
        }

        private static func trimmedRange(
            _ bytes: UnsafeBufferPointer<UInt8>,
            in lineRange: Range<Int>
        ) -> Range<Int> {
            var start = lineRange.lowerBound
            var end = lineRange.upperBound

            while start < end {
                if isASCIIWhitespace(bytes[start]) {
                    start += 1
                } else if end - start >= 3,
                          bytes[start] == 0xEF,
                          bytes[start + 1] == 0xBB,
                          bytes[start + 2] == 0xBF {
                    start += 3
                } else {
                    break
                }
            }
            while end > start, isASCIIWhitespace(bytes[end - 1]) {
                end -= 1
            }
            return start..<end
        }

        private static func isASCIIWhitespace(_ byte: UInt8) -> Bool {
            byte == 0x20 || (byte >= 0x09 && byte <= 0x0D)
        }

        private static func lowercasedASCII(_ byte: UInt8) -> UInt8 {
            byte >= 0x41 && byte <= 0x5A ? byte + 0x20 : byte
        }

        private static func equalsIgnoringASCIICase(
            _ bytes: UnsafeBufferPointer<UInt8>,
            _ range: Range<Int>,
            _ expected: [UInt8]
        ) -> Bool {
            guard range.count == expected.count else {
                return false
            }
            for offset in expected.indices
            where lowercasedASCII(bytes[range.lowerBound + offset]) != expected[offset] {
                return false
            }
            return true
        }
    }

    fileprivate struct SubtitleBand: Equatable {
        let y1: Int
        let y2: Int

        var height: Int {
            y2 - y1 + 1
        }
    }

    fileprivate struct RenderedSubtitleFrame {
        let image: CGImage
        let subtitleBands: [SubtitleBand]
    }

    public static func defaultCollageFileName(
        displayTitle: String,
        plan: SubtitleCollageSelectionPlan
    ) -> String {
        SubtitleCollageSelectionPlan.defaultCollageFileName(
            displayTitle: displayTitle,
            plan: plan
        )
    }

    public static func exportCollage(
        image: CGImage,
        to destinationURL: URL
    ) throws {
        try writePNG(image, to: destinationURL)
    }

    public static func renderCollage(
        plan: SubtitleCollageSelectionPlan,
        videoURL: URL,
        subtitleSource: PlaybackSubtitleSource,
        srtSubtitleStyle: SRTSubtitleStyle
    ) async throws -> CGImage {
        guard plan.selectedCueCount > 0, !plan.groups.isEmpty else {
            throw SubtitleScreenshotExportError.emptyItems
        }

        let renderedGroups = try await renderCollageGroups(
            plan.groups,
            videoURL: videoURL,
            subtitleSource: subtitleSource,
            srtSubtitleStyle: srtSubtitleStyle
        )
        return try composeCollage(renderedGroups).image
    }

    public static func renderCollageGroups(
        _ groups: [SubtitleCollageGroup],
        videoURL: URL,
        subtitleSource: PlaybackSubtitleSource,
        srtSubtitleStyle: SRTSubtitleStyle
    ) async throws -> [SubtitleCollageRenderedGroup] {
        guard !groups.isEmpty else {
            return []
        }

        let session = SubtitleCollageRenderSession(
            videoURL: videoURL,
            subtitleSource: subtitleSource,
            srtSubtitleStyle: srtSubtitleStyle
        )
        var renderedGroups: [SubtitleCollageRenderedGroup] = []
        renderedGroups.reserveCapacity(groups.count)

        for group in groups {
            renderedGroups.append(try await session.renderGroup(group))
        }

        return renderedGroups
    }

    public static func composeCollage(
        _ renderedGroups: [SubtitleCollageRenderedGroup]
    ) throws -> SubtitleCollageComposition {
        let renderedFrames = renderedGroups.map { group in
            RenderedSubtitleFrame(
                image: group.image,
                subtitleBands: group.subtitleBands.map {
                    SubtitleBand(y1: $0.lowerBound, y2: $0.upperBound)
                }
            )
        }
        guard let collage = collageComposition(from: renderedFrames) else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }
        return collage
    }

    static func elapsedMilliseconds(since startNanoseconds: UInt64) -> Double {
        let endNanoseconds = DispatchTime.now().uptimeNanoseconds
        guard endNanoseconds >= startNanoseconds else {
            return 0
        }
        return Double(endNanoseconds - startNanoseconds) / 1_000_000
    }

    static func videoFrame(
        videoPath: String,
        timestampMilliseconds: Int,
        ffmpegExecutable: FFmpegExecutable,
        playableInput: WebDAVPlayableInput? = nil,
        containerProbe: VideoContainerProbeResult? = nil
    ) async throws -> CGImage {
        // BMP keeps the frame uncompressed and self-describing, so the pixels
        // reach the compositor without a PNG round trip through the file system.
        // The 10-bit sources this reads would otherwise produce a 16-bit
        // intermediate that the 8-bit compositing context discards anyway.
        let resolvedInput = playableInput ?? WebDAVClient.shared.resolvePlayableInput(
            for: URL.fromMediaPath(videoPath)
        )
        let resolvedProbe = containerProbe ?? probeVideoContainer(
            resolvedInputPath: resolvedInput.inputPath,
            httpHeaders: resolvedInput.httpHeaders
        )
        let arguments = videoFrameArguments(
            playableInput: resolvedInput,
            timestampMilliseconds: timestampMilliseconds,
            supportsSkipInternalSubtitles: ffmpegExecutable.supportsSkipInternalSubtitles,
            containerProbe: resolvedProbe
        )
        do {
            let frameData = try await runProcessCapturingStandardOutput(
                executableURL: ffmpegExecutable.url,
                arguments: arguments
            )
            guard !frameData.isEmpty else {
                throw SubtitleScreenshotExportError.missingFrameImage(videoPath)
            }
            return try loadImage(from: frameData, sourceDescription: videoPath)
        } catch {
            guard resolvedProbe.canSkipFindStreamInfo || resolvedProbe.isMatroska else {
                throw error
            }
            let fallbackArguments = videoFrameArguments(
                playableInput: resolvedInput,
                timestampMilliseconds: timestampMilliseconds,
                supportsSkipInternalSubtitles: ffmpegExecutable.supportsSkipInternalSubtitles,
                containerProbe: VideoContainerProbeResult(
                    isMatroska: false,
                    canSkipFindStreamInfo: false,
                    swapsVideoDimensions: resolvedProbe.swapsVideoDimensions
                )
            )
            let fallbackFrameData = try await runProcessCapturingStandardOutput(
                executableURL: ffmpegExecutable.url,
                arguments: fallbackArguments
            )
            guard !fallbackFrameData.isEmpty else {
                throw SubtitleScreenshotExportError.missingFrameImage(videoPath)
            }
            return try loadImage(from: fallbackFrameData, sourceDescription: videoPath)
        }
    }

    private static func videoFrameArguments(
        videoPath: String,
        timestampMilliseconds: Int,
        supportsSkipInternalSubtitles: Bool,
        containerProbe: VideoContainerProbeResult? = nil
    ) -> [String] {
        let playableInput = WebDAVClient.shared.resolvePlayableInput(
            for: URL.fromMediaPath(videoPath)
        )
        let resolvedProbe = containerProbe ?? probeVideoContainer(
            resolvedInputPath: playableInput.inputPath,
            httpHeaders: playableInput.httpHeaders
        )
        return videoFrameArguments(
            playableInput: playableInput,
            timestampMilliseconds: timestampMilliseconds,
            supportsSkipInternalSubtitles: supportsSkipInternalSubtitles,
            containerProbe: resolvedProbe
        )
    }

    private static func videoFrameArguments(
        playableInput: WebDAVPlayableInput,
        timestampMilliseconds: Int,
        supportsSkipInternalSubtitles: Bool,
        containerProbe: VideoContainerProbeResult
    ) -> [String] {
        var arguments = [
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error"
        ]
        if let httpHeaders = playableInput.httpHeaders, !httpHeaders.isEmpty {
            arguments += ["-headers", httpHeaders]
        }
        if containerProbe.canSkipFindStreamInfo {
            arguments.append("-nofind_stream_info")
        }
        if supportsSkipInternalSubtitles, containerProbe.isMatroska {
            arguments += ["-cueseeker_skip_internal_subtitles", "1"]
        }
        let scaleFilter = SFXFFmpegPixelAspectRatioScaleFilter(containerProbe.swapsVideoDimensions)
        arguments += [
            "-ss", String(format: "%.3f", Double(max(0, timestampMilliseconds)) / 1_000),
            "-i", playableInput.inputPath,
            "-frames:v", "1",
            "-an",
            "-sn",
            "-dn",
            "-vf", scaleFilter,
            "-pix_fmt", "bgr24",
            "-f", "image2pipe",
            "-vcodec", "bmp",
            "-"
        ]
        return arguments
    }

    static func probeVideoContainer(
        resolvedInputPath: String,
        httpHeaders: String? = nil
    ) -> VideoContainerProbeResult {
        if let probe = try? SFXMediaMetadataInspector.containerProbe(
            atMediaPath: resolvedInputPath,
            httpHeaders: httpHeaders
        ) {
            return VideoContainerProbeResult.evaluate(
                formatName: probe.formatName,
                hasHeaderVideoParameters: probe.hasHeaderVideoParameters,
                swapsVideoDimensions: probe.swapsVideoDimensions
            )
        }
        return VideoContainerProbeResult(
            isMatroska: false,
            canSkipFindStreamInfo: false
        )
    }

    private static func renderSRTFrame(
        cues: [PlaybackSubtitleCue],
        timestampMilliseconds: Int,
        frameImage: CGImage,
        style: SRTSubtitleStyle
    ) throws -> RenderedSubtitleFrame {
        let width = frameImage.width
        let height = frameImage.height
        guard let layout = SRTSubtitleRenderer.makeLayout(
            cues: cues,
            canvasSize: CGSize(width: width, height: height),
            style: style
        ) else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }
        guard let overlayImage = SRTSubtitleRenderer.image(
            layout: layout,
            atMilliseconds: timestampMilliseconds
        ) else {
            return RenderedSubtitleFrame(
                image: frameImage,
                subtitleBands: []
            )
        }
        guard let composedImage = compose(
            baseImage: frameImage,
            overlayImage: overlayImage
        ) else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }
        let bands = layout.activePlacements(
            atMilliseconds: timestampMilliseconds
        ).map {
            paddedBand(
                SubtitleBand(
                    y1: max(0, Int(floor($0.minY))),
                    y2: min(height - 1, Int(ceil($0.maxY)) - 1)
                ),
                frameHeight: height
            )
        }
        return RenderedSubtitleFrame(
            image: composedImage,
            subtitleBands: mergeBands(bands)
        )
    }

    fileprivate static func renderSelectedSubtitleFrame(
        group: SubtitleCollageGroup,
        source: PlaybackSubtitleSource,
        preparedASSScript: PreparedASSRenderScript?,
        requestedFontNames: [String]?,
        timestampMilliseconds: Int,
        frameImage: CGImage,
        srtSubtitleStyle: SRTSubtitleStyle
    ) throws -> RenderedSubtitleFrame {
        if source.format == .srt {
            let cues = group.cues.enumerated().map { sourceOrdinal, cue in
                PlaybackSubtitleCue(
                    sourceOrdinal: sourceOrdinal,
                    startMilliseconds: cue.startMilliseconds,
                    endMilliseconds: cue.endMilliseconds,
                    text: cue.content
                )
            }
            return try renderSRTFrame(
                cues: cues,
                timestampMilliseconds: timestampMilliseconds,
                frameImage: frameImage,
                style: srtSubtitleStyle
            )
        }

        guard source.format == .ass,
              let preparedASSScript,
              let selectedScript = preparedASSScript.script(
                  for: Set(group.cues.map(\.eventIndex))
              )
        else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }

        let renderScript = ASSFontAliasResolver.shared.rewriteRenderScript(
            selectedScript,
            requestedFontNames: requestedFontNames
        )
        let selectedEventKey = group.cues.map(\.eventIndex)
            .sorted()
            .map(String.init)
            .joined(separator: ",")
        let session = try SFXASSRendererSession(
            assScript: renderScript,
            sourceIdentifier: "\(source.url.mediaPath)#selected=\(selectedEventKey)",
            frameWidth: frameImage.width,
            frameHeight: frameImage.height
        )
        defer {
            session.close()
        }

        let output = try session.renderFrame(
            atTimestampMilliseconds: timestampMilliseconds
        )
        let bands = subtitleBands(
            fromRGBAData: output.rgbaData as Data,
            width: frameImage.width,
            height: frameImage.height,
            stride: output.stride
        )
        guard let overlayImage = rgbaImage(
            data: output.rgbaData as Data,
            width: output.width,
            height: output.height,
            stride: output.stride
        ),
        let composedImage = compose(
            baseImage: frameImage,
            overlayImage: overlayImage
        ) else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }
        return RenderedSubtitleFrame(
            image: composedImage,
            subtitleBands: bands
        )
    }

    static func _videoFrameArgumentsForTesting(
        videoPath: String,
        timestampMilliseconds: Int,
        supportsSkipInternalSubtitles: Bool,
        containerProbe: VideoContainerProbeResult? = nil
    ) -> [String] {
        videoFrameArguments(
            videoPath: videoPath,
            timestampMilliseconds: timestampMilliseconds,
            supportsSkipInternalSubtitles: supportsSkipInternalSubtitles,
            containerProbe: containerProbe
        )
    }

    static func _renderSRTFrameForTesting(
        cues: [PlaybackSubtitleCue],
        timestampMilliseconds: Int,
        frameImage: CGImage,
        style: SRTSubtitleStyle = SRTSubtitleStyle()
    ) throws -> CGImage {
        try renderSRTFrame(
            cues: cues,
            timestampMilliseconds: timestampMilliseconds,
            frameImage: frameImage,
            style: style
        ).image
    }

    static func _selectedASSRenderScriptForTesting(
        _ sourceScript: String,
        eventIndices: Set<Int>
    ) -> String? {
        selectedASSRenderScript(sourceScript, eventIndices: eventIndices)
    }

    static func _composeCollageForTesting(
        frames: [(image: CGImage, subtitleBands: [ClosedRange<Int>])]
    ) -> CGImage? {
        collageComposition(
            from: frames.map { frame in
                RenderedSubtitleFrame(
                    image: frame.image,
                    subtitleBands: frame.subtitleBands.map {
                        SubtitleBand(y1: $0.lowerBound, y2: $0.upperBound)
                    }
                )
            }
        )?.image
    }

    private static func selectedASSRenderScript(
        _ sourceScript: String,
        eventIndices: Set<Int>
    ) -> String? {
        PreparedASSRenderScript(sourceScript).script(for: eventIndices)
    }

    /// A Dialogue line stripped of its override blocks.
    ///
    /// Some scripts paint one gradient line as a stack of copies of the same
    /// event, each clipped to a horizontal band of the same glyphs. The copies
    /// only differ inside `{...}`, so indexing collapses them into one Cue and
    /// keeps one event. Rendering that event alone draws one band, which reads
    /// as a missing subtitle, so the copies have to come back with it.
    private static func glyphSignature(
        _ bytes: UnsafeBufferPointer<UInt8>,
        _ lineRange: Range<Int>
    ) -> [UInt8] {
        var signature: [UInt8] = []
        signature.reserveCapacity(lineRange.count)
        var isInsideOverride = false

        for index in lineRange {
            let byte = bytes[index]
            if byte == 0x7B {
                isInsideOverride = true
            } else if byte == 0x7D {
                isInsideOverride = false
            } else if !isInsideOverride {
                signature.append(byte)
            }
        }
        return signature
    }

    private static func matchesGlyphSignature(
        _ bytes: UnsafeBufferPointer<UInt8>,
        _ lineRange: Range<Int>,
        _ signature: [UInt8]
    ) -> Bool {
        if lineRange.count < signature.count {
            return false
        }
        var signatureIndex = 0
        var isInsideOverride = false

        for index in lineRange {
            let byte = bytes[index]
            if byte == 0x7B {
                isInsideOverride = true
            } else if byte == 0x7D {
                isInsideOverride = false
            } else if !isInsideOverride {
                guard signatureIndex < signature.count,
                      byte == signature[signatureIndex]
                else {
                    return false
                }
                signatureIndex += 1
            }
        }
        return signatureIndex == signature.count
    }

    private static func appendWithoutBOM(
        _ bytes: UnsafeBufferPointer<UInt8>,
        in range: Range<Int>,
        to destination: inout [UInt8]
    ) {
        var segmentStart = range.lowerBound
        var index = range.lowerBound
        while index < range.upperBound {
            if bytes[index] == 0xEF,
               index + 2 < range.upperBound,
               bytes[index + 1] == 0xBB,
               bytes[index + 2] == 0xBF {
                if segmentStart < index {
                    destination.append(contentsOf: bytes[segmentStart..<index])
                }
                index += 3
                segmentStart = index
            } else {
                index += 1
            }
        }
        if segmentStart < range.upperBound {
            destination.append(contentsOf: bytes[segmentStart..<range.upperBound])
        }
    }

    private static func subtitleBands(
        fromRGBAData data: Data,
        width: Int,
        height: Int,
        stride: Int
    ) -> [SubtitleBand] {
        guard width > 0, height > 0, stride >= width * 4, data.count >= stride * height else {
            return []
        }

        var rawBands: [SubtitleBand] = []
        var activeStart: Int?
        let threshold: UInt8 = 8

        data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for y in 0..<height {
                let rowStart = y * stride
                var rowHasAlpha = false
                for x in 0..<width where bytes[rowStart + (x * 4) + 3] > threshold {
                    rowHasAlpha = true
                    break
                }

                if rowHasAlpha {
                    if activeStart == nil {
                        activeStart = y
                    }
                } else if let start = activeStart {
                    rawBands.append(SubtitleBand(y1: start, y2: y - 1))
                    activeStart = nil
                }
            }
        }

        if let start = activeStart {
            rawBands.append(SubtitleBand(y1: start, y2: height - 1))
        }

        return mergeBands(rawBands.map { paddedBand($0, frameHeight: height) })
    }

    private static func paddedBand(_ band: SubtitleBand, frameHeight: Int) -> SubtitleBand {
        let padding = max(1, Int((Double(frameHeight) * 0.01).rounded()))
        return SubtitleBand(
            y1: max(0, band.y1 - padding),
            y2: min(frameHeight - 1, band.y2 + padding)
        )
    }

    private static func mergeBands(_ bands: [SubtitleBand]) -> [SubtitleBand] {
        let sortedBands = bands.sorted {
            $0.y1 == $1.y1 ? $0.y2 < $1.y2 : $0.y1 < $1.y1
        }
        var merged: [SubtitleBand] = []

        for band in sortedBands {
            guard var last = merged.popLast() else {
                merged.append(band)
                continue
            }

            if band.y1 <= last.y2 + 1 {
                last = SubtitleBand(y1: last.y1, y2: max(last.y2, band.y2))
                merged.append(last)
            } else {
                merged.append(last)
                merged.append(band)
            }
        }

        return merged
    }

    private static func compose(baseImage: CGImage, overlayImage: CGImage) -> CGImage? {
        let width = baseImage.width
        let height = baseImage.height
        guard let context = makeBitmapContext(width: width, height: height) else {
            return nil
        }

        let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
        drawImage(baseImage, in: context, rect: fullRect)
        drawImage(overlayImage, in: context, rect: fullRect)
        return context.makeImage()
    }

    private static func collageComposition(
        from renderedFrames: [RenderedSubtitleFrame]
    ) -> SubtitleCollageComposition? {
        var strips: [CGImage] = []
        var groupHeights: [Int] = []
        for (index, renderedFrame) in renderedFrames.enumerated() {
            let groupStrips: [CGImage]
            if index == 0 || renderedFrame.subtitleBands.isEmpty {
                groupStrips = [renderedFrame.image]
            } else {
                groupStrips = renderedFrame.subtitleBands.compactMap { band in
                    renderedFrame.image.cropping(
                        to: CGRect(
                            x: 0,
                            y: band.y1,
                            width: renderedFrame.image.width,
                            height: band.height
                        )
                    )
                }
            }
            strips.append(contentsOf: groupStrips)
            groupHeights.append(groupStrips.reduce(0) { $0 + $1.height })
        }
        guard let image = verticalStack(strips) else {
            return nil
        }
        return SubtitleCollageComposition(
            image: image,
            groupHeights: groupHeights
        )
    }

    private static func verticalStack(_ images: [CGImage]) -> CGImage? {
        guard let first = images.first else {
            return nil
        }

        let width = first.width
        let height = images.reduce(0) { $0 + $1.height }
        guard width > 0, height > 0, images.allSatisfy({ $0.width == width }),
              let context = makeBitmapContext(width: width, height: height)
        else {
            return nil
        }

        var y = 0
        for image in images {
            drawImage(
                image,
                in: context,
                rect: CGRect(x: 0, y: height - y - image.height, width: image.width, height: image.height)
            )
            y += image.height
        }

        return context.makeImage()
    }

    private static func drawImage(
        _ image: CGImage,
        in context: CGContext,
        rect: CGRect
    ) {
        context.draw(image, in: rect)
    }

    private static func rgbaImage(data: Data, width: Int, height: Int, stride: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: stride,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func makeBitmapContext(width: Int, height: Int) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
    }

    private static func loadImage(
        from data: Data,
        sourceDescription: String
    ) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw SubtitleScreenshotExportError.imageDecodeFailed(sourceDescription)
        }

        return image
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw SubtitleScreenshotExportError.pngWriteFailed(url.path)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw SubtitleScreenshotExportError.pngWriteFailed(url.path)
        }
    }

    static func ffmpegExecutable() -> FFmpegExecutable? {
        var candidates: [FFmpegExecutable] = [
            FFmpegExecutable(
                url: Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ffmpeg"),
                supportsSkipInternalSubtitles: true
            )
        ]
        if let runtimeRoot = ProcessInfo.processInfo.environment["CUESEEKER_MEDIA_RUNTIME_ROOT"],
           !runtimeRoot.isEmpty {
            candidates.append(
                FFmpegExecutable(
                    url: URL(fileURLWithPath: runtimeRoot).appendingPathComponent("bin/ffmpeg"),
                    supportsSkipInternalSubtitles: true
                )
            )
        }
        let repositoryRuntimeFFmpeg = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/media-runtime/arm64-macos13/bin/ffmpeg")
        candidates.append(
            FFmpegExecutable(
                url: repositoryRuntimeFFmpeg,
                supportsSkipInternalSubtitles: true
            )
        )
        candidates.append(contentsOf: [
            FFmpegExecutable(
                url: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
                supportsSkipInternalSubtitles: false
            ),
            FFmpegExecutable(
                url: URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
                supportsSkipInternalSubtitles: false
            ),
            FFmpegExecutable(
                url: URL(fileURLWithPath: "/usr/bin/ffmpeg"),
                supportsSkipInternalSubtitles: false
            )
        ])

        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0.url.path)
        }
    }

    private static func runProcessCapturingStandardOutput(
        executableURL: URL,
        arguments: [String]
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            // Drain the output before waiting; a frame is far larger than the pipe
            // buffer, so the child would block forever if this waited first.
            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(
                data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw SubtitleScreenshotExportError.processFailed(
                    executableURL.lastPathComponent,
                    process.terminationStatus,
                    errorText
                )
            }
            return output
        }.value
    }
}
