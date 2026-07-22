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
    case sparse(ASSSparseFrame)
    case unchanged(timestampMilliseconds: Int)

    var timestampMilliseconds: Int {
        switch self {
        case .sparse(let frame):
            frame.timestampMilliseconds
        case .unchanged(let timestampMilliseconds):
            timestampMilliseconds
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
    private var renderCacheDatabaseURL: URL?
    private var frameWidth = 0
    private var frameHeight = 0
    private var activeRenderSegmentWindow: PlaybackSubtitleTimeWindow?
    private var requestedFontNames: [String]?
    private var speakerDisplayCues: [SubtitleSpeakerDisplayCue] = []

    func load(
        source: PlaybackSubtitleSource,
        frameWidth: Int,
        frameHeight: Int,
        initialTimestampMilliseconds: Int,
        completion: @escaping @Sendable (UUID, Result<Void, ASSRenderWorkerError>) -> Void
    ) -> UUID {
        let nextGeneration = UUID()

        queue.async { [
            sourcePath = source.url.path,
            renderCacheDatabaseURL = source.renderCacheDatabaseURL
        ] in
            guard !self.isInvalidated else {
                return
            }

            do {
                self.clearState()
                self.sourcePath = sourcePath
                self.renderCacheDatabaseURL = renderCacheDatabaseURL
                self.frameWidth = frameWidth
                self.frameHeight = frameHeight
                self.activeRenderSegmentWindow = nil
                self.speakerDisplayCues = source.speakerDisplayCues
                SubtitleSpeakerDisplayDiagnostics.log(
                    "renderer.assSource.load",
                    fields: [
                        "subtitle": source.url.lastPathComponent,
                        "subtitlePath": sourcePath,
                        "speakerCueCount": "\(source.speakerDisplayCues.count)",
                        "frameWidth": "\(frameWidth)",
                        "frameHeight": "\(frameHeight)",
                        "initialTimestampMilliseconds": "\(initialTimestampMilliseconds)"
                    ]
                )
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

                guard output.changed else {
                    completion(expectedGeneration, .success(.unchanged(timestampMilliseconds: timestampMilliseconds)))
                    return
                }

                let frame = ASSSparseFrame(
                    surface: Self.makeSurface(from: output),
                    frameWidth: output.frameWidth,
                    frameHeight: output.frameHeight,
                    timestampMilliseconds: timestampMilliseconds
                )
                completion(expectedGeneration, .success(.sparse(frame)))
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
        renderCacheDatabaseURL = nil
        frameWidth = 0
        frameHeight = 0
        activeRenderSegmentWindow = nil
        requestedFontNames = nil
        speakerDisplayCues = []
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
        guard let sourcePath, frameWidth > 0, frameHeight > 0 else {
            throw ASSRenderWorkerError(message: "ASS renderer source is not ready.")
        }

        if let segment = try indexedRenderSegment(containing: timestampMilliseconds) {
            activeRenderSegmentWindow = PlaybackSubtitleTimeWindow(
                startMilliseconds: segment.startMilliseconds,
                endMilliseconds: segment.endMilliseconds
            )
            print(
                "libass indexed segment: window=\(segment.startMilliseconds)-\(segment.endMilliseconds)ms events=\(segment.eventCount) bytes=\(segment.byteCount)"
            )
            let sourceIdentifier = "\(sourcePath)#\(segment.startMilliseconds)-\(segment.endMilliseconds)"
            let renderScript = rewriteRenderScript(segment.scriptText)
            return try SFXASSRendererSession(
                assScript: renderScript,
                sourceIdentifier: sourceIdentifier,
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )
        }

        activeRenderSegmentWindow = nil
        if let sourceScript = try? String(contentsOf: URL(fileURLWithPath: sourcePath)) {
            let renderScript = rewriteRenderScript(sourceScript)
            if renderScript != sourceScript {
                return try SFXASSRendererSession(
                    assScript: renderScript,
                    sourceIdentifier: sourcePath,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight
                )
            }
        }

        return try SFXASSRendererSession(
            assFileAtPath: sourcePath,
            frameWidth: frameWidth,
            frameHeight: frameHeight
        )
    }

    private func rewriteRenderScript(_ script: String) -> String {
        let speakerRewrittenScript = ASSSpeakerDisplayRewriter.rewrite(
            script: script,
            cues: speakerDisplayCues
        )
        SubtitleSpeakerDisplayDiagnostics.log(
            "renderer.assScript.rewrite",
            fields: [
                "subtitlePath": sourcePath ?? "",
                "speakerCueCount": "\(speakerDisplayCues.count)",
                "changed": "\(speakerRewrittenScript != script)",
                "scriptBytes": "\(script.lengthOfBytes(using: .utf8))",
                "rewrittenBytes": "\(speakerRewrittenScript.lengthOfBytes(using: .utf8))"
            ]
        )
        return ASSFontAliasResolver.shared.rewriteRenderScript(
            speakerRewrittenScript,
            requestedFontNames: requestedFontNames
        )
    }

    private func indexedRenderSegment(containing timestampMilliseconds: Int) throws -> ASSRenderSegment? {
        guard let renderCacheDatabaseURL, let sourcePath else {
            return nil
        }

        let database = try SubtitleDatabase(
            path: renderCacheDatabaseURL,
            access: .readOnly
        )
        return try database.assRenderSegment(
            forSubtitleFile: URL(fileURLWithPath: sourcePath),
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
            if oldValue != areSubtitlesVisible {
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
            if oldValue != currentTimeMilliseconds {
                requestRender()
            }
        }
    }

    var videoSize: CGSize? {
        didSet {
            if oldValue != videoSize {
                reloadRendererIfPossible()
                needsDisplay = true
            }
        }
    }

    var onRenderingFailure: ((String) -> Void)?

    private var source: PlaybackSubtitleSource?
    private var generation: UUID?
    private var isRendererReady = false
    private var isRenderInFlight = false
    private var pendingTimestampMilliseconds: Int?
    private var renderedTimestampMilliseconds: Int?
    private var renderedFrame: ASSRenderedFrame?
    private var failureMessage: String?
    private let subtitleContainerLayer = CALayer()
    private var subtitleSurfaceLayer: CALayer?
    private var rendererWorker = SourceFaithfulASSRendererWorker()

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
        case .sparse(let frame):
            return frame
        case .unchanged:
            return nil
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let failureMessage {
            drawFailure(message: failureMessage)
        }
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
                        self.needsDisplay = true
                    }
                })
            }
            generation = loadGeneration
        }
    }

    private func requestRender(force: Bool = false) {
        guard areSubtitlesVisible,
              isRendererReady,
              let generation
        else {
            return
        }

        let timestampMilliseconds = max(0, currentTimeMilliseconds)
        if !force, timestampMilliseconds == renderedTimestampMilliseconds {
            return
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
                    self.apply(frame)
                    self.failureMessage = nil
                case .failure(let error):
                    self.clearPresentationState()
                    self.failureMessage = error.message
                    self.onRenderingFailure?(error.message)
                    self.needsDisplay = true
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
        case .sparse(let frame):
            updatePresentation(for: frame)
        case .unchanged:
            break
        }
    }

    private func updatePresentation(for frame: ASSSparseFrame) {
        PlaybackPerformanceProbe.measure("SourceFaithfulASSSubtitleOverlayView.updatePresentation", thresholdMilliseconds: 8) {
            clearSubtitleLayers()
            guard frame.frameWidth > 0, frame.frameHeight > 0 else {
                return
            }

            subtitleContainerLayer.isHidden = !areSubtitlesVisible

            guard let surface = frame.surface,
                  let surfaceImage = makeImage(from: surface)
            else {
                return
            }

            let surfaceLayer = CALayer()
            surfaceLayer.contents = surfaceImage
            surfaceLayer.contentsGravity = .resize
            surfaceLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            surfaceLayer.magnificationFilter = .linear
            surfaceLayer.minificationFilter = .linear
            surfaceLayer.actions = [
                "contents": NSNull(),
                "position": NSNull(),
                "bounds": NSNull(),
                "frame": NSNull()
            ]
            subtitleContainerLayer.addSublayer(surfaceLayer)
            subtitleSurfaceLayer = surfaceLayer

            updatePresentationLayout(for: .sparse(frame))
        }
    }

    private func updatePresentationLayout(for renderedFrame: ASSRenderedFrame) {
        switch renderedFrame {
        case .sparse(let frame):
            updatePresentationLayout(for: frame)
        case .unchanged:
            break
        }
    }

    private func updatePresentationLayout(for frame: ASSSparseFrame) {
        guard frame.frameWidth > 0, frame.frameHeight > 0 else {
            return
        }

        let videoRect = SourceFaithfulASSSubtitleLayout.videoRect(
            videoSize: videoSize,
            in: bounds
        )
        guard videoRect.width > 1, videoRect.height > 1 else {
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
                videoRect: videoRect
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
        let size = videoSize ?? bounds.size
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 1, height > 1 else {
            return nil
        }

        return (width, height)
    }

    private func drawFailure(message: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.systemRed.withAlphaComponent(0.82)
        ]
        let text = NSAttributedString(string: "ASS renderer failure: \(message)", attributes: attributes)
        text.draw(
            with: bounds.insetBy(dx: 16, dy: 16),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
    }
}
