import CASSRendering
import Foundation
import XCTest

final class CASSRenderingProbeTests: XCTestCase {
    func testComplexASSFrameRendersToRGBAAndPNG() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "complex-effects", withExtension: "ass"))

        let output = try SFXASSRenderer.renderASSFile(
            atPath: fixtureURL.path,
            frameWidth: 640,
            frameHeight: 360,
            timestampMilliseconds: 1_500,
            fontsDirectory: nil
        )

        XCTAssertEqual(output.width, 640)
        XCTAssertEqual(output.height, 360)
        XCTAssertEqual(output.stride, 2_560)
        XCTAssertGreaterThan(output.imageCount, 0)
        XCTAssertGreaterThan(nonTransparentPixelCount(in: output.rgbaData), 0)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cass-rendering-\(UUID().uuidString)")
            .appendingPathExtension("png")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        try output.writePNG(toPath: outputURL.path)
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = try XCTUnwrap(attributes[.size] as? UInt64)
        XCTAssertGreaterThan(fileSize, 0)
    }

    func testShortAndZeroDurationFXFramesDoNotCrashRenderer() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "complex-effects", withExtension: "ass"))

        let shortEffectOutput = try SFXASSRenderer.renderASSFile(
            atPath: fixtureURL.path,
            frameWidth: 640,
            frameHeight: 360,
            timestampMilliseconds: 1_220,
            fontsDirectory: nil
        )
        XCTAssertGreaterThan(shortEffectOutput.imageCount, 0)

        let zeroDurationTimestampOutput = try SFXASSRenderer.renderASSFile(
            atPath: fixtureURL.path,
            frameWidth: 640,
            frameHeight: 360,
            timestampMilliseconds: 1_500,
            fontsDirectory: nil
        )
        XCTAssertGreaterThan(zeroDurationTimestampOutput.imageCount, 0)
    }

    private func nonTransparentPixelCount(in data: Data) -> Int {
        var count = 0
        var index = 3
        while index < data.count {
            if data[index] > 0 {
                count += 1
            }
            index += 4
        }
        return count
    }
}
