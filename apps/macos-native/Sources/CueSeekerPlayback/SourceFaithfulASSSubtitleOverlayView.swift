import AppKit
import CASSRendering
import CueSeekerCore
import CoreGraphics
import Foundation

struct ASSCroppedSurface: @unchecked Sendable {
    let rgbaData: Data
    let width: Int
    let height: Int
    let stride: Int
    let destinationX: Int
    let destinationY: Int
}

struct ASSSparseFrame: @unchecked Sendable {
    let surface: ASSCroppedSurface?
    let frameWidth: Int
    let frameHeight: Int
    let timestampMilliseconds: Int
}

enum SourceFaithfulASSSubtitleLayout {
    static func videoRect(videoSize: CGSize?, in bounds: CGRect) -> CGRect {
        guard let videoSize,
              videoSize.width > 0,
              videoSize.height > 0,
              bounds.width > 0,
              bounds.height > 0
        else {
            return bounds
        }

        let scale = min(
            bounds.width / videoSize.width,
            bounds.height / videoSize.height
        )
        let size = CGSize(
            width: videoSize.width * scale,
            height: videoSize.height * scale
        )
        return CGRect(
            x: bounds.midX - (size.width / 2),
            y: bounds.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    static func surfaceFrame(
        destinationX: Int,
        destinationY: Int,
        width: Int,
        height: Int,
        frameWidth: Int,
        frameHeight: Int,
        videoRect: CGRect
    ) -> CGRect? {
        guard frameWidth > 0, frameHeight > 0, width > 0, height > 0 else {
            return nil
        }

        let scaleX = videoRect.width / CGFloat(frameWidth)
        let scaleY = videoRect.height / CGFloat(frameHeight)
        return CGRect(
            x: videoRect.minX + (CGFloat(destinationX) * scaleX),
            y: videoRect.maxY - (CGFloat(destinationY + height) * scaleY),
            width: CGFloat(width) * scaleX,
            height: CGFloat(height) * scaleY
        )
    }
}

private enum ASSRenderedFrame: @unchecked Sendable {
    case sparse(ASSSparseFrame, validRangeMilliseconds: Range<Int>)
    case unchanged(timestampMilliseconds: Int, validRangeMilliseconds: Range<Int>)

    var timestampMilliseconds: Int {
        switch self {
        case .sparse(let frame, _):
            frame.timestampMilliseconds
        case .unchanged(let timestampMilliseconds, _):
            timestampMilliseconds
        }
    }

    var validRangeMilliseconds: Range<Int> {
        switch self {
        case .sparse(_, let range):
            range
        case .unchanged(_, let range):
            range
        }
    }
}

private struct ASSRenderWorkerError: Error, Sendable {
    let message: String
}

private final class SourceFaithfulASSRendererWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "CueSeeker.SourceFaithfulASSRenderer")
    private let invalidationLock = NSLock()
    private var invalidated = false
    private var session: SFXASSRendererSession?
    private var sourcePath: String?
    private var sourceFormat: PlaybackSubtitleSourceFormat?
    private var renderCacheDatabaseURL: URL?
    private var frameWidth = 0
    private var frameHeight = 0
    private var activeRenderSegmentWindow: PlaybackSubtitleTimeWindow?
    private var requestedFontNames: [String]?

    func load(
        source: PlaybackSubtitleSource,
        frameWidth: Int,
        frameHeight: Int,
        initialTimestampMilliseconds: Int,
        completion: @escaping @Sendable (UUID, Result<Void, ASSRenderWorkerError>) -> Void
    ) -> UUID {
        let nextGeneration = UUID()

        queue.async { [
            sourcePath = source.url.mediaPath,
            sourceFormat = source.format,
            renderCacheDatabaseURL = source.renderCacheDatabaseURL
        ] in
            guard !self.isInvalidated else {
                return
            }

            do {
                self.clearState()
                self.sourcePath = sourcePath
                self.sourceFormat = sourceFormat
                self.renderCacheDatabaseURL = renderCacheDatabaseURL
                self.frameWidth = frameWidth
                self.frameHeight = frameHeight
                self.activeRenderSegmentWindow = nil
                self.requestedFontNames = try? ASSPlaybackFontIntentProvider.requestedFontNames(
                    sourcePath: sourcePath,
                    renderCacheDatabaseURL: renderCacheDatabaseURL
                )

                let nextSession = try self.makeSession(containing: initialTimestampMilliseconds)
                guard !self.isInvalidated else {
                    nextSession.close()
                    return
                }

                self.session = nextSession
                completion(nextGeneration, .success(()))
            } catch {
                guard !self.isInvalidated else {
                    return
                }

                self.session = nil
                self.activeRenderSegmentWindow = nil
                completion(
                    nextGeneration,
                    .failure(ASSRenderWorkerError(message: "ASS renderer failed to load source: \(error.localizedDescription)"))
                )
            }
        }

        return nextGeneration
    }

