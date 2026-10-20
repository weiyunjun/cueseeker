import AppKit
import CASSRendering
import CueSeekerCore
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct SubtitleScreenshotExportItem: Equatable, Sendable {
    public let displayTitle: String
    public let videoPath: String
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let cueDisplayOrder: Int?
    public let cueEventIndex: Int?
    public let textLines: [String]
    public let subtitleSource: PlaybackSubtitleSource?

    public init(
        displayTitle: String,
        videoPath: String,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat,
        startMilliseconds: Int,
        endMilliseconds: Int,
        cueDisplayOrder: Int? = nil,
        cueEventIndex: Int? = nil,
        textLines: [String],
        subtitleSource: PlaybackSubtitleSource? = nil
    ) {
        self.displayTitle = displayTitle
        self.videoPath = videoPath
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
        self.startMilliseconds = max(0, startMilliseconds)
        self.endMilliseconds = max(max(0, startMilliseconds), endMilliseconds)
        self.cueDisplayOrder = cueDisplayOrder
        self.cueEventIndex = cueEventIndex
        self.textLines = textLines
        self.subtitleSource = subtitleSource
    }
}

public struct SubtitleCollageRenderedGroup: @unchecked Sendable {
    let image: CGImage
    let subtitleBands: [ClosedRange<Int>]

    public init(
        image: CGImage,
        subtitleBands: [ClosedRange<Int>]
    ) {
        self.image = image
        self.subtitleBands = subtitleBands
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
    case unsupportedSubtitleFormat(String)
    case invalidCollageItems
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
        case .unsupportedSubtitleFormat(let format):
            "Unsupported subtitle screenshot format: \(format)"
        case .invalidCollageItems:
            "Collage export requires selected Cues from one subtitle file and no more than 50 items."
        case .processFailed(let executable, let status, let output):
            "\(executable) exited with status \(status). \(output)"
        }
    }
}

public enum SubtitleScreenshotExporter {
    private struct SubtitleBand: Equatable {
        let y1: Int
        let y2: Int

        var height: Int {
            y2 - y1 + 1
        }
    }

    private struct RenderedSubtitleFrame {
        let image: CGImage
        let subtitleBands: [SubtitleBand]
    }

    private struct PreparedSRTSource: Sendable {
        let source: PlaybackSubtitleSource
        let cues: [PlaybackSubtitleCue]
    }

    public static func defaultScreenshotFileName(for item: SubtitleScreenshotExportItem) -> String {
        "\(item.displayTitle)-\(timeString(milliseconds: item.startMilliseconds))-\(timeString(milliseconds: item.endMilliseconds)).png"
    }

    static func defaultScreenshotFileNames(
        for items: [SubtitleScreenshotExportItem]
    ) -> [String] {
        let baseNames = items.map { defaultScreenshotFileName(for: $0) }
        let indexesByBaseName = Dictionary(grouping: baseNames.indices) {
            baseNames[$0]
        }
        let uniqueBaseNames = indexesByBaseName.compactMap { baseName, indexes in
            indexes.count == 1 ? baseName : nil
        }
        var usedNames = Set(uniqueBaseNames)
        var resolvedNames = baseNames

        for baseName in indexesByBaseName.keys.sorted() {
            guard let indexes = indexesByBaseName[baseName], indexes.count > 1 else {
                continue
            }
            let sortedIndexes = indexes.sorted { lhs, rhs in
                stableTimelinePrecedes(
                    items[lhs],
                    lhsInputOrdinal: lhs,
                    items[rhs],
                    rhsInputOrdinal: rhs
                )
            }
            let stem = baseName.hasSuffix(".png")
                ? String(baseName.dropLast(4))
                : baseName
            for (collisionOrdinal, itemIndex) in sortedIndexes.enumerated() {
                let suffix = String(format: "cue-%02d", collisionOrdinal + 1)
                var candidate = "\(stem)-\(suffix).png"
                var fallbackOrdinal = 2
                while usedNames.contains(candidate) {
                    candidate = "\(stem)-\(suffix)-\(fallbackOrdinal).png"
                    fallbackOrdinal += 1
                }
                resolvedNames[itemIndex] = candidate
                usedNames.insert(candidate)
            }
        }

        return resolvedNames
    }

    public static func defaultScreenshotFolderName(exportedAt: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "CueSeeker-\(formatter.string(from: exportedAt))"
    }

