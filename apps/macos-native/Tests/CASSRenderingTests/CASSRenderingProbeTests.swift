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

    func testActiveEventSetWindowPreservesBoundariesForAnimatedAndOverlappingEvents() throws {
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
        Dialogue: 0,0:00:01.00,0:00:05.00,Default,,0,0,0,,{\\fad(200,200)}Animated Fad Line
        Dialogue: 0,0:00:02.50,0:00:04.00,Default,,0,0,0,,Overlay Mid Line
        Dialogue: 0,0:00:06.00,0:00:08.00,Default,,0,0,0,,{\\move(100,300,220,300)}Animated Move Line
        Dialogue: 0,0:00:09.00,0:00:11.00,Default,,0,0,0,,{\\k50}Karaoke Line
        Dialogue: 0,0:00:12.00,0:00:14.00,Default,,0,0,0,Banner;20;0;0,Effect Event Line
        """

        let session = try SFXASSRendererSession(
            assScript: script,
            sourceIdentifier: "active-set-window.ass",
            frameWidth: 640,
            frameHeight: 360
        )
        defer { session.close() }

        // Blank region before first cue: both windows match 0..<1000.
        let preOutput = try session.renderCroppedImage(atTimestampMilliseconds: 500)
        XCTAssertEqual(preOutput.unchangedFromMilliseconds, 0)
        XCTAssertEqual(preOutput.unchangedUntilMilliseconds, 1_000)
        XCTAssertEqual(preOutput.activeEventSetFromMilliseconds, 0)
        XCTAssertEqual(preOutput.activeEventSetUntilMilliseconds, 1_000)

        // Single animated \fad cue before second cue begins: unchanged shrinks to 1ms,
        // while activeEventSet stops right at the second cue's Start (2500ms).
        let fadBeforeOverlap = try session.renderCroppedImage(atTimestampMilliseconds: 1_500)
        XCTAssertEqual(fadBeforeOverlap.unchangedFromMilliseconds, 1_500)
        XCTAssertEqual(fadBeforeOverlap.unchangedUntilMilliseconds, 1_501)
        XCTAssertEqual(fadBeforeOverlap.activeEventSetFromMilliseconds, 1_000)
        XCTAssertEqual(fadBeforeOverlap.activeEventSetUntilMilliseconds, 2_500)

        // During overlap [2500, 4000): activeEventSet matches 2500..<4000 while unchanged stays 1ms.
        let duringOverlap = try session.renderCroppedImage(atTimestampMilliseconds: 3_000)
        XCTAssertEqual(duringOverlap.unchangedFromMilliseconds, 3_000)
        XCTAssertEqual(duringOverlap.unchangedUntilMilliseconds, 3_001)
        XCTAssertEqual(duringOverlap.activeEventSetFromMilliseconds, 2_500)
        XCTAssertEqual(duringOverlap.activeEventSetUntilMilliseconds, 4_000)

        // After second cue ends [4000, 5000): lower bound clamped by past End (4000).
        let afterOverlap = try session.renderCroppedImage(atTimestampMilliseconds: 4_300)
        XCTAssertEqual(afterOverlap.unchangedFromMilliseconds, 4_300)
        XCTAssertEqual(afterOverlap.unchangedUntilMilliseconds, 4_301)
        XCTAssertEqual(afterOverlap.activeEventSetFromMilliseconds, 4_000)
        XCTAssertEqual(afterOverlap.activeEventSetUntilMilliseconds, 5_000)

        // Blank gap between cues 5000..<6000.
        let gapOutput = try session.renderCroppedImage(atTimestampMilliseconds: 5_200)
        XCTAssertEqual(gapOutput.unchangedFromMilliseconds, 5_000)
        XCTAssertEqual(gapOutput.unchangedUntilMilliseconds, 6_000)
        XCTAssertEqual(gapOutput.activeEventSetFromMilliseconds, 5_000)
        XCTAssertEqual(gapOutput.activeEventSetUntilMilliseconds, 6_000)

        // \move cue [6000, 8000)
        let moveOutput = try session.renderCroppedImage(atTimestampMilliseconds: 6_500)
        XCTAssertEqual(moveOutput.unchangedFromMilliseconds, 6_500)
        XCTAssertEqual(moveOutput.unchangedUntilMilliseconds, 6_501)
        XCTAssertEqual(moveOutput.activeEventSetFromMilliseconds, 6_000)
        XCTAssertEqual(moveOutput.activeEventSetUntilMilliseconds, 8_000)

        // \k cue [9000, 11000) spans across 5000ms window boundary at 10000ms:
        // [5000, 10000) clamps upper bound to 10000, [10000, 15000) clamps lower bound to 10000.
        let karaokeFirstHalf = try session.renderCroppedImage(atTimestampMilliseconds: 9_200)
        XCTAssertEqual(karaokeFirstHalf.unchangedFromMilliseconds, 9_200)
        XCTAssertEqual(karaokeFirstHalf.unchangedUntilMilliseconds, 9_201)
        XCTAssertEqual(karaokeFirstHalf.activeEventSetFromMilliseconds, 9_000)
        XCTAssertEqual(karaokeFirstHalf.activeEventSetUntilMilliseconds, 10_000)

        let karaokeSecondHalf = try session.renderCroppedImage(atTimestampMilliseconds: 10_200)
        XCTAssertEqual(karaokeSecondHalf.unchangedFromMilliseconds, 10_200)
        XCTAssertEqual(karaokeSecondHalf.unchangedUntilMilliseconds, 10_201)
        XCTAssertEqual(karaokeSecondHalf.activeEventSetFromMilliseconds, 10_000)
        XCTAssertEqual(karaokeSecondHalf.activeEventSetUntilMilliseconds, 11_000)

        // Non-empty Effect event [12000, 14000)
        let effectOutput = try session.renderCroppedImage(atTimestampMilliseconds: 12_500)
        XCTAssertEqual(effectOutput.unchangedFromMilliseconds, 12_500)
        XCTAssertEqual(effectOutput.unchangedUntilMilliseconds, 12_501)
        XCTAssertEqual(effectOutput.activeEventSetFromMilliseconds, 12_000)
        XCTAssertEqual(effectOutput.activeEventSetUntilMilliseconds, 14_000)
    }

    func testActiveEventSetWindowClampsToLoadedWindowAndPreservesChangedFalseCacheHit() throws {
        let header = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 640
        PlayResY: 360

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,34,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        """

        var requestedWindows: [(start: Int, end: Int)] = []
        let longAnimatedDialogue = "Dialogue: 0,0:00:01.00,0:10:00.00,Default,,0,0,0,,{\\fad(200,200)}Long Spanning Cue"
        let staticSpanningDialogue = "Dialogue: 0,0:00:08.00,0:00:20.00,Default,,0,0,0,,Static Window Two Line"

        let session = try SFXASSRendererSession(
            assHeader: header,
            sourceIdentifier: "windowed-active-set.ass",
            frameWidth: 640,
            frameHeight: 360,
            windowEventLinesProvider: { windowStart, windowEnd, _ in
                requestedWindows.append((windowStart, windowEnd))
                if windowStart == 0 {
                    return [longAnimatedDialogue]
                }
                return [staticSpanningDialogue]
            }
        )
        defer { session.close() }

        // First window [0, 5000) contains an animated event extending past 5000ms; activeEventSet must clamp to 1000..<5000.
        let firstWindowOutput = try session.renderCroppedImage(atTimestampMilliseconds: 2_000)
        let firstWindow = try XCTUnwrap(requestedWindows.first)
        XCTAssertEqual(firstWindow.start, 0)
        XCTAssertEqual(firstWindow.end, 5_000)
        XCTAssertEqual(firstWindowOutput.unchangedFromMilliseconds, 2_000)
        XCTAssertEqual(firstWindowOutput.unchangedUntilMilliseconds, 2_001)
        XCTAssertEqual(firstWindowOutput.activeEventSetFromMilliseconds, 1_000)
        XCTAssertEqual(firstWindowOutput.activeEventSetUntilMilliseconds, 5_000)

        // Jump to window [10000, 15000): spanning cue [8000, 20000) must clamp to [10000, 15000) on both
        // initial render and changed == false fast cache hit.
        let secondWindowInitial = try session.renderCroppedImage(atTimestampMilliseconds: 12_000)
        XCTAssertTrue(secondWindowInitial.changed)
        XCTAssertEqual(secondWindowInitial.unchangedFromMilliseconds, 10_000)
        XCTAssertEqual(secondWindowInitial.unchangedUntilMilliseconds, 15_000)
        XCTAssertEqual(secondWindowInitial.activeEventSetFromMilliseconds, 10_000)
        XCTAssertEqual(secondWindowInitial.activeEventSetUntilMilliseconds, 15_000)

        let cachedFastHit = try session.renderCroppedImage(atTimestampMilliseconds: 12_250)
        XCTAssertFalse(cachedFastHit.changed)
        XCTAssertEqual(cachedFastHit.unchangedFromMilliseconds, 10_000)
        XCTAssertEqual(cachedFastHit.unchangedUntilMilliseconds, 15_000)
        XCTAssertEqual(cachedFastHit.activeEventSetFromMilliseconds, 10_000)
        XCTAssertEqual(cachedFastHit.activeEventSetUntilMilliseconds, 15_000)

        // Frame resize must invalidate cached bounds and recompute accurate activeEventSet on next render.
        XCTAssertTrue(session.updateFrameWidth(320, frameHeight: 180))
        let afterResize = try session.renderCroppedImage(atTimestampMilliseconds: 12_300)
        XCTAssertTrue(afterResize.changed)
        XCTAssertEqual(afterResize.activeEventSetFromMilliseconds, 10_000)
        XCTAssertEqual(afterResize.activeEventSetUntilMilliseconds, 15_000)
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