    func clear(completion: (@Sendable () -> Void)? = nil) {
        queue.async {
            self.clearState()
            completion?()
        }
    }

    func invalidate() {
        invalidationLock.lock()
        invalidated = true
        invalidationLock.unlock()

        queue.async {
            self.clearState()
        }
    }

    func render(
        generation expectedGeneration: UUID,
        timestampMilliseconds: Int,
        completion: @escaping @Sendable (UUID, Result<ASSRenderedFrame, ASSRenderWorkerError>) -> Void
    ) {
        queue.async {
            guard !self.isInvalidated else {
                return
            }

            do {
                try self.ensureSessionCovers(timestampMilliseconds: timestampMilliseconds)
                guard let session = self.session else {
                    completion(
                        expectedGeneration,
                        .failure(ASSRenderWorkerError(message: "ASS renderer session is not ready."))
                    )
                    return
                }

                let output = try session.renderCroppedImage(atTimestampMilliseconds: timestampMilliseconds)
                guard !self.isInvalidated else {
                    return
                }

                var validLower = max(0, output.unchangedFromMilliseconds)
                var validUpper = max(validLower + 1, output.unchangedUntilMilliseconds)
                if let segmentWindow = self.activeRenderSegmentWindow {
                    validLower = max(validLower, segmentWindow.startMilliseconds)
                    validUpper = min(validUpper, segmentWindow.endMilliseconds)
                }
                let validRange = validLower ..< max(validLower + 1, validUpper)

                guard output.changed else {
                    completion(
                        expectedGeneration,
                        .success(.unchanged(timestampMilliseconds: timestampMilliseconds, validRangeMilliseconds: validRange))
                    )
                    return
                }

                let frame = ASSSparseFrame(
                    surface: Self.makeSurface(from: output),
                    frameWidth: output.frameWidth,
                    frameHeight: output.frameHeight,
                    timestampMilliseconds: timestampMilliseconds
                )
                completion(expectedGeneration, .success(.sparse(frame, validRangeMilliseconds: validRange)))
            } catch {
                guard !self.isInvalidated else {
                    return
                }

                completion(
                    expectedGeneration,
                    .failure(ASSRenderWorkerError(message: "ASS renderer failed at \(timestampMilliseconds) ms: \(error.localizedDescription)"))
                )
            }
        }
    }

    private var isInvalidated: Bool {
        invalidationLock.lock()
        defer {
            invalidationLock.unlock()
        }
        return invalidated
    }

    private func clearState() {
        session?.close()
        session = nil
        sourcePath = nil
        sourceFormat = nil
        renderCacheDatabaseURL = nil
        frameWidth = 0
        frameHeight = 0
        activeRenderSegmentWindow = nil
        requestedFontNames = nil
    }

    private func ensureSessionCovers(timestampMilliseconds: Int) throws {
        if let activeRenderSegmentWindow,
           timestampMilliseconds >= activeRenderSegmentWindow.startMilliseconds,
           timestampMilliseconds < activeRenderSegmentWindow.endMilliseconds {
            return
        }

        if activeRenderSegmentWindow == nil, session != nil {
            return
        }

        session?.close()
        session = try makeSession(containing: timestampMilliseconds)
    }

