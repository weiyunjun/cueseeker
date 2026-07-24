import CASSRendering
import CueSeekerCore
import Foundation
import XCTest

final class CASSRenderingProbeTests: XCTestCase {
    func testComplexASSFrameRendersToRGBAAndPNG() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "complex-effects", withExtension: "ass"))

        let output = try SFXASSRenderer.renderASSFile(
            atPath: fixtureURL.path,
            frameWidth: 640,
            frameHeight: 360,
            timestampMilliseconds: 1_500
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
            timestampMilliseconds: 1_220
        )
        XCTAssertGreaterThan(shortEffectOutput.imageCount, 0)

        let zeroDurationTimestampOutput = try SFXASSRenderer.renderASSFile(
            atPath: fixtureURL.path,
            frameWidth: 640,
            frameHeight: 360,
            timestampMilliseconds: 1_500
        )
        XCTAssertGreaterThan(zeroDurationTimestampOutput.imageCount, 0)
    }

    func testRendererSessionReusesLoadedASSFileAcrossTimestamps() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "complex-effects", withExtension: "ass"))
        let session = try SFXASSRendererSession(
            assFileAtPath: fixtureURL.path,
            frameWidth: 640,
            frameHeight: 360
        )

        let firstFrame = try session.renderFrame(atTimestampMilliseconds: 1_220)
        let secondFrame = try session.renderFrame(atTimestampMilliseconds: 1_500)

        XCTAssertEqual(firstFrame.width, 640)
        XCTAssertEqual(secondFrame.height, 360)
        XCTAssertGreaterThan(firstFrame.imageCount, 0)
        XCTAssertGreaterThan(secondFrame.imageCount, 0)
    }

    func testRendererSessionProducesCroppedOutput() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "complex-effects", withExtension: "ass"))
        let session = try SFXASSRendererSession(
            assFileAtPath: fixtureURL.path,
            frameWidth: 640,
            frameHeight: 360
        )

        let output = try session.renderCroppedImage(atTimestampMilliseconds: 1_500)

        XCTAssertGreaterThan(output.imageCount, 0)
        XCTAssertGreaterThan(output.width, 0)
        XCTAssertGreaterThan(output.height, 0)
        XCTAssertLessThanOrEqual(output.width, output.frameWidth)
        XCTAssertLessThanOrEqual(output.height, output.frameHeight)
        XCTAssertEqual(output.stride, output.width * 4)
        XCTAssertEqual(output.rgbaData.count, output.stride * output.height)
        XCTAssertGreaterThan(nonTransparentPixelCount(in: output.rgbaData), 0)
    }

    func testRendererSessionSkipsCroppedPayloadWhenStaticFrameIsUnchanged() throws {
        let script = """
        [Script Info]
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default, Helvetica, 32, &H00FFFFFF, &H000000FF, &H80000000, &H40000000, 0, 0, 0, 0, 100, 100, 0, 0, 1, 2, 1, 2, 20, 20, 20, 1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:05.00,Default,,0,0,0,,Static subtitle
        """
        let session = try SFXASSRendererSession(
            assScript: script,
            sourceIdentifier: "static-subtitle",
            frameWidth: 640,
            frameHeight: 360
        )

        let firstOutput = try session.renderCroppedImage(atTimestampMilliseconds: 1_500)
        let unchangedOutput = try session.renderCroppedImage(atTimestampMilliseconds: 1_533)

        XCTAssertTrue(firstOutput.changed)
        XCTAssertGreaterThan(firstOutput.imageCount, 0)
        XCTAssertGreaterThan(firstOutput.rgbaData.count, 0)
        XCTAssertFalse(unchangedOutput.changed)
        XCTAssertEqual(unchangedOutput.imageCount, 0)
        XCTAssertEqual(unchangedOutput.width, 0)
        XCTAssertEqual(unchangedOutput.height, 0)
        XCTAssertEqual(unchangedOutput.rgbaData.count, 0)
    }

    func testRendererSessionCanLoadASSFromMemory() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "complex-effects", withExtension: "ass"))
        let script = try String(contentsOf: fixtureURL)
        let session = try SFXASSRendererSession(
            assScript: script,
            sourceIdentifier: "complex-effects-memory",
            frameWidth: 640,
            frameHeight: 360
        )

        let output = try session.renderCroppedImage(atTimestampMilliseconds: 1_500)

        XCTAssertGreaterThan(output.imageCount, 0)
        XCTAssertGreaterThan(output.width, 0)
        XCTAssertGreaterThan(nonTransparentPixelCount(in: output.rgbaData), 0)
    }

    func testConvertedSRTTrackRendersThroughLibass() throws {
        let script = SRTASSConverter.convert(
            """
            1
            00:00:01,000 --> 00:00:03,000
            First simultaneous line

            2
            00:00:01,000 --> 00:00:03,000
            Second simultaneous line
            """
        )
        let session = try SFXASSRendererSession(
            assScript: script,
            sourceIdentifier: "converted-srt",
            frameWidth: 640,
            frameHeight: 360
        )

        let output = try session.renderCroppedImage(
            atTimestampMilliseconds: 1_500
        )

        XCTAssertGreaterThan(output.imageCount, 0)
        XCTAssertGreaterThan(output.width, 0)
        XCTAssertGreaterThan(nonTransparentPixelCount(in: output.rgbaData), 0)
    }

    func testRendererSessionCloseIsIdempotentAndPreventsFurtherRendering() throws {
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "complex-effects", withExtension: "ass"))
        let session = try SFXASSRendererSession(
            assFileAtPath: fixtureURL.path,
            frameWidth: 640,
            frameHeight: 360
        )

        session.close()
        session.close()

        XCTAssertThrowsError(try session.renderImages(atTimestampMilliseconds: 1_500)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, SFXASSRenderingErrorDomain)
            XCTAssertEqual(nsError.code, SFXASSRenderingErrorCode.renderFailed.rawValue)
        }
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
