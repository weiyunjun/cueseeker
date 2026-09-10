import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CueSeekerApp

@Test
@MainActor
func libraryCoverEditingSessionStartsWithCurrentPreviewAndRequiresNewSource() throws {
    let session = LibraryCoverEditingSession(
        target: .folder(path: "/Media/Show"),
        currentCoverPath: "/Covers/current.jpg",
        currentCoverRevision: "current-revision"
    )

    #expect(session.target == .folder(path: "/Media/Show"))
    #expect(session.currentCoverPath == "/Covers/current.jpg")
    #expect(session.currentCoverRevision == "current-revision")
    #expect(session.selectedSource == nil)
    #expect(session.cropRect == .zero)
    #expect(!session.canSave)
    #expect(!session.isSaving)

    let image = try libraryCoverEditingWorkflowImage(width: 1_000, height: 1_000)
    let source = LibraryUserCoverSource(image: image)
    session.selectSource(source)

    #expect(session.selectedSource != nil)
    #expect(session.cropRect == LibraryCoverCropGeometry.initialCropRect(imageSize: source.pixelSize))
    #expect(session.canSave)

    session.isSaving = true
    #expect(!session.canSave)
}

@Test
@MainActor
func libraryChangeCoverOpensEditorBeforeSourceSelection() throws {
    let suiteName = "CueSeekerLibraryCoverEditorTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerLibraryCoverEditorTests-\(UUID().uuidString)",
            isDirectory: true
        )
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: directory.appendingPathComponent("CueSeeker.sqlite")
    )
    app.beginChangingLibraryCover(
        target: .video(path: "/Media/Show/Episode 1.mkv"),
        currentCoverPath: nil,
        currentCoverRevision: nil
    )

    let session = try #require(app.library.coverEditingSession)
    #expect(session.target == .video(path: "/Media/Show/Episode 1.mkv"))
    #expect(session.selectedSource == nil)
    #expect(!session.canSave)

    app.cancelLibraryCoverEditing()
    #expect(app.library.coverEditingSession == nil)
}

@Test
func libraryCoverEditingUsesAcceptedCopyAndContentTypes() {
    #expect(LibraryCoverEditingCopy.dialogTitle == "Edit Cover")
    #expect(LibraryCoverEditingCopy.chooseImageActionTitle == "Choose Image")
    #expect(LibraryCoverEditingCopy.editIcon == .pencilSimple)
    #expect(
        LibraryCoverEditingCopy.hint
            == "Support: JPG, JPEG, PNG, and GIF no more than 20 MB."
    )
    #expect(LibraryCoverEditingCopy.cancelButtonTitle == "Cancel")
    #expect(LibraryCoverEditingCopy.saveButtonTitle == "Save")
    #expect(Set(LibraryCoverOpenPanelPolicy.allowedContentTypes) == [.jpeg, .png, .gif])
    #expect(LibraryCoverContextMenuItem.title == "Change Cover")
    #expect(LibraryCoverContextMenuItem.icon == .export)
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
