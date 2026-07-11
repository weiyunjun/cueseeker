import Foundation
import CoreGraphics
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
func srtSubtitleScreenshotKeepsVideoOrientationAndBottomAnchorsSubtitle() throws {
    let width = 320
    let height = 180
    let frameImage = try makeOrientationTestImage(width: width, height: height)
    let item = SubtitleScreenshotExportItem(
        displayTitle: "SRT Orientation",
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/video.srt",
        subtitleFormat: .srt,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        textLines: ["Test"]
    )

    let rendered = try SubtitleScreenshotExporter._renderSimpleSubtitleFrameForTesting(
        item: item,
        frameImage: frameImage
    )

    let topPixel = try pixel(in: rendered.image, x: 12, y: 12)
    let bottomPixel = try pixel(in: rendered.image, x: 12, y: height - 12)
    #expect(topPixel.red > 220)
    #expect(topPixel.green < 40)
    #expect(topPixel.blue < 40)
    #expect(bottomPixel.red < 40)
    #expect(bottomPixel.green < 40)
    #expect(bottomPixel.blue > 220)

    let band = try #require(rendered.subtitleBands.first)
    #expect(band.y1 > height / 2)
    #expect(band.y2 < height)
    #expect(try darkPixelCount(in: rendered.image, yRange: 0..<(height / 3)) == 0)
    #expect(try darkPixelCount(in: rendered.image, yRange: (height * 2 / 3)..<height) > 100)
}

private struct RGBAPixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
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

private func makeOrientationTestImage(width: Int, height: Int) throws -> CGImage {
    var data = Data(count: width * height * 4)
    data.withUnsafeMutableBytes { rawBuffer in
        let bytes = rawBuffer.bindMemory(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let offset = ((y * width) + x) * 4
                if y < height / 2 {
                    bytes[offset] = 255
                    bytes[offset + 1] = 0
                    bytes[offset + 2] = 0
                    bytes[offset + 3] = 255
                } else {
                    bytes[offset] = 0
                    bytes[offset + 1] = 0
                    bytes[offset + 2] = 255
                    bytes[offset + 3] = 255
                }
            }
        }
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let provider = try #require(CGDataProvider(data: data as CFData))
    return try #require(CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ))
}

private func pixel(in image: CGImage, x: Int, y: Int) throws -> RGBAPixel {
    let data = try imageData(image)
    let offset = (y * image.bytesPerRow) + (x * 4)
    return RGBAPixel(
        red: data[offset],
        green: data[offset + 1],
        blue: data[offset + 2],
        alpha: data[offset + 3]
    )
}

private func darkPixelCount(in image: CGImage, yRange: Range<Int>) throws -> Int {
    let data = try imageData(image)
    var count = 0
    for y in yRange {
        for x in 0..<image.width {
            let offset = (y * image.bytesPerRow) + (x * 4)
            if data[offset] < 100,
               data[offset + 1] < 100,
               data[offset + 2] < 100,
               data[offset + 3] > 180 {
                count += 1
            }
        }
    }
    return count
}

private func imageData(_ image: CGImage) throws -> Data {
    let providerData = try #require(image.dataProvider?.data)
    return providerData as Data
}
