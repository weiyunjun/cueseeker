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
func srtStyleSizeMatchesLibassLineHeightAt1080pAndScales() throws {
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
        let height720 = try #require(layout720.textPlacements[0]).height
        let height1080 = try #require(layout1080.textPlacements[0]).height

        #expect(abs(height1080 - 28) < 0.01)
        #expect(abs(height1080 / height720 - 1.5) < 0.01)
    }

    var pingFangCache = SRTFontCache(lineHeight: 28)
    let pingFangBase = CTFontCreateWithName("PingFangSC-Regular" as CFString, 12, nil)
    let resolvedPingFang = pingFangCache.font(for: pingFangBase, bold: false, italic: false)
    #expect(abs(resolvedPingFang.ascent + resolvedPingFang.descent - 28) < 0.001)
    #expect(abs(CTFontGetSize(resolvedPingFang.font) - 20) < 0.1)
}

@Test
func srtStyleAlignsTheFirstCueToItsMarginsRegardlessOfOutlineBlurAndShadow() throws {
    let canvas = CGSize(width: 1_920, height: 1_080)
    let cue = srtStyleTestCue(0, text: "Aligned")

    for decorated in [false, true] {
        let decorate: (inout SRTSubtitleStyle) -> Void = { style in
            if decorated {
                style.outlineWidth = 4
                style.blur = 5
                style.shadowOffset = 8
            }
        }

        let leftTop = try #require(SRTSubtitleRenderer.makeLayout(
            cues: [cue],
            canvasSize: canvas,
            style: srtBareStyle {
                $0.horizontalAlignment = .left
                $0.verticalAlignment = .top
                decorate(&$0)
            }
        )?.textPlacements[0])
        #expect(abs(leftTop.minX - 25) < 0.01)
        #expect(abs(leftTop.minY - 22) < 0.01)

        let rightBottom = try #require(SRTSubtitleRenderer.makeLayout(
            cues: [cue],
            canvasSize: canvas,
            style: srtBareStyle {
                $0.horizontalAlignment = .right
                $0.verticalAlignment = .bottom
                decorate(&$0)
            }
        )?.textPlacements[0])
        #expect(abs(rightBottom.maxX - (1_920 - 25)) < 0.01)
        #expect(abs(rightBottom.maxY - (1_080 - 22)) < 0.01)

        let centered = try #require(SRTSubtitleRenderer.makeLayout(
            cues: [cue],
            canvasSize: canvas,
            style: srtBareStyle {
                $0.verticalAlignment = .center
                decorate(&$0)
            }
        )?.textPlacements[0])
        #expect(abs(centered.midX - 960) < 0.01)
        #expect(abs(centered.midY - 540) < 0.01)
    }
}

@Test
func srtStyleStacksDownwardForTopAndCenterAndIgnoresShadowAndBlurInCollisionSpacing() throws {
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
    let topFirst = try #require(top.collisionPlacements[0])
    let topSecond = try #require(top.collisionPlacements[1])
    #expect(abs(topSecond.minY - topFirst.maxY) < 0.001)

    let center = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cues,
        canvasSize: canvas,
        style: srtBareStyle { $0.verticalAlignment = .center }
    ))
    let centerFirst = try #require(center.collisionPlacements[0])
    let centerSecond = try #require(center.collisionPlacements[1])
    #expect(abs(centerFirst.midY - 540) < 0.01)
    #expect(abs(centerSecond.minY - centerFirst.maxY) < 0.001)

    let bottomPlain = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cues,
        canvasSize: canvas,
        style: srtBareStyle {
            $0.verticalAlignment = .bottom
            $0.outlineWidth = 2
        }
    ))
    let bottomWithShadowAndBlur = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cues,
        canvasSize: canvas,
        style: srtBareStyle {
            $0.verticalAlignment = .bottom
            $0.outlineWidth = 2
            $0.blur = 6
            $0.shadowOffset = 10
        }
    ))
    #expect(
        abs(
            (bottomPlain.textPlacements[1]!.minY)
                - (bottomWithShadowAndBlur.textPlacements[1]!.minY)
        ) < 0.001
    )
    #expect(
        abs(
            bottomWithShadowAndBlur.collisionPlacements[1]!.maxY
                - bottomWithShadowAndBlur.collisionPlacements[0]!.minY
        ) < 0.001
    )
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
func srtStyleWidensSyntheticBoldGlyphsAndPushesOutlineOutward() throws {
    let canvas = CGSize(width: 640, height: 360)
    let cue = [srtStyleTestCue(0, text: "Hello")]

    let regularLayout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cue,
        canvasSize: canvas,
        style: srtBareStyle {
            $0.fontName = "Monaco"
            $0.size = 96
            $0.outlineWidth = 4
            $0.outlineColor = SRTSubtitleStyle.Color(red: 1, green: 0, blue: 0, alpha: 1)
        }
    ))
    let boldLayout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: cue,
        canvasSize: canvas,
        style: srtBareStyle {
            $0.fontName = "Monaco"
            $0.size = 96
            $0.isBold = true
            $0.outlineWidth = 4
            $0.outlineColor = SRTSubtitleStyle.Color(red: 1, green: 0, blue: 0, alpha: 1)
        }
    ))

    let regularText = try #require(regularLayout.textPlacements[0])
    let boldText = try #require(boldLayout.textPlacements[0])
    #expect(boldText.width > regularText.width + 0.5)

    let regularImage = try #require(SRTSubtitleRenderer.image(layout: regularLayout, atMilliseconds: 1_000))
    let boldImage = try #require(SRTSubtitleRenderer.image(layout: boldLayout, atMilliseconds: 1_000))
    #expect(srtStyleNonTransparentPixelCount(boldImage) > srtStyleNonTransparentPixelCount(regularImage))
}

