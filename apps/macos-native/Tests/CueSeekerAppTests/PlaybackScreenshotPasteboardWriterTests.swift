import AppKit
import CoreVideo
import ImageIO
import Testing
@testable import CueSeekerApp
@testable import CueSeekerPlayback

@Test
@MainActor
func playbackScreenshotPasteboardWriterPublishesReadablePNG() throws {
    let pixelBuffer = try makePasteboardScreenshotPixelBuffer(width: 5, height: 3)
    let image = try PlaybackCurrentFrameScreenshotRenderer.render(pixelBuffer: pixelBuffer)
    let pasteboard = NSPasteboard(
        name: NSPasteboard.Name("CueSeeker.PlaybackScreenshotTests.\(UUID().uuidString)")
    )
    defer {
        pasteboard.clearContents()
    }

    let encodedPNG = try PlaybackScreenshotPasteboardWriter.pngData(for: image)
    try PlaybackScreenshotPasteboardWriter.write(encodedPNG, to: pasteboard)

    let pngData = try #require(pasteboard.data(forType: .png))
    let source = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
    let copiedImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(copiedImage.width == 5)
    #expect(copiedImage.height == 3)
}

private func makePasteboardScreenshotPixelBuffer(
    width: Int,
    height: Int
) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let result = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
        &pixelBuffer
    )
    guard result == kCVReturnSuccess, let pixelBuffer else {
        throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
    }
    memset(
        baseAddress,
        0x5A,
        CVPixelBufferGetBytesPerRow(pixelBuffer) * height
    )
    return pixelBuffer
}
