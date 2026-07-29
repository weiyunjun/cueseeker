import CoreGraphics
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerPlayback

@Test
func subtitleScreenshotDefaultFilenameUsesDisplayTitleAndCueTimeRange() {
    let item = SubtitleScreenshotExportItem(
        displayTitle: "Ave Mujica - 01",
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/video.ass",
        subtitleFormat: .ass,
        startMilliseconds: 30_100,
        endMilliseconds: 34_999,
        textLines: ["大丈夫"]
    )

    #expect(SubtitleScreenshotExporter.defaultScreenshotFileName(for: item) == "Ave Mujica - 01-00.30-00.34.png")
}

@Test
func subtitleScreenshotDefaultFilenameIncludesHourWhenPresent() {
    let item = SubtitleScreenshotExportItem(
        displayTitle: "Long Show - 12",
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/video.ass",
        subtitleFormat: .ass,
        startMilliseconds: 4_532_000,
        endMilliseconds: 4_538_000,
        textLines: ["Hello"]
    )

    #expect(SubtitleScreenshotExporter.defaultScreenshotFileName(for: item) == "Long Show - 12-01.15.32-01.15.38.png")
}

@Test
func subtitleScreenshotCollageFilenameUsesTimelineBoundsAndCount() {
    let first = SubtitleScreenshotExportItem(
        displayTitle: "Show - 01",
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/video.ass",
        subtitleFormat: .ass,
        startMilliseconds: 9_000,
        endMilliseconds: 10_000,
        textLines: ["First"]
    )
    let second = SubtitleScreenshotExportItem(
        displayTitle: "Show - 01",
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/video.ass",
        subtitleFormat: .ass,
        startMilliseconds: 5_000,
        endMilliseconds: 12_000,
        textLines: ["Second"]
    )

    #expect(SubtitleScreenshotExporter.defaultCollageFileName(for: [first, second]) == "Show - 01-00.05-00.12-2.png")
}

@Test
func subtitleScreenshotCollageRequiresOneStandardizedSubtitleFileAndAtMostFiftyItems() {
    let baseItem = SubtitleScreenshotExportItem(
        displayTitle: "Show - 01",
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/video.ass",
        subtitleFormat: .ass,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        textLines: ["Line"]
    )
    let sameSubtitle = SubtitleScreenshotExportItem(
        displayTitle: "Show - 01",
        videoPath: "/tmp/other.mkv",
        subtitlePath: "/tmp/./video.ass",
        subtitleFormat: .ass,
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        textLines: ["Line"]
    )
    let otherSubtitle = SubtitleScreenshotExportItem(
        displayTitle: "Show - 02",
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/other.ass",
        subtitleFormat: .ass,
        startMilliseconds: 5_000,
        endMilliseconds: 6_000,
        textLines: ["Line"]
    )

    #expect(!SubtitleScreenshotExporter.canExportCollage([]))
    #expect(SubtitleScreenshotExporter.canExportCollage([baseItem]))
    #expect(SubtitleScreenshotExporter.canExportCollage([baseItem, sameSubtitle]))
    #expect(!SubtitleScreenshotExporter.canExportCollage([baseItem, otherSubtitle]))
    #expect(!SubtitleScreenshotExporter.canExportCollage(Array(repeating: baseItem, count: 51)))
    #expect(
        SubtitleScreenshotExportError.invalidCollageItems.description
            == "Collage export requires selected Cues from one subtitle file and no more than 50 items."
    )
}

@Test
func subtitleScreenshotBatchFilenamesDeterministicallyDisambiguateSameTimeCues() {
    let upperCue = subtitleScreenshotTestItem(
        displayTitle: "Show - 01",
        cueDisplayOrder: 0,
        cueEventIndex: 20
    )
    let lowerCue = subtitleScreenshotTestItem(
        displayTitle: "Show - 01",
        cueDisplayOrder: 1,
        cueEventIndex: 10
    )
    let baseName = "Show - 01-00.01-00.02"

    #expect(
        SubtitleScreenshotExporter.defaultScreenshotFileNames(for: [lowerCue, upperCue])
            == ["\(baseName)-cue-02.png", "\(baseName)-cue-01.png"]
    )
    #expect(
        SubtitleScreenshotExporter.defaultScreenshotFileNames(for: [upperCue, lowerCue])
            == ["\(baseName)-cue-01.png", "\(baseName)-cue-02.png"]
    )
    #expect(
        SubtitleScreenshotExporter.defaultScreenshotFileNames(for: [upperCue])
            == ["\(baseName).png"]
    )
    #expect(
        SubtitleScreenshotExporter.defaultScreenshotFileNames(for: [upperCue, upperCue])
            == ["\(baseName)-cue-01.png", "\(baseName)-cue-02.png"]
    )
}

@Test
func subtitleScreenshotCollageSortUsesCueMetadataThenInputOrdinal() {
    let displayOne = subtitleScreenshotTestItem(
        displayTitle: "display-one",
        cueDisplayOrder: 1,
        cueEventIndex: 1
    )
    let tiedFirst = subtitleScreenshotTestItem(
        displayTitle: "tied-first",
        cueDisplayOrder: 0,
        cueEventIndex: 2
    )
    let later = subtitleScreenshotTestItem(
        displayTitle: "later",
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        cueDisplayOrder: 0,
        cueEventIndex: 0
    )
    let laterEvent = subtitleScreenshotTestItem(
        displayTitle: "later-event",
        cueDisplayOrder: 0,
        cueEventIndex: 9
    )
    let tiedSecond = subtitleScreenshotTestItem(
        displayTitle: "tied-second",
        cueDisplayOrder: 0,
        cueEventIndex: 2
    )

    let sorted = SubtitleScreenshotExporter._sortedByTimelineForTesting([
        displayOne,
        tiedFirst,
        later,
        laterEvent,
        tiedSecond,
    ])

    #expect(sorted.map(\.displayTitle) == [
        "tied-first",
        "tied-second",
        "later-event",
        "display-one",
        "later",
    ])
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
}

private func subtitleScreenshotTestItem(
    displayTitle: String,
    startMilliseconds: Int = 1_000,
    endMilliseconds: Int = 2_000,
    cueDisplayOrder: Int?,
    cueEventIndex: Int?
) -> SubtitleScreenshotExportItem {
    SubtitleScreenshotExportItem(
        displayTitle: displayTitle,
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/video.ass",
        subtitleFormat: .ass,
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        cueDisplayOrder: cueDisplayOrder,
        cueEventIndex: cueEventIndex,
        textLines: [displayTitle]
    )
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
