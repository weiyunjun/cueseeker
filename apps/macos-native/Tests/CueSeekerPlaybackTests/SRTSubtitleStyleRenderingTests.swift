import AppKit
import CoreText
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerPlayback

private func srtStyleTestCue(
    _ ordinal: Int,
    start: Int = 0,
    end: Int = 5_000,
    text: String
) -> PlaybackSubtitleCue {
    PlaybackSubtitleCue(
        sourceOrdinal: ordinal,
        startMilliseconds: start,
        endMilliseconds: end,
        text: text
    )
}

/// A style with no outline, so a placement is exactly the text's lines.
private func srtBareStyle(_ configure: (inout SRTSubtitleStyle) -> Void = { _ in }) -> SRTSubtitleStyle {
    var style = SRTSubtitleStyle()
    style.fontName = "Helvetica"
    style.outlineWidth = 0
    style.lineSpacing = 0
    configure(&style)
    return style
}

@Test
func srtStyleSizeIsPointSizeAt1080pReferenceHeightAndScales() throws {
    for fontName in ["Helvetica", "PingFangSC-Regular"] {
        let style = srtBareStyle { $0.fontName = fontName }
        let layout720 = try #require(SRTSubtitleRenderer.makeLayout(
            cues: [srtStyleTestCue(0, text: "Line")],
            canvasSize: CGSize(width: 1_280, height: 720),
            style: style
        ))
        let layout1080 = try #require(SRTSubtitleRenderer.makeLayout(
            cues: [srtStyleTestCue(0, text: "Line")],
            canvasSize: CGSize(width: 1_920, height: 1_080),
            style: style
        ))
        let height720 = try #require(layout720.placements[0]).height
        let height1080 = try #require(layout1080.placements[0]).height

        let ctFont = CTFontCreateWithName(fontName as CFString, 28, nil)
        let expected1080Height = CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont)
        #expect(abs(height1080 - expected1080Height) < 1.5)
        #expect(abs(height1080 / height720 - 1.5) < 0.03)
    }
}

@Test
func srtStyleAlignsTheFirstCueToItsMargins() throws {
    let canvas = CGSize(width: 1_920, height: 1_080)
    let cue = srtStyleTestCue(0, text: "Aligned")

    let leftTop = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [cue],
        canvasSize: canvas,
        style: srtBareStyle {
            $0.horizontalAlignment = .left
            $0.verticalAlignment = .top
        }
    )?.placements[0])
    #expect(abs(leftTop.minX - 25) < 1.5)
    #expect(abs(leftTop.minY - 22) < 1.5)

    let rightBottom = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [cue],
        canvasSize: canvas,
        style: srtBareStyle {
            $0.horizontalAlignment = .right
            $0.verticalAlignment = .bottom
        }
    )?.placements[0])
    #expect(abs(rightBottom.maxX - (1_920 - 25)) < 1.5)
    #expect(abs(rightBottom.maxY - (1_080 - 22)) < 1.5)

    let centered = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [cue],
        canvasSize: canvas,
        style: srtBareStyle { $0.verticalAlignment = .center }
    )?.placements[0])
    #expect(abs(centered.midX - 960) < 1.5)
    #expect(abs(centered.midY - 540) < 1.5)
}

@Test
func srtStyleStacksDownwardForTopAndUpwardForCenter() throws {
    let canvas = CGSize(width: 1_920, height: 1_080)
    let cues = [
        srtStyleTestCue(0, start: 0, end: 5_000, text: "First"),
        srtStyleTestCue(1, start: 1_000, end: 5_000, text: "Second")
    ]

    let top = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cues,
        canvasSize: canvas,
        style: srtBareStyle { $0.verticalAlignment = .top }
    ))
    let topFirst = try #require(top.placements[0])
    let topSecond = try #require(top.placements[1])
    #expect(abs(topSecond.minY - topFirst.maxY) < 0.001)

    let center = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cues,
        canvasSize: canvas,
        style: srtBareStyle { $0.verticalAlignment = .center }
    ))
    let centerFirst = try #require(center.placements[0])
    let centerSecond = try #require(center.placements[1])
    #expect(abs(centerFirst.midY - 540) < 1.5)
    #expect(abs(centerSecond.maxY - centerFirst.minY) < 0.001)
}

@Test
func srtStyleLineSpacingAddsOnlyBetweenLines() throws {
    let canvas = CGSize(width: 1_920, height: 1_080)
    let twoLines = [srtStyleTestCue(0, text: "One\nTwo")]
    let oneLine = [srtStyleTestCue(0, text: "One")]

    let tight = try #require(SRTSubtitleRenderer.makeLayout(
        cues: twoLines,
        canvasSize: canvas,
        style: srtBareStyle()
    )?.placements[0])
    let spaced = try #require(SRTSubtitleRenderer.makeLayout(
        cues: twoLines,
        canvasSize: canvas,
        style: srtBareStyle { $0.lineSpacing = 10 }
    )?.placements[0])
    let spacedSingle = try #require(SRTSubtitleRenderer.makeLayout(
        cues: oneLine,
        canvasSize: canvas,
        style: srtBareStyle { $0.lineSpacing = 10 }
    )?.placements[0])
    let tightSingle = try #require(SRTSubtitleRenderer.makeLayout(
        cues: oneLine,
        canvasSize: canvas,
        style: srtBareStyle()
    )?.placements[0])

    #expect(abs(spaced.height - tight.height - 10) < 1.5)
    #expect(abs(spacedSingle.height - tightSingle.height) < 0.001)
}

