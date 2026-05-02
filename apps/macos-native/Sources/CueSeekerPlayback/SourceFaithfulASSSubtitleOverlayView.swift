import AppKit
import CASSRendering
import CoreGraphics
import Foundation

private struct ASSBitmapFrame: @unchecked Sendable {
    let rgbaData: Data
    let width: Int
    let height: Int
    let stride: Int
    let imageCount: Int
    let timestampMilliseconds: Int
}

private struct ASSRenderWorkerError: Error, Sendable {
    let message: String
}

private final class SourceFaithfulASSRendererWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "CueSeeker.SourceFaithfulASSRenderer")
    private var session: SFXASSRendererSession?

    func load(
        sourceURL: URL,
        frameWidth: Int,
        frameHeight: Int,
        completion: @escaping @Sendable (UUID, Result<Void, ASSRenderWorkerError>) -> Void
    ) -> UUID {
        let nextGeneration = UUID()

        queue.async { [sourcePath = sourceURL.path] in
            do {
                let nextSession = try SFXASSRendererSession(
                    assFileAtPath: sourcePath,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight,
                    fontsDirectory: nil
                )
                self.session = nextSession
                completion(nextGeneration, .success(()))
            } catch {
                self.session = nil
                completion(
                    nextGeneration,
                    .failure(ASSRenderWorkerError(message: "ASS renderer failed to load source: \(error.localizedDescription)"))
                )
            }
        }

        return nextGeneration
    }

    func clear() {
        queue.async {
            self.session = nil
        }
    }

    func render(
        generation expectedGeneration: UUID,
        timestampMilliseconds: Int,
        completion: @escaping @Sendable (UUID, Result<ASSBitmapFrame, ASSRenderWorkerError>) -> Void
    ) {
        queue.async {
            guard let session = self.session else {
                completion(
                    expectedGeneration,
                    .failure(ASSRenderWorkerError(message: "ASS renderer session is not ready."))
                )
                return
            }

            do {
                let output = try session.renderFrame(atTimestampMilliseconds: timestampMilliseconds)
                let frame = ASSBitmapFrame(
                    rgbaData: output.rgbaData,
                    width: output.width,
                    height: output.height,
                    stride: output.stride,
                    imageCount: output.imageCount,
                    timestampMilliseconds: timestampMilliseconds
                )
                completion(expectedGeneration, .success(frame))
            } catch {
                completion(
                    expectedGeneration,
                    .failure(ASSRenderWorkerError(message: "ASS renderer failed at \(timestampMilliseconds) ms: \(error.localizedDescription)"))
                )
            }
        }
    }
}

@MainActor
final class SourceFaithfulASSSubtitleOverlayView: NSView {
    var areSubtitlesVisible: Bool = true {
        didSet {
            if oldValue != areSubtitlesVisible {
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

    private let rendererWorker = SourceFaithfulASSRendererWorker()
    private var source: PlaybackSubtitleSource?
    private var generation: UUID?
    private var isRendererReady = false
    private var isRenderInFlight = false
    private var pendingTimestampMilliseconds: Int?
    private var renderedTimestampMilliseconds: Int?
    private var renderedImage: CGImage?
    private var renderedImageCount = 0
    private var failureMessage: String?

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        postsFrameChangedNotifications = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setSource(_ source: PlaybackSubtitleSource?) {
        self.source = source
        isRendererReady = false
        isRenderInFlight = false
        pendingTimestampMilliseconds = nil
        renderedTimestampMilliseconds = nil
        renderedImage = nil
        renderedImageCount = 0
        failureMessage = nil

        guard source != nil else {
            generation = nil
            rendererWorker.clear()
            needsDisplay = true
            return
        }

        reloadRendererIfPossible()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard areSubtitlesVisible else {
            return
        }

        if let renderedImage {
            let videoRect = displayedVideoRect(in: bounds)
            guard videoRect.width > 1, videoRect.height > 1 else {
                return
            }

            guard let context = NSGraphicsContext.current?.cgContext else {
                return
            }

            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            let drawRect = CGRect(
                x: videoRect.minX,
                y: bounds.height - videoRect.maxY,
                width: videoRect.width,
                height: videoRect.height
            )
            context.draw(renderedImage, in: drawRect)
            context.restoreGState()
        }

        if let failureMessage {
            drawFailure(message: failureMessage)
        }
    }

    private func reloadRendererIfPossible() {
        guard let source else {
            return
        }

        guard let renderSize = renderFrameSize() else {
            failureMessage = "ASS renderer is waiting for a valid video size."
            needsDisplay = true
            return
        }

        isRendererReady = false
        isRenderInFlight = false
        pendingTimestampMilliseconds = nil
        renderedTimestampMilliseconds = nil
        renderedImage = nil
        renderedImageCount = 0
        failureMessage = nil
        needsDisplay = true

        let loadGeneration = rendererWorker.load(
            sourceURL: source.url,
            frameWidth: renderSize.width,
            frameHeight: renderSize.height
        ) { [weak self] returnedGeneration, result in
            DispatchQueue.main.async(execute: {
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
                    self.renderedImage = nil
                    self.failureMessage = error.message
                    self.onRenderingFailure?(error.message)
                    self.needsDisplay = true
                }
            })
        }
        generation = loadGeneration
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
            DispatchQueue.main.async(execute: {
                guard let self, self.generation == returnedGeneration else {
                    return
                }

                self.isRenderInFlight = false

                switch result {
                case .success(let frame):
                    self.renderedTimestampMilliseconds = frame.timestampMilliseconds
                    self.renderedImageCount = frame.imageCount
                    self.renderedImage = self.makeImage(from: frame)
                    self.failureMessage = nil
                    self.needsDisplay = true
                case .failure(let error):
                    self.renderedImage = nil
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

    private func makeImage(from frame: ASSBitmapFrame) -> CGImage? {
        guard let provider = CGDataProvider(data: frame.rgbaData as CFData) else {
            failureMessage = "ASS renderer produced bitmap data that could not be displayed."
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: frame.width,
            height: frame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: frame.stride,
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

    private func displayedVideoRect(in bounds: CGRect) -> CGRect {
        guard let videoSize,
              videoSize.width > 0,
              videoSize.height > 0,
              bounds.width > 0,
              bounds.height > 0
        else {
            return bounds
        }

        let scale = min(bounds.width / videoSize.width, bounds.height / videoSize.height)
        let width = videoSize.width * scale
        let height = videoSize.height * scale
        return CGRect(
            x: bounds.midX - (width / 2),
            y: bounds.midY - (height / 2),
            width: width,
            height: height
        )
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