    public static func defaultCollageFileName(for items: [SubtitleScreenshotExportItem]) -> String {
        guard let first = sortedByTimeline(items).first else {
            return "CueSeeker-Collage-0.png"
        }

        let startMilliseconds = items.map(\.startMilliseconds).min() ?? first.startMilliseconds
        let endMilliseconds = items.map(\.endMilliseconds).max() ?? first.endMilliseconds
        return defaultCollageFileName(
            displayTitle: first.displayTitle,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            cueCount: items.count
        )
    }

    public static func defaultCollageFileName(
        displayTitle: String,
        plan: SubtitleCollageSelectionPlan
    ) -> String {
        let selectedCues = plan.selectedCues
        guard let first = selectedCues.first else {
            return "CueSeeker-Collage-0.png"
        }

        return defaultCollageFileName(
            displayTitle: displayTitle,
            startMilliseconds: selectedCues
                .map(\.startMilliseconds)
                .min() ?? first.startMilliseconds,
            endMilliseconds: selectedCues
                .map(\.endMilliseconds)
                .max() ?? first.endMilliseconds,
            cueCount: plan.selectedCueCount
        )
    }

    public static func canExportCollage(_ items: [SubtitleScreenshotExportItem]) -> Bool {
        guard !items.isEmpty, items.count <= 50 else {
            return false
        }

        let subtitlePaths = Set(items.map {
            URL.fromMediaPath($0.subtitlePath).mediaPath
        })
        return subtitlePaths.count == 1
    }

    public static func exportScreenshot(
        item: SubtitleScreenshotExportItem,
        to destinationURL: URL,
        srtSubtitleStyle: SRTSubtitleStyle
    ) async throws {
        try await exportScreenshots(items: [item], toDirectory: destinationURL.deletingLastPathComponent(), explicitSingleDestinationURL: destinationURL, srtSubtitleStyle: srtSubtitleStyle)
    }

    public static func exportScreenshots(
        items: [SubtitleScreenshotExportItem],
        toDirectory directoryURL: URL,
        srtSubtitleStyle: SRTSubtitleStyle
    ) async throws {
        try await exportScreenshots(items: items, toDirectory: directoryURL, explicitSingleDestinationURL: nil, srtSubtitleStyle: srtSubtitleStyle)
    }

    public static func exportCollage(
        items: [SubtitleScreenshotExportItem],
        to destinationURL: URL,
        srtSubtitleStyle: SRTSubtitleStyle
    ) async throws {
        guard canExportCollage(items) else {
            throw SubtitleScreenshotExportError.invalidCollageItems
        }

        guard !items.isEmpty else {
            throw SubtitleScreenshotExportError.emptyItems
        }

        guard let ffmpegURL = ffmpegExecutableURL() else {
            throw SubtitleScreenshotExportError.ffmpegNotFound
        }

        var renderedFrames: [RenderedSubtitleFrame] = []
        let sortedItems = sortedByTimeline(items)
        let preparedSRTSources = try await prepareSRTSources(for: sortedItems)

        for item in sortedItems {
            renderedFrames.append(try await renderedSubtitleFrame(
                item: item,
                ffmpegURL: ffmpegURL,
                preparedSRTSources: preparedSRTSources,
                srtSubtitleStyle: srtSubtitleStyle
            ))
        }

        guard let collage = collageComposition(from: renderedFrames) else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }
        try exportCollage(image: collage.image, to: destinationURL)
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
        guard let ffmpegURL = ffmpegExecutableURL() else {
            throw SubtitleScreenshotExportError.ffmpegNotFound
        }

        let assSourceScript = subtitleSource.format == .ass
            ? try SubtitleTextDecoder.decode(
                contentsOf: subtitleSource.url,
                format: .ass
            )
            : nil
        var renderedGroups: [SubtitleCollageRenderedGroup] = []
        renderedGroups.reserveCapacity(groups.count)

