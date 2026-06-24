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
func subtitleScreenshotCollageRequiresOneVideoAndAtMostFiftyItems() {
    let baseItem = SubtitleScreenshotExportItem(
        displayTitle: "Show - 01",
        videoPath: "/tmp/video.mkv",
        subtitlePath: "/tmp/video.ass",
        subtitleFormat: .ass,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        textLines: ["Line"]
    )
    let sameVideo = SubtitleScreenshotExportItem(
        displayTitle: "Show - 01",
        videoPath: "/tmp/./video.mkv",
        subtitlePath: "/tmp/video.ass",
        subtitleFormat: .ass,
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        textLines: ["Line"]
    )
    let otherVideo = SubtitleScreenshotExportItem(
        displayTitle: "Show - 02",
        videoPath: "/tmp/other.mkv",
        subtitlePath: "/tmp/other.ass",
        subtitleFormat: .ass,
        startMilliseconds: 5_000,
        endMilliseconds: 6_000,
        textLines: ["Line"]
    )

    #expect(SubtitleScreenshotExporter.canExportCollage([baseItem]))
    #expect(SubtitleScreenshotExporter.canExportCollage([baseItem, sameVideo]))
    #expect(!SubtitleScreenshotExporter.canExportCollage([baseItem, otherVideo]))
    #expect(!SubtitleScreenshotExporter.canExportCollage(Array(repeating: baseItem, count: 51)))
}