    private func makeSession(containing timestampMilliseconds: Int) throws -> SFXASSRendererSession {
        guard let sourcePath,
              let sourceFormat,
              frameWidth > 0,
              frameHeight > 0
        else {
            throw ASSRenderWorkerError(message: "ASS renderer source is not ready.")
        }
        guard sourceFormat == .ass else {
            throw ASSRenderWorkerError(
                message: "ASS renderer received a non-ASS source."
            )
        }

        if let segment = try indexedRenderSegment(containing: timestampMilliseconds)
        {
            activeRenderSegmentWindow = PlaybackSubtitleTimeWindow(
                startMilliseconds: segment.startMilliseconds,
                endMilliseconds: segment.endMilliseconds
            )
            print(
                "libass indexed segment: window=\(segment.startMilliseconds)-\(segment.endMilliseconds)ms events=\(segment.eventCount) bytes=\(segment.byteCount)"
            )
            let sourceIdentifier = "\(sourcePath)#\(segment.startMilliseconds)-\(segment.endMilliseconds)"
            let renderScript = rewriteFontAliases(in: segment.scriptText)
            return try SFXASSRendererSession(
                assScript: renderScript,
                sourceIdentifier: sourceIdentifier,
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )
        }

        activeRenderSegmentWindow = nil
        let sourceScript = try SubtitleTextDecoder.decode(
            contentsOf: URL.fromMediaPath(sourcePath),
            format: .ass
        )
        let renderScript = rewriteFontAliases(in: sourceScript)
        return try SFXASSRendererSession(
            assScript: renderScript,
            sourceIdentifier: sourcePath,
            frameWidth: frameWidth,
            frameHeight: frameHeight
        )
    }

    private func rewriteFontAliases(in script: String) -> String {
        return ASSFontAliasResolver.shared.rewriteRenderScript(
            script,
            requestedFontNames: requestedFontNames
        )
    }

    private func indexedRenderSegment(containing timestampMilliseconds: Int) throws -> ASSRenderSegment? {
        guard let renderCacheDatabaseURL, let sourcePath else {
            return nil
        }

        let database = try PlaybackSubtitleDatabase(path: renderCacheDatabaseURL)
        return try database.assRenderSegment(
            forSubtitleFile: URL.fromMediaPath(sourcePath),
            atMilliseconds: timestampMilliseconds
        )
    }

    private static func makeSurface(from output: SFXASSCroppedRenderOutput) -> ASSCroppedSurface? {
        let width = output.width
        let height = output.height
        let stride = output.stride
        guard width > 0, height > 0, stride > 0, output.rgbaData.count > 0 else {
            return nil
        }

        return ASSCroppedSurface(
            rgbaData: output.rgbaData as Data,
            width: width,
            height: height,
            stride: stride,
            destinationX: output.destinationX,
            destinationY: output.destinationY
        )
    }
}

@MainActor
final class SourceFaithfulASSSubtitleOverlayView: NSView {
    var areSubtitlesVisible: Bool = true {
        didSet {
            if !isApplyingPresentation, oldValue != areSubtitlesVisible {
                subtitleContainerLayer.isHidden = !areSubtitlesVisible
                if areSubtitlesVisible {
                    requestRender(force: true)
                }
                needsDisplay = true
            }
        }
    }

    var currentTimeMilliseconds: Int = 0 {
        didSet {
            if !isApplyingPresentation, oldValue != currentTimeMilliseconds {
                requestRender()
            }
        }
    }

    var videoSize: CGSize? {
        didSet {
            if !isApplyingPresentation, oldValue != videoSize {
                reloadRendererIfPossible()
                needsDisplay = true
            }
        }
    }

    var onRenderingFailure: ((String) -> Void)?
    /// The subtitle file itself could not be read. Unlike the renderer's own
    /// in-flight failures this one is the user's to see, so it travels to the
    /// App and is shown in the player's error banner.
    var onSourceLoadFailure: ((URL) -> Void)?