        for group in groups {
            try Task.checkCancellation()
            let timestampMilliseconds = group.renderTimestampMilliseconds
            let frameImage = try await videoFrame(
                videoPath: videoURL.mediaPath,
                timestampMilliseconds: timestampMilliseconds,
                ffmpegURL: ffmpegURL
            )
            try Task.checkCancellation()
            let renderedFrame = try renderSelectedSubtitleFrame(
                group: group,
                source: subtitleSource,
                sourceScript: assSourceScript,
                timestampMilliseconds: timestampMilliseconds,
                frameImage: frameImage,
                srtSubtitleStyle: srtSubtitleStyle
            )
            renderedGroups.append(SubtitleCollageRenderedGroup(
                image: renderedFrame.image,
                subtitleBands: renderedFrame.subtitleBands.map {
                    $0.y1...$0.y2
                }
            ))
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

    private static func exportScreenshots(
        items: [SubtitleScreenshotExportItem],
        toDirectory directoryURL: URL,
        explicitSingleDestinationURL: URL?,
        srtSubtitleStyle: SRTSubtitleStyle
    ) async throws {
        guard !items.isEmpty else {
            throw SubtitleScreenshotExportError.emptyItems
        }

        guard let ffmpegURL = ffmpegExecutableURL() else {
            throw SubtitleScreenshotExportError.ffmpegNotFound
        }

        let defaultFileNames = defaultScreenshotFileNames(for: items)
        let preparedSRTSources = try await prepareSRTSources(for: items)
        for (index, item) in items.enumerated() {
            let renderedFrame = try await renderedSubtitleFrame(
                item: item,
                ffmpegURL: ffmpegURL,
                preparedSRTSources: preparedSRTSources,
                srtSubtitleStyle: srtSubtitleStyle
            )
            let destinationURL = explicitSingleDestinationURL
                ?? directoryURL.appendingPathComponent(defaultFileNames[index])
            try writePNG(renderedFrame.image, to: destinationURL)
        }
    }

    private static func prepareSRTSources(
        for items: [SubtitleScreenshotExportItem]
    ) async throws -> [PreparedSRTSource] {
        var sources: [PlaybackSubtitleSource] = []
        for item in items {
            let source = subtitleSource(for: item)
            guard source.format == .srt else { continue }
            let normalized = normalizedSRTSource(source)
            if !sources.contains(normalized) {
                sources.append(normalized)
            }
        }
        return try await Task.detached(priority: .userInitiated) {
            try sources.map {
                PreparedSRTSource(
                    source: $0,
                    cues: try SRTSubtitleRenderer.loadPlaybackCues(from: $0)
                )
            }
        }.value
    }

    private static func renderedSubtitleFrame(
        item: SubtitleScreenshotExportItem,
        ffmpegURL: URL,
        preparedSRTSources: [PreparedSRTSource],
        srtSubtitleStyle: SRTSubtitleStyle
    ) async throws -> RenderedSubtitleFrame {
        let timestampMilliseconds = midpointMilliseconds(for: item)
        let frameImage = try await videoFrame(
            videoPath: item.videoPath,
            timestampMilliseconds: timestampMilliseconds,
            ffmpegURL: ffmpegURL
        )
        return try renderSubtitleFrame(
            item: item,
            timestampMilliseconds: timestampMilliseconds,
            frameImage: frameImage,
            preparedSRTSources: preparedSRTSources,
            srtSubtitleStyle: srtSubtitleStyle
        )
    }

    private static func videoFrame(
        videoPath: String,
        timestampMilliseconds: Int,
        ffmpegURL: URL
    ) async throws -> CGImage {
        // BMP keeps the frame uncompressed and self-describing, so the pixels
        // reach the compositor without a PNG round trip through the file system.
        // The 10-bit sources this reads would otherwise produce a 16-bit
        // intermediate that the 8-bit compositing context discards anyway.
        let playableInput = WebDAVClient.shared.resolvePlayableInput(
            for: URL.fromMediaPath(videoPath)
        )
        var arguments = [
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error"
        ]
        if let httpHeaders = playableInput.httpHeaders, !httpHeaders.isEmpty {
            arguments += ["-headers", httpHeaders]
        }
        arguments += [
            "-ss", String(format: "%.3f", Double(max(0, timestampMilliseconds)) / 1_000),
            "-i", playableInput.inputPath,
            "-frames:v", "1",
            "-pix_fmt", "bgr24",
            "-f", "image2pipe",
            "-vcodec", "bmp",
            "-"
        ]
        let frameData = try await runProcessCapturingStandardOutput(
            executableURL: ffmpegURL,
            arguments: arguments
        )
        guard !frameData.isEmpty else {
            throw SubtitleScreenshotExportError.missingFrameImage(videoPath)
        }
        return try loadImage(from: frameData, sourceDescription: videoPath)
    }

    private static func subtitleSource(
        for item: SubtitleScreenshotExportItem
    ) -> PlaybackSubtitleSource {
        item.subtitleSource ?? PlaybackSubtitleSource(
            url: URL.fromMediaPath(item.subtitlePath),
            format: item.subtitleFormat.usesASSSemantics ? .ass : .srt,
            matchedVideoURL: URL.fromMediaPath(item.videoPath),
            preparationTimeWindow: PlaybackSubtitleTimeWindow(
                startMilliseconds: item.startMilliseconds,
                endMilliseconds: item.endMilliseconds
            )
        )
    }

    private static func normalizedSRTSource(
        _ source: PlaybackSubtitleSource
    ) -> PlaybackSubtitleSource {
        PlaybackSubtitleSource(
            url: source.url.standardizedMediaURL,
            format: .srt,
            matchedVideoURL: source.matchedVideoURL,
            renderCacheDatabaseURL: source.renderCacheDatabaseURL
        )
    }

    private static func renderSubtitleFrame(
        item: SubtitleScreenshotExportItem,
        timestampMilliseconds: Int,
        frameImage: CGImage,
        preparedSRTSources: [PreparedSRTSource],
        srtSubtitleStyle: SRTSubtitleStyle
    ) throws -> RenderedSubtitleFrame {
        let width = frameImage.width
        let height = frameImage.height
        let source = subtitleSource(for: item)

        if source.format == .srt {
            let normalizedSource = normalizedSRTSource(source)
            guard let preparedSource = preparedSRTSources.first(where: {
                $0.source == normalizedSource
            }) else {
                throw SubtitleScreenshotExportError.imageContextFailed
            }
            return try renderSRTFrame(
                cues: preparedSource.cues,
                timestampMilliseconds: timestampMilliseconds,
                frameImage: frameImage,
                style: srtSubtitleStyle
            )
        }

        let session = try makeASSSession(
            source: source,
            timestampMilliseconds: timestampMilliseconds,
            frameWidth: width,
            frameHeight: height
        )
        defer {
            session.close()
        }

        let output = try session.renderFrame(atTimestampMilliseconds: timestampMilliseconds)
        let bands = subtitleBands(
            fromRGBAData: output.rgbaData as Data,
            width: width,
            height: height,
            stride: output.stride
        )

        guard let overlayImage = rgbaImage(
            data: output.rgbaData as Data,
            width: output.width,
            height: output.height,
            stride: output.stride
        ) else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }

        guard let composedImage = compose(baseImage: frameImage, overlayImage: overlayImage) else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }

