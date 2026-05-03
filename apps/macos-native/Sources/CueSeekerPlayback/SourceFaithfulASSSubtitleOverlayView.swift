import AppKit
import CASSRendering
import CoreGraphics
import Foundation

private struct ASSImageTile: @unchecked Sendable {
    let rgbaData: Data
    let width: Int
    let height: Int
    let stride: Int
    let destinationX: Int
    let destinationY: Int
}

private struct ASSSparseFrame: @unchecked Sendable {
    let tiles: [ASSImageTile]
    let frameWidth: Int
    let frameHeight: Int
    let timestampMilliseconds: Int
}

private enum ASSRenderedFrame: @unchecked Sendable {
    case sparse(ASSSparseFrame)

    var timestampMilliseconds: Int {
        switch self {
        case .sparse(let frame):
            frame.timestampMilliseconds
        }
    }
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
        renderingMode: ASSSubtitleRenderingMode,
        completion: @escaping @Sendable (UUID, Result<ASSRenderedFrame, ASSRenderWorkerError>) -> Void
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
                let output = try session.renderImages(atTimestampMilliseconds: timestampMilliseconds)
                let frame = ASSSparseFrame(
                    tiles: output.images.compactMap(Self.makeTile(from:)),
                    frameWidth: output.frameWidth,
                    frameHeight: output.frameHeight,
                    timestampMilliseconds: timestampMilliseconds
                )
                completion(expectedGeneration, .success(.sparse(frame)))
            } catch {
                completion(
                    expectedGeneration,
                    .failure(ASSRenderWorkerError(message: "ASS renderer failed at \(timestampMilliseconds) ms: \(error.localizedDescription)"))
                )
            }
        }
    }

    private static func makeTile(from image: SFXASSImage) -> ASSImageTile? {
        let width = image.width
        let height = image.height
        let sourceStride = image.stride
        guard width > 0, height > 0, sourceStride > 0 else {
            return nil
        }

        let color = image.color
        let sourceRed = Int((color >> 24) & 0xff)
        let sourceGreen = Int((color >> 16) & 0xff)
        let sourceBlue = Int((color >> 8) & 0xff)
        let sourceOpacity = 255 - Int(color & 0xff)
        guard sourceOpacity > 0 else {
            return nil
        }

        let destinationStride = width * 4
        let maskData = image.bitmapData as Data
        var rgbaData = Data(count: destinationStride * height)

        rgbaData.withUnsafeMutableBytes { rgbaBuffer in
            guard let rgbaBase = rgbaBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }

            maskData.withUnsafeBytes { maskBuffer in
                guard let maskBase = maskBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }

                for y in 0..<height {
                    let sourceRow = maskBase + (y * sourceStride)
                    let destinationRow = rgbaBase + (y * destinationStride)

                    for x in 0..<width {
                        let mask = Int(sourceRow[x])
                        let sourceAlpha = (mask * sourceOpacity + 127) / 255
                        if sourceAlpha <= 0 {
                            continue
                        }

                        let pixel = destinationRow + (x * 4)
                        pixel[0] = UInt8((sourceRed * sourceAlpha + 127) / 255)
                        pixel[1] = UInt8((sourceGreen * sourceAlpha + 127) / 255)
                        pixel[2] = UInt8((sourceBlue * sourceAlpha + 127) / 255)
                        pixel[3] = UInt8(sourceAlpha)
                    }
                }
            }
        }

        return ASSImageTile(
            rgbaData: rgbaData,
            width: width,
            height: height,
            stride: destinationStride,
            destinationX: image.destinationX,
            destinationY: image.destinationY
        )
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

    var renderingMode: ASSSubtitleRenderingMode = .legacy {
        didSet {
            if oldValue != renderingMode {
                renderedTimestampMilliseconds = nil
                renderedFrame = nil
                requestRender(force: true)
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
    private var renderedFrame: ASSRenderedFrame?
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
        renderedFrame = nil
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

        if let renderedFrame {
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
            draw(renderedFrame: renderedFrame, in: videoRect, using: context)
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
        renderedFrame = nil
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
                    self.renderedFrame = nil
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
            timestampMilliseconds: timestampMilliseconds,
            renderingMode: renderingMode
        ) { [weak self] returnedGeneration, result in
            DispatchQueue.main.async(execute: {
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
                    self.renderedFrame = nil
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
            needsDisplay = true
        }
    }

    private func draw(renderedFrame: ASSRenderedFrame, in videoRect: CGRect, using context: CGContext) {
        switch renderedFrame {
        case .sparse(let frame):
            draw(sparseFrame: frame, in: videoRect, using: context)
        }
    }

    private func draw(sparseFrame frame: ASSSparseFrame, in videoRect: CGRect, using context: CGContext) {
        guard frame.frameWidth > 0, frame.frameHeight > 0 else {
            return
        }

        let scaleX = videoRect.width / CGFloat(frame.frameWidth)
        let scaleY = videoRect.height / CGFloat(frame.frameHeight)

        for tile in frame.tiles {
            guard let tileImage = makeImage(from: tile) else {
                continue
            }

            let drawRect = CGRect(
                x: videoRect.minX + (CGFloat(tile.destinationX) * scaleX),
                y: bounds.height - videoRect.minY - (CGFloat(tile.destinationY + tile.height) * scaleY),
                width: CGFloat(tile.width) * scaleX,
                height: CGFloat(tile.height) * scaleY
            )
            context.draw(tileImage, in: drawRect)
        }
    }

    private func makeImage(from tile: ASSImageTile) -> CGImage? {
        guard let provider = CGDataProvider(data: tile.rgbaData as CFData) else {
            failureMessage = "ASS renderer produced image data that could not be displayed."
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: tile.width,
            height: tile.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: tile.stride,
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
