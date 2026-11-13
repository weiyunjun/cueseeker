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

    func testUTF16LEASSDecodesToUTF8BeforeRenderingFromMemory() throws {
        let script = """
        [Script Info]
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,32,&H00FFFFFF,&H000000FF,&H80000000,&H40000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,20,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Rendered UTF-16 subtitle
        """
        var data = Data([0xFF, 0xFE])
        data.append(try XCTUnwrap(script.data(using: .utf16LittleEndian)))
        let decoded = try SubtitleTextDecoder.decode(data, format: .ass)
        let session = try SFXASSRendererSession(
            assScript: decoded,
            sourceIdentifier: "utf16-memory",
            frameWidth: 640,
            frameHeight: 360
        )

        let output = try session.renderCroppedImage(atTimestampMilliseconds: 1_500)

        XCTAssertEqual(Data(decoded.utf8), Data(script.utf8))
        XCTAssertGreaterThan(output.imageCount, 0)
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

        XCTAssertThrowsError(try session.renderCroppedImage(atTimestampMilliseconds: 1_500)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, SFXASSRenderingErrorDomain)
            XCTAssertEqual(nsError.code, SFXASSRenderingErrorCode.renderFailed.rawValue)
        }
    }

    func testEmptyFontsSectionAndCommentsReusePooledEngineWhileEmbeddedFontDataIsolates() throws {
        SFXASSRenderer.resetFontEnvironmentPoolForTesting()
        defer { SFXASSRenderer.resetFontEnvironmentPoolForTesting() }

        SFXASSRenderer.warmUpFontEnvironment()
        XCTAssertEqual(SFXASSRenderer.engineInitializationCountForTesting(), 1)

        let bomAndEmptyFontsBeforeEvents = "\u{feff}" + """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,34,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [fonts]
        ; comment inside empty fonts section
        !: legacy metadata comment
          
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:00.10,0:00:02.00,Default,,0,0,0,,Empty Fonts Test

        [Fonts]
        ; trailing placeholder section
        """

        let session1 = try SFXASSRendererSession(
            assScript: bomAndEmptyFontsBeforeEvents,
            sourceIdentifier: "empty-fonts-test.ass",
            frameWidth: 640,
            frameHeight: 360
        )
        let frame1 = try session1.renderFrame(atTimestampMilliseconds: 500)
        XCTAssertGreaterThan(frame1.imageCount, 0)
        XCTAssertGreaterThan(nonTransparentPixelCount(in: frame1.rgbaData), 0)
        session1.close()
        XCTAssertEqual(SFXASSRenderer.engineInitializationCountForTesting(), 1)

        let embeddedFontsScript = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,34,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [Fonts]
        fontname: EmbeddedDummy.ttf
        !!

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:00.10,0:00:02.00,Default,,0,0,0,,Embedded Fonts Test
        """

        let session2 = try SFXASSRendererSession(
            assScript: embeddedFontsScript,
            sourceIdentifier: "embedded-fonts-test.ass",
            frameWidth: 640,
            frameHeight: 360
        )
        let frame2 = try session2.renderFrame(atTimestampMilliseconds: 500)
        XCTAssertGreaterThan(frame2.imageCount, 0)
        session2.close()
        XCTAssertEqual(SFXASSRenderer.engineInitializationCountForTesting(), 2)

        let session3 = try SFXASSRendererSession(
            assScript: bomAndEmptyFontsBeforeEvents,
            sourceIdentifier: "empty-fonts-after-embedded.ass",
            frameWidth: 640,
            frameHeight: 360
        )
        let frame3 = try session3.renderFrame(atTimestampMilliseconds: 500)
        XCTAssertGreaterThan(frame3.imageCount, 0)
        session3.close()
        XCTAssertEqual(SFXASSRenderer.engineInitializationCountForTesting(), 2)
    }

    func testInvalidateFontEnvironmentPoolRetiresBorrowedSessionAndRebuildsNextGeneration() throws {
        SFXASSRenderer.resetFontEnvironmentPoolForTesting()
        defer { SFXASSRenderer.resetFontEnvironmentPoolForTesting() }

        SFXASSRenderer.warmUpFontEnvironment()
        XCTAssertEqual(SFXASSRenderer.engineInitializationCountForTesting(), 1)

        let script = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,34,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:00.10,0:00:02.00,Default,,0,0,0,,Pool Generation Test
        """

        let session1 = try SFXASSRendererSession(
            assScript: script,
            sourceIdentifier: "pool-gen-1.ass",
            frameWidth: 640,
            frameHeight: 360
        )

        SFXASSRenderer.invalidateFontEnvironmentPool()

        // Active borrowed session continues rendering smoothly.
        let frame1 = try session1.renderFrame(atTimestampMilliseconds: 500)
        XCTAssertGreaterThan(frame1.imageCount, 0)
        XCTAssertGreaterThan(nonTransparentPixelCount(in: frame1.rgbaData), 0)
        XCTAssertEqual(SFXASSRenderer.engineInitializationCountForTesting(), 1)

        // Closing stale session destroys it without returning to pool; next checkout creates +1 new-gen engine.
        session1.close()

        let session2 = try SFXASSRendererSession(
            assScript: script,
            sourceIdentifier: "pool-gen-2.ass",
            frameWidth: 1280,
            frameHeight: 720
        )
        session2.updateFrameWidth(640, frameHeight: 360)
        let frame2 = try session2.renderFrame(atTimestampMilliseconds: 500)
        XCTAssertEqual(frame2.width, 640)
        XCTAssertEqual(frame2.height, 360)
        XCTAssertGreaterThan(frame2.imageCount, 0)
        XCTAssertEqual(SFXASSRenderer.engineInitializationCountForTesting(), 2)
        session2.close()

        // Following checkout reuses the newly pooled generation engine with zero extra initializations.
        let session3 = try SFXASSRendererSession(
            assScript: script,
            sourceIdentifier: "pool-gen-3.ass",
            frameWidth: 640,
            frameHeight: 360
        )
        let frame3 = try session3.renderFrame(atTimestampMilliseconds: 500)
        XCTAssertGreaterThan(frame3.imageCount, 0)
        XCTAssertEqual(SFXASSRenderer.engineInitializationCountForTesting(), 2)
        session3.close()
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