    private var source: PlaybackSubtitleSource?
    private var generation: UUID?
    private var isRendererReady = false
    private var isRenderInFlight = false
    private var pendingTimestampMilliseconds: Int?
    private var renderedTimestampMilliseconds: Int?
    private var renderedValidRangeMilliseconds: Range<Int>?
    private var renderedFrame: ASSRenderedFrame?
    private var failureMessage: String?
    private var isApplyingPresentation = false
    private let subtitleContainerLayer = CALayer()
    private var subtitleSurfaceLayer: CALayer?
    private var rendererWorker = SourceFaithfulASSRendererWorker()
    private(set) var rendererLoadCountForTesting = 0

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        subtitleContainerLayer.frame = bounds
        subtitleContainerLayer.isGeometryFlipped = true
        subtitleContainerLayer.masksToBounds = false
        subtitleContainerLayer.actions = [
            "contents": NSNull(),
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull(),
            "sublayers": NSNull()
        ]
        layer?.addSublayer(subtitleContainerLayer)
        postsFrameChangedNotifications = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        rendererWorker.invalidate()
    }

    var rendererWorkerIdentityForTesting: ObjectIdentifier {
        ObjectIdentifier(rendererWorker)
    }

    func currentPresentationFrame() -> ASSSparseFrame? {
        guard areSubtitlesVisible,
              let renderedFrame
        else {
            return nil
        }

        switch renderedFrame {
        case .sparse(let frame, _):
            return frame
        case .unchanged:
            return nil
        }
    }

    func nextScheduledRenderMilliseconds(after timestampMilliseconds: Int) -> Int? {
        guard areSubtitlesVisible, source != nil else {
            return nil
        }
        guard isRendererReady, !isRenderInFlight, pendingTimestampMilliseconds == nil else {
            return timestampMilliseconds + 33
        }
        guard let validRange = renderedValidRangeMilliseconds,
              validRange.contains(timestampMilliseconds)
        else {
            return timestampMilliseconds
        }
        return validRange.upperBound < Int.max ? validRange.upperBound : nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func setFrameSize(_ newSize: NSSize) {
        let previousSize = frame.size
        super.setFrameSize(newSize)
        if source?.format == .srt, previousSize != newSize {
            reloadRendererIfPossible()
        }
    }

    override func layout() {
        super.layout()

        PlaybackPerformanceProbe.measure("SourceFaithfulASSSubtitleOverlayView.layout", thresholdMilliseconds: 8) {
            subtitleContainerLayer.frame = bounds
            if let renderedFrame {
                updatePresentationLayout(for: renderedFrame)
            }
        }
    }

    func setSource(_ source: PlaybackSubtitleSource?) {
        self.source = source
        clearPresentationState()

        guard source != nil else {
            replaceRendererWorker()
            needsDisplay = true
            return
        }

        reloadRendererIfPossible()
        needsDisplay = true
    }

    func setPresentation(
        source nextSource: PlaybackSubtitleSource?,
        videoSize nextVideoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool
    ) {
        let canReuseRenderer = rendererCanBeReused(
            for: nextSource,
            videoSize: nextVideoSize
        )

        isApplyingPresentation = true
        source = nextSource
        videoSize = nextVideoSize
        currentTimeMilliseconds = max(0, milliseconds)
        areSubtitlesVisible = isVisible
        isApplyingPresentation = false
        subtitleContainerLayer.isHidden = !isVisible

        guard nextSource != nil else {
            clearPresentationState()
            replaceRendererWorker()
            needsDisplay = true
            return
        }

        if canReuseRenderer {
            failureMessage = nil
            requestRender(force: true)
            needsDisplay = true
            return
        }

        reloadRendererIfPossible()
        needsDisplay = true
    }

    private func reloadRendererIfPossible() {
        PlaybackPerformanceProbe.measure("SourceFaithfulASSSubtitleOverlayView.reloadRendererIfPossible", thresholdMilliseconds: 8) {
            guard let source else {
                return
            }

            guard let renderSize = renderFrameSize() else {
                failureMessage = "ASS renderer is waiting for a valid video size."
                needsDisplay = true
                return
            }

            isRendererReady = false
            clearPresentationState()
            failureMessage = nil
            needsDisplay = true
            replaceRendererWorker()

            let loadGeneration = rendererWorker.load(
                source: source,
                frameWidth: renderSize.width,
                frameHeight: renderSize.height,
                initialTimestampMilliseconds: currentTimeMilliseconds
            ) { [weak self] returnedGeneration, result in
                let scheduledAt = PlaybackPerformanceProbe.now()
                DispatchQueue.main.async(execute: {
                    PlaybackPerformanceProbe.logElapsed(
                        "SourceFaithfulASSSubtitleOverlayView.loadCompletion.mainDelay",
                        since: scheduledAt,
                        thresholdMilliseconds: 50
                    )
                    guard let self, self.generation == returnedGeneration else {
                        return
                    }

                    switch result {
                    case .success:
                        self.isRendererReady = true
                        self.failureMessage = nil
                        self.requestRender(force: true)
                    case .failure(let error):
                        self.isRendererReady = false
                        self.renderedFrame = nil
                        self.failureMessage = error.message
                        self.onRenderingFailure?(error.message)
                        self.onSourceLoadFailure?(source.url)
                        self.needsDisplay = true
                    }
                })
            }
            rendererLoadCountForTesting += 1
            generation = loadGeneration
        }
    }

    private func rendererCanBeReused(
        for nextSource: PlaybackSubtitleSource?,
        videoSize nextVideoSize: CGSize?
    ) -> Bool {
        guard let source,
              let nextSource,
              generation != nil,
              failureMessage == nil,
              videoSize == nextVideoSize
        else {
            return false
        }

        return source.url.standardizedMediaURL == nextSource.url.standardizedMediaURL
            && source.format == nextSource.format
            && source.renderCacheDatabaseURL?.standardizedFileURL
                == nextSource.renderCacheDatabaseURL?.standardizedFileURL
    }

    private func requestRender(force: Bool = false) {
        guard areSubtitlesVisible,
              isRendererReady,
              let generation
        else {
            return
        }

        let timestampMilliseconds = max(0, currentTimeMilliseconds)
        if !force {
            if timestampMilliseconds == renderedTimestampMilliseconds {
                return
            }
            if !isRenderInFlight,
               pendingTimestampMilliseconds == nil,
               let validRange = renderedValidRangeMilliseconds,
               validRange.contains(timestampMilliseconds) {
                renderedTimestampMilliseconds = timestampMilliseconds
                return
            }
        } else {
            renderedValidRangeMilliseconds = nil
        }

        pendingTimestampMilliseconds = timestampMilliseconds
        startNextRenderIfNeeded(generation: generation)
    }

    private func startNextRenderIfNeeded(generation: UUID) {
        guard !isRenderInFlight,
              let timestampMilliseconds = pendingTimestampMilliseconds
        else {
            return
        }

        pendingTimestampMilliseconds = nil
        isRenderInFlight = true

        rendererWorker.render(
            generation: generation,
            timestampMilliseconds: timestampMilliseconds
        ) { [weak self] returnedGeneration, result in
            let scheduledAt = PlaybackPerformanceProbe.now()
            DispatchQueue.main.async(execute: {
                PlaybackPerformanceProbe.logElapsed(
                    "SourceFaithfulASSSubtitleOverlayView.renderCompletion.mainDelay",
                    since: scheduledAt,
                    thresholdMilliseconds: 50
                )
                guard let self, self.generation == returnedGeneration else {
                    return
                }

                self.isRenderInFlight = false

                switch result {
                case .success(let frame):
                    self.renderedTimestampMilliseconds = frame.timestampMilliseconds
                    self.renderedValidRangeMilliseconds = frame.validRangeMilliseconds
                    self.apply(frame)
                    self.failureMessage = nil
                case .failure(let error):
                    self.clearPresentationState()
                    self.failureMessage = error.message
                    self.onRenderingFailure?(error.message)
                    self.needsDisplay = true
                }

                if let nextPending = self.pendingTimestampMilliseconds,
                   let validRange = self.renderedValidRangeMilliseconds,
                   validRange.contains(nextPending) {
                    self.renderedTimestampMilliseconds = nextPending
                    self.pendingTimestampMilliseconds = nil
                }

                if self.pendingTimestampMilliseconds != nil, let generation = self.generation {
                    self.startNextRenderIfNeeded(generation: generation)
                }
            })
        }
    }

    private func apply(_ frame: ASSRenderedFrame) {
        switch frame {
        case .sparse:
            renderedFrame = frame
            updatePresentation(for: frame)
        case .unchanged:
            break
        }
    }

    private func clearPresentationState() {
        isRendererReady = false
        isRenderInFlight = false
        pendingTimestampMilliseconds = nil
        renderedTimestampMilliseconds = nil
        renderedValidRangeMilliseconds = nil
        renderedFrame = nil
        failureMessage = nil
        clearSubtitleLayers()
    }

    private func replaceRendererWorker() {
        let previousWorker = rendererWorker
        rendererWorker = SourceFaithfulASSRendererWorker()
        generation = nil
        previousWorker.invalidate()
    }

    private func updatePresentation(for renderedFrame: ASSRenderedFrame) {
        switch renderedFrame {
        case .sparse(let frame, _):
            updatePresentation(for: frame)
        case .unchanged:
            break
        }
    }

    private func updatePresentation(for frame: ASSSparseFrame) {
        PlaybackPerformanceProbe.measure("SourceFaithfulASSSubtitleOverlayView.updatePresentation", thresholdMilliseconds: 8) {
            guard frame.frameWidth > 0, frame.frameHeight > 0 else {
                clearSubtitleLayers()
                return
            }

            subtitleContainerLayer.isHidden = !areSubtitlesVisible

            guard let surface = frame.surface,
                  let surfaceImage = makeImage(from: surface)
            else {
                clearSubtitleLayers()
                return
            }

            let surfaceLayer: CALayer
            if let existingLayer = subtitleSurfaceLayer {
                surfaceLayer = existingLayer
            } else {
                let newLayer = CALayer()
                newLayer.contentsGravity = .resize
                newLayer.magnificationFilter = .linear
                newLayer.minificationFilter = .linear
                newLayer.actions = [
                    "contents": NSNull(),
                    "position": NSNull(),
                    "bounds": NSNull(),
                    "frame": NSNull()
                ]
                subtitleContainerLayer.addSublayer(newLayer)
                subtitleSurfaceLayer = newLayer
                surfaceLayer = newLayer
            }
            surfaceLayer.contents = surfaceImage
            surfaceLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2

            updatePresentationLayout(for: frame)
        }
    }

    private func updatePresentationLayout(for renderedFrame: ASSRenderedFrame) {
        switch renderedFrame {
        case .sparse(let frame, _):
            updatePresentationLayout(for: frame)
        case .unchanged:
            break
        }
    }

    private func updatePresentationLayout(for frame: ASSSparseFrame) {
        guard frame.frameWidth > 0, frame.frameHeight > 0 else {
            return
        }

        let presentationRect = source?.format == .srt
            ? bounds
            : SourceFaithfulASSSubtitleLayout.videoRect(
                videoSize: videoSize,
                in: bounds
            )
        guard presentationRect.width > 1, presentationRect.height > 1 else {
            return
        }

        if let surface = frame.surface, let subtitleSurfaceLayer {
            subtitleSurfaceLayer.frame = SourceFaithfulASSSubtitleLayout.surfaceFrame(
                destinationX: surface.destinationX,
                destinationY: surface.destinationY,
                width: surface.width,
                height: surface.height,
                frameWidth: frame.frameWidth,
                frameHeight: frame.frameHeight,
                videoRect: presentationRect
            ) ?? .zero
        }
    }

    private func clearSubtitleLayers() {
        subtitleSurfaceLayer?.removeFromSuperlayer()
        subtitleSurfaceLayer = nil
    }

    private func makeImage(from surface: ASSCroppedSurface) -> CGImage? {
        guard let provider = CGDataProvider(data: surface.rgbaData as CFData) else {
            failureMessage = "ASS renderer produced image data that could not be displayed."
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: surface.width,
            height: surface.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: surface.stride,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private func renderFrameSize() -> (width: Int, height: Int)? {
        let size = source?.format == .srt
            ? bounds.size
            : videoSize ?? bounds.size
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 1, height > 1 else {
            return nil
        }

        return (width, height)
    }

}
