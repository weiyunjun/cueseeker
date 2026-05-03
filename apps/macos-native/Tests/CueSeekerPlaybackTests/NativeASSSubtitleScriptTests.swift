import Foundation
import AppKit
import Testing
@testable import CueSeekerPlayback

@Test
func nativeASSParserReadsScriptStylesAndEvents() {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Bold, Italic, Alignment, MarginL, MarginR, MarginV, Outline, Shadow
    Style: Dial_EN,Helvetica Neue,54,&H00FFFFFF,&H00000000,&H80000000,-1,0,2,36,36,42,3,2

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 1,0:00:01.20,0:00:04.50,Dial_EN,,0,0,0,,{\\an8}Hello\\Nworld{\\pos(100,200)}
    Comment: 1,0:00:01.20,0:00:04.50,Dial_EN,,0,0,0,,Not rendered
    """

    let document = NativeASSParser.parse(contents)

    #expect(document.playResX == 1920)
    #expect(document.playResY == 1080)
    #expect(document.styles["Dial_EN"]?.fontName == "Helvetica Neue")
    #expect(document.styles["Dial_EN"]?.fontSize == 54)
    #expect(document.styles["Dial_EN"]?.primaryColor.red == 1)
    #expect(document.styles["Dial_EN"]?.primaryColor.green == 1)
    #expect(document.styles["Dial_EN"]?.primaryColor.blue == 1)
    #expect(document.styles["Dial_EN"]?.isBold == true)
    #expect(document.styles["Dial_EN"]?.isItalic == false)
    #expect(document.styles["Dial_EN"]?.alignment == 2)
    #expect(document.styles["Dial_EN"]?.marginV == 42)
    #expect(document.styles["Dial_EN"]?.outline == 3)
    #expect(document.styles["Dial_EN"]?.shadow == 2)

    #expect(document.events.count == 1)
    #expect(document.events[0].layer == 1)
    #expect(document.events[0].startMilliseconds == 1_200)
    #expect(document.events[0].endMilliseconds == 4_500)
    #expect(document.events[0].styleName == "Dial_EN")
    #expect(document.events[0].rawText == "{\\an8}Hello\\Nworld{\\pos(100,200)}")
    #expect(document.events[0].cleanedText == "Hello\nworld")
    #expect(document.events[0].alignmentOverride == 8)
}

@Test
func nativeASSParserReadsNonDefaultFormatsAndCommasInText() {
    let contents = """
    [V4 Styles]
    Format: Fontsize, Name, Fontname, BackColour, PrimaryColour, OutlineColour, Italic, Bold
    Style: 70,Dial_CH,FZCuYuan-M03,&H40000000,&H14FFFFFF,&H14211711,-1,0

    [Events]
    Format: End, Start, Style, Layer, Text
    Dialogue: 0:00:05.00,0:00:03.25,Dial_CH,4,One, two, three
    """

    let document = NativeASSParser.parse(contents)
    let style = document.styles["Dial_CH"]

    #expect(style?.fontName == "FZCuYuan-M03")
    #expect(style?.fontSize == 70)
    #expect(style?.isItalic == true)
    #expect(style?.isBold == false)
    #expect(style?.primaryColor.alpha == 1 - (20.0 / 255.0))
    #expect(style?.outlineColor.red == 17.0 / 255.0)
    #expect(style?.outlineColor.green == 23.0 / 255.0)
    #expect(style?.outlineColor.blue == 33.0 / 255.0)
    #expect(style?.shadowColor.alpha == 1 - (64.0 / 255.0))

    #expect(document.events.count == 1)
    #expect(document.events[0].startMilliseconds == 3_250)
    #expect(document.events[0].endMilliseconds == 5_000)
    #expect(document.events[0].layer == 4)
    #expect(document.events[0].styleName == "Dial_CH")
    #expect(document.events[0].cleanedText == "One, two, three")
}

@Test
func nativeASSDocumentSelectsActiveCuesByTimeLayerAndSourceOrder() {
    let contents = """
    [V4+ Styles]
    Format: Name, Alignment, MarginL, MarginR, MarginV
    Style: Default,2,20,30,40
    Style: Top,8,100,110,120

    [Events]
    Format: Layer, Start, End, Style, MarginL, MarginR, MarginV, Text
    Dialogue: 2,0:00:01.00,0:00:03.00,Top,0,0,0,Layer two
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,0,0,0,Layer zero first
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,12,13,14,{\\an7}Layer zero second
    Dialogue: 9,0:00:04.00,0:00:05.00,Default,0,0,0,Inactive
    """

    let activeCues = NativeASSParser.parse(contents).activeCues(atMilliseconds: 1_500)

    #expect(activeCues.map(\.text) == ["Layer zero first", "Layer zero second", "Layer two"])
    #expect(activeCues.map(\.event.layer) == [0, 0, 2])
    #expect(activeCues[0].effectiveAlignment == 2)
    #expect(activeCues[1].effectiveAlignment == 7)
    #expect(activeCues[2].effectiveAlignment == 8)
    #expect(activeCues[0].marginL == 20)
    #expect(activeCues[1].marginL == 12)
    #expect(activeCues[1].marginR == 13)
    #expect(activeCues[1].marginV == 14)
    #expect(activeCues[2].marginV == 120)
}

@Test
func nativeASSParserStripsUnsupportedOverrideTagsFromVisibleText() {
    let contents = """
    [Events]
    Format: Start, End, Text
    Dialogue: 0:00:01.00,0:00:03.00,{\\pos(100,200)\\blur4}Hello\\N{\\move(0,0,10,10)}world{\\p1}m 0 0 l 10 10{\\p0}\\h!
    """

    let event = NativeASSParser.parse(contents).events.first

    #expect(event?.rawText.contains("\\pos") == true)
    #expect(event?.rawText.contains("\\p1") == true)
    #expect(event?.cleanedText == "Hello\nworld !")
    #expect(event?.cleanedText.contains("\\pos") == false)
    #expect(event?.cleanedText.contains("m 0 0") == false)
}

@Test
func nativeASSParserReadsLeadingStaticSizeOverrides() {
    let contents = """
    [V4+ Styles]
    Format: Name, Fontname, Fontsize, ScaleX, ScaleY
    Style: Default,Helvetica,48,100,100

    [Events]
    Format: Start, End, Style, Text
    Dialogue: 0:00:01.00,0:00:03.00,Default,{\\an2\\FS24\\fscx80\\FSCY75}Hello
    Dialogue: 0:00:04.00,0:00:05.00,Default,Hello {\\fs12}world
    """

    let events = NativeASSParser.parse(contents).events

    #expect(events[0].cleanedText == "Hello")
    #expect(events[0].alignmentOverride == 2)
    #expect(events[0].styleOverride.fontSize == 24)
    #expect(events[0].styleOverride.scaleX == 80)
    #expect(events[0].styleOverride.scaleY == 75)

    #expect(events[1].cleanedText == "Hello world")
    #expect(events[1].styleOverride.fontSize == nil)
    #expect(events[1].styleOverride.scaleX == nil)
    #expect(events[1].styleOverride.scaleY == nil)
}

@Test
@MainActor
func nativeASSRendererProducesTextBoundedSurfaces() {
    let contents = """
    [Script Info]
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Alignment, MarginL, MarginR, MarginV, Outline, Shadow
    Style: Default,Helvetica,32,&H00FFFFFF,&H00000000,&H80000000,2,24,24,30,2,1

    [Events]
    Format: Start, End, Style, Text
    Dialogue: 0:00:01.00,0:00:03.00,Default,Hello\\Nworld
    """
    let document = NativeASSParser.parse(contents)

    let surfaces = NativeASSSubtitleRenderer.renderSurfaces(
        document: document,
        atMilliseconds: 1_500,
        containerBounds: CGRect(x: 0, y: 0, width: 640, height: 360),
        videoSize: CGSize(width: 640, height: 360),
        backingScale: 2
    )

    #expect(surfaces.count == 1)
    guard let surface = surfaces.first else {
        return
    }

    #expect(surface.text == "Hello\nworld")
    #expect(surface.frame.width < 640)
    #expect(surface.frame.height < 140)
    #expect(surface.frame.minY > 180)
    #expect(surface.image.width < 640 * 2)
    #expect(surface.image.height < 140 * 2)
}

@Test
@MainActor
func nativeASSRendererAppliesLeadingStaticSizeOverrides() {
    let contents = """
    [Script Info]
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, ScaleX, ScaleY, Alignment, MarginL, MarginR, MarginV
    Style: Default,Helvetica,40,100,100,2,24,24,30

    [Events]
    Format: Start, End, Style, Text
    Dialogue: 0:00:01.00,0:00:02.00,Default,Visual size sample
    Dialogue: 0:00:03.00,0:00:04.00,Default,{\\fs20\\fscx70\\fscy70}Visual size sample
    """
    let document = NativeASSParser.parse(contents)

    let defaultSurface = NativeASSSubtitleRenderer.renderSurfaces(
        document: document,
        atMilliseconds: 1_500,
        containerBounds: CGRect(x: 0, y: 0, width: 640, height: 360),
        videoSize: CGSize(width: 640, height: 360),
        backingScale: 2
    ).first
    let overrideSurface = NativeASSSubtitleRenderer.renderSurfaces(
        document: document,
        atMilliseconds: 3_500,
        containerBounds: CGRect(x: 0, y: 0, width: 640, height: 360),
        videoSize: CGSize(width: 640, height: 360),
        backingScale: 2
    ).first

    #expect(defaultSurface != nil)
    #expect(overrideSurface != nil)
    guard let defaultSurface, let overrideSurface else {
        return
    }

    #expect(overrideSurface.frame.height < defaultSurface.frame.height * 0.7)
    #expect(overrideSurface.frame.width < defaultSurface.frame.width * 0.7)
}

@Test
@MainActor
func nativeASSRendererCalibratesCJKDialogueFontSize() {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, Bold, Alignment, MarginL, MarginR, MarginV, Outline, Shadow
    Style: Default,Helvetica,54,-1,2,36,36,42,3,0

    [Events]
    Format: Start, End, Style, Text
    Dialogue: 0:00:01.00,0:00:03.00,Default,怎么湿成这样 你没事吧\\Nびしょぬれじゃない　大丈夫
    """
    let document = NativeASSParser.parse(contents)

    let surface = NativeASSSubtitleRenderer.renderSurfaces(
        document: document,
        atMilliseconds: 1_500,
        containerBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        videoSize: CGSize(width: 1920, height: 1080),
        backingScale: 2
    ).first

    #expect(surface != nil)
    guard let surface else {
        return
    }

    #expect(surface.frame.width < 640)
    #expect(surface.frame.height < 125)
}

