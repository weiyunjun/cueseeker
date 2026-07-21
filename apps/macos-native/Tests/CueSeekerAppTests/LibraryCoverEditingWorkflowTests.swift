import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CueSeekerApp

@Test
@MainActor
func libraryCoverEditingSessionStartsWithLargestCrop() throws {
    let image = try libraryCoverEditingWorkflowImage(width: 1_000, height: 1_000)
    let source = LibraryUserCoverSource(image: image)
    let session = LibraryCoverEditingSession(
        target: .folder(path: "/Media/Show"),
        source: source
    )

    #expect(session.target == .folder(path: "/Media/Show"))
    #expect(session.cropRect == LibraryCoverCropGeometry.initialCropRect(imageSize: source.pixelSize))
    #expect(!session.isSaving)
}

@Test
func libraryCoverEditingUsesAcceptedCopyAndContentTypes() {
    #expect(LibraryCoverEditingCopy.dialogTitle == "Edit Cover")
    #expect(
        LibraryCoverEditingCopy.hint
            == "Support: JPG, JPEG, PNG, and GIF no more than 20 MB."
    )
    #expect(LibraryCoverEditingCopy.cancelButtonTitle == "Cancel")
    #expect(LibraryCoverEditingCopy.saveButtonTitle == "Save")
    #expect(Set(LibraryCoverOpenPanelPolicy.allowedContentTypes) == [.jpeg, .png, .gif])
}

@Test
func libraryCoverOpenPanelGreysUnsupportedAndOversizedFiles() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerCoverPanelPolicyTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let validURL = directory.appendingPathComponent("valid.jpg")
    try libraryCoverEditingWorkflowWriteJPEG(
        try libraryCoverEditingWorkflowImage(width: 16, height: 9),
        to: validURL
    )
    let unsupportedURL = directory.appendingPathComponent("unsupported.webp")
    try Data([0x00]).write(to: unsupportedURL)
    let oversizedURL = directory.appendingPathComponent("oversized.png")
    try Data(count: Int(LibraryUserCoverProcessor.maximumSourceByteCount) + 1)
        .write(to: oversizedURL)

    #expect(LibraryCoverOpenPanelPolicy.shouldEnable(directory))
    #expect(LibraryCoverOpenPanelPolicy.shouldEnable(validURL))
    #expect(!LibraryCoverOpenPanelPolicy.shouldEnable(unsupportedURL))
    #expect(!LibraryCoverOpenPanelPolicy.shouldEnable(oversizedURL))
}

private func libraryCoverEditingWorkflowImage(width: Int, height: Int) throws -> CGImage {
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return try #require(context.makeImage())
}

private func libraryCoverEditingWorkflowWriteJPEG(
    _ image: CGImage,
    to url: URL
) throws {
    let destination = try #require(
        CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        )
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}
