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
        return "\(first.displayTitle)-\(timeString(milliseconds: startMilliseconds))-\(timeString(milliseconds: endMilliseconds))-\(items.count).png"
    }

    public static func canExportCollage(_ items: [SubtitleScreenshotExportItem]) -> Bool {
        guard !items.isEmpty, items.count <= 50 else {
            return false
        }

        let subtitlePaths = Set(items.map {
            URL(fileURLWithPath: $0.subtitlePath).standardizedFileURL.path
        })
        return subtitlePaths.count == 1
    }

    public static func exportScreenshot(
        item: SubtitleScreenshotExportItem,
        to destinationURL: URL
    ) async throws {
        try await exportScreenshots(items: [item], toDirectory: destinationURL.deletingLastPathComponent(), explicitSingleDestinationURL: destinationURL)
    }

    public static func exportScreenshots(
        items: [SubtitleScreenshotExportItem],
        toDirectory directoryURL: URL
    ) async throws {
        try await exportScreenshots(items: items, toDirectory: directoryURL, explicitSingleDestinationURL: nil)
    }

    public static func exportCollage(
        items: [SubtitleScreenshotExportItem],
        to destinationURL: URL
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

        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerSubtitleCollage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: workspaceURL)
        }

        var strips: [CGImage] = []
        let sortedItems = sortedByTimeline(items)

        for (index, item) in sortedItems.enumerated() {
            let renderedFrame = try await renderedSubtitleFrame(
                item: item,
                ffmpegURL: ffmpegURL,
                workspaceURL: workspaceURL
            )

            if index == 0 {
                strips.append(renderedFrame.image)
                continue
            }

            if renderedFrame.subtitleBands.isEmpty {
                strips.append(renderedFrame.image)
                continue
            }

            for band in renderedFrame.subtitleBands {
                guard let crop = renderedFrame.image.cropping(to: CGRect(x: 0, y: band.y1, width: renderedFrame.image.width, height: band.height)) else {
                    continue
                }
                strips.append(crop)
            }
        }

        guard let collage = verticalStack(strips) else {
            throw SubtitleScreenshotExportError.imageContextFailed
        }
        try writePNG(collage, to: destinationURL)
    }

    private static func exportScreenshots(
        items: [SubtitleScreenshotExportItem],
        toDirectory directoryURL: URL,
        explicitSingleDestinationURL: URL?
    ) async throws {
        guard !items.isEmpty else {
            throw SubtitleScreenshotExportError.emptyItems
        }

        guard let ffmpegURL = ffmpegExecutableURL() else {
            throw SubtitleScreenshotExportError.ffmpegNotFound
        }

        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerSubtitleScreenshots-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: workspaceURL)
        }

        let defaultFileNames = defaultScreenshotFileNames(for: items)
        for (index, item) in items.enumerated() {
            let renderedFrame = try await renderedSubtitleFrame(
                item: item,
                ffmpegURL: ffmpegURL,
                workspaceURL: workspaceURL
            )
            let destinationURL = explicitSingleDestinationURL
                ?? directoryURL.appendingPathComponent(defaultFileNames[index])
            try writePNG(renderedFrame.image, to: destinationURL)
        }
    }

    private static func renderedSubtitleFrame(
        item: SubtitleScreenshotExportItem,
        ffmpegURL: URL,
        workspaceURL: URL
    ) async throws -> RenderedSubtitleFrame {
        let frameURL = workspaceURL
            .appendingPathComponent("frame-\(UUID().uuidString)")
            .appendingPathExtension("png")
        let timestampMilliseconds = midpointMilliseconds(for: item)
        try await exportVideoFrame(
            videoPath: item.videoPath,
            timestampMilliseconds: timestampMilliseconds,
            ffmpegURL: ffmpegURL,
            outputURL: frameURL
        )

        guard FileManager.default.fileExists(atPath: frameURL.path) else {
            throw SubtitleScreenshotExportError.missingFrameImage(frameURL.path)
        }

        let frameImage = try loadImage(at: frameURL)
        return try renderASSFrame(
            item: item,
            timestampMilliseconds: timestampMilliseconds,
            frameImage: frameImage
        )
    }

    private static func exportVideoFrame(
        videoPath: String,
        timestampMilliseconds: Int,
        ffmpegURL: URL,
        outputURL: URL
    ) async throws {
        try await runProcess(
            executableURL: ffmpegURL,
            arguments: [
                "-nostdin",
                "-y",
                "-hide_banner",
                "-loglevel", "error",
                "-ss", String(format: "%.3f", Double(max(0, timestampMilliseconds)) / 1_000),
                "-i", videoPath,
                "-frames:v", "1",
                outputURL.path
            ]
        )
    }

    private static func renderASSFrame(
        item: SubtitleScreenshotExportItem,
        timestampMilliseconds: Int,
        frameImage: CGImage
    ) throws -> RenderedSubtitleFrame {
        let width = frameImage.width
        let height = frameImage.height
        let source = item.subtitleSource ?? PlaybackSubtitleSource(
            url: URL(fileURLWithPath: item.subtitlePath),
            format: item.subtitleFormat == .ass ? .ass : .srt,
            matchedVideoURL: URL(fileURLWithPath: item.videoPath),
            preparationTimeWindow: PlaybackSubtitleTimeWindow(
                startMilliseconds: item.startMilliseconds,
                endMilliseconds: item.endMilliseconds
            )
        )

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

    private static func makeASSSession(
        source: PlaybackSubtitleSource,
        timestampMilliseconds: Int,
        frameWidth: Int,
        frameHeight: Int
    ) throws -> SFXASSRendererSession {
        let requestedFontNames = source.format == .ass
            ? try? ASSPlaybackFontIntentProvider.requestedFontNames(
                sourcePath: source.url.path,
                renderCacheDatabaseURL: source.renderCacheDatabaseURL
            )
            : nil

        if source.format == .ass,
           let segment = try indexedRenderSegment(
                source: source,
                timestampMilliseconds: timestampMilliseconds
           )
        {
            let speakerRewrittenScript = ASSSpeakerDisplayRewriter.rewrite(
                script: segment.scriptText,
                cues: source.speakerDisplayCues
            )
            let renderScript = ASSFontAliasResolver.shared.rewriteRenderScript(
                speakerRewrittenScript,
                requestedFontNames: requestedFontNames
            )
            return try SFXASSRendererSession(
                assScript: renderScript,
                sourceIdentifier: "\(source.url.path)#\(segment.startMilliseconds)-\(segment.endMilliseconds)",
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )
        }

        if source.format == .srt {
            let sourceScript = try String(contentsOf: source.url)
            let speakerRewrittenScript = ASSSpeakerDisplayRewriter.rewrite(
                script: SRTASSConverter.convert(sourceScript),
                cues: source.speakerDisplayCues
            )
            let renderScript = ASSFontAliasResolver.shared.rewriteRenderScript(
                speakerRewrittenScript,
                requestedFontNames: nil
            )
            return try SFXASSRendererSession(
                assScript: renderScript,
                sourceIdentifier: source.url.path,
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )
        }

        if let sourceScript = try? String(contentsOf: source.url) {
            let speakerRewrittenScript = ASSSpeakerDisplayRewriter.rewrite(
                script: sourceScript,
                cues: source.speakerDisplayCues
            )
            let renderScript = ASSFontAliasResolver.shared.rewriteRenderScript(
                speakerRewrittenScript,
                requestedFontNames: requestedFontNames
            )
            if renderScript != sourceScript {
                return try SFXASSRendererSession(
                    assScript: renderScript,
                    sourceIdentifier: source.url.path,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight
                )
            }
        }

        return try SFXASSRendererSession(
            assFileAtPath: source.url.path,
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

    private static func loadImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw SubtitleScreenshotExportError.imageDecodeFailed(url.path)
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

    private static func ffmpegExecutableURL() -> URL? {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ffmpeg"),
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/bin/ffmpeg")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectoryURL

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: SubtitleScreenshotExportError.processFailed(
                            executableURL.lastPathComponent,
                            process.terminationStatus,
                            output
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