@Test
func srtStyleRendersInlineUnderlineWithOutlineAndShadow() throws {
    let canvas = CGSize(width: 640, height: 1_080)
    let style = srtBareStyle {
        $0.size = 72
        $0.outlineWidth = 4
        $0.outlineColor = SRTSubtitleStyle.Color(red: 1, green: 0, blue: 0, alpha: 1)
        $0.shadowOffset = 14
        $0.shadowColor = SRTSubtitleStyle.Color(red: 0, green: 0, blue: 1, alpha: 1)
    }

    let plainLayout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "H   H")],
        canvasSize: canvas,
        style: style
    ))
    let underlinedLayout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "<u>H   H</u>")],
        canvasSize: canvas,
        style: style
    ))

    let plainImage = try #require(SRTSubtitleRenderer.image(layout: plainLayout, atMilliseconds: 1_000))
    let underlinedImage = try #require(SRTSubtitleRenderer.image(layout: underlinedLayout, atMilliseconds: 1_000))

    // Underline adds both red outline pixels and blue shadow pixels across the span.
    #expect(srtStyleRedOutlinePixelCount(underlinedImage) > srtStyleRedOutlinePixelCount(plainImage) + 100)
    #expect(srtStyleBlueShadowPixelCount(underlinedImage) > srtStyleBlueShadowPixelCount(plainImage) + 100)
}

@Test
func srtStyleFillsSolidOutlineBaseAndEliminatesCrossingStrokeArtifacts() throws {
    let canvas = CGSize(width: 640, height: 360)
    // Transparent text with opaque red outline: because the outline layer fills
    // its interior solidly, the glyph interior must be solid red (not hollow).
    let style = srtBareStyle {
        $0.fontName = "PingFangSC-Regular"
        $0.size = 96
        $0.textColor = SRTSubtitleStyle.Color(red: 1, green: 1, blue: 1, alpha: 0)
        $0.outlineWidth = 3
        $0.outlineColor = SRTSubtitleStyle.Color(red: 1, green: 0, blue: 0, alpha: 1)
    }
    let layout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "十")],
        canvasSize: canvas,
        style: style
    ))
    let textBounds = try #require(layout.textPlacements[0])
    let image = try #require(SRTSubtitleRenderer.image(layout: layout, atMilliseconds: 1_000))
    let centerPixel = try #require(srtStyleTestPixel(
        image,
        x: Int(textBounds.midX.rounded()),
        y: Int(textBounds.midY.rounded())
    ))
    #expect(centerPixel.red > 240 && centerPixel.alpha > 240)
}

@Test
func srtStyleBalancesWrappedLinesAndExcludesTrailingLetterSpacing() throws {
    let canvas = CGSize(width: 560, height: 1_080)
    let words = " Alpha Beta Gamma Delta Epsilon"
    let wrapLayout = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "Start" + words)],
        canvasSize: canvas,
        style: srtBareStyle {
            $0.size = 42
            $0.marginX = 30
        }
    ))
    let item = try #require(wrapLayout.items[0])
    #expect(item.lines.count == 2)
    let lineDiff = abs(item.lines[0].width - item.lines[1].width)
    #expect(lineDiff < item.lines[0].width * 0.45)

    // Trailing letterSpacing must not push the right edge of a single-character
    // line outward or shift its horizontal center.
    let zeroSpacing = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "A")],
        canvasSize: CGSize(width: 1_920, height: 1_080),
        style: srtBareStyle { $0.letterSpacing = 0 }
    )?.textPlacements[0])
    let wideSpacing = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "A")],
        canvasSize: CGSize(width: 1_920, height: 1_080),
        style: srtBareStyle { $0.letterSpacing = 20 }
    )?.textPlacements[0])
    #expect(abs(wideSpacing.width - zeroSpacing.width) < 0.01)
    #expect(abs(wideSpacing.midX - 960) < 0.01)

    // Two characters with letterSpacing = 20 gain exactly 20pt (one gap), not 40pt.
    let twoZero = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "AA")],
        canvasSize: CGSize(width: 1_920, height: 1_080),
        style: srtBareStyle { $0.letterSpacing = 0 }
    )?.textPlacements[0])
    let twoWide = try #require(SRTSubtitleRenderer.makeLayout(
        cues: [srtStyleTestCue(0, text: "AA")],
        canvasSize: CGSize(width: 1_920, height: 1_080),
        style: srtBareStyle { $0.letterSpacing = 20 }
    )?.textPlacements[0])
    #expect(abs((twoWide.width - twoZero.width) - 20) < 0.1)
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

private func srtStyleCountPixels(
    _ image: CGImage,
    where predicate: (UInt8, UInt8, UInt8, UInt8) -> Bool
) -> Int {
    guard let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return 0
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let data = context.data else {
        return 0
    }
    let total = image.width * image.height
    let pixels = data.bindMemory(to: UInt8.self, capacity: total * 4)
    var count = 0
    for i in 0..<total {
        let base = i * 4
        if predicate(pixels[base], pixels[base + 1], pixels[base + 2], pixels[base + 3]) {
            count += 1
        }
    }
    return count
}

private func srtStyleNonTransparentPixelCount(_ image: CGImage) -> Int {
    srtStyleCountPixels(image) { _, _, _, alpha in alpha > 16 }
}

private func srtStyleRedOutlinePixelCount(_ image: CGImage) -> Int {
    srtStyleCountPixels(image) { r, g, b, a in a > 128 && r > 180 && g < 60 && b < 60 }
}

private func srtStyleBlueShadowPixelCount(_ image: CGImage) -> Int {
    srtStyleCountPixels(image) { r, g, b, a in a > 128 && b > 180 && r < 60 && g < 60 }
}