        return RenderedSubtitleFrame(image: composedImage, subtitleBands: bands)
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

    private static func renderSelectedSubtitleFrame(
        group: SubtitleCollageGroup,
        source: PlaybackSubtitleSource,
        sourceScript: String?,
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
              let sourceScript,
              let selectedScript = selectedASSRenderScript(
                  sourceScript,
                  eventIndices: Set(group.cues.map(\.eventIndex))
              )
        else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }

        let requestedFontNames = try? ASSPlaybackFontIntentProvider.requestedFontNames(
            sourcePath: source.url.mediaPath,
            renderCacheDatabaseURL: source.renderCacheDatabaseURL
        )
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
        guard !eventIndices.isEmpty else {
            return nil
        }

        var foundEventIndices = Set<Int>()
        var selectedBytes: [UInt8] = []
        selectedBytes.reserveCapacity(1 << 16)

        ASSScriptScanner.withScriptBytes(sourceScript) { bytes in
            let selectedGlyphs = glyphSignatures(bytes, eventIndices: eventIndices)
            ASSScriptScanner.scanLines(bytes) { lineRange, kind in
                if case .dialogue(let eventIndex) = kind {
                    if eventIndices.contains(eventIndex) {
                        foundEventIndices.insert(eventIndex)
                    } else if !selectedGlyphs.contains(glyphSignature(bytes, lineRange)) {
                        return
                    }
                }
                selectedBytes.append(contentsOf: bytes[lineRange])
                selectedBytes.append(0x0A)
            }
        }

        guard foundEventIndices == eventIndices else {
            return nil
        }
        return String(decoding: selectedBytes, as: UTF8.self)
            .replacingOccurrences(of: "\u{feff}", with: "")
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

    private static func glyphSignatures(
        _ bytes: UnsafeBufferPointer<UInt8>,
        eventIndices: Set<Int>
    ) -> Set<[UInt8]> {
        var signatures = Set<[UInt8]>()
        ASSScriptScanner.scanLines(bytes) { lineRange, kind in
            guard case .dialogue(let eventIndex) = kind,
                  eventIndices.contains(eventIndex)
            else {
                return
            }
            signatures.insert(glyphSignature(bytes, lineRange))
        }
        return signatures
    }

