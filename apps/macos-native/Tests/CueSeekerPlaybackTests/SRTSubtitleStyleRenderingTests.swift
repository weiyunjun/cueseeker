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
func srtStyleSizeIsTheLineHeightAtTheReferenceHeightAndScales() throws {
    // Helvetica's ascent plus descent is one em and PingFang's 1.4 ems, and
    // CoreText lays Helvetica out in a taller frame; the line is 55 either way.
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

        #expect(abs(height720 - 55) < 1.5)
        #expect(abs(height1080 / height720 - 1.5) < 0.03)
    }
}

@Test
func srtStyleAlignsTheFirstCueToItsMargins() throws {
    let canvas = CGSize(width: 1_280, height: 720)
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
    #expect(abs(rightBottom.maxX - (1_280 - 25)) < 1.5)
    #expect(abs(rightBottom.maxY - (720 - 22)) < 1.5)

    let centered = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [cue],
        canvasSize: canvas,
        style: srtBareStyle { $0.verticalAlignment = .center }
    )?.placements[0])
    #expect(abs(centered.midX - 640) < 1.5)
    #expect(abs(centered.midY - 360) < 1.5)
}

@Test
func srtStyleStacksDownwardForTopAndUpwardForCenter() throws {
    let canvas = CGSize(width: 1_280, height: 720)
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
    #expect(abs(centerFirst.midY - 360) < 1.5)
    #expect(abs(centerSecond.maxY - centerFirst.minY) < 0.001)
}

@Test
func srtStyleLineSpacingAddsOnlyBetweenLines() throws {
    let canvas = CGSize(width: 1_280, height: 720)
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
    let canvas = CGSize(width: 1_280, height: 720)
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

    #expect(italic.width > upright.width + 5)
}

@Test
func srtStyleOpaqueBoxPaintsTheBackgroundColorAroundTheText() throws {
    let canvas = CGSize(width: 640, height: 360)
    let cue = [srtStyleTestCue(0, text: "Box")]
    let style = srtBareStyle {
        $0.borderType = .opaqueBox
        $0.backgroundColor = SRTSubtitleStyle.Color(red: 1, green: 0, blue: 0, alpha: 1)
    }
    let layout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cue,
        canvasSize: canvas,
        style: style
    ))
    let bounds = try #require(layout.placements[0])
    let image = try #require(SRTSubtitleRenderer.image(layout: layout, atMilliseconds: 1_000))

    // Just inside the box's left edge, where the padding keeps glyphs away.
    let pixel = try #require(srtStyleTestPixel(
        image,
        x: Int(bounds.minX) + 1,
        y: Int(bounds.midY)
    ))
    #expect(pixel.red > 200 && pixel.green < 50 && pixel.alpha > 200)
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
func srtStyleRoundTripsThroughJSON() throws {
    var style = SRTSubtitleStyle()
    style.fontName = "HiraginoSans-W6"
    style.borderType = .backgroundBox
    style.verticalAlignment = .top
    style.textColor = SRTSubtitleStyle.Color(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)

    let data = try JSONEncoder().encode(style)
    #expect(try JSONDecoder().decode(SRTSubtitleStyle.self, from: data) == style)
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