@Test
func srtStyleSlantsAFaceThatHasNoItalic() throws {
    let canvas = CGSize(width: 1_920, height: 1_080)
    let cue = [srtStyleTestCue(0, text: "日本語")]

    let upright = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cue,
        canvasSize: canvas,
        style: srtBareStyle { $0.fontName = "HiraginoSans-W3" }
    )?.placements[0])
    let italic = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cue,
        canvasSize: canvas,
        style: srtBareStyle {
            $0.fontName = "HiraginoSans-W3"
            $0.isItalic = true
        }
    )?.placements[0])

    #expect(italic.width > upright.width + 2)
}

@Test
func srtStyleBackgroundBoxPaintsTheBackgroundColorAndShadowAroundTheText() throws {
    let canvas = CGSize(width: 640, height: 360)
    let cue = [srtStyleTestCue(0, text: "Box")]
    let style = srtBareStyle {
        $0.borderType = .backgroundBox
        $0.backgroundColor = SRTSubtitleStyle.Color(red: 1, green: 0, blue: 0, alpha: 1)
        $0.shadowColor = SRTSubtitleStyle.Color(red: 0, green: 0, blue: 1, alpha: 1)
        $0.shadowOffset = 9
    }
    let layout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cue,
        canvasSize: canvas,
        style: style
    ))
    let bounds = try #require(layout.placements[0])
    let image = try #require(SRTSubtitleRenderer.image(layout: layout, atMilliseconds: 1_000))

    // Just inside the box's left edge, where the padding keeps glyphs away.
    let boxPixel = try #require(srtStyleTestPixel(
        image,
        x: Int(bounds.minX) + 1,
        y: Int(bounds.minY) + 1
    ))
    #expect(boxPixel.red > 200 && boxPixel.green < 50 && boxPixel.alpha > 200)

    // Bottom-right corner of the visual bounds carries the box's shadow.
    let shadowPixel = try #require(srtStyleTestPixel(
        image,
        x: Int(bounds.maxX) - 2,
        y: Int(bounds.maxY) - 2
    ))
    #expect(shadowPixel.blue > 200 && shadowPixel.red < 50 && shadowPixel.alpha > 200)
}

@Test
func srtStyleOutlineTypeDrawsNoBackgroundBox() throws {
    let canvas = CGSize(width: 640, height: 360)
    let style = srtBareStyle {
        $0.backgroundColor = SRTSubtitleStyle.Color(red: 1, green: 0, blue: 0, alpha: 1)
    }
    let layout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "Box")],
        canvasSize: canvas,
        style: style
    ))
    let bounds = try #require(layout.placements[0])
    let image = try #require(SRTSubtitleRenderer.image(layout: layout, atMilliseconds: 1_000))

    let pixel = try #require(srtStyleTestPixel(
        image,
        x: Int(bounds.minX),
        y: Int(bounds.minY)
    ))
    #expect(pixel.alpha == 0)
}

@Test
func srtStyleRoundTripsThroughJSONAndMapsLegacyOpaqueBoxToBackgroundBox() throws {
    let defaults = SRTSubtitleStyle()
    #expect(defaults.size == 28)
    #expect(defaults.lineSpacing == 6)
    #expect(defaults.outlineWidth == 2)
    #expect(SRTSubtitleStyle.referenceHeight == 1_080)

    var style = SRTSubtitleStyle()
    style.fontName = "HiraginoSans-W6"
    style.borderType = .backgroundBox
    style.verticalAlignment = .top
    style.textColor = SRTSubtitleStyle.Color(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)

    let data = try JSONEncoder().encode(style)
    #expect(try JSONDecoder().decode(SRTSubtitleStyle.self, from: data) == style)

    let legacyType = try JSONDecoder().decode(
        SRTSubtitleStyle.BorderType.self,
        from: Data("\"opaqueBox\"".utf8)
    )
    #expect(legacyType == .backgroundBox)
}

private func srtStyleTestPixel(
    _ image: CGImage,
    x: Int,
    y: Int
) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
    guard x >= 0, y >= 0, x < image.width, y < image.height,
          let context = CGContext(
              data: nil,
              width: image.width,
              height: image.height,
              bitsPerComponent: 8,
              bytesPerRow: image.width * 4,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else {
        return nil
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let data = context.data else {
        return nil
    }
    // The bitmap's rows run top to bottom, like the placements.
    let offset = (y * image.width + x) * 4
    let pixels = data.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
    return (pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3])
}