    private static func makeASSSession(
        source: PlaybackSubtitleSource,
        timestampMilliseconds: Int,
        frameWidth: Int,
        frameHeight: Int
    ) throws -> SFXASSRendererSession {
        guard source.format == .ass else {
            throw SubtitleScreenshotExportError.unsupportedSubtitleFormat(
                source.format.rawValue
            )
        }
        let requestedFontNames = try? ASSPlaybackFontIntentProvider.requestedFontNames(
            sourcePath: source.url.mediaPath,
            renderCacheDatabaseURL: source.renderCacheDatabaseURL
        )

        if let segment = try indexedRenderSegment(
                source: source,
                timestampMilliseconds: timestampMilliseconds
           )
        {
            let renderScript = ASSFontAliasResolver.shared.rewriteRenderScript(
                segment.scriptText,
                requestedFontNames: requestedFontNames
            )
            return try SFXASSRendererSession(
                assScript: renderScript,
                sourceIdentifier: "\(source.url.mediaPath)#\(segment.startMilliseconds)-\(segment.endMilliseconds)",
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )
        }

        let sourceScript = try SubtitleTextDecoder.decode(
            contentsOf: source.url,
            format: .ass
        )
        let renderScript = ASSFontAliasResolver.shared.rewriteRenderScript(
            sourceScript,
            requestedFontNames: requestedFontNames
        )
        return try SFXASSRendererSession(
            assScript: renderScript,
            sourceIdentifier: source.url.mediaPath,
            frameWidth: frameWidth,
            frameHeight: frameHeight
        )
    }

    private static func indexedRenderSegment(
        source: PlaybackSubtitleSource,
        timestampMilliseconds: Int
    ) throws -> ASSRenderSegment? {
        guard let renderCacheDatabaseURL = source.renderCacheDatabaseURL else {
            return nil
        }

        let database = try PlaybackSubtitleDatabase(path: renderCacheDatabaseURL)
        return try database.assRenderSegment(
            forSubtitleFile: source.url,
            atMilliseconds: timestampMilliseconds
        )
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

    private static func midpointMilliseconds(for item: SubtitleScreenshotExportItem) -> Int {
        (item.startMilliseconds + item.endMilliseconds) / 2
    }

    static func _sortedByTimelineForTesting(
        _ items: [SubtitleScreenshotExportItem]
    ) -> [SubtitleScreenshotExportItem] {
        sortedByTimeline(items)
    }

    private static func sortedByTimeline(
        _ items: [SubtitleScreenshotExportItem]
    ) -> [SubtitleScreenshotExportItem] {
        items.enumerated().sorted { lhs, rhs in
            stableTimelinePrecedes(
                lhs.element,
                lhsInputOrdinal: lhs.offset,
                rhs.element,
                rhsInputOrdinal: rhs.offset
            )
        }.map(\.element)
    }

    private static func stableTimelinePrecedes(
        _ lhs: SubtitleScreenshotExportItem,
        lhsInputOrdinal: Int,
        _ rhs: SubtitleScreenshotExportItem,
        rhsInputOrdinal: Int
    ) -> Bool {
        if lhs.startMilliseconds != rhs.startMilliseconds {
            return lhs.startMilliseconds < rhs.startMilliseconds
        }
        if lhs.endMilliseconds != rhs.endMilliseconds {
            return lhs.endMilliseconds < rhs.endMilliseconds
        }

        let lhsDisplayOrder = lhs.cueDisplayOrder ?? Int.max
        let rhsDisplayOrder = rhs.cueDisplayOrder ?? Int.max
        if lhsDisplayOrder != rhsDisplayOrder {
            return lhsDisplayOrder < rhsDisplayOrder
        }

        let lhsEventIndex = lhs.cueEventIndex ?? Int.max
        let rhsEventIndex = rhs.cueEventIndex ?? Int.max
        if lhsEventIndex != rhsEventIndex {
            return lhsEventIndex < rhsEventIndex
        }
        return lhsInputOrdinal < rhsInputOrdinal
    }

    private static func timeString(milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds) / 1_000
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d.%02d.%02d", hours, minutes, seconds)
        }
        return String(format: "%02d.%02d", minutes, seconds)
    }

    private static func defaultCollageFileName(
        displayTitle: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        cueCount: Int
    ) -> String {
        let start = timeString(milliseconds: startMilliseconds)
        let end = timeString(milliseconds: endMilliseconds)
        return "\(displayTitle)-\(start)-\(end)-\(cueCount).png"
    }

    private static func ffmpegExecutableURL() -> URL? {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ffmpeg"),
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/bin/ffmpeg")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
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