@Test
@MainActor
func nativeASSRendererDoesNotClampSmallScriptFontSizesToEightPoints() {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, Alignment, MarginL, MarginR, MarginV
    Style: Small,Helvetica,24,2,24,24,30
    Style: Large,Helvetica,48,2,24,24,30

    [Events]
    Format: Start, End, Style, Text
    Dialogue: 0:00:01.00,0:00:02.00,Small,Visual size sample
    Dialogue: 0:00:03.00,0:00:04.00,Large,Visual size sample
    """
    let document = NativeASSParser.parse(contents)

    let smallSurface = NativeASSSubtitleRenderer.renderSurfaces(
        document: document,
        atMilliseconds: 1_500,
        containerBounds: CGRect(x: 0, y: 0, width: 320, height: 180),
        videoSize: CGSize(width: 1920, height: 1080),
        backingScale: 2
    ).first
    let largeSurface = NativeASSSubtitleRenderer.renderSurfaces(
        document: document,
        atMilliseconds: 3_500,
        containerBounds: CGRect(x: 0, y: 0, width: 320, height: 180),
        videoSize: CGSize(width: 1920, height: 1080),
        backingScale: 2
    ).first

    #expect(smallSurface != nil)
    #expect(largeSurface != nil)
    guard let smallSurface, let largeSurface else {
        return
    }

    #expect(smallSurface.frame.height < largeSurface.frame.height * 0.8)
}

@Test
@MainActor
func nativeASSRendererDoesNotClampTinyScaleOverridesToTenPercent() {
    let contents = """
    [Script Info]
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, Alignment, MarginL, MarginR, MarginV
    Style: Default,Helvetica,100,2,24,24,30

    [Events]
    Format: Start, End, Style, Text
    Dialogue: 0:00:01.00,0:00:02.00,Default,{\\fscy5}Visual size sample
    Dialogue: 0:00:03.00,0:00:04.00,Default,{\\fscy10}Visual size sample
    """
    let document = NativeASSParser.parse(contents)

    let tinyScaleSurface = NativeASSSubtitleRenderer.renderSurfaces(
        document: document,
        atMilliseconds: 1_500,
        containerBounds: CGRect(x: 0, y: 0, width: 640, height: 360),
        videoSize: CGSize(width: 640, height: 360),
        backingScale: 2
    ).first
    let tenPercentSurface = NativeASSSubtitleRenderer.renderSurfaces(
        document: document,
        atMilliseconds: 3_500,
        containerBounds: CGRect(x: 0, y: 0, width: 640, height: 360),
        videoSize: CGSize(width: 640, height: 360),
        backingScale: 2
    ).first

    #expect(tinyScaleSurface != nil)
    #expect(tenPercentSurface != nil)
    guard let tinyScaleSurface, let tenPercentSurface else {
        return
    }

    #expect(tinyScaleSurface.frame.height < tenPercentSurface.frame.height * 0.75)
}
