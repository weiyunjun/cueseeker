import CoreGraphics
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerPlayback

@Test
func subtitleScreenshotCollageFilenameUsesTimelineBoundsAndCount() throws {
    let plan = try SubtitleCollageSelectionPlan(selectedCues: [
        SubtitleFocusCue(
            id: 1,
            cueGroupID: 1,
            ordinal: 0,
            eventIndex: 0,
            displayOrder: 0,
            startMilliseconds: 9_000,
            endMilliseconds: 10_000,
            content: "First"
        ),
        SubtitleFocusCue(
            id: 2,
            cueGroupID: 2,
            ordinal: 1,
            eventIndex: 1,
            displayOrder: 1,
            startMilliseconds: 5_000,
            endMilliseconds: 12_000,
            content: "Second"
        ),
    ])
    #expect(
        SubtitleScreenshotExporter.defaultCollageFileName(
            displayTitle: "Show - 01",
            plan: plan
        ) == "Show - 01-00.05-00.12-2.png"
    )
}

@Test
func subtitleScreenshotExporterUsesSharedSRTDrawingCore() throws {
    let baseImage = try #require(makeBlackExportTestImage(width: 640, height: 360))
    let rendered = try SubtitleScreenshotExporter._renderSRTFrameForTesting(
        cues: [
            PlaybackSubtitleCue(
                sourceOrdinal: 0,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "ごちそうさまでした"
            )
        ],
        timestampMilliseconds: 2_000,
        frameImage: baseImage
    )

    #expect(rendered.width == 640)
    #expect(rendered.height == 360)
    #expect(exportTestImageContainsBrightPixel(rendered))
}

@Test
func subtitleCollageASSRenderScriptKeepsOnlySelectedDialogueEvents() throws {
    let sourceScript = """
    [Script Info]
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default,Arial,32

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Not selected
    Comment: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Preserved comment
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Selected
    """

    let selectedScript = try #require(
        SubtitleScreenshotExporter._selectedASSRenderScriptForTesting(
            sourceScript,
            eventIndices: [1]
        )
    )

    #expect(selectedScript.contains("Style: Default,Arial,32"))
    #expect(selectedScript.contains("Preserved comment"))
    #expect(selectedScript.contains(",,Selected"))
    #expect(!selectedScript.contains("Not selected"))
    #expect(
        SubtitleScreenshotExporter._selectedASSRenderScriptForTesting(
            sourceScript,
            eventIndices: [2]
        ) == nil
    )
}

@Test
func subtitleCollageCompositionKeepsFirstFrameAndCropsLaterSubtitleBands() throws {
    let first = try #require(makeBlackExportTestImage(width: 20, height: 10))
    let second = try #require(makeBlackExportTestImage(width: 20, height: 10))

    let collage = try #require(
        SubtitleScreenshotExporter._composeCollageForTesting(frames: [
            (image: first, subtitleBands: []),
            (image: second, subtitleBands: [2...4, 7...8]),
        ])
    )

    #expect(collage.width == 20)
    #expect(collage.height == 15)

    let composition = try SubtitleScreenshotExporter.composeCollage([
        SubtitleCollageRenderedGroup(image: first, subtitleBands: []),
        SubtitleCollageRenderedGroup(
            image: second,
            subtitleBands: [2...4, 7...8]
        ),
    ])
    let reusableCollage = composition.image
    #expect(reusableCollage.width == collage.width)
    #expect(reusableCollage.height == collage.height)
    // The first group is its whole frame; the second is its two bands stacked.
    #expect(composition.groupHeights == [10, 5])

    let destinationURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeeker-Collage-\(UUID().uuidString).png")
    defer {
        try? FileManager.default.removeItem(at: destinationURL)
    }
    try SubtitleScreenshotExporter.exportCollage(
        image: reusableCollage,
        to: destinationURL
    )
    #expect(FileManager.default.fileExists(atPath: destinationURL.path))
    #expect(try Data(contentsOf: destinationURL).isEmpty == false)
}

private func makeBlackExportTestImage(width: Int, height: Int) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        return nil
    }
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
}

private func exportTestImageContainsBrightPixel(_ image: CGImage) -> Bool {
    let bytesPerRow = image.width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    guard let context = CGContext(
        data: &bytes,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ).rawValue
    ) else {
        return false
    }
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    return stride(from: 0, to: bytes.count, by: 4).contains {
        bytes[$0] > 240 && bytes[$0 + 1] > 240 && bytes[$0 + 2] > 240
    }
}

@Test
func subtitleCollageASSRenderScriptKeepsTheClippedCopiesOfASelectedDialogue() throws {
    let sourceScript = """
    [Script Info]
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: ED,Arial,32

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,ED,,0,0,0,,{\\clip(0,0,640,8)}Gradient line
    Dialogue: 0,0:00:01.00,0:00:03.00,ED,,0,0,0,,{\\clip(0,8,640,16)}Gradient line
    Dialogue: 0,0:00:01.00,0:00:03.00,ED,,0,0,0,,Another line
    Dialogue: 0,0:00:01.00,0:00:03.00,ED,,0,0,20,,{\\clip(0,0,640,8)}Gradient line
    """

    let selectedScript = try #require(
        SubtitleScreenshotExporter._selectedASSRenderScriptForTesting(
            sourceScript,
            eventIndices: [0]
        )
    )

    #expect(selectedScript.contains("{\\clip(0,0,640,8)}Gradient line"))
    #expect(selectedScript.contains("{\\clip(0,8,640,16)}Gradient line"))
    #expect(!selectedScript.contains("Another line"))
    #expect(!selectedScript.contains("0,0,20,,"))
}
