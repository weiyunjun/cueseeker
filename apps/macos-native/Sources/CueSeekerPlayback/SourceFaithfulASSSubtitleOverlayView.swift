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

private struct ASSDirtyRectFrame: @unchecked Sendable {
    let rgbaData: Data
    let width: Int
    let height: Int
    let stride: Int
    let originX: Int
    let originY: Int
    let frameWidth: Int
    let frameHeight: Int
    let timestampMilliseconds: Int
}

private struct ASSFullFrame: @unchecked Sendable {
    let rgbaData: Data
    let width: Int
    let height: Int
    let stride: Int
    let timestampMilliseconds: Int
}

private enum ASSRenderedFrame: @unchecked Sendable {
    case fullFrame(ASSFullFrame)
    case sparse(ASSSparseFrame)
    case dirtyRect(ASSDirtyRectFrame)

    var timestampMilliseconds: Int {
        switch self {
        case .fullFrame(let frame):
            frame.timestampMilliseconds
        case .sparse(let frame):
            frame.timestampMilliseconds
        case .dirtyRect(let frame):
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
                switch renderingMode {
                case .fullFrameRGBA:
                    let output = try session.renderFrame(atTimestampMilliseconds: timestampMilliseconds)
                    let frame = ASSFullFrame(
                        rgbaData: output.rgbaData,
                        width: output.width,
                        height: output.height,
                        stride: output.stride,
                        timestampMilliseconds: timestampMilliseconds
                    )
                    completion(expectedGeneration, .success(.fullFrame(frame)))
                case .sparseImages:
                    let output = try session.renderImages(atTimestampMilliseconds: timestampMilliseconds)
                    let frame = ASSSparseFrame(
                        tiles: output.images.compactMap(Self.makeTile(from:)),
                        frameWidth: output.frameWidth,
                        frameHeight: output.frameHeight,
                        timestampMilliseconds: timestampMilliseconds
                    )
                    completion(expectedGeneration, .success(.sparse(frame)))
                case .dirtyRectSurface:
                    let output = try session.renderImages(atTimestampMilliseconds: timestampMilliseconds)
                    let frame = Self.makeDirtyRectFrame(
                        from: output,
                        timestampMilliseconds: timestampMilliseconds
                    )
                    completion(expectedGeneration, .success(.dirtyRect(frame)))
                }
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

    private static func makeDirtyRectFrame(
        from output: SFXASSImageRenderOutput,
        timestampMilliseconds: Int
    ) -> ASSDirtyRectFrame {
        let frameWidth = output.frameWidth
        let frameHeight = output.frameHeight
        guard frameWidth > 0, frameHeight > 0 else {
            return ASSDirtyRectFrame(
                rgbaData: Data(),
                width: 0,
                height: 0,
                stride: 0,
                originX: 0,
                originY: 0,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                timestampMilliseconds: timestampMilliseconds
            )
        }

        var minX = frameWidth
        var minY = frameHeight
        var maxX = 0
        var maxY = 0
        let images = output.images.filter { image in
            let width = image.width
            let height = image.height
            let sourceOpacity = 255 - Int(image.color & 0xff)
            guard width > 0, height > 0, image.stride > 0, sourceOpacity > 0 else {
                return false
            }

            let clippedMinX = max(0, image.destinationX)
            let clippedMinY = max(0, image.destinationY)
            let clippedMaxX = min(frameWidth, image.destinationX + width)
            let clippedMaxY = min(frameHeight, image.destinationY + height)
            guard clippedMinX < clippedMaxX, clippedMinY < clippedMaxY else {
                return false
            }

            minX = min(minX, clippedMinX)
            minY = min(minY, clippedMinY)
            maxX = max(maxX, clippedMaxX)
            maxY = max(maxY, clippedMaxY)
            return true
        }

        guard !images.isEmpty, minX < maxX, minY < maxY else {
            return ASSDirtyRectFrame(
                rgbaData: Data(),
                width: 0,
                height: 0,
                stride: 0,
                originX: 0,
                originY: 0,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                timestampMilliseconds: timestampMilliseconds
            )
        }

        let width = maxX - minX
        let height = maxY - minY
        let stride = width * 4
        var rgbaData = Data(count: stride * height)

        rgbaData.withUnsafeMutableBytes { rgbaBuffer in
            guard let rgbaBase = rgbaBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }

            for image in images {
                composite(image: image, into: rgbaBase, dirtyMinX: minX, dirtyMinY: minY, dirtyWidth: width, dirtyHeight: height, dirtyStride: stride)
            }
        }

        return ASSDirtyRectFrame(
            rgbaData: rgbaData,
            width: width,
            height: height,
            stride: stride,
            originX: minX,
            originY: minY,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            timestampMilliseconds: timestampMilliseconds
        )
    }

    private static func composite(
        image: SFXASSImage,
        into destination: UnsafeMutablePointer<UInt8>,
        dirtyMinX: Int,
        dirtyMinY: Int,
        dirtyWidth: Int,
        dirtyHeight: Int,
        dirtyStride: Int
    ) {
        let sourceRed = Int((image.color >> 24) & 0xff)
        let sourceGreen = Int((image.color >> 16) & 0xff)
        let sourceBlue = Int((image.color >> 8) & 0xff)
        let sourceOpacity = 255 - Int(image.color & 0xff)
        guard sourceOpacity > 0 else {
            return
        }

        let maskData = image.bitmapData as Data
        maskData.withUnsafeBytes { maskBuffer in
            guard let maskBase = maskBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }

            let startX = max(0, dirtyMinX - image.destinationX)
            let startY = max(0, dirtyMinY - image.destinationY)
            let endX = min(image.width, dirtyMinX + dirtyWidth - image.destinationX)
            let endY = min(image.height, dirtyMinY + dirtyHeight - image.destinationY)
            guard startX < endX, startY < endY else {
                return
            }

            for sourceY in startY..<endY {
                let destinationY = image.destinationY + sourceY - dirtyMinY
                let sourceRow = maskBase + (sourceY * image.stride)
                let destinationRow = destination + (destinationY * dirtyStride)

                for sourceX in startX..<endX {
                    let destinationX = image.destinationX + sourceX - dirtyMinX
                    let mask = Int(sourceRow[sourceX])
                    let sourceAlpha = (mask * sourceOpacity + 127) / 255
                    if sourceAlpha <= 0 {
                        continue
                    }

                    let pixel = destinationRow + (destinationX * 4)
                    let inverseAlpha = 255 - sourceAlpha
                    pixel[0] = UInt8((sourceRed * sourceAlpha + Int(pixel[0]) * inverseAlpha + 127) / 255)
                    pixel[1] = UInt8((sourceGreen * sourceAlpha + Int(pixel[1]) * inverseAlpha + 127) / 255)
                    pixel[2] = UInt8((sourceBlue * sourceAlpha + Int(pixel[2]) * inverseAlpha + 127) / 255)
                    pixel[3] = UInt8(sourceAlpha + (Int(pixel[3]) * inverseAlpha + 127) / 255)
                }
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

    var renderingMode: ASSSubtitleRenderingMode = .sparseImages {
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
                    self.renderedFrame = frame
                    self.failureMessage = nil
                    self.needsDisplay = true
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

    private func draw(renderedFrame: ASSRenderedFrame, in videoRect: CGRect, using context: CGContext) {
        switch renderedFrame {
        case .fullFrame(let frame):
            draw(fullFrame: frame, in: videoRect, using: context)
        case .sparse(let frame):
            draw(sparseFrame: frame, in: videoRect, using: context)
        case .dirtyRect(let frame):
            draw(dirtyRectFrame: frame, in: videoRect, using: context)
        }
    }

    private func draw(fullFrame frame: ASSFullFrame, in videoRect: CGRect, using context: CGContext) {
        guard let image = makeImage(from: frame) else {
            return
        }

        let drawRect = CGRect(
            x: videoRect.minX,
            y: bounds.height - videoRect.maxY,
            width: videoRect.width,
            height: videoRect.height
        )
        context.draw(image, in: drawRect)
    }

    private func draw(dirtyRectFrame frame: ASSDirtyRectFrame, in videoRect: CGRect, using context: CGContext) {
        guard frame.frameWidth > 0, frame.frameHeight > 0, frame.width > 0, frame.height > 0 else {
            return
        }

        guard let image = makeImage(from: frame) else {
            return
        }

        let scaleX = videoRect.width / CGFloat(frame.frameWidth)
        let scaleY = videoRect.height / CGFloat(frame.frameHeight)
        let drawRect = CGRect(
            x: videoRect.minX + (CGFloat(frame.originX) * scaleX),
            y: bounds.height - videoRect.minY - (CGFloat(frame.originY + frame.height) * scaleY),
            width: CGFloat(frame.width) * scaleX,
            height: CGFloat(frame.height) * scaleY
        )
        context.draw(image, in: drawRect)
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

    private func makeImage(from frame: ASSFullFrame) -> CGImage? {
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

    private func makeImage(from frame: ASSDirtyRectFrame) -> CGImage? {
        guard let provider = CGDataProvider(data: frame.rgbaData as CFData) else {
            failureMessage = "ASS renderer produced dirty-rect data that could not be displayed."
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
